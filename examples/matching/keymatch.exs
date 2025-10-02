# KeyMatch Example
# This demonstrates keyMatch() function for URL path pattern matching
# keyMatch() matches patterns like /resource/* to /resource/123

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer with keyMatch model
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/matching/keymatch_model.conf",
    "examples/matching/keymatch_policy.csv"
  )

# Test alice's wildcard access to /alice_data/*
IO.puts("\n=== Alice's Wildcard Access (/alice_data/*) ===")
IO.puts("alice can GET /alice_data/file1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "/alice_data/file1", "GET"])}")
IO.puts("alice can GET /alice_data/file2: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "/alice_data/file2", "GET"])}")
IO.puts("alice can GET /alice_data/subdir/file: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "/alice_data/subdir/file", "GET"])}")
IO.puts("alice can POST /alice_data/file1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "/alice_data/file1", "POST"])}")

# Test alice's specific resource access
IO.puts("\n=== Alice's Specific Resource Access ===")
IO.puts("alice can POST /alice_data/resource1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "/alice_data/resource1", "POST"])}")
IO.puts("alice can POST /alice_data/resource2: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "/alice_data/resource2", "POST"])}")

# Test bob's permissions
IO.puts("\n=== Bob's Permissions ===")
IO.puts("bob can GET /alice_data/resource2: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "/alice_data/resource2", "GET"])}")
IO.puts("bob can GET /alice_data/resource1: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "/alice_data/resource1", "GET"])}")
IO.puts("bob can POST /bob_data/file1: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "/bob_data/file1", "POST"])}")
IO.puts("bob can POST /bob_data/subdir/file: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "/bob_data/subdir/file", "POST"])}")

# Test cathy's regex action matching
IO.puts("\n=== Cathy's Regex Action Matching (GET|POST) ===")
IO.puts("cathy can GET /cathy_data: #{CasbinEx2.Enforcer.enforce(enforcer, ["cathy", "/cathy_data", "GET"])}")
IO.puts("cathy can POST /cathy_data: #{CasbinEx2.Enforcer.enforce(enforcer, ["cathy", "/cathy_data", "POST"])}")
IO.puts("cathy can DELETE /cathy_data: #{CasbinEx2.Enforcer.enforce(enforcer, ["cathy", "/cathy_data", "DELETE"])}")

# Use case: RESTful API authorization
IO.puts("\n=== Use Case: RESTful API Authorization ===")
api_requests = [
  ["alice", "/alice_data/users/123", "GET"],
  ["alice", "/alice_data/posts/456", "GET"],
  ["bob", "/bob_data/comments/789", "POST"],
  ["bob", "/bob_data/likes/111", "POST"]
]

IO.puts("API Request Authorization:")
for [user, path, method] <- api_requests do
  result = CasbinEx2.Enforcer.enforce(enforcer, [user, path, method])
  status = if result, do: "✓ ALLOWED", else: "✗ DENIED"
  IO.puts("  #{status}: #{user} #{method} #{path}")
end

# Add new wildcard permission
IO.puts("\n=== Adding New Wildcard Permission ===")
{:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["dave", "/dave_data/*", "GET"])
IO.puts("dave can GET /dave_data/any/resource: #{CasbinEx2.Enforcer.enforce(enforcer, ["dave", "/dave_data/any/resource", "GET"])}")

IO.puts("\n✅ KeyMatch example completed!")
