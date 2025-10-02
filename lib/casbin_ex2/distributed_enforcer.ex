defmodule CasbinEx2.DistributedEnforcer do
  @moduledoc """
  Distributed enforcer implementation for multi-node Casbin deployments.

  This module provides distributed enforcement capabilities, allowing multiple
  enforcer instances across different nodes to coordinate and synchronize
  policy changes automatically.
  """

  use GenServer
  require Logger

  alias CasbinEx2.Adapter.MemoryAdapter
  alias CasbinEx2.{EnforcerServer, Watcher}

  defstruct [
    :enforcer_name,
    :local_enforcer,
    :watcher,
    :nodes,
    :sync_interval,
    :last_sync,
    :auto_sync
  ]

  @type t :: %__MODULE__{
          enforcer_name: String.t(),
          local_enforcer: pid() | nil,
          watcher: Watcher.t() | nil,
          nodes: [node()],
          sync_interval: non_neg_integer(),
          last_sync: DateTime.t() | nil,
          auto_sync: boolean()
        }

  # 30 seconds
  @default_sync_interval 30_000
  @registry CasbinEx2.Registry

  @doc """
  Starts a distributed enforcer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)

    GenServer.start_link(__MODULE__, opts,
      name: {:via, Registry, {@registry, {:distributed_enforcer, name}}}
    )
  end

  @doc """
  Creates a new distributed enforcer configuration.
  """
  @spec new(String.t(), keyword()) :: t()
  def new(enforcer_name, opts \\ []) do
    %__MODULE__{
      enforcer_name: enforcer_name,
      nodes: Keyword.get(opts, :nodes, [Node.self()]),
      sync_interval: Keyword.get(opts, :sync_interval, @default_sync_interval),
      auto_sync: Keyword.get(opts, :auto_sync, true),
      watcher: Keyword.get(opts, :watcher)
    }
  end

  @doc """
  Enforces a permission check across the distributed cluster.
  """
  @spec enforce(String.t(), [String.t()]) :: boolean()
  def enforce(enforcer_name, params) do
    case Registry.lookup(@registry, {:distributed_enforcer, enforcer_name}) do
      [{pid, _}] ->
        GenServer.call(pid, {:enforce, params})

      [] ->
        {:error, :enforcer_not_found}
    end
  end

  @doc """
  Adds a policy to all nodes in the distributed cluster.
  """
  @spec add_policy(String.t(), [String.t()]) :: :ok | {:error, term()}
  def add_policy(enforcer_name, params) do
    case Registry.lookup(@registry, {:distributed_enforcer, enforcer_name}) do
      [{pid, _}] ->
        GenServer.call(pid, {:add_policy, params})

      [] ->
        {:error, :enforcer_not_found}
    end
  end

  @doc """
  Removes a policy from all nodes in the distributed cluster.
  """
  @spec remove_policy(String.t(), [String.t()]) :: :ok | {:error, term()}
  def remove_policy(enforcer_name, params) do
    case Registry.lookup(@registry, {:distributed_enforcer, enforcer_name}) do
      [{pid, _}] ->
        GenServer.call(pid, {:remove_policy, params})

      [] ->
        {:error, :enforcer_not_found}
    end
  end

  @doc """
  Synchronizes policies across all nodes in the cluster.
  """
  @spec sync_policies(String.t()) :: :ok | {:error, term()}
  def sync_policies(enforcer_name) do
    case Registry.lookup(@registry, {:distributed_enforcer, enforcer_name}) do
      [{pid, _}] ->
        GenServer.call(pid, :sync_policies)

      [] ->
        {:error, :enforcer_not_found}
    end
  end

  @doc """
  Gets the cluster status for the distributed enforcer.
  """
  @spec cluster_status(String.t()) :: %{
          nodes: [node()],
          healthy_nodes: [node()],
          last_sync: DateTime.t() | nil
        }
  def cluster_status(enforcer_name) do
    case Registry.lookup(@registry, {:distributed_enforcer, enforcer_name}) do
      [{pid, _}] ->
        GenServer.call(pid, :cluster_status)

      [] ->
        {:error, :enforcer_not_found}
    end
  end

  @doc """
  Sets the auto-sync behavior for the distributed enforcer.
  """
  @spec set_auto_sync(String.t(), boolean()) :: :ok | {:error, term()}
  def set_auto_sync(enforcer_name, enabled) do
    case Registry.lookup(@registry, {:distributed_enforcer, enforcer_name}) do
      [{pid, _}] ->
        GenServer.call(pid, {:set_auto_sync, enabled})

      [] ->
        {:error, :enforcer_not_found}
    end
  end

  # GenServer callbacks

  @impl GenServer
  def init(opts) do
    enforcer_name = Keyword.fetch!(opts, :name)
    nodes = Keyword.get(opts, :nodes, [Node.self()])
    watcher = Keyword.get(opts, :watcher)

    # Start local enforcer
    model_path = Keyword.fetch!(opts, :model_path)

    local_enforcer_opts =
      opts
      |> Keyword.drop([:nodes, :sync_interval, :auto_sync, :watcher, :model_path])
      |> Keyword.put_new(:adapter, MemoryAdapter.new())

    {:ok, local_enforcer} =
      EnforcerServer.start_link(enforcer_name, model_path, local_enforcer_opts)

    # Setup watcher if provided
    if watcher do
      Watcher.set_update_callback(watcher, fn ->
        GenServer.cast(self(), :policy_updated)
      end)
    end

    state = %__MODULE__{
      enforcer_name: enforcer_name,
      local_enforcer: local_enforcer,
      watcher: watcher,
      nodes: nodes,
      sync_interval: Keyword.get(opts, :sync_interval, @default_sync_interval),
      auto_sync: Keyword.get(opts, :auto_sync, true)
    }

    # Schedule initial sync
    if state.auto_sync do
      Process.send_after(self(), :sync_timer, state.sync_interval)
    end

    # Monitor cluster nodes
    Enum.each(nodes, &Node.monitor(&1, true))

    # Logger.debug("Started distributed enforcer #{enforcer_name} with nodes: #{inspect(nodes)}")

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:enforce, params}, _from, state) do
    result = GenServer.call(state.local_enforcer, {:enforce, params})
    {:reply, result, state}
  end

  def handle_call({:add_policy, params}, _from, state) do
    # Add to local enforcer first
    result = GenServer.call(state.local_enforcer, {:add_policy, params})

    case result do
      true ->
        # Broadcast to other nodes
        broadcast_policy_change({:add_policy, params}, state)

        # Notify watcher
        if state.watcher do
          Watcher.update_for_enforcer(state.watcher, state.enforcer_name)
        end

        {:reply, :ok, state}

      false ->
        {:reply, {:error, :add_failed}, state}
    end
  end

  def handle_call({:remove_policy, params}, _from, state) do
    # Remove from local enforcer first
    result = GenServer.call(state.local_enforcer, {:remove_policy, params})

    case result do
      true ->
        # Broadcast to other nodes
        broadcast_policy_change({:remove_policy, params}, state)

        # Notify watcher
        if state.watcher do
          Watcher.update_for_enforcer(state.watcher, state.enforcer_name)
        end

        {:reply, :ok, state}

      false ->
        {:reply, {:error, :remove_failed}, state}
    end
  end

  def handle_call(:sync_policies, _from, state) do
    result = perform_sync(state)
    new_state = %{state | last_sync: DateTime.utc_now()}
    {:reply, result, new_state}
  end

  def handle_call(:cluster_status, _from, state) do
    healthy_nodes = get_healthy_nodes(state.nodes)

    status = %{
      nodes: state.nodes,
      healthy_nodes: healthy_nodes,
      last_sync: state.last_sync,
      auto_sync: state.auto_sync
    }

    {:reply, status, state}
  end

  def handle_call({:set_auto_sync, enabled}, _from, state) do
    new_state = %{state | auto_sync: enabled}

    if enabled and not state.auto_sync do
      Process.send_after(self(), :sync_timer, state.sync_interval)
    end

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_cast(:policy_updated, state) do
    # Policy was updated via watcher, reload local enforcer
    GenServer.call(state.local_enforcer, :load_policy)
    {:noreply, state}
  end

  def handle_cast({:remote_policy_change, {action, params}}, state) do
    # Apply remote policy change to local enforcer
    case action do
      :add_policy ->
        GenServer.call(state.local_enforcer, {:add_policy, params})

      :remove_policy ->
        GenServer.call(state.local_enforcer, {:remove_policy, params})
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:sync_timer, %{auto_sync: true} = state) do
    perform_sync(state)

    # Schedule next sync
    Process.send_after(self(), :sync_timer, state.sync_interval)

    new_state = %{state | last_sync: DateTime.utc_now()}
    {:noreply, new_state}
  end

  def handle_info(:sync_timer, state) do
    # Auto-sync is disabled, don't schedule next timer
    {:noreply, state}
  end

  def handle_info({:nodedown, node}, state) do
    Logger.warning("Node #{node} went down in distributed enforcer #{state.enforcer_name}")
    {:noreply, state}
  end

  def handle_info({:nodeup, _node}, state) do
    Logger.debug("Node came up in distributed enforcer #{state.enforcer_name}")

    # Trigger sync when a node comes back online
    if state.auto_sync do
      perform_sync(state)
    end

    {:noreply, state}
  end

  # Private functions

  defp broadcast_policy_change(change, state) do
    message = {:remote_policy_change, change}

    # Send to all other nodes
    other_nodes = List.delete(state.nodes, Node.self())

    Enum.each(other_nodes, fn node ->
      case :rpc.call(node, Registry, :lookup, [
             @registry,
             {:distributed_enforcer, state.enforcer_name}
           ]) do
        [{pid, _}] when is_pid(pid) ->
          GenServer.cast(pid, message)

        [] ->
          Logger.warning("Distributed enforcer #{state.enforcer_name} not found on node #{node}")

        {:badrpc, reason} ->
          Logger.warning(
            "Failed to lookup distributed enforcer on node #{node}: #{inspect(reason)}"
          )
      end
    end)
  end

  defp perform_sync(state) do
    healthy_nodes = get_healthy_nodes(state.nodes)

    if length(healthy_nodes) > 1 do
      # Get policies from majority of nodes and reconcile
      reconcile_policies(healthy_nodes, state)
    else
      Logger.warning(
        "Not enough healthy nodes for sync in distributed enforcer #{state.enforcer_name}"
      )

      {:error, :insufficient_nodes}
    end
  end

  defp get_healthy_nodes(nodes) do
    Enum.filter(nodes, fn node ->
      Node.ping(node) == :pong
    end)
  end

  defp reconcile_policies(nodes, state) do
    # Simplified reconciliation: use the node with the most policies as the source of truth
    policies_by_node =
      Enum.map(nodes, fn node ->
        try do
          case :rpc.call(node, GenServer, :call, [state.local_enforcer, :get_policy]) do
            {:badrpc, _} -> {node, []}
            policies -> {node, policies}
          end
        rescue
          _ -> {node, []}
        end
      end)

    # Find the node with the most policies
    {_source_node, source_policies} =
      Enum.max_by(policies_by_node, fn {_node, policies} -> length(policies) end)

    # Update local enforcer with source policies
    GenServer.call(state.local_enforcer, :clear_policy)

    Enum.each(source_policies, fn policy ->
      GenServer.call(state.local_enforcer, {:add_policy, policy})
    end)

    Logger.debug("Synchronized policies for distributed enforcer #{state.enforcer_name}")
    :ok
  end
end
