#!/usr/bin/env elixir

# Basic usage example for CasbinEx2
# This demonstrates basic ACL with RBAC support using file-based policies

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Define model and policy file paths
model_path = Path.join(__DIR__, "rbac_model.conf")
policy_path = Path.join(__DIR__, "rbac_policy.csv")

# Start an enforcer with file adapter
adapter = CasbinEx2.Adapter.FileAdapter.new(policy_path)
{:ok, _pid} = CasbinEx2.start_enforcer(:demo_enforcer, model_path, adapter: adapter)

IO.puts("=== CasbinEx2 Basic Usage Example ===\n")

# Test pre-loaded policies from rbac_policy.csv
IO.puts("=== Testing Pre-loaded Policies ===")

# Alice can read data1 (from CSV)
result1 = CasbinEx2.enforce(:demo_enforcer, ["alice", "data1", "read"])
IO.puts("✓ Alice can read data1: #{result1}")

# Bob can write data2 (from CSV)
result2 = CasbinEx2.enforce(:demo_enforcer, ["bob", "data2", "write"])
IO.puts("✓ Bob can write data2: #{result2}")

# Alice has data_group_admin role (from CSV)
result3 = CasbinEx2.enforce(:demo_enforcer, ["alice", "data_group", "write"])
IO.puts("✓ Alice can write data_group (through role): #{result3}")

# Test adding policies at runtime
IO.puts("\n=== Adding Policies Dynamically ===")

CasbinEx2.add_policy(:demo_enforcer, ["charlie", "data3", "read"])
IO.puts("✓ Added policy: charlie can read data3")

result4 = CasbinEx2.enforce(:demo_enforcer, ["charlie", "data3", "read"])
IO.puts("✓ Charlie can read data3: #{result4}")

# Test adding roles
IO.puts("\n=== Working with Roles ===")

CasbinEx2.add_role_for_user(:demo_enforcer, "bob", "editor")
IO.puts("✓ Added role: bob is now editor")

CasbinEx2.add_policy(:demo_enforcer, ["editor", "data2", "read"])
IO.puts("✓ Added policy: editor can read data2")

result5 = CasbinEx2.enforce(:demo_enforcer, ["bob", "data2", "read"])
IO.puts("✓ Bob can read data2 (through editor role): #{result5}")

# Test role queries
IO.puts("\n=== Role Queries ===")

roles = CasbinEx2.get_roles_for_user(:demo_enforcer, "alice")
IO.puts("✓ Alice's roles: #{inspect(roles)}")

roles = CasbinEx2.get_roles_for_user(:demo_enforcer, "bob")
IO.puts("✓ Bob's roles: #{inspect(roles)}")

users = CasbinEx2.get_users_for_role(:demo_enforcer, "editor")
IO.puts("✓ Users with editor role: #{inspect(users)}")

# Test policy queries
IO.puts("\n=== Policy Queries ===")

policies = CasbinEx2.get_policy(:demo_enforcer)
IO.puts("✓ Total policies: #{length(policies)}")
IO.puts("  Policies: #{inspect(policies, limit: 5)}")

has_policy = CasbinEx2.has_policy(:demo_enforcer, ["alice", "data1", "read"])
IO.puts("✓ Has policy [alice, data1, read]: #{has_policy}")

# Test negative cases
IO.puts("\n=== Negative Authorization Tests ===")

result6 = CasbinEx2.enforce(:demo_enforcer, ["bob", "data1", "read"])
IO.puts("✓ Bob can read data1: #{result6} (expected: false)")

result7 = CasbinEx2.enforce(:demo_enforcer, ["charlie", "data1", "write"])
IO.puts("✓ Charlie can write data1: #{result7} (expected: false)")

# Clean up
IO.puts("\n=== Cleanup ===")
CasbinEx2.stop_enforcer(:demo_enforcer)
IO.puts("✓ Enforcer stopped")

IO.puts("\n=== Demo completed successfully! ===")
IO.puts("\nTry modifying rbac_policy.csv and re-running this example.")