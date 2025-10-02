#!/usr/bin/env elixir

# RBAC (Role-Based Access Control) usage example for CasbinEx2
# This demonstrates comprehensive RBAC features including hierarchical roles and domains

# Start the application
Application.ensure_all_started(:casbin_ex2)

model_path = Path.join(__DIR__, "rbac_model.conf")

IO.puts("=== CasbinEx2 RBAC Usage Example ===\n")

# Start enforcer
{:ok, _pid} = CasbinEx2.start_enforcer(:rbac_enforcer, model_path)
IO.puts("✓ Started RBAC enforcer\n")

# === Basic RBAC: Users and Roles ===
IO.puts("=== Basic RBAC: Users and Roles ===")

# Assign roles to users
CasbinEx2.add_role_for_user(:rbac_enforcer, "alice", "admin")
CasbinEx2.add_role_for_user(:rbac_enforcer, "bob", "editor")
CasbinEx2.add_role_for_user(:rbac_enforcer, "charlie", "viewer")
IO.puts("✓ Assigned roles: alice=admin, bob=editor, charlie=viewer")

# Define role permissions
CasbinEx2.add_policy(:rbac_enforcer, ["admin", "data", "read"])
CasbinEx2.add_policy(:rbac_enforcer, ["admin", "data", "write"])
CasbinEx2.add_policy(:rbac_enforcer, ["admin", "data", "delete"])

CasbinEx2.add_policy(:rbac_enforcer, ["editor", "data", "read"])
CasbinEx2.add_policy(:rbac_enforcer, ["editor", "data", "write"])

CasbinEx2.add_policy(:rbac_enforcer, ["viewer", "data", "read"])
IO.puts("✓ Defined role permissions")

# Test enforcement
IO.puts("\n--- Enforcement Tests ---")
IO.puts("Alice (admin) can delete: #{CasbinEx2.enforce(:rbac_enforcer, ["alice", "data", "delete"])}")
IO.puts("Bob (editor) can write: #{CasbinEx2.enforce(:rbac_enforcer, ["bob", "data", "write"])}")
IO.puts("Bob (editor) can delete: #{CasbinEx2.enforce(:rbac_enforcer, ["bob", "data", "delete"])}")
IO.puts("Charlie (viewer) can read: #{CasbinEx2.enforce(:rbac_enforcer, ["charlie", "data", "read"])}")
IO.puts("Charlie (viewer) can write: #{CasbinEx2.enforce(:rbac_enforcer, ["charlie", "data", "write"])}")

# === Hierarchical Roles ===
IO.puts("\n=== Hierarchical Roles (Role Inheritance) ===")

# Create role hierarchy: super_admin inherits from admin
CasbinEx2.add_role_for_user(:rbac_enforcer, "super_admin", "admin")
CasbinEx2.add_role_for_user(:rbac_enforcer, "david", "super_admin")
IO.puts("✓ Created hierarchy: david -> super_admin -> admin")

# super_admin gets additional permissions
CasbinEx2.add_policy(:rbac_enforcer, ["super_admin", "settings", "write"])
IO.puts("✓ Added super_admin specific permission")

# Test inheritance
IO.puts("\n--- Inheritance Tests ---")
IO.puts("David (super_admin) inherits admin permissions:")
IO.puts("  Can delete data: #{CasbinEx2.enforce(:rbac_enforcer, ["david", "data", "delete"])}")
IO.puts("  Can write settings: #{CasbinEx2.enforce(:rbac_enforcer, ["david", "settings", "write"])}")

IO.puts("Alice (admin) does NOT have super_admin permissions:")
IO.puts("  Can write settings: #{CasbinEx2.enforce(:rbac_enforcer, ["alice", "settings", "write"])}")

# === Multi-Role Users ===
IO.puts("\n=== Multi-Role Users ===")

# User can have multiple roles
CasbinEx2.add_role_for_user(:rbac_enforcer, "eve", "editor")
CasbinEx2.add_role_for_user(:rbac_enforcer, "eve", "reviewer")
IO.puts("✓ Eve has multiple roles: editor and reviewer")

# Add reviewer permissions
CasbinEx2.add_policy(:rbac_enforcer, ["reviewer", "reports", "read"])
CasbinEx2.add_policy(:rbac_enforcer, ["reviewer", "reports", "approve"])

IO.puts("\n--- Multi-Role Tests ---")
IO.puts("Eve's roles: #{inspect(CasbinEx2.get_roles_for_user(:rbac_enforcer, "eve"))}")
IO.puts("Eve (editor) can write data: #{CasbinEx2.enforce(:rbac_enforcer, ["eve", "data", "write"])}")
IO.puts("Eve (reviewer) can approve reports: #{CasbinEx2.enforce(:rbac_enforcer, ["eve", "reports", "approve"])}")

