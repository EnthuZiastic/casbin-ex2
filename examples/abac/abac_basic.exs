# Basic ABAC Example
# This demonstrates Attribute-Based Access Control (ABAC)
# Authorization based on attributes of subject and object

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer with ABAC model (no policy file needed)
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/abac/abac_model.conf",
    ""
  )

# Test with objects that have Owner attribute
IO.puts("\n=== Testing ABAC with Owner Attribute ===")

# Create resource objects with owners
data1 = %{Name: "data1", Owner: "alice"}
data2 = %{Name: "data2", Owner: "bob"}
data3 = %{Name: "data3", Owner: "alice"}

# Alice can access her own resources
IO.puts("alice can access data1 (she owns it): #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", data1, "read"])}")
IO.puts("alice can access data3 (she owns it): #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", data3, "write"])}")

# Alice cannot access bob's resources
IO.puts("alice can access data2 (owned by bob): #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", data2, "read"])}")

# Bob can access his own resources
IO.puts("bob can access data2 (he owns it): #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", data2, "write"])}")

# Bob cannot access alice's resources
IO.puts("bob can access data1 (owned by alice): #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", data1, "read"])}")

# Use case: Document ownership
IO.puts("\n=== Use Case: Document Ownership ===")
document = %{
  id: 123,
  title: "Quarterly Report",
  Owner: "charlie"
}

IO.puts("charlie can edit his document: #{CasbinEx2.Enforcer.enforce(enforcer, ["charlie", document, "edit"])}")
IO.puts("alice can edit charlie's document: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", document, "edit"])}")

# Use case: File system permissions
IO.puts("\n=== Use Case: File System Permissions ===")
file1 = %{path: "/home/alice/file.txt", Owner: "alice"}
file2 = %{path: "/home/bob/file.txt", Owner: "bob"}

IO.puts("alice can read #{file1.path}: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", file1, "read"])}")
IO.puts("alice can read #{file2.path}: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", file2, "read"])}")
IO.puts("bob can read #{file2.path}: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", file2, "read"])}")

IO.puts("\n✅ Basic ABAC example completed!")
