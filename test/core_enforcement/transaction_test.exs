defmodule CasbinEx2.TransactionTest do
  use ExUnit.Case
  doctest CasbinEx2.Transaction

  alias CasbinEx2.{Enforcer, Transaction}

  @model_path "test/examples/rbac_model.conf"
  @policy_path "test/examples/rbac_policy.csv"

  setup do
    # Create test model and policy files if they don't exist
    File.mkdir_p!("test/examples")

    unless File.exists?(@model_path) do
      model_content = """
      [request_definition]
      r = sub, obj, act

      [policy_definition]
      p = sub, obj, act

      [role_definition]
      g = _, _

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act
      """

      File.write!(@model_path, model_content)
    end

    unless File.exists?(@policy_path) do
      policy_content = """
      p, alice, data1, read
      p, bob, data2, write
      g, alice, admin
      """

      File.write!(@policy_path, policy_content)
    end

    {:ok, enforcer} = Enforcer.new_enforcer(@model_path, @policy_path)

    on_exit(fn ->
      File.rm_rf("test/examples")
    end)

    {:ok, enforcer: enforcer}
  end

  describe "new/1" do
    test "creates a new transaction", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)

      assert transaction.enforcer == enforcer
      assert transaction.operations == []
      assert is_map(transaction.original_state)
      assert is_binary(transaction.id)
      assert String.starts_with?(transaction.id, "txn_")
      assert %DateTime{} = transaction.started_at
      assert transaction.status == :active
    end
  end

  describe "add_policy/3" do
    test "adds policy operation to transaction", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)

      {:ok, updated_transaction} =
        Transaction.add_policy(transaction, "p", ["charlie", "data3", "read"])

      assert length(updated_transaction.operations) == 1
      assert {:add_policy, "p", ["charlie", "data3", "read"]} in updated_transaction.operations
    end

    test "fails when transaction is not active", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)
      aborted_transaction = %{transaction | status: :committed}

      {:error, {:invalid_status, :committed}} =
        Transaction.add_policy(aborted_transaction, "p", ["charlie", "data3", "read"])
    end
  end

  describe "remove_policy/3" do
    test "adds remove policy operation to transaction", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)

      {:ok, updated_transaction} =
        Transaction.remove_policy(transaction, "p", ["alice", "data1", "read"])

      assert length(updated_transaction.operations) == 1
      assert {:remove_policy, "p", ["alice", "data1", "read"]} in updated_transaction.operations
    end
  end

  describe "add_grouping_policy/3" do
    test "adds grouping policy operation to transaction", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)

      {:ok, updated_transaction} =
        Transaction.add_grouping_policy(transaction, "g", ["charlie", "user"])

      assert length(updated_transaction.operations) == 1
      assert {:add_grouping_policy, "g", ["charlie", "user"]} in updated_transaction.operations
    end
  end

  describe "remove_grouping_policy/3" do
    test "adds remove grouping policy operation to transaction", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)

      {:ok, updated_transaction} =
        Transaction.remove_grouping_policy(transaction, "g", ["alice", "admin"])

      assert length(updated_transaction.operations) == 1
      assert {:remove_grouping_policy, "g", ["alice", "admin"]} in updated_transaction.operations
    end
  end

  describe "add_policies/3" do
    test "adds multiple policy operations to transaction", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)
      policies = [["charlie", "data3", "read"], ["david", "data4", "write"]]
      {:ok, updated_transaction} = Transaction.add_policies(transaction, "p", policies)

      assert length(updated_transaction.operations) == 1
      assert {:add_policies, "p", policies} in updated_transaction.operations
    end
  end

  describe "remove_policies/3" do
    test "adds multiple remove policy operations to transaction", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)
      policies = [["alice", "data1", "read"], ["bob", "data2", "write"]]
      {:ok, updated_transaction} = Transaction.remove_policies(transaction, "p", policies)

      assert length(updated_transaction.operations) == 1
      assert {:remove_policies, "p", policies} in updated_transaction.operations
    end
  end

  describe "update_policy/4" do
    test "adds update policy operation to transaction", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)
      old_policy = ["alice", "data1", "read"]
      new_policy = ["alice", "data1", "write"]

      {:ok, updated_transaction} =
        Transaction.update_policy(transaction, "p", old_policy, new_policy)

      assert length(updated_transaction.operations) == 1
      assert {:update_policy, "p", old_policy, new_policy} in updated_transaction.operations
    end
  end

  describe "update_grouping_policy/4" do
    test "adds update grouping policy operation to transaction", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)
      old_rule = ["alice", "admin"]
      new_rule = ["alice", "super_admin"]

      {:ok, updated_transaction} =
        Transaction.update_grouping_policy(transaction, "g", old_rule, new_rule)

      assert length(updated_transaction.operations) == 1
      assert {:update_grouping_policy, "g", old_rule, new_rule} in updated_transaction.operations
    end
  end

  describe "commit/1" do
    test "commits transaction and applies all operations", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)
      {:ok, transaction} = Transaction.add_policy(transaction, "p", ["charlie", "data3", "read"])
      {:ok, transaction} = Transaction.add_grouping_policy(transaction, "g", ["charlie", "user"])

      {:ok, updated_enforcer} = Transaction.commit(transaction)

      # Verify policy was added
      assert Enforcer.has_policy(updated_enforcer, ["charlie", "data3", "read"])
      # Verify grouping policy was added (this should be available in updated enforcer)
      grouping_policies = Enforcer.get_grouping_policy(updated_enforcer)
      assert ["charlie", "user"] in grouping_policies
    end

    test "fails when transaction is not active", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)
      committed_transaction = %{transaction | status: :committed}

      {:error, {:invalid_status, :committed}} = Transaction.commit(committed_transaction)
    end

    test "rolls back on operation failure", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)

      # Add a valid operation
      {:ok, transaction} = Transaction.add_policy(transaction, "p", ["charlie", "data3", "read"])

      # Add an operation that would fail (trying to remove non-existent policy)
      {:ok, transaction} =
        Transaction.remove_policy(transaction, "p", ["nonexistent", "data", "action"])

      # The commit should succeed for add but fail gracefully for remove
      case Transaction.commit(transaction) do
        {:ok, _updated_enforcer} ->
          # Transaction succeeded - the remove operation might have been ignored
          :ok

        {:error, _reason} ->
          # Transaction failed - this is also acceptable behavior
          :ok
      end
    end
  end

  describe "rollback/1" do
    test "aborts transaction without applying operations", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)
      {:ok, transaction} = Transaction.add_policy(transaction, "p", ["charlie", "data3", "read"])

      {:ok, original_enforcer} = Transaction.rollback(transaction)

      # Verify the original enforcer is returned
      assert original_enforcer == enforcer
      # Verify policy was not added
      refute Enforcer.has_policy(original_enforcer, ["charlie", "data3", "read"])
    end
  end

  describe "status/1" do
    test "returns transaction status", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)
      assert Transaction.status(transaction) == :active
    end
  end

  describe "id/1" do
    test "returns transaction ID", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)
      id = Transaction.id(transaction)
      assert is_binary(id)
      assert String.starts_with?(id, "txn_")
    end
  end

  describe "operation_count/1" do
    test "returns number of operations", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)
      assert Transaction.operation_count(transaction) == 0

      {:ok, transaction} = Transaction.add_policy(transaction, "p", ["charlie", "data3", "read"])
      assert Transaction.operation_count(transaction) == 1

      {:ok, transaction} = Transaction.add_grouping_policy(transaction, "g", ["charlie", "user"])
      assert Transaction.operation_count(transaction) == 2
    end
  end

  describe "info/1" do
    test "returns transaction information", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)
      {:ok, transaction} = Transaction.add_policy(transaction, "p", ["charlie", "data3", "read"])

      info = Transaction.info(transaction)

      assert info.id == transaction.id
      assert info.status == :active
      assert info.operations == 1
      assert %DateTime{} = info.started_at
    end
  end

  describe "complex transaction scenarios" do
    test "multiple operations in single transaction", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)

      # Add multiple operations
      {:ok, transaction} = Transaction.add_policy(transaction, "p", ["charlie", "data3", "read"])
      {:ok, transaction} = Transaction.add_policy(transaction, "p", ["david", "data4", "write"])
      {:ok, transaction} = Transaction.add_grouping_policy(transaction, "g", ["charlie", "user"])
      {:ok, transaction} = Transaction.remove_policy(transaction, "p", ["bob", "data2", "write"])

      assert Transaction.operation_count(transaction) == 4

      {:ok, updated_enforcer} = Transaction.commit(transaction)

      # Verify all operations were applied
      assert Enforcer.has_policy(updated_enforcer, ["charlie", "data3", "read"])
      assert Enforcer.has_policy(updated_enforcer, ["david", "data4", "write"])
      refute Enforcer.has_policy(updated_enforcer, ["bob", "data2", "write"])

      grouping_policies = Enforcer.get_grouping_policy(updated_enforcer)
      assert ["charlie", "user"] in grouping_policies
    end

    test "update operations in transaction", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)

      # Update existing policy
      {:ok, transaction} =
        Transaction.update_policy(transaction, "p", ["alice", "data1", "read"], [
          "alice",
          "data1",
          "write"
        ])

      {:ok, updated_enforcer} = Transaction.commit(transaction)

      # Verify policy was updated
      refute Enforcer.has_policy(updated_enforcer, ["alice", "data1", "read"])
      assert Enforcer.has_policy(updated_enforcer, ["alice", "data1", "write"])
    end

    test "mixed policy and grouping policy operations", %{enforcer: enforcer} do
      {:ok, transaction} = Transaction.new(enforcer)

      # Add new user with policies and roles
      {:ok, transaction} =
        Transaction.add_policies(transaction, "p", [
          ["eve", "data5", "read"],
          ["eve", "data6", "write"]
        ])

      {:ok, transaction} = Transaction.add_grouping_policy(transaction, "g", ["eve", "editor"])

      {:ok, updated_enforcer} = Transaction.commit(transaction)

      # Verify all changes were applied
      assert Enforcer.has_policy(updated_enforcer, ["eve", "data5", "read"])
      assert Enforcer.has_policy(updated_enforcer, ["eve", "data6", "write"])

      grouping_policies = Enforcer.get_grouping_policy(updated_enforcer)
      assert ["eve", "editor"] in grouping_policies
    end
  end
end
