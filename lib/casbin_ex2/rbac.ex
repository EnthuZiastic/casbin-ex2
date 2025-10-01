defmodule CasbinEx2.RBAC do
  @moduledoc """
  RBAC API for Casbin role-based access control.

  This module provides functions for role-based access control including:
  - Role assignment and removal
  - User and role queries
  - Permission management
  - Implicit role and permission resolution

  Corresponds to rbac_api.go in the Golang Casbin implementation.
  """

  alias CasbinEx2.Enforcer
  alias CasbinEx2.Management

  @doc """
  Gets the roles that a user has.
  """
  def get_roles_for_user(%Enforcer{role_manager: role_manager}, user, domain \\ "") do
    case role_manager do
      nil ->
        []

      rm ->
        CasbinEx2.RoleManager.get_roles(rm, user, domain)
    end
  end

  @doc """
  Gets the users that have a role.
  """
  def get_users_for_role(%Enforcer{role_manager: role_manager}, role, domain \\ "") do
    case role_manager do
      nil ->
        []

      rm ->
        CasbinEx2.RoleManager.get_users(rm, role, domain)
    end
  end

  @doc """
  Determines whether a user has a role.
  """
  def has_role_for_user(%Enforcer{} = enforcer, user, role, domain \\ "") do
    roles = get_roles_for_user(enforcer, user, domain)
    role in roles
  end

  @doc """
  Adds a role for a user.
  Returns false if the user already has the role.
  """
  def add_role_for_user(%Enforcer{} = enforcer, user, role, domain \\ "") do
    params = if domain == "", do: [user, role], else: [user, role, domain]
    add_grouping_policy(enforcer, params)
  end

  @doc """
  Adds roles for a user.
  Returns false if the user already has any of the roles.
  """
  def add_roles_for_user(%Enforcer{} = enforcer, user, roles, domain \\ "") do
    rules =
      Enum.map(roles, fn role ->
        if domain == "", do: [user, role], else: [user, role, domain]
      end)

    add_grouping_policies(enforcer, rules)
  end

  @doc """
  Deletes a role for a user.
  Returns false if the user does not have the role.
  """
  def delete_role_for_user(%Enforcer{} = enforcer, user, role, domain \\ "") do
    params = if domain == "", do: [user, role], else: [user, role, domain]
    remove_grouping_policy(enforcer, params)
  end

  @doc """
  Deletes all roles for a user.
  Returns false if the user does not have any roles.
  """
  def delete_roles_for_user(%Enforcer{} = enforcer, user, domain \\ "") do
    roles = get_roles_for_user(enforcer, user, domain)

    case roles do
      [] ->
        {:error, "user has no roles"}

      _ ->
        rules = build_role_rules(roles, user, domain)
        remove_grouping_policies(enforcer, rules)
    end
  end

  @doc """
  Deletes a user (remove user from all roles).
  Returns false if the user does not exist.
  """
  def delete_user(%Enforcer{grouping_policies: grouping_policies} = enforcer, user) do
    user_rules = find_user_rules(grouping_policies, user)

    case user_rules do
      [] ->
        {:error, "user does not exist"}

      _ ->
        updated_grouping_policies = remove_user_from_grouping_policies(grouping_policies, user)
        updated_policies = remove_user_from_policies(enforcer.policies, user)

        updated_role_manager =
          update_role_manager_for_user_deletion(enforcer.role_manager, user, user_rules)

        updated_enforcer = %{
          enforcer
          | grouping_policies: updated_grouping_policies,
            policies: updated_policies,
            role_manager: updated_role_manager
        }

        {:ok, updated_enforcer}
    end
  end

  @doc """
  Deletes a role.
  Returns false if the role does not exist.
  """
  def delete_role(%Enforcer{grouping_policies: grouping_policies} = enforcer, role) do
    role_rules = find_role_rules(grouping_policies, role)

    case role_rules do
      [] ->
        {:error, "role does not exist"}

      _ ->
        updated_grouping_policies = remove_role_from_grouping_policies(grouping_policies, role)

        updated_role_manager =
          update_role_manager_for_role_deletion(enforcer.role_manager, role, role_rules)

        updated_enforcer = %{
          enforcer
          | grouping_policies: updated_grouping_policies,
            role_manager: updated_role_manager
        }

        {:ok, updated_enforcer}
    end
  end

  @doc """
  Deletes a permission.
  Returns false if the permission does not exist.
  """
  def delete_permission(%Enforcer{policies: policies} = enforcer, permission)
      when is_list(permission) do
    permission_rules = find_permission_rules(policies, permission)

    case permission_rules do
      [] ->
        {:error, "permission does not exist"}

      _ ->
        updated_policies = remove_permission_from_policies(policies, permission)
        updated_enforcer = %{enforcer | policies: updated_policies}
        {:ok, updated_enforcer}
    end
  end

  @doc """
  Adds a permission for a user or role.
  Returns false if the user or role already has the permission.
  """
  def add_permission_for_user(%Enforcer{} = enforcer, user, permission)
      when is_list(permission) do
    params = [user | permission]

    case Management.add_policy(enforcer, params) do
      {:ok, updated_enforcer} -> {:ok, updated_enforcer}
      {:error, "policy already exists"} -> {:ok, enforcer}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Adds permissions for a user or role.
  Returns {:ok, enforcer} if successful, even if some permissions already exist.
  """
  def add_permissions_for_user(%Enforcer{} = enforcer, user, permissions)
      when is_list(permissions) do
    rules = Enum.map(permissions, fn permission -> [user | permission] end)

    # Add policies one by one, allowing duplicates to succeed
    Enum.reduce_while(rules, {:ok, enforcer}, fn rule, {_acc, current_enforcer} ->
      case Management.add_policy(current_enforcer, rule) do
        {:ok, updated_enforcer} -> {:cont, {:ok, updated_enforcer}}
        {:error, "policy already exists"} -> {:cont, {:ok, current_enforcer}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Deletes a permission for a user or role.
  Returns false if the user or role does not have the permission.
  """
  def delete_permission_for_user(%Enforcer{} = enforcer, user, permission)
      when is_list(permission) do
    params = [user | permission]
    Management.remove_policy(enforcer, params)
  end

  @doc """
  Deletes permissions for a user or role.
  Returns false if the user or role does not have any of the permissions.
  """
  def delete_permissions_for_user(%Enforcer{policies: policies} = enforcer, user) do
    user_policies =
      policies
      |> Enum.flat_map(fn {_ptype, rules} ->
        Enum.filter(rules, fn rule -> List.first(rule) == user end)
      end)

    if Enum.empty?(user_policies) do
      {:error, "user has no permissions"}
    else
      Management.remove_policies(enforcer, user_policies)
    end
  end

  @doc """
  Gets permissions for a user or role.
  """
  def get_permissions_for_user(%Enforcer{policies: policies} = _enforcer, user, domain \\ "") do
    policies
    |> Enum.flat_map(fn {_ptype, policy_list} ->
      policy_list
      |> Enum.filter(&filter_user_rule(&1, user, domain))
      |> Enum.map(&extract_permission_from_rule(&1, user, domain))
    end)
  end

  @doc """
  Gets permissions for a user or role in a named policy.
  """
  def get_named_permissions_for_user(
        %Enforcer{policies: policies} = _enforcer,
        ptype,
        user,
        domain \\ ""
      ) do
    policies
    |> Map.get(ptype, [])
    |> Enum.filter(&filter_user_rule(&1, user, domain))
  end

  @doc """
  Determines whether a user has a permission.
  """
  def has_permission_for_user(%Enforcer{} = enforcer, user, permission)
      when is_list(permission) do
    params = [user | permission]
    Management.has_policy(enforcer, params)
  end

  @doc """
  Gets implicit roles for a user.
  """
  def get_implicit_roles_for_user(
        %Enforcer{role_manager: role_manager} = _enforcer,
        user,
        domain \\ ""
      ) do
    case role_manager do
      nil -> []
      rm -> get_roles_recursively(rm, user, domain)
    end
  end

  @doc """
  Gets implicit permissions for a user.

  Note: This function returns permissions WITHOUT the subject field for backward compatibility.
  Use get_implicit_permissions_for_user_with_subject/3 for the full policy including subject.
  """
  def get_implicit_permissions_for_user(%Enforcer{} = enforcer, user, domain \\ "") do
    # Get direct permissions
    direct_permissions = get_permissions_for_user(enforcer, user, domain)

    # Get permissions through roles
    roles = get_implicit_roles_for_user(enforcer, user, domain)

    role_permissions =
      roles
      |> Enum.flat_map(fn role ->
        get_permissions_for_user(enforcer, role, domain)
      end)

    # Combine and deduplicate
    (direct_permissions ++ role_permissions)
    |> Enum.uniq()
  end

  @doc false
  # Internal function that returns full policies including the subject field.
  # Used by get_implicit_resources_for_user and get_allowed_object_conditions.
  defp get_implicit_permissions_for_user_with_subject(%Enforcer{} = enforcer, user, domain \\ "") do
    # Use the named version with default ptype "p" and gtype "g"
    # This returns full policies including the subject
    get_named_implicit_permissions_for_user(enforcer, "p", "g", user, domain)
  end

  @doc """
  Gets users for a role in a specific domain.
  """
  def get_users_for_role_in_domain(%Enforcer{grouping_policies: grouping_policies}, role, domain) do
    grouping_policies
    |> Enum.flat_map(fn {_ptype, policy_list} ->
      policy_list
      |> Enum.filter(&filter_role_rule(&1, role, domain))
      |> Enum.map(fn [user | _] -> user end)
    end)
    |> Enum.uniq()
  end

  @doc """
  Gets roles for a user in a specific domain.
  """
  def get_roles_for_user_in_domain(%Enforcer{grouping_policies: grouping_policies}, user, domain) do
    grouping_policies
    |> Enum.flat_map(fn {_ptype, policy_list} ->
      policy_list
      |> Enum.filter(&filter_user_domain_rule(&1, user, domain))
      |> Enum.map(fn [_user, role | _] -> role end)
    end)
    |> Enum.uniq()
  end

  @doc """
  Gets permissions for a user in a specific domain.
  """
  def get_permissions_for_user_in_domain(%Enforcer{policies: policies} = enforcer, user, domain) do
    # Get direct permissions
    direct_permissions = get_direct_permissions_in_domain(policies, user, domain)

    # Get permissions through roles in this domain
    roles = get_roles_for_user_in_domain(enforcer, user, domain)

    role_permissions =
      roles
      |> Enum.flat_map(fn role ->
        get_permissions_for_user_in_domain(enforcer, role, domain)
      end)

    # Combine and deduplicate
    (direct_permissions ++ role_permissions)
    |> Enum.uniq()
  end

  @doc """
  Adds a role for a user in a specific domain.
  """
  def add_role_for_user_in_domain(%Enforcer{} = enforcer, user, role, domain) do
    params = [user, role, domain]
    add_grouping_policy(enforcer, params)
  end

  @doc """
  Deletes a role for a user in a specific domain.
  """
  def delete_role_for_user_in_domain(%Enforcer{} = enforcer, user, role, domain) do
    params = [user, role, domain]
    remove_grouping_policy(enforcer, params)
  end

  # Helper functions for grouping policy management

  defp add_grouping_policy(%Enforcer{grouping_policies: _grouping_policies} = enforcer, params) do
    add_named_grouping_policy(enforcer, "g", params)
  end

  defp add_named_grouping_policy(
         %Enforcer{grouping_policies: grouping_policies, role_manager: role_manager} = enforcer,
         ptype,
         params
       ) do
    if has_named_grouping_policy(enforcer, ptype, params) do
      {:error, "grouping policy already exists"}
    else
      updated_policies = Map.update(grouping_policies, ptype, [params], &(&1 ++ [params]))

      # Update role manager
      updated_role_manager =
        case {role_manager, params} do
          {nil, _} ->
            nil

          {rm, [user, role]} ->
            CasbinEx2.RoleManager.add_link(rm, user, role, "")

          {rm, [user, role, domain]} ->
            CasbinEx2.RoleManager.add_link(rm, user, role, domain)

          {rm, _} ->
            rm
        end

      updated_enforcer = %{
        enforcer
        | grouping_policies: updated_policies,
          role_manager: updated_role_manager
      }

      {:ok, updated_enforcer}
    end
  end

  defp add_grouping_policies(%Enforcer{} = enforcer, rules) do
    add_named_grouping_policies(enforcer, "g", rules)
  end

  defp add_named_grouping_policies(%Enforcer{} = enforcer, ptype, rules) do
    Enum.reduce_while(rules, {:ok, enforcer}, fn rule, {_acc, current_enforcer} ->
      case add_named_grouping_policy(current_enforcer, ptype, rule) do
        {:ok, updated_enforcer} -> {:cont, {:ok, updated_enforcer}}
        {:error, "grouping policy already exists"} -> {:cont, {:ok, current_enforcer}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp remove_grouping_policy(%Enforcer{} = enforcer, params) do
    remove_named_grouping_policy(enforcer, "g", params)
  end

  defp remove_named_grouping_policy(
         %Enforcer{grouping_policies: grouping_policies, role_manager: role_manager} = enforcer,
         ptype,
         params
       ) do
    if has_named_grouping_policy(enforcer, ptype, params) do
      policy_list = Map.get(grouping_policies, ptype, [])
      updated_policy_list = List.delete(policy_list, params)
      updated_policies = Map.put(grouping_policies, ptype, updated_policy_list)

      # Update role manager
      updated_role_manager =
        case {role_manager, params} do
          {nil, _} ->
            nil

          {rm, [user, role]} ->
            CasbinEx2.RoleManager.delete_link(rm, user, role, "")

          {rm, [user, role, domain]} ->
            CasbinEx2.RoleManager.delete_link(rm, user, role, domain)

          {rm, _} ->
            rm
        end

      updated_enforcer = %{
        enforcer
        | grouping_policies: updated_policies,
          role_manager: updated_role_manager
      }

      {:ok, updated_enforcer}
    else
      {:error, "grouping policy does not exist"}
    end
  end

  defp remove_grouping_policies(%Enforcer{} = enforcer, rules) do
    remove_named_grouping_policies(enforcer, "g", rules)
  end

  defp remove_named_grouping_policies(%Enforcer{} = enforcer, ptype, rules) do
    Enum.reduce_while(rules, {:ok, enforcer}, fn rule, {_acc, current_enforcer} ->
      case remove_named_grouping_policy(current_enforcer, ptype, rule) do
        {:ok, updated_enforcer} -> {:cont, {:ok, updated_enforcer}}
        {:error, _reason} -> {:halt, {:error, "failed to remove grouping policies"}}
      end
    end)
  end

  defp has_named_grouping_policy(%Enforcer{grouping_policies: grouping_policies}, ptype, params) do
    policy_list = Map.get(grouping_policies, ptype, [])
    params in policy_list
  end

  # Helper functions for delete_user
  defp find_user_rules(grouping_policies, user) do
    grouping_policies
    |> Enum.flat_map(fn {_ptype, rules} ->
      Enum.filter(rules, fn rule -> List.first(rule) == user end)
    end)
  end

  defp remove_user_from_grouping_policies(grouping_policies, user) do
    Enum.reduce(grouping_policies, %{}, fn {ptype, rules}, acc ->
      filtered_rules = Enum.reject(rules, fn rule -> List.first(rule) == user end)
      Map.put(acc, ptype, filtered_rules)
    end)
  end

  defp remove_user_from_policies(policies, user) do
    Enum.reduce(policies, %{}, fn {ptype, rules}, acc ->
      filtered_rules = Enum.reject(rules, fn rule -> List.first(rule) == user end)
      Map.put(acc, ptype, filtered_rules)
    end)
  end

  defp update_role_manager_for_user_deletion(nil, _user, _user_rules), do: nil

  defp update_role_manager_for_user_deletion(role_manager, user, user_rules) do
    user_roles = extract_user_roles(user_rules)

    Enum.reduce(user_roles, role_manager, fn {role, domain}, rm ->
      CasbinEx2.RoleManager.delete_link(rm, user, role, domain)
    end)
  end

  defp extract_user_roles(user_rules) do
    user_rules
    |> Enum.map(fn rule ->
      case rule do
        [_user, role] -> {role, ""}
        [_user, role, domain] -> {role, domain}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Helper functions for delete_role
  defp find_role_rules(grouping_policies, role) do
    grouping_policies
    |> Enum.flat_map(fn {_ptype, rules} ->
      Enum.filter(rules, fn rule -> Enum.at(rule, 1) == role end)
    end)
  end

  defp remove_role_from_grouping_policies(grouping_policies, role) do
    Enum.reduce(grouping_policies, %{}, fn {ptype, rules}, acc ->
      filtered_rules = Enum.reject(rules, fn rule -> Enum.at(rule, 1) == role end)
      Map.put(acc, ptype, filtered_rules)
    end)
  end

  defp update_role_manager_for_role_deletion(nil, _role, _role_rules), do: nil

  defp update_role_manager_for_role_deletion(role_manager, role, role_rules) do
    user_role_pairs = extract_user_role_pairs(role_rules)

    Enum.reduce(user_role_pairs, role_manager, fn {user, domain}, rm ->
      CasbinEx2.RoleManager.delete_link(rm, user, role, domain)
    end)
  end

  defp extract_user_role_pairs(role_rules) do
    role_rules
    |> Enum.map(fn rule ->
      case rule do
        [user, _role] -> {user, ""}
        [user, _role, domain] -> {user, domain}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Helper functions for delete_permission
  defp find_permission_rules(policies, permission) do
    policies
    |> Enum.flat_map(fn {_ptype, rules} ->
      Enum.filter(rules, fn rule ->
        Enum.drop(rule, 1) == permission
      end)
    end)
  end

  defp remove_permission_from_policies(policies, permission) do
    Enum.reduce(policies, %{}, fn {ptype, rules}, acc ->
      filtered_rules =
        Enum.reject(rules, fn rule ->
          Enum.drop(rule, 1) == permission
        end)

      Map.put(acc, ptype, filtered_rules)
    end)
  end

  # Helper functions for get_permissions_for_user
  defp filter_user_rule(rule, user, domain) do
    case rule do
      [^user | _rest] when domain == "" ->
        true

      [^user | rest] ->
        List.last(rest) == domain

      _ ->
        false
    end
  end

  defp extract_permission_from_rule(rule, user, domain) do
    case rule do
      [^user | rest] when domain == "" ->
        rest

      [^user | rest] ->
        if List.last(rest) == domain do
          List.delete_at(rest, -1)
        else
          rest
        end
    end
  end

  # Helper functions for get_implicit_roles_for_user
  defp get_roles_recursively(role_manager, user, domain) do
    case CasbinEx2.RoleManager.get_roles(role_manager, user, domain) do
      {:ok, direct_roles} ->
        build_implicit_roles_set(role_manager, direct_roles, domain)

      {:error, _} ->
        []

      direct_roles when is_list(direct_roles) ->
        build_implicit_roles_set(role_manager, direct_roles, domain)
    end
  end

  defp build_implicit_roles_set(role_manager, direct_roles, domain) do
    direct_roles
    |> Enum.reduce(MapSet.new(), fn role, acc ->
      get_role_hierarchy(role_manager, role, domain, acc)
    end)
    |> MapSet.to_list()
  end

  defp get_role_hierarchy(role_manager, role, domain, acc) do
    updated_acc = MapSet.put(acc, role)

    case CasbinEx2.RoleManager.get_roles(role_manager, role, domain) do
      {:ok, indirect_roles} ->
        MapSet.union(updated_acc, MapSet.new(indirect_roles))

      {:error, _} ->
        updated_acc

      indirect_roles when is_list(indirect_roles) ->
        MapSet.union(updated_acc, MapSet.new(indirect_roles))
    end
  end

  # Helper functions for domain-specific functions
  defp filter_role_rule(rule, role, domain) do
    case rule do
      [_user, ^role, ^domain] -> true
      [_user, ^role] when domain == "" -> true
      _ -> false
    end
  end

  defp filter_user_domain_rule(rule, user, domain) do
    case rule do
      [^user, _role, ^domain] -> true
      [^user, _role] when domain == "" -> true
      _ -> false
    end
  end

  defp get_direct_permissions_in_domain(policies, user, domain) do
    policies
    |> Enum.flat_map(fn {_ptype, policy_list} ->
      Enum.filter(policy_list, &filter_user_permission_domain_rule(&1, user, domain))
    end)
  end

  defp filter_user_permission_domain_rule(rule, user, domain) do
    case rule do
      [^user | rest] ->
        List.last(rest) == domain

      _ ->
        false
    end
  end

  # Helper function for delete_roles_for_user
  defp build_role_rules(roles, user, domain) do
    Enum.map(roles, fn role ->
      if domain == "", do: [user, role], else: [user, role, domain]
    end)
  end

  @doc """
  Gets implicit roles for a user by named role definition.

  Compared to `get_implicit_roles_for_user/3`, this function retrieves roles
  from a specific named role definition (ptype).

  ## Examples

      # g, alice, role:admin
      # g, role:admin, role:user
      # g2, alice, role:admin2

      # Get roles from "g2"
      get_named_implicit_roles_for_user(enforcer, "g2", "alice")
      # Returns: ["role:admin2"]
  """
  def get_named_implicit_roles_for_user(
        %Enforcer{} = enforcer,
        _ptype,
        name,
        domain \\ ""
      ) do
    # Get direct roles first
    direct_roles = get_roles_for_user(enforcer, name, domain)

    # Recursively get roles for each direct role (transitive closure)
    all_roles =
      Enum.reduce(direct_roles, direct_roles, fn role, acc ->
        indirect_roles = get_roles_for_user(enforcer, role, domain)
        Enum.uniq(acc ++ indirect_roles)
      end)

    all_roles
  end

  @doc """
  Gets implicit users for a role.

  Returns all users that have the given role, including indirect assignments
  through role hierarchies.

  ## Examples

      # p, admin, data1, read
      # g, alice, admin
      # g, bob, manager
      # g, manager, admin

      get_implicit_users_for_role(enforcer, "admin")
      # Returns: ["alice", "bob"]
  """
  def get_implicit_users_for_role(
        %Enforcer{} = enforcer,
        name,
        domain \\ ""
      ) do
    # Get direct users for the role
    direct_users = get_users_for_role(enforcer, name, domain)

    # Get all roles and find which ones lead to our target role
    all_roles = Management.get_all_roles(enforcer)

    # Find roles that have our target role (recursively)
    indirect_users =
      Enum.flat_map(all_roles, fn role ->
        # Check if this role has our target role
        roles_for_this_role = get_roles_for_user(enforcer, role, domain)

        if name in roles_for_this_role do
          # This role leads to our target, get its users
          get_users_for_role(enforcer, role, domain)
        else
          []
        end
      end)

    Enum.uniq(direct_users ++ indirect_users)
  end

  @doc """
  Gets implicit permissions for a user or role by named policy.

  Compared to `get_implicit_permissions_for_user/3`, this function retrieves
  permissions for a specific named policy (ptype) and grouping policy (gtype).

  ## Examples

      # p, admin, data1, read
      # p2, admin, create
      # g, alice, admin

      # Get permissions from "p2"
      get_named_implicit_permissions_for_user(enforcer, "p2", "g", "alice")
      # Returns: [["admin", "create"]]
  """
  def get_named_implicit_permissions_for_user(
        %Enforcer{policies: policies} = enforcer,
        ptype,
        gtype,
        user,
        domain \\ ""
      ) do
    # Get implicit roles for the user using the specified gtype
    roles =
      case get_named_implicit_roles_for_user(enforcer, gtype, user, domain) do
        {:error, _reason} -> []
        roles when is_list(roles) -> roles
      end

    # Build set of policy roles (user + inherited roles)
    policy_roles = MapSet.new([user | roles])

    # Get policies from the specified ptype
    policy_list = Map.get(policies, ptype, [])

    # Filter policies by domain if specified
    filtered_policies =
      if domain == "" do
        # No domain filtering
        Enum.filter(policy_list, fn [sub | _rest] ->
          MapSet.member?(policy_roles, sub)
        end)
      else
        # With domain filtering - domain is typically the last element
        Enum.filter(policy_list, fn rule ->
          case rule do
            [sub | _rest] when length(rule) > 2 ->
              domain_field = List.last(rule)
              MapSet.member?(policy_roles, sub) and domain_field == domain

            _ ->
              false
          end
        end)
      end

    filtered_policies
  end

  @doc """
  Gets implicit users for a permission.

  Returns all users (not roles) that have the specified permission,
  including users who have it through role inheritance.

  ## Examples

      # p, admin, data1, read
      # p, bob, data1, read
      # g, alice, admin

      get_implicit_users_for_permission(enforcer, "data1", "read")
      # Returns: ["alice", "bob"]

  Note: Only users will be returned, roles will be excluded.
  """
  def get_implicit_users_for_permission(%Enforcer{} = enforcer, permission)
      when is_list(permission) do
    # Get all subjects from policies
    all_subjects = Management.get_all_subjects(enforcer)

    # Get all roles from grouping policies
    all_roles = Management.get_all_roles(enforcer)
    role_set = MapSet.new(all_roles)

    # Filter to only actual users (not roles)
    users = Enum.reject(all_subjects, fn subject -> MapSet.member?(role_set, subject) end)

    # Check which users have the permission (directly or through roles)
    Enum.filter(users, fn user ->
      has_permission_for_user(enforcer, user, permission)
    end)
  end

  @doc """
  Gets all domains for a user.

  Returns all domains where the user has role assignments.

  ## Examples

      # g, alice, admin, domain1
      # g, alice, user, domain2

      get_domains_for_user(enforcer, "alice")
      # Returns: ["domain1", "domain2"]
  """
  def get_domains_for_user(%Enforcer{grouping_policies: grouping_policies}, user) do
    # Get all g policies
    g_policies = Map.get(grouping_policies, "g", [])

    # Extract domains from policies where user is the subject
    g_policies
    |> Enum.filter(fn policy ->
      case policy do
        [^user, _role, _domain | _rest] -> true
        _ -> false
      end
    end)
    |> Enum.map(fn [_user, _role, domain | _rest] -> domain end)
    |> Enum.uniq()
  end

  @doc """
  Gets implicit resources for a user.

  Returns all policies that the user has access to in the domain,
  including through role inheritance.

  ## Examples

      # p, alice, data1, read
      # p, admin, data2, write
      # g, alice, admin

      get_implicit_resources_for_user(enforcer, "alice")
      # Returns: [["alice", "data1", "read"], ["alice", "data2", "write"]]
  """
  def get_implicit_resources_for_user(
        %Enforcer{} = enforcer,
        user,
        domain \\ ""
      ) do
    # Get implicit permissions for the user WITH subject field
    permissions = get_implicit_permissions_for_user_with_subject(enforcer, user, domain)

    # Process permissions to expand role-based resources
    Enum.flat_map(permissions, fn permission ->
      [subject | rest] = permission

      if subject == user do
        # Direct permission for user
        [permission]
      else
        # Permission through a role - expand with user
        # Get all users who have this role
        implicit_users = get_implicit_users_for_role(enforcer, subject, domain)

        if user in implicit_users do
          # Create permission with user as subject
          [[user | rest]]
        else
          []
        end
      end
    end)
    |> Enum.uniq()
  end

  @doc """
  Gets allowed object conditions for a user.

  Returns object conditions that the user can access for a specific action.
  The prefix parameter is used to extract the condition part from the object.

  ## Examples

      # p, alice, r.obj.id == 1, read
      # p, alice, r.obj.id == 2, read

      get_allowed_object_conditions(enforcer, "alice", "read", "r.obj.")
      # Returns: {:ok, ["id == 1", "id == 2"]}

  Returns `{:error, :empty_condition}` if no conditions are found.
  Returns `{:error, :invalid_prefix}` if an object doesn't have the required prefix.
  """
  def get_allowed_object_conditions(
        %Enforcer{} = enforcer,
        user,
        action,
        prefix
      ) do
    # Get implicit permissions for the user WITH subject field
    permissions = get_implicit_permissions_for_user_with_subject(enforcer, user)

    # Extract object conditions for the specified action
    conditions =
      permissions
      |> Enum.filter(fn permission ->
        # permission format: [subject, object, action, ...]
        case permission do
          [_sub, _obj, act | _rest] -> act == action
          _ -> false
        end
      end)
      |> Enum.map(fn permission ->
        [_sub, obj | _rest] = permission

        if String.starts_with?(obj, prefix) do
          {:ok, String.trim_leading(obj, prefix)}
        else
          {:error, :invalid_prefix}
        end
      end)

    # Check for errors
    if Enum.any?(conditions, fn
         {:error, :invalid_prefix} -> true
         _ -> false
       end) do
      {:error, :invalid_prefix}
    else
      # Extract successful conditions
      result = Enum.map(conditions, fn {:ok, cond} -> cond end)

      if Enum.empty?(result) do
        {:error, :empty_condition}
      else
        {:ok, result}
      end
    end
  end

  @doc """
  Gets implicit users for a resource.

  Returns all users (with their full permission rules) who have access
  to the specified resource, including through role inheritance.
  Uses the default "g" grouping policy.

  ## Examples

      # p, admin, data1, read
      # p, bob, data2, write
      # g, alice, admin

      get_implicit_users_for_resource(enforcer, "data1")
      # Returns: [["alice", "data1", "read"]]
  """
  def get_implicit_users_for_resource(%Enforcer{} = enforcer, resource) do
    get_named_implicit_users_for_resource(enforcer, "g", resource)
  end

  @doc """
  Gets implicit users for a resource with named policy support.

  Returns all users who have access to the resource through the specified
  named grouping policy (ptype).

  ## Examples

      # p, admin_group, admin_data, *
      # g, admin, admin_group
      # g2, app, admin_data

      get_named_implicit_users_for_resource(enforcer, "g2", "admin_data")
      # Returns users with access through g2 relationships
  """
  def get_named_implicit_users_for_resource(
        %Enforcer{policies: policies, role_manager: role_manager} = enforcer,
        ptype,
        resource
      ) do
    # Get all roles
    all_roles = Management.get_all_roles(enforcer)
    role_set = MapSet.new(all_roles)

    # Get policies from the specified ptype (g, g2, etc.)
    ptype_policies = Management.get_named_grouping_policy(enforcer, ptype)

    # Build map of resource accessible resource types
    resource_accessible_types =
      Enum.reduce(ptype_policies, MapSet.new(), fn policy, acc ->
        case policy do
          [^resource, resource_type | _rest] -> MapSet.put(acc, resource_type)
          _ -> acc
        end
      end)

    # Get all p policies
    p_policies = Map.get(policies, "p", [])

    # Find permissions for the resource
    permissions =
      Enum.flat_map(p_policies, fn rule ->
        case rule do
          [sub, obj | _rest] ->
            # Check if this policy is for the resource or accessible resource type
            if obj == resource or MapSet.member?(resource_accessible_types, obj) do
              if MapSet.member?(role_set, sub) do
                # Subject is a role - get users for this role
                users =
                  case role_manager do
                    nil -> []
                    rm -> CasbinEx2.RoleManager.get_users(rm, sub, "")
                  end

                # Create permission for each user
                Enum.map(users, fn user ->
                  [user | tl(rule)]
                end)
              else
                # Subject is a user - include directly
                [rule]
              end
            else
              []
            end

          _ ->
            []
        end
      end)

    # Remove duplicates
    Enum.uniq(permissions)
  end

  @doc """
  Gets implicit users for a resource by domain.

  Returns all users who have access to the specified resource in the
  specified domain, including through role inheritance.

  ## Examples

      # p, admin, data1, read, domain1
      # p, alice, data2, read, domain1
      # g, bob, admin, domain1

      get_implicit_users_for_resource_by_domain(enforcer, "data1", "domain1")
      # Returns: [["bob", "data1", "read", "domain1"]]
  """
  def get_implicit_users_for_resource_by_domain(
        %Enforcer{policies: policies, role_manager: role_manager} = enforcer,
        resource,
        domain
      ) do
    # Get all roles in the domain
    all_roles_in_domain = get_all_roles_by_domain(enforcer, domain)
    role_set = MapSet.new(all_roles_in_domain)

    # Get all p policies
    p_policies = Map.get(policies, "p", [])

    # Find permissions for the resource in the domain
    permissions =
      Enum.flat_map(p_policies, fn rule ->
        case rule do
          # Assuming format: [sub, obj, act, domain]
          [sub, obj, _act, dom | _rest] ->
            if obj == resource and dom == domain do
              if MapSet.member?(role_set, sub) do
                # Subject is a role - get users for this role in domain
                users =
                  case role_manager do
                    nil -> []
                    rm -> CasbinEx2.RoleManager.get_users(rm, sub, domain)
                  end

                # Create permission for each user
                Enum.map(users, fn user ->
                  List.replace_at(rule, 0, user)
                end)
              else
                # Subject is a user - include directly
                [rule]
              end
            else
              []
            end

          _ ->
            []
        end
      end)

    # Remove duplicates
    Enum.uniq(permissions)
  end

  @doc """
  Gets all roles by domain.

  Returns all roles that exist in the specified domain.

  ## Examples

      # g, alice, admin, domain1
      # g, bob, user, domain1
      # g, charlie, moderator, domain2

      get_all_roles_by_domain(enforcer, "domain1")
      # Returns: ["admin", "user"]
  """
  def get_all_roles_by_domain(%Enforcer{grouping_policies: grouping_policies}, domain) do
    # Get all g policies
    g_policies = Map.get(grouping_policies, "g", [])

    # Extract roles from policies matching the domain
    g_policies
    |> Enum.filter(fn policy ->
      case policy do
        [_user, _role, dom | _rest] -> dom == domain
        _ -> false
      end
    end)
    |> Enum.map(fn [_user, role | _rest] -> role end)
    |> Enum.uniq()
  end

  @doc """
  Gets implicit object patterns for a user in a domain for a specific action.

  Returns all object patterns that the user has access to (directly or through roles)
  for the specified action in the specified domain.

  ## Parameters
  - `enforcer` - The enforcer struct
  - `user` - User name
  - `domain` - Domain name (use "" for default domain)
  - `action` - Action name (e.g., "read", "write")

  ## Returns
  List of object patterns

  ## Examples

      # p, alice, /data1/*, read
      # p, admin, /data2/*, write
      # g, alice, admin

      get_implicit_object_patterns_for_user(enforcer, "alice", "", "read")
      # Returns: ["/data1/*"]

      get_implicit_object_patterns_for_user(enforcer, "alice", "", "write")
      # Returns: ["/data2/*"] (through admin role)
  """
  @spec get_implicit_object_patterns_for_user(Enforcer.t(), String.t(), String.t(), String.t()) ::
          {:ok, [String.t()]} | {:error, term()}
  def get_implicit_object_patterns_for_user(
        %Enforcer{policies: policies} = enforcer,
        user,
        domain,
        action
      ) do
    # Get all implicit roles for the user in the domain
    roles_result = get_implicit_roles_for_user(enforcer, user, domain)

    roles =
      case roles_result do
        {:ok, role_list} -> role_list
        {:error, _} -> []
      end

    # Create list of subjects (user + all their roles)
    subjects = [user | roles]

    # Get all p policies
    p_policies = Map.get(policies, "p", [])

    # Find all object patterns for the subjects that match the action and domain
    patterns =
      p_policies
      |> Enum.filter(fn policy ->
        case policy do
          # Format: [sub, obj, act] for default domain
          [sub, _obj, act] when domain == "" ->
            sub in subjects and (act == action or act == "*")

          # Format: [sub, obj, act, dom] for specific domain
          [sub, _obj, act, dom] ->
            sub in subjects and dom == domain and (act == action or act == "*")

          # Format with more fields (e.g., [sub, dom, obj, act])
          [sub, dom, _obj, act] ->
            sub in subjects and dom == domain and (act == action or act == "*")

          _ ->
            false
        end
      end)
      |> Enum.map(fn policy ->
        case policy do
          [_sub, obj, _act] -> obj
          [_sub, obj, _act, _dom] -> obj
          [_sub, _dom, obj, _act] -> obj
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    {:ok, patterns}
  end
end
