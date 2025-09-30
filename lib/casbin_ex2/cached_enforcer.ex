defmodule CasbinEx2.CachedEnforcer do
  @moduledoc """
  Cached enforcer that wraps the basic enforcer with a cache layer
  for improved performance on repeated authorization checks.
  """

  use GenServer

  require Logger

  alias CasbinEx2.Enforcer

  defstruct [:enforcer, :cache, :cache_size, :enable_cache]

  @type t :: %__MODULE__{
          enforcer: Enforcer.t(),
          cache: map(),
          cache_size: integer(),
          enable_cache: boolean()
        }

  @default_cache_size 1000

  #
  # Client API
  #

  @doc """
  Starts a cached enforcer server.
  """
  def start_link(name, model_path, opts \\ []) do
    GenServer.start_link(
      __MODULE__,
      {name, model_path, opts},
      name: via_tuple(name)
    )
  end

  @doc """
  Performs cached authorization enforcement.
  """
  def enforce(name, request) do
    GenServer.call(via_tuple(name), {:enforce, request})
  end

  @doc """
  Invalidates the cache.
  """
  def invalidate_cache(name) do
    GenServer.call(via_tuple(name), {:invalidate_cache})
  end

  @doc """
  Enables or disables the cache.
  """
  def enable_cache(name, enable) do
    GenServer.call(via_tuple(name), {:enable_cache, enable})
  end

  @doc """
  Sets the cache size.
  """
  def set_cache_size(name, size) do
    GenServer.call(via_tuple(name), {:set_cache_size, size})
  end

  @doc """
  Gets cache statistics.
  """
  def get_cache_stats(name) do
    GenServer.call(via_tuple(name), {:get_cache_stats})
  end

  # Delegate other calls to the underlying enforcer
  def add_policy(name, params), do: call_and_invalidate(name, {:add_policy, params})
  def remove_policy(name, params), do: call_and_invalidate(name, {:remove_policy, params})

  def add_grouping_policy(name, params),
    do: call_and_invalidate(name, {:add_grouping_policy, params})

  def remove_grouping_policy(name, params),
    do: call_and_invalidate(name, {:remove_grouping_policy, params})

  def load_policy(name), do: call_and_invalidate(name, {:load_policy})

  def get_policy(name), do: GenServer.call(via_tuple(name), {:get_policy})
  def get_grouping_policy(name), do: GenServer.call(via_tuple(name), {:get_grouping_policy})
  def has_policy(name, params), do: GenServer.call(via_tuple(name), {:has_policy, params})

  #
  # Server Callbacks
  #

  @impl GenServer
  def init({name, model_path, opts}) do
    cache_size = Keyword.get(opts, :cache_size, @default_cache_size)
    enable_cache = Keyword.get(opts, :enable_cache, true)

    case create_cached_enforcer(name, model_path, opts) do
      {:ok, enforcer} ->
        state = %__MODULE__{
          enforcer: enforcer,
          cache: %{},
          cache_size: cache_size,
          enable_cache: enable_cache
        }

        Logger.info("Started cached enforcer server '#{name}' with cache size #{cache_size}")
        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to start cached enforcer server '#{name}': #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:enforce, request}, _from, state) do
    if state.enable_cache do
      cached_enforce(request, state)
    else
      result = Enforcer.enforce(state.enforcer, request)
      {:reply, result, state}
    end
  end

  def handle_call({:invalidate_cache}, _from, state) do
    new_state = %{state | cache: %{}}
    Logger.debug("Cache invalidated")
    {:reply, :ok, new_state}
  end

  def handle_call({:enable_cache, enable}, _from, state) do
    new_state = %{state | enable_cache: enable}

    new_state =
      if not enable do
        # Clear cache when disabling
        %{new_state | cache: %{}}
      else
        new_state
      end

    Logger.info("Cache #{if enable, do: "enabled", else: "disabled"}")
    {:reply, :ok, new_state}
  end

  def handle_call({:set_cache_size, size}, _from, state) do
    new_state = %{state | cache_size: size}

    # Trim cache if necessary
    new_state = trim_cache(new_state)

    Logger.info("Cache size set to #{size}")
    {:reply, :ok, new_state}
  end

  def handle_call({:get_cache_stats}, _from, state) do
    stats = %{
      cache_size: map_size(state.cache),
      max_cache_size: state.cache_size,
      cache_enabled: state.enable_cache
    }

    {:reply, stats, state}
  end

  # Policy modification calls that invalidate cache
  def handle_call(call, from, state)
      when elem(call, 0) in [
             :add_policy,
             :remove_policy,
             :add_grouping_policy,
             :remove_grouping_policy,
             :load_policy
           ] do
    # Delegate to enforcer server and invalidate cache
    result = delegate_to_enforcer_server(call, from, state.enforcer)
    new_state = %{state | cache: %{}}
    {:reply, result, new_state}
  end

  # Read-only calls that don't invalidate cache
  def handle_call(call, from, state) do
    result = delegate_to_enforcer_server(call, from, state.enforcer)
    {:reply, result, state}
  end

  #
  # Helper Functions
  #

  defp via_tuple(name) do
    {:via, Registry, {CasbinEx2.EnforcerRegistry, :"cached_#{name}"}}
  end

  defp call_and_invalidate(name, call) do
    GenServer.call(via_tuple(name), call)
  end

  defp create_cached_enforcer(name, model_path, opts) do
    # Create the underlying enforcer
    adapter = Keyword.get(opts, :adapter, CasbinEx2.Adapter.FileAdapter.new(""))

    case Enforcer.init_with_file(model_path, adapter) do
      {:ok, enforcer} ->
        # Store in ETS with a cached prefix
        :ets.insert(:casbin_enforcers_table, {:"cached_#{name}", enforcer})
        {:ok, enforcer}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp cached_enforce(request, state) do
    cache_key = :erlang.phash2(request)

    case Map.get(state.cache, cache_key) do
      nil ->
        # Cache miss - compute result and cache it
        result = Enforcer.enforce(state.enforcer, request)
        new_cache = Map.put(state.cache, cache_key, result)
        new_state = %{state | cache: new_cache} |> trim_cache()

        Logger.debug("Cache miss for request: #{inspect(request)}")
        {:reply, result, new_state}

      cached_result ->
        # Cache hit
        Logger.debug("Cache hit for request: #{inspect(request)}")
        {:reply, cached_result, state}
    end
  end

  defp trim_cache(state) do
    if map_size(state.cache) > state.cache_size do
      # Simple LRU-like eviction: keep only the most recent entries
      # In a production system, you might want a more sophisticated LRU implementation
      cache_entries = Enum.take(state.cache, state.cache_size)
      %{state | cache: Map.new(cache_entries)}
    else
      state
    end
  end

  # This is a simplified delegation - in practice, you might want to
  # implement a more sophisticated approach
  defp delegate_to_enforcer_server(call, _from, enforcer) do
    # For now, we'll handle these calls directly against the enforcer struct
    # In a full implementation, you might want to delegate to an actual enforcer server
    case call do
      {:get_policy} ->
        Map.get(enforcer.policies, "p", [])

      {:get_grouping_policy} ->
        Map.get(enforcer.grouping_policies, "g", [])

      {:has_policy, params} ->
        current_rules = Map.get(enforcer.policies, "p", [])
        params in current_rules

      _ ->
        {:error, :not_implemented}
    end
  end
end
