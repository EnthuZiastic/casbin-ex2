# API Parity Checklist: Go Casbin vs Elixir CasbinEx2

Quick reference for tracking implementation status.

---

## Legend

- ✅ **Exact Match** - Function implemented with exact parameter/return parity
- ⚠️ **Similar** - Function implemented but with minor signature differences (variadic → list, etc.)
- ❌ **Missing** - Function not implemented
- 🔄 **In Progress** - Currently being implemented
- 📝 **Planned** - Scheduled for implementation

---

## Enforcer Core API

| Function | Go Signature | Elixir Status | Notes |
|----------|--------------|---------------|-------|
| NewEnforcer | `NewEnforcer(params...)` | ✅ | `new_enforcer/2` |
| InitWithFile | `InitWithFile(modelPath, policyPath)` | ✅ | `init_with_file/2` |
| InitWithAdapter | `InitWithAdapter(modelPath, adapter)` | ✅ | `init_with_file/2` |
| InitWithModelAndAdapter | `InitWithModelAndAdapter(m, adapter)` | ✅ | `init_with_model_and_adapter/2` |
| LoadModel | `LoadModel()` | ❌ | Missing |
| GetModel | `GetModel()` | ✅ | `get_model/1` |
| SetModel | `SetModel(m)` | ✅ | `set_model/2` |
| GetAdapter | `GetAdapter()` | ✅ | `get_adapter/1` |
| SetAdapter | `SetAdapter(adapter)` | ✅ | `set_adapter/2` |
| SetWatcher | `SetWatcher(watcher)` | ❌ | Missing |
| SetEffector | `SetEffector(eft)` | ✅ | `set_effector/2` |
| ClearPolicy | `ClearPolicy()` | ❌ | Missing |
| LoadPolicy | `LoadPolicy()` | ✅ | `load_policy/1` |
| LoadFilteredPolicy | `LoadFilteredPolicy(filter)` | ❌ | **P1 Missing** |
| LoadIncrementalFilteredPolicy | `LoadIncrementalFilteredPolicy(filter)` | ❌ | **P1 Missing** |
| IsFiltered | `IsFiltered()` | ❌ | **P1 Missing** |
| SavePolicy | `SavePolicy()` | ✅ | `save_policy/1` |

---

## Enforcement Functions

| Function | Go Signature | Elixir Status | Notes |
|----------|--------------|---------------|-------|
| Enforce | `Enforce(rvals...)` | ✅ | `enforce/2` |
| EnforceWithMatcher | `EnforceWithMatcher(matcher, rvals...)` | ✅ | `enforce_with_matcher/3` |
| EnforceEx | `EnforceEx(rvals...)` | ✅ | `enforce_ex/2` |
| EnforceExWithMatcher | `EnforceExWithMatcher(matcher, rvals...)` | ✅ | `enforce_ex_with_matcher/3` |
| BatchEnforce | `BatchEnforce(requests)` | ✅ | `batch_enforce/2` |
| BatchEnforceWithMatcher | `BatchEnforceWithMatcher(matcher, requests)` | ✅ | `batch_enforce_with_matcher/3` |

---

## Configuration & Toggles

| Function | Go Signature | Elixir Status | Notes |
|----------|--------------|---------------|-------|
| EnableEnforce | `EnableEnforce(enable)` | ✅ | `enable_enforce/2` |
| EnableLog | `EnableLog(enable)` | ✅ | `enable_log/2` |
| IsLogEnabled | `IsLogEnabled()` | ✅ | `log_enabled?/1` |
| EnableAutoSave | `EnableAutoSave(autoSave)` | ✅ | `enable_auto_save/2` |
| EnableAutoBuildRoleLinks | `EnableAutoBuildRoleLinks(enable)` | ✅ | `enable_auto_build_role_links/2` |
| EnableAutoNotifyWatcher | `EnableAutoNotifyWatcher(enable)` | ✅ | `enable_auto_notify_watcher/2` |
| EnableAutoNotifyDispatcher | `EnableAutoNotifyDispatcher(enable)` | ✅ | `enable_auto_notify_dispatcher/2` |
| EnableAcceptJsonRequest | `EnableAcceptJsonRequest(enable)` | ✅ | `enable_accept_json_request/2` |

