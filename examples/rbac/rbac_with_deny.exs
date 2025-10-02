# RBAC with Deny Example
# This demonstrates explicit deny rules that override allow rules
# Deny rules take precedence over allow rules

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer with deny-capable RBAC model
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/rbac/rbac_with_deny_model.conf",
    "examples/rbac/rbac_with_deny_policy.csv"
  )

# Test alice's direct permissions
IO.puts("\n=== Alice's Direct Permissions ===")
IO.puts("alice can read data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data1", "read"])}")

# Test alice's role permissions (she has data2_admin role)
IO.puts("\n=== Alice's Role Permissions (data2_admin) ===")
IO.puts("alice can read data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data2", "read"])}")

# BUT alice has explicit deny for writing data2
IO.puts("\n=== Alice's Explicit Deny Override ===")
IO.puts("alice can write data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data2", "write"])}")
IO.puts("^^ FALSE because explicit deny overrides role permission!")

# Show that the role would normally grant write permission
IO.puts("\n=== Role Permissions Without Deny ===")
{:ok, enforcer} = CasbinEx2.RBAC.add_role_for_user(enforcer, "bob", "data2_admin")
IO.puts("bob (also data2_admin) can write data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "data2", "write"])}")

# Use case: Temporary restriction
IO.puts("\n=== Use Case: Temporary Restrictions ===")
IO.puts("Scenario: alice is admin but temporarily restricted from writes")
IO.puts("alice retains read access: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data2", "read"])}")
IO.puts("alice blocked from write: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data2", "write"])}")

# Remove the deny to restore full access
IO.puts("\n=== Removing Deny Restriction ===")
{:ok, enforcer} = CasbinEx2.Management.remove_policy(enforcer, ["alice", "data2", "write", "deny"])
IO.puts("alice can now write data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data2", "write"])}")

# Add deny back
IO.puts("\n=== Re-adding Deny ===")
{:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "data2", "write", "deny"])
IO.puts("alice blocked again: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data2", "write"])}")

IO.puts("\n✅ RBAC with deny example completed!")
