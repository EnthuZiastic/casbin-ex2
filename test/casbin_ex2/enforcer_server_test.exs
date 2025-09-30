defmodule CasbinEx2.EnforcerServerTest do
  use ExUnit.Case

  alias CasbinEx2.Adapter.FileAdapter
  alias CasbinEx2.EnforcerServer
  alias CasbinEx2.EnforcerSupervisor

  @moduletag :integration

  setup do
    # Start the required components for tests
    unless Process.whereis(CasbinEx2.EnforcerRegistry) do
      start_supervised!({Registry, keys: :unique, name: CasbinEx2.EnforcerRegistry})
    end

    unless Process.whereis(CasbinEx2.EnforcerSupervisor) do
      start_supervised!(CasbinEx2.EnforcerSupervisor)
    end

    # Create ETS table for enforcer persistence (if not already exists)
    case :ets.info(:casbin_enforcers_table) do
      :undefined -> :ets.new(:casbin_enforcers_table, [:public, :named_table])
      _ -> :ok
    end

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
    m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
    """

    model_path = "/tmp/test_model_server.conf"
    File.write!(model_path, model_content)

    on_exit(fn ->
      File.rm(model_path)
    end)

    %{model_path: model_path}
  end

  describe "EnforcerServer" do
    test "starts enforcer server and performs basic operations", %{model_path: model_path} do
      enforcer_name = :test_enforcer
      policy_path = "/tmp/test_server_policy.csv"

      # Create empty policy file
      File.write!(policy_path, "")

      # Start enforcer with proper adapter
      adapter = FileAdapter.new(policy_path)

      assert {:ok, _pid} =
               EnforcerSupervisor.start_enforcer(enforcer_name, model_path, adapter: adapter)

      # Add a policy
      assert EnforcerServer.add_policy(enforcer_name, ["alice", "data1", "read"]) == true

      # Check enforcement
      assert EnforcerServer.enforce(enforcer_name, ["alice", "data1", "read"]) == true
      assert EnforcerServer.enforce(enforcer_name, ["alice", "data1", "write"]) == false

      # Get policies
      policies = EnforcerServer.get_policy(enforcer_name)
      assert ["alice", "data1", "read"] in policies

      # Check policy exists
      assert EnforcerServer.has_policy(enforcer_name, ["alice", "data1", "read"]) == true
      assert EnforcerServer.has_policy(enforcer_name, ["bob", "data1", "read"]) == false

      # Remove policy
      assert EnforcerServer.remove_policy(enforcer_name, ["alice", "data1", "read"]) == true
      assert EnforcerServer.enforce(enforcer_name, ["alice", "data1", "read"]) == false

      # Stop enforcer
      assert :ok = EnforcerSupervisor.stop_enforcer(enforcer_name)

      # Cleanup
      File.rm(policy_path)
    end

    test "handles RBAC operations", %{model_path: model_path} do
      enforcer_name = :test_rbac_enforcer
      policy_path = "/tmp/test_rbac_policy.csv"

      # Create empty policy file
      File.write!(policy_path, "")

      # Start enforcer with proper adapter
      adapter = FileAdapter.new(policy_path)

      assert {:ok, _pid} =
               EnforcerSupervisor.start_enforcer(enforcer_name, model_path, adapter: adapter)

      # Add role for user
      assert EnforcerServer.add_role_for_user(enforcer_name, "alice", "admin") == true

      # Check role
      assert EnforcerServer.has_role_for_user(enforcer_name, "alice", "admin") == true
      assert EnforcerServer.has_role_for_user(enforcer_name, "alice", "user") == false

      # Get roles for user
      roles = EnforcerServer.get_roles_for_user(enforcer_name, "alice")
      assert "admin" in roles

      # Get users for role
      users = EnforcerServer.get_users_for_role(enforcer_name, "admin")
      assert "alice" in users

      # Delete role for user
      assert EnforcerServer.delete_role_for_user(enforcer_name, "alice", "admin") == true
      assert EnforcerServer.has_role_for_user(enforcer_name, "alice", "admin") == false

      # Stop enforcer
      assert :ok = EnforcerSupervisor.stop_enforcer(enforcer_name)

      # Cleanup
      File.rm(policy_path)
    end

    test "handles batch operations", %{model_path: model_path} do
      enforcer_name = :test_batch_enforcer
      policy_path = "/tmp/test_batch_policy.csv"

      # Create empty policy file
      File.write!(policy_path, "")

      # Start enforcer with proper adapter
      adapter = FileAdapter.new(policy_path)

      assert {:ok, _pid} =
               EnforcerSupervisor.start_enforcer(enforcer_name, model_path, adapter: adapter)

      # Add multiple policies
      policies = [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"],
        ["charlie", "data3", "read"]
      ]

      assert EnforcerServer.add_policies(enforcer_name, policies) == true

      # Batch enforcement
      requests = [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"],
        ["charlie", "data3", "write"]
      ]

      results = EnforcerServer.batch_enforce(enforcer_name, requests)
      assert results == [true, true, false]

      # Stop enforcer
      assert :ok = EnforcerSupervisor.stop_enforcer(enforcer_name)

      # Cleanup
      File.rm(policy_path)
    end

    test "handles enhanced enforcement APIs", %{model_path: model_path} do
      enforcer_name = :test_enhanced_enforcer
      policy_path = "/tmp/test_enhanced_policy.csv"

      File.write!(policy_path, "")
      adapter = FileAdapter.new(policy_path)

      assert {:ok, _pid} =
               EnforcerSupervisor.start_enforcer(enforcer_name, model_path, adapter: adapter)

      # Add test policies
      assert EnforcerServer.add_policy(enforcer_name, ["alice", "data1", "read"]) == true

      # Test enforce_ex (with explanations)
      {result, explanations} =
        EnforcerServer.enforce_ex(enforcer_name, ["alice", "data1", "read"])

      assert result == true
      assert is_list(explanations)

      # Test enforce_with_matcher
      custom_matcher = "r.sub == p.sub && r.obj == p.obj && r.act == p.act"

      assert EnforcerServer.enforce_with_matcher(enforcer_name, custom_matcher, [
               "alice",
               "data1",
               "read"
             ]) == true

      # Test batch_enforce_ex
      requests = [["alice", "data1", "read"], ["bob", "data1", "read"]]
      results = EnforcerServer.batch_enforce_ex(enforcer_name, requests)
      assert is_list(results)
      assert length(results) == 2

      # Stop enforcer
      assert :ok = EnforcerSupervisor.stop_enforcer(enforcer_name)
      File.rm(policy_path)
    end

    test "handles management APIs", %{model_path: model_path} do
      enforcer_name = :test_mgmt_enforcer
      policy_path = "/tmp/test_mgmt_policy.csv"

      File.write!(policy_path, "")
      adapter = FileAdapter.new(policy_path)

      assert {:ok, _pid} =
               EnforcerSupervisor.start_enforcer(enforcer_name, model_path, adapter: adapter)

      # Add test data
      assert EnforcerServer.add_policy(enforcer_name, ["alice", "data1", "read"]) == true
      assert EnforcerServer.add_policy(enforcer_name, ["bob", "data2", "write"]) == true
      assert EnforcerServer.add_role_for_user(enforcer_name, "alice", "admin") == true

      # Test get_all_* APIs
      subjects = EnforcerServer.get_all_subjects(enforcer_name)
      assert "alice" in subjects
      assert "bob" in subjects

      objects = EnforcerServer.get_all_objects(enforcer_name)
      assert "data1" in objects
      assert "data2" in objects

      actions = EnforcerServer.get_all_actions(enforcer_name)
      assert "read" in actions
      assert "write" in actions

      roles = EnforcerServer.get_all_roles(enforcer_name)
      assert "admin" in roles

      # Test update_policy
      old_policy = ["alice", "data1", "read"]
      new_policy = ["alice", "data1", "write"]
      assert EnforcerServer.update_policy(enforcer_name, old_policy, new_policy) == true
      assert EnforcerServer.has_policy(enforcer_name, new_policy) == true
      assert EnforcerServer.has_policy(enforcer_name, old_policy) == false

      # Stop enforcer
      assert :ok = EnforcerSupervisor.stop_enforcer(enforcer_name)
      File.rm(policy_path)
    end

    test "handles complete RBAC APIs", %{model_path: model_path} do
      enforcer_name = :test_complete_rbac_enforcer
      policy_path = "/tmp/test_complete_rbac_policy.csv"

      File.write!(policy_path, "")
      adapter = FileAdapter.new(policy_path)

      assert {:ok, _pid} =
               EnforcerSupervisor.start_enforcer(enforcer_name, model_path, adapter: adapter)

      # Setup test data
      assert EnforcerServer.add_policy(enforcer_name, ["alice", "data1", "read"]) == true
      assert EnforcerServer.add_policy(enforcer_name, ["bob", "data2", "write"]) == true
      assert EnforcerServer.add_role_for_user(enforcer_name, "alice", "admin") == true
      assert EnforcerServer.add_role_for_user(enforcer_name, "bob", "user") == true

      # Test delete_user
      assert EnforcerServer.delete_user(enforcer_name, "alice") == true
      policies = EnforcerServer.get_policy(enforcer_name)
      assert not Enum.any?(policies, fn [user | _] -> user == "alice" end)
      roles = EnforcerServer.get_roles_for_user(enforcer_name, "alice")
      assert roles == []

      # Test delete_role
      assert EnforcerServer.delete_role(enforcer_name, "user") == true
      assert EnforcerServer.get_roles_for_user(enforcer_name, "bob") == []

      # Re-add some data for further testing
      assert EnforcerServer.add_policy(enforcer_name, ["charlie", "data3", "read"]) == true

      assert EnforcerServer.add_permission_for_user(enforcer_name, "charlie", ["data3", "read"]) ==
               true

      # Test delete_permission
      assert EnforcerServer.delete_permission(enforcer_name, ["data3", "read"]) == true
      policies = EnforcerServer.get_policy(enforcer_name)
      assert not Enum.any?(policies, fn [_, obj, act] -> obj == "data3" && act == "read" end)

      # Test get_users_for_permission
      assert EnforcerServer.add_policy(enforcer_name, ["dave", "data4", "write"]) == true
      users = EnforcerServer.get_users_for_permission(enforcer_name, ["data4", "write"])
      assert "dave" in users

      # Test bulk operations
      assert EnforcerServer.add_roles_for_user(enforcer_name, "eve", ["admin", "moderator"]) ==
               true

      roles = EnforcerServer.get_roles_for_user(enforcer_name, "eve")
      assert "admin" in roles
      assert "moderator" in roles

      permissions = [["data5", "read"], ["data5", "write"]]
      assert EnforcerServer.add_permissions_for_user(enforcer_name, "eve", permissions) == true
      user_permissions = EnforcerServer.get_permissions_for_user(enforcer_name, "eve")
      assert Enum.any?(user_permissions, fn [obj, act] -> obj == "data5" && act == "read" end)

      # Stop enforcer
      assert :ok = EnforcerSupervisor.stop_enforcer(enforcer_name)
      File.rm(policy_path)
    end

    test "handles domain-specific RBAC APIs", %{model_path: model_path} do
      enforcer_name = :test_domain_rbac_enforcer
      policy_path = "/tmp/test_domain_rbac_policy.csv"

      File.write!(policy_path, "")
      adapter = FileAdapter.new(policy_path)

      assert {:ok, _pid} =
               EnforcerSupervisor.start_enforcer(enforcer_name, model_path, adapter: adapter)

      # Test domain-specific role operations
      assert EnforcerServer.add_role_for_user_in_domain(
               enforcer_name,
               "alice",
               "admin",
               "domain1"
             ) == true

      assert EnforcerServer.add_role_for_user_in_domain(enforcer_name, "alice", "user", "domain2") ==
               true

      assert EnforcerServer.add_role_for_user_in_domain(enforcer_name, "bob", "admin", "domain1") ==
               true

      # Test get_roles_for_user_in_domain
      domain1_roles =
        EnforcerServer.get_roles_for_user_in_domain(enforcer_name, "alice", "domain1")

      assert "admin" in domain1_roles

      domain2_roles =
        EnforcerServer.get_roles_for_user_in_domain(enforcer_name, "alice", "domain2")

      assert "user" in domain2_roles

      # Test get_users_for_role_in_domain
      admin_users_domain1 =
        EnforcerServer.get_users_for_role_in_domain(enforcer_name, "admin", "domain1")

      assert "alice" in admin_users_domain1
      assert "bob" in admin_users_domain1

      # Test delete_role_for_user_in_domain
      assert EnforcerServer.delete_role_for_user_in_domain(
               enforcer_name,
               "alice",
               "admin",
               "domain1"
             ) == true

      domain1_roles_after =
        EnforcerServer.get_roles_for_user_in_domain(enforcer_name, "alice", "domain1")

      assert "admin" not in domain1_roles_after

      # Test delete_roles_for_user_in_domain
      assert EnforcerServer.delete_roles_for_user_in_domain(enforcer_name, "alice", "domain2") ==
               true

      domain2_roles_after =
        EnforcerServer.get_roles_for_user_in_domain(enforcer_name, "alice", "domain2")

      assert domain2_roles_after == []

      # Test get_all_users_by_domain
      assert EnforcerServer.add_role_for_user_in_domain(
               enforcer_name,
               "charlie",
               "user",
               "domain3"
             ) == true

      domain3_users = EnforcerServer.get_all_users_by_domain(enforcer_name, "domain3")
      assert "charlie" in domain3_users

      # Test delete_all_users_by_domain
      assert EnforcerServer.delete_all_users_by_domain(enforcer_name, "domain3") == true
      domain3_users_after = EnforcerServer.get_all_users_by_domain(enforcer_name, "domain3")
      assert domain3_users_after == []

      # Stop enforcer
      assert :ok = EnforcerSupervisor.stop_enforcer(enforcer_name)
      File.rm(policy_path)
    end

    test "handles concurrent batch operations with smart batching", %{model_path: model_path} do
      enforcer_name = :test_concurrent_enforcer
      policy_path = "/tmp/test_concurrent_policy.csv"

      File.write!(policy_path, "")
      adapter = FileAdapter.new(policy_path)

      assert {:ok, _pid} =
               EnforcerSupervisor.start_enforcer(enforcer_name, model_path, adapter: adapter)

      # Add test policies for batch operations
      policies = Enum.map(1..15, fn i -> ["user#{i}", "data#{i}", "read"] end)
      assert EnforcerServer.add_policies(enforcer_name, policies) == true

      # Test small batch (should be sequential)
      small_requests = Enum.map(1..5, fn i -> ["user#{i}", "data#{i}", "read"] end)

      start_time = System.monotonic_time(:millisecond)
      small_results = EnforcerServer.batch_enforce(enforcer_name, small_requests)
      small_duration = System.monotonic_time(:millisecond) - start_time

      assert length(small_results) == 5
      assert Enum.all?(small_results, &(&1 == true))

      # Test large batch (should be concurrent)
      large_requests = Enum.map(1..15, fn i -> ["user#{i}", "data#{i}", "read"] end)

      start_time = System.monotonic_time(:millisecond)
      large_results = EnforcerServer.batch_enforce(enforcer_name, large_requests)
      large_duration = System.monotonic_time(:millisecond) - start_time

      assert length(large_results) == 15
      assert Enum.all?(large_results, &(&1 == true))

      # Concurrent execution should be faster for large batches
      # (This is a rough heuristic - in practice, overhead might make small batches faster)
      IO.puts("Small batch (#{length(small_requests)} requests): #{small_duration}ms")
      IO.puts("Large batch (#{length(large_requests)} requests): #{large_duration}ms")

      # Test batch_enforce_ex with explanations
      ex_results = EnforcerServer.batch_enforce_ex(enforcer_name, large_requests)
      assert length(ex_results) == 15
      assert Enum.all?(ex_results, fn {result, _explanations} -> result == true end)

      # Test batch_enforce_with_matcher
      custom_matcher = "r.sub == p.sub && r.obj == p.obj && r.act == p.act"

      matcher_results =
        EnforcerServer.batch_enforce_with_matcher(enforcer_name, custom_matcher, large_requests)

      assert length(matcher_results) == 15
      assert Enum.all?(matcher_results, &(&1 == true))

      # Stop enforcer
      assert :ok = EnforcerSupervisor.stop_enforcer(enforcer_name)
      File.rm(policy_path)
    end

    test "handles mixed success/failure batch operations", %{model_path: model_path} do
      enforcer_name = :test_mixed_batch_enforcer
      policy_path = "/tmp/test_mixed_batch_policy.csv"

      File.write!(policy_path, "")
      adapter = FileAdapter.new(policy_path)

      assert {:ok, _pid} =
               EnforcerSupervisor.start_enforcer(enforcer_name, model_path, adapter: adapter)

      # Add only some policies
      allowed_policies = [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"],
        ["charlie", "data3", "read"]
      ]

      assert EnforcerServer.add_policies(enforcer_name, allowed_policies) == true

      # Create mixed requests (some allowed, some denied)
      mixed_requests = [
        # allowed
        ["alice", "data1", "read"],
        # denied
        ["alice", "data1", "write"],
        # allowed
        ["bob", "data2", "write"],
        # denied
        ["bob", "data2", "read"],
        # allowed
        ["charlie", "data3", "read"],
        # denied
        ["dave", "data4", "read"],
        # denied
        ["eve", "data5", "write"]
      ]

      results = EnforcerServer.batch_enforce(enforcer_name, mixed_requests)
      expected_results = [true, false, true, false, true, false, false]
      assert results == expected_results

      # Test with explanations
      ex_results = EnforcerServer.batch_enforce_ex(enforcer_name, mixed_requests)
      assert length(ex_results) == length(mixed_requests)

      Enum.zip(ex_results, expected_results)
      |> Enum.each(fn {{result, explanations}, expected} ->
        assert result == expected
        assert is_list(explanations)
      end)

      # Stop enforcer
      assert :ok = EnforcerSupervisor.stop_enforcer(enforcer_name)
      File.rm(policy_path)
    end

    test "handles edge cases in batch operations", %{model_path: model_path} do
      enforcer_name = :test_edge_case_enforcer
      policy_path = "/tmp/test_edge_case_policy.csv"

      File.write!(policy_path, "")
      adapter = FileAdapter.new(policy_path)

      assert {:ok, _pid} =
               EnforcerSupervisor.start_enforcer(enforcer_name, model_path, adapter: adapter)

      # Test empty batch
      empty_results = EnforcerServer.batch_enforce(enforcer_name, [])
      assert empty_results == []

      # Test single request batch
      assert EnforcerServer.add_policy(enforcer_name, ["alice", "data1", "read"]) == true
      single_results = EnforcerServer.batch_enforce(enforcer_name, [["alice", "data1", "read"]])
      assert single_results == [true]

      # Test duplicate requests in batch
      duplicate_requests = [
        ["alice", "data1", "read"],
        ["alice", "data1", "read"],
        ["alice", "data1", "read"]
      ]

      duplicate_results = EnforcerServer.batch_enforce(enforcer_name, duplicate_requests)
      assert duplicate_results == [true, true, true]

      # Test malformed requests (should handle gracefully)
      malformed_requests = [
        # valid
        ["alice", "data1", "read"],
        # invalid - too few params
        ["alice"],
        # invalid - too many params
        ["alice", "data1", "read", "extra"],
        # valid but no policy
        ["bob", "data2", "write"]
      ]

      # The system should handle malformed requests gracefully
      # (exact behavior depends on implementation - some might return false, others might error)
      malformed_results = EnforcerServer.batch_enforce(enforcer_name, malformed_requests)
      assert is_list(malformed_results)
      assert length(malformed_results) == length(malformed_requests)

      # Stop enforcer
      assert :ok = EnforcerSupervisor.stop_enforcer(enforcer_name)
      File.rm(policy_path)
    end
  end
end