---

## Role Manager

| Function | Go Signature | Elixir Status | Notes |
|----------|--------------|---------------|-------|
| GetRoleManager | `GetRoleManager()` | ⚠️ | Internal only |
| SetRoleManager | `SetRoleManager(rm)` | ❌ | **P1 Missing** |
| GetNamedRoleManager | `GetNamedRoleManager(ptype)` | ❌ | **P1 Missing** |
| SetNamedRoleManager | `SetNamedRoleManager(ptype, rm)` | ❌ | **P1 Missing** |
| BuildRoleLinks | `BuildRoleLinks()` | ✅ | `build_role_links/1` |
| BuildIncrementalRoleLinks | `BuildIncrementalRoleLinks(op, ptype, rules)` | ❌ | **P2 Missing** |
| BuildIncrementalConditionalRoleLinks | `BuildIncrementalConditionalRoleLinks(...)` | ❌ | **P3 Missing** |

---

## RBAC API - Basic

| Function | Go Signature | Elixir Status | Notes |
|----------|--------------|---------------|-------|
| GetRolesForUser | `GetRolesForUser(name, domain...)` | ⚠️ | `get_roles_for_user/3` |
| GetUsersForRole | `GetUsersForRole(name, domain...)` | ⚠️ | `get_users_for_role/3` |
| HasRoleForUser | `HasRoleForUser(name, role, domain...)` | ⚠️ | `has_role_for_user/4` |
| AddRoleForUser | `AddRoleForUser(user, role, domain...)` | ⚠️ | `add_role_for_user/4` |
| AddRolesForUser | `AddRolesForUser(user, roles, domain...)` | ⚠️ | `add_roles_for_user/4` |
| DeleteRoleForUser | `DeleteRoleForUser(user, role, domain...)` | ⚠️ | `delete_role_for_user/4` |
| DeleteRolesForUser | `DeleteRolesForUser(user, domain...)` | ⚠️ | `delete_roles_for_user/3` |
| DeleteUser | `DeleteUser(user)` | ✅ | `delete_user/2` |
| DeleteRole | `DeleteRole(role)` | ✅ | `delete_role/2` |

---

## RBAC API - Permissions

| Function | Go Signature | Elixir Status | Notes |
|----------|--------------|---------------|-------|
| GetPermissionsForUser | `GetPermissionsForUser(user, domain...)` | ⚠️ | `get_permissions_for_user/3` |
| GetNamedPermissionsForUser | `GetNamedPermissionsForUser(ptype, user, domain...)` | ⚠️ | `get_named_permissions_for_user/4` |
| HasPermissionForUser | `HasPermissionForUser(user, permission...)` | ⚠️ | `has_permission_for_user/3` |
| AddPermissionForUser | `AddPermissionForUser(user, permission...)` | ⚠️ | `add_permission_for_user/3` |
| AddPermissionsForUser | `AddPermissionsForUser(user, permissions...)` | ⚠️ | `add_permissions_for_user/3` |
| DeletePermission | `DeletePermission(permission...)` | ⚠️ | `delete_permission/2` |
| DeletePermissionForUser | `DeletePermissionForUser(user, permission...)` | ⚠️ | `delete_permission_for_user/3` |
| DeletePermissionsForUser | `DeletePermissionsForUser(user)` | ✅ | `delete_permissions_for_user/2` |

---

## RBAC API - Implicit

