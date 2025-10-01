# Conditional Role Manager Analysis

## Overview
The Conditional Role Manager is a complex module that extends the basic RoleManager with conditional link evaluation capabilities.

## Go Implementation Analysis

### File Structure
- **Main Interface**: `../casbin/rbac/role_manager.go`
  - `LinkConditionFunc` type: `func(args ...string) (bool, error)`
  - `ConditionalRoleManager` interface (extends RoleManager)
  - `ContextRoleManager` interface (context-aware operations)

- **Implementation**: `../casbin/rbac/default-role-manager/role_manager.go` (~1300 LOC)
  - `Role` struct with conditional link maps
  - `ConditionalRoleManager` struct
  - `ConditionalDomainManager` struct

### Key Features

#### 1. Conditional Links
```go
type Role struct {
    linkConditionFuncMap       *sync.Map  // user+role -> condition function
    linkConditionFuncParamsMap *sync.Map  // user+role -> parameters
}
```

#### 2. Core Functions
- `AddLinkConditionFunc(user, role, fn)` - Add condition to a link
- `SetLinkConditionFuncParams(user, role, params...)` - Set parameters
- `AddDomainLinkConditionFunc(user, role, domain, fn)` - Domain-specific
- `SetDomainLinkConditionFuncParams(user, role, domain, params...)` - Domain params

#### 3. Link Evaluation
When checking `HasLink`, the condition function is evaluated:
```go
if condFunc, ok := role.linkConditionFuncMap.Load(key); ok {
    valid, err := condFunc.(LinkConditionFunc)(params...)
    if !valid || err != nil {
        return false  // Link is invalid
    }
}
```

### Complexity Assessment

**Estimated Implementation Effort**: 2-3 weeks
- **Lines of Code**: ~800-1000 LOC (Elixir typically more concise than Go)
- **Complexity**: HIGH
  - Thread-safe map operations (Go sync.Map → Elixir ETS or Agent)
  - Function storage and evaluation
  - Domain management integration
  - Backward compatibility with existing RoleManager

## Elixir Design Considerations

### 1. Behavior Definition
```elixir
defmodule CasbinEx2.ConditionalRoleManager do
  @callback add_link_condition_func(rm, user, role, func) :: t()
  @callback set_link_condition_func_params(rm, user, role, params) :: t()
  @callback add_domain_link_condition_func(rm, user, role, domain, func) :: t()
  @callback set_domain_link_condition_func_params(rm, user, role, domain, params) :: t()
end
```

### 2. Implementation Options

**Option A: Extend Existing RoleManager Module**
- Pros: Simpler integration, reuses existing code
- Cons: Increases module complexity

**Option B: Separate ConditionalRoleManager Module**
- Pros: Clean separation, easier testing
- Cons: More duplication, harder integration

**Recommendation**: Option B (Separate Module) for maintainability

### 3. State Storage
- **Go**: Uses `sync.Map` for thread-safe concurrent access
- **Elixir Options**:
  - Agent (simpler, good for single-process)
  - ETS (faster, better for concurrent access)
  - GenServer (if need more control)

**Recommendation**: Use Agent for simplicity, can optimize to ETS later

### 4. Function Storage Challenge
**Problem**: Elixir doesn't serialize anonymous functions across processes
**Solutions**:
1. Store function references as atoms/modules
2. Use a registry pattern for named functions
3. Accept function as parameter in HasLink call

**Recommendation**: Option 3 (pass function during evaluation) - most flexible

## Integration Points

### 1. Enforcer Functions Already Implemented
We already have the enforcer-level functions waiting:
- `add_named_link_condition_func/5`
- `add_named_domain_link_condition_func/6`
- `set_named_link_condition_func_params/5`
- `set_named_domain_link_condition_func_params/6`

These just need ConditionalRoleManager backend to delegate to.

### 2. RoleManager Behavior Extension
Need to extend `CasbinEx2.RoleManager` behavior to include:
- `add_matching_func/3`
- `add_domain_matching_func/3`
- Conditional link functions

## Implementation Phases

### Phase 1: Core Structure (3 days)
1. Define ConditionalRoleManager behavior
2. Create basic module structure
3. Add condition storage (Agent-based)

### Phase 2: Conditional Link Logic (4 days)
1. Implement AddLinkConditionFunc
2. Implement SetLinkConditionFuncParams
3. Implement domain variants
4. Integrate with HasLink evaluation

### Phase 3: Integration (3 days)
1. Update enforcer to use ConditionalRoleManager
2. Ensure backward compatibility
3. Update named_role_managers map handling

### Phase 4: Testing & Documentation (4 days)
1. Unit tests for all functions
2. Integration tests with enforcer
3. Documentation and examples
4. Performance testing

**Total Estimated Time**: 2 weeks (14 days)

## Alternative Approach: Incremental Implementation

Given time constraints, we could implement a **simplified version** first:

### Minimal Viable Implementation (3 days)
1. Add function storage structure
2. Basic conditional link validation
3. Simple parameter passing
4. Skip context-aware features initially

### Benefits
- Quick value delivery
- Validates architecture
- Can be enhanced iteratively

## Recommendation

**For immediate progress**: Implement Policy Dispatcher first (simpler, more immediate value)
**For completeness**: Implement Conditional RM with incremental approach

The Conditional RM has TODO markers in place and can be completed in next sprint.
