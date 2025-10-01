defmodule CasbinEx2.RBACPermissionTest do
  use ExUnit.Case, async: true

  alias CasbinEx2.Adapter.MemoryAdapter
  alias CasbinEx2.Enforcer
  alias CasbinEx2.Model
  alias CasbinEx2.RBAC

  @model_path "examples/rbac_model.conf"

  setup do
    {:ok, model} = Model.load_model(@model_path)
    adapter = MemoryAdapter.new()
    {:ok, enforcer} = Enforcer.init_with_model_and_adapter(model, adapter)

    {:ok, enforcer: enforcer}
  end

  describe "add_permission_for_user/3" do
    test "adds permission for user successfully", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      assert RBAC.has_permission_for_user(enforcer, "alice", ["data1", "read"]) == true
    end

    test "returns ok when adding duplicate permission", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      assert {:ok, _enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
    end

    test "adds multiple different permissions for same user", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data2", "write"])
      assert RBAC.has_permission_for_user(enforcer, "alice", ["data1", "read"]) == true
      assert RBAC.has_permission_for_user(enforcer, "alice", ["data2", "write"]) == true
    end

    test "adds permission for role", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "admin", ["data1", "read"])
      assert RBAC.has_permission_for_user(enforcer, "admin", ["data1", "read"]) == true
    end
  end

  describe "add_permissions_for_user/3" do
    test "adds multiple permissions for user", %{enforcer: enforcer} do
      permissions = [["data1", "read"], ["data2", "write"], ["data3", "delete"]]
      {:ok, enforcer} = RBAC.add_permissions_for_user(enforcer, "alice", permissions)
      assert RBAC.has_permission_for_user(enforcer, "alice", ["data1", "read"]) == true
      assert RBAC.has_permission_for_user(enforcer, "alice", ["data2", "write"]) == true
      assert RBAC.has_permission_for_user(enforcer, "alice", ["data3", "delete"]) == true
    end

    test "handles empty permission list", %{enforcer: enforcer} do
      {:ok, _enforcer} = RBAC.add_permissions_for_user(enforcer, "alice", [])
      assert RBAC.get_permissions_for_user(enforcer, "alice") == []
    end

    test "succeeds even if some permissions already exist", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])

      permissions = [["data1", "read"], ["data2", "write"]]
      {:ok, enforcer} = RBAC.add_permissions_for_user(enforcer, "alice", permissions)

      assert RBAC.has_permission_for_user(enforcer, "alice", ["data1", "read"]) == true
      assert RBAC.has_permission_for_user(enforcer, "alice", ["data2", "write"]) == true
    end
  end

  describe "delete_permission_for_user/3" do
    test "deletes permission for user successfully", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      {:ok, enforcer} = RBAC.delete_permission_for_user(enforcer, "alice", ["data1", "read"])
      assert RBAC.has_permission_for_user(enforcer, "alice", ["data1", "read"]) == false
    end

    test "returns error when deleting non-existent permission", %{enforcer: enforcer} do
      assert {:error, _} = RBAC.delete_permission_for_user(enforcer, "alice", ["data1", "read"])
    end

    test "does not affect other permissions", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data2", "write"])
      {:ok, enforcer} = RBAC.delete_permission_for_user(enforcer, "alice", ["data1", "read"])
      assert RBAC.has_permission_for_user(enforcer, "alice", ["data1", "read"]) == false
      assert RBAC.has_permission_for_user(enforcer, "alice", ["data2", "write"]) == true
    end
  end

  describe "delete_permissions_for_user/2" do
    test "deletes all permissions for user", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data2", "write"])
      {:ok, enforcer} = RBAC.delete_permissions_for_user(enforcer, "alice")
      assert RBAC.get_permissions_for_user(enforcer, "alice") == []
    end

    test "returns error when user has no permissions", %{enforcer: enforcer} do
      assert {:error, "user has no permissions"} =
               RBAC.delete_permissions_for_user(enforcer, "alice")
    end

    test "does not affect other users", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "bob", ["data2", "write"])
      {:ok, enforcer} = RBAC.delete_permissions_for_user(enforcer, "alice")
      assert RBAC.get_permissions_for_user(enforcer, "alice") == []
      assert length(RBAC.get_permissions_for_user(enforcer, "bob")) == 1
    end
  end

  describe "get_permissions_for_user/2" do
    test "returns empty list for user with no permissions", %{enforcer: enforcer} do
      assert RBAC.get_permissions_for_user(enforcer, "alice") == []
    end

    test "returns single permission for user", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      permissions = RBAC.get_permissions_for_user(enforcer, "alice")
      assert length(permissions) == 1
      assert ["data1", "read"] in permissions
    end

    test "returns multiple permissions for user", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data2", "write"])
      permissions = RBAC.get_permissions_for_user(enforcer, "alice")
      assert length(permissions) == 2
      assert ["data1", "read"] in permissions
      assert ["data2", "write"] in permissions
    end

    test "returns permissions for role", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "admin", ["data1", "read"])
      permissions = RBAC.get_permissions_for_user(enforcer, "admin")
      assert ["data1", "read"] in permissions
    end
  end

  describe "get_permissions_for_user/3 with domain" do
    test "returns permissions for user in specific domain", %{enforcer: enforcer} do
      {:ok, enforcer} =
        RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read", "domain1"])

      {:ok, enforcer} =
        RBAC.add_permission_for_user(enforcer, "alice", ["data2", "write", "domain2"])

      permissions = RBAC.get_permissions_for_user(enforcer, "alice", "domain1")
      assert ["data1", "read"] in permissions
      refute ["data2", "write"] in permissions
    end

    test "returns empty list for non-existent domain", %{enforcer: enforcer} do
      {:ok, enforcer} =
        RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read", "domain1"])

      assert RBAC.get_permissions_for_user(enforcer, "alice", "domain2") == []
    end
  end

  describe "get_named_permissions_for_user/3" do
    test "returns permissions for user in named policy type", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      permissions = RBAC.get_named_permissions_for_user(enforcer, "p", "alice")
      assert ["alice", "data1", "read"] in permissions
    end

    test "returns empty list for non-existent policy type", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      assert RBAC.get_named_permissions_for_user(enforcer, "p2", "alice") == []
    end
  end

  describe "get_named_permissions_for_user/4 with domain" do
    test "returns permissions in specific domain and policy type", %{enforcer: enforcer} do
      {:ok, enforcer} =
        RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read", "domain1"])

      permissions = RBAC.get_named_permissions_for_user(enforcer, "p", "alice", "domain1")
      assert ["alice", "data1", "read", "domain1"] in permissions
    end
  end

  describe "has_permission_for_user/3" do
    test "returns false when user has no permissions", %{enforcer: enforcer} do
      assert RBAC.has_permission_for_user(enforcer, "alice", ["data1", "read"]) == false
    end

    test "returns true when user has permission", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      assert RBAC.has_permission_for_user(enforcer, "alice", ["data1", "read"]) == true
    end

    test "returns false when user has different permission", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      assert RBAC.has_permission_for_user(enforcer, "alice", ["data2", "write"]) == false
    end
  end

  describe "delete_permission/2" do
    test "deletes permission from all users", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "bob", ["data1", "read"])
      {:ok, enforcer} = RBAC.delete_permission(enforcer, ["data1", "read"])
      assert RBAC.has_permission_for_user(enforcer, "alice", ["data1", "read"]) == false
      assert RBAC.has_permission_for_user(enforcer, "bob", ["data1", "read"]) == false
    end

    test "returns error when permission does not exist", %{enforcer: enforcer} do
      assert {:error, "permission does not exist"} =
               RBAC.delete_permission(enforcer, ["data1", "read"])
    end

    test "does not affect other permissions", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data2", "write"])
      {:ok, enforcer} = RBAC.delete_permission(enforcer, ["data1", "read"])
      assert RBAC.has_permission_for_user(enforcer, "alice", ["data2", "write"]) == true
    end
  end

  describe "get_implicit_permissions_for_user/2" do
    test "returns empty list for user with no permissions", %{enforcer: enforcer} do
      assert RBAC.get_implicit_permissions_for_user(enforcer, "alice") == []
    end

    test "returns direct permissions for user", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      permissions = RBAC.get_implicit_permissions_for_user(enforcer, "alice")
      assert ["data1", "read"] in permissions
    end

    test "returns permissions inherited through roles", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "admin", ["data1", "read"])
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      permissions = RBAC.get_implicit_permissions_for_user(enforcer, "alice")
      assert ["data1", "read"] in permissions
    end

    test "combines direct and inherited permissions", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "admin", ["data2", "write"])
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      permissions = RBAC.get_implicit_permissions_for_user(enforcer, "alice")
      assert length(permissions) == 2
      assert ["data1", "read"] in permissions
      assert ["data2", "write"] in permissions
    end

    test "deduplicates permissions", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "admin", ["data1", "read"])
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      permissions = RBAC.get_implicit_permissions_for_user(enforcer, "alice")
      assert length(permissions) == 1
      assert ["data1", "read"] in permissions
    end
  end

  describe "get_implicit_permissions_for_user/3 with domain" do
    test "returns implicit permissions in specific domain", %{enforcer: enforcer} do
      {:ok, enforcer} =
        RBAC.add_permission_for_user(enforcer, "admin", ["data1", "read", "domain1"])

      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin", "domain1")
      permissions = RBAC.get_implicit_permissions_for_user(enforcer, "alice", "domain1")
      assert ["data1", "read"] in permissions
    end

    test "does not return permissions from other domains", %{enforcer: enforcer} do
      {:ok, enforcer} =
        RBAC.add_permission_for_user(enforcer, "admin", ["data1", "read", "domain1"])

      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin", "domain1")
      assert RBAC.get_implicit_permissions_for_user(enforcer, "alice", "domain2") == []
    end
  end

  describe "get_permissions_for_user_in_domain/3" do
    test "returns direct permissions in domain", %{enforcer: enforcer} do
      {:ok, enforcer} =
        RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read", "domain1"])

      permissions = RBAC.get_permissions_for_user_in_domain(enforcer, "alice", "domain1")
      # Function returns full rules including user and domain
      assert ["alice", "data1", "read", "domain1"] in permissions
    end

    test "returns permissions inherited through roles in domain", %{enforcer: enforcer} do
      {:ok, enforcer} =
        RBAC.add_permission_for_user(enforcer, "admin", ["data1", "read", "domain1"])

      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "alice", "admin", "domain1")

      permissions = RBAC.get_permissions_for_user_in_domain(enforcer, "alice", "domain1")
      # Should include admin's permission
      assert ["admin", "data1", "read", "domain1"] in permissions
    end

    test "combines direct and inherited permissions in domain", %{enforcer: enforcer} do
      {:ok, enforcer} =
        RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read", "domain1"])

      {:ok, enforcer} =
        RBAC.add_permission_for_user(enforcer, "admin", ["data2", "write", "domain1"])

      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "alice", "admin", "domain1")

      permissions = RBAC.get_permissions_for_user_in_domain(enforcer, "alice", "domain1")
      assert length(permissions) >= 2
      assert ["alice", "data1", "read", "domain1"] in permissions
      assert ["admin", "data2", "write", "domain1"] in permissions
    end

    test "does not return permissions from other domains", %{enforcer: enforcer} do
      {:ok, enforcer} =
        RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read", "domain1"])

      assert RBAC.get_permissions_for_user_in_domain(enforcer, "alice", "domain2") == []
    end
  end

  describe "permission and role integration" do
    test "user inherits permissions through role", %{enforcer: enforcer} do
      # Create admin role with permissions
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "admin", ["data1", "read"])
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "admin", ["data1", "write"])

      # Assign alice to admin role
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")

      # Alice should inherit admin permissions
      implicit_perms = RBAC.get_implicit_permissions_for_user(enforcer, "alice")
      assert ["data1", "read"] in implicit_perms
      assert ["data1", "write"] in implicit_perms
    end

    test "user has both direct and inherited permissions", %{enforcer: enforcer} do
      # Direct permission
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])

      # Role permission
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "admin", ["data2", "write"])
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")

      implicit_perms = RBAC.get_implicit_permissions_for_user(enforcer, "alice")
      assert ["data1", "read"] in implicit_perms
      assert ["data2", "write"] in implicit_perms
    end

    test "deleting user removes all permissions and roles", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.delete_user(enforcer, "alice")

      assert RBAC.get_permissions_for_user(enforcer, "alice") == []
      assert RBAC.get_roles_for_user(enforcer, "alice") == []
    end

    test "deleting role does not delete permissions", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "admin", ["data1", "read"])
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.delete_role(enforcer, "admin")

      # Role should be gone
      assert RBAC.get_roles_for_user(enforcer, "alice") == []

      # But permission should still exist
      assert ["data1", "read"] in RBAC.get_permissions_for_user(enforcer, "admin")
    end
  end

  describe "edge cases and error handling" do
    test "handles empty permission list", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", [])
      permissions = RBAC.get_permissions_for_user(enforcer, "alice")
      assert permissions == [[]]
    end

    test "handles permission with single element", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["read"])
      assert RBAC.has_permission_for_user(enforcer, "alice", ["read"]) == true
    end

    test "handles permission with many elements", %{enforcer: enforcer} do
      {:ok, enforcer} =
        RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read", "allow", "2024"])

      assert RBAC.has_permission_for_user(enforcer, "alice", [
               "data1",
               "read",
               "allow",
               "2024"
             ]) == true
    end

    test "handles special characters in permission", %{enforcer: enforcer} do
      {:ok, enforcer} =
        RBAC.add_permission_for_user(enforcer, "alice", ["data/path/file.txt", "read"])

      assert RBAC.has_permission_for_user(enforcer, "alice", ["data/path/file.txt", "read"]) ==
               true
    end

    test "handles unicode in permission", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "用户", ["数据", "读取"])
      assert RBAC.has_permission_for_user(enforcer, "用户", ["数据", "读取"]) == true
    end

    test "handles empty string user", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "", ["data1", "read"])
      assert RBAC.has_permission_for_user(enforcer, "", ["data1", "read"]) == true
    end
  end

  describe "concurrent permission operations" do
    test "adding permissions concurrently maintains consistency", %{enforcer: enforcer} do
      users = ["alice", "bob", "charlie"]
      permissions = [["data1", "read"], ["data2", "write"], ["data3", "delete"]]

      # Add permissions sequentially (simulating concurrent in test environment)
      enforcer =
        Enum.reduce(users, enforcer, fn user, acc ->
          Enum.reduce(permissions, acc, fn perm, inner_acc ->
            {:ok, updated} = RBAC.add_permission_for_user(inner_acc, user, perm)
            updated
          end)
        end)

      # Verify all permissions were added
      for user <- users do
        user_perms = RBAC.get_permissions_for_user(enforcer, user)
        assert length(user_perms) == 3
      end
    end
  end

  describe "complex permission scenarios" do
    test "multi-level role hierarchy with permissions", %{enforcer: enforcer} do
      # Create hierarchy: alice -> manager -> admin
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "manager")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "manager", "admin")

      # Add permissions at each level
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "manager", ["data2", "write"])
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "admin", ["data3", "delete"])

      # Alice should have all permissions through hierarchy
      implicit_perms = RBAC.get_implicit_permissions_for_user(enforcer, "alice")
      assert ["data1", "read"] in implicit_perms
      assert ["data2", "write"] in implicit_perms
    end

    test "cross-domain permissions do not interfere", %{enforcer: enforcer} do
      {:ok, enforcer} =
        RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read", "domain1"])

      {:ok, enforcer} =
        RBAC.add_permission_for_user(enforcer, "alice", ["data1", "write", "domain2"])

      perms1 = RBAC.get_permissions_for_user(enforcer, "alice", "domain1")
      perms2 = RBAC.get_permissions_for_user(enforcer, "alice", "domain2")

      assert ["data1", "read"] in perms1
      refute ["data1", "write"] in perms1
      assert ["data1", "write"] in perms2
      refute ["data1", "read"] in perms2
    end
  end
end
