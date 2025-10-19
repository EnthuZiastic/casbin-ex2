defmodule CasbinEx2.Management do
  @moduledoc """
  Management API for Casbin authorization policies.

  This module provides functions for policy management including:
  - Getting policies (filtered and unfiltered)
  - Adding and removing policies
  - Getting subjects, objects, and actions
  - Grouping policy management

  Corresponds to management_api.go in the Golang Casbin implementation.
  """

  alias CasbinEx2.Enforcer

  @doc """
  Gets the list of subjects that show up in the current policy.
  """
  def get_all_subjects(%Enforcer{policies: policies}) do
    policies
    |> Enum.flat_map(fn {_ptype, policy_list} ->
      Enum.map(policy_list, fn rule -> List.first(rule) end)
    end)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Gets the list of subjects that show up in the current named policy.
  """
  def get_all_named_subjects(%Enforcer{policies: policies}, ptype) do
    case Map.get(policies, ptype) do
      nil ->
        []

      policy_list ->
        policy_list
        |> Enum.map(fn rule -> List.first(rule) end)
        |> Enum.uniq()
        |> Enum.reject(&is_nil/1)
    end
  end

  @doc """
  Gets the list of objects that show up in the current policy.
  """
  def get_all_objects(%Enforcer{policies: policies}) do
    policies
    |> Enum.flat_map(fn {_ptype, policy_list} ->
      Enum.map(policy_list, fn rule -> Enum.at(rule, 1) end)
    end)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Gets the list of objects that show up in the current named policy.
  """
  def get_all_named_objects(%Enforcer{policies: policies}, ptype) do
    case Map.get(policies, ptype) do
      nil ->
        []

      policy_list ->
        policy_list
        |> Enum.map(fn rule -> Enum.at(rule, 1) end)
        |> Enum.uniq()
        |> Enum.reject(&is_nil/1)
    end
  end

  @doc """
  Gets the list of actions that show up in the current policy.
  """
  def get_all_actions(%Enforcer{policies: policies}) do
    policies
    |> Enum.flat_map(fn {_ptype, policy_list} ->
      Enum.map(policy_list, fn rule -> Enum.at(rule, 2) end)
    end)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Gets the list of actions that show up in the current named policy.
  """
  def get_all_named_actions(%Enforcer{policies: policies}, ptype) do
    case Map.get(policies, ptype) do
      nil ->
        []

      policy_list ->
        policy_list
        |> Enum.map(fn rule -> Enum.at(rule, 2) end)
        |> Enum.uniq()
        |> Enum.reject(&is_nil/1)
    end
  end

  @doc """
  Gets the list of roles that show up in the current policy.
  """
  def get_all_roles(%Enforcer{grouping_policies: grouping_policies}) do
    grouping_policies
    |> Enum.flat_map(fn {_ptype, policy_list} ->
      Enum.map(policy_list, fn rule -> Enum.at(rule, 1) end)
    end)
    |> Enum.uniq()
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Gets the list of roles that show up in the current named policy.
  """
  def get_all_named_roles(%Enforcer{grouping_policies: grouping_policies}, ptype) do
    case Map.get(grouping_policies, ptype) do
      nil ->
        []

      policy_list ->
        policy_list
        |> Enum.map(fn rule -> Enum.at(rule, 1) end)
        |> Enum.uniq()
        |> Enum.reject(&is_nil/1)
    end
  end

  @doc """
  Gets all the authorization rules in the policy.
  """
  def get_policy(%Enforcer{} = enforcer) do
    get_named_policy(enforcer, "p")
  end

  @doc """
  Gets all the authorization rules in the named policy.
  """
  def get_named_policy(%Enforcer{policies: policies}, ptype) do
    Map.get(policies, ptype, [])
  end

  @doc """
  Gets all the authorization rules in the policy, field filters can be specified.
  """
  def get_filtered_policy(%Enforcer{} = enforcer, field_index, field_values) do
    get_filtered_named_policy(enforcer, "p", field_index, field_values)
  end

  @doc """
  Gets all the authorization rules in the named policy, field filters can be specified.
  """
  def get_filtered_named_policy(%Enforcer{policies: policies}, ptype, field_index, field_values) do
    policy_list = Map.get(policies, ptype, [])

    policy_list
    |> Enum.filter(fn rule ->
      field_values
      |> Enum.with_index()
      |> Enum.all?(fn {value, index} ->
        actual_index = field_index + index
        rule_value = Enum.at(rule, actual_index)
        value == "" or rule_value == value
      end)
    end)
  end

  @doc """
  Gets all the role inheritance rules in the policy.
  """
  def get_grouping_policy(%Enforcer{} = enforcer) do
    get_named_grouping_policy(enforcer, "g")
  end

  @doc """
  Gets all the role inheritance rules in the named policy.
  """
  def get_named_grouping_policy(%Enforcer{grouping_policies: grouping_policies}, ptype) do
    Map.get(grouping_policies, ptype, [])
  end

  @doc """
  Gets all the role inheritance rules in the policy, field filters can be specified.
  """
  def get_filtered_grouping_policy(%Enforcer{} = enforcer, field_index, field_values) do
    get_filtered_named_grouping_policy(enforcer, "g", field_index, field_values)
  end

  @doc """
  Gets all the role inheritance rules in the named policy, field filters can be specified.
  """
  def get_filtered_named_grouping_policy(
        %Enforcer{grouping_policies: grouping_policies},
        ptype,
        field_index,
        field_values
      ) do
    policy_list = Map.get(grouping_policies, ptype, [])

    policy_list
    |> Enum.filter(fn rule ->
      field_values
      |> Enum.with_index()
      |> Enum.all?(fn {value, index} ->
        actual_index = field_index + index
        rule_value = Enum.at(rule, actual_index)
        value == "" or rule_value == value
      end)
    end)
  end

  @doc """
  Determines whether an authorization rule exists.
  """
  def has_policy(%Enforcer{} = enforcer, params) do
    has_named_policy(enforcer, "p", params)
  end

  @doc """
  Determines whether a named authorization rule exists.
  """
  def has_named_policy(%Enforcer{policies: policies}, ptype, params) do
    policy_list = Map.get(policies, ptype, [])
    params in policy_list
  end

  @doc """
  Determines whether a role inheritance rule exists.
  """
  def has_grouping_policy(%Enforcer{} = enforcer, params) do
    has_named_grouping_policy(enforcer, "g", params)
  end

  @doc """
  Determines whether a named role inheritance rule exists.
  """
  def has_named_grouping_policy(%Enforcer{grouping_policies: grouping_policies}, ptype, params) do
    policy_list = Map.get(grouping_policies, ptype, [])
    params in policy_list
  end

  @doc """
  Adds a role inheritance rule to the current policy.
  Returns {:ok, enforcer} if successful, {:error, reason} if failed.
  """
  def add_grouping_policy(%Enforcer{} = enforcer, params) do
    add_named_grouping_policy(enforcer, "g", params)
  end

  @doc """
  Adds role inheritance rules to the current policy.
  If the rule already exists, the function returns error for the corresponding policy rule.
  Otherwise returns {:ok, enforcer} by adding the new rules.
  """
  def add_grouping_policies(%Enforcer{} = enforcer, rules) do
    add_named_grouping_policies(enforcer, "g", rules)
  end

  @doc """
  Adds a named role inheritance rule to the current policy.
  Returns {:ok, enforcer} if successful, {:error, reason} if failed.
  """
  def add_named_grouping_policy(
        %Enforcer{grouping_policies: grouping_policies, role_manager: role_manager} = enforcer,
        ptype,
        params
      ) do
    if has_named_grouping_policy(enforcer, ptype, params) do
      {:error, "grouping policy already exists"}
    else
      updated_grouping_policies =
        Map.update(grouping_policies, ptype, [params], &(&1 ++ [params]))

      updated_enforcer = %{enforcer | grouping_policies: updated_grouping_policies}

      # Update role manager if it's the default "g" type
      updated_enforcer = update_role_manager_for_grouping(updated_enforcer, ptype, params)

      {:ok, updated_enforcer}
    end
  end

  # Update role manager when adding grouping policy
  defp update_role_manager_for_grouping(
         %Enforcer{role_manager: role_manager} = enforcer,
         "g",
         params
       )
       when length(params) >= 2 do
    # Support both 2-parameter (user, role) and 3-parameter (user, role, domain) forms
    case params do
      [user, role, domain | _rest] ->
        updated_rm = CasbinEx2.RoleManager.add_link(role_manager, user, role, domain)
        %{enforcer | role_manager: updated_rm}

      [user, role] ->
        updated_rm = CasbinEx2.RoleManager.add_link(role_manager, user, role, "")
        %{enforcer | role_manager: updated_rm}

      _ ->
        enforcer
    end
  end

  defp update_role_manager_for_grouping(enforcer, _ptype, _params), do: enforcer

  @doc """
  Adds named role inheritance rules to the current policy.
  Returns {:ok, enforcer} if successful, {:error, reason} if any rule fails.
  """
  def add_named_grouping_policies(%Enforcer{} = enforcer, ptype, rules) do
    Enum.reduce_while(rules, {:ok, enforcer}, fn rule, {:ok, current_enforcer} ->
      case add_named_grouping_policy(current_enforcer, ptype, rule) do
        {:ok, updated_enforcer} -> {:cont, {:ok, updated_enforcer}}
        {:error, _reason} -> {:halt, {:error, "failed to add grouping policies"}}
      end
    end)
  end

  @doc """
  Adds role inheritance rules to the current policy.
  If a rule already exists, it will be skipped (not added).
  Unlike add_grouping_policies, other non-existent rules are still added instead of returning error.
  Returns {:ok, enforcer, count} where count is the number of rules successfully added.
  """
  def add_grouping_policies_ex(%Enforcer{} = enforcer, rules) do
    add_named_grouping_policies_ex(enforcer, "g", rules)
  end

  @doc """
  Adds named role inheritance rules to the current policy.
  If a rule already exists, it will be skipped (not added).
  Unlike add_named_grouping_policies, other non-existent rules are still added instead of returning error.
  Returns {:ok, enforcer, count} where count is the number of rules successfully added.
  """
  def add_named_grouping_policies_ex(%Enforcer{} = enforcer, ptype, rules) do
    {updated_enforcer, count} =
      Enum.reduce(rules, {enforcer, 0}, fn rule, {current_enforcer, added_count} ->
        case add_named_grouping_policy(current_enforcer, ptype, rule) do
          {:ok, updated_enforcer} -> {updated_enforcer, added_count + 1}
          {:error, _reason} -> {current_enforcer, added_count}
        end
      end)

    {:ok, updated_enforcer, count}
  end

  @doc """
  Removes a role inheritance rule from the current policy.
  Returns {:ok, enforcer} if successful, {:error, reason} if failed.
  """
  def remove_grouping_policy(%Enforcer{} = enforcer, params) do
    remove_named_grouping_policy(enforcer, "g", params)
  end

  @doc """
  Removes role inheritance rules from the current policy.
  Returns {:ok, enforcer} if successful, {:error, reason} if any rule fails.
  """
  def remove_grouping_policies(%Enforcer{} = enforcer, rules) do
    remove_named_grouping_policies(enforcer, "g", rules)
  end

  @doc """
  Removes a named role inheritance rule from the current policy.
  Returns {:ok, enforcer} if successful, {:error, reason} if failed.
  """
  def remove_named_grouping_policy(
        %Enforcer{grouping_policies: grouping_policies, role_manager: role_manager} = enforcer,
        ptype,
        params
      ) do
    policy_list = Map.get(grouping_policies, ptype, [])

    if params in policy_list do
      updated_policy_list = List.delete(policy_list, params)
      updated_grouping_policies = Map.put(grouping_policies, ptype, updated_policy_list)
      updated_enforcer = %{enforcer | grouping_policies: updated_grouping_policies}

      # Update role manager if it's the default "g" type
      updated_enforcer =
        if ptype == "g" && length(params) >= 2 do
          [user, role | _rest] = params
          updated_rm = CasbinEx2.RoleManager.delete_link(role_manager, user, role)
          %{updated_enforcer | role_manager: updated_rm}
        else
          updated_enforcer
        end

      {:ok, updated_enforcer}
    else
      {:error, "grouping policy does not exist"}
    end
  end

  @doc """
  Removes named role inheritance rules from the current policy.
  Returns {:ok, enforcer} if successful, {:error, reason} if any rule fails.
  """
  def remove_named_grouping_policies(%Enforcer{} = enforcer, ptype, rules) do
    Enum.reduce_while(rules, {:ok, enforcer}, fn rule, {:ok, current_enforcer} ->
      case remove_named_grouping_policy(current_enforcer, ptype, rule) do
        {:ok, updated_enforcer} -> {:cont, {:ok, updated_enforcer}}
        {:error, _reason} -> {:halt, {:error, "failed to remove grouping policies"}}
      end
    end)
  end

  @doc """
  Removes a filtered role inheritance rule from the current policy.
  Returns {:ok, enforcer} if successful, {:error, reason} if failed.
  """
  def remove_filtered_grouping_policy(%Enforcer{} = enforcer, field_index, field_values) do
    remove_filtered_named_grouping_policy(enforcer, "g", field_index, field_values)
  end

  @doc """
  Removes filtered named role inheritance rules from the current policy.
  Returns {:ok, enforcer, count} with the number of rules removed.
  """
  def remove_filtered_named_grouping_policy(
        %Enforcer{} = enforcer,
        ptype,
        field_index,
        field_values
      ) do
    {:ok, updated_enforcer, removed_rules} =
      remove_filtered_named_grouping_policy_internal(
        enforcer,
        ptype,
        field_index,
        field_values
      )

    {:ok, updated_enforcer, length(removed_rules)}
  end

  @doc false
  # Internal version that returns the actual removed rules (used by enforcer.ex)
  def remove_filtered_named_grouping_policy_internal(
        %Enforcer{grouping_policies: grouping_policies} = enforcer,
        ptype,
        field_index,
        field_values
      ) do
    policy_list = Map.get(grouping_policies, ptype, [])

    {removed_policies, remaining_policies} =
      Enum.split_with(policy_list, fn rule ->
        field_values
        |> Enum.with_index()
        |> Enum.all?(fn {value, index} ->
          actual_index = field_index + index
          rule_value = Enum.at(rule, actual_index)
          value == "" or rule_value == value
        end)
      end)

    updated_grouping_policies = Map.put(grouping_policies, ptype, remaining_policies)
    updated_enforcer = %{enforcer | grouping_policies: updated_grouping_policies}

    # Update role manager for each removed policy if it's the default "g" type
    updated_enforcer =
      if ptype == "g" do
        Enum.reduce(removed_policies, updated_enforcer, &update_role_manager_for_removed_policy/2)
      else
        updated_enforcer
      end

    {:ok, updated_enforcer, removed_policies}
  end

  @doc """
  Adds a policy without triggering watcher notifications.
  Useful in distributed scenarios where the node updates its own policies.

  ## Parameters
  - `enforcer` - The enforcer struct
  - `sec` - Section type: "p" for policy, "g" for grouping
  - `ptype` - Policy type (e.g., "p", "p2", "g", "g2")
  - `rule` - The policy rule to add

  ## Examples

      # Add policy without notification
      {:ok, enforcer} = Management.self_add_policy(enforcer, "p", "p", ["alice", "data1", "read"])

      # Add grouping policy without notification
      {:ok, enforcer} = Management.self_add_policy(enforcer, "g", "g", ["alice", "admin"])
  """
  def self_add_policy(%Enforcer{} = enforcer, sec, ptype, rule) do
    case sec do
      "p" -> add_named_policy(enforcer, ptype, rule)
      "g" -> add_named_grouping_policy(enforcer, ptype, rule)
      _ -> {:error, "invalid section type, must be 'p' or 'g'"}
    end
  end

  @doc """
  Adds multiple policies without triggering watcher notifications.
  Returns {:ok, enforcer, count} where count is the number of successfully added rules.
  """
  def self_add_policies_ex(%Enforcer{} = enforcer, sec, ptype, rules) do
    case sec do
      "p" -> add_named_policies_ex(enforcer, ptype, rules)
      "g" -> add_named_grouping_policies_ex(enforcer, ptype, rules)
      _ -> {:error, "invalid section type, must be 'p' or 'g'"}
    end
  end

  @doc """
  Adds multiple policies without triggering watcher notifications.
  Does not filter duplicates (use self_add_policies_ex for that).
  """
  def self_add_policies(%Enforcer{} = enforcer, sec, ptype, rules) do
    case sec do
      "p" -> add_named_policies(enforcer, ptype, rules)
      "g" -> add_named_grouping_policies(enforcer, ptype, rules)
      _ -> {:error, "invalid section type, must be 'p' or 'g'"}
    end
  end

  @doc """
  Removes a policy without triggering watcher notifications.
  Useful in distributed scenarios where the node updates its own policies.
  """
  def self_remove_policy(%Enforcer{} = enforcer, sec, ptype, rule) do
    case sec do
      "p" -> remove_named_policy(enforcer, ptype, rule)
      "g" -> remove_named_grouping_policy(enforcer, ptype, rule)
      _ -> {:error, "invalid section type, must be 'p' or 'g'"}
    end
  end

  @doc """
  Removes multiple policies without triggering watcher notifications.
  Useful in distributed scenarios where the node updates its own policies.
  """
  def self_remove_policies(%Enforcer{} = enforcer, sec, ptype, rules) do
    case sec do
      "p" -> remove_named_policies(enforcer, ptype, rules)
      "g" -> remove_named_grouping_policies(enforcer, ptype, rules)
      _ -> {:error, "invalid section type, must be 'p' or 'g'"}
    end
  end

  @doc """
  Removes filtered policies without triggering watcher notifications.
  Useful in distributed scenarios where the node updates its own policies.

  ## Parameters
  - `enforcer` - The enforcer struct
  - `sec` - Section type ("p" or "g")
  - `ptype` - Policy type
  - `field_index` - Index of the field to match (0-based)
  - `field_values` - Values to match

  ## Examples

      {:ok, enforcer} = self_remove_filtered_policy(enforcer, "p", "p", 0, ["alice"])
  """
  def self_remove_filtered_policy(%Enforcer{} = enforcer, sec, ptype, field_index, field_values) do
    case sec do
      "p" -> remove_filtered_named_policy(enforcer, ptype, field_index, field_values)
      "g" -> remove_filtered_named_grouping_policy(enforcer, ptype, field_index, field_values)
      _ -> {:error, "invalid section type, must be 'p' or 'g'"}
    end
  end

  @doc """
  Updates a policy without triggering watcher notifications.
  Useful in distributed scenarios where the node updates its own policies.
  """
  def self_update_policy(%Enforcer{} = enforcer, sec, ptype, old_rule, new_rule) do
    case sec do
      "p" -> update_named_policy(enforcer, ptype, old_rule, new_rule)
      "g" -> update_named_grouping_policy(enforcer, ptype, old_rule, new_rule)
      _ -> {:error, "invalid section type, must be 'p' or 'g'"}
    end
  end

  @doc """
  Updates multiple policies without triggering watcher notifications.
  Useful in distributed scenarios where the node updates its own policies.
  """
  def self_update_policies(%Enforcer{} = enforcer, sec, ptype, old_rules, new_rules) do
    case sec do
      "p" -> update_named_policies(enforcer, ptype, old_rules, new_rules)
      "g" -> update_named_grouping_policies(enforcer, ptype, old_rules, new_rules)
      _ -> {:error, "invalid section type, must be 'p' or 'g'"}
    end
  end

  @doc """
  Adds a custom function to the enforcer's function map.

  The function can then be used in matcher expressions.

  ## Parameters
  - `enforcer` - The enforcer struct
  - `name` - The name of the function (string)
  - `function` - An anonymous function that takes arguments and returns a boolean or value

  ## Examples

      # Add a custom matching function
      enforcer = Management.add_function(enforcer, "customMatch", fn arg1, arg2 ->
        String.contains?(arg1, arg2)
      end)

      # Now you can use it in matchers: customMatch(r.obj, p.obj)
  """
  def add_function(%Enforcer{function_map: function_map} = enforcer, name, function)
      when is_binary(name) and is_function(function) do
    updated_function_map = Map.put(function_map, name, function)
    %{enforcer | function_map: updated_function_map}
  end

  @doc """
  Updates a role inheritance rule from old_rule to new_rule.
  Returns {:ok, enforcer} if successful, {:error, reason} if failed.
  """
  def update_grouping_policy(%Enforcer{} = enforcer, old_rule, new_rule) do
    update_named_grouping_policy(enforcer, "g", old_rule, new_rule)
  end

  @doc """
  Updates multiple role inheritance rules from old_rules to new_rules.
  Returns {:ok, enforcer} if successful, {:error, reason} if failed.
  """
  def update_grouping_policies(%Enforcer{} = enforcer, old_rules, new_rules) do
    update_named_grouping_policies(enforcer, "g", old_rules, new_rules)
  end

  @doc """
  Updates a named role inheritance rule from old_rule to new_rule.
  Returns {:ok, enforcer} if successful, {:error, reason} if failed.
  """
  def update_named_grouping_policy(%Enforcer{} = enforcer, ptype, old_rule, new_rule) do
    case remove_named_grouping_policy(enforcer, ptype, old_rule) do
      {:ok, updated_enforcer} ->
        add_named_grouping_policy(updated_enforcer, ptype, new_rule)

      {:error, _reason} ->
        {:error, :not_found}
    end
  end

  @doc """
  Updates multiple named role inheritance rules from old_rules to new_rules.
  Returns {:ok, enforcer} if successful, {:error, reason} if failed.
  """
  def update_named_grouping_policies(%Enforcer{} = enforcer, ptype, old_rules, new_rules) do
    if length(old_rules) != length(new_rules) do
      {:error, "old_rules and new_rules must have same length"}
    else
      # Remove all old rules first, then add all new rules
      case remove_named_grouping_policies(enforcer, ptype, old_rules) do
        {:ok, updated_enforcer} ->
          add_named_grouping_policies(updated_enforcer, ptype, new_rules)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Adds an authorization rule to the current policy.
  Returns {:ok, enforcer} if successful, {:error, reason} if failed.
  """
  def add_policy(%Enforcer{} = enforcer, params) do
    add_named_policy(enforcer, "p", params)
  end

  @doc """
  Adds an authorization rule to the current named policy.
  Returns {:ok, enforcer} if successful, {:error, reason} if failed.
  """
  def add_named_policy(%Enforcer{policies: policies} = enforcer, ptype, params) do
    if has_named_policy(enforcer, ptype, params) do
      {:error, "policy already exists"}
    else
      updated_policies = Map.update(policies, ptype, [params], &(&1 ++ [params]))
      updated_enforcer = %{enforcer | policies: updated_policies}
      {:ok, updated_enforcer}
    end
  end

  @doc """
  Adds authorization rules to the current policy.
  Returns false if any rule already exists.
  """
  def add_policies(%Enforcer{} = enforcer, rules) do
    add_named_policies(enforcer, "p", rules)
  end

  @doc """
  Adds authorization rules to the current named policy.
  Returns false if any rule already exists.
  """
  def add_named_policies(%Enforcer{} = enforcer, ptype, rules) do
    Enum.reduce_while(rules, {:ok, enforcer}, fn rule, {_acc, current_enforcer} ->
      case add_named_policy(current_enforcer, ptype, rule) do
        {:ok, updated_enforcer} -> {:cont, {:ok, updated_enforcer}}
        {:error, _reason} -> {:halt, {:error, "failed to add policies"}}
      end
    end)
  end

  @doc """
  Adds authorization rules to the current policy.
  If a rule already exists, it will be skipped (not added).
  Unlike add_policies, other non-existent rules are still added instead of returning error.
  Returns {:ok, enforcer} with count of rules added.
  """
  def add_policies_ex(%Enforcer{} = enforcer, rules) do
    add_named_policies_ex(enforcer, "p", rules)
  end

  @doc """
  Adds authorization rules to the current named policy.
  If a rule already exists, it will be skipped (not added).
  Unlike add_named_policies, other non-existent rules are still added instead of returning error.
  Returns {:ok, enforcer, count} where count is the number of rules successfully added.
  """
  def add_named_policies_ex(%Enforcer{} = enforcer, ptype, rules) do
    {updated_enforcer, count} =
      Enum.reduce(rules, {enforcer, 0}, fn rule, {current_enforcer, added_count} ->
        case add_named_policy(current_enforcer, ptype, rule) do
          {:ok, updated_enforcer} -> {updated_enforcer, added_count + 1}
          {:error, _reason} -> {current_enforcer, added_count}
        end
      end)

    {:ok, updated_enforcer, count}
  end

  @doc """
  Removes an authorization rule from the current policy.
  Returns false if the rule does not exist.
  """
  def remove_policy(%Enforcer{} = enforcer, params) do
    remove_named_policy(enforcer, "p", params)
  end

  @doc """
  Removes an authorization rule from the current named policy.
  Returns false if the rule does not exist.
  """
  def remove_named_policy(%Enforcer{policies: policies} = enforcer, ptype, params) do
    if has_named_policy(enforcer, ptype, params) do
      policy_list = Map.get(policies, ptype, [])
      updated_policy_list = List.delete(policy_list, params)
      updated_policies = Map.put(policies, ptype, updated_policy_list)
      updated_enforcer = %{enforcer | policies: updated_policies}
      {:ok, updated_enforcer}
    else
      {:error, "policy does not exist"}
    end
  end

  @doc """
  Removes authorization rules from the current policy.
  Returns false if any rule does not exist.
  """
  def remove_policies(%Enforcer{} = enforcer, rules) do
    remove_named_policies(enforcer, "p", rules)
  end

  @doc """
  Removes authorization rules from the current named policy.
  Returns false if any rule does not exist.
  """
  def remove_named_policies(%Enforcer{} = enforcer, ptype, rules) do
    Enum.reduce_while(rules, {:ok, enforcer}, fn rule, {_acc, current_enforcer} ->
      case remove_named_policy(current_enforcer, ptype, rule) do
        {:ok, updated_enforcer} -> {:cont, {:ok, updated_enforcer}}
        {:error, _reason} -> {:halt, {:error, "failed to remove policies"}}
      end
    end)
  end

  @doc """
  Removes authorization rules that match the filter from the current policy.
  Returns {:ok, enforcer, count} with the number of rules removed.
  """
  def remove_filtered_policy(%Enforcer{} = enforcer, field_index, field_values) do
    {:ok, updated_enforcer, removed_rules} =
      remove_filtered_named_policy_internal(enforcer, "p", field_index, field_values)

    {:ok, updated_enforcer, length(removed_rules)}
  end

  @doc """
  Removes authorization rules that match the filter from the current named policy.
  Returns {:ok, enforcer, count} with the number of rules removed.
  """
  def remove_filtered_named_policy(
        %Enforcer{} = enforcer,
        ptype,
        field_index,
        field_values
      ) do
    {:ok, updated_enforcer, removed_rules} =
      remove_filtered_named_policy_internal(enforcer, ptype, field_index, field_values)

    {:ok, updated_enforcer, length(removed_rules)}
  end

  @doc false
  # Internal version that returns the actual removed rules (used by enforcer.ex)
  def remove_filtered_named_policy_internal(
        %Enforcer{policies: policies} = enforcer,
        ptype,
        field_index,
        field_values
      ) do
    policy_list = Map.get(policies, ptype, [])

    {matching_rules, remaining_rules} =
      Enum.split_with(policy_list, fn rule ->
        field_values
        |> Enum.with_index()
        |> Enum.all?(fn {value, index} ->
          actual_index = field_index + index
          rule_value = Enum.at(rule, actual_index)
          value == "" or rule_value == value
        end)
      end)

    updated_policies = Map.put(policies, ptype, remaining_rules)
    updated_enforcer = %{enforcer | policies: updated_policies}
    {:ok, updated_enforcer, matching_rules}
  end

  @doc """
  Updates a policy rule from old_rule to new_rule.
  """
  def update_policy(%Enforcer{} = enforcer, old_rule, new_rule) do
    update_named_policy(enforcer, "p", old_rule, new_rule)
  end

  @doc """
  Updates a named policy rule from old_rule to new_rule.
  """
  def update_named_policy(%Enforcer{} = enforcer, ptype, old_rule, new_rule) do
    case remove_named_policy(enforcer, ptype, old_rule) do
      {:ok, updated_enforcer} ->
        add_named_policy(updated_enforcer, ptype, new_rule)

      {:error, _reason} ->
        {:error, :not_found}
    end
  end

  @doc """
  Updates multiple policy rules.
  """
  def update_policies(%Enforcer{} = enforcer, old_rules, new_rules) do
    update_named_policies(enforcer, "p", old_rules, new_rules)
  end

  @doc """
  Updates multiple named policy rules.
  """
  def update_named_policies(%Enforcer{} = enforcer, ptype, old_rules, new_rules) do
    if length(old_rules) != length(new_rules) do
      {:error, "old_rules and new_rules must have same length"}
    else
      # Remove all old rules first, then add all new rules
      case remove_named_policies(enforcer, ptype, old_rules) do
        {:ok, updated_enforcer} ->
          add_named_policies(updated_enforcer, ptype, new_rules)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Updates policies that match the filter with new policies.
  Delegates to update_filtered_named_policies with "p" type.

  Returns {:ok, enforcer, old_rules} with the list of old rules that were replaced.
  """
  def update_filtered_policies(
        %Enforcer{} = enforcer,
        new_rules,
        field_index,
        field_values
      ) do
    update_filtered_named_policies(enforcer, "p", new_rules, field_index, field_values)
  end

  @doc """
  Updates named policies that match the filter with new policies.

  The function:
  1. Finds policies matching the filter
  2. Removes those policies
  3. Adds the new policies
  4. Returns the old policies that were replaced

  Returns {:ok, enforcer, old_rules} with the list of old rules that were replaced.
  """
  def update_filtered_named_policies(
        %Enforcer{policies: policies} = enforcer,
        ptype,
        new_rules,
        field_index,
        field_values
      ) do
    policy_list = Map.get(policies, ptype, [])

    # Find matching policies (these will be removed)
    old_rules =
      Enum.filter(policy_list, fn rule ->
        field_values
        |> Enum.with_index()
        |> Enum.all?(fn {value, index} ->
          actual_index = field_index + index
          rule_value = Enum.at(rule, actual_index)
          value == "" or rule_value == value
        end)
      end)

    # Remove old rules and add new ones
    case remove_named_policies(enforcer, ptype, old_rules) do
      {:ok, updated_enforcer} ->
        case add_named_policies(updated_enforcer, ptype, new_rules) do
          {:ok, final_enforcer} ->
            {:ok, final_enforcer, old_rules}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets policies filtered by a custom matcher expression.

  This is a simplified implementation that evaluates a custom matcher function
  against each policy rule. In the Golang version, this uses govaluate for
  expression parsing - here we expect a function that takes a policy rule
  and returns a boolean.

  Parameters:
  - enforcer: The enforcer instance
  - ptype: Policy type (e.g., "p", "p2")
  - matcher: A function that takes a policy rule (list of strings) and returns true/false

  Returns {:ok, filtered_policies} or {:error, reason}

  Example:
      matcher = fn rule ->
        [sub, obj, act] = rule
        sub == "alice" and act == "read"
      end
      {:ok, policies} = get_filtered_named_policy_with_matcher(enforcer, "p", matcher)
  """
  def get_filtered_named_policy_with_matcher(
        %Enforcer{policies: policies},
        ptype,
        matcher
      )
      when is_function(matcher, 1) do
    policy_list = Map.get(policies, ptype, [])

    filtered =
      try do
        Enum.filter(policy_list, matcher)
      rescue
        e ->
          {:error, "matcher function error: #{inspect(e)}"}
      end

    case filtered do
      {:error, _reason} = error -> error
      result -> {:ok, result}
    end
  end

  def get_filtered_named_policy_with_matcher(_enforcer, _ptype, _matcher) do
    {:error, "matcher must be a function with arity 1"}
  end

  # Private helper functions

  defp update_role_manager_for_removed_policy(params, acc_enforcer) when length(params) >= 2 do
    [user, role | _rest] = params
    updated_rm = CasbinEx2.RoleManager.delete_link(acc_enforcer.role_manager, user, role)
    %{acc_enforcer | role_manager: updated_rm}
  end

  defp update_role_manager_for_removed_policy(_params, acc_enforcer), do: acc_enforcer
end
