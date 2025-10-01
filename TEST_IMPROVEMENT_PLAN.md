# Test Coverage Improvement Plan
**Created**: October 1, 2025
**Target**: Increase coverage from 59.31% to 80%+ in 2 weeks

## Executive Summary

**Current Coverage**: 59.31% (675 tests)
**Target Coverage**: 80%+ (est. 950+ tests needed)
**Priority Modules**:
1. Enforcer: 41.26% → 80% (+275 tests estimated)
2. RBAC: 42.57% → 80% (+150 tests estimated)
3. Adapter Protocol: 42.86% → 80% (+30 tests estimated)
4. GraphQL Adapter: 1.75% → 70% (+80 tests estimated)
5. REST Adapter: 1.92% → 70% (+80 tests estimated)

**Total New Tests Needed**: ~600 tests over 2 weeks

---

## Module 1: GraphQL Adapter (Priority: HIGH)
**Current**: 1.75% coverage (only config tests)
**Target**: 70% coverage
**Gap**: Missing all functional tests

### Missing Test Coverage:

#### Core Adapter Functions (NOT TESTED):
```elixir
✗ load_policy/2 - Load policies via GraphQL query
✗ load_filtered_policy/3 - Load with filter conditions
✗ load_incremental_filtered_policy/3 - Incremental loading
✗ save_policy/3 - Save policies via mutation
✗ add_policy/4 - Add single policy via mutation
✗ remove_policy/4 - Remove single policy via mutation
✗ remove_filtered_policy/5 - Remove with filter
✗ filtered?/1 - Returns true (simple test)
```

#### Advanced Features (NOT TESTED):
```elixir
✗ introspect_schema/1 - GraphQL schema introspection
✗ subscribe_policy_changes/1 - WebSocket subscriptions
✗ validate_query/1 - Query validation
```

### Test Implementation Plan:

**File**: `test/adapters/graphql_adapter_test.exs`
**Estimated**: 80 new tests

```elixir
# Phase 1: Mock-based functional tests (40 tests)
describe "load_policy/2 with mock GraphQL" do
  test "successfully loads policies from GraphQL endpoint"
  test "handles empty policy response"
  test "handles GraphQL errors gracefully"
  test "retries on network failure"
  test "respects timeout configuration"
  test "includes authentication headers"
  test "parses GraphQL response correctly"
  test "handles malformed JSON response"
end

describe "save_policy/3 with mock GraphQL" do
  test "successfully saves policies via mutation"
  test "handles save errors"
  test "batches large policy sets"
  test "validates policy data before sending"
end

describe "add_policy/4" do
  test "adds single policy via mutation"
  test "handles duplicate policy errors"
  test "validates rule format"
end

describe "remove_policy/4" do
  test "removes single policy"
  test "handles not found errors"
end

describe "filtered operations" do
  test "load_filtered_policy applies filter correctly"
  test "remove_filtered_policy removes matching policies"
  test "filtered?/1 returns true"
end

# Phase 2: Integration tests with mock server (20 tests)
describe "GraphQL integration" do
  test "full policy lifecycle - load, add, save, remove"
  test "handles connection failures"
  test "retries with exponential backoff"
  test "circuit breaker activates after failures"
end

# Phase 3: Advanced features (20 tests)
describe "schema introspection" do
  test "introspect_schema returns schema details"
  test "handles introspection disabled"
end

describe "subscriptions" do
  test "subscribe_policy_changes establishes WebSocket"
  test "receives policy change notifications"
  test "handles subscription errors"
end
```

---

## Module 2: REST Adapter (Priority: HIGH)
**Current**: 1.92% coverage (only config tests)
**Target**: 70% coverage
**Gap**: Missing all functional tests

### Missing Test Coverage (Similar to GraphQL):
```elixir
✗ load_policy/2 - GET /policies
✗ save_policy/3 - POST /policies
✗ add_policy/4 - POST /policies/add
✗ remove_policy/4 - DELETE /policies/remove
✗ remove_filtered_policy/5 - DELETE with filter
✗ test_connection/1 - Connection health check
✗ get_config/1 - Retrieve adapter config
```

### Test Implementation Plan:

**File**: `test/adapters/rest_adapter_test.exs`
**Estimated**: 80 new tests

