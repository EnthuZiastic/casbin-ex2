defmodule CasbinEx2.Model.MultiTenancyModel do
  @moduledoc """
  Multi-Tenancy Model for enhanced domain management.

  Provides comprehensive multi-tenant access control with tenant isolation,
  hierarchical tenant structures, cross-tenant permissions, tenant-specific
  policies, and tenant inheritance patterns.
  """

  defstruct [
    :tenants,
    :tenant_hierarchy,
    :tenant_policies,
    :tenant_users,
    :cross_tenant_permissions,
    :isolation_level,
    :enabled
  ]

  @type isolation_level :: :strict | :moderate | :relaxed
  @type tenant :: %{
          id: String.t(),
          name: String.t(),
          parent_id: String.t() | nil,
          level: integer(),
          metadata: %{String.t() => term()},
          active: boolean()
        }

  @type cross_tenant_permission :: %{
          from_tenant: String.t(),
          to_tenant: String.t(),
          subject: String.t(),
          action: String.t(),
          resource_pattern: String.t()
        }

  @type t :: %__MODULE__{
          tenants: %{String.t() => tenant()},
          tenant_hierarchy: %{String.t() => [String.t()]},
          tenant_policies: %{String.t() => %{String.t() => [term()]}},
          tenant_users: %{String.t() => %{String.t() => [String.t()]}},
          cross_tenant_permissions: [cross_tenant_permission()],
          isolation_level: isolation_level(),
          enabled: boolean()
        }

  @doc """
  Creates a new Multi-Tenancy model.

  ## Examples

      mt_model = MultiTenancyModel.new()
      mt_model = MultiTenancyModel.new(isolation_level: :strict)

  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      tenants: %{},
      tenant_hierarchy: %{},
      tenant_policies: %{},
      tenant_users: %{},
      cross_tenant_permissions: [],
      isolation_level: Keyword.get(opts, :isolation_level, :moderate),
      enabled: true
    }
  end

  @doc """
  Adds a tenant.

  ## Examples

      tenant = %{
        id: "tenant1",
        name: "Acme Corp",
        parent_id: nil,
        level: 0,
        metadata: %{"industry" => "tech"},
        active: true
      }
      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant)

  """
  @spec add_tenant(t(), tenant()) :: {:ok, t()} | {:error, term()}
  def add_tenant(%__MODULE__{} = model, tenant) do
    if Map.has_key?(model.tenants, tenant.id) do
      {:error, :tenant_exists}
    else
      # Add tenant
      updated_tenants = Map.put(model.tenants, tenant.id, tenant)

      # Update hierarchy
      updated_hierarchy =
        case tenant.parent_id do
          nil ->
            model.tenant_hierarchy

          parent_id ->
            current_children = Map.get(model.tenant_hierarchy, parent_id, [])
            Map.put(model.tenant_hierarchy, parent_id, [tenant.id | current_children])
        end

      # Initialize tenant-specific collections
      updated_policies = Map.put(model.tenant_policies, tenant.id, %{})
      updated_users = Map.put(model.tenant_users, tenant.id, %{})

      updated_model = %{
        model
        | tenants: updated_tenants,
          tenant_hierarchy: updated_hierarchy,
          tenant_policies: updated_policies,
          tenant_users: updated_users
      }

      {:ok, updated_model}
    end
  end

  @doc """
  Removes a tenant and all its data.

  ## Examples

      {:ok, model} = MultiTenancyModel.remove_tenant(model, "tenant1")

  """
  @spec remove_tenant(t(), String.t()) :: {:ok, t()} | {:error, term()}
  def remove_tenant(%__MODULE__{} = model, tenant_id) do
    case Map.get(model.tenants, tenant_id) do
      nil -> {:error, :tenant_not_found}
      tenant -> do_remove_tenant(model, tenant_id, tenant)
    end
  end

  defp do_remove_tenant(model, tenant_id, tenant) do
    children = Map.get(model.tenant_hierarchy, tenant_id, [])

    if length(children) > 0 do
      {:error, :tenant_has_children}
    else
      perform_tenant_removal(model, tenant_id, tenant)
    end
  end

  defp perform_tenant_removal(model, tenant_id, tenant) do
    updated_hierarchy = update_parent_hierarchy(model, tenant_id, tenant.parent_id)

    updated_model = %{
      model
      | tenants: Map.delete(model.tenants, tenant_id),
        tenant_hierarchy: Map.delete(updated_hierarchy, tenant_id),
        tenant_policies: Map.delete(model.tenant_policies, tenant_id),
        tenant_users: Map.delete(model.tenant_users, tenant_id),
        cross_tenant_permissions: remove_cross_tenant_permissions(model, tenant_id)
    }

    {:ok, updated_model}
  end

  defp update_parent_hierarchy(model, tenant_id, parent_id) do
    case parent_id do
      nil ->
        model.tenant_hierarchy

      parent_id ->
        current_children = Map.get(model.tenant_hierarchy, parent_id, [])
        updated_children = List.delete(current_children, tenant_id)
        Map.put(model.tenant_hierarchy, parent_id, updated_children)
    end
  end

  defp remove_cross_tenant_permissions(model, tenant_id) do
    Enum.reject(model.cross_tenant_permissions, fn perm ->
      perm.from_tenant == tenant_id || perm.to_tenant == tenant_id
    end)
  end

  @doc """
  Adds a user to a tenant.

  ## Examples

      {:ok, model} = MultiTenancyModel.add_user_to_tenant(model, "tenant1", "alice", ["admin"])

  """
  @spec add_user_to_tenant(t(), String.t(), String.t(), [String.t()]) ::
          {:ok, t()} | {:error, term()}
  def add_user_to_tenant(%__MODULE__{} = model, tenant_id, user_id, roles) do
    if Map.has_key?(model.tenants, tenant_id) do
      current_tenant_users = Map.get(model.tenant_users, tenant_id, %{})
      updated_tenant_users = Map.put(current_tenant_users, user_id, roles)
      updated_users = Map.put(model.tenant_users, tenant_id, updated_tenant_users)

      updated_model = %{model | tenant_users: updated_users}
      {:ok, updated_model}
    else
      {:error, :tenant_not_found}
    end
  end

  @doc """
  Adds a policy to a tenant.

  ## Examples

      {:ok, model} = MultiTenancyModel.add_tenant_policy(model, "tenant1", "p", ["alice", "read", "doc1"])

  """
  @spec add_tenant_policy(t(), String.t(), String.t(), [String.t()]) ::
          {:ok, t()} | {:error, term()}
  def add_tenant_policy(%__MODULE__{} = model, tenant_id, policy_type, policy_rule) do
    if Map.has_key?(model.tenants, tenant_id) do
      current_tenant_policies = Map.get(model.tenant_policies, tenant_id, %{})
      current_type_policies = Map.get(current_tenant_policies, policy_type, [])
      updated_type_policies = [policy_rule | current_type_policies]

      updated_tenant_policies =
        Map.put(current_tenant_policies, policy_type, updated_type_policies)

      updated_policies = Map.put(model.tenant_policies, tenant_id, updated_tenant_policies)

      updated_model = %{model | tenant_policies: updated_policies}
      {:ok, updated_model}
    else
      {:error, :tenant_not_found}
    end
  end

  @doc """
  Adds a cross-tenant permission.

  ## Examples

      permission = %{
        from_tenant: "tenant1",
        to_tenant: "tenant2",
        subject: "alice",
        action: "read",
        resource_pattern: "shared/*"
      }
      {:ok, model} = MultiTenancyModel.add_cross_tenant_permission(model, permission)

  """
  @spec add_cross_tenant_permission(t(), cross_tenant_permission()) ::
          {:ok, t()} | {:error, term()}
  def add_cross_tenant_permission(%__MODULE__{isolation_level: :strict}, _permission) do
    {:error, :cross_tenant_access_forbidden}
  end

  def add_cross_tenant_permission(%__MODULE__{} = model, permission) do
    # Validate both tenants exist
    if Map.has_key?(model.tenants, permission.from_tenant) &&
         Map.has_key?(model.tenants, permission.to_tenant) do
      updated_permissions = [permission | model.cross_tenant_permissions]
      updated_model = %{model | cross_tenant_permissions: updated_permissions}
      {:ok, updated_model}
    else
      {:error, :tenant_not_found}
    end
  end

  @doc """
  Checks if a user can access a resource in a tenant.

  ## Examples

      MultiTenancyModel.can_access?(model, "tenant1", "alice", "read", "doc1")

  """
  @spec can_access?(t(), String.t(), String.t(), String.t(), String.t()) :: boolean()
  def can_access?(%__MODULE__{enabled: false}, _tenant_id, _user_id, _action, _resource), do: true

  def can_access?(%__MODULE__{} = model, tenant_id, user_id, action, resource) do
    # Check if user belongs to tenant
    tenant_access = check_tenant_access(model, tenant_id, user_id, action, resource)

    # Check cross-tenant permissions if isolation allows
    cross_tenant_access =
      if model.isolation_level != :strict do
        check_cross_tenant_access(model, tenant_id, user_id, action, resource)
      else
        false
      end

    # Check inherited access from parent tenants
    inherited_access = check_inherited_access(model, tenant_id, user_id, action, resource)

    tenant_access || cross_tenant_access || inherited_access
  end

  @doc """
  Evaluates a multi-tenancy policy against a request.

  ## Examples

      MultiTenancyModel.evaluate_policy(model, ["tenant1", "alice", "read", "doc1"], "tenant_user")

  """
  @spec evaluate_policy(t(), [String.t()], String.t()) :: boolean()
  def evaluate_policy(%__MODULE__{enabled: false}, _request, _policy), do: true

  def evaluate_policy(%__MODULE__{} = model, [tenant_id, user_id, action, resource], policy) do
    case policy do
      "tenant_user" ->
        has_tenant_user?(model, tenant_id, user_id)

      "tenant_admin" ->
        has_tenant_role?(model, tenant_id, user_id, "admin")

      "cross_tenant_allowed" ->
        model.isolation_level != :strict

      "tenant_hierarchy" ->
        can_access?(model, tenant_id, user_id, action, resource)

      _ ->
        can_access?(model, tenant_id, user_id, action, resource)
    end
  end

  @doc """
  Gets tenant hierarchy (all descendants).

  ## Examples

      descendants = MultiTenancyModel.get_tenant_descendants(model, "tenant1")

  """
  @spec get_tenant_descendants(t(), String.t()) :: [String.t()]
  def get_tenant_descendants(%__MODULE__{} = model, tenant_id) do
    get_descendants_recursive(model, tenant_id, [])
  end

  @doc """
  Gets tenant ancestors (all parents up the hierarchy).

  ## Examples

      ancestors = MultiTenancyModel.get_tenant_ancestors(model, "tenant1")

  """
  @spec get_tenant_ancestors(t(), String.t()) :: [String.t()]
  def get_tenant_ancestors(%__MODULE__{} = model, tenant_id) do
    case Map.get(model.tenants, tenant_id) do
      nil ->
        []

      tenant ->
        case tenant.parent_id do
          nil -> []
          parent_id -> [parent_id | get_tenant_ancestors(model, parent_id)]
        end
    end
  end

  @doc """
  Gets all users in a tenant including inherited users.

  ## Examples

      users = MultiTenancyModel.get_all_tenant_users(model, "tenant1")

  """
  @spec get_all_tenant_users(t(), String.t()) :: %{String.t() => [String.t()]}
  def get_all_tenant_users(%__MODULE__{} = model, tenant_id) do
    # Get direct users
    direct_users = Map.get(model.tenant_users, tenant_id, %{})

    # Get inherited users from parent tenants
    inherited_users =
      if model.isolation_level == :relaxed do
        model
        |> get_tenant_ancestors(tenant_id)
        |> Enum.reduce(%{}, fn ancestor_id, acc ->
          ancestor_users = Map.get(model.tenant_users, ancestor_id, %{})
          Map.merge(acc, ancestor_users)
        end)
      else
        %{}
      end

    Map.merge(inherited_users, direct_users)
  end

  # Private functions

  defp check_tenant_access(%__MODULE__{} = model, tenant_id, user_id, action, resource) do
    # Check if user exists in tenant
    tenant_users = Map.get(model.tenant_users, tenant_id, %{})
    user_roles = Map.get(tenant_users, user_id, [])

    if length(user_roles) > 0 do
      # Check tenant-specific policies
      tenant_policies = Map.get(model.tenant_policies, tenant_id, %{})
      check_policies_match(tenant_policies, user_id, action, resource, user_roles)
    else
      false
    end
  end

  defp check_cross_tenant_access(
         %__MODULE__{} = model,
         target_tenant_id,
         user_id,
         action,
         resource
       ) do
    Enum.any?(model.cross_tenant_permissions, fn perm ->
      perm.to_tenant == target_tenant_id &&
        perm.subject == user_id &&
        perm.action == action &&
        matches_resource_pattern?(perm.resource_pattern, resource)
    end)
  end

  defp check_inherited_access(%__MODULE__{} = model, tenant_id, user_id, action, resource) do
    if model.isolation_level == :relaxed do
      model
      |> get_tenant_ancestors(tenant_id)
      |> Enum.any?(fn ancestor_id ->
        check_tenant_access(model, ancestor_id, user_id, action, resource)
      end)
    else
      false
    end
  end

  defp check_policies_match(policies, user_id, action, resource, user_roles) do
    # Check direct user policies
    user_policies = Map.get(policies, "p", [])

    user_match =
      Enum.any?(user_policies, fn [subj, act, res] ->
        subj == user_id && act == action && res == resource
      end)

    # Check role-based policies
    role_match =
      Enum.any?(user_roles, fn role ->
        role_policies = Map.get(policies, "p", [])

        Enum.any?(role_policies, fn [subj, act, res] ->
          subj == role && act == action && res == resource
        end)
      end)

    user_match || role_match
  end

  defp matches_resource_pattern?(pattern, resource) do
    if String.contains?(pattern, "*") do
      regex_pattern =
        pattern
        |> String.replace("*", ".*")
        |> (&"^#{&1}$").()

      case Regex.compile(regex_pattern) do
        {:ok, regex} -> Regex.match?(regex, resource)
        {:error, _} -> false
      end
    else
      pattern == resource
    end
  end

  defp get_descendants_recursive(%__MODULE__{} = model, tenant_id, visited) do
    if tenant_id in visited do
      # Prevent infinite loops
      []
    else
      children = Map.get(model.tenant_hierarchy, tenant_id, [])
      new_visited = [tenant_id | visited]

      children ++
        Enum.flat_map(children, fn child_id ->
          get_descendants_recursive(model, child_id, new_visited)
        end)
    end
  end

  defp has_tenant_user?(%__MODULE__{} = model, tenant_id, user_id) do
    tenant_users = Map.get(model.tenant_users, tenant_id, %{})
    Map.has_key?(tenant_users, user_id)
  end

  defp has_tenant_role?(%__MODULE__{} = model, tenant_id, user_id, role) do
    tenant_users = Map.get(model.tenant_users, tenant_id, %{})
    user_roles = Map.get(tenant_users, user_id, [])
    role in user_roles
  end
end
