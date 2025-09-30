# CasbinEx2

[![Hex.pm](https://img.shields.io/hexpm/v/casbin_ex2.svg)](https://hex.pm/packages/casbin_ex2)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/casbin_ex2/)

CasbinEx2 is a powerful authorization library for Elixir, providing a comprehensive implementation of the [Casbin](https://casbin.org/) authorization framework. It supports multiple access control models including ACL, RBAC, and ABAC.

## Features

- **Multiple Access Control Models**: ACL, RBAC, ABAC support
- **Process-Based Architecture**: GenServer-based enforcement with OTP supervision
- **Database Persistence**: Ecto SQL adapter for database-backed policy storage
- **High Performance**: Cached enforcer for improved performance
- **Thread Safety**: Synchronized enforcer for concurrent access
- **Distributed Enforcement**: Multi-node policy synchronization with watchers
- **Dynamic Management**: Runtime policy and role management
- **Flexible Adapters**: File and database adapters included
- **Batch Operations**: Batch enforcement and policy management
- **Comprehensive API**: Full RBAC API with domain support
- **Policy Explanations**: Enforcement with detailed explanations
- **Custom Matchers**: Support for custom authorization logic

## Installation

Add `casbin_ex2` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:casbin_ex2, "~> 0.1.0"},
    {:ecto_sql, "~> 3.10"},      # Required for Ecto adapter
    {:postgrex, "~> 0.17"}       # Required for PostgreSQL
  ]
end
```

## Quick Start

### 1. Define a Model

Create a model configuration file (e.g., `rbac_model.conf`):

```ini
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

### 2. Start an Enforcer

```elixir
# Start an enforcer with file adapter
{:ok, _pid} = CasbinEx2.start_enforcer(:my_enforcer, "path/to/rbac_model.conf")

# Or with Ecto adapter
adapter = CasbinEx2.Adapter.EctoAdapter.new(MyApp.Repo)
{:ok, _pid} = CasbinEx2.start_enforcer(:my_enforcer, "path/to/rbac_model.conf", adapter: adapter)
```

### 3. Add Policies and Roles

```elixir
# Add policy: alice can read data1
CasbinEx2.add_policy(:my_enforcer, ["alice", "data1", "read"])

# Add role: alice has admin role
CasbinEx2.add_role_for_user(:my_enforcer, "alice", "admin")

# Add policy: admin can write data1
CasbinEx2.add_policy(:my_enforcer, ["admin", "data1", "write"])
```

### 4. Check Permissions

```elixir
# Check if alice can read data1
CasbinEx2.enforce(:my_enforcer, ["alice", "data1", "read"])  # true

# Check if alice can write data1 (through admin role)
CasbinEx2.enforce(:my_enforcer, ["alice", "data1", "write"]) # true

# Check if bob can read data1
CasbinEx2.enforce(:my_enforcer, ["bob", "data1", "read"])    # false
```

## Advanced Usage

### Cached Enforcer

For better performance with frequent authorization checks:

```elixir
# Start cached enforcer
{:ok, _pid} = CasbinEx2.CachedEnforcer.start_link(
  :cached_enforcer,
  "path/to/model.conf",
  cache_size: 1000
)

# Use same API
CasbinEx2.CachedEnforcer.enforce(:cached_enforcer, ["alice", "data1", "read"])
```

### Synchronized Enforcer

For thread-safe operations in concurrent environments:

```elixir
# Start synced enforcer
{:ok, _pid} = CasbinEx2.SyncedEnforcer.start_link(
  :synced_enforcer,
  "path/to/model.conf"
)

# Use same API with automatic synchronization
CasbinEx2.SyncedEnforcer.enforce(:synced_enforcer, ["alice", "data1", "read"])
```

### Distributed Enforcer

For multi-node deployments with automatic policy synchronization:

```elixir
# Start distributed enforcer
{:ok, _pid} = CasbinEx2.DistributedEnforcer.start_link(
  :distributed_enforcer,
  "path/to/model.conf",
  nodes: [node()],
  sync_interval: 5000
)

# Policies are automatically synchronized across nodes
CasbinEx2.DistributedEnforcer.add_policy(:distributed_enforcer, ["alice", "data1", "read"])
```

### Database Integration

#### 1. Create Migration

```elixir
defmodule MyApp.Repo.Migrations.CreateCasbinRules do
  use Ecto.Migration

  def change do
    create table(:casbin_rules, primary_key: false) do
      add(:id, :serial, primary_key: true)
      add(:ptype, :string, size: 100, null: false)
      add(:v0, :string, size: 100)
      add(:v1, :string, size: 100)
      add(:v2, :string, size: 100)
      add(:v3, :string, size: 100)
      add(:v4, :string, size: 100)
      add(:v5, :string, size: 100)

      timestamps()
    end

    create(index(:casbin_rules, [:ptype]))
    create(index(:casbin_rules, [:ptype, :v0]))
    create(index(:casbin_rules, [:ptype, :v0, :v1]))
  end
end
```

#### 2. Use Ecto Adapter

```elixir
adapter = CasbinEx2.Adapter.EctoAdapter.new(MyApp.Repo)

{:ok, _pid} = CasbinEx2.start_enforcer(
  :db_enforcer,
  "path/to/model.conf",
  adapter: adapter
)

# Policies are automatically persisted to database
CasbinEx2.add_policy(:db_enforcer, ["alice", "data1", "read"])
```

## API Reference

### Policy Management

```elixir
# Add/remove policies
CasbinEx2.add_policy(enforcer, ["user", "resource", "action"])
CasbinEx2.remove_policy(enforcer, ["user", "resource", "action"])

# Update policies
CasbinEx2.update_policy(enforcer, ["alice", "data1", "read"], ["alice", "data1", "write"])
CasbinEx2.update_policies(enforcer, old_policies, new_policies)

# Batch operations
CasbinEx2.add_policies(enforcer, [
  ["alice", "data1", "read"],
  ["bob", "data2", "write"]
])

# Query policies
CasbinEx2.get_policy(enforcer)
CasbinEx2.has_policy(enforcer, ["alice", "data1", "read"])

# Get all entities
CasbinEx2.get_all_subjects(enforcer)
CasbinEx2.get_all_objects(enforcer)
CasbinEx2.get_all_actions(enforcer)
CasbinEx2.get_all_roles(enforcer)
CasbinEx2.get_all_domains(enforcer)
```

### Role Management

```elixir
# Add/remove roles
CasbinEx2.add_role_for_user(enforcer, "alice", "admin")
CasbinEx2.delete_role_for_user(enforcer, "alice", "admin")

# Domain-specific roles
CasbinEx2.add_role_for_user_in_domain(enforcer, "alice", "admin", "domain1")
CasbinEx2.delete_role_for_user_in_domain(enforcer, "alice", "admin", "domain1")

# Batch role operations
CasbinEx2.add_roles_for_user(enforcer, "alice", ["admin", "moderator"])

# Query roles
CasbinEx2.get_roles_for_user(enforcer, "alice")
CasbinEx2.get_users_for_role(enforcer, "admin")
CasbinEx2.has_role_for_user(enforcer, "alice", "admin")

# Implicit roles (includes inherited roles)
CasbinEx2.get_implicit_roles_for_user(enforcer, "alice")

# Complete user/role cleanup
CasbinEx2.delete_user(enforcer, "alice")  # Removes user from all policies
CasbinEx2.delete_role(enforcer, "admin")  # Removes role from all policies
```

### Permission Management

```elixir
# Add/remove permissions for users
CasbinEx2.add_permission_for_user(enforcer, "alice", ["data1", "read"])
CasbinEx2.delete_permission_for_user(enforcer, "alice", ["data1", "read"])

# Batch permission operations
CasbinEx2.add_permissions_for_user(enforcer, "alice", [
  ["data1", "read"],
  ["data2", "write"]
])

# Query permissions
CasbinEx2.get_permissions_for_user(enforcer, "alice")
CasbinEx2.get_implicit_permissions_for_user(enforcer, "alice")  # Includes role permissions
CasbinEx2.has_permission_for_user(enforcer, "alice", ["data1", "read"])

# Find users with specific permissions
CasbinEx2.get_users_for_permission(enforcer, ["data1", "read"])
```

### Advanced Enforcement

```elixir
# Basic enforcement
CasbinEx2.enforce(enforcer, ["alice", "data1", "read"])

# Enforcement with explanations
{allowed, explanations} = CasbinEx2.enforce_ex(enforcer, ["alice", "data1", "read"])

# Custom matcher enforcement
CasbinEx2.enforce_with_matcher(enforcer, custom_matcher, ["alice", "data1", "read"])
CasbinEx2.enforce_ex_with_matcher(enforcer, custom_matcher, ["alice", "data1", "read"])

# Batch enforcement for multiple requests
results = CasbinEx2.batch_enforce(enforcer, [
  ["alice", "data1", "read"],
  ["bob", "data2", "write"],
  ["charlie", "data3", "delete"]
])

# Batch enforcement with explanations
results_ex = CasbinEx2.batch_enforce_ex(enforcer, requests)
```

### Policy Persistence

```elixir
# Load from adapter
CasbinEx2.load_policy(enforcer)

# Save to adapter
CasbinEx2.save_policy(enforcer)
```

## Model Configuration Examples

### ACL Model

```ini
[request_definition]
r = sub, obj, act

[policy_definition]
p = sub, obj, act

[policy_effect]
e = some(where (p.eft == allow))

[matchers]
m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
```

### RBAC Model

```ini
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

### RBAC with Domains

```ini
[request_definition]
r = sub, dom, obj, act

[policy_definition]
p = sub, dom, obj, act

[role_definition]
g = _, _, _

[policy_effect]
e = some(where (p.eft == allow))

[matchers]
m = g(r.sub, p.sub, r.dom) && r.dom == p.dom && r.obj == p.obj && r.act == p.act
```

## Performance Benchmarking

CasbinEx2 includes built-in benchmarking tools to compare different enforcement strategies:

```elixir
# Run comprehensive benchmarks
CasbinEx2.Benchmark.run_comprehensive_benchmarks()

# Compare different enforcement methods
CasbinEx2.Benchmark.benchmark_enforcement_comparison()

# Test batch processing performance
CasbinEx2.Benchmark.benchmark_batch_processing()

# Evaluate cache performance gains
CasbinEx2.Benchmark.benchmark_cache_performance()

# Test scalability with large policy sets
CasbinEx2.Benchmark.benchmark_scalability()
```

## Testing

Run the test suite:

```bash
mix test
```

Run benchmarks:

```bash
mix run -e "CasbinEx2.Benchmark.run_comprehensive_benchmarks()"
```

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