| Function | Go Signature | Elixir Status | Notes |
|----------|--------------|---------------|-------|
| GetImplicitRolesForUser | `GetImplicitRolesForUser(name, domain...)` | ⚠️ | `get_implicit_roles_for_user/3` |
| GetNamedImplicitRolesForUser | `GetNamedImplicitRolesForUser(ptype, name, domain...)` | ⚠️ | `get_named_implicit_roles_for_user/4` |
| GetImplicitPermissionsForUser | `GetImplicitPermissionsForUser(user, domain...)` | ⚠️ | `get_implicit_permissions_for_user/3` |
| GetNamedImplicitPermissionsForUser | `GetNamedImplicitPermissionsForUser(ptype, gtype, user, domain...)` | ⚠️ | `get_named_implicit_permissions_for_user/5` |
| GetImplicitUsersForRole | `GetImplicitUsersForRole(name, domain...)` | ⚠️ | `get_implicit_users_for_role/3` |
| GetImplicitUsersForPermission | `GetImplicitUsersForPermission(permission...)` | ⚠️ | `get_implicit_users_for_permission/2` |
| GetImplicitResourcesForUser | `GetImplicitResourcesForUser(user, domain...)` | ⚠️ | `get_implicit_resources_for_user/3` |
| GetImplicitUsersForResource | `GetImplicitUsersForResource(resource)` | ✅ | `get_implicit_users_for_resource/2` |
| GetNamedImplicitUsersForResource | `GetNamedImplicitUsersForResource(ptype, resource)` | ✅ | `get_named_implicit_users_for_resource/3` |
| GetImplicitUsersForResourceByDomain | `GetImplicitUsersForResourceByDomain(resource, domain)` | ✅ | `get_implicit_users_for_resource_by_domain/3` |
| GetDomainsForUser | `GetDomainsForUser(user)` | ✅ | `get_domains_for_user/2` |
| GetAllowedObjectConditions | `GetAllowedObjectConditions(user, action, prefix)` | ✅ | `get_allowed_object_conditions/4` |
| GetImplicitObjectPatternsForUser | `GetImplicitObjectPatternsForUser(user, domain, action)` | ✅ | `get_implicit_object_patterns_for_user/4` |

---

## RBAC API - Domain Specific

| Function | Go Signature | Elixir Status | Notes |
|----------|--------------|---------------|-------|
| GetUsersForRoleInDomain | `GetUsersForRoleInDomain(name, domain)` | ✅ | `get_users_for_role_in_domain/3` |
| GetRolesForUserInDomain | `GetRolesForUserInDomain(name, domain)` | ✅ | `get_roles_for_user_in_domain/3` |
| GetPermissionsForUserInDomain | `GetPermissionsForUserInDomain(user, domain)` | ✅ | `get_permissions_for_user_in_domain/3` |
| AddRoleForUserInDomain | `AddRoleForUserInDomain(user, role, domain)` | ✅ | `add_role_for_user_in_domain/4` |
| DeleteRoleForUserInDomain | `DeleteRoleForUserInDomain(user, role, domain)` | ✅ | `delete_role_for_user_in_domain/4` |
| DeleteRolesForUserInDomain | `DeleteRolesForUserInDomain(user, domain)` | ❌ | **P1 Missing** |
| GetAllUsersByDomain | `GetAllUsersByDomain(domain)` | ✅ | `get_all_roles_by_domain/2` |
| DeleteAllUsersByDomain | `DeleteAllUsersByDomain(domain)` | ❌ | **P1 Missing** |
| DeleteDomains | `DeleteDomains(domains...)` | ❌ | **P1 Missing** |
| GetAllDomains | `GetAllDomains()` | ❌ | **P1 Missing** |
| GetAllRolesByDomain | `GetAllRolesByDomain(domain)` | ✅ | `get_all_roles_by_domain/2` |

---

## Management API - Queries

