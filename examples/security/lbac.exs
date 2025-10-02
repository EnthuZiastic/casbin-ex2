# Lattice-Based Access Control (LBAC) Example
# This demonstrates LBAC combining BLP (confidentiality) and BIBA (integrity)
# LBAC enforces both confidentiality and integrity constraints simultaneously

# LBAC Rules:
# Read:  subject_conf >= object_conf AND subject_int >= object_int
# Write: subject_conf <= object_conf AND subject_int <= object_int

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer with LBAC model (no policy file needed)
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/security/lbac_model.conf",
    ""
  )

# Define levels (higher number = higher level)
# Confidentiality: 1=Public, 2=Internal, 3=Confidential, 4=Secret
# Integrity: 1=Untrusted, 2=Normal, 3=Validated, 4=Critical

IO.puts("\n=== Lattice-Based Access Control (LBAC) ===")
IO.puts("Combines BLP (confidentiality) + BIBA (integrity)")
IO.puts("")
IO.puts("Confidentiality Levels: 1=Public, 2=Internal, 3=Confidential, 4=Secret")
IO.puts("Integrity Levels: 1=Untrusted, 2=Normal, 3=Validated, 4=Critical")

# Test read operations (need sufficient clearance AND integrity)
IO.puts("\n=== Read Operations (conf >= obj_conf AND int >= obj_int) ===")
IO.puts("User (C:3,I:3) can read Data (C:2,I:2): #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", 3, 3, "data", 2, 2, "read"])}")
IO.puts("User (C:3,I:3) can read Data (C:3,I:3): #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", 3, 3, "data", 3, 3, "read"])}")
IO.puts("User (C:3,I:3) can read Data (C:4,I:2): #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", 3, 3, "data", 4, 2, "read"])}")
IO.puts("^^ FALSE - insufficient confidentiality clearance")
IO.puts("User (C:3,I:3) can read Data (C:2,I:4): #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", 3, 3, "data", 2, 4, "read"])}")
IO.puts("^^ FALSE - insufficient integrity level")

# Test write operations (cannot write up in either dimension)
IO.puts("\n=== Write Operations (conf <= obj_conf AND int <= obj_int) ===")
IO.puts("User (C:2,I:2) can write Data (C:2,I:2): #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", 2, 2, "data", 2, 2, "write"])}")
IO.puts("User (C:2,I:2) can write Data (C:3,I:3): #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", 2, 2, "data", 3, 3, "write"])}")
IO.puts("User (C:2,I:2) can write Data (C:3,I:2): #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", 2, 2, "data", 3, 2, "write"])}")
IO.puts("User (C:2,I:2) can write Data (C:2,I:3): #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", 2, 2, "data", 2, 3, "write"])}")
IO.puts("User (C:2,I:2) can write Data (C:1,I:1): #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", 2, 2, "data", 1, 1, "write"])}")
IO.puts("^^ FALSE - would downgrade confidentiality/integrity")

# Use case: High clearance, low integrity (e.g., compromised user)
IO.puts("\n=== Use Case: Compromised High-Clearance User (C:4,I:1) ===")
IO.puts("Compromised user has high clearance but low integrity")
IO.puts("Read Secret Data (C:4,I:3): #{CasbinEx2.Enforcer.enforce(enforcer, ["compromised", 4, 1, "secret", 4, 3, "read"])}")
IO.puts("^^ FALSE - low integrity prevents reading validated data")
IO.puts("Write Untrusted Data (C:4,I:1): #{CasbinEx2.Enforcer.enforce(enforcer, ["compromised", 4, 1, "untrusted", 4, 1, "write"])}")
IO.puts("Write Validated Data (C:4,I:3): #{CasbinEx2.Enforcer.enforce(enforcer, ["compromised", 4, 1, "validated", 4, 3, "write"])}")
IO.puts("^^ FALSE - low integrity cannot corrupt high-integrity data")

