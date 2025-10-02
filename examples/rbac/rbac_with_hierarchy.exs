# RBAC with Hierarchy Example
# This demonstrates hierarchical roles where roles can inherit from other roles
# alice -> admin -> data1_admin + data2_admin

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer with role hierarchy
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/rbac/rbac_model.conf",
    "examples/rbac/rbac_with_hierarchy_policy.csv"
  )

# Test alice's direct permissions
IO.puts("\n=== Alice's Direct Permissions ===")
IO.puts("alice can read data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data1", "read"])}")

# Test alice's inherited permissions through role hierarchy
# alice -> admin -> data1_admin
# alice -> admin -> data2_admin
IO.puts("\n=== Alice's Inherited Permissions (Through Role Hierarchy) ===")
IO.puts("alice can write data1 (via admin -> data1_admin): #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data1", "write"])}")
IO.puts("alice can read data2 (via admin -> data2_admin): #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data2", "read"])}")
IO.puts("alice can write data2 (via admin -> data2_admin): #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data2", "write"])}")

# Show alice's role hierarchy
IO.puts("\n=== Alice's Role Hierarchy ===")
direct_roles = CasbinEx2.RBAC.get_roles_for_user(enforcer, "alice")
IO.puts("alice's direct roles: #{inspect(direct_roles)}")

# Get implicit roles (transitive closure)
implicit_roles = CasbinEx2.RBAC.get_implicit_roles_for_user(enforcer, "alice")
IO.puts("alice's implicit roles: #{inspect(implicit_roles)}")

# Test bob (no hierarchy)
IO.puts("\n=== Bob's Permissions (No Hierarchy) ===")
IO.puts("bob can write data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "data2", "write"])}")
IO.puts("bob can read data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "data2", "read"])}")
IO.puts("bob can write data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "data1", "write"])}")

# Add bob to admin role to give him hierarchy
IO.puts("\n=== Adding Bob to Admin Role (Hierarchy) ===")
{:ok, enforcer} = CasbinEx2.RBAC.add_role_for_user(enforcer, "bob", "admin")
IO.puts("bob can now write data1 (via hierarchy): #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "data1", "write"])}")
bob_implicit = CasbinEx2.RBAC.get_implicit_roles_for_user(enforcer, "bob")
IO.puts("bob's implicit roles: #{inspect(bob_implicit)}")

# Create deeper hierarchy: charlie -> manager -> admin -> data1_admin + data2_admin
IO.puts("\n=== Creating Deeper Hierarchy ===")
{:ok, enforcer} = CasbinEx2.RBAC.add_role_for_user(enforcer, "charlie", "manager")
{:ok, enforcer} = CasbinEx2.RBAC.add_role_for_user(enforcer, "manager", "admin")
charlie_implicit = CasbinEx2.RBAC.get_implicit_roles_for_user(enforcer, "charlie")
IO.puts("charlie's implicit roles (3-level hierarchy): #{inspect(charlie_implicit)}")
IO.puts("charlie can write data1 (via 3-level hierarchy): #{CasbinEx2.Enforcer.enforce(enforcer, ["charlie", "data1", "write"])}")
IO.puts("charlie can write data2 (via 3-level hierarchy): #{CasbinEx2.Enforcer.enforce(enforcer, ["charlie", "data2", "write"])}")

IO.puts("\n✅ RBAC with hierarchy example completed!")
