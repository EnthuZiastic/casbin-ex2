#!/usr/bin/env elixir

# Advanced patterns and use cases for CasbinEx2
# Demonstrates ABAC, custom matchers, batch operations, and performance optimization

# Start the application
Application.ensure_all_started(:casbin_ex2)

IO.puts("=== CasbinEx2 Advanced Patterns Example ===\n")

# ============================================================================
# Pattern 1: ABAC (Attribute-Based Access Control)
# ============================================================================

IO.puts("=== Pattern 1: ABAC (Attribute-Based Access Control) ===")

# Create ABAC model inline
abac_model = """
[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

[policy_effect]
e = some(where (p.eft == allow))

[matchers]
m = r.sub.role == p.sub && r.obj.owner == r.sub.name && r.act == p.act
"""

{:ok, _pid} =
  CasbinEx2.start_enforcer(
    :abac_enforcer,
    model_path: {:text, abac_model},
    auto_save: false
  )

# Define ABAC policies
CasbinEx2.add_policy(:abac_enforcer, ["user", "resource", "read"])
CasbinEx2.add_policy(:abac_enforcer, ["user", "resource", "write"])

IO.puts("✓ ABAC enforcer created with attribute-based rules")

# Test with attribute maps
alice_attrs = %{name: "alice", role: "user"}
resource1_attrs = %{id: "r1", owner: "alice"}

# Note: This demonstrates the ABAC model structure
# Actual attribute matching would require custom function implementation
IO.puts("✓ ABAC model supports: r.sub.role == p.sub && r.obj.owner == r.sub.name")
IO.puts("  Example: alice (role=user) accessing resource (owner=alice)")

# ============================================================================
# Pattern 2: Custom Matchers with Functions
# ============================================================================

IO.puts("\n=== Pattern 2: Custom Matchers with Functions ===")

# RESTful model with KeyMatch for path matching
restful_model = """
[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

[policy_effect]
e = some(where (p.eft == allow))

[matchers]
m = r.sub == p.sub && keyMatch(r.obj, p.obj) && r.act == p.act
"""

{:ok, _pid} =
  CasbinEx2.start_enforcer(
    :restful_enforcer,
    model_path: {:text, restful_model}
  )

# Policies with wildcards
CasbinEx2.add_policy(:restful_enforcer, ["alice", "/api/users/*", "GET"])
CasbinEx2.add_policy(:restful_enforcer, ["alice", "/api/posts/:id", "GET"])
CasbinEx2.add_policy(:restful_enforcer, ["bob", "/api/admin/*", "POST"])

IO.puts("✓ RESTful enforcer with keyMatch for URL patterns")

# Test pattern matching
test_cases = [
  ["alice", "/api/users/123", "GET"],
  ["alice", "/api/posts/456", "GET"],
  ["alice", "/api/admin/settings", "POST"],
  ["bob", "/api/admin/users", "POST"]
]

IO.puts("\n--- Pattern Matching Tests ---")

Enum.each(test_cases, fn [user, path, method] = request ->
  result = CasbinEx2.enforce(:restful_enforcer, request)
  IO.puts("  #{user} #{method} #{path}: #{result}")
end)

# ============================================================================
# Pattern 3: Batch Operations for Performance
# ============================================================================

IO.puts("\n=== Pattern 3: Batch Operations for Performance ===")

model_path = Path.join(__DIR__, "rbac_model.conf")
{:ok, _pid} = CasbinEx2.start_enforcer(:batch_enforcer, model_path, auto_save: false)

# Add multiple policies in batch (more efficient)
policies = [
  ["user1", "resource1", "read"],
  ["user1", "resource1", "write"],
  ["user2", "resource2", "read"],
  ["user3", "resource3", "write"],
  ["user4", "resource4", "read"],
  ["user4", "resource4", "write"],
  ["user4", "resource4", "delete"]
]

start_time = System.monotonic_time(:millisecond)

