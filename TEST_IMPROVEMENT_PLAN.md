# Test Coverage Improvement Plan
**Created**: October 1, 2025
**Last Updated**: October 1, 2025
**Target**: Increase coverage from 59.31% to 80%+ in 2 weeks

## 📊 Current Progress

**Overall Coverage**: 65.90% (was 59.31%, +6.59 points)
**Total Tests**: 887 (was 675, +212 tests)
**Days Completed**: 6/10 (60%)
**Estimated Completion**: Day 10 (on track)

### Module Progress:
- ✅ **GraphQL Adapter**: 85.09% (was 1.75%, +83.34 points) - **Exceeds 85% target!**
- ✅ **REST Adapter**: 89.42% (was 1.92%, +87.50 points) - **Exceeds 70% target!**
- ✅ **Adapter Protocol**: 100.00% (was 42.86%, +57.14 points) - **Perfect 100% coverage!**
- ✅ **RBAC**: 72.41% (was 42.57%, +29.84 points) - **Day 6 role management complete!**
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
**Current**: 85.09% coverage (60 functional tests added)
**Target**: 70% coverage - **ACHIEVED AND EXCEEDED**
**Improvement**: +83.34 percentage points

### Completed Test Coverage (Day 1 + Day 2):

#### Core Adapter Functions ✅ ALL TESTED (Day 1):
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

**Day 1 Total**: 40 tests covering success paths, error handling, edge cases, auth, and network failures

#### Advanced Features ✅ ALL TESTED (Day 2):
```elixir
✅ introspect_schema/1 - GraphQL schema introspection (5 tests)
✅ subscribe_policy_changes/1 - WebSocket subscriptions (4 tests)
✅ validate_query/1 - Query validation (8 tests)
✅ new_mock/1 - Mock adapter creation (3 tests)
```

**Day 2 Total**: 20 tests covering introspection, subscriptions, query validation, and mock utilities
**Grand Total**: 60 tests with 85.09% coverage

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
- ✅ All 60 tests passing
- ✅ `mix format` - clean
- ✅ `mix credo --strict` - no issues
- ✅ Coverage verified: 85.09%

### ✅ Completed Implementation (Day 2):

**File**: `test/adapters/graphql_adapter_test.exs`
**Tests Created**: 20 advanced feature tests
**Commit**: c119944

**Implementation Details**:
- Added `introspect_schema/1` tests with schema validation
- Added `subscribe_policy_changes/1` tests for WebSocket subscriptions
- Added `validate_query/1` tests for query validation
- Added `new_mock/1` tests for mock adapter creation
- All tests use existing MockClient infrastructure

**Test Structure**:
```elixir
✅ describe "introspect_schema/1 - schema introspection" (5 tests)
✅ describe "subscribe_policy_changes/1 - WebSocket subscriptions" (4 tests)
✅ describe "validate_query/1 - query validation" (8 tests)
✅ describe "new_mock/1 - mock adapter creation" (3 tests)
```

---

## Module 2: REST Adapter ✅ COMPLETED (Priority: HIGH)
**Starting**: 1.92% coverage (only config tests)
**Current**: 89.42% coverage (71 functional tests added)
**Target**: 70% coverage - **ACHIEVED AND EXCEEDED**
**Improvement**: +87.50 percentage points

### ✅ Completed Test Coverage (Day 3 + Day 4):

#### Core Adapter Functions + Authentication ✅ TESTED:
```elixir
✅ load_policy/2 - GET /policies (9 tests)
✅ load_filtered_policy/3 - Filtered loading (3 tests)
✅ save_policy/3 - POST /policies (4 tests)
✅ add_policy/4 - POST /policies/add (3 tests)
✅ remove_policy/4 - DELETE /policies/remove (3 tests)
✅ remove_filtered_policy/5 - DELETE with filter (2 tests)
✅ filtered?/1 - Returns true (1 test)
✅ test_connection/1 - Health check (3 tests)
✅ get_config/1 - Configuration summary (2 tests)
✅ Authentication - Bearer token (2 tests)
✅ Authentication - Basic auth (2 tests)
✅ Authentication - API key (1 test)
✅ Authentication - Custom headers (1 test)
✅ new_mock/1 - Mock adapter (2 tests)
```

**Day 3 Total**: 37 tests covering core operations, authentication, error handling
**Day 4 Total**: 34 tests covering connection management, retry logic, timeouts, pooling
**Grand Total**: 90 tests (19 config + 71 functional)

