defmodule CasbinEx2.ConditionalRoleManager do
  @moduledoc """
  Conditional role manager that extends the standard role manager with
  conditional link functions. Links can have conditions that must be
  satisfied for the link to be valid.
  """

  alias CasbinEx2.RoleManager

  defstruct [
    :role_manager,
    link_condition_funcs: %{},
    link_condition_params: %{}
  ]

  @type link_condition_func :: (map() -> boolean())
  @type t :: %__MODULE__{
          role_manager: RoleManager.t(),
          link_condition_funcs: %{String.t() => link_condition_func()},
          link_condition_params: %{String.t() => [String.t()]}
        }

  @doc """
  Creates a new conditional role manager wrapping a standard role manager.
  """
  @spec new(RoleManager.t()) :: t()
  def new(role_manager \\ RoleManager.new_role_manager()) do
    %__MODULE__{
      role_manager: role_manager,
      link_condition_funcs: %{},
      link_condition_params: %{}
    }
  end

  @doc """
  Adds a conditional link function for a user-role relationship.
  The link is only valid when the condition function returns true.

  ## Parameters
  - `cond_rm` - The conditional role manager
  - `user` - User name
  - `role` - Role name
  - `func` - Condition function that takes a map of parameters and returns boolean

  ## Returns
  Updated conditional role manager
  """
  @spec add_link_condition_func(t(), String.t(), String.t(), link_condition_func()) :: t()
  def add_link_condition_func(cond_rm, user, role, func) do
    key = build_link_key(user, role, "")
    updated_funcs = Map.put(cond_rm.link_condition_funcs, key, func)
    %{cond_rm | link_condition_funcs: updated_funcs}
  end

  @doc """
  Sets parameters for a conditional link function.

  ## Parameters
  - `cond_rm` - The conditional role manager
  - `user` - User name
  - `role` - Role name
  - `params` - List of parameter strings

  ## Returns
  Updated conditional role manager
  """
  @spec set_link_condition_func_params(t(), String.t(), String.t(), [String.t()]) :: t()
  def set_link_condition_func_params(cond_rm, user, role, params) do
    key = build_link_key(user, role, "")
    updated_params = Map.put(cond_rm.link_condition_params, key, params)
    %{cond_rm | link_condition_params: updated_params}
  end

  @doc """
  Adds a conditional link function for a user-role-domain relationship.
  The link is only valid when the condition function returns true.

  ## Parameters
  - `cond_rm` - The conditional role manager
  - `user` - User name
  - `role` - Role name
  - `domain` - Domain name
  - `func` - Condition function that takes a map of parameters and returns boolean

  ## Returns
  Updated conditional role manager
  """
  @spec add_domain_link_condition_func(
          t(),
          String.t(),
          String.t(),
          String.t(),
          link_condition_func()
        ) :: t()
  def add_domain_link_condition_func(cond_rm, user, role, domain, func) do
    key = build_link_key(user, role, domain)
    updated_funcs = Map.put(cond_rm.link_condition_funcs, key, func)
    %{cond_rm | link_condition_funcs: updated_funcs}
  end

  @doc """
  Sets parameters for a conditional domain link function.

  ## Parameters
  - `cond_rm` - The conditional role manager
  - `user` - User name
  - `role` - Role name
  - `domain` - Domain name
  - `params` - List of parameter strings

  ## Returns
  Updated conditional role manager
  """
  @spec set_domain_link_condition_func_params(
          t(),
          String.t(),
          String.t(),
          String.t(),
          [String.t()]
        ) :: t()
  def set_domain_link_condition_func_params(cond_rm, user, role, domain, params) do
    key = build_link_key(user, role, domain)
    updated_params = Map.put(cond_rm.link_condition_params, key, params)
    %{cond_rm | link_condition_params: updated_params}
  end

  @doc """
  Checks if a user-role link is valid by evaluating the condition function.

  ## Parameters
  - `cond_rm` - The conditional role manager
  - `user` - User name
  - `role` - Role name
  - `domain` - Domain name (optional, defaults to "")

  ## Returns
  True if the link is valid (no condition or condition returns true), false otherwise
  """
  @spec has_link(t(), String.t(), String.t(), String.t()) :: boolean()
  def has_link(cond_rm, user, role, domain \\ "") do
    # First check if the underlying role manager has the link
    if RoleManager.has_link(cond_rm.role_manager, user, role, domain) do
      # If there's a condition function, evaluate it
      evaluate_link_condition(cond_rm, user, role, domain)
    else
      false
    end
  end

  @doc """
  Adds an inheritance relation between role1 and role2.
  Delegates to the underlying role manager.
  """
  @spec add_link(t(), String.t(), String.t(), String.t()) :: t()
  def add_link(cond_rm, role1, role2, domain \\ "") do
    updated_rm = RoleManager.add_link(cond_rm.role_manager, role1, role2, domain)
    %{cond_rm | role_manager: updated_rm}
  end

  @doc """
  Removes an inheritance relation between role1 and role2.
  Delegates to the underlying role manager.
  """
  @spec delete_link(t(), String.t(), String.t(), String.t()) :: t()
  def delete_link(cond_rm, role1, role2, domain \\ "") do
    updated_rm = RoleManager.delete_link(cond_rm.role_manager, role1, role2, domain)
    %{cond_rm | role_manager: updated_rm}
  end

  @doc """
  Clears all roles and condition functions.
  """
  @spec clear(t()) :: t()
  def clear(cond_rm) do
    %{
      cond_rm
      | role_manager: RoleManager.clear(cond_rm.role_manager),
        link_condition_funcs: %{},
        link_condition_params: %{}
    }
  end

  # Private functions

  defp build_link_key(user, role, domain) when domain == "" or domain == nil do
    "#{user}::#{role}"
  end

  defp build_link_key(user, role, domain) do
    "#{user}::#{role}::#{domain}"
  end

  defp evaluate_link_condition(cond_rm, user, role, domain) do
    key = build_link_key(user, role, domain)

    case Map.get(cond_rm.link_condition_funcs, key) do
      nil ->
        # No condition function, link is valid
        true

      func ->
        # Get parameters if they exist
        params = Map.get(cond_rm.link_condition_params, key, [])
        # Convert parameter list to a map for the condition function
        param_map = parse_params_to_map(params)
        # Evaluate the condition function
        func.(param_map)
    end
  end

  defp parse_params_to_map(params) do
    # Parse parameters like ["key1=value1", "key2=value2"] into %{"key1" => "value1", "key2" => "value2"}
    Enum.reduce(params, %{}, fn param, acc ->
      case String.split(param, "=", parts: 2) do
        [key, value] -> Map.put(acc, String.trim(key), String.trim(value))
        _ -> acc
      end
    end)
  end
end
