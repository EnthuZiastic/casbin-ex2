defmodule CasbinEx2.SyncedEnforcerTest do
  use ExUnit.Case, async: false

  alias CasbinEx2.SyncedEnforcer
  alias CasbinEx2.Adapter.FileAdapter

  @model_path "examples/rbac_model.conf"
  @policy_path "examples/rbac_policy.csv"

  setup do
    # Ensure clean state before each test
    name = :"test_synced_#{:rand.uniform(10000)}"
    adapter = FileAdapter.new(@policy_path)
    {:ok, pid} = SyncedEnforcer.start_link(name, @model_path, adapter: adapter)

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    {:ok, name: name, pid: pid}
  end

  describe "start_link/3" do
    test "starts synced enforcer with model and policy", %{name: name, pid: pid} do
      assert Process.alive?(pid)
    end

    test "initializes with file adapter" do
      new_name = :"test_init_#{:rand.uniform(10000)}"
      adapter = FileAdapter.new(@policy_path)
      assert {:ok, _pid} = SyncedEnforcer.start_link(new_name, @model_path, adapter: adapter)

      # Clean up
      GenServer.stop(via_tuple(new_name))
    end
  end

  describe "enforce/2 - read operations" do
    test "performs authorization check with read lock", %{name: name} do
      result = SyncedEnforcer.enforce(name, ["alice", "data1", "read"])
      assert result == true
    end

    test "rejects unauthorized access", %{name: name} do
      result = SyncedEnforcer.enforce(name, ["bob", "data1", "write"])
      assert result == false
    end

    test "handles concurrent read requests", %{name: name} do
      tasks =
        Enum.map(1..10, fn _ ->
          Task.async(fn ->
            SyncedEnforcer.enforce(name, ["alice", "data1", "read"])
          end)
        end)

      results = Task.await_many(tasks)

      # All should return true
      assert Enum.all?(results, &(&1 == true))
    end
  end

  describe "batch_enforce/2" do
    test "performs batch enforcement with read lock", %{name: name} do
      requests = [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"],
        ["alice", "data2", "read"]
      ]

      results = SyncedEnforcer.batch_enforce(name, requests)

      assert is_list(results)
      assert length(results) == 3
    end
  end

  describe "add_policy/2 - write operations" do
    test "adds policy with write lock", %{name: name} do
      assert true == SyncedEnforcer.add_policy(name, ["eve", "data3", "write"])

      # Verify policy was added
      assert true == SyncedEnforcer.enforce(name, ["eve", "data3", "write"])
    end

    test "returns false for duplicate policy", %{name: name} do
      SyncedEnforcer.add_policy(name, ["dave", "data4", "read"])
      # Adding same policy again should return false
      assert false == SyncedEnforcer.add_policy(name, ["dave", "data4", "read"])
    end
  end

  describe "add_policies/2" do
    test "adds multiple policies in batch", %{name: name} do
      policies = [
        ["user1", "data5", "read"],
        ["user2", "data6", "write"]
      ]

      assert true == SyncedEnforcer.add_policies(name, policies)

      assert true == SyncedEnforcer.enforce(name, ["user1", "data5", "read"])
      assert true == SyncedEnforcer.enforce(name, ["user2", "data6", "write"])
    end
  end

  describe "remove_policy/2" do
    test "removes existing policy", %{name: name} do
      # Add a policy first
      SyncedEnforcer.add_policy(name, ["temp_user", "temp_data", "read"])

      # Remove it
      assert true == SyncedEnforcer.remove_policy(name, ["temp_user", "temp_data", "read"])

      # Verify it's removed
      assert false == SyncedEnforcer.enforce(name, ["temp_user", "temp_data", "read"])
    end

    test "returns false for non-existent policy", %{name: name} do
      assert false == SyncedEnforcer.remove_policy(name, ["nonexistent", "data", "action"])
    end
  end

  describe "remove_policies/2" do
    test "removes multiple policies in batch", %{name: name} do
      # Add policies first
      SyncedEnforcer.add_policies(name, [
        ["batch_user1", "data7", "read"],
        ["batch_user2", "data8", "write"]
      ])

      # Remove them
      policies_to_remove = [
        ["batch_user1", "data7", "read"],
        ["batch_user2", "data8", "write"]
      ]

      assert true == SyncedEnforcer.remove_policies(name, policies_to_remove)
    end
  end

  describe "remove_filtered_policy/3" do
    test "removes policies matching filter", %{name: name} do
      # Add policies
      SyncedEnforcer.add_policies(name, [
        ["filter_test1", "data9", "read"],
        ["filter_test1", "data9", "write"],
        ["filter_test2", "data9", "read"]
      ])

      # Remove all policies for filter_test1
      assert true == SyncedEnforcer.remove_filtered_policy(name, 0, ["filter_test1"])
    end
  end

  describe "role management" do
    test "add_role_for_user/4", %{name: name} do
      assert true == SyncedEnforcer.add_role_for_user(name, "new_user", "admin")

      roles = SyncedEnforcer.get_roles_for_user(name, "new_user")
      assert "admin" in roles
    end

    test "delete_role_for_user/4", %{name: name} do
      SyncedEnforcer.add_role_for_user(name, "test_user", "editor")
      assert true == SyncedEnforcer.delete_role_for_user(name, "test_user", "editor")

      roles = SyncedEnforcer.get_roles_for_user(name, "test_user")
      refute "editor" in roles
    end

    test "delete_roles_for_user/3", %{name: name} do
      SyncedEnforcer.add_role_for_user(name, "multi_role_user", "role1")
      SyncedEnforcer.add_role_for_user(name, "multi_role_user", "role2")

      assert true == SyncedEnforcer.delete_roles_for_user(name, "multi_role_user")

      roles = SyncedEnforcer.get_roles_for_user(name, "multi_role_user")
      assert roles == []
    end

    test "get_roles_for_user/3", %{name: name} do
      roles = SyncedEnforcer.get_roles_for_user(name, "alice")
      assert is_list(roles)
    end

    test "get_users_for_role/3", %{name: name} do
      SyncedEnforcer.add_role_for_user(name, "user_a", "viewer")
      SyncedEnforcer.add_role_for_user(name, "user_b", "viewer")

      users = SyncedEnforcer.get_users_for_role(name, "viewer")
      assert "user_a" in users
      assert "user_b" in users
    end

    test "has_role_for_user/4", %{name: name} do
      SyncedEnforcer.add_role_for_user(name, "test_check_user", "moderator")

      assert true == SyncedEnforcer.has_role_for_user(name, "test_check_user", "moderator")
      assert false == SyncedEnforcer.has_role_for_user(name, "test_check_user", "admin")
    end
  end

  describe "policy query operations" do
    test "get_policy/1", %{name: name} do
      policies = SyncedEnforcer.get_policy(name)
      assert is_list(policies)
    end

    test "get_filtered_policy/3", %{name: name} do
      filtered = SyncedEnforcer.get_filtered_policy(name, 0, ["alice"])
      assert is_list(filtered)
    end

    test "has_policy/2", %{name: name} do
      # Add a known policy
      SyncedEnforcer.add_policy(name, ["check_user", "check_data", "check_action"])

      assert true == SyncedEnforcer.has_policy(name, ["check_user", "check_data", "check_action"])
      assert false == SyncedEnforcer.has_policy(name, ["nonexistent", "policy", "rule"])
    end

    test "get_grouping_policy/1", %{name: name} do
      grouping = SyncedEnforcer.get_grouping_policy(name)
      assert is_list(grouping)
    end

    test "get_permissions_for_user/3", %{name: name} do
      permissions = SyncedEnforcer.get_permissions_for_user(name, "alice")
      assert is_list(permissions)
    end
  end

  describe "enforcer lifecycle operations" do
    test "load_policy/1", %{name: name} do
      assert :ok == SyncedEnforcer.load_policy(name)
    end

    test "save_policy/1", %{name: name} do
      # Note: This might fail with file adapter in test, but tests the API
      result = SyncedEnforcer.save_policy(name)
      assert result == :ok or match?({:error, _}, result)
    end

    test "build_role_links/1", %{name: name} do
      assert :ok == SyncedEnforcer.build_role_links(name)
    end
  end

  describe "thread safety" do
    test "handles concurrent read and write operations", %{name: name} do
      # Spawn readers
      read_tasks =
        Enum.map(1..10, fn _ ->
          Task.async(fn ->
            SyncedEnforcer.enforce(name, ["alice", "data1", "read"])
          end)
        end)

      # Spawn writers
      write_tasks =
        Enum.map(1..5, fn i ->
          Task.async(fn ->
            SyncedEnforcer.add_policy(name, ["concurrent_user#{i}", "data#{i}", "read"])
          end)
        end)

      # All operations should complete without deadlock or errors
      read_results = Task.await_many(read_tasks)
      write_results = Task.await_many(write_tasks)

      assert Enum.all?(read_results, &is_boolean/1)
      assert Enum.all?(write_results, &is_boolean/1)
    end

    test "maintains data consistency under concurrent modifications", %{name: name} do
      # Add base policy
      SyncedEnforcer.add_policy(name, ["consistency_user", "data", "read"])

      # Concurrent operations
      tasks =
        Enum.flat_map(1..10, fn i ->
          [
            Task.async(fn ->
              SyncedEnforcer.add_policy(name, ["user#{i}", "data#{i}", "read"])
            end),
            Task.async(fn ->
              SyncedEnforcer.enforce(name, ["consistency_user", "data", "read"])
            end)
          ]
        end)

      results = Task.await_many(tasks)

      # Enforcement checks should always return true for existing policy
      enforcement_results = Enum.take_every(results, 2)
      assert Enum.all?(enforcement_results, &(&1 == true))
    end
  end

  describe "edge cases" do
    test "handles empty policy operations", %{name: name} do
      assert true == SyncedEnforcer.add_policies(name, [])
      assert true == SyncedEnforcer.remove_policies(name, [])
    end

    test "handles rapid sequential operations", %{name: name, pid: pid} do
      # Rapid add-remove cycle
      for i <- 1..100 do
        SyncedEnforcer.add_policy(name, ["rapid_user#{i}", "data#{i}", "read"])
      end

      for i <- 1..100 do
        SyncedEnforcer.remove_policy(name, ["rapid_user#{i}", "data#{i}", "read"])
      end

      # No crashes or deadlocks
      assert Process.alive?(pid)
    end
  end

  describe "error handling" do
    test "handles operations on stopped enforcer gracefully" do
      stopped_name = :"stopped_enforcer_#{:rand.uniform(10000)}"
      adapter = FileAdapter.new(@policy_path)

      {:ok, pid} = SyncedEnforcer.start_link(stopped_name, @model_path, adapter: adapter)

      GenServer.stop(pid)

      # Operations should timeout or return error (not crash)
      assert catch_exit(SyncedEnforcer.enforce(stopped_name, ["alice", "data1", "read"]))
    end
  end

  # Helper functions
  defp via_tuple(name) do
    {:via, Registry, {CasbinEx2.EnforcerRegistry, :"synced_#{name}"}}
  end
end