# Use case: Normal user with validated integrity
IO.puts("\n=== Use Case: Normal User (C:2,I:3) ===")
IO.puts("Normal clearance but validated integrity")
IO.puts("Read Public Validated (C:1,I:2): #{CasbinEx2.Enforcer.enforce(enforcer, ["user", 2, 3, "public", 1, 2, "read"])}")
IO.puts("Read Internal Validated (C:2,I:3): #{CasbinEx2.Enforcer.enforce(enforcer, ["user", 2, 3, "internal", 2, 3, "read"])}")
IO.puts("Read Confidential Data (C:3,I:2): #{CasbinEx2.Enforcer.enforce(enforcer, ["user", 2, 3, "confidential", 3, 2, "read"])}")
IO.puts("^^ FALSE - insufficient confidentiality clearance")
IO.puts("")
IO.puts("Write Internal Validated (C:2,I:3): #{CasbinEx2.Enforcer.enforce(enforcer, ["user", 2, 3, "internal", 2, 3, "write"])}")
IO.puts("Write Confidential Critical (C:3,I:4): #{CasbinEx2.Enforcer.enforce(enforcer, ["user", 2, 3, "confidential", 3, 4, "write"])}")

# Use case: System process (C:4,I:4)
IO.puts("\n=== Use Case: System Process (C:4,I:4) ===")
IO.puts("Maximum confidentiality and integrity")
IO.puts("Read Secret Critical (C:4,I:4): #{CasbinEx2.Enforcer.enforce(enforcer, ["system", 4, 4, "critical", 4, 4, "read"])}")
IO.puts("Read Public Validated (C:1,I:3): #{CasbinEx2.Enforcer.enforce(enforcer, ["system", 4, 4, "public", 1, 3, "read"])}")
IO.puts("Read Confidential Normal (C:3,I:2): #{CasbinEx2.Enforcer.enforce(enforcer, ["system", 4, 4, "data", 3, 2, "read"])}")
IO.puts("Read any data with sufficient levels: TRUE")
IO.puts("")
IO.puts("Write Secret Critical (C:4,I:4): #{CasbinEx2.Enforcer.enforce(enforcer, ["system", 4, 4, "critical", 4, 4, "write"])}")
IO.puts("Write Public Normal (C:1,I:2): #{CasbinEx2.Enforcer.enforce(enforcer, ["system", 4, 4, "public", 1, 2, "write"])}")
IO.puts("^^ FALSE - cannot downgrade confidentiality or integrity")

# Practical scenarios
IO.puts("\n=== Practical Security Scenarios ===")
IO.puts("")
IO.puts("1. External API (C:1,I:1) - Untrusted Public:")
IO.puts("   Can read: Public Untrusted data only")
IO.puts("   Can write: Can upgrade to any level")
IO.puts("")
IO.puts("2. Internal Service (C:2,I:3) - Internal Validated:")
IO.puts("   Can read: Public/Internal with Normal/Validated integrity")
IO.puts("   Can write: Internal+ with Validated+ integrity")
IO.puts("")
IO.puts("3. Security Service (C:4,I:4) - Secret Critical:")
IO.puts("   Can read: All data at all levels")
IO.puts("   Can write: Only to Secret/Critical (prevents leaks)")
IO.puts("")
IO.puts("4. Compromised Account (C:3,I:1) - Confidential Untrusted:")
IO.puts("   Can read: Limited by low integrity")
IO.puts("   Can write: Limited by low integrity")
IO.puts("   Result: Minimal damage possible")

# LBAC protection summary
IO.puts("\n=== LBAC Protection Summary ===")
IO.puts("✓ Combines BLP (confidentiality) and BIBA (integrity):")
IO.puts("  - BLP prevents reading up, writing down (confidentiality)")
IO.puts("  - BIBA prevents reading down, writing up (integrity)")
IO.puts("")
IO.puts("✓ Dual Protection:")
IO.puts("  - Protects against information leakage (BLP)")
IO.puts("  - Protects against data corruption (BIBA)")
IO.puts("")
IO.puts("✓ Use Cases:")
IO.puts("  - Military/government multi-level security")
IO.puts("  - Healthcare HIPAA compliance")
IO.puts("  - Financial systems with audit trails")
IO.puts("  - Critical infrastructure protection")
IO.puts("")
IO.puts("✓ Key Benefit:")
IO.puts("  Compromised users with high clearance but low integrity")
IO.puts("  cannot read validated data or corrupt high-integrity systems")

IO.puts("\n✅ LBAC model example completed!")
