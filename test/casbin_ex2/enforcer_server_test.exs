defmodule CasbinEx2.EnforcerServerTest do
  use ExUnit.Case

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
      adapter = CasbinEx2.Adapter.FileAdapter.new(policy_path)

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
      adapter = CasbinEx2.Adapter.FileAdapter.new(policy_path)

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
      adapter = CasbinEx2.Adapter.FileAdapter.new(policy_path)

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
  end
end
