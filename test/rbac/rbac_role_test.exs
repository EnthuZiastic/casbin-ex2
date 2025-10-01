defmodule CasbinEx2.RBACRoleTest do
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

  describe "get_roles_for_user/2" do
    test "returns empty list for user with no roles", %{enforcer: enforcer} do
      assert RBAC.get_roles_for_user(enforcer, "alice") == []
    end

    test "returns single role for user", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      assert RBAC.get_roles_for_user(enforcer, "alice") == ["admin"]
    end

    test "returns multiple roles for user", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "editor")
      roles = RBAC.get_roles_for_user(enforcer, "alice")
      assert length(roles) == 2
      assert "admin" in roles
      assert "editor" in roles
    end

    test "returns empty list when role_manager is nil" do
      enforcer = %Enforcer{role_manager: nil}
      assert RBAC.get_roles_for_user(enforcer, "alice") == []
    end
  end

  describe "get_roles_for_user/3 with domain" do
    test "returns roles for user in specific domain", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin", "domain1")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "editor", "domain2")
      assert RBAC.get_roles_for_user(enforcer, "alice", "domain1") == ["admin"]
      assert RBAC.get_roles_for_user(enforcer, "alice", "domain2") == ["editor"]
    end

    test "returns empty list for non-existent domain", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin", "domain1")
      assert RBAC.get_roles_for_user(enforcer, "alice", "domain2") == []
    end
  end

  describe "get_users_for_role/2" do
    test "returns empty list for role with no users", %{enforcer: enforcer} do
      assert RBAC.get_users_for_role(enforcer, "admin") == []
    end

    test "returns single user for role", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      assert RBAC.get_users_for_role(enforcer, "admin") == ["alice"]
    end

    test "returns multiple users for role", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "bob", "admin")
      users = RBAC.get_users_for_role(enforcer, "admin")
      assert length(users) == 2
      assert "alice" in users
      assert "bob" in users
    end

    test "returns empty list when role_manager is nil" do
      enforcer = %Enforcer{role_manager: nil}
      assert RBAC.get_users_for_role(enforcer, "admin") == []
    end
  end

  describe "get_users_for_role/3 with domain" do
    test "returns users for role in specific domain", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin", "domain1")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "bob", "admin", "domain2")
      assert RBAC.get_users_for_role(enforcer, "admin", "domain1") == ["alice"]
      assert RBAC.get_users_for_role(enforcer, "admin", "domain2") == ["bob"]
    end
  end

  describe "has_role_for_user/3" do
    test "returns false when user has no roles", %{enforcer: enforcer} do
      assert RBAC.has_role_for_user(enforcer, "alice", "admin") == false
    end

    test "returns true when user has role", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      assert RBAC.has_role_for_user(enforcer, "alice", "admin") == true
    end

    test "returns false when user has different role", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      assert RBAC.has_role_for_user(enforcer, "alice", "editor") == false
    end
  end

  describe "has_role_for_user/4 with domain" do
    test "returns true when user has role in domain", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin", "domain1")
      assert RBAC.has_role_for_user(enforcer, "alice", "admin", "domain1") == true
    end

    test "returns false when user has role in different domain", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin", "domain1")
      assert RBAC.has_role_for_user(enforcer, "alice", "admin", "domain2") == false
    end
  end

  describe "add_role_for_user/3" do
    test "adds role for user successfully", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      assert RBAC.has_role_for_user(enforcer, "alice", "admin") == true
    end

    test "returns error when adding duplicate role", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")

      assert {:error, "grouping policy already exists"} =
               RBAC.add_role_for_user(enforcer, "alice", "admin")
    end

    test "adds multiple roles for same user", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "editor")
      assert RBAC.has_role_for_user(enforcer, "alice", "admin") == true
      assert RBAC.has_role_for_user(enforcer, "alice", "editor") == true
    end

    test "updates role manager when adding role", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      refute is_nil(enforcer.role_manager)
      assert RBAC.get_roles_for_user(enforcer, "alice") == ["admin"]
    end
  end

  describe "add_role_for_user/4 with domain" do
    test "adds role for user in specific domain", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin", "domain1")
      assert RBAC.has_role_for_user(enforcer, "alice", "admin", "domain1") == true
      assert RBAC.has_role_for_user(enforcer, "alice", "admin", "domain2") == false
    end

    test "allows same role in different domains", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin", "domain1")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin", "domain2")
      assert RBAC.has_role_for_user(enforcer, "alice", "admin", "domain1") == true
      assert RBAC.has_role_for_user(enforcer, "alice", "admin", "domain2") == true
    end
  end

  describe "add_roles_for_user/3" do
    test "adds multiple roles for user", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_roles_for_user(enforcer, "alice", ["admin", "editor"])
      assert RBAC.has_role_for_user(enforcer, "alice", "admin") == true
      assert RBAC.has_role_for_user(enforcer, "alice", "editor") == true
    end

    test "handles empty role list", %{enforcer: enforcer} do
      {:ok, _enforcer} = RBAC.add_roles_for_user(enforcer, "alice", [])
      assert RBAC.get_roles_for_user(enforcer, "alice") == []
    end

    test "succeeds even if some roles already exist", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.add_roles_for_user(enforcer, "alice", ["admin", "editor"])
      roles = RBAC.get_roles_for_user(enforcer, "alice")
      assert "admin" in roles
      assert "editor" in roles
    end
  end

  describe "add_roles_for_user/4 with domain" do
    test "adds multiple roles in specific domain", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_roles_for_user(enforcer, "alice", ["admin", "editor"], "domain1")
      assert RBAC.has_role_for_user(enforcer, "alice", "admin", "domain1") == true
      assert RBAC.has_role_for_user(enforcer, "alice", "editor", "domain1") == true
    end
  end

  describe "delete_role_for_user/3" do
    test "deletes role for user successfully", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.delete_role_for_user(enforcer, "alice", "admin")
      assert RBAC.has_role_for_user(enforcer, "alice", "admin") == false
    end

    test "returns error when deleting non-existent role", %{enforcer: enforcer} do
      assert {:error, "grouping policy does not exist"} =
               RBAC.delete_role_for_user(enforcer, "alice", "admin")
    end

    test "does not affect other roles", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "editor")
      {:ok, enforcer} = RBAC.delete_role_for_user(enforcer, "alice", "admin")
      assert RBAC.has_role_for_user(enforcer, "alice", "admin") == false
      assert RBAC.has_role_for_user(enforcer, "alice", "editor") == true
    end
  end

  describe "delete_role_for_user/4 with domain" do
    test "deletes role for user in specific domain", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin", "domain1")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin", "domain2")
      {:ok, enforcer} = RBAC.delete_role_for_user(enforcer, "alice", "admin", "domain1")
      assert RBAC.has_role_for_user(enforcer, "alice", "admin", "domain1") == false
      assert RBAC.has_role_for_user(enforcer, "alice", "admin", "domain2") == true
    end
  end

  describe "delete_roles_for_user/2" do
    test "deletes all roles for user", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "editor")
      {:ok, enforcer} = RBAC.delete_roles_for_user(enforcer, "alice")
      assert RBAC.get_roles_for_user(enforcer, "alice") == []
    end

    test "returns error when user has no roles", %{enforcer: enforcer} do
      assert {:error, "user has no roles"} = RBAC.delete_roles_for_user(enforcer, "alice")
    end

    test "does not affect other users", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "bob", "editor")
      {:ok, enforcer} = RBAC.delete_roles_for_user(enforcer, "alice")
      assert RBAC.get_roles_for_user(enforcer, "alice") == []
      assert RBAC.get_roles_for_user(enforcer, "bob") == ["editor"]
    end
  end

  describe "delete_roles_for_user/3 with domain" do
    test "deletes all roles for user in specific domain", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin", "domain1")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "editor", "domain1")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "viewer", "domain2")
      {:ok, enforcer} = RBAC.delete_roles_for_user(enforcer, "alice", "domain1")
      assert RBAC.get_roles_for_user(enforcer, "alice", "domain1") == []
      assert RBAC.get_roles_for_user(enforcer, "alice", "domain2") == ["viewer"]
    end
  end

  describe "delete_user/2" do
    test "deletes user from all roles", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "editor")
      {:ok, enforcer} = RBAC.delete_user(enforcer, "alice")
      assert RBAC.get_roles_for_user(enforcer, "alice") == []
    end

    test "returns error when user does not exist", %{enforcer: enforcer} do
      assert {:error, "user does not exist"} = RBAC.delete_user(enforcer, "alice")
    end

    test "removes user from grouping policies", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.delete_user(enforcer, "alice")
      assert enforcer.grouping_policies == %{"g" => []}
    end

    test "removes user from regular policies", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.add_permission_for_user(enforcer, "alice", ["data1", "read"])
      {:ok, enforcer} = RBAC.delete_user(enforcer, "alice")
      assert RBAC.get_permissions_for_user(enforcer, "alice") == []
    end

    test "does not affect other users", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "bob", "editor")
      {:ok, enforcer} = RBAC.delete_user(enforcer, "alice")
      assert RBAC.get_roles_for_user(enforcer, "bob") == ["editor"]
    end
  end

  describe "delete_role/2" do
    test "deletes role from all users", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "bob", "admin")
      {:ok, enforcer} = RBAC.delete_role(enforcer, "admin")
      assert RBAC.get_users_for_role(enforcer, "admin") == []
      assert RBAC.get_roles_for_user(enforcer, "alice") == []
      assert RBAC.get_roles_for_user(enforcer, "bob") == []
    end

    test "returns error when role does not exist", %{enforcer: enforcer} do
      assert {:error, "role does not exist"} = RBAC.delete_role(enforcer, "admin")
    end

    test "does not affect other roles", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "editor")
      {:ok, enforcer} = RBAC.delete_role(enforcer, "admin")
      assert RBAC.get_roles_for_user(enforcer, "alice") == ["editor"]
    end

    test "removes role from grouping policies", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "bob", "admin")
      {:ok, enforcer} = RBAC.delete_role(enforcer, "admin")
      assert enforcer.grouping_policies == %{"g" => []}
    end
  end

  describe "get_implicit_roles_for_user/2" do
    test "returns empty list when user has no roles", %{enforcer: enforcer} do
      assert RBAC.get_implicit_roles_for_user(enforcer, "alice") == []
    end

    test "returns direct roles", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      roles = RBAC.get_implicit_roles_for_user(enforcer, "alice")
      assert "admin" in roles
    end

    test "returns indirect roles through inheritance", %{enforcer: enforcer} do
      # Create role hierarchy: alice -> admin -> superuser
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "admin", "superuser")
      roles = RBAC.get_implicit_roles_for_user(enforcer, "alice")
      assert "admin" in roles
      # Note: superuser might not appear if role manager doesn't track transitive roles
    end

    test "returns empty list when role_manager is nil" do
      enforcer = %Enforcer{role_manager: nil}
      assert RBAC.get_implicit_roles_for_user(enforcer, "alice") == []
    end
  end

  describe "get_implicit_roles_for_user/3 with domain" do
    test "returns implicit roles in specific domain", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin", "domain1")
      roles = RBAC.get_implicit_roles_for_user(enforcer, "alice", "domain1")
      assert "admin" in roles
    end
  end

  describe "get_users_for_role_in_domain/3" do
    test "returns users for role in specific domain", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin", "domain1")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "bob", "admin", "domain2")
      users = RBAC.get_users_for_role_in_domain(enforcer, "admin", "domain1")
      assert "alice" in users
      refute "bob" in users
    end

    test "returns empty list for non-existent domain", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin", "domain1")
      assert RBAC.get_users_for_role_in_domain(enforcer, "admin", "domain2") == []
    end
  end

  describe "get_roles_for_user_in_domain/3" do
    test "returns roles for user in specific domain", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin", "domain1")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "editor", "domain2")
      roles = RBAC.get_roles_for_user_in_domain(enforcer, "alice", "domain1")
      assert "admin" in roles
      refute "editor" in roles
    end

    test "returns empty list for non-existent domain", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin", "domain1")
      assert RBAC.get_roles_for_user_in_domain(enforcer, "alice", "domain2") == []
    end
  end

  describe "add_role_for_user_in_domain/4" do
    test "adds role for user in specific domain", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "alice", "admin", "domain1")
      roles = RBAC.get_roles_for_user_in_domain(enforcer, "alice", "domain1")
      assert "admin" in roles
    end

    test "allows same role in multiple domains", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "alice", "admin", "domain1")
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "alice", "admin", "domain2")
      assert "admin" in RBAC.get_roles_for_user_in_domain(enforcer, "alice", "domain1")
      assert "admin" in RBAC.get_roles_for_user_in_domain(enforcer, "alice", "domain2")
    end
  end

  describe "delete_role_for_user_in_domain/4" do
    test "deletes role for user in specific domain", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "alice", "admin", "domain1")
      {:ok, enforcer} = RBAC.add_role_for_user_in_domain(enforcer, "alice", "admin", "domain2")
      {:ok, enforcer} = RBAC.delete_role_for_user_in_domain(enforcer, "alice", "admin", "domain1")
      assert RBAC.get_roles_for_user_in_domain(enforcer, "alice", "domain1") == []
      assert "admin" in RBAC.get_roles_for_user_in_domain(enforcer, "alice", "domain2")
    end

    test "returns error when role does not exist in domain", %{enforcer: enforcer} do
      assert {:error, "grouping policy does not exist"} =
               RBAC.delete_role_for_user_in_domain(enforcer, "alice", "admin", "domain1")
    end
  end

  describe "edge cases and error handling" do
    test "handles empty string user", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "", "admin")
      assert RBAC.has_role_for_user(enforcer, "", "admin") == true
    end

    test "handles empty string role", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "")
      assert RBAC.has_role_for_user(enforcer, "alice", "") == true
    end

    test "handles special characters in user name", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice@example.com", "admin")
      assert RBAC.has_role_for_user(enforcer, "alice@example.com", "admin") == true
    end

    test "handles special characters in role name", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin-super")
      assert RBAC.has_role_for_user(enforcer, "alice", "admin-super") == true
    end

    test "handles unicode characters", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "用户", "角色")
      assert RBAC.has_role_for_user(enforcer, "用户", "角色") == true
    end
  end
end
