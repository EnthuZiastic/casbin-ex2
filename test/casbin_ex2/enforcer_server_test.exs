defmodule CasbinEx2.EnforcerServerTest do
  use ExUnit.Case

  alias CasbinEx2.EnforcerServer
  alias CasbinEx2.EnforcerSupervisor

  @moduletag :integration

  setup do
    # Start the application supervisor for tests
    start_supervised!(CasbinEx2.Application)

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

      # Start enforcer
      assert {:ok, _pid} = EnforcerSupervisor.start_enforcer(enforcer_name, model_path)

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
    end

    test "handles RBAC operations", %{model_path: model_path} do
      enforcer_name = :test_rbac_enforcer

      # Start enforcer
      assert {:ok, _pid} = EnforcerSupervisor.start_enforcer(enforcer_name, model_path)

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
    end

    test "handles batch operations", %{model_path: model_path} do
      enforcer_name = :test_batch_enforcer

      # Start enforcer
      assert {:ok, _pid} = EnforcerSupervisor.start_enforcer(enforcer_name, model_path)

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
    end
  end
end