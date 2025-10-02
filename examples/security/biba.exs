# BIBA Integrity Model Example
# This demonstrates the BIBA integrity model for mandatory access control
# BIBA focuses on data integrity with "no read down, no write up" rules

# BIBA Rules:
# 1. Read: subject_level <= object_level (can read at same or higher level)
# 2. Write: subject_level >= object_level (can write at same or lower level)

# Start the application
Application.ensure_all_started(:casbin_ex2)

# Create enforcer with BIBA model (no policy file needed)
{:ok, enforcer} =
  CasbinEx2.Enforcer.new_enforcer(
    "examples/security/biba_model.conf",
    ""
  )

# Define integrity levels (higher number = higher integrity)
# Level 4: Critical system files
# Level 3: Important application data
# Level 2: Regular user data
# Level 1: Public/untrusted data

IO.puts("\n=== BIBA Integrity Model ===")
IO.puts("Integrity Levels:")
IO.puts("  4 = Critical system files")
IO.puts("  3 = Important application data")
IO.puts("  2 = Regular user data")
IO.puts("  1 = Public/untrusted data")

# Test read operations (can read at same or higher level)
IO.puts("\n=== Read Operations (subject_level <= object_level) ===")
IO.puts("User L2 can read data L2: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", 2, "data", 2, "read"])}")
IO.puts("User L2 can read data L3: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", 2, "data", 3, "read"])}")
IO.puts("User L2 can read data L4: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", 2, "data", 4, "read"])}")
IO.puts("User L2 can read data L1: #{CasbinEx2.Enforcer.enforce(enforcer, ["alice", 2, "data", 1, "read"])}")
IO.puts("^^ FALSE - cannot read down (prevents reading untrusted data)")

# Test write operations (can write at same or lower level)
IO.puts("\n=== Write Operations (subject_level >= object_level) ===")
IO.puts("User L3 can write data L3: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", 3, "data", 3, "write"])}")
IO.puts("User L3 can write data L2: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", 3, "data", 2, "write"])}")
IO.puts("User L3 can write data L1: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", 3, "data", 1, "write"])}")
IO.puts("User L3 can write data L4: #{CasbinEx2.Enforcer.enforce(enforcer, ["bob", 3, "data", 4, "write"])}")
IO.puts("^^ FALSE - cannot write up (prevents corrupting higher integrity data)")

# Use case: System administrator (Level 4)
IO.puts("\n=== Use Case: System Administrator (Level 4) ===")
IO.puts("Sysadmin L4 can read system files L4: #{CasbinEx2.Enforcer.enforce(enforcer, ["admin", 4, "system_files", 4, "read"])}")
IO.puts("Sysadmin L4 can write system files L4: #{CasbinEx2.Enforcer.enforce(enforcer, ["admin", 4, "system_files", 4, "write"])}")
IO.puts("Sysadmin L4 can write user data L2: #{CasbinEx2.Enforcer.enforce(enforcer, ["admin", 4, "user_data", 2, "write"])}")
IO.puts("Sysadmin L4 can read untrusted L1: #{CasbinEx2.Enforcer.enforce(enforcer, ["admin", 4, "untrusted", 1, "read"])}")
IO.puts("^^ FALSE - admin cannot read untrusted data (integrity protection)")

# Use case: Regular user (Level 2)
IO.puts("\n=== Use Case: Regular User (Level 2) ===")
IO.puts("User L2 can read app data L3: #{CasbinEx2.Enforcer.enforce(enforcer, ["user", 2, "app_data", 3, "read"])}")
IO.puts("User L2 can write user data L2: #{CasbinEx2.Enforcer.enforce(enforcer, ["user", 2, "user_data", 2, "write"])}")
IO.puts("User L2 can write public L1: #{CasbinEx2.Enforcer.enforce(enforcer, ["user", 2, "public", 1, "write"])}")
IO.puts("User L2 can write app data L3: #{CasbinEx2.Enforcer.enforce(enforcer, ["user", 2, "app_data", 3, "write"])}")
IO.puts("^^ FALSE - user cannot corrupt higher integrity application data")

# Use case: Public API (Level 1 - untrusted)
IO.puts("\n=== Use Case: Public API (Level 1 - Untrusted) ===")
IO.puts("Public L1 can read anything L1-4:")
IO.puts("  Read L1: #{CasbinEx2.Enforcer.enforce(enforcer, ["public", 1, "data", 1, "read"])}")
IO.puts("  Read L2: #{CasbinEx2.Enforcer.enforce(enforcer, ["public", 1, "data", 2, "read"])}")
IO.puts("  Read L3: #{CasbinEx2.Enforcer.enforce(enforcer, ["public", 1, "data", 3, "read"])}")
IO.puts("  Read L4: #{CasbinEx2.Enforcer.enforce(enforcer, ["public", 1, "data", 4, "read"])}")
IO.puts("")
IO.puts("Public L1 can write L1: #{CasbinEx2.Enforcer.enforce(enforcer, ["public", 1, "data", 1, "write"])}")
IO.puts("Public L1 can write L2: #{CasbinEx2.Enforcer.enforce(enforcer, ["public", 1, "data", 2, "write"])}")
IO.puts("^^ FALSE - untrusted source cannot write to any trusted level")

# Integrity protection summary
IO.puts("\n=== BIBA Integrity Protection Summary ===")
IO.puts("✓ Protects data integrity by preventing:")
IO.puts("  1. Reading down (no contamination from lower integrity)")
IO.puts("  2. Writing up (no corruption of higher integrity)")
IO.puts("")
IO.puts("✓ Prevents:")
IO.puts("  - Untrusted data corrupting trusted data")
IO.puts("  - High-integrity processes reading low-integrity data")
IO.puts("  - Malware escalating integrity levels")

IO.puts("\n✅ BIBA integrity model example completed!")
