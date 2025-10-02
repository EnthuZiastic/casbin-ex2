# RBAC with Pattern Matching Example
# This demonstrates pattern-based resource matching in RBAC
# Uses regex and wildcard patterns for flexible resource authorization

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer with pattern-based RBAC model
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/rbac/rbac_with_pattern_model.conf",
    "examples/rbac/rbac_with_pattern_policy.csv"
  )

# Test alice's direct permissions
IO.puts("\n=== Alice's Direct Permissions ===")
IO.puts("alice can GET /pen/1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "/pen/1", "GET"])}")
IO.puts("alice can GET /pen2/1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "/pen2/1", "GET"])}")

# Test alice's role-based permissions with pattern matching
# alice -> book_admin -> book_group, which matches /book/* pattern
IO.puts("\n=== Alice's Pattern-Based Permissions (book_admin) ===")
IO.puts("alice can GET /book/123: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "/book/123", "GET"])}")
IO.puts("alice can GET /book/456: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "/book/456", "GET"])}")
IO.puts("alice can POST /book/123: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "/book/123", "POST"])}")

# Test bob's pattern-based permissions
# bob -> pen_admin -> pen_group, which matches /pen/:id pattern
IO.puts("\n=== Bob's Pattern-Based Permissions (pen_admin) ===")
IO.puts("bob can GET /pen/1: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "/pen/1", "GET"])}")
IO.puts("bob can GET /pen/999: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "/pen/999", "GET"])}")
IO.puts("bob can GET /book/123: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "/book/123", "GET"])}")

# Test wildcard pattern - everyone can access pen3_group
IO.puts("\n=== Wildcard Pattern (Everyone) ===")
IO.puts("alice can GET /pen3/1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "/pen3/1", "GET"])}")
IO.puts("bob can GET /pen3/2: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "/pen3/2", "GET"])}")
IO.puts("charlie can GET /pen3/999: #{CasbinEx2.Enforcer.enforce(enforcer, ["charlie", "/pen3/999", "GET"])}")

# Test cathy's complex permissions
IO.puts("\n=== Cathy's Complex Permissions ===")
IO.puts("cathy has pen_admin role")
IO.puts("cathy can GET /pen/5: #{CasbinEx2.Enforcer.enforce(enforcer, ["cathy", "/pen/5", "GET"])}")

# REST API pattern example
IO.puts("\n=== REST API Pattern Example ===")
{:ok, enforcer} = CasbinEx2.RBAC.add_role_for_user(enforcer, "dave", "book_admin")
IO.puts("dave (book_admin) can GET /book/1: #{CasbinEx2.Enforcer.enforce(enforcer, ["dave", "/book/1", "GET"])}")
IO.puts("dave (book_admin) can GET /book/100: #{CasbinEx2.Enforcer.enforce(enforcer, ["dave", "/book/100", "GET"])}")
IO.puts("dave (book_admin) can DELETE /book/1: #{CasbinEx2.Enforcer.enforce(enforcer, ["dave", "/book/1", "DELETE"])}")

IO.puts("\n✅ RBAC with pattern matching example completed!")
