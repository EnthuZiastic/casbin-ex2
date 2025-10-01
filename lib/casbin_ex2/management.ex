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
  Returns the number of rules removed.
  """
  def remove_filtered_policy(%Enforcer{} = enforcer, field_index, field_values) do
    remove_filtered_named_policy(enforcer, "p", field_index, field_values)
  end

  @doc """
  Removes authorization rules that match the filter from the current named policy.
  Returns the number of rules removed.
  """
  def remove_filtered_named_policy(
        %Enforcer{policies: policies} = enforcer,
        ptype,
        field_index,
        field_values
      ) do
    policy_list = Map.get(policies, ptype, [])

    {_matching_rules, remaining_rules} =
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
    {:ok, updated_enforcer}
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
end
