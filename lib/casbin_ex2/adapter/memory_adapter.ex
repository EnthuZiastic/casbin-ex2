defmodule CasbinEx2.Adapter.MemoryAdapter do
  @moduledoc """
  In-memory adapter for storing policies in process memory.

  This adapter stores policies in memory using ETS tables for fast access.
  It's ideal for testing, caching, and applications that don't require
  persistent policy storage.

  ## Features

  - High-performance in-memory storage
  - Support for filtered policy loading
  - Thread-safe operations using ETS
  - Optional policy change notifications
  - Memory usage monitoring
  - Policy versioning support

  ## Usage

      # Create a new memory adapter
      adapter = CasbinEx2.Adapter.MemoryAdapter.new()

      # Create with custom options
      adapter = CasbinEx2.Adapter.MemoryAdapter.new(
        table_name: :my_policies,
        notifications: true,
        versioning: true
      )

      # Use with enforcer
      enforcer = CasbinEx2.Enforcer.new(model, adapter)
  """

  @behaviour CasbinEx2.Adapter

  defstruct [
    :table_name,
    :notifications,
    :versioning,
    :version,
    :subscribers
  ]

  @type t :: %__MODULE__{
          table_name: atom(),
          notifications: boolean(),
          versioning: boolean(),
          version: non_neg_integer(),
          subscribers: [pid()]
        }

  @doc """
  Creates a new memory adapter.

  ## Options

  - `:table_name` - ETS table name (default: generates unique name)
  - `:notifications` - Enable policy change notifications (default: false)
  - `:versioning` - Enable policy versioning (default: false)
  - `:initial_policies` - Initial policies to load (default: empty)
  - `:initial_grouping_policies` - Initial grouping policies (default: empty)

  ## Examples

      # Basic adapter
      adapter = CasbinEx2.Adapter.MemoryAdapter.new()

      # With custom configuration
      adapter = CasbinEx2.Adapter.MemoryAdapter.new(
        table_name: :my_policies,
        notifications: true,
        versioning: true,
        initial_policies: %{"p" => [["alice", "data1", "read"]]},
        initial_grouping_policies: %{"g" => [["alice", "admin"]]}
      )
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    table_name = Keyword.get(opts, :table_name, generate_table_name())
    notifications = Keyword.get(opts, :notifications, false)
    versioning = Keyword.get(opts, :versioning, false)
    initial_policies = Keyword.get(opts, :initial_policies, %{})
    initial_grouping_policies = Keyword.get(opts, :initial_grouping_policies, %{})

    # Create ETS table with appropriate options
    table_opts = [
      :named_table,
      :public,
      :set,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ]

    :ets.new(table_name, table_opts)

    adapter = %__MODULE__{
      table_name: table_name,
      notifications: notifications,
      versioning: versioning,
      version: 0,
      subscribers: []
    }

    # Load initial policies if provided
    if map_size(initial_policies) > 0 or map_size(initial_grouping_policies) > 0 do
      save_policy(adapter, initial_policies, initial_grouping_policies)
    end

    adapter
  end

  @doc """
  Creates a memory adapter from an existing adapter.

  Loads all policies from the source adapter into memory for fast access.
  """
  @spec from_adapter(CasbinEx2.Adapter.t(), CasbinEx2.Model.t(), keyword()) ::
          {:ok, t()} | {:error, term()}
  def from_adapter(source_adapter, model, opts \\ []) do
    case CasbinEx2.Adapter.load_policy(source_adapter, model) do
      {:ok, policies, grouping_policies} ->
        opts_with_policies =
          opts
          |> Keyword.put(:initial_policies, policies)
          |> Keyword.put(:initial_grouping_policies, grouping_policies)

        adapter = new(opts_with_policies)
        {:ok, adapter}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Subscribes to policy change notifications.

  The calling process will receive messages when policies are modified.
  """
  @spec subscribe(t()) :: t()
  def subscribe(%__MODULE__{notifications: true, subscribers: subscribers} = adapter) do
    if Process.alive?(self()) and self() not in subscribers do
      Process.monitor(self())
      %{adapter | subscribers: [self() | subscribers]}
    else
      adapter
    end
  end

  def subscribe(%__MODULE__{notifications: false}), do: raise("Notifications not enabled")

  @doc """
  Unsubscribes from policy change notifications.
  """
  @spec unsubscribe(t()) :: t()
  def unsubscribe(%__MODULE__{subscribers: subscribers} = adapter) do
    %{adapter | subscribers: List.delete(subscribers, self())}
  end

  @doc """
  Gets current policy version.
  """
  @spec get_version(t()) :: non_neg_integer() | nil
  def get_version(%__MODULE__{versioning: true, version: version}), do: version
  def get_version(%__MODULE__{versioning: false}), do: nil

  @doc """
  Gets memory usage statistics.
  """
  @spec get_memory_stats(t()) :: %{
          table_size: non_neg_integer(),
          memory_bytes: non_neg_integer(),
          policy_count: non_neg_integer(),
          grouping_policy_count: non_neg_integer()
        }
  def get_memory_stats(%__MODULE__{table_name: table_name}) do
    info = :ets.info(table_name)

    {policies, grouping_policies} = get_all_policies(table_name)

    %{
      table_size: Keyword.get(info, :size, 0),
      memory_bytes: Keyword.get(info, :memory, 0) * :erlang.system_info(:wordsize),
      policy_count: count_rules(policies),
      grouping_policy_count: count_rules(grouping_policies)
    }
  end

  @doc """
  Clears all policies from memory.
  """
  @spec clear(t()) :: t()
  def clear(%__MODULE__{table_name: table_name} = adapter) do
    case :ets.info(table_name) do
      :undefined ->
        # Table doesn't exist, nothing to clear
        :ok

      _ ->
        # Table exists, clear it
        :ets.delete_all_objects(table_name)
    end

    updated_adapter = increment_version(adapter)

    # Store updated adapter state for testing
    Process.put(:memory_adapter_state, updated_adapter)

    notify_subscribers(updated_adapter, :policies_cleared, %{})

    updated_adapter
  end

  # Adapter Behaviour Implementation

  @impl CasbinEx2.Adapter
  def load_policy(%__MODULE__{table_name: table_name}, _model) do
    case :ets.info(table_name) do
      :undefined ->
        # Table doesn't exist, return empty policies
        {:ok, %{}, %{}}

      _ ->
        # Table exists, load policies
        {policies, grouping_policies} = get_all_policies(table_name)
        {:ok, policies, grouping_policies}
    end
  end

  @impl CasbinEx2.Adapter
  def load_filtered_policy(%__MODULE__{table_name: table_name}, _model, filter) do
    case :ets.info(table_name) do
      :undefined ->
        # Table doesn't exist, return empty policies
        {:ok, %{}, %{}}

      _ ->
        # Table exists, load and filter policies
        {policies, grouping_policies} = get_all_policies(table_name)

        filtered_policies = apply_filter(policies, filter, :policies)
        filtered_grouping = apply_filter(grouping_policies, filter, :grouping_policies)

        {:ok, filtered_policies, filtered_grouping}
    end
  end

  @impl CasbinEx2.Adapter
  def load_incremental_filtered_policy(%__MODULE__{} = adapter, model, filter) do
    # For memory adapter, incremental is the same as full filtered load
    load_filtered_policy(adapter, model, filter)
  end

  @impl CasbinEx2.Adapter
  def filtered?(%__MODULE__{}), do: true

  @impl CasbinEx2.Adapter
  def save_policy(
        %__MODULE__{table_name: table_name} = adapter,
        policies,
        grouping_policies
      ) do
    # Ensure table exists
    actual_table = ensure_table_exists(table_name)

    # Clear existing policies only if table exists
    case :ets.info(actual_table) do
      :undefined -> :ok
      _ -> :ets.delete_all_objects(actual_table)
    end

    # Store new policies
    store_policies(actual_table, policies, :policy)
    store_policies(actual_table, grouping_policies, :grouping_policy)

    # Update version and notify
    updated_adapter = increment_version(adapter)

    # Store updated adapter state for testing
    Process.put(:memory_adapter_state, updated_adapter)

    notify_subscribers(updated_adapter, :policies_saved, %{
      policy_count: count_rules(policies),
      grouping_policy_count: count_rules(grouping_policies)
    })

    :ok
  end

  @impl CasbinEx2.Adapter
  def add_policy(
        %__MODULE__{table_name: table_name} = adapter,
        sec,
        ptype,
        rule
      ) do
    # Ensure table exists
    actual_table = ensure_table_exists(table_name)

    key = {sec, ptype}
    policy_key = {:policy, key}

    # Use GenServer-style serialized access for thread safety
    # Get the mutex process for this table
    mutex_name = :"#{table_name}_mutex"

    # Ensure mutex exists
    unless Process.whereis(mutex_name) do
      Agent.start_link(fn -> :ok end, name: mutex_name)
    end

    # Perform atomic add within the agent to serialize access
    Agent.get_and_update(mutex_name, fn _state ->
      existing_rules = get_rules(actual_table, key)

      # Check if rule already exists to avoid duplicates
      unless Enum.member?(existing_rules, rule) do
        updated_rules = [rule | existing_rules]
        :ets.insert(actual_table, {policy_key, updated_rules})
      end

      {:ok, :ok}
    end)

    # Update version and notify
    updated_adapter = increment_version(adapter)

    # Store updated adapter state for testing
    Process.put(:memory_adapter_state, updated_adapter)

    notify_subscribers(updated_adapter, :policy_added, %{
      section: sec,
      policy_type: ptype,
      rule: rule
    })

    :ok
  end

  @impl CasbinEx2.Adapter
  def remove_policy(
        %__MODULE__{table_name: table_name} = adapter,
        sec,
        ptype,
        rule
      ) do
    # Ensure table exists
    actual_table = ensure_table_exists(table_name)

    key = {sec, ptype}
    existing_rules = get_rules(actual_table, key)
    updated_rules = List.delete(existing_rules, rule)

    if updated_rules == [] do
      :ets.delete(actual_table, {:policy, key})
    else
      :ets.insert(actual_table, {{:policy, key}, updated_rules})
    end

    # Update version and notify
    updated_adapter = increment_version(adapter)

    # Store updated adapter state for testing
    Process.put(:memory_adapter_state, updated_adapter)

    notify_subscribers(updated_adapter, :policy_removed, %{
      section: sec,
      policy_type: ptype,
      rule: rule
    })

    :ok
  end

  @impl CasbinEx2.Adapter
  def remove_filtered_policy(
        %__MODULE__{table_name: table_name} = adapter,
        sec,
        ptype,
        field_index,
        field_values
      ) do
    # Ensure table exists
    actual_table = ensure_table_exists(table_name)

    key = {sec, ptype}
    existing_rules = get_rules(actual_table, key)

    filtered_rules =
      existing_rules
      |> Enum.reject(fn rule ->
        matches_filter?(rule, field_index, field_values)
      end)

    if filtered_rules == [] do
      :ets.delete(actual_table, {:policy, key})
    else
      :ets.insert(actual_table, {{:policy, key}, filtered_rules})
    end

    # Update version and notify
    removed_count = length(existing_rules) - length(filtered_rules)
    updated_adapter = increment_version(adapter)

    # Store updated adapter state for testing
    Process.put(:memory_adapter_state, updated_adapter)

    notify_subscribers(updated_adapter, :policies_filtered, %{
      section: sec,
      policy_type: ptype,
      field_index: field_index,
      field_values: field_values,
      removed_count: removed_count
    })

    :ok
  end

  # Private functions

  defp ensure_table_exists(table_name) do
    case :ets.info(table_name) do
      :undefined ->
        # Table doesn't exist, create it
        table_opts = [:public, :set, {:read_concurrency, true}, {:write_concurrency, true}]
        created_table = :ets.new(table_name, table_opts)
        created_table

      _ ->
        # Table already exists
        table_name
    end
  end

  defp generate_table_name do
    # Include both unique integer and current process to ensure uniqueness across concurrent tests
    :"casbin_memory_#{:erlang.unique_integer([:positive])}_#{:erlang.pid_to_list(self()) |> List.to_string() |> String.replace(["<", ">", "."], "_")}"
  end

  defp get_all_policies(table_name) do
    # Get all policy entries - the key is {sec, ptype} and value is rules list
    policy_entries =
      table_name
      |> :ets.select([{{{:policy, :"$1"}, :"$2"}, [], [{{:"$1", :"$2"}}]}])

    # Convert to the expected format where keys are just ptype
    policies =
      policy_entries
      |> Enum.reduce(%{}, fn {{_sec, ptype}, rules}, acc ->
        Map.put(acc, ptype, rules)
      end)

    # Get all grouping policy entries
    grouping_entries =
      table_name
      |> :ets.select([{{{:grouping_policy, :"$1"}, :"$2"}, [], [{{:"$1", :"$2"}}]}])

    # Convert to the expected format where keys are just ptype
    grouping_policies =
      grouping_entries
      |> Enum.reduce(%{}, fn {{_sec, ptype}, rules}, acc ->
        Map.put(acc, ptype, rules)
      end)

    {policies, grouping_policies}
  end

  defp store_policies(_table_name, policies, _type) when map_size(policies) == 0, do: :ok

  defp store_policies(table_name, policies, type) do
    entries =
      policies
      |> Enum.map(fn {ptype, rules} ->
        # For policies, sec is typically "p", for grouping policies, sec is typically "g"
        sec =
          case type do
            :policy -> "p"
            :grouping_policy -> "g"
            # default fallback
            _ -> "p"
          end

        {{type, {sec, ptype}}, rules}
      end)

    # Ensure table exists before inserting
    actual_table = ensure_table_exists(table_name)
    :ets.insert(actual_table, entries)
  end

  defp get_rules(table_name, key) do
    case :ets.info(table_name) do
      :undefined ->
        []

      _ ->
        case :ets.lookup(table_name, {:policy, key}) do
          [{_, rules}] -> rules
          [] -> []
        end
    end
  end

  defp apply_filter(policies, filter, _type) when is_nil(filter), do: policies

  defp apply_filter(policies, filter, type) when is_function(filter, 2) do
    policies
    |> Enum.into(%{}, fn {ptype, rules} ->
      filtered_rules = Enum.filter(rules, &filter.(type, &1))
      {ptype, filtered_rules}
    end)
    |> Enum.reject(fn {_ptype, rules} -> Enum.empty?(rules) end)
    |> Enum.into(%{})
  end

  defp apply_filter(policies, filter, _type) when is_map(filter) do
    # Apply map-based filter (implementation depends on filter structure)
    policies
  end

  defp matches_filter?(rule, field_index, field_values) do
    field_values
    |> Enum.with_index()
    |> Enum.all?(fn {value, index} ->
      actual_index = field_index + index

      case Enum.at(rule, actual_index) do
        ^value -> true
        nil -> false
        _other -> false
      end
    end)
  end

  defp count_rules(policies) do
    policies
    |> Map.values()
    |> Enum.map(&length/1)
    |> Enum.sum()
  end

  defp increment_version(%__MODULE__{versioning: true, version: version} = adapter) do
    %{adapter | version: version + 1}
  end

  defp increment_version(%__MODULE__{versioning: false} = adapter), do: adapter

  defp notify_subscribers(%__MODULE__{notifications: false}, _event, _data), do: :ok

  defp notify_subscribers(
         %__MODULE__{notifications: true, subscribers: subscribers, version: version},
         event,
         data
       ) do
    message = {:casbin_policy_change, event, Map.put(data, :version, version)}

    subscribers
    |> Enum.filter(&Process.alive?/1)
    |> Enum.each(&send(&1, message))

    :ok
  end
end