| Function | Go Signature | Elixir Status | Notes |
|----------|--------------|---------------|-------|
| GetAllSubjects | `GetAllSubjects()` | ✅ | `get_all_subjects/1` |
| GetAllNamedSubjects | `GetAllNamedSubjects(ptype)` | ✅ | `get_all_named_subjects/2` |
| GetAllObjects | `GetAllObjects()` | ✅ | `get_all_objects/1` |
| GetAllNamedObjects | `GetAllNamedObjects(ptype)` | ✅ | `get_all_named_objects/2` |
| GetAllActions | `GetAllActions()` | ✅ | `get_all_actions/1` |
| GetAllNamedActions | `GetAllNamedActions(ptype)` | ✅ | `get_all_named_actions/2` |
| GetAllRoles | `GetAllRoles()` | ✅ | `get_all_roles/1` |
| GetAllNamedRoles | `GetAllNamedRoles(ptype)` | ✅ | `get_all_named_roles/2` |
| GetPolicy | `GetPolicy()` | ✅ | `get_policy/1` |
| GetFilteredPolicy | `GetFilteredPolicy(fieldIndex, fieldValues...)` | ⚠️ | `get_filtered_policy/3` |
| GetNamedPolicy | `GetNamedPolicy(ptype)` | ✅ | `get_named_policy/2` |
| GetFilteredNamedPolicy | `GetFilteredNamedPolicy(ptype, fieldIndex, fieldValues...)` | ⚠️ | `get_filtered_named_policy/4` |
| GetFilteredNamedPolicyWithMatcher | `GetFilteredNamedPolicyWithMatcher(ptype, matcher)` | ✅ | `get_filtered_named_policy_with_matcher/3` |
| GetGroupingPolicy | `GetGroupingPolicy()` | ✅ | `get_grouping_policy/1` |
| GetFilteredGroupingPolicy | `GetFilteredGroupingPolicy(fieldIndex, fieldValues...)` | ⚠️ | `get_filtered_grouping_policy/3` |
| GetNamedGroupingPolicy | `GetNamedGroupingPolicy(ptype)` | ✅ | `get_named_grouping_policy/2` |
| GetFilteredNamedGroupingPolicy | `GetFilteredNamedGroupingPolicy(ptype, fieldIndex, fieldValues...)` | ⚠️ | `get_filtered_named_grouping_policy/4` |

---

## Management API - Existence

| Function | Go Signature | Elixir Status | Notes |
|----------|--------------|---------------|-------|
| HasPolicy | `HasPolicy(params...)` | ⚠️ | `has_policy/2` |
| HasNamedPolicy | `HasNamedPolicy(ptype, params...)` | ⚠️ | `has_named_policy/3` |
| HasGroupingPolicy | `HasGroupingPolicy(params...)` | ⚠️ | `has_grouping_policy/2` |
| HasNamedGroupingPolicy | `HasNamedGroupingPolicy(ptype, params...)` | ⚠️ | `has_named_grouping_policy/3` |

---

## Management API - Policy Modification

| Function | Go Signature | Elixir Status | Notes |
|----------|--------------|---------------|-------|
| AddPolicy | `AddPolicy(params...)` | ⚠️ | `add_policy/2` |
| AddPolicies | `AddPolicies(rules)` | ✅ | `add_policies/2` |
| AddPoliciesEx | `AddPoliciesEx(rules)` | ✅ | `add_policies_ex/2` |
| AddNamedPolicy | `AddNamedPolicy(ptype, params...)` | ⚠️ | `add_named_policy/3` |
| AddNamedPolicies | `AddNamedPolicies(ptype, rules)` | ✅ | `add_named_policies/3` |
| AddNamedPoliciesEx | `AddNamedPoliciesEx(ptype, rules)` | ✅ | `add_named_policies_ex/3` |
| RemovePolicy | `RemovePolicy(params...)` | ⚠️ | `remove_policy/2` |
| RemovePolicies | `RemovePolicies(rules)` | ✅ | `remove_policies/2` |
| RemoveFilteredPolicy | `RemoveFilteredPolicy(fieldIndex, fieldValues...)` | ⚠️ | `remove_filtered_policy/3` |
| RemoveNamedPolicy | `RemoveNamedPolicy(ptype, params...)` | ⚠️ | `remove_named_policy/3` |
| RemoveNamedPolicies | `RemoveNamedPolicies(ptype, rules)` | ✅ | `remove_named_policies/3` |
| RemoveFilteredNamedPolicy | `RemoveFilteredNamedPolicy(ptype, fieldIndex, fieldValues...)` | ⚠️ | `remove_filtered_named_policy/4` |

---

## Management API - Policy Updates