### ✅ Completed Implementation (Day 3):

**File**: `test/adapters/rest_adapter_test.exs`
**Tests Created**: 37 functional tests
**Commit**: a617ddb

**Implementation Details**:
- Enhanced MockClient with Agent-based state management
- Added `mock_response/1`, `mock_error/1` for flexible test mocking
- Comprehensive HTTP error handling (404, 401, 500, 503, timeout, connection refused)
- All authentication types tested (bearer, basic, API key, custom)
- Proper setup/teardown with try/catch for Agent lifecycle

**Test Structure**:
```elixir
✅ describe "load_policy/2 - loading policies via REST API" (9 tests)
✅ describe "load_filtered_policy/3 - filtered policy loading" (3 tests)
✅ describe "save_policy/3 - saving policies via REST API" (4 tests)
✅ describe "add_policy/4 - adding single policy" (3 tests)
✅ describe "remove_policy/4 - removing single policy" (3 tests)
✅ describe "remove_filtered_policy/5 - removing policies with filter" (2 tests)
✅ describe "filtered?/1 - filter support" (1 test)
✅ describe "test_connection/1 - connection health check" (3 tests)
✅ describe "get_config/1 - adapter configuration" (2 tests)
✅ describe "authentication - bearer token" (2 tests)
✅ describe "authentication - basic auth" (2 tests)
✅ describe "authentication - API key" (1 test)
✅ describe "authentication - custom headers" (1 test)
✅ describe "new_mock/1 - mock adapter creation" (2 tests)
```

**Quality Assurance**:
- ✅ All 56 tests passing
- ✅ `mix format` - clean
- ✅ `mix credo --strict` - no issues
- ✅ Overall project tests: 752, all passing

### ✅ Completed Implementation (Day 4):

**File**: `test/adapters/rest_adapter_test.exs`
**Tests Created**: 34 connection management tests
**Commit**: 2a3f6ce

**Implementation Details**:
- Retry logic with exponential backoff tests
- Timeout and connection pooling configuration tests
- Circuit breaker pattern tests
- URL and path handling tests
- Header management and error response tests
- Concurrent operations tests
- load_incremental_filtered_policy/3 tests
- Edge cases and configuration validation
- Fixed Agent lifecycle issues in GraphQL and distributed enforcer tests

**Test Structure**:
```elixir
✅ describe "retry logic with exponential backoff" (5 tests)
✅ describe "timeout configuration" (3 tests)
✅ describe "connection pooling configuration" (3 tests)
✅ describe "circuit breaker configuration" (3 tests)
✅ describe "URL and path handling" (3 tests)
✅ describe "header management" (4 tests)
✅ describe "error response handling" (3 tests)
✅ describe "concurrent operations" (2 tests)
✅ describe "load_incremental_filtered_policy/3" (2 tests)
✅ describe "edge cases and error recovery" (4 tests)
✅ describe "configuration validation" (2 tests)
```

**Quality Assurance**:
- ✅ All 90 REST adapter tests passing
- ✅ All 786 project tests passing
- ✅ `mix format` - clean
- ✅ `mix credo --strict` - no issues
- ✅ REST Adapter coverage: 89.42%
- ✅ Overall coverage: 64.07%

---

## Module 3: Adapter Protocol ✅ COMPLETED (Priority: MEDIUM)
**Starting**: 42.86% coverage
**Current**: 100.00% coverage (40 tests added)
**Target**: 80% coverage - **ACHIEVED AND EXCEEDED - Perfect 100%!**
**Improvement**: +57.14 percentage points

### ✅ Completed Test Coverage (Day 5):

#### Adapter Protocol Dispatch ✅ ALL TESTED:
```elixir
✅ Protocol dispatch with MemoryAdapter (5 tests)
✅ Protocol dispatch with FileAdapter (5 tests)
✅ Protocol dispatch with StringAdapter (5 tests)
✅ Protocol dispatch with BatchAdapter (5 tests)
✅ load_filtered_policy/3 dispatch (4 tests)
✅ load_incremental_filtered_policy/3 dispatch (4 tests)
✅ Adapter struct access (4 tests)
✅ Adapter immutability (2 tests)
✅ Error handling (2 tests)
✅ Adapter polymorphism (2 tests)
✅ Adapter capabilities (2 tests)
```

**Day 5 Total**: 40 tests covering all adapter protocol dispatch mechanisms
**Grand Total**: 40 tests with 100% coverage

