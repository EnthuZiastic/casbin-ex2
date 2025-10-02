# Bell-LaPadula (BLP) Confidentiality Model Example
# This demonstrates the BLP model for mandatory access control
# BLP focuses on data confidentiality with "no read up, no write down" rules

# BLP Rules:
# 1. Read: subject_level >= object_level (can read at same or lower level)
# 2. Write: subject_level <= object_level (can write at same or higher level)

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer with BLP model (no policy file needed)
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/security/blp_model.conf",
    ""
  )

# Define classification levels (higher number = higher classification)
# Level 4: Top Secret
# Level 3: Secret
# Level 2: Confidential
# Level 1: Unclassified

IO.puts("\n=== Bell-LaPadula Confidentiality Model ===")
IO.puts("Classification Levels:")
IO.puts("  4 = Top Secret")
IO.puts("  3 = Secret")
IO.puts("  2 = Confidential")
IO.puts("  1 = Unclassified")

# Test read operations (can read at same or lower level)
IO.puts("\n=== Read Operations (subject_level >= object_level) ===")
IO.puts("Secret L3 can read Secret L3: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", 3, "data", 3, "read"])}")
IO.puts("Secret L3 can read Confidential L2: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", 3, "data", 2, "read"])}")
IO.puts("Secret L3 can read Unclassified L1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", 3, "data", 1, "read"])}")
IO.puts("Secret L3 can read Top Secret L4: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", 3, "data", 4, "read"])}")
IO.puts("^^ FALSE - cannot read up (no access to higher classification)")

# Test write operations (can write at same or higher level)
IO.puts("\n=== Write Operations (subject_level <= object_level) ===")
IO.puts("Confidential L2 can write Confidential L2: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", 2, "data", 2, "write"])}")
IO.puts("Confidential L2 can write Secret L3: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", 2, "data", 3, "write"])}")
IO.puts("Confidential L2 can write Top Secret L4: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", 2, "data", 4, "write"])}")
IO.puts("Confidential L2 can write Unclassified L1: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", 2, "data", 1, "write"])}")
IO.puts("^^ FALSE - cannot write down (prevents classified info leaking to lower levels)")

# Use case: Top Secret clearance (Level 4)
IO.puts("\n=== Use Case: Top Secret Clearance (Level 4) ===")
IO.puts("Top Secret L4 can read Top Secret L4: #{CasbinEx2.Enforcer.enforce(enforcer, ["admin", 4, "top_secret", 4, "read"])}")
IO.puts("Top Secret L4 can read Secret L3: #{CasbinEx2.Enforcer.enforce(enforcer, ["admin", 4, "secret", 3, "read"])}")
IO.puts("Top Secret L4 can read Confidential L2: #{CasbinEx2.Enforcer.enforce(enforcer, ["admin", 4, "confidential", 2, "read"])}")
IO.puts("Top Secret L4 can read Unclassified L1: #{CasbinEx2.Enforcer.enforce(enforcer, ["admin", 4, "public", 1, "read"])}")
IO.puts("")
IO.puts("Top Secret L4 can write Top Secret L4: #{CasbinEx2.Enforcer.enforce(enforcer, ["admin", 4, "top_secret", 4, "write"])}")
IO.puts("Top Secret L4 can write Secret L3: #{CasbinEx2.Enforcer.enforce(enforcer, ["admin", 4, "secret", 3, "write"])}")
IO.puts("^^ FALSE - cannot write down (prevents accidental declassification)")

# Use case: Confidential clearance (Level 2)
IO.puts("\n=== Use Case: Confidential Clearance (Level 2) ===")
IO.puts("Confidential L2 can read Confidential L2: #{CasbinEx2.Enforcer.enforce(enforcer, ["user", 2, "confidential", 2, "read"])}")
IO.puts("Confidential L2 can read Unclassified L1: #{CasbinEx2.Enforcer.enforce(enforcer, ["user", 2, "public", 1, "read"])}")
IO.puts("Confidential L2 can read Secret L3: #{CasbinEx2.Enforcer.enforce(enforcer, ["user", 2, "secret", 3, "read"])}")
IO.puts("^^ FALSE - cannot access Secret documents")
IO.puts("")
IO.puts("Confidential L2 can write Secret L3: #{CasbinEx2.Enforcer.enforce(enforcer, ["user", 2, "secret", 3, "write"])}")
IO.puts("Confidential L2 can write Top Secret L4: #{CasbinEx2.Enforcer.enforce(enforcer, ["user", 2, "top_secret", 4, "write"])}")
IO.puts("^^ Both TRUE - can write to higher classifications")