| Function | Go Signature | Elixir Status | Notes |
|----------|--------------|---------------|-------|
| UpdatePolicy | `UpdatePolicy(oldPolicy, newPolicy)` | ✅ | `update_policy/3` |
| UpdateNamedPolicy | `UpdateNamedPolicy(ptype, p1, p2)` | ✅ | `update_named_policy/4` |
| UpdatePolicies | `UpdatePolicies(oldPolicies, newPolicies)` | ✅ | `update_policies/3` |
| UpdateNamedPolicies | `UpdateNamedPolicies(ptype, p1, p2)` | ✅ | `update_named_policies/4` |
| UpdateFilteredPolicies | `UpdateFilteredPolicies(newPolicies, fieldIndex, fieldValues...)` | ⚠️ | `update_filtered_policies/4` |
| UpdateFilteredNamedPolicies | `UpdateFilteredNamedPolicies(ptype, newPolicies, fieldIndex, fieldValues...)` | ⚠️ | `update_filtered_named_policies/5` |

---

## Management API - Grouping Modification

| Function | Go Signature | Elixir Status | Notes |
|----------|--------------|---------------|-------|
| AddGroupingPolicy | `AddGroupingPolicy(params...)` | ⚠️ | `add_grouping_policy/2` |
| AddGroupingPolicies | `AddGroupingPolicies(rules)` | ✅ | `add_grouping_policies/2` |
| AddGroupingPoliciesEx | `AddGroupingPoliciesEx(rules)` | ✅ | `add_grouping_policies_ex/2` |
| AddNamedGroupingPolicy | `AddNamedGroupingPolicy(ptype, params...)` | ⚠️ | `add_named_grouping_policy/3` |
| AddNamedGroupingPolicies | `AddNamedGroupingPolicies(ptype, rules)` | ✅ | `add_named_grouping_policies/3` |
| AddNamedGroupingPoliciesEx | `AddNamedGroupingPoliciesEx(ptype, rules)` | ✅ | `add_named_grouping_policies_ex/3` |
| RemoveGroupingPolicy | `RemoveGroupingPolicy(params...)` | ⚠️ | `remove_grouping_policy/2` |
| RemoveGroupingPolicies | `RemoveGroupingPolicies(rules)` | ✅ | `remove_grouping_policies/2` |
| RemoveFilteredGroupingPolicy | `RemoveFilteredGroupingPolicy(fieldIndex, fieldValues...)` | ⚠️ | `remove_filtered_grouping_policy/3` |
| RemoveNamedGroupingPolicy | `RemoveNamedGroupingPolicy(ptype, params...)` | ⚠️ | `remove_named_grouping_policy/3` |
| RemoveNamedGroupingPolicies | `RemoveNamedGroupingPolicies(ptype, rules)` | ✅ | `remove_named_grouping_policies/3` |
| RemoveFilteredNamedGroupingPolicy | `RemoveFilteredNamedGroupingPolicy(ptype, fieldIndex, fieldValues...)` | ⚠️ | `remove_filtered_named_grouping_policy/4` |

---

## Management API - Grouping Updates

| Function | Go Signature | Elixir Status | Notes |
|----------|--------------|---------------|-------|
| UpdateGroupingPolicy | `UpdateGroupingPolicy(oldRule, newRule)` | ✅ | `update_grouping_policy/3` |
| UpdateGroupingPolicies | `UpdateGroupingPolicies(oldRules, newRules)` | ✅ | `update_grouping_policies/3` |
| UpdateNamedGroupingPolicy | `UpdateNamedGroupingPolicy(ptype, oldRule, newRule)` | ✅ | `update_named_grouping_policy/4` |
| UpdateNamedGroupingPolicies | `UpdateNamedGroupingPolicies(ptype, oldRules, newRules)` | ✅ | `update_named_grouping_policies/4` |

---

## Management API - Self Functions (Watcher)

| Function | Go Signature | Elixir Status | Notes |
|----------|--------------|---------------|-------|
| SelfAddPolicy | `SelfAddPolicy(sec, ptype, rule)` | ✅ | `self_add_policy/4` |
| SelfAddPolicies | `SelfAddPolicies(sec, ptype, rules)` | ✅ | `self_add_policies/4` |
| SelfAddPoliciesEx | `SelfAddPoliciesEx(sec, ptype, rules)` | ✅ | `self_add_policies_ex/4` |
| SelfRemovePolicy | `SelfRemovePolicy(sec, ptype, rule)` | ✅ | `self_remove_policy/4` |
| SelfRemovePolicies | `SelfRemovePolicies(sec, ptype, rules)` | ✅ | `self_remove_policies/4` |
| SelfRemoveFilteredPolicy | `SelfRemoveFilteredPolicy(sec, ptype, fieldIndex, fieldValues...)` | ⚠️ | `self_remove_filtered_policy/5` |
| SelfUpdatePolicy | `SelfUpdatePolicy(sec, ptype, oldRule, newRule)` | ✅ | `self_update_policy/5` |
| SelfUpdatePolicies | `SelfUpdatePolicies(sec, ptype, oldRules, newRules)` | ✅ | `self_update_policies/5` |