### ✅ Completed Implementation (Day 5):

**File**: `test/casbin_ex2/adapter_test.exs`
**Tests Created**: 40 protocol dispatch tests
**Commit**: edaf8d7

**Implementation Details**:
- Comprehensive protocol dispatch testing for all adapter types
- Tests verify correct delegation to adapter implementations
- Tests ensure adapters can be used polymorphically
- Tests verify adapter struct access and immutability patterns
- Tests cover filtered and incremental policy loading
- Tests validate error handling and propagation

**Test Structure**:
```elixir
✅ describe "protocol dispatch with MemoryAdapter" (5 tests)
✅ describe "protocol dispatch with FileAdapter" (5 tests)
✅ describe "protocol dispatch with StringAdapter" (5 tests)
✅ describe "protocol dispatch with BatchAdapter" (5 tests)
✅ describe "load_filtered_policy/3 dispatch" (4 tests)
✅ describe "load_incremental_filtered_policy/3 dispatch" (4 tests)
✅ describe "adapter struct access" (4 tests)
✅ describe "adapter immutability" (2 tests)
✅ describe "error handling" (2 tests)
✅ describe "adapter polymorphism" (2 tests)
✅ describe "adapter capabilities" (2 tests)
```

**Quality Assurance**:
- ✅ All 40 tests passing
- ✅ `mix format` - clean
- ✅ `mix credo --strict` - no issues
- ✅ Adapter Protocol coverage: 100%
- ✅ Overall coverage: 64.41%

**Side Benefits**:
- FileAdapter: +12.20 points (65.85% → 78.05%)
- StringAdapter: +0.72 points (87.77% → 88.49%)
- MemoryAdapter: +1.48 points (86.67% → 88.15%)
- BatchAdapter: +1.62 points (72.36% → 73.98%)

---

## Module 4: RBAC Module ⚡ IN PROGRESS (Priority: CRITICAL)
**Starting**: 42.57% coverage
**Current**: 72.41% coverage (61 role tests added - Day 6)
**Target**: 80% coverage
**Improvement**: +29.84 percentage points

### ✅ Completed Test Coverage (Day 6):

#### RBAC Role Management ✅ ALL TESTED:
```elixir
✅ get_roles_for_user/2-3 - Direct and domain-specific role retrieval (8 tests)
✅ get_users_for_role/2-3 - User-to-role mapping queries (6 tests)
✅ has_role_for_user/3-4 - Role membership checks (6 tests)
✅ add_role_for_user/3-4 - Single role assignment (8 tests)
✅ add_roles_for_user/3-4 - Bulk role assignment (4 tests)
✅ delete_role_for_user/3-4 - Single role removal (6 tests)
✅ delete_roles_for_user/2-3 - Bulk role removal (4 tests)
✅ delete_user/2 - Complete user deletion (4 tests)
✅ delete_role/2 - Complete role deletion (4 tests)
✅ get_implicit_roles_for_user/2-3 - Role inheritance (3 tests)
✅ Domain-specific operations - Cross-domain role management (6 tests)
✅ Edge cases - Empty strings, special characters, unicode (5 tests)
```

**Day 6 Total**: 61 tests covering all role management operations
**Remaining**: Permission management tests (Day 7)

### ✅ Completed Implementation (Day 6):

**File**: `test/rbac/rbac_role_test.exs`
**Tests Created**: 61 comprehensive role management tests
**Commit**: 3055dd5

**Implementation Details**:
- Comprehensive role assignment and removal operations
- Domain-specific role management across multiple tenants
- Role hierarchy and implicit role resolution
- Complete user and role deletion with cascade cleanup
- Edge case handling: empty strings, special characters, unicode

**Bug Fixes Applied**:
- Fixed RoleManager.get_roles/3 return type handling (was expecting {:ok, roles}, now handles list directly)
- Fixed RoleManager.get_users/3 return type handling (same issue)
- Fixed remove_named_grouping_policy to update role_manager on deletion (was only updating grouping_policies)

