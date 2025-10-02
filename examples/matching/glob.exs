# Glob Match Example
# This demonstrates globMatch() function for shell-style pattern matching
# Supports * wildcard for flexible path matching

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer with glob matching model
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/matching/glob_model.conf",
    "examples/matching/glob_policy.csv"
  )

# Test u1's pattern: /foo/*
IO.puts("\n=== u1's Pattern: /foo/* ===")
IO.puts("u1 can read /foo/bar: #{CasbinEx2.Enforcer.enforce(enforcer, ["u1", "/foo/bar", "read"])}")
IO.puts("u1 can read /foo/baz: #{CasbinEx2.Enforcer.enforce(enforcer, ["u1", "/foo/baz", "read"])}")
IO.puts("u1 can read /foo: #{CasbinEx2.Enforcer.enforce(enforcer, ["u1", "/foo", "read"])}")
IO.puts("u1 can read /foobar: #{CasbinEx2.Enforcer.enforce(enforcer, ["u1", "/foobar", "read"])}")

# Test u2's pattern: /foo*
IO.puts("\n=== u2's Pattern: /foo* ===")
IO.puts("u2 can read /foo: #{CasbinEx2.Enforcer.enforce(enforcer, ["u2", "/foo", "read"])}")
IO.puts("u2 can read /foobar: #{CasbinEx2.Enforcer.enforce(enforcer, ["u2", "/foobar", "read"])}")
IO.puts("u2 can read /foo/bar: #{CasbinEx2.Enforcer.enforce(enforcer, ["u2", "/foo/bar", "read"])}")
IO.puts("u2 can read /bar: #{CasbinEx2.Enforcer.enforce(enforcer, ["u2", "/bar", "read"])}")

# Test u3's pattern: /*/foo/*
IO.puts("\n=== u3's Pattern: /*/foo/* ===")
IO.puts("u3 can read /bar/foo/baz: #{CasbinEx2.Enforcer.enforce(enforcer, ["u3", "/bar/foo/baz", "read"])}")
IO.puts("u3 can read /data/foo/file: #{CasbinEx2.Enforcer.enforce(enforcer, ["u3", "/data/foo/file", "read"])}")
IO.puts("u3 can read /foo/bar: #{CasbinEx2.Enforcer.enforce(enforcer, ["u3", "/foo/bar", "read"])}")
IO.puts("u3 can read /bar/foo: #{CasbinEx2.Enforcer.enforce(enforcer, ["u3", "/bar/foo", "read"])}")

# Test u4's pattern: * (matches everything)
IO.puts("\n=== u4's Pattern: * (Universal Access) ===")
IO.puts("u4 can read /foo: #{CasbinEx2.Enforcer.enforce(enforcer, ["u4", "/foo", "read"])}")
IO.puts("u4 can read /bar: #{CasbinEx2.Enforcer.enforce(enforcer, ["u4", "/bar", "read"])}")
IO.puts("u4 can read /anything/at/all: #{CasbinEx2.Enforcer.enforce(enforcer, ["u4", "/anything/at/all", "read"])}")

# Use case: File system glob patterns
IO.puts("\n=== Use Case: File System Glob Patterns ===")
{:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["u5", "*.txt", "read"])
{:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["u6", "/docs/*.pdf", "read"])

IO.puts("u5 can read file.txt: #{CasbinEx2.Enforcer.enforce(enforcer, ["u5", "file.txt", "read"])}")
IO.puts("u5 can read document.txt: #{CasbinEx2.Enforcer.enforce(enforcer, ["u5", "document.txt", "read"])}")
IO.puts("u5 can read file.pdf: #{CasbinEx2.Enforcer.enforce(enforcer, ["u5", "file.pdf", "read"])}")

IO.puts("u6 can read /docs/manual.pdf: #{CasbinEx2.Enforcer.enforce(enforcer, ["u6", "/docs/manual.pdf", "read"])}")
IO.puts("u6 can read /docs/guide.pdf: #{CasbinEx2.Enforcer.enforce(enforcer, ["u6", "/docs/guide.pdf", "read"])}")
IO.puts("u6 can read /files/doc.pdf: #{CasbinEx2.Enforcer.enforce(enforcer, ["u6", "/files/doc.pdf", "read"])}")

# Pattern comparison
IO.puts("\n=== Pattern Comparison ===")
IO.puts("Glob patterns are more flexible than simple wildcards")
IO.puts("They support shell-style matching with * anywhere in the pattern")

IO.puts("\n✅ Glob match example completed!")