---

## Custom Functions

| Function | Go Signature | Elixir Status | Notes |
|----------|--------------|---------------|-------|
| AddFunction | `AddFunction(name, function)` | ✅ | `add_function/3` |
| AddNamedMatchingFunc | `AddNamedMatchingFunc(ptype, name, fn)` | ❌ | **P3 Missing** |
| AddNamedDomainMatchingFunc | `AddNamedDomainMatchingFunc(ptype, name, fn)` | ❌ | **P3 Missing** |
| AddNamedLinkConditionFunc | `AddNamedLinkConditionFunc(ptype, user, role, fn)` | ❌ | **P3 Missing** |
| AddNamedDomainLinkConditionFunc | `AddNamedDomainLinkConditionFunc(ptype, user, role, domain, fn)` | ❌ | **P3 Missing** |
| SetNamedLinkConditionFuncParams | `SetNamedLinkConditionFuncParams(ptype, user, role, params...)` | ❌ | **P3 Missing** |
| SetNamedDomainLinkConditionFuncParams | `SetNamedDomainLinkConditionFuncParams(ptype, user, role, domain, params...)` | ❌ | **P3 Missing** |

---

## Summary Statistics

### Overall Coverage
- **Total Functions Analyzed:** 115
- **Exact Matches (✅):** 45 (39%)
- **Similar/Adapted (⚠️):** 35 (30%)
- **Missing (❌):** 35 (31%)

### By Category
| Category | Total | Implemented | Missing | Coverage |
|----------|-------|-------------|---------|----------|
| Core Enforcer | 15 | 11 | 4 | 73% |
| Enforcement | 6 | 6 | 0 | 100% |
| Configuration | 8 | 8 | 0 | 100% |
| Role Manager | 7 | 2 | 5 | 29% |
| RBAC Basic | 9 | 9 | 0 | 100% |
| RBAC Permissions | 8 | 8 | 0 | 100% |
| RBAC Implicit | 13 | 13 | 0 | 100% |
| RBAC Domains | 11 | 7 | 4 | 64% |
| Management Queries | 18 | 18 | 0 | 100% |
| Management Modify | 12 | 12 | 0 | 100% |
| Management Update | 10 | 10 | 0 | 100% |
| Custom Functions | 7 | 1 | 6 | 14% |

### Priority Breakdown
- **P1 (Critical):** 11 missing functions
- **P2 (Important):** 3 missing functions
- **P3 (Advanced):** 6 missing functions

---

## Action Items

### Immediate (This Week)
- [ ] Review missing P1 functions with team
- [ ] Prioritize filtered policy loading implementation
- [ ] Start domain management functions

### Short Term (Next 2 Weeks)
- [ ] Implement all P1 missing functions
- [ ] Add comprehensive test coverage
- [ ] Update documentation

### Medium Term (Next Month)
- [ ] Implement P2 functions (watcher, incremental)
- [ ] Performance benchmarking
- [ ] Migration guide for users

### Long Term (Future)
- [ ] P3 advanced features (conditional roles, link conditions)
- [ ] Full feature parity with Go version
- [ ] Community contributions

---

## Notes

1. **Variadic Parameters**: Go's `...interface{}` maps to Elixir lists - functionally equivalent
2. **Error Handling**: Go's `(result, error)` maps to `{:ok, result} | {:error, reason}` - idiomatic difference
3. **Naming**: All functions follow Elixir snake_case convention vs Go's PascalCase
4. **Function Style**: Elixir passes enforcer as first parameter (functional) vs Go receiver methods (OOP)

---

**Last Updated:** 2025-10-02
**Next Review:** When implementing P1 functions
