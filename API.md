# CasbinEx2 API Documentation

This document provides a comprehensive reference for all CasbinEx2 APIs organized by functionality.

## Table of Contents

- [Enforcer Management](#enforcer-management)
- [Basic Enforcement](#basic-enforcement)
- [Advanced Enforcement](#advanced-enforcement)
- [Policy Management](#policy-management)
- [Role Management](#role-management)
- [Permission Management](#permission-management)
- [Domain Operations](#domain-operations)
- [Batch Operations](#batch-operations)
- [Policy Persistence](#policy-persistence)
- [Management APIs](#management-apis)
- [Specialized Enforcers](#specialized-enforcers)

## Enforcer Management

### `start_enforcer/3`

Starts a new enforcer process.

```elixir
CasbinEx2.start_enforcer(name, model_path, opts \\ [])
```

**Parameters:**
- `name` - Atom identifier for the enforcer
- `model_path` - Path to the model configuration file
- `opts` - Options including `:adapter` for custom adapters

**Returns:** `{:ok, pid}` or `{:error, reason}`

### `stop_enforcer/1`

Stops an enforcer process.

```elixir
CasbinEx2.stop_enforcer(name)
```

**Parameters:**
- `name` - Enforcer identifier

**Returns:** `:ok`

## Basic Enforcement

### `enforce/2`

Performs authorization enforcement.

```elixir
CasbinEx2.enforce(name, request)
```

**Parameters:**
- `name` - Enforcer identifier
- `request` - List representing the authorization request (e.g., `["alice", "data1", "read"]`)

**Returns:** `true` or `false`

### `enforce_ex/2`

Performs authorization enforcement with explanations.

```elixir
CasbinEx2.enforce_ex(name, request)
```

**Returns:** `{allowed, explanations}` where `allowed` is boolean and `explanations` is a list

## Advanced Enforcement

### `enforce_with_matcher/3`

Performs authorization enforcement with a custom matcher.

```elixir
CasbinEx2.enforce_with_matcher(name, matcher, request)
```

**Parameters:**
- `matcher` - Custom matcher function

### `enforce_ex_with_matcher/3`

Performs authorization enforcement with custom matcher and explanations.

```elixir
CasbinEx2.enforce_ex_with_matcher(name, matcher, request)
```

## Policy Management

### `add_policy/2`

Adds a policy rule.

```elixir
CasbinEx2.add_policy(name, params)
```

**Parameters:**
- `params` - List representing the policy (e.g., `["alice", "data1", "read"]`)

**Returns:** `true` if added, `false` if already exists

### `remove_policy/2`

Removes a policy rule.

```elixir
CasbinEx2.remove_policy(name, params)
```

**Returns:** `true` if removed, `false` if didn't exist

### `get_policy/1`

Gets all policy rules.

```elixir
CasbinEx2.get_policy(name)
```

**Returns:** List of policy rules

### `has_policy/2`

Checks if a policy rule exists.

```elixir
CasbinEx2.has_policy(name, params)
```

**Returns:** `true` or `false`

### `update_policy/3`

Updates a policy rule.

```elixir
CasbinEx2.update_policy(name, old_policy, new_policy)
```

### `update_policies/3`

Updates multiple policy rules.

```elixir
CasbinEx2.update_policies(name, old_policies, new_policies)
```

### `update_grouping_policy/3`

Updates a grouping policy rule.

```elixir
CasbinEx2.update_grouping_policy(name, old_rule, new_rule)
```

## Role Management

### `add_role_for_user/4`

Adds a role for a user.

```elixir
CasbinEx2.add_role_for_user(name, user, role, domain \\ "")
```

**Parameters:**
- `user` - User identifier
- `role` - Role name
- `domain` - Optional domain (for domain-specific RBAC)

### `delete_role_for_user/4`

Deletes a role for a user.

```elixir
CasbinEx2.delete_role_for_user(name, user, role, domain \\ "")
```

### `get_roles_for_user/3`

Gets all roles for a user.

```elixir
CasbinEx2.get_roles_for_user(name, user, domain \\ "")
```

**Returns:** List of role names

### `get_users_for_role/3`

Gets all users for a role.

```elixir
CasbinEx2.get_users_for_role(name, role, domain \\ "")
```

**Returns:** List of user identifiers

### `has_role_for_user/4`

Checks if a user has a role.

```elixir
CasbinEx2.has_role_for_user(name, user, role, domain \\ "")
```

**Returns:** `true` or `false`

### `get_implicit_roles_for_user/3`

Gets implicit roles for a user (includes inherited roles).

```elixir
CasbinEx2.get_implicit_roles_for_user(name, user, domain \\ "")
```

## Permission Management

### `add_permission_for_user/3`

Adds a permission for a user.

```elixir
CasbinEx2.add_permission_for_user(name, user, permission)
```

### `delete_permission_for_user/3`

Deletes a permission for a user.

```elixir
CasbinEx2.delete_permission_for_user(name, user, permission)
```

### `get_permissions_for_user/3`

Gets permissions for a user.

```elixir
CasbinEx2.get_permissions_for_user(name, user, domain \\ "")
```

### `get_implicit_permissions_for_user/3`

Gets implicit permissions for a user (includes permissions through roles).

```elixir
CasbinEx2.get_implicit_permissions_for_user(name, user, domain \\ "")
```

### `has_permission_for_user/3`

Checks if a user has a specific permission.

```elixir
CasbinEx2.has_permission_for_user(name, user, permission)
```

### `get_users_for_permission/2`

Gets all users who have the specified permission.

```elixir
CasbinEx2.get_users_for_permission(name, permission)
```

## Domain Operations

### `add_role_for_user_in_domain/4`

Adds a role for a user in the specified domain.

```elixir
CasbinEx2.add_role_for_user_in_domain(name, user, role, domain)
```

### `delete_role_for_user_in_domain/4`

Deletes a role for a user in the specified domain.

```elixir
CasbinEx2.delete_role_for_user_in_domain(name, user, role, domain)
```

### `get_users_for_role_in_domain/3`

Gets all users who have the specified role in the given domain.

```elixir
CasbinEx2.get_users_for_role_in_domain(name, role, domain)
```

### `get_roles_for_user_in_domain/3`

Gets all roles for a user in the given domain.

```elixir
CasbinEx2.get_roles_for_user_in_domain(name, user, domain)
```

### `delete_roles_for_user_in_domain/3`

Deletes all roles for a user in the specified domain.

```elixir
CasbinEx2.delete_roles_for_user_in_domain(name, user, domain)
```

### `get_all_users_by_domain/2`

Gets all users in the specified domain.

```elixir
CasbinEx2.get_all_users_by_domain(name, domain)
```

### `delete_all_users_by_domain/2` ✨ **ENHANCED**

Deletes all users and their role assignments in the specified domain.

```elixir
CasbinEx2.RBAC.delete_all_users_by_domain(enforcer, domain)
```

**Parameters:**
- `enforcer` - The enforcer struct
- `domain` - The domain to clear

**Returns:** `{:ok, enforcer}` or `{:error, reason}`

**Use Case:** Multi-tenant cleanup when removing a tenant domain.

### `delete_domains/2` ✨ **NEW**

Batch deletes multiple domains and all their role assignments.

```elixir
CasbinEx2.RBAC.delete_domains(enforcer, domains)
```

**Parameters:**
- `enforcer` - The enforcer struct
- `domains` - List of domain strings to delete

**Returns:** `{:ok, enforcer}` or `{:error, reason}`

**Use Case:** Bulk domain cleanup in multi-tenant systems.

## Batch Operations

### `batch_enforce/2`

Performs batch enforcement for multiple requests.

```elixir
CasbinEx2.batch_enforce(name, requests)
```

**Parameters:**
- `requests` - List of request lists

**Returns:** List of boolean results

### `batch_enforce_ex/2`

Performs batch enforcement with explanations.

```elixir
CasbinEx2.batch_enforce_ex(name, requests)
```

**Returns:** List of `{allowed, explanations}` tuples

### `batch_enforce_with_matcher/3`

Performs batch enforcement with custom matcher.

```elixir
CasbinEx2.batch_enforce_with_matcher(name, matcher, requests)
```

### `add_roles_for_user/4`

Adds multiple roles for a user in one operation.

```elixir
CasbinEx2.add_roles_for_user(name, user, roles, domain \\ "")
```

### `add_permissions_for_user/3`

Adds multiple permissions for a user in one operation.

```elixir
CasbinEx2.add_permissions_for_user(name, user, permissions)
```

### `delete_permissions_for_user/3`

Deletes multiple permissions for a user in one operation.

```elixir
CasbinEx2.delete_permissions_for_user(name, user, permissions)
```

## Policy Persistence

### `load_policy/1`

Loads policy from the adapter.

```elixir
CasbinEx2.load_policy(name)
```

**Returns:** `:ok` or `{:error, reason}`

### `save_policy/1`

Saves policy to the adapter.

```elixir
CasbinEx2.save_policy(name)
```

**Returns:** `:ok` or `{:error, reason}`

### `load_filtered_policy/2` ✨ **NEW**

Loads a filtered subset of policies from the adapter based on filter criteria.

```elixir
CasbinEx2.Enforcer.load_filtered_policy(enforcer, filter)
```

**Parameters:**
- `enforcer` - The enforcer struct
- `filter` - Map containing filter criteria (e.g., `%{subject: "alice", domain: "domain1"}`)

**Returns:** `{:ok, enforcer}` or `{:error, reason}`

**Use Case:** Large-scale deployments where loading all policies would be inefficient.

### `load_incremental_filtered_policy/2` ✨ **NEW**

Loads additional filtered policies without clearing existing ones.

```elixir
CasbinEx2.Enforcer.load_incremental_filtered_policy(enforcer, filter)
```

**Parameters:**
- `enforcer` - The enforcer struct
- `filter` - Map containing filter criteria

**Returns:** `{:ok, enforcer}` or `{:error, reason}`

**Use Case:** Incrementally loading additional policies for multi-tenant systems.

### `is_filtered?/1` ✨ **NEW**

Checks if the loaded policy has been filtered.

```elixir
CasbinEx2.Enforcer.is_filtered?(enforcer)
```

**Returns:** `true` if policies were loaded using filtered loading, `false` otherwise

### `clear_policy/1` ✨ **NEW**

Clears all policies and grouping policies from the enforcer without affecting adapter storage.

```elixir
CasbinEx2.Enforcer.clear_policy(enforcer)
```

**Returns:** Updated enforcer struct with empty policies

### `load_model/2` ✨ **NEW**

Reloads the model from a file path.

```elixir
CasbinEx2.Enforcer.load_model(enforcer, model_path)
```

**Parameters:**
- `enforcer` - The enforcer struct
- `model_path` - Path to the model configuration file

**Returns:** `{:ok, enforcer}` or `{:error, reason}`

**Use Case:** Dynamic model updates when the model configuration file has been updated.

### `set_watcher/2` ✨ **ENHANCED**

Sets a watcher for distributed policy synchronization.

```elixir
CasbinEx2.Enforcer.set_watcher(enforcer, watcher)
```

**Parameters:**
- `enforcer` - The enforcer struct
- `watcher` - Watcher implementation for policy sync (e.g., RedisWatcher, EtcdWatcher)

**Returns:** `{:ok, enforcer}` or `{:error, reason}`

**Use Case:** Distributed systems requiring policy synchronization across multiple nodes.

### `build_incremental_role_links/4` ✨ **NEW**

Incrementally builds role links without clearing existing links.

```elixir
CasbinEx2.Enforcer.build_incremental_role_links(enforcer, op, ptype, rules)
```

**Parameters:**
- `enforcer` - The enforcer struct
- `op` - Operation: `:add` to add links, `:remove` to remove links
- `ptype` - Policy type (e.g., "g", "g2")
- `rules` - List of rules, each rule is a list like `["alice", "admin", "domain1"]`

**Returns:** `{:ok, enforcer}` or `{:error, reason}`

**Use Case:** Performance optimization when only a few role assignments change, avoiding full role link rebuild.

**Example:**
```elixir
# Add new role links incrementally
{:ok, enforcer} = build_incremental_role_links(
  enforcer,
  :add,
  "g",
  [["alice", "admin"], ["bob", "editor"]]
)

# Remove specific role links
{:ok, enforcer} = build_incremental_role_links(
  enforcer,
  :remove,
  "g",
  [["bob", "editor"]]
)
```

### `build_incremental_conditional_role_links/4` ✨ **NEW**

Incrementally builds conditional role links for advanced role management scenarios.

```elixir
CasbinEx2.Enforcer.build_incremental_conditional_role_links(enforcer, op, ptype, rules)
```

**Parameters:**
- `enforcer` - The enforcer struct
- `op` - Operation: `:add` to add links, `:remove` to remove links
- `ptype` - Policy type (e.g., "g", "g2")
- `rules` - List of rules with conditional parameters

**Returns:** `{:ok, enforcer}` or `{:error, reason}`

**Use Case:** Advanced scenarios requiring conditional role relationships (time-based roles, context-aware permissions).

## Management APIs

### `get_all_subjects/1`

Gets all subjects that show up in policies.

```elixir
CasbinEx2.get_all_subjects(name)
```

### `get_all_objects/1`

Gets all objects that show up in policies.

```elixir
CasbinEx2.get_all_objects(name)
```

### `get_all_actions/1`

Gets all actions that show up in policies.

```elixir
CasbinEx2.get_all_actions(name)
```

### `get_all_roles/1`

Gets all roles that show up in grouping policies.

```elixir
CasbinEx2.get_all_roles(name)
```

### `get_all_domains/1`

Gets all domains from policies and grouping policies.

```elixir
CasbinEx2.get_all_domains(name)
```

### `delete_user/2`

Completely removes a user (removes user from all policies and grouping policies).

```elixir
CasbinEx2.delete_user(name, user)
```

### `delete_role/2`

Completely removes a role (removes role from all grouping policies).

```elixir
CasbinEx2.delete_role(name, role)
```

### `delete_permission/2`

Removes a permission (removes permission from all policies).

```elixir
CasbinEx2.delete_permission(name, permission)
```

## Specialized Enforcers

### CachedEnforcer

For improved performance with frequent authorization checks:

```elixir
# Start
{:ok, _pid} = CasbinEx2.CachedEnforcer.start_link(
  :cached_enforcer,
  "path/to/model.conf",
  cache_size: 1000
)

# Use same API as basic enforcer
CasbinEx2.CachedEnforcer.enforce(:cached_enforcer, ["alice", "data1", "read"])
```

### SyncedEnforcer

For thread-safe operations in concurrent environments:

```elixir
# Start
{:ok, _pid} = CasbinEx2.SyncedEnforcer.start_link(
  :synced_enforcer,
  "path/to/model.conf"
)

# Use same API with automatic synchronization
CasbinEx2.SyncedEnforcer.enforce(:synced_enforcer, ["alice", "data1", "read"])
```

### DistributedEnforcer

For multi-node deployments with automatic policy synchronization:

```elixir
# Start
{:ok, _pid} = CasbinEx2.DistributedEnforcer.start_link(
  :distributed_enforcer,
  "path/to/model.conf",
  nodes: [node()],
  sync_interval: 5000
)

# Policies are automatically synchronized across nodes
CasbinEx2.DistributedEnforcer.add_policy(:distributed_enforcer, ["alice", "data1", "read"])
```

## Return Value Conventions

- **Boolean operations** (like `enforce`, `has_policy`, `add_policy`): Return `true` or `false`
- **List operations** (like `get_policy`, `get_roles_for_user`): Return lists of results
- **Process operations** (like `start_enforcer`): Return `{:ok, pid}` or `{:error, reason}`
- **Persistence operations** (like `load_policy`, `save_policy`): Return `:ok` or `{:error, reason}`

## Error Handling

All functions handle errors gracefully and return appropriate error tuples when operations fail. Check the return values to handle errors in your application.

For detailed examples and usage patterns, see the main [README.md](README.md) file.