defmodule CasbinEx2.ContextRoleManagerTest do
  use ExUnit.Case, async: true

  alias CasbinEx2.ContextRoleManager

  describe "new_role_manager/1" do
    test "creates role manager with default hierarchy level" do
      rm = ContextRoleManager.new_role_manager()
      assert rm.max_hierarchy_level == 10
      assert rm.roles == %{}
    end

    test "creates role manager with custom hierarchy level" do
      rm = ContextRoleManager.new_role_manager(5)
      assert rm.max_hierarchy_level == 5
    end
  end

  describe "clear_ctx/2" do
    test "clears all role data with context" do
      ctx = %{request_id: "test-clear"}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "bob", "user")

      refute rm.roles == %{}

      rm = ContextRoleManager.clear_ctx(ctx, rm)
      assert rm.roles == %{}
    end

    test "preserves hierarchy level after clear" do
      ctx = %{}
      rm = ContextRoleManager.new_role_manager(7)
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")
      rm = ContextRoleManager.clear_ctx(ctx, rm)

      assert rm.max_hierarchy_level == 7
      assert rm.roles == %{}
    end
  end

  describe "add_link_ctx/5" do
    test "adds basic role inheritance with context" do
      ctx = %{request_id: "req-001"}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")

      assert ContextRoleManager.has_link_ctx(ctx, rm, "alice", "admin")
    end

    test "adds role inheritance with domain" do
      ctx = %{metadata: %{source: "api"}}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin", "domain1")

      assert ContextRoleManager.has_link_ctx(ctx, rm, "alice", "admin", "domain1")
      refute ContextRoleManager.has_link_ctx(ctx, rm, "alice", "admin", "domain2")
    end

    test "supports multiple role assignments with context" do
      ctx = %{timeout: 5000}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "moderator")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "editor")

      assert ContextRoleManager.has_link_ctx(ctx, rm, "alice", "admin")
      assert ContextRoleManager.has_link_ctx(ctx, rm, "alice", "moderator")
      assert ContextRoleManager.has_link_ctx(ctx, rm, "alice", "editor")
    end

    test "adds transitive role hierarchy" do
      ctx = %{request_id: "req-002"}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "admin", "superuser")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "superuser", "root")

      assert ContextRoleManager.has_link_ctx(ctx, rm, "alice", "admin")
      assert ContextRoleManager.has_link_ctx(ctx, rm, "alice", "superuser")
      assert ContextRoleManager.has_link_ctx(ctx, rm, "alice", "root")
    end
  end

  describe "delete_link_ctx/5" do
    test "removes role inheritance with context" do
      ctx = %{request_id: "req-003"}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")
      assert ContextRoleManager.has_link_ctx(ctx, rm, "alice", "admin")

      rm = ContextRoleManager.delete_link_ctx(ctx, rm, "alice", "admin")
      refute ContextRoleManager.has_link_ctx(ctx, rm, "alice", "admin")
    end

    test "removes role inheritance with domain" do
      ctx = %{metadata: %{user: "system"}}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin", "domain1")
      rm = ContextRoleManager.delete_link_ctx(ctx, rm, "alice", "admin", "domain1")

      refute ContextRoleManager.has_link_ctx(ctx, rm, "alice", "admin", "domain1")
    end

    test "does not affect other role links" do
      ctx = %{}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "moderator")
      rm = ContextRoleManager.delete_link_ctx(ctx, rm, "alice", "admin")

      refute ContextRoleManager.has_link_ctx(ctx, rm, "alice", "admin")
      assert ContextRoleManager.has_link_ctx(ctx, rm, "alice", "moderator")
    end
  end

  describe "has_link_ctx/5" do
    test "returns true for direct role link with context" do
      ctx = %{request_id: "req-004"}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")

      assert ContextRoleManager.has_link_ctx(ctx, rm, "alice", "admin")
    end

    test "returns true for transitive role link" do
      ctx = %{timeout: 3000}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "admin", "superuser")

      assert ContextRoleManager.has_link_ctx(ctx, rm, "alice", "superuser")
    end

    test "returns false for non-existent link" do
      ctx = %{}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")

      refute ContextRoleManager.has_link_ctx(ctx, rm, "alice", "superuser")
    end

    test "returns true when checking same role" do
      ctx = %{}
      rm = ContextRoleManager.new_role_manager()

      assert ContextRoleManager.has_link_ctx(ctx, rm, "alice", "alice")
    end

    test "respects domain boundaries" do
      ctx = %{request_id: "req-005"}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin", "domain1")

      assert ContextRoleManager.has_link_ctx(ctx, rm, "alice", "admin", "domain1")
      refute ContextRoleManager.has_link_ctx(ctx, rm, "alice", "admin", "domain2")
    end
  end

  describe "get_roles_ctx/4" do
    test "returns direct roles with context" do
      ctx = %{metadata: %{action: "list_roles"}}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "moderator")

      roles = ContextRoleManager.get_roles_ctx(ctx, rm, "alice")
      assert Enum.sort(roles) == ["admin", "moderator"]
    end

    test "returns empty list when no roles assigned" do
      ctx = %{}
      rm = ContextRoleManager.new_role_manager()

      roles = ContextRoleManager.get_roles_ctx(ctx, rm, "alice")
      assert roles == []
    end

    test "returns roles for specific domain" do
      ctx = %{request_id: "req-006"}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin", "domain1")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "user", "domain2")

      roles_d1 = ContextRoleManager.get_roles_ctx(ctx, rm, "alice", "domain1")
      roles_d2 = ContextRoleManager.get_roles_ctx(ctx, rm, "alice", "domain2")

      assert roles_d1 == ["admin"]
      assert roles_d2 == ["user"]
    end

    test "does not return transitive roles, only direct" do
      ctx = %{}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "admin", "superuser")

      roles = ContextRoleManager.get_roles_ctx(ctx, rm, "alice")
      assert roles == ["admin"]
    end
  end

  describe "get_users_ctx/4" do
    test "returns users with specific role and context" do
      ctx = %{metadata: %{action: "list_users"}}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "bob", "admin")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "charlie", "user")

      users = ContextRoleManager.get_users_ctx(ctx, rm, "admin")
      assert Enum.sort(users) == ["alice", "bob"]
    end

    test "returns empty list when no users have role" do
      ctx = %{}
      rm = ContextRoleManager.new_role_manager()

      users = ContextRoleManager.get_users_ctx(ctx, rm, "admin")
      assert users == []
    end

    test "returns users for specific domain" do
      ctx = %{request_id: "req-007"}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin", "domain1")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "bob", "admin", "domain2")

      users_d1 = ContextRoleManager.get_users_ctx(ctx, rm, "admin", "domain1")
      users_d2 = ContextRoleManager.get_users_ctx(ctx, rm, "admin", "domain2")

      assert users_d1 == ["alice"]
      assert users_d2 == ["bob"]
    end
  end

  describe "get_domains_ctx/3" do
    test "returns domains where user has roles" do
      ctx = %{request_id: "req-008"}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin", "domain1")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "user", "domain2")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "moderator", "domain3")

      domains = ContextRoleManager.get_domains_ctx(ctx, rm, "alice")
      assert Enum.sort(domains) == ["domain1", "domain2", "domain3"]
    end

    test "returns empty list when user has no domain roles" do
      ctx = %{}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")

      domains = ContextRoleManager.get_domains_ctx(ctx, rm, "alice")
      assert domains == []
    end

    test "returns unique domains only" do
      ctx = %{}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin", "domain1")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "user", "domain1")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "moderator", "domain1")

      domains = ContextRoleManager.get_domains_ctx(ctx, rm, "alice")
      assert domains == ["domain1"]
    end
  end

  describe "get_all_domains_ctx/2" do
    test "returns all domains in role manager with context" do
      ctx = %{metadata: %{action: "list_all_domains"}}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin", "domain1")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "bob", "user", "domain2")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "charlie", "moderator", "domain3")

      domains = ContextRoleManager.get_all_domains_ctx(ctx, rm)
      assert Enum.sort(domains) == ["domain1", "domain2", "domain3"]
    end

    test "returns empty list when no domains exist" do
      ctx = %{}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")

      domains = ContextRoleManager.get_all_domains_ctx(ctx, rm)
      assert domains == []
    end

    test "returns unique domains only" do
      ctx = %{}
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin", "domain1")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "bob", "user", "domain1")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "charlie", "admin", "domain2")

      domains = ContextRoleManager.get_all_domains_ctx(ctx, rm)
      assert Enum.sort(domains) == ["domain1", "domain2"]
    end
  end

  describe "non-context delegated functions" do
    test "clear/1 works without context" do
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link(rm, "alice", "admin")
      rm = ContextRoleManager.clear(rm)

      assert rm.roles == %{}
    end

    test "add_link/4 works without context" do
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link(rm, "alice", "admin")

      assert ContextRoleManager.has_link(rm, "alice", "admin")
    end

    test "delete_link/4 works without context" do
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link(rm, "alice", "admin")
      rm = ContextRoleManager.delete_link(rm, "alice", "admin")

      refute ContextRoleManager.has_link(rm, "alice", "admin")
    end

    test "has_link/4 works without context" do
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link(rm, "alice", "admin")

      assert ContextRoleManager.has_link(rm, "alice", "admin")
    end

    test "get_roles/3 works without context" do
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link(rm, "alice", "admin")
      rm = ContextRoleManager.add_link(rm, "alice", "moderator")

      roles = ContextRoleManager.get_roles(rm, "alice")
      assert Enum.sort(roles) == ["admin", "moderator"]
    end

    test "get_users/3 works without context" do
      rm = ContextRoleManager.new_role_manager()
      rm = ContextRoleManager.add_link(rm, "alice", "admin")
      rm = ContextRoleManager.add_link(rm, "bob", "admin")

      users = ContextRoleManager.get_users(rm, "admin")
      assert Enum.sort(users) == ["alice", "bob"]
    end
  end

  describe "complex scenarios with context" do
    test "multi-domain, multi-user, multi-role scenario" do
      ctx = %{request_id: "req-complex-001", timeout: 10_000}
      rm = ContextRoleManager.new_role_manager()

      # Domain1: alice is admin, bob is user
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin", "domain1")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "bob", "user", "domain1")

      # Domain2: alice is user, charlie is admin
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "alice", "user", "domain2")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "charlie", "admin", "domain2")

      # Verify alice's roles across domains
      assert ContextRoleManager.has_link_ctx(ctx, rm, "alice", "admin", "domain1")
      assert ContextRoleManager.has_link_ctx(ctx, rm, "alice", "user", "domain2")
      refute ContextRoleManager.has_link_ctx(ctx, rm, "alice", "admin", "domain2")

      # Verify domain memberships
      alice_domains = ContextRoleManager.get_domains_ctx(ctx, rm, "alice")
      assert Enum.sort(alice_domains) == ["domain1", "domain2"]

      # Verify all domains
      all_domains = ContextRoleManager.get_all_domains_ctx(ctx, rm)
      assert Enum.sort(all_domains) == ["domain1", "domain2"]
    end

    test "context propagation through hierarchy" do
      ctx = %{
        request_id: "req-hierarchy-001",
        metadata: %{
          source: "api",
          user_agent: "test-client",
          trace_id: "trace-123"
        }
      }

      rm = ContextRoleManager.new_role_manager()

      # Build hierarchy with context
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "intern", "employee")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "employee", "member")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "member", "authenticated")

      # Context is passed through all operations
      assert ContextRoleManager.has_link_ctx(ctx, rm, "intern", "employee")
      assert ContextRoleManager.has_link_ctx(ctx, rm, "intern", "member")
      assert ContextRoleManager.has_link_ctx(ctx, rm, "intern", "authenticated")
    end

    test "respects max hierarchy level with context" do
      ctx = %{request_id: "req-limit"}
      rm = ContextRoleManager.new_role_manager(3)

      # Build deep hierarchy
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "user1", "user2")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "user2", "user3")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "user3", "user4")
      rm = ContextRoleManager.add_link_ctx(ctx, rm, "user4", "user5")

      # Should reach user4 (depth 3) but not user5 (depth 4)
      assert ContextRoleManager.has_link_ctx(ctx, rm, "user1", "user4")
      refute ContextRoleManager.has_link_ctx(ctx, rm, "user1", "user5")
    end
  end
end
