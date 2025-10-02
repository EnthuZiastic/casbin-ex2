# ABAC Without Policy File Example
# This demonstrates pure ABAC without any policy file
# All authorization logic is in the matcher expression

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer with ABAC model (no policy file!)
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/abac/abac_not_using_policy_model.conf",
    ""
  )

# Test pure attribute-based authorization
IO.puts("\n=== Pure ABAC (No Policies) ===")

# Create resources with ownership
doc1 = %{id: 1, title: "Alice's Document", Owner: "alice"}
doc2 = %{id: 2, title: "Bob's Document", Owner: "bob"}

# Owners can access their own resources
IO.puts("alice can access her document: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", doc1, "read"])}")
IO.puts("bob can access his document: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", doc2, "write"])}")

# Non-owners cannot access
IO.puts("alice can access bob's document: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", doc2, "read"])}")
IO.puts("bob can access alice's document: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", doc1, "write"])}")

# Use case: Cloud storage with ownership
IO.puts("\n=== Use Case: Cloud Storage Ownership ===")
files = [
  %{path: "/alice/photo.jpg", Owner: "alice", size: 1024},
  %{path: "/bob/report.pdf", Owner: "bob", size: 2048},
  %{path: "/alice/video.mp4", Owner: "alice", size: 4096}
]

IO.puts("\nAlice's access to all files:")
for file <- files do
  result = CasbinEx2.Enforcer.enforce(enforcer, ["alice", file, "read"])
  IO.puts("  #{file.path}: #{result}")
end

IO.puts("\nBob's access to all files:")
for file <- files do
  result = CasbinEx2.Enforcer.enforce(enforcer, ["bob", file, "read"])
  IO.puts("  #{file.path}: #{result}")
end

# Use case: Multi-tenant SaaS application
IO.puts("\n=== Use Case: Multi-Tenant SaaS ===")
projects = [
  %{name: "Project A", Owner: "tenant1", users: 10},
  %{name: "Project B", Owner: "tenant2", users: 25},
  %{name: "Project C", Owner: "tenant1", users: 5}
]

IO.puts("\nTenant1's projects:")
for project <- projects do
  if CasbinEx2.Enforcer.enforce(enforcer, ["tenant1", project, "manage"]) do
    IO.puts("  ✓ #{project.name} (#{project.users} users)")
  end
end

IO.puts("\nTenant2's projects:")
for project <- projects do
  if CasbinEx2.Enforcer.enforce(enforcer, ["tenant2", project, "manage"]) do
    IO.puts("  ✓ #{project.name} (#{project.users} users)")
  end
end

# Demonstrate: No policies needed!
IO.puts("\n=== No Policies Required ===")
policies = CasbinEx2.Management.get_policy(enforcer)
IO.puts("Total policies defined: #{length(policies)}")
IO.puts("Authorization works purely through attribute matching!")

IO.puts("\n✅ ABAC without policy file example completed!")
