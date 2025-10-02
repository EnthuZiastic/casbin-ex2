# CasbinEx2 Examples

This directory contains comprehensive examples demonstrating various usage patterns of CasbinEx2.

## Running Examples

All examples require the application to be compiled first:

```bash
# From project root
mix compile

# Run any example
mix run examples/basic_usage.exs
mix run examples/genserver_usage.exs
mix run examples/rbac_usage.exs
mix run examples/advanced_patterns.exs
```

## Example Files

### 1. basic_usage.exs
**Purpose**: Introduction to CasbinEx2 with basic ACL and RBAC
**Topics Covered**:
- Starting an enforcer with file-based policies
- Pre-loaded policy testing from CSV files
- Adding policies dynamically at runtime
- Working with roles
- Policy queries and verification
- Negative authorization tests

**Run**: `mix run examples/basic_usage.exs`

### 2. genserver_usage.exs
**Purpose**: Using CasbinEx2 with supervised GenServer processes
**Topics Covered**:
- Starting enforcer with FileAdapter
- Multi-tenant scenario (multiple enforcers)
- Custom options (caching, auto-save)
- Manual save control for batch operations
- Process information and graceful shutdown

**Run**: `mix run examples/genserver_usage.exs`

**Note**: Demonstrates process-based authorization for concurrent applications

### 3. rbac_usage.exs
**Purpose**: Comprehensive RBAC (Role-Based Access Control) patterns
**Topics Covered**:
- Basic role assignment and permissions
- Hierarchical roles (role inheritance)
- Multi-role users
- Domain-based RBAC (multi-tenant)
- RBAC query operations
- Dynamic role management
- Batch role operations

**Run**: `mix run examples/rbac_usage.exs`

**Note**: Shows complete RBAC features including 86 available RBAC functions

### 4. advanced_patterns.exs
**Purpose**: Advanced authorization patterns and optimization techniques
**Topics Covered**:
- ABAC (Attribute-Based Access Control)
- Custom matchers with KeyMatch for RESTful URLs
- Batch operations for performance
- Priority-based policies (firewall-like)
- Policy filtering and queries
- Conditional enforcement with context
- Transaction support

**Run**: `mix run examples/advanced_patterns.exs`

**Note**: Demonstrates production-ready patterns for high-performance scenarios

### 5. phoenix_usage.ex
**Purpose**: Phoenix/LiveView integration patterns (code reference only)
**Topics Covered**:
- Phoenix plugs for authorization
- Controller-level authorization
- LiveView authorization
- Helper modules
- View helpers for templates
- Multi-tenant authorization
- API authorization for JSON endpoints
- Absinthe GraphQL middleware

**Note**: This is a reference module showing integration patterns. Use code snippets in your Phoenix app.

## Configuration Files

### rbac_model.conf
Standard RBAC model definition with:
- Request definition (subject, object, action)
- Policy definition
- Role definition (groupings)
- Policy effect (some allow)
- Matchers (role-based matching)

### rbac_policy.csv
Sample policies demonstrating:
- Direct user permissions (p, alice, data1, read)
- Role-based permissions (p, admin, data, write)
- Role assignments (g, alice, admin)
- Multi-level hierarchies

## Quick Start

1. **Basic enforcement**:
```elixir
# Start enforcer
{:ok, _} = CasbinEx2.start_enforcer(:my_enforcer, "examples/rbac_model.conf")

# Check permission
CasbinEx2.enforce(:my_enforcer, ["alice", "data1", "read"])
# => true or false
```

2. **With file adapter**:
```elixir
adapter = CasbinEx2.Adapter.FileAdapter.new("examples/rbac_policy.csv")
{:ok, _} = CasbinEx2.start_enforcer(:my_enforcer, "examples/rbac_model.conf", adapter: adapter)
```

3. **Add policies at runtime**:
```elixir
CasbinEx2.add_policy(:my_enforcer, ["bob", "data2", "write"])
CasbinEx2.add_role_for_user(:my_enforcer, "bob", "editor")
```

## Common Issues

### ModuleNotFound Errors
**Solution**: Always compile before running examples:
```bash
mix compile
mix run examples/basic_usage.exs
```

### Policy File Not Found
**Solution**: Run examples from project root, not from examples/ directory:
```bash
# Correct
cd /path/to/casbin-ex2
mix run examples/basic_usage.exs

# Incorrect
cd /path/to/casbin-ex2/examples
elixir basic_usage.exs
```

### Empty Roles After Adding
**Issue**: Roles might not persist between enforcer restarts without proper adapter
**Solution**: Use FileAdapter or EctoAdapter for persistence:
```elixir
adapter = CasbinEx2.Adapter.FileAdapter.new("policies.csv")
{:ok, _} = CasbinEx2.start_enforcer(:my_enforcer, "model.conf", adapter: adapter)
```

## Model Files Reference

All examples use `rbac_model.conf` which defines:

```conf
[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

[role_definition]
g = _, _

[policy_effect]
e = some(where (p.eft == allow))

[matchers]
m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act
```

This enables:
- Subject (user) authorization
- Object (resource) protection
- Action (operation) control
- Role-based inheritance

## Next Steps

1. **Explore Examples**: Run each example to see features in action
2. **Read API Documentation**: Check [../API.md](../API.md) for complete API reference
3. **Review Feature Parity**: See [../FeatureParity.md](../FeatureParity.md) for implementation status
4. **Integration Guide**: Follow [../README.md](../README.md) for integration into your app

## Additional Resources

- **Online Editor**: [https://casbin.org/editor/](https://casbin.org/editor/) - Test policies visually
- **Casbin Documentation**: [https://casbin.org/docs/overview](https://casbin.org/docs/overview)
- **Go Casbin Reference**: [https://github.com/casbin/casbin](https://github.com/casbin/casbin)
- **Elixir API Docs**: Run `mix docs` and open `doc/index.html`

## Contributing

Found an issue with examples? Have a new pattern to share?
- Open an issue at the project repository
- Submit a PR with new examples
- Add documentation improvements

## License

Examples are provided under the same license as the main project (Apache 2.0).
