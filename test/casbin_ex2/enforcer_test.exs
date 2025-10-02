defmodule CasbinEx2.EnforcerTest do
  use ExUnit.Case

  alias CasbinEx2.Adapter.FileAdapter
  alias CasbinEx2.Enforcer

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

  describe "enforce_ex/2" do
    test "returns result with explanation" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])

      # Test enforcement with explanations
      assert {true, explanations} = Enforcer.enforce_ex(enforcer, ["alice", "data1", "read"])
      assert is_list(explanations)
      assert length(explanations) > 0

      assert {false, explanations} = Enforcer.enforce_ex(enforcer, ["alice", "data1", "write"])
      assert is_list(explanations)
    end

    test "returns disabled explanation when enforcer disabled" do
      enforcer = create_test_enforcer()
      enforcer = Enforcer.enable_enforce(enforcer, false)

      assert {true, ["Enforcer disabled"]} =
               Enforcer.enforce_ex(enforcer, ["alice", "data1", "read"])
    end
  end

  describe "enforce_with_matcher/3" do
    test "enforces with custom matcher" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["bob", "data2", "read"])

      # Custom matcher that matches based on existing policies
      custom_matcher = "r.sub == p.sub && r.obj == p.obj && r.act == p.act"

      assert Enforcer.enforce_with_matcher(enforcer, custom_matcher, ["alice", "data1", "read"]) ==
               true

      assert Enforcer.enforce_with_matcher(enforcer, custom_matcher, ["bob", "data2", "read"]) ==
               true

      assert Enforcer.enforce_with_matcher(enforcer, custom_matcher, ["bob", "data2", "write"]) ==
               false
    end

    test "returns true when disabled" do
      enforcer = create_test_enforcer()
      enforcer = Enforcer.enable_enforce(enforcer, false)

      assert Enforcer.enforce_with_matcher(enforcer, "r.act == 'read'", [
               "alice",
               "data1",
               "write"
             ]) == true
    end
  end

  describe "enforce_ex_with_matcher/3" do
    test "returns result with explanation using custom matcher" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])

      custom_matcher = "r.act == 'read'"

      assert {result, explanations} =
               Enforcer.enforce_ex_with_matcher(enforcer, custom_matcher, ["bob", "data2", "read"])

      assert is_boolean(result)
      assert is_list(explanations)
    end

    test "returns disabled explanation when enforcer disabled" do
      enforcer = create_test_enforcer()
      enforcer = Enforcer.enable_enforce(enforcer, false)

      assert {true, ["Enforcer disabled"]} =
               Enforcer.enforce_ex_with_matcher(enforcer, "r.act == 'read'", [
                 "alice",
                 "data1",
                 "read"
               ])
    end
  end

  describe "batch_enforce/2" do
    test "handles small batches sequentially" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["bob", "data2", "write"])

      requests = [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"],
        ["charlie", "data3", "read"]
      ]

      results = Enforcer.batch_enforce(enforcer, requests)
      assert results == [true, true, false]
    end

    test "handles large batches concurrently" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])

      # Create 15 requests to trigger concurrent processing
      requests =
        for i <- 1..15 do
          if i == 1, do: ["alice", "data1", "read"], else: ["user#{i}", "data#{i}", "read"]
        end

      results = Enforcer.batch_enforce(enforcer, requests)
      assert length(results) == 15
      assert List.first(results) == true
      assert Enum.drop(results, 1) |> Enum.all?(&(&1 == false))
    end
  end

  describe "batch_enforce_ex/2" do
    test "returns batch results with explanations" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])

      requests = [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"]
      ]

      results = Enforcer.batch_enforce_ex(enforcer, requests)
      assert length(results) == 2
      assert {true, _explanations} = Enum.at(results, 0)
      assert {false, _explanations} = Enum.at(results, 1)
    end

    test "handles large batches concurrently with explanations" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])

      # Create 12 requests to trigger concurrent processing
      requests =
        for i <- 1..12 do
          if i == 1, do: ["alice", "data1", "read"], else: ["user#{i}", "data#{i}", "read"]
        end

      results = Enforcer.batch_enforce_ex(enforcer, requests)
      assert length(results) == 12
      assert {true, _explanations} = List.first(results)
    end
  end

  describe "batch_enforce_with_matcher/3" do
    test "batch enforcement with custom matcher" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])

      custom_matcher = "r.act == 'read'"

      requests = [
        ["bob", "data2", "read"],
        ["charlie", "data3", "write"]
      ]

      results = Enforcer.batch_enforce_with_matcher(enforcer, custom_matcher, requests)
      assert length(results) == 2
      # Results depend on custom matcher implementation
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
      enforcer = %{
        enforcer
        | policies: %{"p" => [["alice", "data1", "read"], ["bob", "data2", "write"]]},
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

  describe "management APIs" do
    test "get_all_subjects returns all policy subjects" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["bob", "data2", "write"])
      {:ok, enforcer} = add_test_policy(enforcer, ["charlie", "data3", "read"])

      subjects = Enforcer.get_all_subjects(enforcer)
      assert "alice" in subjects
      assert "bob" in subjects
      assert "charlie" in subjects
      assert length(subjects) == 3
    end

    test "get_all_objects returns all policy objects" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["bob", "data2", "write"])
      {:ok, enforcer} = add_test_policy(enforcer, ["charlie", "data1", "read"])

      objects = Enforcer.get_all_objects(enforcer)
      assert "data1" in objects
      assert "data2" in objects
      assert length(objects) == 2
    end

    test "get_all_actions returns all policy actions" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["bob", "data2", "write"])
      {:ok, enforcer} = add_test_policy(enforcer, ["charlie", "data3", "read"])

      actions = Enforcer.get_all_actions(enforcer)
      assert "read" in actions
      assert "write" in actions
      assert length(actions) == 2
    end

    test "get_all_roles returns all grouping policy roles" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "admin"])
      {:ok, enforcer} = Enforcer.add_named_grouping_policy(enforcer, "g", ["bob", "user"])
      {:ok, enforcer} = Enforcer.add_named_grouping_policy(enforcer, "g", ["charlie", "admin"])

      roles = Enforcer.get_all_roles(enforcer)
      assert "admin" in roles
      assert "user" in roles
      assert length(roles) == 2
    end

    test "get_all_domains returns all domains from policies and grouping policies" do
      enforcer = create_test_enforcer()
      # Add grouping policies with domains (using 3-element format: user, role, domain)
      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "admin", "domain1"])

      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["bob", "user", "domain2"])

      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["charlie", "admin", "domain1"])

      domains = Enforcer.get_all_domains(enforcer)
      assert "domain1" in domains
      assert "domain2" in domains
      assert length(domains) >= 2
    end
  end

  describe "policy update operations" do
    test "update_policy changes existing policy" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])

      old_policy = ["alice", "data1", "read"]
      new_policy = ["alice", "data1", "write"]

      assert {:ok, enforcer} = Enforcer.update_policy(enforcer, old_policy, new_policy)

      policies = Enforcer.get_policy(enforcer)
      assert new_policy in policies
      assert old_policy not in policies
    end

    test "update_policy returns error for non-existent policy" do
      enforcer = create_test_enforcer()

      old_policy = ["alice", "data1", "read"]
      new_policy = ["alice", "data1", "write"]

      assert {:error, :not_found} = Enforcer.update_policy(enforcer, old_policy, new_policy)
    end

    test "update_policies changes multiple policies" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["bob", "data2", "write"])

      old_policies = [["alice", "data1", "read"], ["bob", "data2", "write"]]
      new_policies = [["alice", "data1", "write"], ["bob", "data2", "read"]]

      assert {:ok, enforcer} = Enforcer.update_policies(enforcer, old_policies, new_policies)

      policies = Enforcer.get_policy(enforcer)
      assert ["alice", "data1", "write"] in policies
      assert ["bob", "data2", "read"] in policies
      assert ["alice", "data1", "read"] not in policies
      assert ["bob", "data2", "write"] not in policies
    end

    test "update_grouping_policy changes existing grouping policy" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "admin"])

      old_rule = ["alice", "admin"]
      new_rule = ["alice", "user"]

      assert {:ok, enforcer} = Enforcer.update_grouping_policy(enforcer, old_rule, new_rule)

      grouping_policies = Enforcer.get_grouping_policy(enforcer)
      assert new_rule in grouping_policies
      assert old_rule not in grouping_policies
    end

    test "update_grouping_policies changes multiple grouping policies" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "admin"])
      {:ok, enforcer} = Enforcer.add_named_grouping_policy(enforcer, "g", ["bob", "user"])

      old_rules = [["alice", "admin"], ["bob", "user"]]
      new_rules = [["alice", "user"], ["bob", "admin"]]

      assert {:ok, enforcer} = Enforcer.update_grouping_policies(enforcer, old_rules, new_rules)

      grouping_policies = Enforcer.get_grouping_policy(enforcer)
      assert ["alice", "user"] in grouping_policies
      assert ["bob", "admin"] in grouping_policies
      assert ["alice", "admin"] not in grouping_policies
      assert ["bob", "user"] not in grouping_policies
    end
  end

  describe "complete RBAC APIs" do
    test "delete_user removes user from all policies and grouping policies" do
      enforcer = create_test_enforcer()
      # Add policies and roles for alice
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data2", "write"])
      {:ok, enforcer} = Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "admin"])

      assert {:ok, enforcer} = Enforcer.delete_user(enforcer, "alice")

      # Check alice is removed from all policies
      policies = Enforcer.get_policy(enforcer)
      assert not Enum.any?(policies, fn [user | _] -> user == "alice" end)

      # Check alice is removed from all grouping policies
      grouping_policies = Enforcer.get_grouping_policy(enforcer)
      assert not Enum.any?(grouping_policies, fn [user | _] -> user == "alice" end)
    end

    test "delete_role removes role from all grouping policies" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "admin"])
      {:ok, enforcer} = Enforcer.add_named_grouping_policy(enforcer, "g", ["bob", "admin"])
      {:ok, enforcer} = Enforcer.add_named_grouping_policy(enforcer, "g", ["charlie", "user"])

      assert {:ok, enforcer} = Enforcer.delete_role(enforcer, "admin")

      grouping_policies = Enforcer.get_grouping_policy(enforcer)
      assert not Enum.any?(grouping_policies, fn [_user, role | _] -> role == "admin" end)
      assert Enum.any?(grouping_policies, fn [_user, role | _] -> role == "user" end)
    end

    test "delete_permission removes permission from all policies" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["bob", "data1", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["charlie", "data2", "write"])

      assert {:ok, enforcer} = Enforcer.delete_permission(enforcer, ["data1", "read"])

      policies = Enforcer.get_policy(enforcer)
      assert not Enum.any?(policies, fn [_user | perm] -> perm == ["data1", "read"] end)
      assert Enum.any?(policies, fn [_user | perm] -> perm == ["data2", "write"] end)
    end

    test "get_users_for_permission returns users with specific permission" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["bob", "data1", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["charlie", "data2", "write"])

      users = Enforcer.get_users_for_permission(enforcer, ["data1", "read"])
      assert "alice" in users
      assert "bob" in users
      assert "charlie" not in users
      assert length(users) == 2
    end

    test "add_roles_for_user adds multiple roles at once" do
      enforcer = create_test_enforcer()
      roles = ["admin", "user", "editor"]

      assert {:ok, enforcer} = Enforcer.add_roles_for_user(enforcer, "alice", roles)

      grouping_policies = Enforcer.get_grouping_policy(enforcer)
      assert ["alice", "admin"] in grouping_policies
      assert ["alice", "user"] in grouping_policies
      assert ["alice", "editor"] in grouping_policies
    end

    test "add_permissions_for_user adds multiple permissions at once" do
      enforcer = create_test_enforcer()
      permissions = [["data1", "read"], ["data2", "write"], ["data3", "read"]]

      assert {:ok, enforcer} = Enforcer.add_permissions_for_user(enforcer, "alice", permissions)

      policies = Enforcer.get_policy(enforcer)
      assert ["alice", "data1", "read"] in policies
      assert ["alice", "data2", "write"] in policies
      assert ["alice", "data3", "read"] in policies
    end

    test "delete_permissions_for_user removes all permissions for user" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data2", "write"])
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data3", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["bob", "data1", "read"])

      assert {:ok, enforcer} = Enforcer.delete_permissions_for_user(enforcer, "alice")

      policies = Enforcer.get_policy(enforcer)
      assert ["alice", "data1", "read"] not in policies
      assert ["alice", "data3", "read"] not in policies
      assert ["alice", "data2", "write"] not in policies
      # Bob's permissions should remain
      assert ["bob", "data1", "read"] in policies
    end

    test "get_implicit_permissions_for_user returns direct and role-based permissions" do
      enforcer = create_test_enforcer()
      # Add direct permission
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])
      # Add role and role permission
      {:ok, enforcer} = Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "admin"])
      {:ok, enforcer} = add_test_policy(enforcer, ["admin", "data2", "write"])

      permissions = Enforcer.get_implicit_permissions_for_user(enforcer, "alice")
      assert ["alice", "data1", "read"] in permissions
      assert ["admin", "data2", "write"] in permissions
    end

    test "get_implicit_roles_for_user returns roles for user" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "admin"])
      {:ok, enforcer} = Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "user"])

      roles = Enforcer.get_implicit_roles_for_user(enforcer, "alice")
      assert "admin" in roles
      assert "user" in roles
    end

    test "has_permission_for_user checks if user has specific permission" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])

      # has_permission_for_user works on the policy level, not just permissions
      assert Enforcer.has_permission_for_user(enforcer, "alice", ["data1", "read"]) == true
      assert Enforcer.has_permission_for_user(enforcer, "alice", ["data2", "write"]) == false
    end
  end

  describe "domain-specific RBAC APIs" do
    test "get_users_for_role_in_domain returns users for role in specific domain" do
      enforcer = create_test_enforcer()

      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "admin", "domain1"])

      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["bob", "admin", "domain1"])

      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["charlie", "admin", "domain2"])

      users = Enforcer.get_users_for_role_in_domain(enforcer, "admin", "domain1")
      assert "alice" in users
      assert "bob" in users
      assert "charlie" not in users
    end

    test "get_roles_for_user_in_domain returns roles for user in specific domain" do
      enforcer = create_test_enforcer()

      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "admin", "domain1"])

      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "user", "domain1"])

      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "editor", "domain2"])

      roles = Enforcer.get_roles_for_user_in_domain(enforcer, "alice", "domain1")
      assert "admin" in roles
      assert "user" in roles
      assert "editor" not in roles
    end

    test "add_role_for_user_in_domain adds role in specific domain" do
      enforcer = create_test_enforcer()

      assert {:ok, enforcer} =
               Enforcer.add_role_for_user_in_domain(enforcer, "alice", "admin", "domain1")

      grouping_policies = Enforcer.get_grouping_policy(enforcer)
      assert ["alice", "admin", "domain1"] in grouping_policies
    end

    test "delete_role_for_user_in_domain removes role in specific domain" do
      enforcer = create_test_enforcer()

      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "admin", "domain1"])

      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "admin", "domain2"])

      assert {:ok, enforcer} =
               Enforcer.delete_role_for_user_in_domain(enforcer, "alice", "admin", "domain1")

      grouping_policies = Enforcer.get_grouping_policy(enforcer)
      assert ["alice", "admin", "domain1"] not in grouping_policies
      assert ["alice", "admin", "domain2"] in grouping_policies
    end

    test "delete_roles_for_user_in_domain removes all roles for user in domain" do
      enforcer = create_test_enforcer()

      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "admin", "domain1"])

      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "user", "domain1"])

      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "editor", "domain2"])

      assert {:ok, enforcer} =
               Enforcer.delete_roles_for_user_in_domain(enforcer, "alice", "domain1")

      grouping_policies = Enforcer.get_grouping_policy(enforcer)
      assert ["alice", "admin", "domain1"] not in grouping_policies
      assert ["alice", "user", "domain1"] not in grouping_policies
      assert ["alice", "editor", "domain2"] in grouping_policies
    end

    test "get_all_users_by_domain returns users in specific domain" do
      enforcer = create_test_enforcer()

      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "admin", "domain1"])

      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["bob", "user", "domain1"])

      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["charlie", "admin", "domain2"])

      users = Enforcer.get_all_users_by_domain(enforcer, "domain1")
      assert "alice" in users
      assert "bob" in users
      assert "charlie" not in users
    end

    test "delete_all_users_by_domain removes all users in domain" do
      enforcer = create_test_enforcer()

      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["alice", "admin", "domain1"])

      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["bob", "user", "domain1"])

      {:ok, enforcer} =
        Enforcer.add_named_grouping_policy(enforcer, "g", ["charlie", "admin", "domain2"])

      assert {:ok, enforcer} = Enforcer.delete_all_users_by_domain(enforcer, "domain1")

      grouping_policies = Enforcer.get_grouping_policy(enforcer)

      assert not Enum.any?(grouping_policies, fn [_user, _role, domain] -> domain == "domain1" end)

      assert Enum.any?(grouping_policies, fn [_user, _role, domain] -> domain == "domain2" end)
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
    g = _, _, _

    [policy_effect]
    e = some(where (p.eft == allow))

    [matchers]
    m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
    """

    # Use unique file names for each test
    test_id = :erlang.unique_integer([:positive])
    model_path = "/tmp/test_model_#{test_id}.conf"
    policy_path = "/tmp/test_policy_#{test_id}.csv"

    File.write!(model_path, model_content)
    # Create empty policy file
    File.write!(policy_path, "")

    adapter = FileAdapter.new(policy_path)
    {:ok, enforcer} = Enforcer.new_enforcer(model_path, adapter)

    # Clean up the model file but keep policy file for test duration
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
    g = _, _, _

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

  describe "batch enforcement APIs" do
    test "batch_enforce processes multiple requests efficiently" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["bob", "data2", "write"])
      {:ok, enforcer} = add_test_policy(enforcer, ["charlie", "data3", "read"])

      # Test small batch (sequential processing)
      requests = [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"],
        ["alice", "data2", "write"],
        ["charlie", "data3", "read"]
      ]

      results = Enforcer.batch_enforce(enforcer, requests)
      assert results == [true, true, false, true]
    end

    test "batch_enforce handles large batches with concurrent processing" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])

      # Create a large batch (>10 requests) to trigger concurrent processing
      requests = for _i <- 1..15, do: ["alice", "data1", "read"]

      results = Enforcer.batch_enforce(enforcer, requests)
      assert length(results) == 15
      assert Enum.all?(results, fn result -> result == true end)
    end

    test "batch_enforce_with_matcher processes requests with custom matcher" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])

      # Custom matcher that always allows
      custom_matcher = "r.sub == p.sub && r.obj == p.obj && r.act == p.act"

      requests = [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"]
      ]

      results = Enforcer.batch_enforce_with_matcher(enforcer, custom_matcher, requests)
      assert length(results) == 2
      # Alice should match
      assert hd(results) == true
      # Bob should not match
      assert hd(tl(results)) == false
    end

    test "batch_enforce_ex returns decisions with explanations" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])

      requests = [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"]
      ]

      results = Enforcer.batch_enforce_ex(enforcer, requests)
      assert length(results) == 2

      [{decision1, explanation1}, {decision2, explanation2}] = results
      assert decision1 == true
      assert is_list(explanation1)
      assert decision2 == false
      assert is_list(explanation2)
    end
  end

  describe "filtered policy operations" do
    test "remove_filtered_policy removes policies matching filter criteria" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data2", "write"])
      {:ok, enforcer} = add_test_policy(enforcer, ["bob", "data1", "read"])

      # Remove all policies for alice (field_index 0, value "alice")
      assert {:ok, enforcer} = Enforcer.remove_filtered_policy(enforcer, 0, ["alice"])

      policies = Enforcer.get_policy(enforcer)
      assert ["alice", "data1", "read"] not in policies
      assert ["alice", "data2", "write"] not in policies
      assert ["bob", "data1", "read"] in policies
    end

    test "remove_filtered_named_policy removes policies from specific policy type" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data2", "write"])
      {:ok, enforcer} = add_test_policy(enforcer, ["bob", "data1", "read"])

      # Remove policies with "data1" object (field_index 1, value "data1")
      assert {:ok, enforcer} = Enforcer.remove_filtered_named_policy(enforcer, "p", 1, ["data1"])

      policies = Enforcer.get_policy(enforcer)
      assert ["alice", "data1", "read"] not in policies
      assert ["bob", "data1", "read"] not in policies
      assert ["alice", "data2", "write"] in policies
    end

    test "remove_filtered_policy with multiple field values" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "write"])
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data2", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["bob", "data1", "read"])

      # Remove policies for alice with data1 (field_index 0, values ["alice", "data1"])
      assert {:ok, enforcer} = Enforcer.remove_filtered_policy(enforcer, 0, ["alice", "data1"])

      policies = Enforcer.get_policy(enforcer)
      assert ["alice", "data1", "read"] not in policies
      assert ["alice", "data1", "write"] not in policies
      assert ["alice", "data2", "read"] in policies
      assert ["bob", "data1", "read"] in policies
    end

    test "get_filtered_policy returns policies matching criteria" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data2", "write"])
      {:ok, enforcer} = add_test_policy(enforcer, ["bob", "data1", "read"])

      # Get all policies for alice
      filtered_policies = Enforcer.get_filtered_policy(enforcer, 0, ["alice"])
      assert ["alice", "data1", "read"] in filtered_policies
      assert ["alice", "data2", "write"] in filtered_policies
      assert ["bob", "data1", "read"] not in filtered_policies
      assert length(filtered_policies) == 2
    end

    test "get_filtered_named_policy returns policies from specific type" do
      enforcer = create_test_enforcer()
      {:ok, enforcer} = add_test_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["bob", "data1", "read"])
      {:ok, enforcer} = add_test_policy(enforcer, ["charlie", "data2", "write"])

      # Get all policies with "read" action (field_index 2, value "read")
      filtered_policies = Enforcer.get_filtered_named_policy(enforcer, "p", 2, ["read"])
      assert ["alice", "data1", "read"] in filtered_policies
      assert ["bob", "data1", "read"] in filtered_policies
      assert ["charlie", "data2", "write"] not in filtered_policies
      assert length(filtered_policies) == 2
    end
  end
end
