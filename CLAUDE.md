# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CasbinEx2 is an Elixir implementation of the Casbin authorization library, ported from the official Go version at `../casbin`. This is a production-ready authorization library with 100% API parity to Go Casbin, implementing ACL, RBAC, ABAC and other access control models.

**Key Facts:**
- 127+ API functions implemented (complete IEnforcer interface parity)
- 42 test files with 1,298+ passing tests
- 9 built-in adapters (vs 2 in Go core)
- GenServer-based architecture with OTP supervision
- Supports distributed enforcement across nodes

## Reference Project Structure

This project parallels the Go Casbin codebase at `../casbin`:
- Maintain similar naming (converted to snake_case for Elixir conventions)
- Keep module structure aligned with Go packages
- Mirror test organization and coverage
- Preserve function signatures with Elixir idioms

**Critical Rule:** When migrating features from Go Casbin, use similar names for modules, functions, and tests. The only difference should be Elixir's snake_case style.

## Common Development Commands

### Testing
```bash
# Run all tests
mix test

# Run specific test file
mix test test/casbin_ex2/enforcer_test.exs

# Run single test by line number
mix test test/casbin_ex2/enforcer_test.exs:45

# Run with coverage report
mix test --cover

# Run tests matching pattern
mix test --only rbac
```

### Code Quality (MANDATORY after each session)
```bash
# 1. Format code (always run first)
mix format

# 2. Run strict linting (fix all issues)
mix credo --strict

# 3. Run tests and fix failures
mix test
```

### Type Checking
```bash
# Run dialyzer for type safety
mix dialyzer

# First time setup (slow, one-time)
mix dialyzer --plt
```

### Development Server
```bash
# Start IEx with project loaded
iex -S mix

# Reload changed modules in IEx
recompile()
```

## Architecture Overview

### Core Modules (`lib/casbin_ex2/`)

**Enforcement Engine:**
- `enforcer.ex` - Main enforcement logic (98KB, 127+ functions)
- `enforcer_server.ex` - GenServer wrapper for supervised enforcement
- `cached_enforcer.ex` - High-performance caching layer
- `synced_enforcer.ex` - Thread-safe concurrent enforcement
- `distributed_enforcer.ex` - Multi-node policy synchronization

**Policy & Role Management:**
- `management.ex` - Policy CRUD operations (67 functions)
- `rbac.ex` - Role-based access control (86 functions, 2× Go Casbin)
- `role_manager.ex` - Default role manager
- `conditional_role_manager.ex` - Role links with conditions
- `context_role_manager.ex` - Context-aware role management

**Core Components:**
- `model.ex` - Model parsing and configuration
- `adapter.ex` - Adapter behavior definition
- `effect.ex` - Policy effect evaluation
- `transaction.ex` - Atomic policy operations
- `frontend.ex` - Frontend integration APIs

**Infrastructure:**
- `application.ex` - OTP application startup
- `enforcer_supervisor.ex` - Supervision tree
- `logger.ex` - Logging utilities
- `watcher.ex` - Distributed policy watching
- `dispatcher.ex` - Policy change dispatching

### Adapters (`lib/casbin_ex2/adapter/`)

9 built-in adapters (more than Go Casbin core):
- `file_adapter.ex` - CSV file storage
- `ecto_adapter.ex` - PostgreSQL/MySQL/SQLite via Ecto
- `memory_adapter.ex` - ETS-based in-memory
- `string_adapter.ex` - String-based policies
- `redis_adapter.ex` - Distributed Redis storage
- Plus: BatchAdapter, ContextAdapter, GraphQLAdapter, RESTAdapter

### Model Components (`lib/casbin_ex2/model/`)

Policy model parsing and configuration:
- `assertion.ex` - Policy assertion definitions
- `function.ex` - Built-in matching functions (35+ operators)
- `policy.ex` - Policy rule storage
- `scope.ex` - Policy scope management

### Test Organization (`test/`)

**Core Tests (`test/casbin_ex2/`):**
- `enforcer_test.exs` - Basic enforcement
- `management_test.exs` - Policy management
- `rbac_test.exs` - Role operations
- `transaction_test.exs` - Atomic operations
- `benchmark.exs` - Performance benchmarks

**Policy Model Tests (`test/policy_models/`):**
- ACL variants (basic, superuser, without_users, without_resources)
- RBAC models (basic, domains, resource_roles, deny)
- Advanced (ABAC, RESTful, priority)
- Security models (BIBA, BLP, LBAC)

**RBAC Tests (`test/rbac/`):**
- Core RBAC functionality
- Domain operations
- Implicit permissions
- Role hierarchies

**Core Enforcement (`test/core_enforcement/`):**
- Pattern matching tests
- Network matching (IP, CIDR)
- Policy effect tests
- Custom functions

**Adapter Tests (`test/adapters/`):**
- Individual adapter implementations
- Persistence verification
- Distributed synchronization

## Code Style & Conventions

### Naming Conventions
- **Modules:** PascalCase (e.g., `CasbinEx2.Enforcer`)
- **Functions:** snake_case (e.g., `add_role_for_user/4`)
- **Predicates:** End with `?` (e.g., `has_policy?/2`, `log_enabled?/1`)
- **Private functions:** Prefix with `do_` when implementing public function

### Function Signatures
- Always include `@spec` type annotations
- Use pattern matching for different arities
- Return `{:ok, result}` or `{:error, reason}` for operations that can fail
- For predicates, return plain `true` or `false`

### State Management Pattern
```elixir
# Go Casbin (mutating):
func (e *Enforcer) AddPolicy(params ...interface{}) (bool, error)

# Elixir pattern (immutable):
@spec add_policy(Enforcer.t(), list()) :: {:ok, Enforcer.t()} | {:error, term()}
def add_policy(%Enforcer{} = e, policy) when is_list(policy)
```

