# ABAC with Rules Example
# This demonstrates ABAC with rule-based attribute evaluation
# Rules can evaluate complex conditions on subject attributes

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer with rule-based ABAC model
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/abac/abac_rule_model.conf",
    "examples/abac/abac_rule_policy.csv"
  )

# Test with users of different ages
IO.puts("\n=== Testing Age-Based Rules ===")

# Create user objects with Age attribute
alice = %{Name: "alice", Age: 25}  # Adult
bob = %{Name: "bob", Age: 16}      # Minor
charlie = %{Name: "charlie", Age: 65}  # Senior

# Test /data1 access (requires Age > 18)
IO.puts("\nAccess to /data1 (requires Age > 18):")
IO.puts("alice (25) can read /data1: #{CasbinEx2.Enforcer.enforce(enforcer, [alice, "/data1", "read"])}")
IO.puts("bob (16) can read /data1: #{CasbinEx2.Enforcer.enforce(enforcer, [bob, "/data1", "read"])}")
IO.puts("charlie (65) can read /data1: #{CasbinEx2.Enforcer.enforce(enforcer, [charlie, "/data1", "read"])}")

# Test /data2 access (requires Age < 60)
IO.puts("\nAccess to /data2 (requires Age < 60):")
IO.puts("alice (25) can write /data2: #{CasbinEx2.Enforcer.enforce(enforcer, [alice, "/data2", "write"])}")
IO.puts("bob (16) can write /data2: #{CasbinEx2.Enforcer.enforce(enforcer, [bob, "/data2", "write"])}")
IO.puts("charlie (65) can write /data2: #{CasbinEx2.Enforcer.enforce(enforcer, [charlie, "/data2", "write"])}")

# Use case: Content rating system
IO.puts("\n=== Use Case: Content Rating System ===")
IO.puts("Scenario: /data1 is adult content (18+), /data2 is senior-limited")
IO.puts("alice (25) - Adult, not senior: Can access both")
IO.puts("bob (16) - Minor: Can only access /data2")
IO.puts("charlie (65) - Senior: Can only access /data1")

# Add new rule dynamically
IO.puts("\n=== Adding New Age-Based Rule ===")
{:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["r.sub.Age >= 21", "/data3", "purchase"])

dave = %{Name: "dave", Age: 20}
eve = %{Name: "eve", Age: 22}

IO.puts("dave (20) can purchase /data3 (21+): #{CasbinEx2.Enforcer.enforce(enforcer, [dave, "/data3", "purchase"])}")
IO.puts("eve (22) can purchase /data3 (21+): #{CasbinEx2.Enforcer.enforce(enforcer, [eve, "/data3", "purchase"])}")

IO.puts("\n✅ ABAC with rules example completed!")