```elixir
# Phase 1: Mock-based REST functional tests (40 tests)
describe "load_policy/2 with mock REST API" do
  test "GET /policies returns policy data"
  test "includes authentication headers"
  test "handles 404 not found"
  test "handles 401 unauthorized"
  test "handles 500 server errors"
  test "retries on timeout"
  test "parses JSON response"
end

describe "save_policy/3" do
  test "POST /policies with policy data"
  test "handles save conflicts"
  test "validates request payload"
end

describe "add_policy/4" do
  test "POST /policies/add for single policy"
  test "returns created policy"
end

describe "remove_policy/4" do
  test "DELETE /policies/remove"
  test "returns 204 no content"
end

# Phase 2: Authentication tests (20 tests)
describe "authentication" do
  test "bearer token in Authorization header"
  test "basic auth with credentials"
  test "API key in custom header"
  test "handles auth failure 401"
end

# Phase 3: Connection management (20 tests)
describe "connection health" do
  test "test_connection verifies REST API reachable"
  test "connection pooling works"
  test "circuit breaker activates"
end
```

---

## Module 3: Adapter Protocol (Priority: MEDIUM)
**Current**: 42.86% coverage
**Target**: 80% coverage
**Gap**: Protocol dispatch function tests

### Missing Test Coverage:
```elixir
✗ Adapter.load_policy/2 - Dispatches to adapter.__struct__.load_policy
✗ Adapter.save_policy/3 - Protocol dispatch
✗ Adapter.add_policy/4 - Protocol dispatch
✗ Adapter.remove_policy/4 - Protocol dispatch
✗ Adapter.filtered?/1 - Protocol dispatch
```

### Test Implementation Plan:

**File**: `test/casbin_ex2/adapter_test.exs` (CREATE NEW)
**Estimated**: 30 new tests

```elixir
defmodule CasbinEx2.AdapterTest do
  use ExUnit.Case
  alias CasbinEx2.Adapter
  alias CasbinEx2.Adapter.MemoryAdapter

  describe "protocol dispatch" do
    setup do
      adapter = MemoryAdapter.new()
      model = %{}  # Mock model
      {:ok, adapter: adapter, model: model}
    end

    test "load_policy/2 dispatches to adapter implementation", %{adapter: adapter, model: model} do
      assert {:ok, _policies, _grouping} = Adapter.load_policy(adapter, model)
    end

    test "save_policy/3 dispatches correctly"
    test "add_policy/4 dispatches correctly"
    test "remove_policy/4 dispatches correctly"
    test "filtered?/1 returns adapter's filtered support"
  end

  describe "error handling" do
    test "handles adapter that doesn't implement callback"
    test "propagates adapter errors correctly"
  end
end
```

---

## Module 4: RBAC Module (Priority: CRITICAL)
**Current**: 42.57% coverage (24 functions)
**Target**: 80% coverage
**Gap**: Need dedicated RBAC test file

### Investigation Needed:
Current RBAC tests might be in `enforcer_test.exs`. Need to:
1. Check what RBAC functions are already tested
2. Create dedicated `test/casbin_ex2/rbac_test.exs`
3. Add comprehensive RBAC-specific tests

### RBAC Functions to Test:
```elixir
# From lib/casbin_ex2/rbac.ex (24 functions)
- get_roles_for_user/2,3
- get_users_for_role/2,3
- has_role_for_user/3,4
- add_role_for_user/3,4
- delete_role_for_user/3,4
- delete_roles_for_user/2,3
- delete_user/2,3
- delete_role/2,3
- get_implicit_roles_for_user/2,3
- get_implicit_users_for_role/2,3
- get_implicit_permissions_for_user/2,3
- get_permissions_for_user/2,3
- has_permission_for_user/3,4
- add_permissions_for_user/3,4
- delete_permission/3,4
- delete_permissions_for_user/2,3
- get_all_subjects/1,2
- get_all_objects/1,2
- get_all_actions/1,2
- get_all_roles/1,2
```

### Test Implementation Plan:

**File**: `test/casbin_ex2/rbac_test.exs` (CREATE NEW)
**Estimated**: 150 new tests

```elixir
defmodule CasbinEx2.RBACTest do
  use ExUnit.Case
  alias CasbinEx2.{Enforcer, RBAC}

  setup do
    {:ok, enforcer} = Enforcer.new("examples/rbac_model.conf", "examples/rbac_policy.csv")
    {:ok, enforcer: enforcer}
  end

  describe "role management" do
    test "get_roles_for_user/2 returns user roles"
    test "get_roles_for_user/3 with domain"
    test "add_role_for_user/3 adds role"
    test "add_role_for_user/4 with domain"
    test "delete_role_for_user/3 removes role"
    test "has_role_for_user/3 checks role"
    test "delete_roles_for_user/2 removes all roles"
    test "delete_user/2 removes user completely"
    test "delete_role/2 removes role from all users"
  end

  describe "implicit roles" do
    test "get_implicit_roles_for_user/2 includes inherited roles"
    test "get_implicit_users_for_role/2 includes indirect users"
  end

  describe "permissions" do
    test "get_permissions_for_user/2 returns direct permissions"
    test "get_implicit_permissions_for_user/2 includes inherited"
    test "add_permissions_for_user/3 adds permissions"
    test "delete_permissions_for_user/2 removes all"
    test "has_permission_for_user/3 checks permission"
  end

  describe "introspection" do
    test "get_all_subjects/1 returns all subjects"
    test "get_all_objects/1 returns all objects"
    test "get_all_actions/1 returns all actions"
    test "get_all_roles/1 returns all roles"
  end
end
```