# === Domain-Based RBAC (Multi-Tenant) ===
IO.puts("\n=== Domain-Based RBAC (Multi-Tenant) ===")

# Same user, different roles in different domains
CasbinEx2.add_role_for_user(:rbac_enforcer, "frank", "admin", "domain1")
CasbinEx2.add_role_for_user(:rbac_enforcer, "frank", "viewer", "domain2")
IO.puts("✓ Frank is admin in domain1, viewer in domain2")

# Domain-specific policies
CasbinEx2.add_policy(:rbac_enforcer, ["admin", "domain1", "data", "write"])
CasbinEx2.add_policy(:rbac_enforcer, ["viewer", "domain2", "data", "read"])

IO.puts("\n--- Domain Tests ---")
IO.puts("Frank's roles in domain1: #{inspect(CasbinEx2.get_roles_for_user_in_domain(:rbac_enforcer, "frank", "domain1"))}")
IO.puts("Frank's roles in domain2: #{inspect(CasbinEx2.get_roles_for_user_in_domain(:rbac_enforcer, "frank", "domain2"))}")

# === RBAC Query Operations ===
IO.puts("\n=== RBAC Query Operations ===")

# Get all users with a specific role
editors = CasbinEx2.get_users_for_role(:rbac_enforcer, "editor")
IO.puts("Users with 'editor' role: #{inspect(editors)}")

# Check if user has specific role
has_role = CasbinEx2.has_role_for_user(:rbac_enforcer, "alice", "admin")
IO.puts("Alice has 'admin' role: #{has_role}")

# Get all permissions for a user (including through roles)
permissions = CasbinEx2.get_implicit_permissions_for_user(:rbac_enforcer, "alice")
IO.puts("Alice's implicit permissions (#{length(permissions)}): #{inspect(permissions, limit: 3)}")

# Get all roles in the system
all_roles = CasbinEx2.get_all_roles(:rbac_enforcer)
IO.puts("All roles in system: #{inspect(all_roles)}")

# === Dynamic Role Management ===
IO.puts("\n=== Dynamic Role Management ===")

# Add temporary role
CasbinEx2.add_role_for_user(:rbac_enforcer, "grace", "temp_admin")
IO.puts("✓ Added grace as temp_admin")

grace_roles = CasbinEx2.get_roles_for_user(:rbac_enforcer, "grace")
IO.puts("Grace's roles: #{inspect(grace_roles)}")

# Remove role
CasbinEx2.delete_role_for_user(:rbac_enforcer, "grace", "temp_admin")
IO.puts("✓ Removed temp_admin role from grace")

grace_roles_after = CasbinEx2.get_roles_for_user(:rbac_enforcer, "grace")
IO.puts("Grace's roles after removal: #{inspect(grace_roles_after)}")

# Delete all roles for a user
CasbinEx2.delete_roles_for_user(:rbac_enforcer, "eve")
IO.puts("✓ Removed all roles for eve")

eve_roles = CasbinEx2.get_roles_for_user(:rbac_enforcer, "eve")
IO.puts("Eve's roles: #{inspect(eve_roles)} (should be empty)")

# === Batch Operations for Efficiency ===
IO.puts("\n=== Batch Role Operations ===")

# Add multiple roles at once
role_assignments = [
  ["harry", "developer"],
  ["harry", "tester"],
  ["harry", "documenter"]
]

Enum.each(role_assignments, fn [user, role] ->
  CasbinEx2.add_role_for_user(:rbac_enforcer, user, role)
end)

IO.puts("✓ Added multiple roles for harry in batch")

harry_roles = CasbinEx2.get_roles_for_user(:rbac_enforcer, "harry")
IO.puts("Harry's roles: #{inspect(harry_roles)}")

# === Summary ===
IO.puts("\n=== Summary ===")
all_policies = CasbinEx2.get_policy(:rbac_enforcer)
IO.puts("Total policies defined: #{length(all_policies)}")

all_users = all_policies |> Enum.map(&List.first/1) |> Enum.uniq()
IO.puts("Unique users/roles: #{length(all_users)}")

# Cleanup
IO.puts("\n=== Cleanup ===")
CasbinEx2.stop_enforcer(:rbac_enforcer)
IO.puts("✓ Enforcer stopped")

IO.puts("\n=== Demo completed successfully! ===")

IO.puts("""

Key RBAC Features Demonstrated:
✓ Basic role assignment and permission checking
✓ Hierarchical roles (role inheritance)
✓ Multi-role users (one user, multiple roles)
✓ Domain-based RBAC (multi-tenant support)
✓ Comprehensive query operations
✓ Dynamic role management (add/remove at runtime)
✓ Batch operations for efficiency
✓ Implicit permissions through role hierarchy
""")
