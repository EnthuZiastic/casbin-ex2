# ACL Without Users Example
# This demonstrates resource-only authorization without user identification
# Useful for public APIs where only resource+action matters

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer without users in the model
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/acl/basic_without_users_model.conf",
    "examples/acl/basic_without_users_policy.csv"
  )

# Test resource permissions (no user needed)
IO.puts("\n=== Testing Resource Permissions (No User) ===")
IO.puts("data1 allows read: #{CasbinEx2.Enforcer.enforce(enforcer, ["data1", "read"])}")
IO.puts("data1 allows write: #{CasbinEx2.Enforcer.enforce(enforcer, ["data1", "write"])}")
IO.puts("data2 allows write: #{CasbinEx2.Enforcer.enforce(enforcer, ["data2", "write"])}")
IO.puts("data2 allows read: #{CasbinEx2.Enforcer.enforce(enforcer, ["data2", "read"])}")

# Use case: Public API endpoints
IO.puts("\n=== Use Case: Public API Endpoints ===")
IO.puts("GET /data1 allowed: #{CasbinEx2.Enforcer.enforce(enforcer, ["data1", "read"])}")
IO.puts("POST /data1 allowed: #{CasbinEx2.Enforcer.enforce(enforcer, ["data1", "write"])}")
IO.puts("GET /data2 allowed: #{CasbinEx2.Enforcer.enforce(enforcer, ["data2", "read"])}")
IO.puts("POST /data2 allowed: #{CasbinEx2.Enforcer.enforce(enforcer, ["data2", "write"])}")

# Add new resource permission
IO.puts("\n=== Adding New Resource Permission ===")
{:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["data3", "read"])
IO.puts("data3 now allows read: #{CasbinEx2.Enforcer.enforce(enforcer, ["data3", "read"])}")
IO.puts("data3 allows write: #{CasbinEx2.Enforcer.enforce(enforcer, ["data3", "write"])}")

IO.puts("\n✅ ACL without users example completed!")
