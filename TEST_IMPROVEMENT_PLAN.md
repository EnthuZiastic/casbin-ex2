# Test Coverage Improvement Plan
**Created**: October 1, 2025
**Last Updated**: October 1, 2025
**Target**: Increase coverage from 59.31% to 80%+ in 2 weeks

## 📊 Current Progress

**Overall Coverage**: 61.39% (was 59.31%, +2.08 points)
**Total Tests**: 695 (was 675, +20 tests)
**Days Completed**: 1/10 (10%)
**Estimated Completion**: Day 10 (on track)

### Module Progress:
- ✅ **GraphQL Adapter**: 67.54% (was 1.75%, +65.79 points) - **Exceeds 70% target!**
- ⏳ **REST Adapter**: 1.92% (no change yet) - Day 3-4 target
- ⏳ **Adapter Protocol**: 42.86% (no change yet) - Day 5 target
- ⏳ **RBAC**: 42.57% (no change yet) - Day 6-7 target
- ⏳ **Enforcer**: 41.26% (no change yet) - Day 8-10 target

---

## Executive Summary

**Starting Coverage**: 59.31% (675 tests)
**Target Coverage**: 80%+ (est. 950+ tests needed)
**Priority Modules**:
1. Enforcer: 41.26% → 80% (+275 tests estimated)
2. RBAC: 42.57% → 80% (+150 tests estimated)
3. Adapter Protocol: 42.86% → 80% (+30 tests estimated)
4. ✅ GraphQL Adapter: 1.75% → 67.54% (40 tests completed - Day 1)
5. REST Adapter: 1.92% → 70% (+80 tests estimated)

**Total New Tests Needed**: ~600 tests over 2 weeks

---

## Module 1: GraphQL Adapter ✅ COMPLETED (Priority: HIGH)
**Starting**: 1.75% coverage (only config tests)
**Current**: 67.54% coverage (40 functional tests added)
**Target**: 70% coverage - **ACHIEVED AND EXCEEDED**
**Improvement**: +65.79 percentage points

### Completed Test Coverage (Day 1):

#### Core Adapter Functions ✅ ALL TESTED:
```elixir
✅ load_policy/2 - Load policies via GraphQL query (9 tests)
✅ load_filtered_policy/3 - Load with filter conditions (4 tests)
✅ load_incremental_filtered_policy/3 - Incremental loading (1 test)
✅ save_policy/3 - Save policies via mutation (5 tests)
✅ add_policy/4 - Add single policy via mutation (4 tests)
✅ remove_policy/4 - Remove single policy via mutation (4 tests)
✅ remove_filtered_policy/5 - Remove with filter (3 tests)
✅ filtered?/1 - Returns true (1 test)
✅ Configuration - All adapter options (10 tests)
```

**Total**: 40 tests covering success paths, error handling, edge cases, auth, and network failures

#### Advanced Features (NOT YET TESTED - Optional Day 2):
```elixir
⏳ introspect_schema/1 - GraphQL schema introspection
⏳ subscribe_policy_changes/1 - WebSocket subscriptions
⏳ validate_query/1 - Query validation
```

### ✅ Completed Implementation (Day 1):

**File**: `test/adapters/graphql_adapter_test.exs`
**Tests Created**: 40 functional tests
**Commit**: 19a4671

**Implementation Details**:
- Enhanced MockClient module with Agent-based state management
- Added `mock_response/1`, `mock_error/1` for flexible test mocking
- Added `last_headers/0`, `last_variables/0`, `last_timeout/0` for verification
- Proper setup/teardown for Agent lifecycle management

**Test Structure**:
```elixir
✅ describe "new/1 - adapter configuration" (10 tests)
✅ describe "load_policy/2 - loading policies" (9 tests)
✅ describe "load_filtered_policy/3 - filtered loading" (4 tests)
✅ describe "load_incremental_filtered_policy/3 - incremental loading" (1 test)
✅ describe "filtered?/1 - filter support" (1 test)
✅ describe "save_policy/3 - saving policies" (5 tests)
✅ describe "add_policy/4 - adding single policy" (4 tests)
✅ describe "remove_policy/4 - removing single policy" (4 tests)
✅ describe "remove_filtered_policy/5 - filtered removal" (3 tests)
```

**Quality Assurance**:
- ✅ All 40 tests passing
- ✅ `mix format` - clean
- ✅ `mix credo --strict` - no issues
- ✅ Coverage verified: 67.54%

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

- **Day 1**: GraphQL Adapter - Core functions (load, save, add, remove) - 40 tests ✅ **COMPLETED**
  - **Actual Results**: 40 tests created, coverage 1.75% → 67.54% (+65.79 points)
  - **Overall Impact**: Total tests 675 → 695 (+20), overall coverage 59.31% → 61.39% (+2.08 points)
  - **Status**: All tests passing, code formatted, credo clean
  - **Commit**: 19a4671 "feat: add comprehensive GraphQL adapter tests and improvement plan"
- **Day 2**: GraphQL Adapter - Advanced features (introspection, subscriptions) - 40 tests
- **Day 3**: REST Adapter - Core functions + auth - 40 tests
- **Day 4**: REST Adapter - Connection management + integration - 40 tests
- **Day 5**: Adapter Protocol tests - 30 tests

**Expected**: +190 tests, adapters at 70%+, protocol at 80%+
**Progress**: Day 1/5 complete, +20 tests so far

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
