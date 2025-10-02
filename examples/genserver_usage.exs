#!/usr/bin/env elixir

# GenServer usage example for CasbinEx2
# This demonstrates using CasbinEx2 with supervised processes

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Define model and policy file paths
model_path = Path.join(__DIR__, "rbac_model.conf")
policy_path = Path.join(__DIR__, "rbac_policy.csv")

IO.puts("=== CasbinEx2 GenServer Usage Example ===\n")

# Method 1: Start enforcer with FileAdapter
IO.puts("=== Method 1: Using File Adapter ===")
adapter = CasbinEx2.Adapter.FileAdapter.new(policy_path)
{:ok, pid1} = CasbinEx2.start_enforcer(:file_enforcer, model_path, adapter: adapter)
IO.puts("✓ Started enforcer with PID: #{inspect(pid1)}")

# Verify it works
result1 = CasbinEx2.enforce(:file_enforcer, ["alice", "data1", "read"])
IO.puts("✓ Enforcement test: #{result1}")

# Method 2: Start multiple enforcers (multi-tenant scenario)
IO.puts("\n=== Method 2: Multiple Enforcers (Multi-tenant) ===")

{:ok, _pid2} = CasbinEx2.start_enforcer(:tenant1_enforcer, model_path)
IO.puts("✓ Started tenant1 enforcer")

{:ok, _pid3} = CasbinEx2.start_enforcer(:tenant2_enforcer, model_path)
IO.puts("✓ Started tenant2 enforcer")

# Configure different policies for each tenant
CasbinEx2.add_policy(:tenant1_enforcer, ["alice", "tenant1_data", "read"])
CasbinEx2.add_policy(:tenant2_enforcer, ["bob", "tenant2_data", "write"])

result2 = CasbinEx2.enforce(:tenant1_enforcer, ["alice", "tenant1_data", "read"])
IO.puts("✓ Tenant1: Alice can read tenant1_data: #{result2}")

result3 = CasbinEx2.enforce(:tenant2_enforcer, ["bob", "tenant2_data", "write"])
IO.puts("✓ Tenant2: Bob can write tenant2_data: #{result3}")

# Verify isolation
result4 = CasbinEx2.enforce(:tenant2_enforcer, ["alice", "tenant1_data", "read"])
IO.puts("✓ Tenant2: Alice CANNOT read tenant1_data: #{result4} (isolated)")

# Method 3: Using EnforceServer directly with options
IO.puts("\n=== Method 3: EnforceServer with Custom Options ===")

{:ok, _pid4} =
  CasbinEx2.EnforceServer.start_link(
    name: :cached_enforcer,
    model_path: model_path,
    adapter: adapter,
    enable_cache: true,
    auto_save: false
  )

IO.puts("✓ Started cached enforcer with custom options")

# Add policies to cached enforcer
CasbinEx2.add_policy(:cached_enforcer, ["charlie", "cached_data", "read"])
result5 = CasbinEx2.enforce(:cached_enforcer, ["charlie", "cached_data", "read"])
IO.puts("✓ Cached enforcement: #{result5}")

# Demonstrate persistence control
IO.puts("\n=== Method 4: Manual Save Control ===")

# Disable auto-save for batch operations
{:ok, _pid5} = CasbinEx2.start_enforcer(:batch_enforcer, model_path, auto_save: false)
IO.puts("✓ Started enforcer with auto_save disabled")

# Add multiple policies efficiently
policies = [
  ["user1", "resource1", "read"],
  ["user2", "resource2", "write"],
  ["user3", "resource3", "delete"]
]

Enum.each(policies, fn policy ->
  CasbinEx2.add_policy(:batch_enforcer, policy)
end)

IO.puts("✓ Added #{length(policies)} policies in batch mode")

# Manually save when done
# Note: save_policy would be called if we had a writable adapter
# CasbinEx2.save_policy(:batch_enforcer)
# IO.puts("✓ Manually saved policies")

# Process information
IO.puts("\n=== Process Information ===")
IO.puts("✓ File enforcer PID: #{inspect(pid1)}")
IO.puts("✓ File enforcer alive: #{Process.alive?(pid1)}")

# Check enforcer status
policy_count = length(CasbinEx2.get_policy(:file_enforcer))
IO.puts("✓ File enforcer has #{policy_count} policies")

# Demonstrate graceful shutdown
IO.puts("\n=== Cleanup ===")

CasbinEx2.stop_enforcer(:file_enforcer)
IO.puts("✓ Stopped file_enforcer")

CasbinEx2.stop_enforcer(:tenant1_enforcer)
CasbinEx2.stop_enforcer(:tenant2_enforcer)
IO.puts("✓ Stopped tenant enforcers")

CasbinEx2.stop_enforcer(:cached_enforcer)
IO.puts("✓ Stopped cached_enforcer")

CasbinEx2.stop_enforcer(:batch_enforcer)
IO.puts("✓ Stopped batch_enforcer")

# Verify all stopped
IO.puts("✓ File enforcer still alive: #{Process.alive?(pid1)} (should be false)")

IO.puts("\n=== Demo completed successfully! ===")

IO.puts("""

Key Takeaways:
- Each enforcer runs in its own supervised GenServer process
- Multiple enforcers can run simultaneously (multi-tenant support)
- Processes are isolated - policies don't leak between enforcers
- Enforcers can be configured with options (caching, auto-save, etc.)
- Graceful shutdown with stop_enforcer/1
""")