**Test Structure**:
```elixir
✅ describe "get_roles_for_user/2" (4 tests)
✅ describe "get_roles_for_user/3 with domain" (2 tests)
✅ describe "get_users_for_role/2" (4 tests)
✅ describe "get_users_for_role/3 with domain" (2 tests)
✅ describe "has_role_for_user/3" (3 tests)
✅ describe "has_role_for_user/4 with domain" (2 tests)
✅ describe "add_role_for_user/3" (4 tests)
✅ describe "add_role_for_user/4 with domain" (2 tests)
✅ describe "add_roles_for_user/3" (3 tests)
✅ describe "add_roles_for_user/4 with domain" (1 test)
✅ describe "delete_role_for_user/3" (3 tests)
✅ describe "delete_role_for_user/4 with domain" (2 tests)
✅ describe "delete_roles_for_user/2" (3 tests)
✅ describe "delete_roles_for_user/3 with domain" (1 test)
✅ describe "delete_user/2" (4 tests)
✅ describe "delete_role/2" (4 tests)
✅ describe "get_implicit_roles_for_user/2" (4 tests)
✅ describe "get_implicit_roles_for_user/3 with domain" (1 test)
✅ describe "get_users_for_role_in_domain/3" (2 tests)
✅ describe "get_roles_for_user_in_domain/3" (2 tests)
✅ describe "add_role_for_user_in_domain/4" (2 tests)
✅ describe "delete_role_for_user_in_domain/4" (2 tests)
✅ describe "edge cases and error handling" (5 tests)
```

**Quality Assurance**:
- ✅ All 61 tests passing
- ✅ All 887 project tests passing
- ✅ `mix format` - clean
- ✅ `mix credo --strict` - no issues
- ✅ RBAC coverage: 72.41%
- ✅ Overall coverage: 65.90%

---

## Module 4 (continued): RBAC Permission Management ⏳ PENDING (Priority: CRITICAL)
**Current**: 72.41% coverage (after Day 6)
**Target**: 80% coverage
**Gap**: Need permission management tests (Day 7)

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
- **Day 2**: GraphQL Adapter - Advanced features (introspection, subscriptions, validation) - 20 tests ✅ **COMPLETED**
  - **Actual Results**: 20 tests created, coverage 67.54% → 85.09% (+17.55 points)
  - **Overall Impact**: Total tests 695 → 715 (+20), overall coverage 61.39% → 61.87% (+0.48 points)
  - **Status**: All 60 GraphQL tests passing, exceeds 85% target
  - **Commit**: c119944 "feat: add GraphQL adapter advanced features tests (Day 2)"
- **Day 3**: REST Adapter - Core functions + auth - 37 tests ✅ **COMPLETED**
  - **Actual Results**: 37 tests created (load, save, add, remove, filters, auth, connection)
  - **Overall Impact**: Total tests 715 → 752 (+37), overall coverage 61.87% → 63.74% (+1.87 points)
  - **Status**: All 56 REST tests passing (19 config + 37 functional), all 752 project tests passing
  - **Commit**: a617ddb "feat: add comprehensive REST adapter tests (Day 3)"
- **Day 4**: REST Adapter - Connection management - 34 tests ✅ **COMPLETED**
  - **Actual Results**: 34 tests created (retry logic, timeouts, pooling, circuit breaker, concurrent ops)
  - **Overall Impact**: Total tests 752 → 786 (+34), overall coverage 63.74% → 64.07% (+0.33 points)
  - **Status**: All 90 REST tests passing, REST adapter 89.42% coverage (exceeds 70% target)
  - **Bonus**: Fixed Agent lifecycle issues in GraphQL and distributed enforcer tests
  - **Commit**: 2a3f6ce "feat: add REST adapter connection management tests (Day 4)"
- **Day 5**: Adapter Protocol tests - 40 tests ✅ **COMPLETED**
  - **Actual Results**: 40 tests created (protocol dispatch for all adapter types)
  - **Overall Impact**: Total tests 786 → 826 (+40), overall coverage 64.07% → 64.41% (+0.34 points)
  - **Status**: All 40 protocol tests passing, Adapter protocol 100% coverage (perfect!)
  - **Side Benefits**: FileAdapter +12.20, StringAdapter +0.72, MemoryAdapter +1.48, BatchAdapter +1.62
  - **Commit**: edaf8d7 "feat: add comprehensive Adapter protocol tests (Day 5)"

**Expected**: +190 tests, adapters at 70%+, protocol at 80%+
**Progress**: Days 1-5/5 complete, +151 tests achieved
  - GraphQL Adapter: 85.09% (exceeds 85% target)
  - REST Adapter: 89.42% (exceeds 70% target)
  - Adapter Protocol: 100.00% (exceeds 80% target - perfect score!)

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
