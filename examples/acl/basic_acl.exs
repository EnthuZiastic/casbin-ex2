# Basic ACL Example
# This demonstrates simple Access Control List (ACL) authorization
# Users have direct permissions on resources without roles

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer with basic ACL model
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/acl/basic_model.conf",
    "examples/acl/basic_policy.csv"
  )

# Test alice's permissions
IO.puts("\n=== Testing Alice's Permissions ===")
IO.puts("alice can read data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data1", "read"])}")
IO.puts("alice can write data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data1", "write"])}")
IO.puts("alice can read data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data2", "read"])}")

# Test bob's permissions
IO.puts("\n=== Testing Bob's Permissions ===")
IO.puts("bob can write data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "data2", "write"])}")
IO.puts("bob can read data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "data2", "read"])}")
IO.puts("bob can write data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "data1", "write"])}")

# Add a new permission dynamically
IO.puts("\n=== Adding New Permission ===")
{:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "data2", "write"])
IO.puts("alice can now write data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data2", "write"])}")

# Remove a permission
IO.puts("\n=== Removing Permission ===")
{:ok, enforcer} = CasbinEx2.Management.remove_policy(enforcer, ["alice", "data1", "read"])
IO.puts("alice can read data1 after removal: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data1", "read"])}")

IO.puts("\n✅ Basic ACL example completed!")
