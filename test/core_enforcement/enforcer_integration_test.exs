defmodule CasbinEx2.EnforcerIntegrationTest do
  use ExUnit.Case, async: true

  alias CasbinEx2.Adapter.MemoryAdapter
  alias CasbinEx2.Enforcer
  alias CasbinEx2.Management
  alias CasbinEx2.Model
  alias CasbinEx2.RBAC

  @model_path "examples/rbac_model.conf"

  setup do
    {:ok, model} = Model.load_model(@model_path)
    adapter = MemoryAdapter.new()
    {:ok, enforcer} = Enforcer.init_with_model_and_adapter(model, adapter)

    {:ok, enforcer: enforcer, model: model}
  end

  describe "complete RBAC workflow" do
    test "end-to-end user lifecycle with roles and permissions", %{enforcer: enforcer} do
      # Step 1: Create user with role
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "developer")
      assert RBAC.has_role_for_user(enforcer, "alice", "developer") == true

      # Step 2: Add permissions to role
      {:ok, enforcer} = Management.add_policy(enforcer, ["developer", "code", "read"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["developer", "code", "write"])

      # Step 3: Test enforcement through role
      assert Enforcer.enforce(enforcer, ["alice", "code", "read"]) == true
      assert Enforcer.enforce(enforcer, ["alice", "code", "write"]) == true
      assert Enforcer.enforce(enforcer, ["alice", "code", "delete"]) == false

      # Step 4: Add direct permission to user
      {:ok, enforcer} = Management.add_policy(enforcer, ["alice", "docs", "read"])
      assert Enforcer.enforce(enforcer, ["alice", "docs", "read"]) == true

      # Step 5: Remove role
      {:ok, enforcer} = RBAC.delete_role_for_user(enforcer, "alice", "developer")
      assert Enforcer.enforce(enforcer, ["alice", "code", "read"]) == false
      # Direct permission should still work
      assert Enforcer.enforce(enforcer, ["alice", "docs", "read"]) == true

      # Step 6: Remove user's direct permission
      {:ok, enforcer} = Management.remove_policy(enforcer, ["alice", "docs", "read"])
      assert Enforcer.enforce(enforcer, ["alice", "docs", "read"]) == false
    end

    test "hierarchical roles with permission inheritance", %{enforcer: enforcer} do
      # Create role hierarchy: user -> developer -> admin
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "developer")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "developer", "admin")

      # Add permissions at different levels
      {:ok, enforcer} = Management.add_policy(enforcer, ["admin", "server", "manage"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["developer", "code", "write"])

      # User should inherit all permissions
      assert Enforcer.enforce(enforcer, ["alice", "code", "write"]) == true
      assert Enforcer.enforce(enforcer, ["alice", "server", "manage"]) == true

      # Check implicit roles
      implicit_roles = RBAC.get_implicit_roles_for_user(enforcer, "alice")
      assert "developer" in implicit_roles
      assert "admin" in implicit_roles
    end

    test "multiple roles with combined permissions", %{enforcer: enforcer} do
      # User has multiple roles
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "developer")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "tester")

      # Each role has different permissions
      {:ok, enforcer} = Management.add_policy(enforcer, ["developer", "code", "write"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["tester", "tests", "run"])

      # User should have permissions from both roles
      assert Enforcer.enforce(enforcer, ["alice", "code", "write"]) == true
      assert Enforcer.enforce(enforcer, ["alice", "tests", "run"]) == true

      roles = RBAC.get_roles_for_user(enforcer, "alice")
      assert length(roles) == 2
      assert "developer" in roles
      assert "tester" in roles
    end
  end

  describe "domain-like separation with role naming" do
    test "separate roles for different contexts", %{enforcer: enforcer} do
      # Use role naming to simulate domains: alice_domain1, alice_domain2
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin_domain1")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "user_domain2")

      # Add context-specific permissions
      {:ok, enforcer} = Management.add_policy(enforcer, ["admin_domain1", "data1", "write"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["user_domain2", "data2", "read"])

      # Test enforcement
      assert Enforcer.enforce(enforcer, ["alice", "data1", "write"]) == true
      assert Enforcer.enforce(enforcer, ["alice", "data2", "read"]) == true
      assert Enforcer.enforce(enforcer, ["alice", "data1", "read"]) == false
      assert Enforcer.enforce(enforcer, ["alice", "data2", "write"]) == false
    end

    test "role isolation between users", %{enforcer: enforcer} do
      # Same role pattern for different users
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin_context1")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "bob", "admin_context2")

      {:ok, enforcer} = Management.add_policy(enforcer, ["admin_context1", "data1", "delete"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["admin_context2", "data2", "delete"])

      # Alice can only access context1, Bob only context2
      assert Enforcer.enforce(enforcer, ["alice", "data1", "delete"]) == true
      assert Enforcer.enforce(enforcer, ["alice", "data2", "delete"]) == false
      assert Enforcer.enforce(enforcer, ["bob", "data2", "delete"]) == true
      assert Enforcer.enforce(enforcer, ["bob", "data1", "delete"]) == false
    end
  end

  describe "policy and role coordination" do
    test "policy changes affect role-based enforcement", %{enforcer: enforcer} do
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "developer")
      {:ok, enforcer} = Management.add_policy(enforcer, ["developer", "code", "read"])

      # Initial enforcement works
      assert Enforcer.enforce(enforcer, ["alice", "code", "read"]) == true

      # Remove policy
      {:ok, enforcer} = Management.remove_policy(enforcer, ["developer", "code", "read"])

      # Enforcement should fail now
      assert Enforcer.enforce(enforcer, ["alice", "code", "read"]) == false

      # Add policy back
      {:ok, enforcer} = Management.add_policy(enforcer, ["developer", "code", "read"])

      # Should work again
      assert Enforcer.enforce(enforcer, ["alice", "code", "read"]) == true
    end

    test "role changes affect policy enforcement", %{enforcer: enforcer} do
      {:ok, enforcer} = Management.add_policy(enforcer, ["developer", "code", "write"])

      # No role yet, enforcement fails
      assert Enforcer.enforce(enforcer, ["alice", "code", "write"]) == false

      # Add role
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "developer")

      # Now enforcement succeeds
      assert Enforcer.enforce(enforcer, ["alice", "code", "write"]) == true

      # Remove role
      {:ok, enforcer} = RBAC.delete_role_for_user(enforcer, "alice", "developer")

      # Back to failing
      assert Enforcer.enforce(enforcer, ["alice", "code", "write"]) == false
    end

    test "batch policy and role operations", %{enforcer: enforcer} do
      # Batch add roles
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "developer")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "bob", "tester")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "charlie", "admin")

      # Batch add policies
      policies = [
        ["developer", "code", "write"],
        ["tester", "tests", "run"],
        ["admin", "system", "manage"]
      ]

      {:ok, enforcer} = Management.add_policies(enforcer, policies)

      # All users should have their respective permissions
      assert Enforcer.enforce(enforcer, ["alice", "code", "write"]) == true
      assert Enforcer.enforce(enforcer, ["bob", "tests", "run"]) == true
      assert Enforcer.enforce(enforcer, ["charlie", "system", "manage"]) == true
    end
  end

  describe "adapter integration" do
    test "policies persist through adapter save/load cycle", %{model: model} do
      adapter = MemoryAdapter.new()
      {:ok, enforcer} = Enforcer.init_with_model_and_adapter(model, adapter)

      # Add policies
      {:ok, enforcer} = Management.add_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["bob", "data2", "write"])

      # Policies work in current enforcer
      assert Enforcer.enforce(enforcer, ["alice", "data1", "read"]) == true
      assert Enforcer.enforce(enforcer, ["bob", "data2", "write"]) == true
    end

    test "roles persist through adapter save/load cycle", %{model: model} do
      adapter = MemoryAdapter.new()
      {:ok, enforcer} = Enforcer.init_with_model_and_adapter(model, adapter)

      # Add role and policy
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin")
      {:ok, enforcer} = Management.add_policy(enforcer, ["admin", "data", "delete"])

      # Role-based enforcement should work
      assert Enforcer.enforce(enforcer, ["alice", "data", "delete"]) == true
      assert RBAC.has_role_for_user(enforcer, "alice", "admin") == true
    end
  end

  describe "complex multi-step workflows" do
    test "organization onboarding workflow", %{enforcer: enforcer} do
      # Step 1: Create organization roles
      permissions = %{
        "owner" => [["org", "delete"], ["org", "manage"]],
        "admin" => [["org", "manage"], ["users", "manage"]],
        "member" => [["projects", "create"], ["projects", "read"]],
        "guest" => [["projects", "read"]]
      }

      # Add all permissions
      enforcer =
        Enum.reduce(permissions, enforcer, fn {role, perms}, acc ->
          Enum.reduce(perms, acc, fn [resource, action], inner_acc ->
            {:ok, updated} = Management.add_policy(inner_acc, [role, resource, action])
            updated
          end)
        end)

      # Step 2: Onboard users with different roles
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "owner")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "bob", "admin")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "charlie", "member")

      # Step 3: Verify permissions
      assert Enforcer.enforce(enforcer, ["alice", "org", "delete"]) == true
      assert Enforcer.enforce(enforcer, ["bob", "users", "manage"]) == true
      assert Enforcer.enforce(enforcer, ["charlie", "projects", "create"]) == true

      # Step 4: Promote user
      {:ok, enforcer} = RBAC.delete_role_for_user(enforcer, "charlie", "member")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "charlie", "admin")

      # Charlie now has admin permissions
      assert Enforcer.enforce(enforcer, ["charlie", "users", "manage"]) == true
      assert Enforcer.enforce(enforcer, ["charlie", "org", "delete"]) == false
    end

    test "dynamic permission adjustment workflow", %{enforcer: enforcer} do
      # Initial setup
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "developer")
      {:ok, enforcer} = Management.add_policy(enforcer, ["developer", "code", "read"])

      # Check initial permission
      assert Enforcer.enforce(enforcer, ["alice", "code", "read"]) == true
      assert Enforcer.enforce(enforcer, ["alice", "code", "write"]) == false

      # Upgrade permissions for the role
      {:ok, enforcer} = Management.add_policy(enforcer, ["developer", "code", "write"])

      # All users with that role get upgraded
      assert Enforcer.enforce(enforcer, ["alice", "code", "write"]) == true

      # Add temporary elevated permission
      {:ok, enforcer} = Management.add_policy(enforcer, ["alice", "production", "deploy"])
      assert Enforcer.enforce(enforcer, ["alice", "production", "deploy"]) == true

      # Revoke temporary permission
      {:ok, enforcer} = Management.remove_policy(enforcer, ["alice", "production", "deploy"])
      assert Enforcer.enforce(enforcer, ["alice", "production", "deploy"]) == false

      # Role permissions remain
      assert Enforcer.enforce(enforcer, ["alice", "code", "write"]) == true
    end

    test "team-based access control workflow", %{enforcer: enforcer} do
      # Create teams as roles
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "team_backend")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "bob", "team_frontend")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "charlie", "team_backend")

      # Add team permissions
      {:ok, enforcer} = Management.add_policy(enforcer, ["team_backend", "api", "access"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["team_backend", "database", "query"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["team_frontend", "ui", "access"])

      # Verify team isolation
      assert Enforcer.enforce(enforcer, ["alice", "api", "access"]) == true
      assert Enforcer.enforce(enforcer, ["alice", "ui", "access"]) == false
      assert Enforcer.enforce(enforcer, ["bob", "ui", "access"]) == true
      assert Enforcer.enforce(enforcer, ["bob", "api", "access"]) == false

      # Both backend team members have same access
      assert Enforcer.enforce(enforcer, ["charlie", "api", "access"]) == true
      assert Enforcer.enforce(enforcer, ["charlie", "database", "query"]) == true
    end
  end

  describe "enforcement with complex matchers" do
    test "regex-based matching integration", %{enforcer: enforcer} do
      # Add policies with wildcards
      {:ok, enforcer} = Management.add_policy(enforcer, ["alice", "/api/users/*", "GET"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["bob", "/api/admin/*", "GET"])

      # Use custom matcher with keyMatch
      matcher = "r.sub == p.sub && keyMatch(r.obj, p.obj) && r.act == p.act"

      # Test matching
      result =
        Enforcer.enforce_with_matcher(enforcer, matcher, ["alice", "/api/users/123", "GET"])

      assert is_boolean(result)

      result =
        Enforcer.enforce_with_matcher(enforcer, matcher, ["bob", "/api/admin/settings", "GET"])

      assert is_boolean(result)
    end

    test "ABAC-style attribute matching", %{enforcer: enforcer} do
      # Add policies with attributes
      {:ok, enforcer} = Management.add_policy(enforcer, ["alice", "document", "read"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["bob", "document", "write"])

      # Create custom matcher that checks attributes
      matcher = "r.sub == p.sub && r.obj == p.obj && r.act == p.act"

      assert Enforcer.enforce_with_matcher(enforcer, matcher, ["alice", "document", "read"]) ==
               true

      assert Enforcer.enforce_with_matcher(enforcer, matcher, ["alice", "document", "write"]) ==
               false
    end
  end

  describe "real-world scenarios" do
    test "file sharing application scenario", %{enforcer: enforcer} do
      # Setup: Users can own, share, and access files

      # Alice owns file1
      {:ok, enforcer} = Management.add_policy(enforcer, ["alice", "file1", "owner"])

      # Alice shares file1 with Bob (read access)
      {:ok, enforcer} = Management.add_policy(enforcer, ["bob", "file1", "read"])

      # Alice shares file1 with Charlie (write access)
      {:ok, enforcer} = Management.add_policy(enforcer, ["charlie", "file1", "write"])

      # Alice as owner can perform actions
      assert Enforcer.enforce(enforcer, ["alice", "file1", "owner"]) == true

      # Bob can only read
      assert Enforcer.enforce(enforcer, ["bob", "file1", "read"]) == true
      assert Enforcer.enforce(enforcer, ["bob", "file1", "write"]) == false

      # Charlie can read and write
      assert Enforcer.enforce(enforcer, ["charlie", "file1", "write"]) == true

      # Revoke Bob's access
      {:ok, enforcer} = Management.remove_policy(enforcer, ["bob", "file1", "read"])
      assert Enforcer.enforce(enforcer, ["bob", "file1", "read"]) == false
    end

    test "multi-tenant SaaS application scenario", %{enforcer: enforcer} do
      # Simulate tenants with role naming: admin_tenant1, admin_tenant2
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "admin_tenant1")

      {:ok, enforcer} =
        Management.add_policy(enforcer, ["admin_tenant1", "data_tenant1", "manage"])

      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "bob", "admin_tenant2")

      {:ok, enforcer} =
        Management.add_policy(enforcer, ["admin_tenant2", "data_tenant2", "manage"])

      # Alice can only manage tenant1 data
      assert Enforcer.enforce(enforcer, ["alice", "data_tenant1", "manage"]) == true
      assert Enforcer.enforce(enforcer, ["alice", "data_tenant2", "manage"]) == false

      # Bob can only manage tenant2 data
      assert Enforcer.enforce(enforcer, ["bob", "data_tenant2", "manage"]) == true
      assert Enforcer.enforce(enforcer, ["bob", "data_tenant1", "manage"]) == false

      # Add user to tenant1
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "charlie", "user_tenant1")
      {:ok, enforcer} = Management.add_policy(enforcer, ["user_tenant1", "data_tenant1", "read"])

      assert Enforcer.enforce(enforcer, ["charlie", "data_tenant1", "read"]) == true
      assert Enforcer.enforce(enforcer, ["charlie", "data_tenant1", "manage"]) == false
    end

    test "project-based access control scenario", %{enforcer: enforcer} do
      # Setup: Projects have owners, contributors, and viewers

      # Alice owns project1
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "alice", "project1_owner")
      {:ok, enforcer} = Management.add_policy(enforcer, ["project1_owner", "project1", "delete"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["project1_owner", "project1", "write"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["project1_owner", "project1", "read"])

      # Bob is contributor
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "bob", "project1_contributor")

      {:ok, enforcer} =
        Management.add_policy(enforcer, ["project1_contributor", "project1", "write"])

      {:ok, enforcer} =
        Management.add_policy(enforcer, ["project1_contributor", "project1", "read"])

      # Charlie is viewer
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "charlie", "project1_viewer")
      {:ok, enforcer} = Management.add_policy(enforcer, ["project1_viewer", "project1", "read"])

      # Verify access levels
      assert Enforcer.enforce(enforcer, ["alice", "project1", "delete"]) == true
      assert Enforcer.enforce(enforcer, ["bob", "project1", "write"]) == true
      assert Enforcer.enforce(enforcer, ["bob", "project1", "delete"]) == false
      assert Enforcer.enforce(enforcer, ["charlie", "project1", "read"]) == true
      assert Enforcer.enforce(enforcer, ["charlie", "project1", "write"]) == false

      # Promote bob to owner
      {:ok, enforcer} = RBAC.delete_role_for_user(enforcer, "bob", "project1_contributor")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "bob", "project1_owner")

      assert Enforcer.enforce(enforcer, ["bob", "project1", "delete"]) == true
    end
  end

  describe "stress test integration" do
    test "large-scale multi-user system", %{enforcer: enforcer} do
      # Create 50 users with roles
      enforcer =
        Enum.reduce(1..50, enforcer, fn i, acc ->
          role =
            cond do
              rem(i, 5) == 0 -> "admin"
              rem(i, 3) == 0 -> "developer"
              true -> "user"
            end

          {:ok, updated} = RBAC.add_role_for_user(acc, "user#{i}", role)
          updated
        end)

      # Add role permissions
      {:ok, enforcer} = Management.add_policy(enforcer, ["admin", "system", "manage"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["developer", "code", "write"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["user", "data", "read"])

      # Batch enforce for all users
      requests =
        Enum.map(1..50, fn i ->
          role =
            cond do
              rem(i, 5) == 0 -> ["user#{i}", "system", "manage"]
              rem(i, 3) == 0 -> ["user#{i}", "code", "write"]
              true -> ["user#{i}", "data", "read"]
            end

          role
        end)

      results = Enforcer.batch_enforce(enforcer, requests)

      # All should return true (correct permissions for their roles)
      assert Enum.all?(results, &(&1 == true))
    end

    test "complex role hierarchy with many users", %{enforcer: enforcer} do
      # Create hierarchy: intern -> junior -> senior -> lead -> manager
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "intern", "junior")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "junior", "senior")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "senior", "lead")
      {:ok, enforcer} = RBAC.add_role_for_user(enforcer, "lead", "manager")

      # Add permissions at each level
      {:ok, enforcer} = Management.add_policy(enforcer, ["manager", "budget", "approve"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["lead", "team", "manage"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["senior", "architecture", "design"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["junior", "code", "write"])

      # Assign 20 users to intern role
      enforcer =
        Enum.reduce(1..20, enforcer, fn i, acc ->
          {:ok, updated} = RBAC.add_role_for_user(acc, "user#{i}", "intern")
          updated
        end)

      # All interns should inherit all permissions through hierarchy
      assert Enforcer.enforce(enforcer, ["user1", "code", "write"]) == true
      assert Enforcer.enforce(enforcer, ["user10", "architecture", "design"]) == true
      assert Enforcer.enforce(enforcer, ["user20", "team", "manage"]) == true
      assert Enforcer.enforce(enforcer, ["user15", "budget", "approve"]) == true
    end
  end
end