---

## Module 5: Enforcer Module (Priority: CRITICAL)
**Current**: 41.26% coverage (92 functions, 942 test lines exist)
**Target**: 80% coverage
**Gap**: 58.74% of code untested despite 942 test lines

### Analysis Needed:
With 942 test lines but only 41% coverage, likely issues:
1. Tests focus on happy paths, missing edge cases
2. Error handling paths not tested
3. Complex conditional branches not covered
4. Private functions not indirectly tested

### Investigation Plan:
```bash
# Generate coverage report to see uncovered lines
mix test --cover
open cover/excoveralls.html  # View detailed coverage

# Identify untested functions
grep "def " lib/casbin_ex2/enforcer.ex | \
  while read func; do
    grep -q "$func" test/casbin_ex2/enforcer_test.exs || echo "Missing: $func"
  done
```

### Test Improvement Strategy:
**File**: `test/casbin_ex2/enforcer_test.exs` (ENHANCE EXISTING)
**Estimated**: 275 new tests

Focus areas:
1. **Error cases** (50 tests): Invalid inputs, malformed policies, nil handling
2. **Edge cases** (100 tests): Empty policies, boundary conditions, special characters
3. **Batch operations** (50 tests): Large datasets, concurrent operations
4. **Performance** (25 tests): Caching behavior, optimization paths
5. **Integration** (50 tests): Multi-component workflows

---

## Implementation Timeline

### Week 1: Adapters (Days 1-5)
**Goal**: Fix GraphQL (1.75%→70%) and REST (1.92%→70%) adapters

- **Day 1**: GraphQL Adapter - Core functions (load, save, add, remove) - 40 tests
- **Day 2**: GraphQL Adapter - Advanced features (introspection, subscriptions) - 40 tests
- **Day 3**: REST Adapter - Core functions + auth - 40 tests
- **Day 4**: REST Adapter - Connection management + integration - 40 tests
- **Day 5**: Adapter Protocol tests - 30 tests

**Expected**: +190 tests, adapters at 70%+, protocol at 80%+

### Week 2: Core Modules (Days 6-10)
**Goal**: Improve Enforcer (41%→80%) and RBAC (42%→80%)

- **Day 6**: RBAC Module - Role management tests - 50 tests
- **Day 7**: RBAC Module - Permissions + introspection tests - 100 tests
- **Day 8**: Enforcer Module - Error cases + edge cases - 150 tests
- **Day 9**: Enforcer Module - Batch ops + performance - 75 tests
- **Day 10**: Enforcer Module - Integration tests - 50 tests

**Expected**: +425 tests, RBAC at 80%+, Enforcer at 75%+

### Validation & Refinement
**Goal**: Reach 80% overall coverage

- Run `mix test --cover` after each day
- Identify remaining gaps
- Add targeted tests for uncovered lines
- Aim for 80% by end of Week 2

---

## Success Metrics

**Coverage Targets**:
- Overall: 59.31% → 80%+ (20.69 point improvement)
- Enforcer: 41.26% → 80%+ (38.74 point improvement)
- RBAC: 42.57% → 80%+ (37.43 point improvement)
- Adapter: 42.86% → 80%+ (37.14 point improvement)
- GraphQL Adapter: 1.75% → 70%+ (68.25 point improvement)
- REST Adapter: 1.92% → 70%+ (68.08 point improvement)

**Test Count**:
- Current: 675 tests
- Target: 1,275 tests (+600 new tests)

**Quality Gates**:
- ✓ All new tests pass
- ✓ No regressions in existing tests
- ✓ mix credo --strict passes
- ✓ mix format passes
- ✓ Coverage report generated successfully

---

## Next Steps

1. **Review this plan** - Approve or request modifications
2. **Start with adapters** (Week 1) - Highest ROI for coverage improvement
3. **Daily progress tracking** - Update TODO.md with daily achievements
4. **Coverage monitoring** - Run mix test --cover daily
5. **Iterate as needed** - Adjust plan based on actual coverage gains
