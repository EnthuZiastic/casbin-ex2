defmodule CasbinEx2.RoleManager do
  @moduledoc """
  Role manager for handling role inheritance.
  """

  defstruct [:max_hierarchy_level, :roles]

  @type t :: %__MODULE__{
          max_hierarchy_level: integer(),
          roles: map()
        }

  @doc """
  Creates a new role manager with the specified max hierarchy level.
  """
  @spec new_role_manager(integer()) :: t()
  def new_role_manager(max_hierarchy_level \\ 10) do
    %__MODULE__{
      max_hierarchy_level: max_hierarchy_level,
      roles: %{}
    }
  end

  @doc """
  Clears all roles.
  """
  @spec clear(t()) :: t()
  def clear(role_manager) do
    %{role_manager | roles: %{}}
  end

  @doc """
  Adds an inheritance relation between role1 and role2.
  role1 inherits role2.
  """
  @spec add_link(t(), String.t(), String.t(), String.t()) :: t()
  def add_link(%__MODULE__{roles: roles} = role_manager, role1, role2, domain \\ "") do
    key = build_key(role1, domain)
    current_roles = Map.get(roles, key, MapSet.new())
    updated_roles = MapSet.put(current_roles, build_key(role2, domain))

    %{role_manager | roles: Map.put(roles, key, updated_roles)}
  end

  @doc """
  Removes an inheritance relation between role1 and role2.
  """
  @spec delete_link(t(), String.t(), String.t(), String.t()) :: t()
  def delete_link(%__MODULE__{roles: roles} = role_manager, role1, role2, domain \\ "") do
    key = build_key(role1, domain)
    current_roles = Map.get(roles, key, MapSet.new())
    updated_roles = MapSet.delete(current_roles, build_key(role2, domain))

    updated_map =
      if MapSet.size(updated_roles) == 0 do
        Map.delete(roles, key)
      else
        Map.put(roles, key, updated_roles)
      end

    %{role_manager | roles: updated_map}
  end

  @doc """
  Returns true if role1 has role2.
  """
  @spec has_link(t(), String.t(), String.t(), String.t()) :: boolean()
  def has_link(%__MODULE__{} = role_manager, role1, role2, domain \\ "") do
    if role1 == role2 do
      true
    else
      has_link_helper(role_manager, role1, role2, domain, 0)
    end
  end

  @doc """
  Gets all roles that a user has.
  """
  @spec get_roles(t(), String.t(), String.t()) :: [String.t()]
  def get_roles(%__MODULE__{roles: roles}, name, domain \\ "") do
    key = build_key(name, domain)

    case Map.get(roles, key) do
      nil ->
        []

      role_set ->
        role_set
        |> MapSet.to_list()
        |> Enum.map(&extract_role_from_key/1)
    end
  end

  @doc """
  Gets all users who have a role.
  """
  @spec get_users(t(), String.t(), String.t()) :: [String.t()]
  def get_users(%__MODULE__{roles: roles}, role, domain \\ "") do
    target_role_key = build_key(role, domain)

    roles
    |> Enum.filter(fn {_user_key, role_set} ->
      MapSet.member?(role_set, target_role_key)
    end)
    |> Enum.map(fn {user_key, _} -> extract_role_from_key(user_key) end)
  end

  @doc """
  Prints all the roles.
  """
  @spec print_roles(t()) :: :ok
  def print_roles(%__MODULE__{roles: roles}) do
    Enum.each(roles, fn {user_key, role_set} ->
      user = extract_role_from_key(user_key)
      role_list = role_set |> MapSet.to_list() |> Enum.map(&extract_role_from_key/1)
      IO.puts("#{user}: #{Enum.join(role_list, ", ")}")
    end)
  end

  # Private functions

  defp has_link_helper(role_manager, role1, role2, domain, level) do
    if level >= role_manager.max_hierarchy_level do
      false
    else
      check_role_hierarchy(role_manager, role1, role2, domain, level)
    end
  end

  defp check_role_hierarchy(role_manager, role1, role2, domain, level) do
    key = build_key(role1, domain)
    target_key = build_key(role2, domain)

    case Map.get(role_manager.roles, key) do
      nil -> false
      role_set -> check_role_membership(role_manager, role_set, role2, domain, level, target_key)
    end
  end

  defp check_role_membership(role_manager, role_set, role2, domain, level, target_key) do
    if MapSet.member?(role_set, target_key) do
      true
    else
      check_transitive_inheritance(role_manager, role_set, role2, domain, level)
    end
  end

  defp check_transitive_inheritance(role_manager, role_set, role2, domain, level) do
    role_set
    |> MapSet.to_list()
    |> Enum.any?(fn inherited_role_key ->
      inherited_role = extract_role_from_key(inherited_role_key)
      has_link_helper(role_manager, inherited_role, role2, domain, level + 1)
    end)
  end

  defp build_key(role, "") do
    role
  end

  defp build_key(role, domain) do
    "#{role}::#{domain}"
  end

  defp extract_role_from_key(key) do
    case String.split(key, "::", parts: 2) do
      [role] -> role
      [role, _domain] -> role
    end
  end
end