Return new enforcer struct rather than mutating in place.

### GenServer Integration
When using enforcer as GenServer:
```elixir
# Direct struct usage (functional)
{:ok, enforcer} = Enforcer.new_enforcer(model, adapter)
result = Enforcer.enforce(enforcer, ["alice", "data1", "read"])

# GenServer usage (concurrent)
{:ok, _pid} = EnforceServer.start_link(model_path: model, name: :my_enforcer)
result = CasbinEx2.enforce(:my_enforcer, ["alice", "data1", "read"])
```

## Important Implementation Details

### Policy Comparison with Go Casbin

When implementing features from Go Casbin:
1. Check `../casbin` for reference implementation
2. Maintain function name mapping (camelCase → snake_case)
3. Preserve parameter order and semantics
4. Adapt return types to Elixir idioms (`{:ok, _}` pattern)
5. Use functional immutability (return new enforcer)

### Testing Requirements

Every new feature MUST include:
- Unit tests in `test/casbin_ex2/`
- Integration tests if involving adapters
- Policy model tests if adding new model support
- Benchmark tests for performance-critical features

Test file naming: `<module_name>_test.exs`

### Built-in Operators

35+ matching operators in `lib/casbin_ex2/model/function.ex`:
- Pattern: `keyMatch`, `keyMatch2-5`, `regexMatch`, `globMatch`
- Network: `ipMatch`, `ipMatch2-3`
- Path: `keyGet`, `keyGet2-3`
- Time: `timeMatch`

When adding operators, maintain compatibility with Go Casbin.

### Adapter Development

New adapters must implement `CasbinEx2.Adapter` behavior:
```elixir
@callback load_policy(Model.t()) :: {:ok, Model.t()} | {:error, term()}
@callback save_policy(Model.t()) :: :ok | {:error, term()}
@callback add_policy(String.t(), String.t(), list()) :: :ok | {:error, term()}
@callback remove_policy(String.t(), String.t(), list()) :: :ok | {:error, term()}
```

## Common Patterns

### Creating an Enforcer
```elixir
# From files
{:ok, e} = Enforcer.new_enforcer("model.conf", "policy.csv")

# With custom adapter
adapter = EctoAdapter.new(repo: MyApp.Repo)
{:ok, e} = Enforcer.new_enforcer("model.conf", adapter)

# As supervised GenServer
{:ok, pid} = EnforceServer.start_link(
  model_path: "model.conf",
  adapter: adapter,
  name: :my_enforcer
)
```

### RBAC Operations
```elixir
# Add role
{:ok, e} = RBAC.add_role_for_user(e, "alice", "admin")

# Check role
has_role = RBAC.has_role_for_user(e, "alice", "admin")

# Get implicit permissions through roles
perms = RBAC.get_implicit_permissions_for_user(e, "alice")
```

### Transaction Pattern
```elixir
# Atomic multi-operation
{:ok, tx} = Transaction.new_transaction(enforcer)
{:ok, tx} = Transaction.add_policy(tx, "p", ["alice", "data1", "read"])
{:ok, tx} = Transaction.add_policy(tx, "p", ["bob", "data2", "write"])
{:ok, enforcer} = Transaction.commit(tx)
```

## Integration Points

### Phoenix Integration
Add to supervision tree in `application.ex`:
```elixir
children = [
  MyApp.Repo,
  {CasbinEx2.EnforceServer, [
    model_path: "priv/casbin/model.conf",
    adapter: EctoAdapter.new(repo: MyApp.Repo),
    name: :casbin
  ]}
]
```

Create authorization plug:
```elixir
defmodule MyAppWeb.AuthorizePlug do
  def call(conn, _opts) do
    user = conn.assigns.current_user
    resource = conn.path_info |> Enum.join("/")
    action = conn.method |> String.downcase()

    if CasbinEx2.enforce(:casbin, [user.id, resource, action]) do
      conn
    else
      conn |> put_status(:forbidden) |> halt()
    end
  end
end
```

### Ecto Configuration
```elixir
# config/config.exs
config :casbin_ex2, CasbinEx2.Repo,
  database: "casbin_db",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"
```

## Documentation Standards

All public functions require:
- `@moduledoc` for modules
- `@doc` for public functions
- `@spec` type specifications
- Usage examples in doc strings
- Parameter descriptions

Example:
```elixir
@doc """
Adds a role for a user.

## Parameters
- `enforcer` - The enforcer struct
- `user` - User identifier
- `role` - Role to assign

## Returns
- `{:ok, enforcer}` - Updated enforcer with role assigned
- `{:error, reason}` - If role assignment fails

## Examples

    iex> {:ok, e} = RBAC.add_role_for_user(e, "alice", "admin")
    {:ok, %Enforcer{}}
"""
@spec add_role_for_user(Enforcer.t(), String.t(), String.t()) ::
  {:ok, Enforcer.t()} | {:error, term()}
```

## Performance Considerations

- Use `batch_enforce/2` for multiple authorization checks (10× faster)
- Enable caching with `CachedEnforcer` for repeated checks
- Use `filtered_policy` loading for large policy sets
- Consider `DistributedEnforcer` for multi-node deployments
- Benchmark performance-critical changes with `test/casbin_ex2/benchmark.exs`

## Key Resources

- **API Reference:** `API.md` - Complete function documentation
- **Feature Parity:** `FeatureParity.md` - Comparison with Go Casbin
- **Examples:** `examples/` - Working examples for all models
- **Go Reference:** `../casbin` - Original implementation
- **Online Editor:** https://casbin.org/editor/ - Test policies online
