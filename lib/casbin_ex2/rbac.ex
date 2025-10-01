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
        case CasbinEx2.RoleManager.get_roles(rm, user, domain) do
          {:ok, roles} -> roles
          {:error, _} -> []
        end
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
        case CasbinEx2.RoleManager.get_users(rm, role, domain) do
          {:ok, users} -> users
          {:error, _} -> []
        end
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

    if Enum.empty?(roles) do
      {:error, "user has no roles"}
    else
      rules =
        Enum.map(roles, fn role ->
          if domain == "", do: [user, role], else: [user, role, domain]
        end)

      remove_grouping_policies(enforcer, rules)
    end
  end

  @doc """
  Deletes a user (remove user from all roles).
  Returns false if the user does not exist.
  """
  def delete_user(%Enforcer{grouping_policies: grouping_policies} = enforcer, user) do
    user_rules =
      grouping_policies
      |> Enum.flat_map(fn {_ptype, rules} ->
        Enum.filter(rules, fn rule -> List.first(rule) == user end)
      end)

    if Enum.empty?(user_rules) do
      {:error, "user does not exist"}
    else
      # Remove all grouping policies where user is the subject
      updated_grouping_policies =
        Enum.reduce(grouping_policies, %{}, fn {ptype, rules}, acc ->
          filtered_rules = Enum.reject(rules, fn rule -> List.first(rule) == user end)
          Map.put(acc, ptype, filtered_rules)
        end)

      # Also remove all policies where user is the subject
      updated_policies =
        Enum.reduce(enforcer.policies, %{}, fn {ptype, rules}, acc ->
          filtered_rules = Enum.reject(rules, fn rule -> List.first(rule) == user end)
          Map.put(acc, ptype, filtered_rules)
        end)

      # Also update the role_manager to remove user's roles
      updated_role_manager =
        case enforcer.role_manager do
          nil ->
            nil

          role_manager ->
            # Get all roles the user has and remove them from role_manager
            user_roles =
              user_rules
              |> Enum.map(fn rule ->
                case rule do
                  [_user, role] -> {role, ""}
                  [_user, role, domain] -> {role, domain}
                  _ -> nil
                end
              end)
              |> Enum.reject(&is_nil/1)

            # Remove each role link from the role_manager
            Enum.reduce(user_roles, role_manager, fn {role, domain}, rm ->
              CasbinEx2.RoleManager.delete_link(rm, user, role, domain)
            end)
        end

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
    role_rules =
      grouping_policies
      |> Enum.flat_map(fn {_ptype, rules} ->
        Enum.filter(rules, fn rule -> Enum.at(rule, 1) == role end)
      end)

    if Enum.empty?(role_rules) do
      {:error, "role does not exist"}
    else
      # Remove all grouping policies where role is the object
      updated_grouping_policies =
        Enum.reduce(grouping_policies, %{}, fn {ptype, rules}, acc ->
          filtered_rules = Enum.reject(rules, fn rule -> Enum.at(rule, 1) == role end)
          Map.put(acc, ptype, filtered_rules)
        end)

      # Also update the role_manager to remove role links
      updated_role_manager =
        case enforcer.role_manager do
          nil ->
            nil

          role_manager ->
            # Get all users that have this role and remove the links
            user_role_pairs =
              role_rules
              |> Enum.map(fn rule ->
                case rule do
                  [user, _role] -> {user, ""}
                  [user, _role, domain] -> {user, domain}
                  _ -> nil
                end
              end)
              |> Enum.reject(&is_nil/1)

            # Remove each role link from the role_manager
            Enum.reduce(user_role_pairs, role_manager, fn {user, domain}, rm ->
              CasbinEx2.RoleManager.delete_link(rm, user, role, domain)
            end)
        end

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
    permission_rules =
      policies
      |> Enum.flat_map(fn {_ptype, rules} ->
        Enum.filter(rules, fn rule ->
          Enum.drop(rule, 1) == permission
        end)
      end)

    if Enum.empty?(permission_rules) do
      {:error, "permission does not exist"}
    else
      # Remove all policies that match the permission
      updated_policies =
        Enum.reduce(policies, %{}, fn {ptype, rules}, acc ->
          filtered_rules =
            Enum.reject(rules, fn rule ->
              Enum.drop(rule, 1) == permission
            end)

          Map.put(acc, ptype, filtered_rules)
        end)

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
      |> Enum.filter(fn rule ->
        case rule do
          [^user | _rest] when domain == "" ->
            true

          [^user | rest] ->
            # Check if domain matches (domain is usually the last element)
            List.last(rest) == domain

          _ ->
            false
        end
      end)
      |> Enum.map(fn rule ->
        case rule do
          [^user | rest] when domain == "" ->
            rest

          [^user | rest] ->
            # Remove domain from the end if it matches
            if List.last(rest) == domain do
              List.delete_at(rest, -1)
            else
              rest
            end
        end
      end)
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
    case Map.get(policies, ptype) do
      nil ->
        []

      policy_list ->
        Enum.filter(policy_list, fn rule ->
          case rule do
            [^user | _rest] when domain == "" ->
              true

            [^user | rest] ->
              # Check if domain matches (domain is usually the last element)
              List.last(rest) == domain

            _ ->
              false
          end
        end)
    end
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
      nil ->
        []

      rm ->
        # Get all roles recursively
        case CasbinEx2.RoleManager.get_roles(rm, user, domain) do
          {:ok, direct_roles} ->
            # Get implicit roles by traversing the role hierarchy
            direct_roles
            |> Enum.reduce(MapSet.new(), fn role, acc ->
              case CasbinEx2.RoleManager.get_roles(rm, role, domain) do
                {:ok, indirect_roles} ->
                  MapSet.union(acc, MapSet.new([role | indirect_roles]))

                {:error, _} ->
                  MapSet.put(acc, role)
              end
            end)
            |> MapSet.to_list()

          {:error, _} ->
            []

          direct_roles when is_list(direct_roles) ->
            # Handle case where RoleManager returns list directly
            direct_roles
            |> Enum.reduce(MapSet.new(), fn role, acc ->
              case CasbinEx2.RoleManager.get_roles(rm, role, domain) do
                {:ok, indirect_roles} ->
                  MapSet.union(acc, MapSet.new([role | indirect_roles]))

                {:error, _} ->
                  MapSet.put(acc, role)

                indirect_roles when is_list(indirect_roles) ->
                  MapSet.union(acc, MapSet.new([role | indirect_roles]))
              end
            end)
            |> MapSet.to_list()
        end
    end
  end

  @doc """
  Gets implicit permissions for a user.
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

  @doc """
  Gets users for a role in a specific domain.
  """
  def get_users_for_role_in_domain(%Enforcer{grouping_policies: grouping_policies}, role, domain) do
    grouping_policies
    |> Enum.flat_map(fn {_ptype, policy_list} ->
      policy_list
      |> Enum.filter(fn rule ->
        case rule do
          [_user, ^role, ^domain] -> true
          [_user, ^role] when domain == "" -> true
          _ -> false
        end
      end)
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
      |> Enum.filter(fn rule ->
        case rule do
          [^user, _role, ^domain] -> true
          [^user, _role] when domain == "" -> true
          _ -> false
        end
      end)
      |> Enum.map(fn [_user, role | _] -> role end)
    end)
    |> Enum.uniq()
  end

  @doc """
  Gets permissions for a user in a specific domain.
  """
  def get_permissions_for_user_in_domain(%Enforcer{policies: policies} = enforcer, user, domain) do
    # Get direct permissions
    direct_permissions =
      policies
      |> Enum.flat_map(fn {_ptype, policy_list} ->
        Enum.filter(policy_list, fn rule ->
          case rule do
            [^user | rest] ->
              # Check if domain matches (domain is usually the last element)
              List.last(rest) == domain

            _ ->
              false
          end
        end)
      end)

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
         %Enforcer{grouping_policies: grouping_policies} = enforcer,
         ptype,
         params
       ) do
    if has_named_grouping_policy(enforcer, ptype, params) do
      policy_list = Map.get(grouping_policies, ptype, [])
      updated_policy_list = List.delete(policy_list, params)
      updated_policies = Map.put(grouping_policies, ptype, updated_policy_list)
      updated_enforcer = %{enforcer | grouping_policies: updated_policies}
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
end
