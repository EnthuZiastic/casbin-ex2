defmodule CasbinEx2 do
  @moduledoc """
  CasbinEx2 is an Elixir implementation of the Casbin authorization library.

  Casbin is a powerful and efficient open-source access control library.
  It provides support for enforcing authorization based on various access control models.

  ## Features

  - Multiple built-in models: ACL, RBAC, ABAC
  - Support for multiple adapters (File, Ecto SQL)
  - Process-based enforcement with GenServer
  - Cached enforcement for better performance
  - Synchronized enforcement for thread safety
  - Dynamic supervisor for managing enforcer processes

  ## Basic Usage

      # Start an enforcer
      {:ok, _pid} = CasbinEx2.start_enforcer(:my_enforcer, "path/to/model.conf")

      # Add a policy
      CasbinEx2.add_policy(:my_enforcer, ["alice", "data1", "read"])

      # Check permissions
      CasbinEx2.enforce(:my_enforcer, ["alice", "data1", "read"])  # true

  """

  alias CasbinEx2.EnforcerServer
  alias CasbinEx2.EnforcerSupervisor

  @doc """
  Starts a new enforcer process.
  """
  def start_enforcer(name, model_path, opts \\ []) do
    EnforcerSupervisor.start_enforcer(name, model_path, opts)
  end

  @doc """
  Stops an enforcer process.
  """
  def stop_enforcer(name) do
    EnforcerSupervisor.stop_enforcer(name)
  end

  @doc """
  Performs authorization enforcement.
  """
  def enforce(name, request) do
    EnforcerServer.enforce(name, request)
  end

  @doc """
  Performs authorization enforcement with explanations.
  Returns {allowed, explanations}.
  """
  def enforce_ex(name, request) do
    EnforcerServer.enforce_ex(name, request)
  end

  @doc """
  Performs authorization enforcement with custom matcher.
  """
  def enforce_with_matcher(name, matcher, request) do
    EnforcerServer.enforce_with_matcher(name, matcher, request)
  end

  @doc """
  Performs authorization enforcement with custom matcher and explanations.
  """
  def enforce_ex_with_matcher(name, matcher, request) do
    EnforcerServer.enforce_ex_with_matcher(name, matcher, request)
  end

  @doc """
  Performs batch enforcement for multiple requests.
  """
  def batch_enforce(name, requests) do
    EnforcerServer.batch_enforce(name, requests)
  end

  @doc """
  Performs batch enforcement with explanations.
  """
  def batch_enforce_ex(name, requests) do
    EnforcerServer.batch_enforce_ex(name, requests)
  end

  @doc """
  Performs batch enforcement with custom matcher.
  """
  def batch_enforce_with_matcher(name, matcher, requests) do
    EnforcerServer.batch_enforce_with_matcher(name, matcher, requests)
  end

  @doc """
  Adds a policy rule.
  """
  def add_policy(name, params) do
    EnforcerServer.add_policy(name, params)
  end

  @doc """
  Removes a policy rule.
  """
  def remove_policy(name, params) do
    EnforcerServer.remove_policy(name, params)
  end

  @doc """
  Gets all policy rules.
  """
  def get_policy(name) do
    EnforcerServer.get_policy(name)
  end

  @doc """
  Checks if a policy rule exists.
  """
  def has_policy(name, params) do
    EnforcerServer.has_policy(name, params)
  end

  @doc """
  Adds a role for a user.
  """
  def add_role_for_user(name, user, role, domain \\ "") do
    EnforcerServer.add_role_for_user(name, user, role, domain)
  end

  @doc """
  Deletes a role for a user.
  """
  def delete_role_for_user(name, user, role, domain \\ "") do
    EnforcerServer.delete_role_for_user(name, user, role, domain)
  end

  @doc """
  Gets all roles for a user.
  """
  def get_roles_for_user(name, user, domain \\ "") do
    EnforcerServer.get_roles_for_user(name, user, domain)
  end

  @doc """
  Gets all users for a role.
  """
  def get_users_for_role(name, role, domain \\ "") do
    EnforcerServer.get_users_for_role(name, role, domain)
  end

  @doc """
  Checks if a user has a role.
  """
  def has_role_for_user(name, user, role, domain \\ "") do
    EnforcerServer.has_role_for_user(name, user, role, domain)
  end

  @doc """
  Gets permissions for a user.
  """
  def get_permissions_for_user(name, user, domain \\ "") do
    EnforcerServer.get_permissions_for_user(name, user, domain)
  end

  @doc """
  Adds a permission for a user.
  """
  def add_permission_for_user(name, user, permission) do
    EnforcerServer.add_permission_for_user(name, user, permission)
  end

  @doc """
  Deletes a permission for a user.
  """
  def delete_permission_for_user(name, user, permission) do
    EnforcerServer.delete_permission_for_user(name, user, permission)
  end

  @doc """
  Gets implicit permissions for a user (includes permissions through roles).
  """
  def get_implicit_permissions_for_user(name, user, domain \\ "") do
    EnforcerServer.get_implicit_permissions_for_user(name, user, domain)
  end

  @doc """
  Gets implicit roles for a user (includes inherited roles).
  """
  def get_implicit_roles_for_user(name, user, domain \\ "") do
    EnforcerServer.get_implicit_roles_for_user(name, user, domain)
  end

  @doc """
  Checks if a user has a specific permission.
  """
  def has_permission_for_user(name, user, permission) do
    EnforcerServer.has_permission_for_user(name, user, permission)
  end

  @doc """
  Loads policy from the adapter.
  """
  def load_policy(name) do
    EnforcerServer.load_policy(name)
  end

  @doc """
  Saves policy to the adapter.
  """
  def save_policy(name) do
    EnforcerServer.save_policy(name)
  end

  #
  # Management APIs
  #

  @doc """
  Gets all subjects that show up in policies.
  """
  def get_all_subjects(name) do
    EnforcerServer.get_all_subjects(name)
  end

  @doc """
  Gets all objects that show up in policies.
  """
  def get_all_objects(name) do
    EnforcerServer.get_all_objects(name)
  end

  @doc """
  Gets all actions that show up in policies.
  """
  def get_all_actions(name) do
    EnforcerServer.get_all_actions(name)
  end

  @doc """
  Gets all roles that show up in grouping policies.
  """
  def get_all_roles(name) do
    EnforcerServer.get_all_roles(name)
  end

  @doc """
  Gets all domains from policies and grouping policies.
  """
  def get_all_domains(name) do
    EnforcerServer.get_all_domains(name)
  end

  @doc """
  Updates a policy rule.
  """
  def update_policy(name, old_policy, new_policy) do
    EnforcerServer.update_policy(name, old_policy, new_policy)
  end

  @doc """
  Updates multiple policy rules.
  """
  def update_policies(name, old_policies, new_policies) do
    EnforcerServer.update_policies(name, old_policies, new_policies)
  end

  @doc """
  Updates a grouping policy rule.
  """
  def update_grouping_policy(name, old_rule, new_rule) do
    EnforcerServer.update_grouping_policy(name, old_rule, new_rule)
  end

  @doc """
  Updates multiple grouping policy rules.
  """
  def update_grouping_policies(name, old_rules, new_rules) do
    EnforcerServer.update_grouping_policies(name, old_rules, new_rules)
  end

  #
  # Complete RBAC API
  #

  @doc """
  Completely removes a user (removes user from all policies and grouping policies).
  """
  def delete_user(name, user) do
    EnforcerServer.delete_user(name, user)
  end

  @doc """
  Completely removes a role (removes role from all grouping policies).
  """
  def delete_role(name, role) do
    EnforcerServer.delete_role(name, role)
  end

  @doc """
  Removes a permission (removes permission from all policies).
  """
  def delete_permission(name, permission) do
    EnforcerServer.delete_permission(name, permission)
  end

  @doc """
  Gets all users who have the specified permission.
  """
  def get_users_for_permission(name, permission) do
    EnforcerServer.get_users_for_permission(name, permission)
  end

  @doc """
  Adds multiple roles for a user in one operation.
  """
  def add_roles_for_user(name, user, roles, domain \\ "") do
    EnforcerServer.add_roles_for_user(name, user, roles, domain)
  end

  @doc """
  Adds multiple permissions for a user in one operation.
  """
  def add_permissions_for_user(name, user, permissions) do
    EnforcerServer.add_permissions_for_user(name, user, permissions)
  end

  @doc """
  Deletes multiple permissions for a user in one operation.
  """
  def delete_permissions_for_user(name, user, permissions) do
    EnforcerServer.delete_permissions_for_user(name, user, permissions)
  end

  @doc """
  Gets all users who have the specified role in the given domain.
  """
  def get_users_for_role_in_domain(name, role, domain) do
    EnforcerServer.get_users_for_role_in_domain(name, role, domain)
  end

  @doc """
  Gets all roles for a user in the given domain.
  """
  def get_roles_for_user_in_domain(name, user, domain) do
    EnforcerServer.get_roles_for_user_in_domain(name, user, domain)
  end

  @doc """
  Adds a role for a user in the specified domain.
  """
  def add_role_for_user_in_domain(name, user, role, domain) do
    EnforcerServer.add_role_for_user_in_domain(name, user, role, domain)
  end

  @doc """
  Deletes a role for a user in the specified domain.
  """
  def delete_role_for_user_in_domain(name, user, role, domain) do
    EnforcerServer.delete_role_for_user_in_domain(name, user, role, domain)
  end

  @doc """
  Deletes all roles for a user in the specified domain.
  """
  def delete_roles_for_user_in_domain(name, user, domain) do
    EnforcerServer.delete_roles_for_user_in_domain(name, user, domain)
  end

  @doc """
  Gets all users in the specified domain.
  """
  def get_all_users_by_domain(name, domain) do
    EnforcerServer.get_all_users_by_domain(name, domain)
  end

  @doc """
  Deletes all users in the specified domain.
  """
  def delete_all_users_by_domain(name, domain) do
    EnforcerServer.delete_all_users_by_domain(name, domain)
  end
end
