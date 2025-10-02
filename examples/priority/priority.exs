# Priority Policy Example
# This demonstrates priority-based policy evaluation
# Policies are evaluated in order, first match wins

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer with priority policy model
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/priority/priority_model.conf",
    "examples/priority/priority_policy.csv"
  )

# Test alice: Has both allow (direct) and deny (via group)
# Direct policies have higher priority than role policies
IO.puts("\n=== Alice's Priority Resolution ===")
IO.puts("Policy order for alice on data1:")
IO.puts("1. p, alice, data1, read, allow (direct - HIGHER priority)")
IO.puts("2. p, data1_deny_group, data1, read, deny (via group - lower priority)")
IO.puts("")
IO.puts("alice can read data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data1", "read"])}")
IO.puts("^^ TRUE because direct 'allow' has priority over group 'deny'")
IO.puts("")
IO.puts("alice can write data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data1", "write"])}")
IO.puts("^^ TRUE because direct 'allow' has priority over group 'deny'")

# Test bob: Has deny (direct) and allow (via group)
# Direct deny has higher priority than role allow
IO.puts("\n=== Bob's Priority Resolution ===")
IO.puts("Policy order for bob on data2:")
IO.puts("1. p, bob, data2, read, deny (direct - HIGHER priority)")
IO.puts("2. p, data2_allow_group, data2, read, allow (via group - lower priority)")
IO.puts("")
IO.puts("bob can read data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "data2", "read"])}")
IO.puts("^^ FALSE because direct 'deny' has priority over group 'allow'")
IO.puts("")
IO.puts("bob can write data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "data2", "write"])}")
IO.puts("^^ FALSE because direct 'deny' exists")

# Show policy evaluation order
IO.puts("\n=== Policy Evaluation Order ===")
IO.puts("Priority model evaluates policies in this order:")
IO.puts("1. Direct user policies (highest priority)")
IO.puts("2. Role/group policies (lower priority)")
IO.puts("3. Default deny if no match")

# Use case: Override group policies
IO.puts("\n=== Use Case: Override Group Policies ===")
IO.puts("Scenario: alice is in data1_deny_group but has direct allow")
IO.puts("Result: Direct policy overrides group policy")
IO.puts("")
IO.puts("Scenario: bob is in data2_allow_group but has direct deny")
IO.puts("Result: Direct policy overrides group policy")

# Add another user to demonstrate priority
IO.puts("\n=== Adding Charlie with Only Group Policy ===")
{:ok, enforcer} = CasbinEx2.RBAC.add_role_for_user(enforcer, "charlie", "data1_deny_group")
IO.puts("charlie (only in data1_deny_group) can read data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["charlie", "data1", "read"])}")
IO.puts("^^ FALSE because no direct policy to override group deny")

# Add direct policy for charlie
IO.puts("\n=== Adding Direct Policy for Charlie ===")
{:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["charlie", "data1", "read", "allow"])
IO.puts("charlie (now with direct allow) can read data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["charlie", "data1", "read"])}")
IO.puts("^^ TRUE because direct policy now has priority")

# Show priority with multiple roles
IO.puts("\n=== Priority with Multiple Roles ===")
{:ok, enforcer} = CasbinEx2.RBAC.add_role_for_user(enforcer, "dave", "data2_allow_group")
{:ok, enforcer} = CasbinEx2.RBAC.add_role_for_user(enforcer, "dave", "data1_deny_group")

dave_roles = CasbinEx2.RBAC.get_roles_for_user(enforcer, "dave")
IO.puts("dave's roles: #{inspect(dave_roles)}")
IO.puts("dave can read data2 (via data2_allow_group): #{CasbinEx2.Enforcer.enforce(enforcer, ["dave", "data2", "read"])}")
IO.puts("dave can read data1 (via data1_deny_group): #{CasbinEx2.Enforcer.enforce(enforcer, ["dave", "data1", "read"])}")

IO.puts("\n✅ Priority policy example completed!")
