defmodule CasbinEx2.ContextRoleManager do
  @moduledoc """
  Context-aware role manager for handling role inheritance with optional context propagation.

  This module extends the basic RoleManager with context-aware versions of all operations,
  which is useful for things like handling request timeouts, distributed tracing, and
  passing additional metadata through the role hierarchy operations.

  All context-aware functions have a `_ctx` suffix and accept an optional context map
  as the first parameter. This context can contain:
  - `:timeout` - Operation timeout in milliseconds
  - `:request_id` - Request tracking ID
  - `:metadata` - Additional metadata for the operation
  - Any custom fields needed by your application

  The underlying role management logic is delegated to `CasbinEx2.RoleManager`,
  so all the role hierarchy rules and behavior remain the same.
  """

  alias CasbinEx2.RoleManager

  @type context :: map()
  @type t :: RoleManager.t()

  @doc """
  Creates a new context-aware role manager with the specified max hierarchy level.

  ## Parameters
  - `max_hierarchy_level` - Maximum depth for role hierarchy traversal (default: 10)

  ## Returns
  A new role manager struct that can be used with both regular and context-aware operations.

  ## Examples
      iex> rm = CasbinEx2.ContextRoleManager.new_role_manager()
      iex> rm.max_hierarchy_level
      10

      iex> rm = CasbinEx2.ContextRoleManager.new_role_manager(5)
      iex> rm.max_hierarchy_level
      5
  """
  @spec new_role_manager(integer()) :: t()
  def new_role_manager(max_hierarchy_level \\ 10) do
    RoleManager.new_role_manager(max_hierarchy_level)
  end

  @doc """
  Clears all stored data and resets the role manager to the initial state with context.

  ## Parameters
  - `ctx` - Context map (can contain timeout, metadata, etc.)
  - `role_manager` - The role manager struct to clear

  ## Returns
  A cleared role manager struct with an empty roles map.

  ## Examples
      iex> rm = CasbinEx2.ContextRoleManager.new_role_manager()
      iex> rm = CasbinEx2.ContextRoleManager.add_link_ctx(%{}, rm, "alice", "admin")
      iex> rm = CasbinEx2.ContextRoleManager.clear_ctx(%{}, rm)
      iex> rm.roles
      %{}
  """
  @spec clear_ctx(context(), t()) :: t()
  def clear_ctx(_ctx, role_manager) do
    # Context can be used for logging, metrics, etc.
    RoleManager.clear(role_manager)
  end

  @doc """
  Adds the inheritance link between two roles with context.

  role: name1 inherits role: name2.
  domain is a prefix to the roles (can be used for other purposes).

  ## Parameters
  - `ctx` - Context map (can contain timeout, metadata, etc.)
  - `role_manager` - The role manager struct
  - `name1` - The role that will inherit permissions
  - `name2` - The role being inherited from
  - `domain` - Optional domain prefix (default: "")

  ## Returns
  Updated role manager with the new inheritance link.

  ## Examples
      iex> rm = CasbinEx2.ContextRoleManager.new_role_manager()
      iex> ctx = %{request_id: "req-123"}
      iex> rm = CasbinEx2.ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")
      iex> CasbinEx2.ContextRoleManager.has_link_ctx(ctx, rm, "alice", "admin")
      true
  """
  @spec add_link_ctx(context(), t(), String.t(), String.t(), String.t()) :: t()
  def add_link_ctx(_ctx, role_manager, name1, name2, domain \\ "") do
    # Context can be used for:
    # - Request tracing
    # - Logging who made the change
    # - Enforcing timeouts
    # - Distributed tracing
    RoleManager.add_link(role_manager, name1, name2, domain)
  end

  @doc """
  Deletes the inheritance link between two roles with context.

  role: name1 will no longer inherit role: name2.
  domain is a prefix to the roles (can be used for other purposes).

  ## Parameters
  - `ctx` - Context map (can contain timeout, metadata, etc.)
  - `role_manager` - The role manager struct
  - `name1` - The role that was inheriting
  - `name2` - The role being inherited from
  - `domain` - Optional domain prefix (default: "")

  ## Returns
  Updated role manager with the inheritance link removed.

  ## Examples
      iex> rm = CasbinEx2.ContextRoleManager.new_role_manager()
      iex> ctx = %{request_id: "req-124"}
      iex> rm = CasbinEx2.ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")
      iex> rm = CasbinEx2.ContextRoleManager.delete_link_ctx(ctx, rm, "alice", "admin")
      iex> CasbinEx2.ContextRoleManager.has_link_ctx(ctx, rm, "alice", "admin")
      false
  """
  @spec delete_link_ctx(context(), t(), String.t(), String.t(), String.t()) :: t()
  def delete_link_ctx(_ctx, role_manager, name1, name2, domain \\ "") do
    RoleManager.delete_link(role_manager, name1, name2, domain)
  end

  @doc """
  Determines whether a link exists between two roles with context.

  Checks if role: name1 inherits role: name2.
  domain is a prefix to the roles (can be used for other purposes).

  ## Parameters
  - `ctx` - Context map (can contain timeout, metadata, etc.)
  - `role_manager` - The role manager struct
  - `name1` - The role to check
  - `name2` - The role being checked for inheritance
  - `domain` - Optional domain prefix (default: "")

  ## Returns
  `true` if name1 has name2 (directly or transitively), `false` otherwise.

  ## Examples
      iex> rm = CasbinEx2.ContextRoleManager.new_role_manager()
      iex> ctx = %{timeout: 5000}
      iex> rm = CasbinEx2.ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")
      iex> rm = CasbinEx2.ContextRoleManager.add_link_ctx(ctx, rm, "admin", "superuser")
      iex> CasbinEx2.ContextRoleManager.has_link_ctx(ctx, rm, "alice", "superuser")
      true
  """
  @spec has_link_ctx(context(), t(), String.t(), String.t(), String.t()) :: boolean()
  def has_link_ctx(_ctx, role_manager, name1, name2, domain \\ "") do
    # Context timeout could be used to limit hierarchy traversal time
    RoleManager.has_link(role_manager, name1, name2, domain)
  end

  @doc """
  Gets the roles that a user inherits with context.

  domain is a prefix to the roles (can be used for other purposes).

  ## Parameters
  - `ctx` - Context map (can contain timeout, metadata, etc.)
  - `role_manager` - The role manager struct
  - `name` - The user/role name
  - `domain` - Optional domain prefix (default: "")

  ## Returns
  List of role names that the user directly inherits.

  ## Examples
      iex> rm = CasbinEx2.ContextRoleManager.new_role_manager()
      iex> ctx = %{metadata: %{source: "api"}}
      iex> rm = CasbinEx2.ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")
      iex> rm = CasbinEx2.ContextRoleManager.add_link_ctx(ctx, rm, "alice", "moderator")
      iex> roles = CasbinEx2.ContextRoleManager.get_roles_ctx(ctx, rm, "alice")
      iex> Enum.sort(roles)
      ["admin", "moderator"]
  """
  @spec get_roles_ctx(context(), t(), String.t(), String.t()) :: [String.t()]
  def get_roles_ctx(_ctx, role_manager, name, domain \\ "") do
    RoleManager.get_roles(role_manager, name, domain)
  end

  @doc """
  Gets the users that inherit a role with context.

  domain is a prefix to the users (can be used for other purposes).

  ## Parameters
  - `ctx` - Context map (can contain timeout, metadata, etc.)
  - `role_manager` - The role manager struct
  - `name` - The role name
  - `domain` - Optional domain prefix (default: "")

  ## Returns
  List of user names that directly inherit this role.

  ## Examples
      iex> rm = CasbinEx2.ContextRoleManager.new_role_manager()
      iex> ctx = %{request_id: "req-125"}
      iex> rm = CasbinEx2.ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin")
      iex> rm = CasbinEx2.ContextRoleManager.add_link_ctx(ctx, rm, "bob", "admin")
      iex> users = CasbinEx2.ContextRoleManager.get_users_ctx(ctx, rm, "admin")
      iex> Enum.sort(users)
      ["alice", "bob"]
  """
  @spec get_users_ctx(context(), t(), String.t(), String.t()) :: [String.t()]
  def get_users_ctx(_ctx, role_manager, name, domain \\ "") do
    RoleManager.get_users(role_manager, name, domain)
  end

  @doc """
  Gets domains that a user has with context.

  This extracts all unique domains from the role keys where the user appears.

  ## Parameters
  - `ctx` - Context map (can contain timeout, metadata, etc.)
  - `role_manager` - The role manager struct
  - `name` - The user name

  ## Returns
  List of domain names where the user has roles.

  ## Examples
      iex> rm = CasbinEx2.ContextRoleManager.new_role_manager()
      iex> ctx = %{}
      iex> rm = CasbinEx2.ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin", "domain1")
      iex> rm = CasbinEx2.ContextRoleManager.add_link_ctx(ctx, rm, "alice", "user", "domain2")
      iex> domains = CasbinEx2.ContextRoleManager.get_domains_ctx(ctx, rm, "alice")
      iex> Enum.sort(domains)
      ["domain1", "domain2"]
  """
  @spec get_domains_ctx(context(), t(), String.t()) :: [String.t()]
  def get_domains_ctx(_ctx, %RoleManager{roles: roles}, name) do
    roles
    |> Map.keys()
    |> Enum.filter(fn key ->
      extract_user_from_key(key) == name
    end)
    |> Enum.map(&extract_domain_from_key/1)
    |> Enum.filter(fn domain -> domain != "" end)
    |> Enum.uniq()
  end

  @doc """
  Gets all domains with context.

  Returns all unique domain identifiers found in the role manager.

  ## Parameters
  - `ctx` - Context map (can contain timeout, metadata, etc.)
  - `role_manager` - The role manager struct

  ## Returns
  List of all domain names in the role manager.

  ## Examples
      iex> rm = CasbinEx2.ContextRoleManager.new_role_manager()
      iex> ctx = %{}
      iex> rm = CasbinEx2.ContextRoleManager.add_link_ctx(ctx, rm, "alice", "admin", "domain1")
      iex> rm = CasbinEx2.ContextRoleManager.add_link_ctx(ctx, rm, "bob", "user", "domain2")
      iex> domains = CasbinEx2.ContextRoleManager.get_all_domains_ctx(ctx, rm)
      iex> Enum.sort(domains)
      ["domain1", "domain2"]
  """
  @spec get_all_domains_ctx(context(), t()) :: [String.t()]
  def get_all_domains_ctx(_ctx, %RoleManager{roles: roles}) do
    roles
    |> Map.keys()
    |> Enum.map(&extract_domain_from_key/1)
    |> Enum.filter(fn domain -> domain != "" end)
    |> Enum.uniq()
  end

  # Private helper functions

  defp extract_user_from_key(key) do
    case String.split(key, "::", parts: 2) do
      [user] -> user
      [user, _domain] -> user
    end
  end

  defp extract_domain_from_key(key) do
    case String.split(key, "::", parts: 2) do
      [_user] -> ""
      [_user, domain] -> domain
    end
  end

  # Delegate non-context versions for compatibility

  @doc """
  Clears all roles (non-context version).

  Delegates to `CasbinEx2.RoleManager.clear/1`.
  """
  @spec clear(t()) :: t()
  defdelegate clear(role_manager), to: RoleManager

  @doc """
  Adds an inheritance link (non-context version).

  Delegates to `CasbinEx2.RoleManager.add_link/4`.
  """
  @spec add_link(t(), String.t(), String.t(), String.t()) :: t()
  defdelegate add_link(role_manager, name1, name2, domain \\ ""), to: RoleManager

  @doc """
  Removes an inheritance link (non-context version).

  Delegates to `CasbinEx2.RoleManager.delete_link/4`.
  """
  @spec delete_link(t(), String.t(), String.t(), String.t()) :: t()
  defdelegate delete_link(role_manager, name1, name2, domain \\ ""), to: RoleManager

  @doc """
  Checks if a role link exists (non-context version).

  Delegates to `CasbinEx2.RoleManager.has_link/4`.
  """
  @spec has_link(t(), String.t(), String.t(), String.t()) :: boolean()
  defdelegate has_link(role_manager, name1, name2, domain \\ ""), to: RoleManager

  @doc """
  Gets roles for a user (non-context version).

  Delegates to `CasbinEx2.RoleManager.get_roles/3`.
  """
  @spec get_roles(t(), String.t(), String.t()) :: [String.t()]
  defdelegate get_roles(role_manager, name, domain \\ ""), to: RoleManager

  @doc """
  Gets users with a role (non-context version).

  Delegates to `CasbinEx2.RoleManager.get_users/3`.
  """
  @spec get_users(t(), String.t(), String.t()) :: [String.t()]
  defdelegate get_users(role_manager, name, domain \\ ""), to: RoleManager

  @doc """
  Prints all roles (non-context version).

  Delegates to `CasbinEx2.RoleManager.print_roles/1`.
  """
  @spec print_roles(t()) :: :ok
  defdelegate print_roles(role_manager), to: RoleManager
end
