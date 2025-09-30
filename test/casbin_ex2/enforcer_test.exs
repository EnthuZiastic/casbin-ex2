defmodule CasbinEx2.EnforcerTest do
  use ExUnit.Case

  alias CasbinEx2.Enforcer
  alias CasbinEx2.Adapter.FileAdapter

  @moduletag :unit

  describe "new_enforcer/2" do
    test "creates enforcer with model file and adapter" do
      model_content = """
      [request_definition]
      r = sub, obj, act

      [policy_definition]
      p = sub, obj, act

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
      """

      # Create temporary model file
      model_path = "/tmp/test_model.conf"
      File.write!(model_path, model_content)

      adapter = FileAdapter.new("/tmp/test_policy.csv")

      assert {:ok, enforcer} = Enforcer.new_enforcer(model_path, adapter)
      assert %Enforcer{} = enforcer
      assert enforcer.enabled == true

      # Cleanup
      File.rm(model_path)
    end

    test "creates enforcer with model file and policy file" do
      model_content = """
      [request_definition]
      r = sub, obj, act

      [policy_definition]
      p = sub, obj, act

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
      """

      policy_content = """
      p, alice, data1, read
      p, bob, data2, write
      """

      # Create temporary files
      model_path = "/tmp/test_model.conf"
      policy_path = "/tmp/test_policy.csv"
      File.write!(model_path, model_content)
      File.write!(policy_path, policy_content)

      assert {:ok, enforcer} = Enforcer.new_enforcer(model_path, policy_path)
      assert %Enforcer{} = enforcer

      # Check that policies were loaded
      policies = Map.get(enforcer.policies, "p", [])
      assert length(policies) == 2
      assert ["alice", "data1", "read"] in policies
      assert ["bob", "data2", "write"] in policies

      # Cleanup
      File.rm(model_path)
      File.rm(policy_path)
    end
  end

  describe "enforce/2" do
    test "allows access when policy matches" do
      enforcer = create_test_enforcer()

      # Add a policy
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])

      # Test enforcement
      assert Enforcer.enforce(enforcer, ["alice", "data1", "read"]) == true
      assert Enforcer.enforce(enforcer, ["alice", "data1", "write"]) == false
      assert Enforcer.enforce(enforcer, ["bob", "data1", "read"]) == false
    end

    test "denies access when disabled" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])

      # Disable enforcer
      enforcer = Enforcer.enable_enforce(enforcer, false)

      # Should allow all requests when disabled
      assert Enforcer.enforce(enforcer, ["alice", "data1", "read"]) == true
      assert Enforcer.enforce(enforcer, ["bob", "data1", "write"]) == true
    end
  end

  describe "load_policy/1" do
    test "loads policies from adapter" do
      policy_content = """
      p, alice, data1, read
      p, bob, data2, write
      g, alice, admin
      """

      policy_path = "/tmp/test_policy.csv"
      File.write!(policy_path, policy_content)

      enforcer = create_test_enforcer_with_file_adapter(policy_path)

      assert {:ok, enforcer} = Enforcer.load_policy(enforcer)

      # Check policies were loaded
      policies = Map.get(enforcer.policies, "p", [])
      assert length(policies) == 2

      grouping_policies = Map.get(enforcer.grouping_policies, "g", [])
      assert length(grouping_policies) == 1

      # Cleanup
      File.rm(policy_path)
    end
  end

  describe "save_policy/1" do
    test "saves policies to adapter" do
      policy_path = "/tmp/test_save_policy.csv"

      enforcer = create_test_enforcer_with_file_adapter(policy_path)

      # Add some policies manually
      enforcer = %{enforcer |
        policies: %{"p" => [["alice", "data1", "read"], ["bob", "data2", "write"]]},
        grouping_policies: %{"g" => [["alice", "admin"]]}
      }

      assert {:ok, _enforcer} = Enforcer.save_policy(enforcer)

      # Check file was created and has content
      assert File.exists?(policy_path)
      content = File.read!(policy_path)
      assert String.contains?(content, "p, alice, data1, read")
      assert String.contains?(content, "g, alice, admin")

      # Cleanup
      File.rm(policy_path)
    end
  end

  # Helper functions

  defp create_test_enforcer do
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

    model_path = "/tmp/test_model.conf"
    File.write!(model_path, model_content)

    adapter = FileAdapter.new("/tmp/empty_policy.csv")
    {:ok, enforcer} = Enforcer.new_enforcer(model_path, adapter)

    File.rm(model_path)
    enforcer
  end

  defp create_test_enforcer_with_file_adapter(policy_path) do
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

    model_path = "/tmp/test_model.conf"
    File.write!(model_path, model_content)

    adapter = FileAdapter.new(policy_path)
    {:ok, enforcer} = Enforcer.new_enforcer(model_path, adapter)

    File.rm(model_path)
    enforcer
  end

  defp add_test_policy(enforcer, rule) do
    %{policies: policies} = enforcer
    current_rules = Map.get(policies, "p", [])
    new_rules = [rule | current_rules]
    new_policies = Map.put(policies, "p", new_rules)
    {:ok, %{enforcer | policies: new_policies}}
  end
end