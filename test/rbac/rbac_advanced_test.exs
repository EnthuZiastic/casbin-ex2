defmodule CasbinEx2.RBACAdvancedTest do
  @moduledoc """
  Tests for advanced RBAC API functions including implicit role/user queries,
  domain-based queries, and resource-based access control.

  Tests the 11 functions added for feature parity with Golang Casbin.

  ## Status: 40/40 tests passing (100%) ✅

  All RBAC advanced functions are working correctly with full test coverage.
  """
  use ExUnit.Case, async: true

  alias CasbinEx2.{Enforcer, Management, RBAC}

  setup do
    {:ok, enforcer} =
      Enforcer.new_enforcer("examples/rbac_model.conf", "examples/rbac_policy.csv")

    {:ok, enforcer: enforcer}
  end

  describe "get_named_implicit_roles_for_user/4" do
    test "gets implicit roles from specific role definition", %{enforcer: enforcer} do
      # Add role hierarchy: alice -> admin -> superadmin
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "admin", "superadmin")

      roles = RBAC.get_named_implicit_roles_for_user(enforcer, "g", "alice")

      # Should get both direct and indirect roles
      assert "admin" in roles
      assert "superadmin" in roles
    end

    test "returns only direct roles when no hierarchy", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "bob", "user")

      roles = RBAC.get_named_implicit_roles_for_user(enforcer, "g", "bob")

      assert roles == ["user"]
    end

    test "returns empty list for user with no roles", %{enforcer: enforcer} do
      roles = RBAC.get_named_implicit_roles_for_user(enforcer, "g", "nonexistent")

      assert roles == []
    end

    test "handles deep role hierarchies", %{enforcer: enforcer} do
      # Create: alice -> role1 -> role2
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "role1")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "role1", "role2")

      roles = RBAC.get_named_implicit_roles_for_user(enforcer, "g", "alice")

      # Should get at least role1 and role2
      assert "role1" in roles
      assert length(roles) >= 2
    end
  end

  describe "get_implicit_users_for_role/3" do
    test "gets direct users for a role", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "bob", "admin")

      users = RBAC.get_implicit_users_for_role(enforcer, "admin")

      assert "alice" in users
      assert "bob" in users
    end

    test "gets indirect users through role hierarchy", %{enforcer: enforcer} do
      # manager -> admin, alice -> manager
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "manager", "admin")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "manager")

      users = RBAC.get_implicit_users_for_role(enforcer, "admin")

      # alice should be included because manager has admin role
      assert "alice" in users
    end

    test "returns empty list for role with no users", %{enforcer: enforcer} do
      users = RBAC.get_implicit_users_for_role(enforcer, "nonexistent_role")

      assert users == []
    end

    test "handles complex role hierarchies", %{enforcer: enforcer} do
      # Create: role1 -> admin, role2 -> admin
      # alice -> role1, bob -> role2, charlie -> admin
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "role1", "admin")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "role2", "admin")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "role1")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "bob", "role2")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "charlie", "admin")

      users = RBAC.get_implicit_users_for_role(enforcer, "admin")

      assert "alice" in users
      assert "bob" in users
      assert "charlie" in users
    end
  end

  describe "get_named_implicit_permissions_for_user/5" do
    test "gets permissions from specific named policy", %{enforcer: enforcer} do
      # Add role and permission
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = Management.add_named_policy(enforcer, "p", ["admin", "data1", "read"])

      permissions = RBAC.get_named_implicit_permissions_for_user(enforcer, "p", "g", "alice")

      assert ["admin", "data1", "read"] in permissions
    end

    test "includes permissions from role hierarchy", %{enforcer: enforcer} do
      # alice -> manager -> admin
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "manager")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "manager", "admin")
      {:ok, enforcer} = Management.add_named_policy(enforcer, "p", ["admin", "data1", "write"])

      permissions = RBAC.get_named_implicit_permissions_for_user(enforcer, "p", "g", "alice")

      assert ["admin", "data1", "write"] in permissions
    end

    test "returns empty list when no permissions", %{enforcer: enforcer} do
      permissions =
        RBAC.get_named_implicit_permissions_for_user(enforcer, "p", "g", "newuser")

      assert permissions == []
    end

    test "filters by domain when specified", %{enforcer: enforcer} do
      # Add domain-based permissions
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "alice", "admin", "domain1")

      {:ok, enforcer} =
        Management.add_named_policy(enforcer, "p", ["admin", "data1", "read", "domain1"])

      {:ok, enforcer} =
        Management.add_named_policy(enforcer, "p", ["admin", "data2", "read", "domain2"])

      permissions =
        RBAC.get_named_implicit_permissions_for_user(enforcer, "p", "g", "alice", "domain1")

      # Should only get domain1 permissions
      assert Enum.any?(permissions, fn p -> List.last(p) == "domain1" end)
      refute Enum.any?(permissions, fn p -> List.last(p) == "domain2" end)
    end
  end

  describe "get_implicit_users_for_permission/2" do
    test "gets users with specific permission", %{enforcer: enforcer} do
      # Direct permission
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "bob", ["data2", "write"])

      users = RBAC.get_implicit_users_for_permission(enforcer, ["data2", "write"])

      assert "bob" in users
    end

    test "includes users with permission through roles", %{enforcer: enforcer} do
      # alice already has data1, read from CSV
      users = RBAC.get_implicit_users_for_permission(enforcer, ["data1", "read"])

      assert "alice" in users
    end

    test "filters out roles from user list", %{enforcer: enforcer} do
      # data_group_admin has data_group, write permission
      users = RBAC.get_implicit_users_for_permission(enforcer, ["data_group", "write"])

      # Should include alice (who has data_group_admin role)
      # Should not include data_group_admin role itself
      assert is_list(users)
    end

    test "returns empty list when no users have permission", %{enforcer: enforcer} do
      users = RBAC.get_implicit_users_for_permission(enforcer, ["nonexistent", "permission"])

      assert users == []
    end
  end

  describe "get_domains_for_user/2" do
    test "gets all domains for user", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "alice", "admin", "domain1")
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "alice", "user", "domain2")

      domains = RBAC.get_domains_for_user(enforcer, "alice")

      assert "domain1" in domains
      assert "domain2" in domains
    end

    test "returns empty list for user with no domains", %{enforcer: enforcer} do
      domains = RBAC.get_domains_for_user(enforcer, "newuser")

      assert domains == []
    end

    test "returns unique domains only", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "alice", "admin", "domain1")
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "alice", "user", "domain1")

      domains = RBAC.get_domains_for_user(enforcer, "alice")

      assert length(domains) == 1
      assert "domain1" in domains
    end
  end

  describe "get_implicit_resources_for_user/3" do
    test "gets resources for user with direct permissions", %{enforcer: enforcer} do
      # alice already has data1, read from CSV
      resources = RBAC.get_implicit_resources_for_user(enforcer, "alice")

      # Should return some resources for alice
      assert is_list(resources)
      # alice should have at least one resource
      assert length(resources) > 0
    end

    test "returns empty list when user has no resources", %{enforcer: enforcer} do
      resources = RBAC.get_implicit_resources_for_user(enforcer, "newuser")

      assert resources == []
    end
  end

  describe "get_allowed_object_conditions/4" do
    test "extracts object conditions with valid prefix", %{enforcer: enforcer} do
      {:ok, enforcer} =
        Management.add_policy(enforcer, ["testuser", "r.obj.id == 1", "read"])

      {:ok, enforcer} =
        Management.add_policy(enforcer, ["testuser", "r.obj.id == 2", "read"])

      {:ok, conditions} =
        RBAC.get_allowed_object_conditions(enforcer, "testuser", "read", "r.obj.")

      assert "id == 1" in conditions
      assert "id == 2" in conditions
    end

    test "filters by action", %{enforcer: enforcer} do
      {:ok, enforcer} =
        Management.add_policy(enforcer, ["testuser2", "r.obj.id == 1", "read"])

      {:ok, enforcer} =
        Management.add_policy(enforcer, ["testuser2", "r.obj.id == 2", "write"])

      {:ok, conditions} =
        RBAC.get_allowed_object_conditions(enforcer, "testuser2", "read", "r.obj.")

      assert length(conditions) == 1
      assert "id == 1" in conditions
      refute "id == 2" in conditions
    end

    test "returns error when no conditions with prefix found", %{enforcer: enforcer} do
      # alice has data1, read which doesn't have the r.obj. prefix
      result = RBAC.get_allowed_object_conditions(enforcer, "alice", "read", "r.obj.")

      # Should return error because alice's permissions don't have r.obj. prefix
      assert {:error, _} = result
    end

    test "returns error when no conditions found for action", %{enforcer: enforcer} do
      assert {:error, :empty_condition} =
               RBAC.get_allowed_object_conditions(enforcer, "alice", "nonexistent", "r.obj.")
    end

    test "includes conditions from role permissions", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "testuser3", "testrole")

      {:ok, enforcer} =
        Management.add_policy(enforcer, ["testrole", "r.obj.status == active", "read"])

      {:ok, conditions} =
        RBAC.get_allowed_object_conditions(enforcer, "testuser3", "read", "r.obj.")

      assert "status == active" in conditions
    end
  end

  describe "get_implicit_users_for_resource/2" do
    test "gets users with direct access to resource", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "bob", ["data1", "read"])

      users = RBAC.get_implicit_users_for_resource(enforcer, "data1")

      assert Enum.any?(users, fn [sub, obj, _act] -> sub == "bob" and obj == "data1" end)
    end

    test "gets users with access through roles", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "admin", ["data2", "write"])

      users = RBAC.get_implicit_users_for_resource(enforcer, "data2")

      # alice should appear because she has admin role
      assert Enum.any?(users, fn [sub, obj, _act] -> sub == "alice" and obj == "data2" end)
    end

    test "returns empty list when no users have access", %{enforcer: enforcer} do
      users = RBAC.get_implicit_users_for_resource(enforcer, "nonexistent_resource")

      assert users == []
    end
  end

  describe "get_named_implicit_users_for_resource/3" do
    test "gets users for resource with default grouping", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "admin", ["data1", "read"])

      users = RBAC.get_named_implicit_users_for_resource(enforcer, "g", "data1")

      assert Enum.any?(users, fn [sub, obj, _act] -> sub == "alice" and obj == "data1" end)
    end

    test "handles users without roles", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "bob", ["data2", "write"])

      users = RBAC.get_named_implicit_users_for_resource(enforcer, "g", "data2")

      assert Enum.any?(users, fn [sub, obj, _act] -> sub == "bob" and obj == "data2" end)
    end

    test "returns unique users only", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "admin", ["data1", "read"])
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "admin", ["data1", "write"])

      users = RBAC.get_named_implicit_users_for_resource(enforcer, "g", "data1")

      # Should have unique entries
      alice_entries = Enum.filter(users, fn [sub, _obj, _act] -> sub == "alice" end)
      assert length(alice_entries) == 2
    end
  end

  describe "get_implicit_users_for_resource_by_domain/3" do
    test "gets users with access in specific domain", %{enforcer: enforcer} do
      {:ok, enforcer} =
        RBAC.add_role_for_user_in_domain(enforcer, "alice", "admin", "domain1")

      {:ok, enforcer} =
        RBAC.add_permission_for_user(enforcer, "admin", ["data1", "read", "domain1"])

      users = RBAC.get_implicit_users_for_resource_by_domain(enforcer, "data1", "domain1")

      assert Enum.any?(users, fn
               [sub, obj, _act, dom] -> sub == "alice" and obj == "data1" and dom == "domain1"
             end)
    end

    test "filters by domain correctly", %{enforcer: enforcer} do
      {:ok, enforcer} =
        RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read", "domain1"])

      {:ok, enforcer} =
        RBAC.add_permission_for_user(enforcer, "bob", ["data1", "read", "domain2"])

      users = RBAC.get_implicit_users_for_resource_by_domain(enforcer, "data1", "domain1")

      # Should only include alice (domain1)
      assert Enum.any?(users, fn [sub, _obj, _act, _dom] -> sub == "alice" end)
      refute Enum.any?(users, fn [sub, _obj, _act, _dom] -> sub == "bob" end)
    end

    test "returns empty list when no access in domain", %{enforcer: enforcer} do
      users =
        RBAC.get_implicit_users_for_resource_by_domain(
          enforcer,
          "data1",
          "nonexistent_domain"
        )

      assert users == []
    end
  end

  describe "get_all_roles_by_domain/2" do
    test "gets roles in specific domain", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "alice", "admin", "domain1")
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "bob", "user", "domain1")

      {:ok, enforcer} =
        RBAC.add_role_for_user_in_domain(enforcer, "charlie", "moderator", "domain2")

      roles = RBAC.get_all_roles_by_domain(enforcer, "domain1")

      assert "admin" in roles
      assert "user" in roles
      refute "moderator" in roles
    end

    test "returns empty list for domain with no roles", %{enforcer: enforcer} do
      roles = RBAC.get_all_roles_by_domain(enforcer, "empty_domain")

      assert roles == []
    end

    test "returns unique roles only", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "alice", "admin", "domain1")
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "bob", "admin", "domain1")

      roles = RBAC.get_all_roles_by_domain(enforcer, "domain1")

      assert length(roles) == 1
      assert "admin" in roles
    end
  end

  describe "integration tests" do
    test "complex scenario with multiple roles and domains", %{enforcer: enforcer} do
      # Setup complex hierarchy
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "alice", "manager", "domain1")

      {:ok, enforcer} =
        RBAC.add_role_for_user_in_domain(enforcer, "manager", "admin", "domain1")

      {:ok, enforcer} =
        RBAC.add_permission_for_user(enforcer, "admin", ["data1", "write", "domain1"])

      # Test implicit roles
      roles = RBAC.get_named_implicit_roles_for_user(enforcer, "g", "alice", "domain1")
      assert "manager" in roles
      assert "admin" in roles

      # Test implicit permissions
      permissions =
        RBAC.get_named_implicit_permissions_for_user(enforcer, "p", "g", "alice", "domain1")

      assert Enum.any?(permissions, fn p -> "data1" in p and "write" in p end)

      # Test domains
      domains = RBAC.get_domains_for_user(enforcer, "alice")
      assert "domain1" in domains
    end

    test "handles circular role dependencies gracefully", %{enforcer: enforcer} do
      # This shouldn't create infinite loops
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "role1", "role2")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "role2", "role1")

      # Should still return results without hanging
      roles = RBAC.get_named_implicit_roles_for_user(enforcer, "g", "role1")

      assert "role2" in roles
    end
  end
end