# Use case: Unclassified user (Level 1)
IO.puts("\n=== Use Case: Unclassified User (Level 1) ===")
IO.puts("Unclassified L1 can read Unclassified L1: #{CasbinEx2.Enforcer.enforce(enforcer, ["guest", 1, "public", 1, "read"])}")
IO.puts("Unclassified L1 can read Confidential L2: #{CasbinEx2.Enforcer.enforce(enforcer, ["guest", 1, "confidential", 2, "read"])}")
IO.puts("Unclassified L1 can read Secret L3: #{CasbinEx2.Enforcer.enforce(enforcer, ["guest", 1, "secret", 3, "read"])}")
IO.puts("^^ FALSE - no access to any classified information")
IO.puts("")
IO.puts("Unclassified L1 can write Unclassified L1: #{CasbinEx2.Enforcer.enforce(enforcer, ["guest", 1, "public", 1, "write"])}")
IO.puts("Unclassified L1 can write Confidential L2: #{CasbinEx2.Enforcer.enforce(enforcer, ["guest", 1, "confidential", 2, "write"])}")
IO.puts("Unclassified L1 can write Secret L3: #{CasbinEx2.Enforcer.enforce(enforcer, ["guest", 1, "secret", 3, "write"])}")
IO.puts("^^ All TRUE - can write to any level (but prevents reading classified data)")

# Military/Government use case
IO.puts("\n=== Military/Government Use Case ===")
IO.puts("Scenario: Intelligence analyst with Secret clearance")
analyst_level = 3
IO.puts("")
IO.puts("Can read intelligence reports:")
IO.puts("  Unclassified L1: #{CasbinEx2.Enforcer.enforce(enforcer, ["analyst", analyst_level, "report", 1, "read"])}")
IO.puts("  Confidential L2: #{CasbinEx2.Enforcer.enforce(enforcer, ["analyst", analyst_level, "report", 2, "read"])}")
IO.puts("  Secret L3: #{CasbinEx2.Enforcer.enforce(enforcer, ["analyst", analyst_level, "report", 3, "read"])}")
IO.puts("  Top Secret L4: #{CasbinEx2.Enforcer.enforce(enforcer, ["analyst", analyst_level, "report", 4, "read"])}")
IO.puts("")
IO.puts("Can write analysis to:")
IO.puts("  Secret L3: #{CasbinEx2.Enforcer.enforce(enforcer, ["analyst", analyst_level, "analysis", 3, "write"])}")
IO.puts("  Top Secret L4: #{CasbinEx2.Enforcer.enforce(enforcer, ["analyst", analyst_level, "analysis", 4, "write"])}")
IO.puts("  Confidential L2: #{CasbinEx2.Enforcer.enforce(enforcer, ["analyst", analyst_level, "analysis", 2, "write"])}")
IO.puts("^^ FALSE - cannot declassify by writing to lower level")

# Confidentiality protection summary
IO.puts("\n=== BLP Confidentiality Protection Summary ===")
IO.puts("✓ Protects data confidentiality by preventing:")
IO.puts("  1. Reading up (no access to higher classification)")
IO.puts("  2. Writing down (no declassification/information leakage)")
IO.puts("")
IO.puts("✓ Prevents:")
IO.puts("  - Unauthorized access to classified information")
IO.puts("  - Accidental or intentional information leakage")
IO.puts("  - Privilege escalation attacks")
IO.puts("")
IO.puts("✓ Enforces:")
IO.puts("  - Need-to-know principle")
IO.puts("  - Mandatory access control")
IO.puts("  - Multi-level security")

IO.puts("\n✅ Bell-LaPadula confidentiality model example completed!")
