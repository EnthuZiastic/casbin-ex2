defmodule CasbinEx2.Logger do
  @moduledoc """
  Enhanced logging system for Casbin operations.

  Provides configurable logging for enforcement decisions, policy changes,
  and system events. Essential for debugging and audit trails.
  """

  use GenServer
  require Logger

  defstruct [
    :enabled,
    :level,
    :output,
    :format,
    :filters,
    :buffer,
    :buffer_size,
    :flush_interval
  ]

  @type log_level :: :debug | :info | :warn | :error
  @type output_type :: :console | :file | :custom
  @type log_entry :: %{
          timestamp: DateTime.t(),
          level: log_level(),
          event_type: atom(),
          message: String.t(),
          metadata: map()
        }

  @type t :: %__MODULE__{
          enabled: boolean(),
          level: log_level(),
          output: output_type(),
          format: atom(),
          filters: [atom()],
          buffer: [log_entry()],
          buffer_size: pos_integer(),
          flush_interval: pos_integer()
        }

  @default_config %{
    enabled: false,
    level: :warn,
    output: :console,
    format: :standard,
    filters: [],
    buffer: [],
    buffer_size: 100,
    flush_interval: 5000
  }

  @doc """
  Starts the logger GenServer.

  ## Examples

      {:ok, pid} = CasbinLogger.start_link()

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Enables logging with optional configuration.

  ## Examples

      :ok = CasbinLogger.enable_log()
      :ok = CasbinLogger.enable_log(level: :debug, output: :file)

  """
  @spec enable_log(keyword()) :: :ok
  def enable_log(opts \\ []) do
    GenServer.call(__MODULE__, {:enable, opts})
  end

  @doc """
  Disables logging.

  ## Examples

      :ok = CasbinLogger.disable_log()

  """
  @spec disable_log() :: :ok
  def disable_log do
    GenServer.call(__MODULE__, :disable)
  end

  @doc """
  Sets the log level.

  ## Examples

      :ok = CasbinLogger.set_log_level(:debug)

  """
  @spec set_log_level(log_level()) :: :ok
  def set_log_level(level) when level in [:debug, :info, :warn, :error] do
    GenServer.call(__MODULE__, {:set_level, level})
  end

  @doc """
  Sets the output type.

  ## Examples

      :ok = CasbinLogger.set_output(:file)

  """
  @spec set_output(output_type()) :: :ok
  def set_output(output) when output in [:console, :file, :custom] do
    GenServer.call(__MODULE__, {:set_output, output})
  end

  @doc """
  Adds a filter for event types.

  ## Examples

      :ok = CasbinLogger.add_filter(:enforcement)

  """
  @spec add_filter(atom()) :: :ok
  def add_filter(event_type) when is_atom(event_type) do
    GenServer.call(__MODULE__, {:add_filter, event_type})
  end

  @doc """
  Removes a filter for event types.

  ## Examples

      :ok = CasbinLogger.remove_filter(:enforcement)

  """
  @spec remove_filter(atom()) :: :ok
  def remove_filter(event_type) when is_atom(event_type) do
    GenServer.call(__MODULE__, {:remove_filter, event_type})
  end

  @doc """
  Logs an enforcement decision.

  ## Examples

      :ok = CasbinLogger.log_enforcement(["alice", "data1", "read"], true, "Direct policy match")

  """
  @spec log_enforcement([String.t()], boolean(), String.t(), map()) :: :ok
  def log_enforcement(request, result, explanation, metadata \\ %{}) do
    log_event(:enforcement, :warn, "Enforcement: #{inspect(request)} -> #{result}", %{
      request: request,
      result: result,
      explanation: explanation,
      metadata: metadata
    })
  end

  @doc """
  Logs a policy change.

  ## Examples

      :ok = CasbinLogger.log_policy_change(:add, "p", ["alice", "data1", "read"])

  """
  @spec log_policy_change(atom(), String.t(), [String.t()], map()) :: :ok
  def log_policy_change(action, ptype, params, metadata \\ %{}) do
    log_event(:policy_change, :warn, "Policy #{action}: #{ptype} #{inspect(params)}", %{
      action: action,
      ptype: ptype,
      params: params,
      metadata: metadata
    })
  end

  @doc """
  Logs a role management operation.

  ## Examples

      :ok = CasbinLogger.log_role_operation(:add_link, "alice", "admin", "")

  """
  @spec log_role_operation(atom(), String.t(), String.t(), String.t(), map()) :: :ok
  def log_role_operation(operation, user, role, domain, metadata \\ %{}) do
    log_event(:role_management, :warn, "Role #{operation}: #{user} -> #{role} (#{domain})", %{
      operation: operation,
      user: user,
      role: role,
      domain: domain,
      metadata: metadata
    })
  end

  @doc """
  Logs an adapter operation.

  ## Examples

      :ok = CasbinLogger.log_adapter_operation(:load_policy, :success, 150)

  """
  @spec log_adapter_operation(atom(), atom(), any(), map()) :: :ok
  def log_adapter_operation(operation, status, result, metadata \\ %{}) do
    log_event(:adapter, :warn, "Adapter #{operation}: #{status} - #{inspect(result)}", %{
      operation: operation,
      status: status,
      result: result,
      metadata: metadata
    })
  end

  @doc """
  Logs a watcher event.

  ## Examples

      :ok = CasbinLogger.log_watcher_event(:policy_update, "Policy updated from external source")

  """
  @spec log_watcher_event(atom(), String.t(), map()) :: :ok
  def log_watcher_event(event_type, message, metadata \\ %{}) do
    log_event(:watcher, :warn, "Watcher #{event_type}: #{message}", %{
      event_type: event_type,
      message: message,
      metadata: metadata
    })
  end

  @doc """
  Logs an error event.

  ## Examples

      :ok = CasbinLogger.log_error(:enforcement_error, "Invalid policy format", %{policy: ["alice"]})

  """
  @spec log_error(atom(), String.t(), map()) :: :ok
  def log_error(error_type, message, metadata \\ %{}) do
    log_event(:error, :error, "Error #{error_type}: #{message}", %{
      error_type: error_type,
      message: message,
      metadata: metadata
    })
  end

  @doc """
  Logs a performance metric.

  ## Examples

      :ok = CasbinLogger.log_performance(:enforcement, 1500, %{request_count: 100})

  """
  @spec log_performance(atom(), non_neg_integer(), map()) :: :ok
  def log_performance(operation, duration_us, metadata \\ %{}) do
    log_event(:performance, :debug, "Performance #{operation}: #{duration_us}μs", %{
      operation: operation,
      duration_us: duration_us,
      metadata: metadata
    })
  end

  @doc """
  Gets the current logger configuration.

  ## Examples

      config = CasbinLogger.get_config()

  """
  @spec get_config() :: t()
  def get_config do
    GenServer.call(__MODULE__, :get_config)
  end

  @doc """
  Gets recent log entries from the buffer.

  ## Examples

      entries = CasbinLogger.get_recent_logs(10)

  """
  @spec get_recent_logs(pos_integer()) :: [log_entry()]
  def get_recent_logs(count \\ 50) do
    GenServer.call(__MODULE__, {:get_recent_logs, count})
  end

  @doc """
  Flushes the log buffer immediately.

  ## Examples

      :ok = CasbinLogger.flush()

  """
  @spec flush() :: :ok
  def flush do
    GenServer.call(__MODULE__, :flush)
  end

  @doc """
  Clears the log buffer.

  ## Examples

      :ok = CasbinLogger.clear_buffer()

  """
  @spec clear_buffer() :: :ok
  def clear_buffer do
    GenServer.call(__MODULE__, :clear_buffer)
  end

  # GenServer Callbacks

  @impl true
  def init(opts) do
    config = struct(__MODULE__, Map.merge(@default_config, Enum.into(opts, %{})))
    schedule_flush(config.flush_interval)
    {:ok, config}
  end

  @impl true
  def handle_call({:enable, opts}, _from, state) do
    opts_map = Enum.into(opts, %{enabled: true})
    new_config = struct(state, opts_map)
    {:reply, :ok, new_config}
  end

  def handle_call(:disable, _from, state) do
    new_config = %{state | enabled: false}
    {:reply, :ok, new_config}
  end

  def handle_call({:set_level, level}, _from, state) do
    new_config = %{state | level: level}
    {:reply, :ok, new_config}
  end

  def handle_call({:set_output, output}, _from, state) do
    new_config = %{state | output: output}
    {:reply, :ok, new_config}
  end

  def handle_call({:add_filter, event_type}, _from, state) do
    new_filters = [event_type | state.filters] |> Enum.uniq()
    new_config = %{state | filters: new_filters}
    {:reply, :ok, new_config}
  end

  def handle_call({:remove_filter, event_type}, _from, state) do
    new_filters = List.delete(state.filters, event_type)
    new_config = %{state | filters: new_filters}
    {:reply, :ok, new_config}
  end

  def handle_call(:get_config, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:get_recent_logs, count}, _from, state) do
    recent_logs = Enum.take(state.buffer, count)
    {:reply, recent_logs, state}
  end

  def handle_call(:flush, _from, state) do
    flush_buffer(state)
    new_state = %{state | buffer: []}
    {:reply, :ok, new_state}
  end

  def handle_call(:clear_buffer, _from, state) do
    new_state = %{state | buffer: []}
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:log, entry}, state) do
    if should_log?(entry, state) do
      new_buffer = add_to_buffer(entry, state.buffer, state.buffer_size)
      new_state = %{state | buffer: new_buffer}
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:flush_timer, state) do
    flush_buffer(state)
    schedule_flush(state.flush_interval)
    new_state = %{state | buffer: []}
    {:noreply, new_state}
  end

  # Private functions

  defp log_event(event_type, level, message, metadata) do
    entry = %{
      timestamp: DateTime.utc_now(),
      level: level,
      event_type: event_type,
      message: message,
      metadata: metadata
    }

    GenServer.cast(__MODULE__, {:log, entry})
  end

  defp should_log?(entry, state) do
    state.enabled and
      level_enabled?(entry.level, state.level) and
      filter_enabled?(entry.event_type, state.filters)
  end

  defp level_enabled?(entry_level, config_level) do
    level_priority(entry_level) >= level_priority(config_level)
  end

  defp level_priority(:debug), do: 0
  defp level_priority(:info), do: 1
  defp level_priority(:warn), do: 2
  defp level_priority(:error), do: 3

  defp filter_enabled?(_event_type, []), do: true
  defp filter_enabled?(event_type, filters), do: event_type in filters

  defp add_to_buffer(entry, buffer, max_size) do
    new_buffer = [entry | buffer]

    if length(new_buffer) > max_size do
      Enum.take(new_buffer, max_size)
    else
      new_buffer
    end
  end

  defp flush_buffer(%{buffer: buffer, output: output, format: format}) do
    if length(buffer) > 0 do
      Enum.each(buffer, &output_entry(&1, output, format))
    end
  end

  defp output_entry(entry, :console, format) do
    formatted_message = format_entry(entry, format)
    IO.puts(formatted_message)
  end

  defp output_entry(entry, :file, format) do
    formatted_message = format_entry(entry, format)
    # In a real implementation, you'd write to a file
    # For now, we'll use Logger
    Logger.log(entry.level, formatted_message)
  end

  defp output_entry(entry, :custom, format) do
    formatted_message = format_entry(entry, format)
    Logger.log(entry.level, formatted_message)
  end

  defp format_entry(entry, :standard) do
    timestamp = DateTime.to_iso8601(entry.timestamp)
    level = String.upcase(to_string(entry.level))
    "[#{timestamp}] #{level} [#{entry.event_type}] #{entry.message}"
  end

  defp format_entry(entry, :detailed) do
    timestamp = DateTime.to_iso8601(entry.timestamp)
    level = String.upcase(to_string(entry.level))
    metadata_str = inspect(entry.metadata, pretty: true)
    "[#{timestamp}] #{level} [#{entry.event_type}] #{entry.message}\nMetadata: #{metadata_str}"
  end

  defp format_entry(entry, :json) do
    Jason.encode!(%{
      timestamp: DateTime.to_iso8601(entry.timestamp),
      level: entry.level,
      event_type: entry.event_type,
      message: entry.message,
      metadata: entry.metadata
    })
  end

  defp schedule_flush(interval) do
    Process.send_after(self(), :flush_timer, interval)
  end
end
