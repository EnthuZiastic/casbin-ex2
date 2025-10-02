# ACL Without Resources Example
# This demonstrates user capability-based authorization without resource specification
# Useful for system-wide capabilities or feature flags

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer without resources in the model
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/acl/basic_without_resources_model.conf",
    "examples/acl/basic_without_resources_policy.csv"
  )

# Test user capabilities (no resource needed)
IO.puts("\n=== Testing User Capabilities (No Resource) ===")
IO.puts("alice can read: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "read"])}")
IO.puts("alice can write: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "write"])}")
IO.puts("bob can write: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "write"])}")
IO.puts("bob can read: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "read"])}")
IO.puts("charlie can admin: #{CasbinEx2.Enforcer.enforce(enforcer, ["charlie", "admin"])}")

# Use case: System-wide capabilities
IO.puts("\n=== Use Case: System Capabilities ===")
IO.puts("alice has read capability: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "read"])}")
IO.puts("bob has write capability: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "write"])}")
IO.puts("charlie has admin capability: #{CasbinEx2.Enforcer.enforce(enforcer, ["charlie", "admin"])}")

# Use case: Feature flags
IO.puts("\n=== Use Case: Feature Flags ===")
{:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "beta_feature"])
{:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["bob", "export"])
IO.puts("alice can access beta_feature: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "beta_feature"])}")
IO.puts("bob can export: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "export"])}")
IO.puts("charlie can export: #{CasbinEx2.Enforcer.enforce(enforcer, ["charlie", "export"])}")

# Grant system-wide capability to user
IO.puts("\n=== Granting System Capability ===")
{:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["dave", "monitor"])
IO.puts("dave can monitor: #{CasbinEx2.Enforcer.enforce(enforcer, ["dave", "monitor"])}")

IO.puts("\n✅ ACL without resources example completed!")
