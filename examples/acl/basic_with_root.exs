# ACL with Superuser Example
# This demonstrates ACL with a superuser (root) who can access everything
# The matcher includes: || r.sub == "root"

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer with superuser model
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/acl/basic_with_root_model.conf",
    "examples/acl/basic_with_root_policy.csv"
  )

# Test regular users
IO.puts("\n=== Testing Regular Users ===")
IO.puts("alice can read data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data1", "read"])}")
IO.puts("alice can write data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data1", "write"])}")
IO.puts("bob can write data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "data2", "write"])}")
IO.puts("bob can read data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "data1", "read"])}")

# Test root superuser (no policies needed!)
IO.puts("\n=== Testing Root Superuser ===")
IO.puts("root can read data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["root", "data1", "read"])}")
IO.puts("root can write data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["root", "data1", "write"])}")
IO.puts("root can read data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["root", "data2", "read"])}")
IO.puts("root can write data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["root", "data2", "write"])}")
IO.puts("root can delete anything: #{CasbinEx2.Enforcer.enforce(enforcer, ["root", "any_data", "delete"])}")

# Show that root bypasses all policies
IO.puts("\n=== Root Bypasses Policy Checks ===")
policies = CasbinEx2.Management.get_policy(enforcer)
IO.puts("Total policies defined: #{length(policies)}")
IO.puts("But root can access anything without policies!")

IO.puts("\n✅ Superuser ACL example completed!")
