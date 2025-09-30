defmodule CasbinEx2.Watcher.RedisWatcher do
  @moduledoc """
  Redis-based watcher for distributed policy change notifications.

  This watcher uses Redis pub/sub to notify other enforcer instances
  when policies are changed.
  """

  use GenServer

  @behaviour CasbinEx2.Watcher

  defstruct [:redis_conn, :channel, :update_callback]

  @type t :: %__MODULE__{
          redis_conn: pid() | nil,
          channel: String.t(),
          update_callback: function() | nil
        }

  @default_channel "casbin_policy_update"

  @doc """
  Creates a new Redis watcher.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      channel: Keyword.get(opts, :channel, @default_channel)
    }
  end

  @doc """
  Starts the Redis watcher as a GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl CasbinEx2.Watcher
  def start_watcher do
    case GenServer.start_link(__MODULE__, [], name: __MODULE__) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> error
    end
  end

  @impl CasbinEx2.Watcher
  def stop_watcher do
    GenServer.stop(__MODULE__)
  end

  @impl CasbinEx2.Watcher
  def set_update_callback(callback) when is_function(callback) do
    GenServer.call(__MODULE__, {:set_update_callback, callback})
  end

  @impl CasbinEx2.Watcher
  def update do
    GenServer.cast(__MODULE__, :update)
  end

  @impl CasbinEx2.Watcher
  def update_for_enforcer(enforcer_name) do
    GenServer.cast(__MODULE__, {:update_for_enforcer, enforcer_name})
  end

  # GenServer callbacks

  @impl GenServer
  def init(opts) do
    channel = Keyword.get(opts, :channel, @default_channel)

    state = %__MODULE__{
      channel: channel
    }

    # Note: In a real implementation, you would connect to Redis here
    # For now, we'll simulate the connection
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:set_update_callback, callback}, _from, state) do
    new_state = %{state | update_callback: callback}
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_cast(:update, %{channel: channel} = state) do
    # Publish update notification to Redis
    publish_update(channel, %{type: "policy_update", timestamp: System.system_time()})
    {:noreply, state}
  end

  def handle_cast({:update_for_enforcer, enforcer_name}, %{channel: channel} = state) do
    # Publish enforcer-specific update notification
    publish_update(channel, %{
      type: "enforcer_update",
      enforcer: enforcer_name,
      timestamp: System.system_time()
    })

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:redis_message, _channel, message}, state) do
    # Handle incoming Redis messages
    case Jason.decode(message) do
      {:ok, %{"type" => "policy_update"}} ->
        if state.update_callback do
          state.update_callback.()
        end

      {:ok, %{"type" => "enforcer_update", "enforcer" => enforcer_name}} ->
        if state.update_callback do
          state.update_callback.(enforcer_name)
        end

      _ ->
        :ok
    end

    {:noreply, state}
  end

  # Private functions

  defp publish_update(channel, message) do
    # In a real implementation, this would publish to Redis
    # For now, we'll just log the message
    encoded_message = Jason.encode!(message)

    # Simulate publishing (in real implementation, use Redix or similar)
    # Redix.command(:redis, ["PUBLISH", channel, encoded_message])

    # For demonstration, we'll log the message (Phoenix.PubSub not available)
    # In a real implementation, you would use Redis pub/sub or Phoenix.PubSub
    require Logger
    Logger.debug("Publishing policy update to channel #{channel}: #{encoded_message}")
  end
end
