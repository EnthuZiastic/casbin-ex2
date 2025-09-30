#!/usr/bin/env elixir

# Basic usage example for CasbinEx2

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Define model and policy file paths
model_path = Path.join(__DIR__, "rbac_model.conf")
policy_path = Path.join(__DIR__, "rbac_policy.csv")

# Start an enforcer
{:ok, _pid} = CasbinEx2.start_enforcer(:demo_enforcer, model_path)

# Load policies from file
adapter = CasbinEx2.Adapter.FileAdapter.new(policy_path)

# Add some policies manually
CasbinEx2.add_policy(:demo_enforcer, ["alice", "data1", "read"])
CasbinEx2.add_policy(:demo_enforcer, ["bob", "data2", "write"])

# Add roles
CasbinEx2.add_role_for_user(:demo_enforcer, "alice", "admin")
CasbinEx2.add_policy(:demo_enforcer, ["admin", "data1", "write"])

# Test enforcement
IO.puts("=== Authorization Tests ===")

# Alice should be able to read data1 (direct permission)
result1 = CasbinEx2.enforce(:demo_enforcer, ["alice", "data1", "read"])
IO.puts("Alice can read data1: #{result1}")

# Alice should be able to write data1 (through admin role)
result2 = CasbinEx2.enforce(:demo_enforcer, ["alice", "data1", "write"])
IO.puts("Alice can write data1: #{result2}")

# Bob should be able to write data2
result3 = CasbinEx2.enforce(:demo_enforcer, ["bob", "data2", "write"])
IO.puts("Bob can write data2: #{result3}")

# Bob should NOT be able to read data1
result4 = CasbinEx2.enforce(:demo_enforcer, ["bob", "data1", "read"])
IO.puts("Bob can read data1: #{result4}")

# Test role queries
IO.puts("\n=== Role Queries ===")
roles = CasbinEx2.get_roles_for_user(:demo_enforcer, "alice")
IO.puts("Alice's roles: #{inspect(roles)}")

users = CasbinEx2.get_users_for_role(:demo_enforcer, "admin")
IO.puts("Users with admin role: #{inspect(users)}")

# Test policy queries
IO.puts("\n=== Policy Queries ===")
policies = CasbinEx2.get_policy(:demo_enforcer)
IO.puts("All policies: #{inspect(policies)}")

has_policy = CasbinEx2.has_policy(:demo_enforcer, ["alice", "data1", "read"])
IO.puts("Has policy [alice, data1, read]: #{has_policy}")

# Clean up
CasbinEx2.stop_enforcer(:demo_enforcer)

IO.puts("\n=== Demo completed ===")