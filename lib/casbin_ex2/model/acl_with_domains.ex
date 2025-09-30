defmodule CasbinEx2.Model.AclWithDomains do
  @moduledoc """
  ACL with Domains Model Enhancement.

  Provides enhanced domain-specific access control with hierarchical domains,
  domain inheritance, and cross-domain policy management.
  """

  alias CasbinEx2.Enforcer

  defstruct [
    :domains,
    :domain_hierarchy,
    :cross_domain_policies,
    :domain_metadata,
    :inheritance_enabled
  ]

  @type domain_info :: %{
          name: String.t(),
          parent: String.t() | nil,
          children: [String.t()],
          metadata: map()
        }

  @type t :: %__MODULE__{
          domains: %{String.t() => domain_info()},
          domain_hierarchy: %{String.t() => [String.t()]},
          cross_domain_policies: [list()],
          domain_metadata: %{String.t() => map()},
          inheritance_enabled: boolean()
        }

  @doc """
  Creates a new ACL with Domains model.

  ## Examples

      acl_model = AclWithDomains.new()

  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      domains: %{},
      domain_hierarchy: %{},
      cross_domain_policies: [],
      domain_metadata: %{},
      inheritance_enabled: true
    }
  end

  @doc """
  Adds a domain to the model.

  ## Examples

      {:ok, model} = AclWithDomains.add_domain(model, "engineering", "tech", %{region: "us-west"})

  """
  @spec add_domain(t(), String.t(), String.t() | nil, map()) :: {:ok, t()} | {:error, term()}
  def add_domain(
        %__MODULE__{domains: domains} = model,
        domain_name,
        parent_domain \\ nil,
        metadata \\ %{}
      ) do
    if Map.has_key?(domains, domain_name) do
      {:error, :domain_already_exists}
    else
      # Validate parent domain exists if specified
      case validate_parent_domain(domains, parent_domain) do
        :ok ->
          domain_info = %{
            name: domain_name,
            parent: parent_domain,
            children: [],
            metadata: metadata
          }

          new_domains = Map.put(domains, domain_name, domain_info)

          # Update parent's children list
          updated_domains = update_parent_children(new_domains, parent_domain, domain_name)

          # Update hierarchy
          new_hierarchy = update_hierarchy(model.domain_hierarchy, domain_name, parent_domain)

          # Update domain metadata
          new_domain_metadata = Map.put(model.domain_metadata, domain_name, metadata)

          {:ok,
           %{
             model
             | domains: updated_domains,
               domain_hierarchy: new_hierarchy,
               domain_metadata: new_domain_metadata
           }}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Removes a domain from the model.

  ## Examples

      {:ok, model} = AclWithDomains.remove_domain(model, "engineering")

  """
  @spec remove_domain(t(), String.t()) :: {:ok, t()} | {:error, term()}
  def remove_domain(%__MODULE__{domains: domains} = model, domain_name) do
    case Map.get(domains, domain_name) do
      nil ->
        {:error, :domain_not_found}

      domain_info ->
        # Check if domain has children
        if Enum.empty?(domain_info.children) do
          # Remove from parent's children list
          updated_domains = remove_from_parent_children(domains, domain_info.parent, domain_name)

          # Remove the domain
          final_domains = Map.delete(updated_domains, domain_name)

          # Update hierarchy
          new_hierarchy = remove_from_hierarchy(model.domain_hierarchy, domain_name)

          # Remove domain metadata
          new_domain_metadata = Map.delete(model.domain_metadata, domain_name)

          {:ok,
           %{
             model
             | domains: final_domains,
               domain_hierarchy: new_hierarchy,
               domain_metadata: new_domain_metadata
           }}
        else
          {:error, :domain_has_children}
        end
    end
  end

  @doc """
  Gets domain information.

  ## Examples

      domain_info = AclWithDomains.get_domain(model, "engineering")

  """
  @spec get_domain(t(), String.t()) :: domain_info() | nil
  def get_domain(%__MODULE__{domains: domains}, domain_name) do
    Map.get(domains, domain_name)
  end

  @doc """
  Gets all domains.

  ## Examples

      domains = AclWithDomains.get_all_domains(model)

  """
  @spec get_all_domains(t()) :: [String.t()]
  def get_all_domains(%__MODULE__{domains: domains}) do
    Map.keys(domains)
  end

  @doc """
  Gets child domains of a specific domain.

  ## Examples

      children = AclWithDomains.get_child_domains(model, "tech")

  """
  @spec get_child_domains(t(), String.t()) :: [String.t()]
  def get_child_domains(%__MODULE__{domains: domains}, domain_name) do
    case Map.get(domains, domain_name) do
      nil -> []
      domain_info -> domain_info.children
    end
  end

  @doc """
  Gets parent domain of a specific domain.

  ## Examples

      parent = AclWithDomains.get_parent_domain(model, "engineering")

  """
  @spec get_parent_domain(t(), String.t()) :: String.t() | nil
  def get_parent_domain(%__MODULE__{domains: domains}, domain_name) do
    case Map.get(domains, domain_name) do
      nil -> nil
      domain_info -> domain_info.parent
    end
  end

  @doc """
  Gets all ancestor domains (including the domain itself).

  ## Examples

      ancestors = AclWithDomains.get_ancestor_domains(model, "engineering")

  """
  @spec get_ancestor_domains(t(), String.t()) :: [String.t()]
  def get_ancestor_domains(%__MODULE__{domains: domains}, domain_name) do
    get_ancestors_recursive(domains, domain_name, [])
  end

  @doc """
  Gets all descendant domains (including the domain itself).

  ## Examples

      descendants = AclWithDomains.get_descendant_domains(model, "tech")

  """
  @spec get_descendant_domains(t(), String.t()) :: [String.t()]
  def get_descendant_domains(%__MODULE__{domains: domains}, domain_name) do
    get_descendants_recursive(domains, domain_name, [])
  end

  @doc """
  Gets roles for a user in a specific domain with inheritance.

  ## Examples

      roles = AclWithDomains.get_roles_for_user_in_domain(model, enforcer, "alice", "engineering")

  """
  @spec get_roles_for_user_in_domain(t(), Enforcer.t(), String.t(), String.t()) :: [String.t()]
  def get_roles_for_user_in_domain(
        %__MODULE__{inheritance_enabled: false},
        enforcer,
        user,
        domain
      ) do
    # No inheritance - just get direct roles
    Enforcer.get_roles_for_user_in_domain(enforcer, user, domain)
  end

  def get_roles_for_user_in_domain(%__MODULE__{} = model, enforcer, user, domain) do
    # Get roles from current domain and all ancestor domains
    ancestor_domains = get_ancestor_domains(model, domain)

    ancestor_domains
    |> Enum.flat_map(fn ancestor_domain ->
      Enforcer.get_roles_for_user_in_domain(enforcer, user, ancestor_domain)
    end)
    |> Enum.uniq()
  end

  @doc """
  Gets users for a role in a specific domain with inheritance.

  ## Examples

      users = AclWithDomains.get_users_for_role_in_domain(model, enforcer, "admin", "engineering")

  """
  @spec get_users_for_role_in_domain(t(), Enforcer.t(), String.t(), String.t()) :: [String.t()]
  def get_users_for_role_in_domain(
        %__MODULE__{inheritance_enabled: false},
        enforcer,
        role,
        domain
      ) do
    # No inheritance - just get direct users
    Enforcer.get_users_for_role_in_domain(enforcer, role, domain)
  end

  def get_users_for_role_in_domain(%__MODULE__{} = model, enforcer, role, domain) do
    # Get users from current domain and all descendant domains
    descendant_domains = get_descendant_domains(model, domain)

    descendant_domains
    |> Enum.flat_map(fn descendant_domain ->
      Enforcer.get_users_for_role_in_domain(enforcer, role, descendant_domain)
    end)
    |> Enum.uniq()
  end

  @doc """
  Checks if a user has a role in any related domain (with inheritance).

  ## Examples

      has_role = AclWithDomains.has_role_in_domain_hierarchy(model, enforcer, "alice", "admin", "engineering")

  """
  @spec has_role_in_domain_hierarchy(t(), Enforcer.t(), String.t(), String.t(), String.t()) ::
          boolean()
  def has_role_in_domain_hierarchy(%__MODULE__{} = model, enforcer, user, role, domain) do
    roles = get_roles_for_user_in_domain(model, enforcer, user, domain)
    role in roles
  end

  @doc """
  Adds a cross-domain policy.

  ## Examples

      {:ok, model} = AclWithDomains.add_cross_domain_policy(model,
        ["alice", "domain1", "data", "domain2", "read"])

  """
  @spec add_cross_domain_policy(t(), [String.t()]) :: {:ok, t()} | {:error, term()}
  def add_cross_domain_policy(%__MODULE__{cross_domain_policies: policies} = model, policy) do
    if policy in policies do
      {:error, :policy_already_exists}
    else
      new_policies = [policy | policies]
      {:ok, %{model | cross_domain_policies: new_policies}}
    end
  end

  @doc """
  Removes a cross-domain policy.

  ## Examples

      {:ok, model} = AclWithDomains.remove_cross_domain_policy(model,
        ["alice", "domain1", "data", "domain2", "read"])

  """
  @spec remove_cross_domain_policy(t(), [String.t()]) :: {:ok, t()} | {:error, term()}
  def remove_cross_domain_policy(%__MODULE__{cross_domain_policies: policies} = model, policy) do
    if policy in policies do
      new_policies = List.delete(policies, policy)
      {:ok, %{model | cross_domain_policies: new_policies}}
    else
      {:error, :policy_not_found}
    end
  end

  @doc """
  Gets all cross-domain policies.

  ## Examples

      policies = AclWithDomains.get_cross_domain_policies(model)

  """
  @spec get_cross_domain_policies(t()) :: [list()]
  def get_cross_domain_policies(%__MODULE__{cross_domain_policies: policies}), do: policies

  @doc """
  Sets domain metadata.

  ## Examples

      {:ok, model} = AclWithDomains.set_domain_metadata(model, "engineering", %{region: "us-west", team_size: 50})

  """
  @spec set_domain_metadata(t(), String.t(), map()) :: {:ok, t()} | {:error, term()}
  def set_domain_metadata(
        %__MODULE__{domains: domains, domain_metadata: metadata} = model,
        domain_name,
        new_metadata
      ) do
    if Map.has_key?(domains, domain_name) do
      # Update domain info
      domain_info = Map.get(domains, domain_name)
      updated_domain_info = %{domain_info | metadata: new_metadata}
      new_domains = Map.put(domains, domain_name, updated_domain_info)

      # Update metadata cache
      new_metadata_cache = Map.put(metadata, domain_name, new_metadata)

      {:ok, %{model | domains: new_domains, domain_metadata: new_metadata_cache}}
    else
      {:error, :domain_not_found}
    end
  end

  @doc """
  Gets domain metadata.

  ## Examples

      metadata = AclWithDomains.get_domain_metadata(model, "engineering")

  """
  @spec get_domain_metadata(t(), String.t()) :: map()
  def get_domain_metadata(%__MODULE__{domain_metadata: metadata}, domain_name) do
    Map.get(metadata, domain_name, %{})
  end

  @doc """
  Enables or disables domain inheritance.

  ## Examples

      model = AclWithDomains.set_inheritance_enabled(model, true)

  """
  @spec set_inheritance_enabled(t(), boolean()) :: t()
  def set_inheritance_enabled(%__MODULE__{} = model, enabled) do
    %{model | inheritance_enabled: enabled}
  end

  @doc """
  Checks if domain inheritance is enabled.

  ## Examples

      enabled = AclWithDomains.inheritance_enabled?(model)

  """
  @spec inheritance_enabled?(t()) :: boolean()
  def inheritance_enabled?(%__MODULE__{inheritance_enabled: enabled}), do: enabled

  @doc """
  Finds domains by metadata criteria.

  ## Examples

      domains = AclWithDomains.find_domains_by_metadata(model, %{region: "us-west"})

  """
  @spec find_domains_by_metadata(t(), map()) :: [String.t()]
  def find_domains_by_metadata(%__MODULE__{domain_metadata: metadata}, criteria) do
    metadata
    |> Enum.filter(fn {_domain, domain_metadata} ->
      Enum.all?(criteria, fn {key, value} ->
        Map.get(domain_metadata, key) == value
      end)
    end)
    |> Enum.map(fn {domain, _metadata} -> domain end)
  end

  @doc """
  Gets the domain hierarchy as a tree structure.

  ## Examples

      tree = AclWithDomains.get_domain_tree(model)

  """
  @spec get_domain_tree(t()) :: map()
  def get_domain_tree(%__MODULE__{domains: domains}) do
    # Find root domains (no parent)
    root_domains =
      domains
      |> Enum.filter(fn {_name, info} -> is_nil(info.parent) end)
      |> Enum.map(fn {name, _info} -> name end)

    # Build tree structure
    root_domains
    |> Enum.reduce(%{}, fn root_domain, acc ->
      Map.put(acc, root_domain, build_domain_subtree(domains, root_domain))
    end)
  end

  # Private functions

  defp validate_parent_domain(_domains, nil), do: :ok

  defp validate_parent_domain(domains, parent_domain) do
    if Map.has_key?(domains, parent_domain) do
      :ok
    else
      {:error, :parent_domain_not_found}
    end
  end

  defp update_parent_children(domains, nil, _child_domain), do: domains

  defp update_parent_children(domains, parent_domain, child_domain) do
    parent_info = Map.get(domains, parent_domain)
    updated_parent = %{parent_info | children: [child_domain | parent_info.children]}
    Map.put(domains, parent_domain, updated_parent)
  end

  defp remove_from_parent_children(domains, nil, _child_domain), do: domains

  defp remove_from_parent_children(domains, parent_domain, child_domain) do
    parent_info = Map.get(domains, parent_domain)
    updated_parent = %{parent_info | children: List.delete(parent_info.children, child_domain)}
    Map.put(domains, parent_domain, updated_parent)
  end

  defp update_hierarchy(hierarchy, domain_name, nil) do
    Map.put(hierarchy, domain_name, [])
  end

  defp update_hierarchy(hierarchy, domain_name, parent_domain) do
    parent_ancestors = Map.get(hierarchy, parent_domain, [])
    Map.put(hierarchy, domain_name, [parent_domain | parent_ancestors])
  end

  defp remove_from_hierarchy(hierarchy, domain_name) do
    Map.delete(hierarchy, domain_name)
  end

  defp get_ancestors_recursive(_domains, nil, acc), do: acc

  defp get_ancestors_recursive(domains, domain_name, acc) do
    if domain_name in acc do
      # Prevent infinite loops
      acc
    else
      new_acc = [domain_name | acc]

      case Map.get(domains, domain_name) do
        nil -> new_acc
        domain_info -> get_ancestors_recursive(domains, domain_info.parent, new_acc)
      end
    end
  end

  defp get_descendants_recursive(domains, domain_name, acc) do
    if domain_name in acc do
      # Prevent infinite loops
      acc
    else
      new_acc = [domain_name | acc]
      get_descendants_for_domain(domains, domain_name, new_acc)
    end
  end

  defp get_descendants_for_domain(domains, domain_name, acc) do
    case Map.get(domains, domain_name) do
      nil ->
        acc

      domain_info ->
        get_descendants_for_children(domains, domain_info.children, acc)
    end
  end

  defp get_descendants_for_children(domains, children, acc) do
    Enum.reduce(children, acc, fn child, child_acc ->
      get_descendants_recursive(domains, child, child_acc)
    end)
  end

  defp build_domain_subtree(domains, domain_name) do
    case Map.get(domains, domain_name) do
      nil ->
        %{}

      domain_info ->
        children =
          domain_info.children
          |> Enum.reduce(%{}, fn child, acc ->
            Map.put(acc, child, build_domain_subtree(domains, child))
          end)

        %{
          metadata: domain_info.metadata,
          children: children
        }
    end
  end
end