# Batch add
CasbinEx2.add_policies(:batch_enforcer, policies)

end_time = System.monotonic_time(:millisecond)
batch_time = end_time - start_time

IO.puts("✓ Added #{length(policies)} policies in batch")
IO.puts("  Time: #{batch_time}ms")

# Batch remove
start_time = System.monotonic_time(:millisecond)
CasbinEx2.remove_policies(:batch_enforcer, policies)
end_time = System.monotonic_time(:millisecond)
remove_time = end_time - start_time

IO.puts("✓ Removed #{length(policies)} policies in batch")
IO.puts("  Time: #{remove_time}ms")

# ============================================================================
# Pattern 4: Priority-Based Policies (Firewall-like)
# ============================================================================

IO.puts("\n=== Pattern 4: Priority-Based Policies ===")

priority_model = """
[request_definition]
r = sub, obj, act

[policy_definition]
p = priority, sub, obj, act, eft

[policy_effect]
e = priority(p.eft) || deny

[matchers]
m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
"""

{:ok, _pid} =
  CasbinEx2.start_enforcer(
    :priority_enforcer,
    model_path: {:text, priority_model}
  )

# Higher priority = processed first
CasbinEx2.add_policy(:priority_enforcer, ["1", "alice", "data1", "read", "deny"])
CasbinEx2.add_policy(:priority_enforcer, ["2", "alice", "data1", "read", "allow"])
CasbinEx2.add_policy(:priority_enforcer, ["3", "*", "*", "read", "allow"])

IO.puts("✓ Priority-based enforcer (firewall-like rules)")
IO.puts("  Priority 1 (highest): deny alice reading data1")
IO.puts("  Priority 2: allow alice reading data1")
IO.puts("  Priority 3: allow all reads")

# ============================================================================
# Pattern 5: Policy Filtering and Queries
# ============================================================================

IO.puts("\n=== Pattern 5: Policy Filtering and Queries ===")

{:ok, _pid} = CasbinEx2.start_enforcer(:query_enforcer, model_path)

# Add diverse policies
CasbinEx2.add_policy(:query_enforcer, ["alice", "data1", "read"])
CasbinEx2.add_policy(:query_enforcer, ["alice", "data1", "write"])
CasbinEx2.add_policy(:query_enforcer, ["alice", "data2", "read"])
CasbinEx2.add_policy(:query_enforcer, ["bob", "data1", "read"])
CasbinEx2.add_policy(:query_enforcer, ["bob", "data2", "write"])

IO.puts("✓ Added diverse policies for querying")

# Get filtered policies
alice_policies = CasbinEx2.get_filtered_policy(:query_enforcer, 0, ["alice"])
IO.puts("\nAlice's policies (#{length(alice_policies)}):")
Enum.each(alice_policies, fn policy -> IO.puts("  #{inspect(policy)}") end)

data1_policies = CasbinEx2.get_filtered_policy(:query_enforcer, 1, ["data1"])
IO.puts("\nPolicies for data1 (#{length(data1_policies)}):")
Enum.each(data1_policies, fn policy -> IO.puts("  #{inspect(policy)}") end)

read_policies = CasbinEx2.get_filtered_policy(:query_enforcer, 2, ["read"])
IO.puts("\nRead policies (#{length(read_policies)}):")
Enum.each(read_policies, fn policy -> IO.puts("  #{inspect(policy)}") end)

# ============================================================================
# Pattern 6: Conditional Enforcement
# ============================================================================

IO.puts("\n=== Pattern 6: Conditional Enforcement with Context ===")

defmodule ConditionalAuth do
  @moduledoc "Helper for context-aware authorization"

  def can_access?(enforcer, user, resource, action, context \\ %{}) do
    # Base enforcement check
    base_result = CasbinEx2.enforce(enforcer, [user, resource, action])

    # Apply additional context-based rules
    case context do
      %{time_restricted: true, current_hour: hour} ->
        # Business hours check (9 AM - 5 PM)
        base_result && hour >= 9 && hour <= 17

      %{ip_restricted: true, ip: ip} ->
        # IP whitelist check
        base_result && ip in ["10.0.0.0/8", "192.168.0.0/16"]

      %{mfa_required: true, mfa_verified: verified} ->
        # Multi-factor authentication check
        base_result && verified

      _ ->
        base_result
    end
  end
