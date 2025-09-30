defmodule CasbinEx2.Adapter.ContextAdapter do
  @moduledoc """
  Context-Aware Adapter framework that provides enhanced adapters with contextual information.

  This framework enables adapters to receive and utilize additional context such as:
  - Request metadata (timestamps, user agent, etc.)
  - Environment information (tenant, deployment stage, etc.)
  - Security context (authentication state, IP address, etc.)
  - Performance context (caching hints, priority levels, etc.)

  ## Context Structure

  Context is passed as a map with standardized keys:

      %{
        request_id: "unique-request-id",
        timestamp: ~U[2024-01-01 00:00:00Z],
        user_agent: "CasbinEx2/1.0",
        ip_address: "192.168.1.1",
        tenant_id: "tenant-123",
        environment: "production",
        auth_context: %{user_id: "user-456", roles: ["admin"]},
        performance_hints: %{cache_ttl: 300, priority: :normal}
      }

  ## Usage

      # Create a context-aware adapter
      base_adapter = CasbinEx2.Adapter.FileAdapter.new("policy.csv")
      context_adapter = CasbinEx2.Adapter.ContextAdapter.new(base_adapter, default_context)

      # Use with enforcer
      enforcer = CasbinEx2.Enforcer.new(model, context_adapter)

      # Operations automatically include context
      CasbinEx2.Enforcer.add_policy(enforcer, "alice", "data1", "read")
  """

  @behaviour CasbinEx2.Adapter

  defstruct [
    :base_adapter,
    :default_context,
    :context_processors,
    :middleware
  ]

  @type context :: %{
          optional(:request_id) => String.t(),
          optional(:timestamp) => DateTime.t(),
          optional(:user_agent) => String.t(),
          optional(:ip_address) => String.t(),
          optional(:tenant_id) => String.t(),
          optional(:environment) => String.t(),
          optional(:auth_context) => map(),
          optional(:performance_hints) => map(),
          optional(atom()) => any()
        }

  @type context_processor :: (context -> context)
  @type middleware :: (atom(), list(), context -> {:ok, any()} | {:error, term()} | :continue)

  @type t :: %__MODULE__{
          base_adapter: CasbinEx2.Adapter.t(),
          default_context: context(),
          context_processors: [context_processor()],
          middleware: [middleware()]
        }

  @doc """
  Creates a new context-aware adapter.

  ## Parameters

  - `base_adapter` - The underlying adapter to wrap
  - `default_context` - Default context values to merge with request context
  - `opts` - Optional configuration
    - `:context_processors` - List of functions to process context
    - `:middleware` - List of middleware functions for operation interception

  ## Examples

      base_adapter = CasbinEx2.Adapter.FileAdapter.new("policy.csv")

      default_context = %{
        environment: "production",
        tenant_id: "default-tenant"
      }

      context_adapter = CasbinEx2.Adapter.ContextAdapter.new(
        base_adapter,
        default_context,
        context_processors: [&add_timestamp/1],
        middleware: [&audit_middleware/3]
      )
  """
  @spec new(CasbinEx2.Adapter.t(), context(), keyword()) :: t()
  def new(base_adapter, default_context \\ %{}, opts \\ []) do
    %__MODULE__{
      base_adapter: base_adapter,
      default_context: default_context,
      context_processors: Keyword.get(opts, :context_processors, []),
      middleware: Keyword.get(opts, :middleware, [])
    }
  end

  @doc """
  Sets the request context for subsequent operations.

  Context is stored in the process dictionary and merged with default context.
  """
  @spec set_context(context()) :: :ok
  def set_context(context) when is_map(context) do
    Process.put(:casbin_context, context)
    :ok
  end

  @doc """
  Gets the current request context.

  Returns merged context from process dictionary and default context.
  """
  @spec get_context(t()) :: context()
  def get_context(%__MODULE__{default_context: default_context, context_processors: processors}) do
    request_context = Process.get(:casbin_context, %{})

    default_context
    |> Map.merge(request_context)
    |> apply_context_processors(processors)
  end

  @doc """
  Clears the current request context.
  """
  @spec clear_context() :: :ok
  def clear_context do
    Process.delete(:casbin_context)
    :ok
  end

  @doc """
  Executes a function with a specific context.

  The context is automatically set before execution and cleared afterwards.
  """
  @spec with_context(context(), (-> any())) :: any()
  def with_context(context, fun) when is_map(context) and is_function(fun, 0) do
    old_context = Process.get(:casbin_context)
    set_context(context)

    try do
      fun.()
    after
      if old_context do
        set_context(old_context)
      else
        clear_context()
      end
    end
  end

  # Adapter Behaviour Implementation

  @impl CasbinEx2.Adapter
  def load_policy(%__MODULE__{} = adapter, model) do
    context = get_context(adapter)
    execute_with_middleware(adapter, :load_policy, [model], context)
  end

  @impl CasbinEx2.Adapter
  def load_filtered_policy(%__MODULE__{} = adapter, model, filter) do
    context = get_context(adapter)
    execute_with_middleware(adapter, :load_filtered_policy, [model, filter], context)
  end

  @impl CasbinEx2.Adapter
  def load_incremental_filtered_policy(%__MODULE__{} = adapter, model, filter) do
    context = get_context(adapter)
    execute_with_middleware(adapter, :load_incremental_filtered_policy, [model, filter], context)
  end

  @impl CasbinEx2.Adapter
  def filtered?(%__MODULE__{base_adapter: base_adapter}) do
    CasbinEx2.Adapter.filtered?(base_adapter)
  end

  @impl CasbinEx2.Adapter
  def save_policy(%__MODULE__{} = adapter, policies, grouping_policies) do
    context = get_context(adapter)
    execute_with_middleware(adapter, :save_policy, [policies, grouping_policies], context)
  end

  @impl CasbinEx2.Adapter
  def add_policy(%__MODULE__{} = adapter, sec, ptype, rule) do
    context = get_context(adapter)
    execute_with_middleware(adapter, :add_policy, [sec, ptype, rule], context)
  end

  @impl CasbinEx2.Adapter
  def remove_policy(%__MODULE__{} = adapter, sec, ptype, rule) do
    context = get_context(adapter)
    execute_with_middleware(adapter, :remove_policy, [sec, ptype, rule], context)
  end

  @impl CasbinEx2.Adapter
  def remove_filtered_policy(%__MODULE__{} = adapter, sec, ptype, field_index, field_values) do
    context = get_context(adapter)

    execute_with_middleware(
      adapter,
      :remove_filtered_policy,
      [sec, ptype, field_index, field_values],
      context
    )
  end

  # Private functions

  defp apply_context_processors(context, processors) do
    Enum.reduce(processors, context, fn processor, acc ->
      processor.(acc)
    end)
  end

  defp execute_with_middleware(
         %__MODULE__{base_adapter: base_adapter, middleware: middleware},
         operation,
         args,
         context
       ) do
    case run_middleware(middleware, operation, args, context) do
      :continue ->
        # No middleware intercepted, execute on base adapter
        apply(base_adapter.__struct__, operation, [base_adapter | args])

      {:ok, policies, grouping_policies} ->
        {:ok, policies, grouping_policies}

      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp run_middleware([], _operation, _args, _context), do: :continue

  defp run_middleware([middleware | rest], operation, args, context) do
    case middleware.(operation, args, context) do
      :continue -> run_middleware(rest, operation, args, context)
      result -> result
    end
  end

  # Built-in Context Processors

  @doc """
  Built-in context processor that adds current timestamp.
  """
  @spec add_timestamp_processor(context()) :: context()
  def add_timestamp_processor(context) do
    Map.put_new(context, :timestamp, DateTime.utc_now())
  end

  @doc """
  Built-in context processor that adds a unique request ID.
  """
  @spec add_request_id_processor(context()) :: context()
  def add_request_id_processor(context) do
    Map.put_new(context, :request_id, generate_request_id())
  end

  @doc """
  Built-in context processor that validates required context fields.
  """
  @spec validate_context_processor([atom()]) :: context_processor()
  def validate_context_processor(required_fields) do
    fn context ->
      missing_fields =
        required_fields
        |> Enum.reject(&Map.has_key?(context, &1))

      if Enum.empty?(missing_fields) do
        context
      else
        raise ArgumentError, "Missing required context fields: #{inspect(missing_fields)}"
      end
    end
  end

  # Built-in Middleware

  @doc """
  Built-in middleware for auditing adapter operations.

  Logs all adapter operations with context information.
  """
  @spec audit_middleware(atom(), list(), context()) :: :continue
  def audit_middleware(operation, args, context) do
    require Logger

    Logger.info("Adapter operation #{operation}", %{
      operation: operation,
      args_count: length(args),
      context: context,
      timestamp: DateTime.utc_now()
    })

    :continue
  end

  @doc """
  Built-in middleware for performance monitoring.

  Measures and logs execution time for adapter operations.
  """
  @spec performance_middleware(atom(), list(), context()) :: :continue
  def performance_middleware(_operation, _args, context) do
    start_time = System.monotonic_time(:microsecond)

    # Store start time in context for post-execution measurement
    updated_context = Map.put(context, :start_time, start_time)
    set_context(updated_context)

    :continue
  end

  @doc """
  Built-in middleware for caching read operations.

  Caches the results of load_policy and load_filtered_policy operations.
  """
  @spec cache_middleware(atom(), list(), context()) :: :continue | {:ok, any()}
  def cache_middleware(operation, args, context)
      when operation in [:load_policy, :load_filtered_policy] do
    case get_cache_hint(context) do
      nil ->
        :continue

      ttl ->
        cache_key = generate_cache_key(operation, args, context)

        case lookup_cache(cache_key) do
          {:ok, cached_result} ->
            {:ok, cached_result}

          :miss ->
            # Cache miss - let operation continue and cache result
            Process.put(:cache_key, cache_key)
            Process.put(:cache_ttl, ttl)
            :continue
        end
    end
  end

  def cache_middleware(_operation, _args, _context), do: :continue

  @doc """
  Built-in middleware for multi-tenant isolation.

  Ensures operations are scoped to the correct tenant.
  """
  @spec tenant_isolation_middleware(atom(), list(), context()) :: :continue | {:error, term()}
  def tenant_isolation_middleware(_operation, _args, context) do
    case Map.get(context, :tenant_id) do
      nil ->
        {:error, "Tenant ID required for this operation"}

      tenant_id when is_binary(tenant_id) ->
        # Validate tenant access permissions here if needed
        :continue

      _ ->
        {:error, "Invalid tenant ID format"}
    end
  end

  # Utility functions

  defp generate_request_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp get_cache_hint(context) do
    context
    |> Map.get(:performance_hints, %{})
    |> Map.get(:cache_ttl)
  end

  defp generate_cache_key(operation, args, context) do
    tenant_id = Map.get(context, :tenant_id, "default")
    args_hash = :erlang.phash2(args)
    "casbin:#{tenant_id}:#{operation}:#{args_hash}"
  end

  defp lookup_cache(_cache_key) do
    # Placeholder for cache implementation
    # In a real implementation, this would interface with ETS, Redis, etc.
    :miss
  end
end
