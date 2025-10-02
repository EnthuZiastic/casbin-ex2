# IP Match Example
# This demonstrates ipMatch() function for IP CIDR matching
# Useful for network-based authorization and firewall rules

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer with IP matching model
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/matching/ipmatch_model.conf",
    "examples/matching/ipmatch_policy.csv"
  )

# Test 192.168.2.0/24 network (allows data1 read)
IO.puts("\n=== Network 192.168.2.0/24 Access (data1 read) ===")
IO.puts("192.168.2.1 can read data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["192.168.2.1", "data1", "read"])}")
IO.puts("192.168.2.100 can read data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["192.168.2.100", "data1", "read"])}")
IO.puts("192.168.2.254 can read data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["192.168.2.254", "data1", "read"])}")
IO.puts("192.168.3.1 can read data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["192.168.3.1", "data1", "read"])}")
IO.puts("192.168.2.1 can write data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["192.168.2.1", "data1", "write"])}")

# Test 10.0.0.0/16 network (allows data2 write)
IO.puts("\n=== Network 10.0.0.0/16 Access (data2 write) ===")
IO.puts("10.0.0.1 can write data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["10.0.0.1", "data2", "write"])}")
IO.puts("10.0.1.1 can write data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["10.0.1.1", "data2", "write"])}")
IO.puts("10.0.255.254 can write data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["10.0.255.254", "data2", "write"])}")
IO.puts("10.1.0.1 can write data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["10.1.0.1", "data2", "write"])}")
IO.puts("10.0.0.1 can read data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["10.0.0.1", "data2", "read"])}")

# Use case: Office network access
IO.puts("\n=== Use Case: Office Network Access ===")
IO.puts("Scenario: 192.168.2.0/24 is the development network")
IO.puts("          10.0.0.0/16 is the production network")
IO.puts("")
IO.puts("Dev network (192.168.2.50) can read data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["192.168.2.50", "data1", "read"])}")
IO.puts("Prod network (10.0.5.10) can write data2: #{CasbinEx2.Enforcer.enforce(enforcer, ["10.0.5.10", "data2", "write"])}")

# Add tighter subnet for admin access
IO.puts("\n=== Adding Tighter Subnet for Admin Access ===")
{:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["192.168.2.0/28", "admin_panel", "access"])

IO.puts("192.168.2.1 (in /28) can access admin_panel: #{CasbinEx2.Enforcer.enforce(enforcer, ["192.168.2.1", "admin_panel", "access"])}")
IO.puts("192.168.2.10 (in /28) can access admin_panel: #{CasbinEx2.Enforcer.enforce(enforcer, ["192.168.2.10", "admin_panel", "access"])}")
IO.puts("192.168.2.20 (not in /28) can access admin_panel: #{CasbinEx2.Enforcer.enforce(enforcer, ["192.168.2.20", "admin_panel", "access"])}")
IO.puts("192.168.2.100 (not in /28) can access admin_panel: #{CasbinEx2.Enforcer.enforce(enforcer, ["192.168.2.100", "admin_panel", "access"])}")

# Use case: API rate limiting by IP range
IO.puts("\n=== Use Case: API Rate Limiting by IP Range ===")
{:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["203.0.113.0/24", "api", "standard"])
{:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["198.51.100.0/24", "api", "premium"])

IO.puts("Standard customer (203.0.113.50): #{CasbinEx2.Enforcer.enforce(enforcer, ["203.0.113.50", "api", "standard"])}")
IO.puts("Standard customer (203.0.113.50) premium: #{CasbinEx2.Enforcer.enforce(enforcer, ["203.0.113.50", "api", "premium"])}")
IO.puts("Premium customer (198.51.100.10): #{CasbinEx2.Enforcer.enforce(enforcer, ["198.51.100.10", "api", "premium"])}")
IO.puts("Premium customer (198.51.100.10) standard: #{CasbinEx2.Enforcer.enforce(enforcer, ["198.51.100.10", "api", "standard"])}")

# Use case: Geographic restrictions
IO.puts("\n=== Use Case: Geographic IP Restrictions ===")
IO.puts("Different IP ranges can represent different geographic regions")
IO.puts("Policies can restrict access based on user location")

IO.puts("\n✅ IP match example completed!")
