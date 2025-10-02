# Regex Match Example
# This demonstrates regexMatch() function for full regular expression matching
# Most flexible matching function supporting complex patterns

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer with regex matching model
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/matching/regex_model.conf",
    "examples/matching/regex_policy.csv"
  )

# Test alice|bob pattern
IO.puts("\n=== Pattern: alice|bob on /data[0-9]+ ===")
IO.puts("alice can read /data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "/data1", "read"])}")
IO.puts("alice can write /data9: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "/data9", "write"])}")
IO.puts("bob can read /data5: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "/data5", "read"])}")
IO.puts("charlie can read /data1: #{CasbinEx2.Enforcer.enforce(enforcer, ["charlie", "/data1", "read"])}")
IO.puts("alice can read /data: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "/data", "read"])}")
IO.puts("alice can read /data1x: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "/data1x", "read"])}")

# Test admin_.* pattern
IO.puts("\n=== Pattern: admin_.* on /admin/.* ===")
IO.puts("admin_john can read /admin/users: #{CasbinEx2.Enforcer.enforce(enforcer, ["admin_john", "/admin/users", "read"])}")
IO.puts("admin_sarah can delete /admin/logs: #{CasbinEx2.Enforcer.enforce(enforcer, ["admin_sarah", "/admin/logs", "delete"])}")
IO.puts("admin_123 can write /admin/config: #{CasbinEx2.Enforcer.enforce(enforcer, ["admin_123", "/admin/config", "write"])}")
IO.puts("user_john can read /admin/users: #{CasbinEx2.Enforcer.enforce(enforcer, ["user_john", "/admin/users", "read"])}")
IO.puts("admin_john can read /user/data: #{CasbinEx2.Enforcer.enforce(enforcer, ["admin_john", "/user/data", "read"])}")

# Test user_[a-z]+ pattern
IO.puts("\n=== Pattern: user_[a-z]+ on /user/[a-z]+/.* ===")
IO.puts("user_alice can read /user/alice/profile: #{CasbinEx2.Enforcer.enforce(enforcer, ["user_alice", "/user/alice/profile", "read"])}")
IO.puts("user_bob can read /user/bob/settings: #{CasbinEx2.Enforcer.enforce(enforcer, ["user_bob", "/user/bob/settings", "read"])}")
IO.puts("user_alice can write /user/alice/data: #{CasbinEx2.Enforcer.enforce(enforcer, ["user_alice", "/user/alice/data", "write"])}")
IO.puts("user_123 can read /user/alice/profile: #{CasbinEx2.Enforcer.enforce(enforcer, ["user_123", "/user/alice/profile", "read"])}")
IO.puts("user_alice can read /user/Alice/profile: #{CasbinEx2.Enforcer.enforce(enforcer, ["user_alice", "/user/Alice/profile", "read"])}")

# Test email pattern
IO.puts("\n=== Pattern: .*@company\\.com on /shared/.* ===")
IO.puts("alice@company.com can read /shared/docs: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice@company.com", "/shared/docs", "read"])}")
IO.puts("bob@company.com can read /shared/files: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob@company.com", "/shared/files", "read"])}")
IO.puts("alice@other.com can read /shared/docs: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice@other.com", "/shared/docs", "read"])}")
IO.puts("alice@company.com can write /shared/docs: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice@company.com", "/shared/docs", "write"])}")

# Use case: Dynamic user patterns
IO.puts("\n=== Use Case: Dynamic User Patterns ===")
{:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["dev_.*", "/api/v[0-9]+/.*", "GET|POST"])

IO.puts("dev_alice can GET /api/v1/users: #{CasbinEx2.Enforcer.enforce(enforcer, ["dev_alice", "/api/v1/users", "GET"])}")
IO.puts("dev_bob can POST /api/v2/data: #{CasbinEx2.Enforcer.enforce(enforcer, ["dev_bob", "/api/v2/data", "POST"])}")
IO.puts("dev_charlie can DELETE /api/v1/users: #{CasbinEx2.Enforcer.enforce(enforcer, ["dev_charlie", "/api/v1/users", "DELETE"])}")
IO.puts("user_alice can GET /api/v1/users: #{CasbinEx2.Enforcer.enforce(enforcer, ["user_alice", "/api/v1/users", "GET"])}")

# Use case: API versioning
IO.puts("\n=== Use Case: API Versioning ===")
IO.puts("Regex patterns can match versioned API endpoints")
IO.puts("Pattern /api/v[0-9]+/.* matches /api/v1/..., /api/v2/..., etc.")

# Complex pattern combinations
IO.puts("\n=== Complex Pattern Combinations ===")
{:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["[a-z]+_[0-9]+", "/files/.*\\.(txt|pdf)", "read"])

IO.puts("user_123 can read /files/document.pdf: #{CasbinEx2.Enforcer.enforce(enforcer, ["user_123", "/files/document.pdf", "read"])}")
IO.puts("alice_456 can read /files/notes.txt: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice_456", "/files/notes.txt", "read"])}")
IO.puts("user_123 can read /files/image.jpg: #{CasbinEx2.Enforcer.enforce(enforcer, ["user_123", "/files/image.jpg", "read"])}")

IO.puts("\n✅ Regex match example completed!")
