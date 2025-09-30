defmodule CasbinEx2.EnforcerServer do
  @moduledoc """
  A GenServer that wraps an Enforcer struct and provides a process-based interface
  for authorization enforcement and policy management.
  """

  use GenServer

  require Logger

  alias CasbinEx2.Adapter.FileAdapter
  alias CasbinEx2.Enforcer

  #
  # Client API
  #

  @doc """
  Starts an enforcer server with the given name, model path, and options.
  """
  def start_link(name, model_path, opts \\ []) do
    GenServer.start_link(
      __MODULE__,
      {name, model_path, opts},
      name: via_tuple(name)
    )
  end

  @doc """
  Performs authorization enforcement. Returns true if the request is allowed.
  """
  def enforce(name, request) do
    GenServer.call(via_tuple(name), {:enforce, request})
  end

  @doc """
  Performs authorization enforcement with explanations. Returns {allowed, explanations}.
  """
  def enforce_ex(name, request) do
    GenServer.call(via_tuple(name), {:enforce_ex, request})
  end

  @doc """
  Performs authorization enforcement with custom matcher.
  """
  def enforce_with_matcher(name, matcher, request) do
    GenServer.call(via_tuple(name), {:enforce_with_matcher, matcher, request})
  end

  @doc """
  Performs authorization enforcement with custom matcher and explanations.
  """
  def enforce_ex_with_matcher(name, matcher, request) do
    GenServer.call(via_tuple(name), {:enforce_ex_with_matcher, matcher, request})
  end

  @doc """
  Performs batch enforcement for multiple requests.
  """
  def batch_enforce(name, requests) do
    GenServer.call(via_tuple(name), {:batch_enforce, requests})
  end

  @doc """
  Performs batch enforcement with explanations for multiple requests.
  """
  def batch_enforce_ex(name, requests) do
    GenServer.call(via_tuple(name), {:batch_enforce_ex, requests})
  end

  @doc """
  Performs batch enforcement with custom matcher.
  """
  def batch_enforce_with_matcher(name, matcher, requests) do
    GenServer.call(via_tuple(name), {:batch_enforce_with_matcher, matcher, requests})
  end

  @doc """
  Adds a policy rule.
  """
  def add_policy(name, params) when is_list(params) do
    GenServer.call(via_tuple(name), {:add_policy, params})
  end

  @doc """
  Adds multiple policy rules.
  """
  def add_policies(name, rules) when is_list(rules) do
    GenServer.call(via_tuple(name), {:add_policies, rules})
  end

  @doc """
  Removes a policy rule.
  """
  def remove_policy(name, params) when is_list(params) do
    GenServer.call(via_tuple(name), {:remove_policy, params})
  end

  @doc """
  Removes multiple policy rules.
  """
  def remove_policies(name, rules) when is_list(rules) do
    GenServer.call(via_tuple(name), {:remove_policies, rules})
  end

  @doc """
  Removes filtered policy rules.
  """
  def remove_filtered_policy(name, field_index, field_values) do
    GenServer.call(via_tuple(name), {:remove_filtered_policy, field_index, field_values})
  end

  @doc """
  Gets all policy rules.
  """
  def get_policy(name) do
    GenServer.call(via_tuple(name), {:get_policy})
  end

  @doc """
  Gets filtered policy rules.
  """
  def get_filtered_policy(name, field_index, field_values) do
    GenServer.call(via_tuple(name), {:get_filtered_policy, field_index, field_values})
  end

  @doc """
  Checks if a policy rule exists.
  """
  def has_policy(name, params) do
    GenServer.call(via_tuple(name), {:has_policy, params})
  end

  @doc """
  Adds a grouping policy (role inheritance).
  """
  def add_grouping_policy(name, params) do
    GenServer.call(via_tuple(name), {:add_grouping_policy, params})
  end

  @doc """
  Removes a grouping policy.
  """
  def remove_grouping_policy(name, params) do
    GenServer.call(via_tuple(name), {:remove_grouping_policy, params})
  end

  @doc """
  Gets all grouping policies.
  """
  def get_grouping_policy(name) do
    GenServer.call(via_tuple(name), {:get_grouping_policy})
  end

  @doc """
  Adds a role for a user.
  """
  def add_role_for_user(name, user, role, domain \\ "") do
    GenServer.call(via_tuple(name), {:add_role_for_user, user, role, domain})
  end

  @doc """
  Deletes a role for a user.
  """
  def delete_role_for_user(name, user, role, domain \\ "") do
    GenServer.call(via_tuple(name), {:delete_role_for_user, user, role, domain})
  end

  @doc """
  Deletes all roles for a user.
  """
  def delete_roles_for_user(name, user, domain \\ "") do
    GenServer.call(via_tuple(name), {:delete_roles_for_user, user, domain})
  end

  @doc """
  Gets all roles for a user.
  """
  def get_roles_for_user(name, user, domain \\ "") do
    GenServer.call(via_tuple(name), {:get_roles_for_user, user, domain})
  end

  @doc """
  Gets all users for a role.
  """
  def get_users_for_role(name, role, domain \\ "") do
    GenServer.call(via_tuple(name), {:get_users_for_role, role, domain})
  end

  @doc """
  Checks if a user has a role.
  """
  def has_role_for_user(name, user, role, domain \\ "") do
    GenServer.call(via_tuple(name), {:has_role_for_user, user, role, domain})
  end

  @doc """
  Gets all permissions for a user.
  """
  def get_permissions_for_user(name, user, domain \\ "") do
    GenServer.call(via_tuple(name), {:get_permissions_for_user, user, domain})
  end

  @doc """
  Adds a permission for a user.
  """
  def add_permission_for_user(name, user, permission) when is_list(permission) do
    GenServer.call(via_tuple(name), {:add_permission_for_user, user, permission})
  end

  @doc """
  Deletes a permission for a user.
  """
  def delete_permission_for_user(name, user, permission) when is_list(permission) do
    GenServer.call(via_tuple(name), {:delete_permission_for_user, user, permission})
  end

  @doc """
  Deletes all permissions for a user.
  """
  def delete_permissions_for_user(name, user) do
    GenServer.call(via_tuple(name), {:delete_permissions_for_user, user})
  end

  @doc """
  Loads policy from the adapter.
  """
  def load_policy(name) do
    GenServer.call(via_tuple(name), {:load_policy})
  end

  @doc """
  Saves policy to the adapter.
  """
  def save_policy(name) do
    GenServer.call(via_tuple(name), {:save_policy})
  end

  @doc """
  Clears all policies.
  """
  def clear_policy(name) do
    GenServer.call(via_tuple(name), {:clear_policy})
  end

  #
  # Self-Management APIs (bypass auto-notify)
  #

  @doc """
  Adds a policy rule without triggering auto-save or watcher notifications.
  """
  def add_policy_self(name, params) when is_list(params) do
    GenServer.call(via_tuple(name), {:add_policy_self, params})
  end

  @doc """
  Adds multiple policy rules without triggering auto-save or watcher notifications.
  """
  def add_policies_self(name, rules) when is_list(rules) do
    GenServer.call(via_tuple(name), {:add_policies_self, rules})
  end

  @doc """
  Removes a policy rule without triggering auto-save or watcher notifications.
  """
  def remove_policy_self(name, params) when is_list(params) do
    GenServer.call(via_tuple(name), {:remove_policy_self, params})
  end

  @doc """
  Removes multiple policy rules without triggering auto-save or watcher notifications.
  """
  def remove_policies_self(name, rules) when is_list(rules) do
    GenServer.call(via_tuple(name), {:remove_policies_self, rules})
  end

  @doc """
  Removes filtered policy rules without triggering auto-save or watcher notifications.
  """
  def remove_filtered_policy_self(name, field_index, field_values) do
    GenServer.call(via_tuple(name), {:remove_filtered_policy_self, field_index, field_values})
  end

  @doc """
  Adds a grouping policy without triggering auto-save or watcher notifications.
  """
  def add_grouping_policy_self(name, params) when is_list(params) do
    GenServer.call(via_tuple(name), {:add_grouping_policy_self, params})
  end

  @doc """
  Adds multiple grouping policies without triggering auto-save or watcher notifications.
  """
  def add_grouping_policies_self(name, rules) when is_list(rules) do
    GenServer.call(via_tuple(name), {:add_grouping_policies_self, rules})
  end

  @doc """
  Removes a grouping policy without triggering auto-save or watcher notifications.
  """
  def remove_grouping_policy_self(name, params) when is_list(params) do
    GenServer.call(via_tuple(name), {:remove_grouping_policy_self, params})
  end

  @doc """
  Removes multiple grouping policies without triggering auto-save or watcher notifications.
  """
  def remove_grouping_policies_self(name, rules) when is_list(rules) do
    GenServer.call(via_tuple(name), {:remove_grouping_policies_self, rules})
  end

  @doc """
  Removes filtered grouping policies without triggering auto-save or watcher notifications.
  """
  def remove_filtered_grouping_policy_self(name, field_index, field_values) do
    GenServer.call(
      via_tuple(name),
      {:remove_filtered_grouping_policy_self, field_index, field_values}
    )
  end

  @doc """
  Updates a policy rule without triggering auto-save or watcher notifications.
  """
  def update_policy_self(name, old_params, new_params) do
    GenServer.call(via_tuple(name), {:update_policy_self, old_params, new_params})
  end

  @doc """
  Updates multiple policy rules without triggering auto-save or watcher notifications.
  """
  def update_policies_self(name, old_rules, new_rules) do
    GenServer.call(via_tuple(name), {:update_policies_self, old_rules, new_rules})
  end

  @doc """
  Updates grouping policies without triggering auto-save or watcher notifications.
  """
  def update_grouping_policy_self(name, old_params, new_params) do
    GenServer.call(via_tuple(name), {:update_grouping_policy_self, old_params, new_params})
  end

  @doc """
  Updates multiple grouping policies without triggering auto-save or watcher notifications.
  """
  def update_grouping_policies_self(name, old_rules, new_rules) do
    GenServer.call(via_tuple(name), {:update_grouping_policies_self, old_rules, new_rules})
  end

  @doc """
  Enables or disables the enforcer.
  """
  def enable_enforce(name, enable) do
    GenServer.call(via_tuple(name), {:enable_enforce, enable})
  end

  @doc """
  Enables or disables auto-save.
  """
  def enable_auto_save(name, auto_save) do
    GenServer.call(via_tuple(name), {:enable_auto_save, auto_save})
  end

  @doc """
  Builds role links.
  """
  def build_role_links(name) do
    GenServer.call(via_tuple(name), {:build_role_links})
  end

  #
  # Management APIs
  #

  @doc """
  Gets all subjects that show up in policies.
  """
  def get_all_subjects(name) do
    GenServer.call(via_tuple(name), {:get_all_subjects})
  end

  @doc """
  Gets all objects that show up in policies.
  """
  def get_all_objects(name) do
    GenServer.call(via_tuple(name), {:get_all_objects})
  end

  @doc """
  Gets all actions that show up in policies.
  """
  def get_all_actions(name) do
    GenServer.call(via_tuple(name), {:get_all_actions})
  end

  @doc """
  Gets all roles that show up in grouping policies.
  """
  def get_all_roles(name) do
    GenServer.call(via_tuple(name), {:get_all_roles})
  end

  @doc """
  Gets all domains from policies and grouping policies.
  """
  def get_all_domains(name) do
    GenServer.call(via_tuple(name), {:get_all_domains})
  end

  @doc """
  Updates a policy rule.
  """
  def update_policy(name, old_policy, new_policy) do
    GenServer.call(via_tuple(name), {:update_policy, old_policy, new_policy})
  end

  @doc """
  Updates multiple policy rules.
  """
  def update_policies(name, old_policies, new_policies) do
    GenServer.call(via_tuple(name), {:update_policies, old_policies, new_policies})
  end

  @doc """
  Updates a grouping policy rule.
  """
  def update_grouping_policy(name, old_rule, new_rule) do
    GenServer.call(via_tuple(name), {:update_grouping_policy, old_rule, new_rule})
  end

  @doc """
  Updates multiple grouping policy rules.
  """
  def update_grouping_policies(name, old_rules, new_rules) do
    GenServer.call(via_tuple(name), {:update_grouping_policies, old_rules, new_rules})
  end

  @doc """
  Gets implicit permissions for a user (includes permissions through roles).
  """
  def get_implicit_permissions_for_user(name, user, domain \\ "") do
    GenServer.call(via_tuple(name), {:get_implicit_permissions_for_user, user, domain})
  end

  @doc """
  Gets implicit roles for a user (includes inherited roles).
  """
  def get_implicit_roles_for_user(name, user, domain \\ "") do
    GenServer.call(via_tuple(name), {:get_implicit_roles_for_user, user, domain})
  end

  @doc """
  Checks if a user has a specific permission.
  """
  def has_permission_for_user(name, user, permission) when is_list(permission) do
    GenServer.call(via_tuple(name), {:has_permission_for_user, user, permission})
  end

  #
  # Complete RBAC API
  #

  @doc """
  Completely removes a user (removes user from all policies and grouping policies).
  """
  def delete_user(name, user) do
    GenServer.call(via_tuple(name), {:delete_user, user})
  end

  @doc """
  Completely removes a role (removes role from all grouping policies).
  """
  def delete_role(name, role) do
    GenServer.call(via_tuple(name), {:delete_role, role})
  end

  @doc """
  Removes a permission (removes permission from all policies).
  """
  def delete_permission(name, permission) do
    GenServer.call(via_tuple(name), {:delete_permission, permission})
  end

  @doc """
  Gets all users who have the specified permission.
  """
  def get_users_for_permission(name, permission) do
    GenServer.call(via_tuple(name), {:get_users_for_permission, permission})
  end

  @doc """
  Adds multiple roles for a user in one operation.
  """
  def add_roles_for_user(name, user, roles, domain \\ "") do
    GenServer.call(via_tuple(name), {:add_roles_for_user, user, roles, domain})
  end

  @doc """
  Adds multiple permissions for a user in one operation.
  """
  def add_permissions_for_user(name, user, permissions) do
    GenServer.call(via_tuple(name), {:add_permissions_for_user, user, permissions})
  end

  @doc """
  Deletes multiple permissions for a user in one operation.
  """
  def delete_permissions_for_user(name, user, permissions) do
    GenServer.call(via_tuple(name), {:delete_permissions_for_user, user, permissions})
  end

  @doc """
  Gets all users who have the specified role in the given domain.
  """
  def get_users_for_role_in_domain(name, role, domain) do
    GenServer.call(via_tuple(name), {:get_users_for_role_in_domain, role, domain})
  end

  @doc """
  Gets all roles for a user in the given domain.
  """
  def get_roles_for_user_in_domain(name, user, domain) do
    GenServer.call(via_tuple(name), {:get_roles_for_user_in_domain, user, domain})
  end

  @doc """
  Adds a role for a user in the specified domain.
  """
  def add_role_for_user_in_domain(name, user, role, domain) do
    GenServer.call(via_tuple(name), {:add_role_for_user_in_domain, user, role, domain})
  end

  @doc """
  Deletes a role for a user in the specified domain.
  """
  def delete_role_for_user_in_domain(name, user, role, domain) do
    GenServer.call(via_tuple(name), {:delete_role_for_user_in_domain, user, role, domain})
  end

  @doc """
  Deletes all roles for a user in the specified domain.
  """
  def delete_roles_for_user_in_domain(name, user, domain) do
    GenServer.call(via_tuple(name), {:delete_roles_for_user_in_domain, user, domain})
  end

  @doc """
  Gets all users in the specified domain.
  """
  def get_all_users_by_domain(name, domain) do
    GenServer.call(via_tuple(name), {:get_all_users_by_domain, domain})
  end

  @doc """
  Deletes all users in the specified domain.
  """
  def delete_all_users_by_domain(name, domain) do
    GenServer.call(via_tuple(name), {:delete_all_users_by_domain, domain})
  end

  #
  # Server Callbacks
  #

  @impl GenServer
  def init({name, model_path, opts}) do
    case create_or_lookup_enforcer(name, model_path, opts) do
      {:ok, enforcer} ->
        Logger.info("Started enforcer server '#{name}'")
        {:ok, enforcer}

      {:error, reason} ->
        Logger.error("Failed to start enforcer server '#{name}': #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:enforce, request}, _from, enforcer) do
    result = Enforcer.enforce(enforcer, request)
    {:reply, result, enforcer}
  end

  def handle_call({:enforce_ex, request}, _from, enforcer) do
    result = Enforcer.enforce_ex(enforcer, request)
    {:reply, result, enforcer}
  end

  def handle_call({:enforce_with_matcher, matcher, request}, _from, enforcer) do
    result = Enforcer.enforce_with_matcher(enforcer, matcher, request)
    {:reply, result, enforcer}
  end

  def handle_call({:enforce_ex_with_matcher, matcher, request}, _from, enforcer) do
    result = Enforcer.enforce_ex_with_matcher(enforcer, matcher, request)
    {:reply, result, enforcer}
  end

  def handle_call({:batch_enforce, requests}, _from, enforcer) do
    results = Enforcer.batch_enforce(enforcer, requests)
    {:reply, results, enforcer}
  end

  def handle_call({:batch_enforce_ex, requests}, _from, enforcer) do
    results = Enforcer.batch_enforce_ex(enforcer, requests)
    {:reply, results, enforcer}
  end

  def handle_call({:batch_enforce_with_matcher, matcher, requests}, _from, enforcer) do
    results = Enforcer.batch_enforce_with_matcher(enforcer, matcher, requests)
    {:reply, results, enforcer}
  end

  def handle_call({:add_policy, params}, _from, enforcer) do
    case add_policy_impl(enforcer, "p", "p", params) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:add_policies, rules}, _from, enforcer) do
    case add_policies_impl(enforcer, "p", "p", rules) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:remove_policy, params}, _from, enforcer) do
    case remove_policy_impl(enforcer, "p", "p", params) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:get_policy}, _from, enforcer) do
    policies = get_policy_impl(enforcer, "p", "p")
    {:reply, policies, enforcer}
  end

  def handle_call({:has_policy, params}, _from, enforcer) do
    result = has_policy_impl(enforcer, "p", "p", params)
    {:reply, result, enforcer}
  end

  def handle_call({:add_grouping_policy, params}, _from, enforcer) do
    case add_grouping_policy_impl(enforcer, "g", "g", params) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:remove_grouping_policy, params}, _from, enforcer) do
    case remove_grouping_policy_impl(enforcer, "g", "g", params) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:get_grouping_policy}, _from, enforcer) do
    policies = get_grouping_policy_impl(enforcer, "g", "g")
    {:reply, policies, enforcer}
  end

  def handle_call({:add_role_for_user, user, role, domain}, _from, enforcer) do
    params = if domain == "", do: [user, role], else: [user, role, domain]

    case add_grouping_policy_impl(enforcer, "g", "g", params) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:delete_role_for_user, user, role, domain}, _from, enforcer) do
    params = if domain == "", do: [user, role], else: [user, role, domain]

    case remove_grouping_policy_impl(enforcer, "g", "g", params) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:get_roles_for_user, user, domain}, _from, enforcer) do
    roles = get_roles_for_user_impl(enforcer, user, domain)
    {:reply, roles, enforcer}
  end

  def handle_call({:get_users_for_role, role, domain}, _from, enforcer) do
    users = get_users_for_role_impl(enforcer, role, domain)
    {:reply, users, enforcer}
  end

  def handle_call({:has_role_for_user, user, role, domain}, _from, enforcer) do
    result = has_role_for_user_impl(enforcer, user, role, domain)
    {:reply, result, enforcer}
  end

  def handle_call({:load_policy}, _from, enforcer) do
    case Enforcer.load_policy(enforcer) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, :ok, new_enforcer}

      {:error, reason} ->
        {:reply, {:error, reason}, enforcer}
    end
  end

  def handle_call({:save_policy}, _from, enforcer) do
    case Enforcer.save_policy(enforcer) do
      {:ok, new_enforcer} ->
        {:reply, :ok, new_enforcer}

      {:error, reason} ->
        {:reply, {:error, reason}, enforcer}
    end
  end

  def handle_call({:enable_enforce, enable}, _from, enforcer) do
    new_enforcer = Enforcer.enable_enforce(enforcer, enable)
    update_ets(new_enforcer)
    {:reply, :ok, new_enforcer}
  end

  def handle_call({:enable_auto_save, auto_save}, _from, enforcer) do
    new_enforcer = Enforcer.enable_auto_save(enforcer, auto_save)
    update_ets(new_enforcer)
    {:reply, :ok, new_enforcer}
  end

  def handle_call({:clear_policy}, _from, enforcer) do
    new_enforcer = %{enforcer | policies: %{}, grouping_policies: %{}}
    update_ets(new_enforcer)
    {:reply, :ok, new_enforcer}
  end

  def handle_call({:build_role_links}, _from, enforcer) do
    {:ok, new_enforcer} = Enforcer.build_role_links(enforcer)
    update_ets(new_enforcer)
    {:reply, :ok, new_enforcer}
  end

  # Management API handlers
  def handle_call({:get_all_subjects}, _from, enforcer) do
    result = Enforcer.get_all_subjects(enforcer)
    {:reply, result, enforcer}
  end

  def handle_call({:get_all_objects}, _from, enforcer) do
    result = Enforcer.get_all_objects(enforcer)
    {:reply, result, enforcer}
  end

  def handle_call({:get_all_actions}, _from, enforcer) do
    result = Enforcer.get_all_actions(enforcer)
    {:reply, result, enforcer}
  end

  def handle_call({:get_all_roles}, _from, enforcer) do
    result = Enforcer.get_all_roles(enforcer)
    {:reply, result, enforcer}
  end

  def handle_call({:get_all_domains}, _from, enforcer) do
    result = Enforcer.get_all_domains(enforcer)
    {:reply, result, enforcer}
  end

  def handle_call({:update_policy, old_policy, new_policy}, _from, enforcer) do
    case Enforcer.update_policy(enforcer, old_policy, new_policy) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:update_policies, old_policies, new_policies}, _from, enforcer) do
    case Enforcer.update_policies(enforcer, old_policies, new_policies) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:update_grouping_policy, old_rule, new_rule}, _from, enforcer) do
    case Enforcer.update_grouping_policy(enforcer, old_rule, new_rule) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:update_grouping_policies, old_rules, new_rules}, _from, enforcer) do
    case Enforcer.update_grouping_policies(enforcer, old_rules, new_rules) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:get_implicit_permissions_for_user, user, domain}, _from, enforcer) do
    result = get_implicit_permissions_for_user_impl(enforcer, user, domain)
    {:reply, result, enforcer}
  end

  def handle_call({:get_implicit_roles_for_user, user, domain}, _from, enforcer) do
    result = get_implicit_roles_for_user_impl(enforcer, user, domain)
    {:reply, result, enforcer}
  end

  def handle_call({:has_permission_for_user, user, permission}, _from, enforcer) do
    result = has_permission_for_user_impl(enforcer, user, permission)
    {:reply, result, enforcer}
  end

  # Complete RBAC API handlers

  def handle_call({:delete_user, user}, _from, enforcer) do
    case Enforcer.delete_user(enforcer, user) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:delete_role, role}, _from, enforcer) do
    case Enforcer.delete_role(enforcer, role) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:delete_permission, permission}, _from, enforcer) do
    case Enforcer.delete_permission(enforcer, permission) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:get_users_for_permission, permission}, _from, enforcer) do
    result = Enforcer.get_users_for_permission(enforcer, permission)
    {:reply, result, enforcer}
  end

  def handle_call({:add_roles_for_user, user, roles, domain}, _from, enforcer) do
    case Enforcer.add_roles_for_user(enforcer, user, roles, domain) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:add_permissions_for_user, user, permissions}, _from, enforcer) do
    case Enforcer.add_permissions_for_user(enforcer, user, permissions) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:add_permission_for_user, user, permission}, _from, enforcer) do
    case Enforcer.add_permissions_for_user(enforcer, user, [permission]) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:get_permissions_for_user, user, domain}, _from, enforcer) do
    result = Enforcer.get_permissions_for_user(enforcer, user, domain)
    {:reply, result, enforcer}
  end

  def handle_call({:delete_permissions_for_user, user, permissions}, _from, enforcer) do
    case Enforcer.delete_permissions_for_user(enforcer, user, permissions) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:get_users_for_role_in_domain, role, domain}, _from, enforcer) do
    result = Enforcer.get_users_for_role_in_domain(enforcer, role, domain)
    {:reply, result, enforcer}
  end

  def handle_call({:get_roles_for_user_in_domain, user, domain}, _from, enforcer) do
    result = Enforcer.get_roles_for_user_in_domain(enforcer, user, domain)
    {:reply, result, enforcer}
  end

  def handle_call({:add_role_for_user_in_domain, user, role, domain}, _from, enforcer) do
    case Enforcer.add_role_for_user_in_domain(enforcer, user, role, domain) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:delete_role_for_user_in_domain, user, role, domain}, _from, enforcer) do
    case Enforcer.delete_role_for_user_in_domain(enforcer, user, role, domain) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:delete_roles_for_user_in_domain, user, domain}, _from, enforcer) do
    case Enforcer.delete_roles_for_user_in_domain(enforcer, user, domain) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:get_all_users_by_domain, domain}, _from, enforcer) do
    result = Enforcer.get_all_users_by_domain(enforcer, domain)
    {:reply, result, enforcer}
  end

  def handle_call({:delete_all_users_by_domain, domain}, _from, enforcer) do
    case Enforcer.delete_all_users_by_domain(enforcer, domain) do
      {:ok, new_enforcer} ->
        update_ets(new_enforcer)
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  # Self-Management API handlers (bypass auto-notify)

  def handle_call({:add_policy_self, params}, _from, enforcer) do
    case add_policy_impl(enforcer, "p", "p", params) do
      {:ok, new_enforcer} ->
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:add_policies_self, rules}, _from, enforcer) do
    case add_policies_impl(enforcer, "p", "p", rules) do
      {:ok, new_enforcer} ->
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:remove_policy_self, params}, _from, enforcer) do
    case remove_policy_impl(enforcer, "p", "p", params) do
      {:ok, new_enforcer} ->
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:remove_policies_self, rules}, _from, enforcer) do
    {:ok, new_enforcer} = remove_policies_impl(enforcer, "p", "p", rules)
    {:reply, true, new_enforcer}
  end

  def handle_call({:remove_filtered_policy_self, field_index, field_values}, _from, enforcer) do
    {:ok, new_enforcer} =
      remove_filtered_policy_impl(enforcer, "p", "p", field_index, field_values)

    {:reply, true, new_enforcer}
  end

  def handle_call({:add_grouping_policy_self, params}, _from, enforcer) do
    case add_grouping_policy_impl(enforcer, "g", "g", params) do
      {:ok, new_enforcer} ->
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:add_grouping_policies_self, rules}, _from, enforcer) do
    {:ok, new_enforcer} = add_grouping_policies_impl(enforcer, "g", "g", rules)
    {:reply, true, new_enforcer}
  end

  def handle_call({:remove_grouping_policy_self, params}, _from, enforcer) do
    case remove_grouping_policy_impl(enforcer, "g", "g", params) do
      {:ok, new_enforcer} ->
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:remove_grouping_policies_self, rules}, _from, enforcer) do
    {:ok, new_enforcer} = remove_grouping_policies_impl(enforcer, "g", "g", rules)
    {:reply, true, new_enforcer}
  end

  def handle_call(
        {:remove_filtered_grouping_policy_self, field_index, field_values},
        _from,
        enforcer
      ) do
    {:ok, new_enforcer} =
      remove_filtered_grouping_policy_impl(enforcer, "g", "g", field_index, field_values)

    {:reply, true, new_enforcer}
  end

  def handle_call({:update_policy_self, old_params, new_params}, _from, enforcer) do
    case update_policy_impl(enforcer, "p", "p", old_params, new_params) do
      {:ok, new_enforcer} ->
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:update_policies_self, old_rules, new_rules}, _from, enforcer) do
    case update_policies_impl(enforcer, "p", "p", old_rules, new_rules) do
      {:ok, new_enforcer} ->
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:update_grouping_policy_self, old_params, new_params}, _from, enforcer) do
    case update_grouping_policy_impl(enforcer, "g", "g", old_params, new_params) do
      {:ok, new_enforcer} ->
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  def handle_call({:update_grouping_policies_self, old_rules, new_rules}, _from, enforcer) do
    case update_grouping_policies_impl(enforcer, "g", "g", old_rules, new_rules) do
      {:ok, new_enforcer} ->
        {:reply, true, new_enforcer}

      {:error, _reason} ->
        {:reply, false, enforcer}
    end
  end

  # Default handler for unhandled calls
  def handle_call(msg, _from, enforcer) do
    Logger.warning("Unhandled call: #{inspect(msg)}")
    {:reply, {:error, :unhandled}, enforcer}
  end

  #
  # Helper Functions
  #

  defp via_tuple(name) do
    {:via, Registry, {CasbinEx2.EnforcerRegistry, name}}
  end

  defp self_name do
    case Registry.keys(CasbinEx2.EnforcerRegistry, self()) do
      [name] -> name
      _ -> :unknown
    end
  end

  defp create_or_lookup_enforcer(name, model_path, opts) do
    case :ets.lookup(:casbin_enforcers_table, name) do
      [] ->
        # Create new enforcer
        adapter = Keyword.get(opts, :adapter, FileAdapter.new(""))

        case Enforcer.init_with_file(model_path, adapter) do
          {:ok, enforcer} ->
            :ets.insert(:casbin_enforcers_table, {name, enforcer})
            {:ok, enforcer}

          {:error, reason} ->
            {:error, reason}
        end

      [{^name, enforcer}] ->
        # Return existing enforcer
        {:ok, enforcer}
    end
  end

  defp update_ets(enforcer) do
    name = self_name()
    :ets.insert(:casbin_enforcers_table, {name, enforcer})
  end

  # Policy management implementations

  defp add_policy_impl(enforcer, _sec, ptype, rule) do
    %{policies: policies} = enforcer
    current_rules = Map.get(policies, ptype, [])

    if rule in current_rules do
      {:error, :already_exists}
    else
      new_rules = [rule | current_rules]
      new_policies = Map.put(policies, ptype, new_rules)
      new_enforcer = %{enforcer | policies: new_policies}

      if enforcer.auto_save do
        Enforcer.save_policy(new_enforcer)
      else
        {:ok, new_enforcer}
      end
    end
  end

  defp add_policies_impl(enforcer, _sec, ptype, rules) do
    %{policies: policies} = enforcer
    current_rules = Map.get(policies, ptype, [])

    new_rules =
      Enum.reduce(rules, current_rules, fn rule, acc ->
        if rule in acc do
          acc
        else
          [rule | acc]
        end
      end)

    new_policies = Map.put(policies, ptype, new_rules)
    new_enforcer = %{enforcer | policies: new_policies}

    if enforcer.auto_save do
      Enforcer.save_policy(new_enforcer)
    else
      {:ok, new_enforcer}
    end
  end

  defp remove_policy_impl(enforcer, _sec, ptype, rule) do
    %{policies: policies} = enforcer
    current_rules = Map.get(policies, ptype, [])

    if rule in current_rules do
      new_rules = List.delete(current_rules, rule)
      new_policies = Map.put(policies, ptype, new_rules)
      new_enforcer = %{enforcer | policies: new_policies}

      if enforcer.auto_save do
        Enforcer.save_policy(new_enforcer)
      else
        {:ok, new_enforcer}
      end
    else
      {:error, :not_found}
    end
  end

  defp get_policy_impl(enforcer, _sec, ptype) do
    Map.get(enforcer.policies, ptype, [])
  end

  defp has_policy_impl(enforcer, _sec, ptype, params) do
    current_rules = Map.get(enforcer.policies, ptype, [])
    params in current_rules
  end

  defp add_grouping_policy_impl(enforcer, _sec, ptype, rule) do
    %{grouping_policies: grouping_policies, role_manager: role_manager} = enforcer
    current_rules = Map.get(grouping_policies, ptype, [])

    if rule in current_rules do
      {:error, :already_exists}
    else
      new_rules = [rule | current_rules]
      new_grouping_policies = Map.put(grouping_policies, ptype, new_rules)

      # Update role manager
      new_role_manager =
        case rule do
          [user, role] ->
            CasbinEx2.RoleManager.add_link(role_manager, user, role, "")

          [user, role, domain] ->
            CasbinEx2.RoleManager.add_link(role_manager, user, role, domain)

          _ ->
            role_manager
        end

      new_enforcer = %{
        enforcer
        | grouping_policies: new_grouping_policies,
          role_manager: new_role_manager
      }

      if enforcer.auto_save do
        Enforcer.save_policy(new_enforcer)
      else
        {:ok, new_enforcer}
      end
    end
  end

  defp remove_grouping_policy_impl(enforcer, _sec, ptype, rule) do
    %{grouping_policies: grouping_policies, role_manager: role_manager} = enforcer
    current_rules = Map.get(grouping_policies, ptype, [])

    if rule in current_rules do
      new_rules = List.delete(current_rules, rule)
      new_grouping_policies = Map.put(grouping_policies, ptype, new_rules)

      # Update role manager
      new_role_manager =
        case rule do
          [user, role] ->
            CasbinEx2.RoleManager.delete_link(role_manager, user, role, "")

          [user, role, domain] ->
            CasbinEx2.RoleManager.delete_link(role_manager, user, role, domain)

          _ ->
            role_manager
        end

      new_enforcer = %{
        enforcer
        | grouping_policies: new_grouping_policies,
          role_manager: new_role_manager
      }

      if enforcer.auto_save do
        Enforcer.save_policy(new_enforcer)
      else
        {:ok, new_enforcer}
      end
    else
      {:error, :not_found}
    end
  end

  defp get_grouping_policy_impl(enforcer, _sec, ptype) do
    Map.get(enforcer.grouping_policies, ptype, [])
  end

  defp get_roles_for_user_impl(enforcer, user, domain) do
    CasbinEx2.RoleManager.get_roles(enforcer.role_manager, user, domain)
  end

  defp get_users_for_role_impl(enforcer, role, domain) do
    CasbinEx2.RoleManager.get_users(enforcer.role_manager, role, domain)
  end

  defp has_role_for_user_impl(enforcer, user, role, domain) do
    CasbinEx2.RoleManager.has_link(enforcer.role_manager, user, role, domain)
  end

  # Missing impl functions for Self-management APIs

  defp remove_policies_impl(enforcer, _sec, ptype, rules) do
    new_policies =
      Enum.reduce(rules, enforcer.policies, fn rule, acc ->
        case Map.get(acc, ptype) do
          nil ->
            acc

          policies ->
            filtered_policies = Enum.reject(policies, &(&1 == rule))
            Map.put(acc, ptype, filtered_policies)
        end
      end)

    {:ok, %{enforcer | policies: new_policies}}
  end

  defp remove_filtered_policy_impl(enforcer, _sec, ptype, field_index, field_values) do
    case Map.get(enforcer.policies, ptype) do
      nil ->
        {:ok, enforcer}

      policies ->
        filtered_policies =
          Enum.reject(policies, fn policy ->
            match_filtered_policy?(policy, field_index, field_values)
          end)

        new_policies = Map.put(enforcer.policies, ptype, filtered_policies)
        {:ok, %{enforcer | policies: new_policies}}
    end
  end

  defp add_grouping_policies_impl(enforcer, _sec, ptype, rules) do
    new_grouping_policies =
      Enum.reduce(rules, enforcer.grouping_policies, fn rule, acc ->
        case Map.get(acc, ptype) do
          nil -> Map.put(acc, ptype, [rule])
          policies -> Map.put(acc, ptype, [rule | policies])
        end
      end)

    {:ok, %{enforcer | grouping_policies: new_grouping_policies}}
  end

  defp remove_grouping_policies_impl(enforcer, _sec, ptype, rules) do
    new_grouping_policies =
      Enum.reduce(rules, enforcer.grouping_policies, fn rule, acc ->
        case Map.get(acc, ptype) do
          nil ->
            acc

          policies ->
            filtered_policies = Enum.reject(policies, &(&1 == rule))
            Map.put(acc, ptype, filtered_policies)
        end
      end)

    {:ok, %{enforcer | grouping_policies: new_grouping_policies}}
  end

  defp remove_filtered_grouping_policy_impl(enforcer, _sec, ptype, field_index, field_values) do
    case Map.get(enforcer.grouping_policies, ptype) do
      nil ->
        {:ok, enforcer}

      policies ->
        filtered_policies =
          Enum.reject(policies, fn policy ->
            match_filtered_policy?(policy, field_index, field_values)
          end)

        new_grouping_policies = Map.put(enforcer.grouping_policies, ptype, filtered_policies)
        {:ok, %{enforcer | grouping_policies: new_grouping_policies}}
    end
  end

  defp update_policy_impl(enforcer, _sec, ptype, old_params, new_params) do
    case Map.get(enforcer.policies, ptype) do
      nil ->
        {:error, :policy_not_found}

      policies ->
        case Enum.find_index(policies, &(&1 == old_params)) do
          nil ->
            {:error, :policy_not_found}

          index ->
            updated_policies = List.replace_at(policies, index, new_params)
            new_policies = Map.put(enforcer.policies, ptype, updated_policies)
            {:ok, %{enforcer | policies: new_policies}}
        end
    end
  end

  defp update_policies_impl(enforcer, _sec, ptype, old_rules, new_rules) do
    case validate_rule_lengths(old_rules, new_rules) do
      :ok -> update_rules_batch(enforcer, ptype, old_rules, new_rules)
      error -> error
    end
  end

  defp validate_rule_lengths(old_rules, new_rules) do
    if length(old_rules) == length(new_rules) do
      :ok
    else
      {:error, :rule_count_mismatch}
    end
  end

  defp update_rules_batch(enforcer, ptype, old_rules, new_rules) do
    Enum.zip(old_rules, new_rules)
    |> Enum.reduce_while({:ok, enforcer}, fn {old_rule, new_rule}, {:ok, acc_enforcer} ->
      case update_policy_impl(acc_enforcer, "p", ptype, old_rule, new_rule) do
        {:ok, updated_enforcer} -> {:cont, {:ok, updated_enforcer}}
        error -> {:halt, error}
      end
    end)
  end

  defp update_grouping_policy_impl(enforcer, _sec, ptype, old_params, new_params) do
    case Map.get(enforcer.grouping_policies, ptype) do
      nil ->
        {:error, :policy_not_found}

      policies ->
        case Enum.find_index(policies, &(&1 == old_params)) do
          nil ->
            {:error, :policy_not_found}

          index ->
            updated_policies = List.replace_at(policies, index, new_params)
            new_grouping_policies = Map.put(enforcer.grouping_policies, ptype, updated_policies)
            {:ok, %{enforcer | grouping_policies: new_grouping_policies}}
        end
    end
  end

  defp update_grouping_policies_impl(enforcer, _sec, ptype, old_rules, new_rules) do
    case validate_rule_lengths(old_rules, new_rules) do
      :ok -> update_grouping_rules_batch(enforcer, ptype, old_rules, new_rules)
      error -> error
    end
  end

  defp update_grouping_rules_batch(enforcer, ptype, old_rules, new_rules) do
    Enum.zip(old_rules, new_rules)
    |> Enum.reduce_while({:ok, enforcer}, fn {old_rule, new_rule}, {:ok, acc_enforcer} ->
      case update_grouping_policy_impl(acc_enforcer, "g", ptype, old_rule, new_rule) do
        {:ok, updated_enforcer} -> {:cont, {:ok, updated_enforcer}}
        error -> {:halt, error}
      end
    end)
  end

  defp match_filtered_policy?(policy, field_index, field_values) do
    field_values
    |> Enum.with_index()
    |> Enum.all?(fn {value, index} ->
      policy_index = field_index + index

      case Enum.at(policy, policy_index) do
        nil -> false
        policy_value -> policy_value == value
      end
    end)
  end

  # Helper implementations for new management APIs

  defp get_implicit_permissions_for_user_impl(enforcer, user, domain) do
    Enforcer.get_implicit_permissions_for_user(enforcer, user, domain)
  end

  defp get_implicit_roles_for_user_impl(enforcer, user, domain) do
    Enforcer.get_implicit_roles_for_user(enforcer, user, domain)
  end

  defp has_permission_for_user_impl(enforcer, user, permission) do
    Enforcer.has_permission_for_user(enforcer, user, permission)
  end
end