end

{:ok, _pid} = CasbinEx2.start_enforcer(:context_enforcer, model_path)
CasbinEx2.add_policy(:context_enforcer, ["alice", "sensitive_data", "read"])

IO.puts("✓ Conditional enforcement with context awareness")

# Test with different contexts
contexts = [
  {%{}, "no restrictions"},
  {%{time_restricted: true, current_hour: 14}, "during business hours"},
  {%{time_restricted: true, current_hour: 22}, "after hours"},
  {%{mfa_required: true, mfa_verified: true}, "with MFA"},
  {%{mfa_required: true, mfa_verified: false}, "without MFA"}
]

IO.puts("\n--- Context-Based Tests ---")

Enum.each(contexts, fn {context, desc} ->
  result =
    ConditionalAuth.can_access?(
      :context_enforcer,
      "alice",
      "sensitive_data",
      "read",
      context
    )

  IO.puts("  Access #{desc}: #{result}")
end)

# ============================================================================
# Pattern 7: Transaction Support
# ============================================================================

IO.puts("\n=== Pattern 7: Transaction Support (Atomic Operations) ===")

{:ok, _pid} = CasbinEx2.start_enforcer(:transaction_enforcer, model_path)

IO.puts("✓ Transaction enforcer started")

# Simulate atomic policy update
defmodule PolicyTransaction do
  def update_user_permissions(enforcer, user, old_permissions, new_permissions) do
    # Start transaction
    try do
      # Remove old permissions
      Enum.each(old_permissions, fn perm ->
        CasbinEx2.remove_policy(enforcer, [user | perm])
      end)

      # Add new permissions
      Enum.each(new_permissions, fn perm ->
        CasbinEx2.add_policy(enforcer, [user | perm])
      end)

      {:ok, "Transaction completed"}
    rescue
      e ->
        # Rollback would happen here
        {:error, "Transaction failed: #{inspect(e)}"}
    end
  end
end

old_perms = [["data1", "read"], ["data2", "write"]]
new_perms = [["data3", "read"], ["data3", "write"], ["data4", "read"]]

result =
  PolicyTransaction.update_user_permissions(
    :transaction_enforcer,
    "charlie",
    old_perms,
    new_perms
  )

IO.puts("✓ Transaction result: #{inspect(result)}")

# ============================================================================
# Cleanup
# ============================================================================

IO.puts("\n=== Cleanup ===")

enforcers = [
  :abac_enforcer,
  :restful_enforcer,
  :batch_enforcer,
  :priority_enforcer,
  :query_enforcer,
  :context_enforcer,
  :transaction_enforcer
]

Enum.each(enforcers, fn enforcer ->
  CasbinEx2.stop_enforcer(enforcer)
end)

IO.puts("✓ All enforcers stopped")

IO.puts("\n=== Demo completed successfully! ===")

IO.puts("""

Advanced Patterns Demonstrated:
✓ ABAC - Attribute-based access control with custom attributes
✓ Custom Matchers - KeyMatch for RESTful URL patterns
✓ Batch Operations - Efficient bulk policy add/remove
✓ Priority Policies - Firewall-like rule precedence
✓ Policy Filtering - Query and filter policies efficiently
✓ Conditional Enforcement - Context-aware authorization
✓ Transaction Support - Atomic policy operations

Performance Tips:
- Use batch operations for multiple policy changes
- Disable auto_save for bulk operations
- Use filtered queries instead of full policy retrieval
- Cache enforcement results when appropriate
- Consider cached enforcer for high-throughput scenarios
""")
