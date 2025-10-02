# Basic RBAC Example
# This demonstrates Role-Based Access Control (RBAC)
# Users inherit permissions from their roles

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer with RBAC model
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/rbac/rbac_model.conf",
    "examples/rbac/rbac_policy.csv"
  )

# Test alice's direct permissions
IO.puts("\n=== Alice's Direct Permissions ===")
IO.puts("alice can read data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data1", "read"])}")
IO.puts("alice can write data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data1", "write"])}")

# Test alice's role-inherited permissions
IO.puts("\n=== Alice's Role-Based Permissions (data2_admin role) ===")
IO.puts("alice can read data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data2", "read"])}")
IO.puts("alice can write data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data2", "write"])}")

# Test bob's permissions
IO.puts("\n=== Bob's Permissions ===")
IO.puts("bob can write data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "data2", "write"])}")
IO.puts("bob can read data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "data2", "read"])}")

# Show alice's roles
IO.puts("\n=== Role Management ===")
roles = CasbinEx2.RBAC.get_roles_for_user(enforcer, "alice")
IO.puts("alice's roles: #{inspect(roles)}")

# Add a new role to bob
IO.puts("\n=== Adding Role to Bob ===")
{:ok, enforcer} = CasbinEx2.RBAC.add_role_for_user(enforcer, "bob", "data2_admin")
roles = CasbinEx2.RBAC.get_roles_for_user(enforcer, "bob")
IO.puts("bob's roles: #{inspect(roles)}")
IO.puts("bob can now read data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "data2", "read"])}")

# Remove role from alice
IO.puts("\n=== Removing Role from Alice ===")
{:ok, enforcer} = CasbinEx2.RBAC.delete_role_for_user(enforcer, "alice", "data2_admin")
IO.puts("alice can still write data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data2", "write"])}")

IO.puts("\n✅ Basic RBAC example completed!")
