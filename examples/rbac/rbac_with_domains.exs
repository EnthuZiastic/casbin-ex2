# RBAC with Domains Example
# This demonstrates multi-tenancy with domain-based RBAC
# Users can have different roles in different domains/tenants

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer with domain-based RBAC model
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/rbac/rbac_with_domains_model.conf",
    "examples/rbac/rbac_with_domains_policy.csv"
  )

# Test alice in domain1 (she is admin there)
IO.puts("\n=== Alice in Domain1 (Admin) ===")
IO.puts("alice can read data1 in domain1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "domain1", "data1", "read"])}")
IO.puts("alice can write data1 in domain1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "domain1", "data1", "write"])}")

# Test alice in domain2 (she is NOT admin there)
IO.puts("\n=== Alice in Domain2 (Not Admin) ===")
IO.puts("alice can read data2 in domain2: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "domain2", "data2", "read"])}")
IO.puts("alice can write data2 in domain2: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "domain2", "data2", "write"])}")

# Test bob in domain2 (he is admin there)
IO.puts("\n=== Bob in Domain2 (Admin) ===")
IO.puts("bob can read data2 in domain2: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "domain2", "data2", "read"])}")
IO.puts("bob can write data2 in domain2: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "domain2", "data2", "write"])}")

# Test bob in domain1 (he is NOT admin there)
IO.puts("\n=== Bob in Domain1 (Not Admin) ===")
IO.puts("bob can read data1 in domain1: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", "domain1", "data1", "read"])}")

# Show roles in specific domains
IO.puts("\n=== Domain-Specific Roles ===")
alice_roles_d1 = CasbinEx2.RBAC.get_roles_for_user_in_domain(enforcer, "alice", "domain1")
alice_roles_d2 = CasbinEx2.RBAC.get_roles_for_user_in_domain(enforcer, "alice", "domain2")
IO.puts("alice's roles in domain1: #{inspect(alice_roles_d1)}")
IO.puts("alice's roles in domain2: #{inspect(alice_roles_d2)}")

bob_roles_d1 = CasbinEx2.RBAC.get_roles_for_user_in_domain(enforcer, "bob", "domain1")
bob_roles_d2 = CasbinEx2.RBAC.get_roles_for_user_in_domain(enforcer, "bob", "domain2")
IO.puts("bob's roles in domain1: #{inspect(bob_roles_d1)}")
IO.puts("bob's roles in domain2: #{inspect(bob_roles_d2)}")

# Add alice as admin in domain2 as well
IO.puts("\n=== Making Alice Admin in Domain2 ===")
{:ok, enforcer} = CasbinEx2.RBAC.add_role_for_user_in_domain(enforcer, "alice", "admin", "domain2")
IO.puts("alice can now write data2 in domain2: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", "domain2", "data2", "write"])}")

# Get all domains
IO.puts("\n=== All Domains ===")
domains = CasbinEx2.RBAC.get_all_domains(enforcer)
IO.puts("Available domains: #{inspect(domains)}")

IO.puts("\n✅ RBAC with domains example completed!")
