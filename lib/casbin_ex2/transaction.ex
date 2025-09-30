defmodule CasbinEx2.Transaction do
  @moduledoc """
  Transaction support for Casbin operations.

  Provides atomic operations for multiple policy changes with rollback capability.
  Essential for enterprise use cases where policy changes must be applied atomically.
  """

  alias CasbinEx2.Enforcer

  defstruct [
    :enforcer,
    :operations,
    :original_state,
    :id,
    :started_at,
    :status
  ]

  @type operation ::
          {:add_policy, String.t(), [String.t()]}
          | {:remove_policy, String.t(), [String.t()]}
          | {:add_grouping_policy, String.t(), [String.t()]}
          | {:remove_grouping_policy, String.t(), [String.t()]}
          | {:add_policies, String.t(), [[String.t()]]}
          | {:remove_policies, String.t(), [[String.t()]]}
          | {:update_policy, String.t(), [String.t()], [String.t()]}
          | {:update_grouping_policy, String.t(), [String.t()], [String.t()]}

  @type t :: %__MODULE__{
          enforcer: Enforcer.t(),
          operations: [operation()],
          original_state: map(),
          id: String.t(),
          started_at: DateTime.t(),
          status: :active | :committed | :aborted
        }

  @doc """
  Creates a new transaction for the given enforcer.

  ## Examples

      {:ok, transaction} = Transaction.new(enforcer)

  """
  @spec new(Enforcer.t()) :: {:ok, t()}
  def new(%Enforcer{} = enforcer) do
    transaction = %__MODULE__{
      enforcer: enforcer,
      operations: [],
      original_state: capture_state(enforcer),
      id: generate_transaction_id(),
      started_at: DateTime.utc_now(),
      status: :active
    }

    {:ok, transaction}
  end

  @doc """
  Adds a policy operation to the transaction.

  ## Examples

      {:ok, transaction} = Transaction.add_policy(transaction, "p", ["alice", "data1", "read"])

  """
  @spec add_policy(t(), String.t(), [String.t()]) :: {:ok, t()} | {:error, term()}
  def add_policy(%__MODULE__{status: :active} = transaction, ptype, params) do
    operation = {:add_policy, ptype, params}
    updated_transaction = %{transaction | operations: [operation | transaction.operations]}
    {:ok, updated_transaction}
  end

  def add_policy(%__MODULE__{status: status}, _ptype, _params) do
    {:error, {:invalid_status, status}}
  end

  @doc """
  Adds a remove policy operation to the transaction.

  ## Examples

      {:ok, transaction} = Transaction.remove_policy(transaction, "p", ["alice", "data1", "read"])

  """
  @spec remove_policy(t(), String.t(), [String.t()]) :: {:ok, t()} | {:error, term()}
  def remove_policy(%__MODULE__{status: :active} = transaction, ptype, params) do
    operation = {:remove_policy, ptype, params}
    updated_transaction = %{transaction | operations: [operation | transaction.operations]}
    {:ok, updated_transaction}
  end

  def remove_policy(%__MODULE__{status: status}, _ptype, _params) do
    {:error, {:invalid_status, status}}
  end

  @doc """
  Adds a grouping policy operation to the transaction.

  ## Examples

      {:ok, transaction} = Transaction.add_grouping_policy(transaction, "g", ["alice", "admin"])

  """
  @spec add_grouping_policy(t(), String.t(), [String.t()]) :: {:ok, t()} | {:error, term()}
  def add_grouping_policy(%__MODULE__{status: :active} = transaction, ptype, params) do
    operation = {:add_grouping_policy, ptype, params}
    updated_transaction = %{transaction | operations: [operation | transaction.operations]}
    {:ok, updated_transaction}
  end

  def add_grouping_policy(%__MODULE__{status: status}, _ptype, _params) do
    {:error, {:invalid_status, status}}
  end

  @doc """
  Adds a remove grouping policy operation to the transaction.

  ## Examples

      {:ok, transaction} = Transaction.remove_grouping_policy(transaction, "g", ["alice", "admin"])

  """
  @spec remove_grouping_policy(t(), String.t(), [String.t()]) :: {:ok, t()} | {:error, term()}
  def remove_grouping_policy(%__MODULE__{status: :active} = transaction, ptype, params) do
    operation = {:remove_grouping_policy, ptype, params}
    updated_transaction = %{transaction | operations: [operation | transaction.operations]}
    {:ok, updated_transaction}
  end

  def remove_grouping_policy(%__MODULE__{status: status}, _ptype, _params) do
    {:error, {:invalid_status, status}}
  end

  @doc """
  Adds multiple policy operations to the transaction.

  ## Examples

      {:ok, transaction} = Transaction.add_policies(transaction, "p", [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"]
      ])

  """
  @spec add_policies(t(), String.t(), [[String.t()]]) :: {:ok, t()} | {:error, term()}
  def add_policies(%__MODULE__{status: :active} = transaction, ptype, rules) do
    operation = {:add_policies, ptype, rules}
    updated_transaction = %{transaction | operations: [operation | transaction.operations]}
    {:ok, updated_transaction}
  end

  def add_policies(%__MODULE__{status: status}, _ptype, _rules) do
    {:error, {:invalid_status, status}}
  end

  @doc """
  Adds multiple remove policy operations to the transaction.

  ## Examples

      {:ok, transaction} = Transaction.remove_policies(transaction, "p", [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"]
      ])

  """
  @spec remove_policies(t(), String.t(), [[String.t()]]) :: {:ok, t()} | {:error, term()}
  def remove_policies(%__MODULE__{status: :active} = transaction, ptype, rules) do
    operation = {:remove_policies, ptype, rules}
    updated_transaction = %{transaction | operations: [operation | transaction.operations]}
    {:ok, updated_transaction}
  end

  def remove_policies(%__MODULE__{status: status}, _ptype, _rules) do
    {:error, {:invalid_status, status}}
  end

  @doc """
  Adds an update policy operation to the transaction.

  ## Examples

      {:ok, transaction} = Transaction.update_policy(transaction, "p",
        ["alice", "data1", "read"], ["alice", "data1", "write"])

  """
  @spec update_policy(t(), String.t(), [String.t()], [String.t()]) ::
          {:ok, t()} | {:error, term()}
  def update_policy(%__MODULE__{status: :active} = transaction, ptype, old_policy, new_policy) do
    operation = {:update_policy, ptype, old_policy, new_policy}
    updated_transaction = %{transaction | operations: [operation | transaction.operations]}
    {:ok, updated_transaction}
  end

  def update_policy(%__MODULE__{status: status}, _ptype, _old_policy, _new_policy) do
    {:error, {:invalid_status, status}}
  end

  @doc """
  Adds an update grouping policy operation to the transaction.

  ## Examples

      {:ok, transaction} = Transaction.update_grouping_policy(transaction, "g",
        ["alice", "admin"], ["alice", "super_admin"])

  """
  @spec update_grouping_policy(t(), String.t(), [String.t()], [String.t()]) ::
          {:ok, t()} | {:error, term()}
  def update_grouping_policy(
        %__MODULE__{status: :active} = transaction,
        ptype,
        old_rule,
        new_rule
      ) do
    operation = {:update_grouping_policy, ptype, old_rule, new_rule}
    updated_transaction = %{transaction | operations: [operation | transaction.operations]}
    {:ok, updated_transaction}
  end

  def update_grouping_policy(%__MODULE__{status: status}, _ptype, _old_rule, _new_rule) do
    {:error, {:invalid_status, status}}
  end

  @doc """
  Commits the transaction, applying all operations atomically.

  ## Examples

      {:ok, enforcer} = Transaction.commit(transaction)

  """
  @spec commit(t()) :: {:ok, Enforcer.t()} | {:error, term()}
  def commit(
        %__MODULE__{status: :active, operations: operations, enforcer: enforcer} = _transaction
      ) do
    # Disable auto-save temporarily
    temp_enforcer = Enforcer.enable_auto_save(enforcer, false)

    case apply_operations(temp_enforcer, Enum.reverse(operations)) do
      {:ok, updated_enforcer} ->
        # Re-enable auto-save and save once
        final_enforcer = Enforcer.enable_auto_save(updated_enforcer, enforcer.auto_save)

        case Enforcer.save_policy(final_enforcer) do
          {:ok, saved_enforcer} ->
            {:ok, saved_enforcer}

          {:error, reason} ->
            {:error, {:save_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:operation_failed, reason}}
    end
  end

  def commit(%__MODULE__{status: status}) do
    {:error, {:invalid_status, status}}
  end

  @doc """
  Aborts the transaction without applying any operations.

  ## Examples

      {:ok, original_enforcer} = Transaction.rollback(transaction)

  """
  @spec rollback(t()) :: {:ok, Enforcer.t()}
  def rollback(%__MODULE__{enforcer: enforcer} = transaction) do
    _updated_transaction = %{transaction | status: :aborted}
    {:ok, enforcer}
  end

  @doc """
  Gets the current status of the transaction.

  ## Examples

      :active = Transaction.status(transaction)

  """
  @spec status(t()) :: :active | :committed | :aborted
  def status(%__MODULE__{status: status}), do: status

  @doc """
  Gets the transaction ID.

  ## Examples

      "txn_12345" = Transaction.id(transaction)

  """
  @spec id(t()) :: String.t()
  def id(%__MODULE__{id: id}), do: id

  @doc """
  Gets the number of operations in the transaction.

  ## Examples

      5 = Transaction.operation_count(transaction)

  """
  @spec operation_count(t()) :: non_neg_integer()
  def operation_count(%__MODULE__{operations: operations}), do: length(operations)

  @doc """
  Gets information about the transaction.

  ## Examples

      %{id: "txn_12345", status: :active, operations: 3, started_at: ~U[...]} =
        Transaction.info(transaction)

  """
  @spec info(t()) :: map()
  def info(%__MODULE__{} = transaction) do
    %{
      id: transaction.id,
      status: transaction.status,
      operations: length(transaction.operations),
      started_at: transaction.started_at
    }
  end

  # Private functions

  defp capture_state(%Enforcer{policies: policies, grouping_policies: grouping_policies}) do
    %{
      policies: deep_copy(policies),
      grouping_policies: deep_copy(grouping_policies)
    }
  end

  defp deep_copy(data) do
    :erlang.term_to_binary(data) |> :erlang.binary_to_term()
  end

  defp generate_transaction_id do
    "txn_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  defp apply_operations(enforcer, []), do: {:ok, enforcer}

  defp apply_operations(enforcer, [operation | rest]) do
    case apply_single_operation(enforcer, operation) do
      {:ok, updated_enforcer} ->
        apply_operations(updated_enforcer, rest)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp apply_single_operation(enforcer, operation) do
    case operation do
      {op_type, ptype, params} when op_type in [:add_policy, :remove_policy] ->
        apply_policy_operation(enforcer, op_type, ptype, params)

      {op_type, ptype, params} when op_type in [:add_grouping_policy, :remove_grouping_policy] ->
        apply_grouping_policy_operation(enforcer, op_type, ptype, params)

      {op_type, ptype, rules} when op_type in [:add_policies, :remove_policies] ->
        apply_batch_operation(enforcer, op_type, ptype, rules)

      {:update_policy, ptype, old_policy, new_policy} ->
        Enforcer.update_named_policy(enforcer, ptype, old_policy, new_policy)

      {:update_grouping_policy, ptype, old_rule, new_rule} ->
        Enforcer.update_named_grouping_policy(enforcer, ptype, old_rule, new_rule)

      _ ->
        {:error, {:unsupported_operation, operation}}
    end
  end

  defp apply_policy_operation(enforcer, :add_policy, ptype, params) do
    Enforcer.add_named_policy(enforcer, ptype, params)
  end

  defp apply_policy_operation(enforcer, :remove_policy, ptype, params) do
    Enforcer.remove_named_policy(enforcer, ptype, params)
  end

  defp apply_grouping_policy_operation(enforcer, :add_grouping_policy, ptype, params) do
    Enforcer.add_named_grouping_policy(enforcer, ptype, params)
  end

  defp apply_grouping_policy_operation(enforcer, :remove_grouping_policy, ptype, params) do
    Enforcer.remove_named_grouping_policy(enforcer, ptype, params)
  end

  defp apply_batch_operation(enforcer, :add_policies, ptype, rules) do
    Enforcer.add_named_policies(enforcer, ptype, rules)
  end

  defp apply_batch_operation(enforcer, :remove_policies, ptype, rules) do
    Enforcer.remove_named_policies(enforcer, ptype, rules)
  end
end
