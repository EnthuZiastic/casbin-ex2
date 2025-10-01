defmodule CasbinEx2.Adapter.BatchAdapter do
  @moduledoc """
  Batch Operations Support for Casbin Adapters.

  Provides batch operations for policy management with atomic transactions,
  performance optimization, and bulk data handling.
  """

  @behaviour CasbinEx2.Adapter

  alias CasbinEx2.Adapter
  alias CasbinEx2.Model

  defstruct [
    :base_adapter,
    :batch_size,
    :enable_transaction,
    :enable_validation,
    :batch_buffer,
    :operation_count,
    :max_retries
  ]

  @type batch_operation ::
          {:add_policy, String.t(), [String.t()]}
          | {:remove_policy, String.t(), [String.t()]}

  @type t :: %__MODULE__{
          base_adapter: Adapter.t(),
          batch_size: pos_integer(),
          enable_transaction: boolean(),
          enable_validation: boolean(),
          batch_buffer: [batch_operation()],
          operation_count: non_neg_integer(),
          max_retries: pos_integer()
        }

  @doc """
  Creates a new batch adapter wrapping a base adapter.

  ## Examples

      adapter = BatchAdapter.new(FileAdapter.new("policy.csv"))
      adapter = BatchAdapter.new(base_adapter, batch_size: 100, enable_transaction: true)

  """
  @spec new(Adapter.t(), keyword()) :: t()
  def new(base_adapter, opts \\ []) do
    %__MODULE__{
      base_adapter: base_adapter,
      batch_size: Keyword.get(opts, :batch_size, 50),
      enable_transaction: Keyword.get(opts, :enable_transaction, true),
      enable_validation: Keyword.get(opts, :enable_validation, true),
      batch_buffer: [],
      operation_count: 0,
      max_retries: Keyword.get(opts, :max_retries, 3)
    }
  end

  @doc """
  Adds multiple policies in a single batch operation.

  ## Examples

      {:ok, adapter} = BatchAdapter.add_policies(adapter, "p", [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"]
      ])

  """
  @spec add_policies(t(), String.t(), [[String.t()]]) :: {:ok, t()} | {:error, term()}
  def add_policies(%__MODULE__{} = adapter, ptype, policies) when is_list(policies) do
    if adapter.enable_validation do
      case validate_policies(policies) do
        :ok ->
          execute_batch_add_policies(adapter, ptype, policies)

        {:error, reason} ->
          {:error, {:validation_failed, reason}}
      end
    else
      execute_batch_add_policies(adapter, ptype, policies)
    end
  end

  @doc """
  Removes multiple policies in a single batch operation.

  ## Examples

      {:ok, adapter} = BatchAdapter.remove_policies(adapter, "p", [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"]
      ])

  """
  @spec remove_policies(t(), String.t(), [[String.t()]]) :: {:ok, t()} | {:error, term()}
  def remove_policies(%__MODULE__{} = adapter, ptype, policies) when is_list(policies) do
    if adapter.enable_validation do
      case validate_policies(policies) do
        :ok ->
          execute_batch_remove_policies(adapter, ptype, policies)

        {:error, reason} ->
          {:error, {:validation_failed, reason}}
      end
    else
      execute_batch_remove_policies(adapter, ptype, policies)
    end
  end

  @doc """
  Removes policies matching a filter in batch.

  ## Examples

      {:ok, adapter} = BatchAdapter.remove_filtered_policies(adapter, "p", 0, ["alice"])

  """
  @spec remove_filtered_policies(t(), String.t(), integer(), [String.t()]) ::
          {:ok, t()} | {:error, term()}
  def remove_filtered_policies(
        %__MODULE__{base_adapter: base_adapter} = adapter,
        ptype,
        field_index,
        field_values
      ) do
    case try_with_retries(adapter.max_retries, fn ->
           remove_filtered_with_fallback(base_adapter, ptype, field_index, field_values)
         end) do
      {:ok, updated_base_adapter} ->
        {:ok, %{adapter | base_adapter: updated_base_adapter}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Executes multiple operations as a batch.

  ## Examples

      operations = [
        {:add_policy, "p", ["charlie", "data3", "read"]},
        {:remove_policy, "p", ["alice", "data1", "read"]}
      ]
      {:ok, adapter} = BatchAdapter.execute_batch(adapter, operations)

  """
  @spec execute_batch(t(), [batch_operation()]) :: {:ok, t()} | {:error, term()}
  def execute_batch(%__MODULE__{} = adapter, operations) when is_list(operations) do
    if adapter.enable_transaction do
      execute_transactional_batch(adapter, operations)
    else
      execute_sequential_batch(adapter, operations)
    end
  end

  @doc """
  Gets batch operation statistics.

  ## Examples

      stats = BatchAdapter.get_stats(adapter)

  """
  @spec get_stats(t()) :: map()
  def get_stats(%__MODULE__{} = adapter) do
    %{
      operation_count: adapter.operation_count,
      batch_size: adapter.batch_size,
      buffer_size: length(adapter.batch_buffer),
      enable_transaction: adapter.enable_transaction,
      enable_validation: adapter.enable_validation,
      max_retries: adapter.max_retries
    }
  end

  @doc """
  Flushes any buffered operations.

  ## Examples

      {:ok, adapter} = BatchAdapter.flush(adapter)

  """
  @spec flush(t()) :: {:ok, t()} | {:error, term()}
  def flush(%__MODULE__{batch_buffer: []} = adapter), do: {:ok, adapter}

  def flush(%__MODULE__{batch_buffer: operations} = adapter) do
    case execute_batch(adapter, Enum.reverse(operations)) do
      {:ok, updated_adapter} ->
        {:ok, %{updated_adapter | batch_buffer: []}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Configures batch processing options.

  ## Examples

      adapter = BatchAdapter.configure(adapter,
        batch_size: 100,
        enable_transaction: false,
        enable_validation: true
      )

  """
  @spec configure(t(), keyword()) :: t()
  def configure(%__MODULE__{} = adapter, opts) do
    %{
      adapter
      | batch_size: Keyword.get(opts, :batch_size, adapter.batch_size),
        enable_transaction: Keyword.get(opts, :enable_transaction, adapter.enable_transaction),
        enable_validation: Keyword.get(opts, :enable_validation, adapter.enable_validation),
        max_retries: Keyword.get(opts, :max_retries, adapter.max_retries)
    }
  end

  # Adapter behaviour implementation

  @impl true
  def load_policy(%__MODULE__{base_adapter: base_adapter}, model) do
    Adapter.load_policy(base_adapter, model)
  end

  @impl true
  def save_policy(%__MODULE__{base_adapter: base_adapter}, policies, grouping_policies) do
    Adapter.save_policy(base_adapter, policies, grouping_policies)
  end

  @impl true
  def add_policy(%__MODULE__{base_adapter: base_adapter} = adapter, sec, ptype, params) do
    case base_adapter.__struct__.add_policy(base_adapter, sec, ptype, params) do
      :ok ->
        {:ok, %{adapter | operation_count: adapter.operation_count + 1}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def remove_policy(%__MODULE__{base_adapter: base_adapter} = adapter, sec, ptype, params) do
    case base_adapter.__struct__.remove_policy(base_adapter, sec, ptype, params) do
      :ok ->
        {:ok, %{adapter | operation_count: adapter.operation_count + 1}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Removes filtered policy rules.
  """
  @impl true
  def remove_filtered_policy(
        %__MODULE__{base_adapter: base_adapter} = adapter,
        sec,
        ptype,
        field_index,
        field_values
      ) do
    case base_adapter.__struct__.remove_filtered_policy(
           base_adapter,
           sec,
           ptype,
           field_index,
           field_values
         ) do
      :ok ->
        {:ok, %{adapter | operation_count: adapter.operation_count + 1}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks if filtered loading is supported.
  """
  @impl true
  def filtered?(%__MODULE__{base_adapter: base_adapter}) do
    if function_exported?(base_adapter.__struct__, :filtered?, 1) do
      base_adapter.__struct__.filtered?(base_adapter)
    else
      false
    end
  end

  @doc """
  Loads filtered policies.
  """
  @impl true
  def load_filtered_policy(%__MODULE__{base_adapter: base_adapter}, model, filter) do
    base_adapter.__struct__.load_filtered_policy(base_adapter, model, filter)
  end

  @doc """
  Loads incremental filtered policies.
  """
  @impl true
  def load_incremental_filtered_policy(%__MODULE__{base_adapter: base_adapter}, model, filter) do
    base_adapter.__struct__.load_incremental_filtered_policy(base_adapter, model, filter)
  end

  # Private functions

  defp execute_batch_add_policies(%__MODULE__{} = adapter, ptype, policies) do
    batches = Enum.chunk_every(policies, adapter.batch_size)
    process_batches(batches, adapter, ptype, &execute_single_batch_add/3)
  end

  defp execute_batch_remove_policies(%__MODULE__{} = adapter, ptype, policies) do
    batches = Enum.chunk_every(policies, adapter.batch_size)
    process_batches(batches, adapter, ptype, &execute_single_batch_remove/3)
  end

  defp process_batches(batches, adapter, ptype, batch_executor) do
    Enum.reduce_while(batches, {:ok, adapter}, fn batch, {:ok, acc_adapter} ->
      process_single_batch(batch, acc_adapter, ptype, batch_executor, adapter.max_retries)
    end)
  end

  defp process_single_batch(batch, acc_adapter, ptype, batch_executor, max_retries) do
    case try_with_retries(max_retries, fn ->
           batch_executor.(acc_adapter.base_adapter, ptype, batch)
         end) do
      {:ok, updated_base_adapter} ->
        updated_adapter = %{
          acc_adapter
          | base_adapter: updated_base_adapter,
            operation_count: acc_adapter.operation_count + length(batch)
        }

        {:cont, {:ok, updated_adapter}}

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp execute_single_batch_add(base_adapter, ptype, batch) do
    # Check if base adapter supports batch operations
    if function_exported?(base_adapter.__struct__, :add_policies, 3) do
      batch_add_policies(base_adapter, ptype, batch)
    else
      # Fallback: execute one by one
      add_policies_one_by_one(base_adapter, ptype, batch)
    end
  end

  defp execute_single_batch_remove(base_adapter, ptype, batch) do
    # Check if base adapter supports batch operations
    if function_exported?(base_adapter.__struct__, :remove_policies, 3) do
      batch_remove_policies(base_adapter, ptype, batch)
    else
      # Fallback: execute one by one
      remove_policies_one_by_one(base_adapter, ptype, batch)
    end
  end

  defp execute_transactional_batch(%__MODULE__{base_adapter: base_adapter} = adapter, operations) do
    # If base adapter supports transactions, use them
    if function_exported?(base_adapter.__struct__, :execute_transaction, 2) do
      execute_with_transaction(adapter, base_adapter, operations)
    else
      # Fallback: execute sequentially (not truly transactional)
      execute_sequential_batch(adapter, operations)
    end
  end

  defp execute_sequential_batch(%__MODULE__{} = adapter, operations) do
    Enum.reduce_while(operations, {:ok, adapter}, fn operation, {:ok, acc_adapter} ->
      case execute_single_operation(acc_adapter, operation) do
        {:ok, updated_adapter} -> {:cont, {:ok, updated_adapter}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp execute_single_operation(adapter, operation) do
    case operation do
      {:add_policy, ptype, params} ->
        add_policy(adapter, "p", ptype, params)

      {:remove_policy, ptype, params} ->
        remove_policy(adapter, "p", ptype, params)

      {:add_grouping_policy, _ptype, _params} ->
        {:error, :grouping_policy_not_supported}

      {:remove_grouping_policy, _ptype, _params} ->
        {:error, :grouping_policy_not_supported}

      _ ->
        {:error, {:unsupported_operation, operation}}
    end
  end

  defp validate_policies(policies) do
    case Enum.find(policies, &(!is_list(&1) or Enum.empty?(&1))) do
      nil -> :ok
      invalid_policy -> {:error, {:invalid_policy, invalid_policy}}
    end
  end

  defp fallback_remove_filtered_policies(base_adapter, ptype, field_index, field_values) do
    # This is a simplified fallback - in a real implementation,
    # you would load the current policies, filter them, and save the result
    with {:ok, policies, grouping_policies} <- Adapter.load_policy(base_adapter, %Model{}),
         current_policies <- Map.get(policies, ptype, []),
         filtered_policies <- filter_policies(current_policies, field_index, field_values),
         updated_policies <- Map.put(policies, ptype, filtered_policies),
         :ok <- Adapter.save_policy(base_adapter, updated_policies, grouping_policies) do
      {:ok, base_adapter}
    end
  end

  defp filter_policies(policies, field_index, field_values) do
    Enum.reject(policies, fn policy ->
      policy_matches_filter?(policy, field_index, field_values)
    end)
  end

  defp policy_matches_filter?(policy, field_index, field_values) do
    field_values
    |> Enum.with_index()
    |> Enum.all?(fn {value, offset} ->
      field_matches_value?(policy, field_index + offset, value)
    end)
  end

  defp field_matches_value?(policy, field_index, value) do
    case Enum.at(policy, field_index) do
      ^value -> true
      _ -> false
    end
  end

  defp remove_filtered_with_fallback(base_adapter, ptype, field_index, field_values) do
    if function_exported?(base_adapter.__struct__, :remove_filtered_policies, 4) do
      case base_adapter.__struct__.remove_filtered_policies(
             base_adapter,
             ptype,
             field_index,
             field_values
           ) do
        :ok -> {:ok, base_adapter}
        {:ok, _} = result -> result
        {:error, _} = error -> error
      end
    else
      # Fallback: load policies, filter, and save
      fallback_remove_filtered_policies(base_adapter, ptype, field_index, field_values)
    end
  end

  defp batch_add_policies(base_adapter, ptype, batch) do
    base_adapter.__struct__.add_policies(base_adapter, ptype, batch)
  end

  defp add_policies_one_by_one(base_adapter, ptype, batch) do
    Enum.reduce_while(batch, {:ok, base_adapter}, fn policy, {:ok, acc_adapter} ->
      case acc_adapter.__struct__.add_policy(acc_adapter, "p", ptype, policy) do
        :ok -> {:cont, {:ok, acc_adapter}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp batch_remove_policies(base_adapter, ptype, batch) do
    base_adapter.__struct__.remove_policies(base_adapter, ptype, batch)
  end

  defp remove_policies_one_by_one(base_adapter, ptype, batch) do
    Enum.reduce_while(batch, {:ok, base_adapter}, fn policy, {:ok, acc_adapter} ->
      case acc_adapter.__struct__.remove_policy(acc_adapter, "p", ptype, policy) do
        :ok -> {:cont, {:ok, acc_adapter}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp execute_with_transaction(adapter, base_adapter, operations) do
    case base_adapter.__struct__.execute_transaction(base_adapter, operations) do
      {:ok, updated_base_adapter} ->
        {:ok,
         %{
           adapter
           | base_adapter: updated_base_adapter,
             operation_count: adapter.operation_count + length(operations)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp try_with_retries(0, _fun), do: {:error, :max_retries_exceeded}

  defp try_with_retries(retries, fun) do
    case fun.() do
      {:ok, result} ->
        {:ok, result}

      {:error, _reason} when retries > 1 ->
        # Exponential backoff
        Process.sleep(100 * (4 - retries))
        try_with_retries(retries - 1, fun)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
