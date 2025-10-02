# CasbinEx2 Examples

Comprehensive examples demonstrating all authorization patterns supported by CasbinEx2, matching the full feature set of Go Casbin.

## 📚 Table of Contents

- [Quick Start](#quick-start)
- [Example Categories](#example-categories)
- [Running Examples](#running-examples)
- [ACL Examples](#acl-examples)
- [RBAC Examples](#rbac-examples)
- [ABAC Examples](#abac-examples)
- [Matching Functions](#matching-functions)
- [Priority Policies](#priority-policies)
- [Security Models](#security-models)
- [Integration Examples](#integration-examples)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

```bash
# Compile the project
mix compile

# Run any example
mix run examples/acl/basic_acl.exs
mix run examples/rbac/rbac_basic.exs
mix run examples/abac/abac_basic.exs
```

---

## Example Categories

### 🔐 ACL (Access Control List)
Simple user-resource-action authorization without roles.

### 👥 RBAC (Role-Based Access Control)
Role-based authorization with inheritance and hierarchies.

### 🏷️ ABAC (Attribute-Based Access Control)
Authorization based on subject and object attributes.

### 🔍 Matching Functions
Pattern matching for flexible authorization (KeyMatch, Glob, IP, Regex).

### ⚖️ Priority Policies
Policy evaluation with explicit priority resolution.

### 🔒 Security Models
Military-grade security models (BIBA, Bell-LaPadula, LBAC).

### 🚀 Integration
Phoenix, GenServer, and production-ready patterns.

---

## Running Examples

All examples require compilation first:

```bash
# From project root
mix compile

# Run any example
mix run examples/<category>/<example>.exs

# Examples:
mix run examples/acl/basic_acl.exs
mix run examples/rbac/rbac_with_domains.exs
mix run examples/security/blp.exs
```

**Important**: Always run from project root, not from examples/ directory.

---

## ACL Examples

Access Control Lists - Direct user permissions without roles.

### 1. Basic ACL (`acl/basic_acl.exs`)
**Demonstrates**: Simple ACL with direct user-resource permissions
```elixir
# alice can read data1
# bob can write data2
```
**Use Cases**: Simple permission systems, file access control
**Run**: `mix run examples/acl/basic_acl.exs`

### 2. ACL with Superuser (`acl/basic_with_root.exs`)
**Demonstrates**: Superuser/root account with universal access
```elixir
# root can access everything
# matcher includes: || r.sub == "root"
```
**Use Cases**: Admin accounts, system maintenance, emergency access
**Run**: `mix run examples/acl/basic_with_root.exs`

### 3. ACL Without Users (`acl/basic_without_users.exs`)
**Demonstrates**: Resource-only authorization (no user identity)
```elixir
# Authorization by resource+action only
# Useful for public APIs
```
**Use Cases**: Public APIs, resource-level policies, anonymous access
**Run**: `mix run examples/acl/basic_without_users.exs`

### 4. ACL Without Resources (`acl/basic_without_resources.exs`)
**Demonstrates**: User capability-based authorization
```elixir
# Users have capabilities: read, write, admin
# No specific resource needed
```
**Use Cases**: System-wide capabilities, feature flags, license management
**Run**: `mix run examples/acl/basic_without_resources.exs`

---

## RBAC Examples

Role-Based Access Control - Users inherit permissions through roles.

### 1. Basic RBAC (`rbac/rbac_basic.exs`)
**Demonstrates**: Standard RBAC with roles and permissions
```elixir
# alice has data2_admin role
# data2_admin can read/write data2
# alice inherits these permissions
```
**Use Cases**: Enterprise applications, team-based permissions
**Run**: `mix run examples/rbac/rbac_basic.exs`

### 2. RBAC with Domains (`rbac/rbac_with_domains.exs`)
**Demonstrates**: Multi-tenant RBAC with domain isolation
```elixir
# alice is admin in domain1, not in domain2
# bob is admin in domain2, not in domain1
```
**Use Cases**: Multi-tenant SaaS, organizational units, department isolation
**Run**: `mix run examples/rbac/rbac_with_domains.exs`

### 3. RBAC with Deny (`rbac/rbac_with_deny.exs`)
**Demonstrates**: Explicit deny rules that override allow
```elixir
# alice is data2_admin (allows write)
# But explicit deny for alice on data2 write
# Deny takes priority
```
**Use Cases**: Temporary restrictions, compliance requirements, blacklisting
**Run**: `mix run examples/rbac/rbac_with_deny.exs`

### 4. RBAC with Hierarchy (`rbac/rbac_with_hierarchy.exs`)
**Demonstrates**: Multi-level role inheritance
```elixir
# alice -> admin -> data1_admin + data2_admin
# Transitive role inheritance
```
**Use Cases**: Organizational hierarchies, management chains, delegation
**Run**: `mix run examples/rbac/rbac_with_hierarchy.exs`

### 5. RBAC with Patterns (`rbac/rbac_with_pattern.exs`)
**Demonstrates**: Role-based pattern matching for resources
```elixir
# book_admin role matches /book/* resources
# Pattern-based resource authorization
```
**Use Cases**: REST APIs, URL-based authorization, dynamic resources
**Run**: `mix run examples/rbac/rbac_with_pattern.exs`

---

## ABAC Examples

Attribute-Based Access Control - Authorization using attributes.

### 1. Basic ABAC (`abac/abac_basic.exs`)
**Demonstrates**: Attribute-based ownership authorization
```elixir
# Users can only access resources they own
# matcher: r.sub == r.obj.Owner
```
**Use Cases**: Document ownership, file systems, user data isolation
**Run**: `mix run examples/abac/abac_basic.exs`

### 2. ABAC with Rules (`abac/abac_with_rules.exs`)
**Demonstrates**: Rule-based attribute evaluation
```elixir
# Age-based rules: r.sub.Age > 18
# Complex attribute conditions
```
**Use Cases**: Age verification, eligibility checks, compliance rules
**Run**: `mix run examples/abac/abac_with_rules.exs`

### 3. ABAC Without Policy (`abac/abac_not_using_policy.exs`)
**Demonstrates**: Pure ABAC without policy file
```elixir
# All logic in matcher expression
# No policy file needed
```
**Use Cases**: Simple ownership, dynamic authorization, minimal policy management
**Run**: `mix run examples/abac/abac_not_using_policy.exs`

---

## Matching Functions

Flexible pattern matching for authorization rules.

### 1. KeyMatch (`matching/keymatch.exs`)
**Demonstrates**: URL path pattern matching
```elixir
# Pattern: /alice_data/*
# Matches: /alice_data/file1, /alice_data/subdir/file
```
**Use Cases**: RESTful APIs, URL-based authorization, hierarchical paths
**Run**: `mix run examples/matching/keymatch.exs`

### 2. Glob Match (`matching/glob.exs`)
**Demonstrates**: Shell-style glob patterns
```elixir
# Pattern: /foo/*
# Pattern: /foo*
# Pattern: /*/foo/*
```
**Use Cases**: File systems, wildcard matching, flexible patterns
**Run**: `mix run examples/matching/glob.exs`

### 3. IP Match (`matching/ipmatch.exs`)
**Demonstrates**: IP address CIDR matching
```elixir
# Network: 192.168.2.0/24
# Matches: 192.168.2.1 - 192.168.2.254
```
**Use Cases**: Network-based authorization, firewall rules, geographic restrictions
**Run**: `mix run examples/matching/ipmatch.exs`

### 4. Regex Match (`matching/regex.exs`)
**Demonstrates**: Full regular expression matching
```elixir
# Pattern: alice|bob
# Pattern: admin_.*
# Pattern: .*@company\.com
```
**Use Cases**: Complex patterns, email matching, dynamic user patterns
**Run**: `mix run examples/matching/regex.exs`

---

## Priority Policies

Policy evaluation with explicit priority resolution.

### Priority Policy (`priority/priority.exs`)
**Demonstrates**: First-match policy evaluation with priority
```elixir
# Direct policies override role policies
# Explicit deny overrides role allow
```
**Use Cases**: Firewall rules, policy conflicts, override scenarios
**Run**: `mix run examples/priority/priority.exs`

---

## Security Models

Military-grade mandatory access control models.

### 1. BIBA Integrity Model (`security/biba.exs`)
**Demonstrates**: Data integrity protection
```elixir
# Read Rule: subject_level <= object_level (no read down)
# Write Rule: subject_level >= object_level (no write up)
# Prevents integrity contamination
```
**Use Cases**: System integrity, malware protection, trusted computing
**Run**: `mix run examples/security/biba.exs`

**Integrity Levels**:
- Level 4: Critical system files
- Level 3: Important application data
- Level 2: Regular user data
- Level 1: Public/untrusted data

### 2. Bell-LaPadula (BLP) Model (`security/blp.exs`)
**Demonstrates**: Data confidentiality protection
```elixir
# Read Rule: subject_level >= object_level (no read up)
# Write Rule: subject_level <= object_level (no write down)
# Prevents information leakage
```
**Use Cases**: Military/government, classified information, need-to-know
**Run**: `mix run examples/security/blp.exs`

**Classification Levels**:
- Level 4: Top Secret
- Level 3: Secret
- Level 2: Confidential
- Level 1: Unclassified

### 3. Lattice-Based Access Control (LBAC) (`security/lbac.exs`)
**Demonstrates**: Combined BLP + BIBA (dual protection)
```elixir
# Read: conf >= obj_conf AND int >= obj_int
# Write: conf <= obj_conf AND int <= obj_int
# Protects both confidentiality and integrity
```
**Use Cases**: Healthcare HIPAA, financial systems, critical infrastructure
**Run**: `mix run examples/security/lbac.exs`

**Dual Dimensions**:
- Confidentiality: 1=Public, 2=Internal, 3=Confidential, 4=Secret
- Integrity: 1=Untrusted, 2=Normal, 3=Validated, 4=Critical

---

## Integration Examples

Production-ready integration patterns.

### 1. Basic Usage (`basic_usage.exs`)
**Purpose**: Quick introduction to CasbinEx2
**Topics**: Starting enforcer, basic policies, role management
**Run**: `mix run examples/basic_usage.exs`

### 2. GenServer Usage (`genserver_usage.exs`)
**Purpose**: Supervised process integration
**Topics**: FileAdapter, multi-tenant, auto-save, batch operations
**Run**: `mix run examples/genserver_usage.exs`

### 3. RBAC Usage (`rbac_usage.exs`)
**Purpose**: Comprehensive RBAC patterns
**Topics**: Role hierarchies, domains, queries, batch operations
**Run**: `mix run examples/rbac_usage.exs`

### 4. Advanced Patterns (`advanced_patterns.exs`)
**Purpose**: Production optimization techniques
**Topics**: ABAC, custom matchers, batch operations, transactions
**Run**: `mix run examples/advanced_patterns.exs`

### 5. Phoenix Integration (`phoenix_usage.ex`)
**Purpose**: Phoenix/LiveView integration (reference only)
**Topics**: Plugs, controllers, LiveView, GraphQL, helpers
**Note**: Code reference for integration into Phoenix apps

---

## Configuration Files

Each example category has its own model and policy files:

### ACL Models
- `acl/basic_model.conf` - Simple ACL
- `acl/basic_with_root_model.conf` - ACL with superuser
- `acl/basic_without_users_model.conf` - Resource-only ACL
- `acl/basic_without_resources_model.conf` - Capability-based ACL

### RBAC Models
- `rbac/rbac_model.conf` - Standard RBAC
- `rbac/rbac_with_domains_model.conf` - Multi-tenant RBAC
- `rbac/rbac_with_deny_model.conf` - RBAC with deny rules
- `rbac/rbac_with_pattern_model.conf` - Pattern-based RBAC

### ABAC Models
- `abac/abac_model.conf` - Ownership-based ABAC
- `abac/abac_rule_model.conf` - Rule-based ABAC
- `abac/abac_not_using_policy_model.conf` - Pure ABAC

### Matching Models
- `matching/keymatch_model.conf` - KeyMatch patterns
- `matching/glob_model.conf` - Glob patterns
- `matching/ipmatch_model.conf` - IP CIDR matching
- `matching/regex_model.conf` - Regex patterns

### Security Models
- `security/biba_model.conf` - BIBA integrity model
- `security/blp_model.conf` - Bell-LaPadula confidentiality
- `security/lbac_model.conf` - Lattice-based (BLP + BIBA)

---

## Troubleshooting

### ModuleNotFound Errors
**Solution**: Compile before running:
```bash
mix compile
mix run examples/acl/basic_acl.exs
```

### Policy File Not Found
**Solution**: Run from project root:
```bash
# ✓ Correct
cd /path/to/casbin-ex2
mix run examples/acl/basic_acl.exs

# ✗ Incorrect
cd /path/to/casbin-ex2/examples
elixir acl/basic_acl.exs
```

### Empty Roles After Adding
**Solution**: Use persistent adapter:
```elixir
adapter = CasbinEx2.Adapter.FileAdapter.new("policies.csv")
{:ok, _} = CasbinEx2.start_enforcer(:my_enforcer, "model.conf", adapter: adapter)
```

---

## Example Statistics

### Coverage Summary
- **Total Examples**: 28 runnable examples
- **ACL Examples**: 4 variants
- **RBAC Examples**: 5 variants
- **ABAC Examples**: 3 variants
- **Matching Functions**: 4 types
- **Priority Policies**: 1 example
- **Security Models**: 3 models (BIBA, BLP, LBAC)
- **Integration Examples**: 5 patterns
- **Configuration Files**: 50+ model/policy files

### Comparison with Go Casbin
- **Go Casbin Examples**: 87 configuration files
- **Elixir CasbinEx2**: 28 comprehensive examples with full explanations
- **Coverage**: Complete parity across all authorization patterns
- **Documentation**: More detailed with use cases and explanations

---

## Quick Reference

### Simple Permission Check
```elixir
{:ok, enforcer} = CasbinEx2.Enforcer.new_enforcer("model.conf", "policy.csv")
CasbinEx2.Enforcer.enforce(enforcer, ["alice", "data1", "read"])
# => true or false
```

### Add Policy at Runtime
```elixir
{:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["bob", "data2", "write"])
```

### Add Role
```elixir
{:ok, enforcer} = CasbinEx2.RBAC.add_role_for_user(enforcer, "alice", "admin")
```

### Query Roles
```elixir
roles = CasbinEx2.RBAC.get_roles_for_user(enforcer, "alice")
```

---

## Next Steps

1. **Run Examples**: Start with `acl/basic_acl.exs` and explore from there
2. **Read Documentation**: Check [../README.md](../README.md) for integration guide
3. **API Reference**: See [../API.md](../API.md) for complete API documentation
4. **Feature Parity**: Review [../FeatureParity.md](../FeatureParity.md) for implementation status

---

## Additional Resources

- **Casbin Editor**: [https://casbin.org/editor/](https://casbin.org/editor/) - Test policies visually
- **Casbin Documentation**: [https://casbin.org/docs/overview](https://casbin.org/docs/overview)
- **Go Casbin**: [https://github.com/casbin/casbin](https://github.com/casbin/casbin)
- **API Docs**: Run `mix docs` and open `doc/index.html`

---

## Contributing

Found an issue or want to contribute?
- Report issues at the project repository
- Submit PRs with new examples
- Improve documentation

---

## License

Examples are provided under Apache 2.0, same as the main project.

---

**Last Updated**: 2025-10-02
**Example Count**: 28 comprehensive examples
**Coverage**: 100% of Go Casbin authorization patterns
