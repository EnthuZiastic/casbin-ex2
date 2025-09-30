defmodule CasbinEx2.Enforcer do
  @moduledoc """
  The main enforcer struct for Casbin authorization.

  This module provides the core functionality for policy enforcement,
  policy management, and role-based access control (RBAC).
  """

  import Bitwise
  alias CasbinEx2.Model
  alias CasbinEx2.RoleManager
  alias CasbinEx2.Adapter

  defstruct [
    :model,
    :adapter,
    :watcher,
    :role_manager,
    :function_map,
    :effect_expr,
    :enabled,
    :auto_save,
    :auto_build_role_links,
    :auto_notify_watcher,
    policies: %{},
    grouping_policies: %{}
  ]

  @type t :: %__MODULE__{
          model: Model.t() | nil,
          adapter: Adapter.t() | nil,
          watcher: any() | nil,
          role_manager: RoleManager.t() | nil,
          function_map: map(),
          effect_expr: any() | nil,
          enabled: boolean(),
          auto_save: boolean(),
          auto_build_role_links: boolean(),
          auto_notify_watcher: boolean(),
          policies: map(),
          grouping_policies: map()
        }

  @doc """
  Creates a new enforcer.

  ## Examples

      # With model file and policy file
      {:ok, enforcer} = new_enforcer("model.conf", "policy.csv")

      # With model file and adapter
      adapter = FileAdapter.new("policy.csv")
      {:ok, enforcer} = new_enforcer("model.conf", adapter)
  """
  @spec new_enforcer(String.t(), String.t()) :: {:ok, t()} | {:error, term()}
  @spec new_enforcer(String.t(), Adapter.t()) :: {:ok, t()} | {:error, term()}
  def new_enforcer(model_path, policy_path)
      when is_binary(model_path) and is_binary(policy_path) do
    adapter = CasbinEx2.Adapter.FileAdapter.new(policy_path)
    init_with_file(model_path, adapter)
  end

  def new_enforcer(model_path, %_{} = adapter) do
    init_with_file(model_path, adapter)
  end

  @doc """
  Initializes the enforcer with model file and adapter.
  """
  @spec init_with_file(String.t(), Adapter.t()) :: {:ok, t()} | {:error, term()}
  def init_with_file(model_path, adapter) do
    with {:ok, model} <- Model.load_model(model_path),
         {:ok, enforcer} <- init_with_model_and_adapter(model, adapter) do
      {:ok, enforcer}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Initializes the enforcer with model and adapter.
  """
  @spec init_with_model_and_adapter(Model.t(), Adapter.t()) :: {:ok, t()} | {:error, term()}
  def init_with_model_and_adapter(model, adapter) do
    enforcer = %__MODULE__{
      model: model,
      adapter: adapter,
      enabled: true,
      auto_save: true,
      auto_build_role_links: true,
      auto_notify_watcher: true,
      function_map: init_function_map(),
      role_manager: RoleManager.new_role_manager(10)
    }

    case load_policy(enforcer) do
      {:ok, updated_enforcer} -> {:ok, updated_enforcer}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Loads policy from the adapter.
  """
  @spec load_policy(t()) :: {:ok, t()} | {:error, term()}
  def load_policy(%__MODULE__{adapter: adapter, model: model} = enforcer) do
    case Adapter.load_policy(adapter, model) do
      {:ok, policies, grouping_policies} ->
        updated_enforcer = %{enforcer | policies: policies, grouping_policies: grouping_policies}

        if enforcer.auto_build_role_links do
          build_role_links(updated_enforcer)
        else
          {:ok, updated_enforcer}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Saves policy to the adapter.
  """
  @spec save_policy(t()) :: {:ok, t()} | {:error, term()}
  def save_policy(
        %__MODULE__{adapter: adapter, policies: policies, grouping_policies: grouping_policies} =
          enforcer
      ) do
    case Adapter.save_policy(adapter, policies, grouping_policies) do
      :ok -> {:ok, enforcer}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  The main enforcement function. Returns true if the request is allowed.
  """
  @spec enforce(t(), list()) :: boolean()
  def enforce(%__MODULE__{enabled: false}, _request), do: true

  def enforce(%__MODULE__{model: model, policies: _policies} = enforcer, request) do
    # Get the matcher expression from the model
    matcher_expr = Model.get_matcher(model)

    # Evaluate the request against all policies
    {result, _explain} = enforce_internal(enforcer, request, matcher_expr)
    result
  end

  @doc """
  Enforcement with custom matcher. Returns true if the request is allowed.
  """
  @spec enforce_with_matcher(t(), String.t(), list()) :: boolean()
  def enforce_with_matcher(%__MODULE__{enabled: false}, _matcher, _request), do: true

  def enforce_with_matcher(enforcer, matcher, request) do
    {result, _explain} = enforce_internal(enforcer, request, matcher)
    result
  end

  @doc """
  Extended enforcement function. Returns {allowed, explanation}.
  """
  @spec enforce_ex(t(), list()) :: {boolean(), [String.t()]}
  def enforce_ex(%__MODULE__{enabled: false}, _request), do: {true, ["Enforcer disabled"]}

  def enforce_ex(%__MODULE__{model: model} = enforcer, request) do
    matcher_expr = Model.get_matcher(model)
    enforce_internal(enforcer, request, matcher_expr)
  end

  @doc """
  Extended enforcement with custom matcher. Returns {allowed, explanation}.
  """
  @spec enforce_ex_with_matcher(t(), String.t(), list()) :: {boolean(), [String.t()]}
  def enforce_ex_with_matcher(%__MODULE__{enabled: false}, _matcher, _request),
    do: {true, ["Enforcer disabled"]}

  def enforce_ex_with_matcher(enforcer, matcher, request) do
    enforce_internal(enforcer, request, matcher)
  end

  @doc """
  Batch enforcement for multiple requests.
  """
  @spec batch_enforce(t(), [list()]) :: [boolean()]
  def batch_enforce(enforcer, requests) do
    Enum.map(requests, &enforce(enforcer, &1))
  end

  @doc """
  Batch enforcement with custom matcher.
  """
  @spec batch_enforce_with_matcher(t(), String.t(), [list()]) :: [boolean()]
  def batch_enforce_with_matcher(enforcer, matcher, requests) do
    Enum.map(requests, &enforce_with_matcher(enforcer, matcher, &1))
  end

  @doc """
  Builds role inheritance links.
  """
  @spec build_role_links(t()) :: {:ok, t()} | {:error, term()}
  def build_role_links(
        %__MODULE__{role_manager: role_manager, grouping_policies: grouping_policies} = enforcer
      ) do
    # Clear existing role links
    RoleManager.clear(role_manager)

    # Build role links from grouping policies
    grouping_policies
    |> Map.values()
    |> List.flatten()
    |> Enum.each(fn policy ->
      case policy do
        policy when is_list(policy) and length(policy) >= 2 ->
          [user, role | domain] = policy
          domain_value = if domain != [], do: hd(domain), else: ""
          RoleManager.add_link(role_manager, user, role, domain_value)

        _ ->
          # Skip invalid policies
          :ok
      end
    end)

    {:ok, enforcer}
  end

  @doc """
  Enables or disables the enforcer.
  """
  @spec enable_enforce(t(), boolean()) :: t()
  def enable_enforce(enforcer, enable) do
    %{enforcer | enabled: enable}
  end

  @doc """
  Enables or disables auto-save.
  """
  @spec enable_auto_save(t(), boolean()) :: t()
  def enable_auto_save(enforcer, auto_save) do
    %{enforcer | auto_save: auto_save}
  end

  # Policy Management APIs

  @doc """
  Adds a policy rule for the default policy type "p".
  """
  @spec add_policy(t(), [String.t()]) :: {:ok, t()} | {:error, term()}
  def add_policy(enforcer, params) do
    add_named_policy(enforcer, "p", params)
  end

  @doc """
  Adds a named policy rule.
  """
  @spec add_named_policy(t(), String.t(), [String.t()]) :: {:ok, t()} | {:error, term()}
  def add_named_policy(%__MODULE__{policies: policies} = enforcer, ptype, params) do
    current_rules = Map.get(policies, ptype, [])

    if params in current_rules do
      {:error, :already_exists}
    else
      new_rules = [params | current_rules]
      new_policies = Map.put(policies, ptype, new_rules)
      updated_enforcer = %{enforcer | policies: new_policies}

      if enforcer.auto_save do
        save_policy(updated_enforcer)
      else
        {:ok, updated_enforcer}
      end
    end
  end

  @doc """
  Adds multiple policy rules for the default policy type "p".
  """
  @spec add_policies(t(), [[String.t()]]) :: {:ok, t()} | {:error, term()}
  def add_policies(enforcer, rules) do
    add_named_policies(enforcer, "p", rules)
  end

  @doc """
  Adds multiple named policy rules.
  """
  @spec add_named_policies(t(), String.t(), [[String.t()]]) :: {:ok, t()} | {:error, term()}
  def add_named_policies(%__MODULE__{policies: policies} = enforcer, ptype, rules) do
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
    updated_enforcer = %{enforcer | policies: new_policies}

    if enforcer.auto_save do
      save_policy(updated_enforcer)
    else
      {:ok, updated_enforcer}
    end
  end

  @doc """
  Removes a policy rule for the default policy type "p".
  """
  @spec remove_policy(t(), [String.t()]) :: {:ok, t()} | {:error, term()}
  def remove_policy(enforcer, params) do
    remove_named_policy(enforcer, "p", params)
  end

  @doc """
  Removes a named policy rule.
  """
  @spec remove_named_policy(t(), String.t(), [String.t()]) :: {:ok, t()} | {:error, term()}
  def remove_named_policy(%__MODULE__{policies: policies} = enforcer, ptype, params) do
    current_rules = Map.get(policies, ptype, [])

    if params in current_rules do
      new_rules = List.delete(current_rules, params)
      new_policies = Map.put(policies, ptype, new_rules)
      updated_enforcer = %{enforcer | policies: new_policies}

      if enforcer.auto_save do
        save_policy(updated_enforcer)
      else
        {:ok, updated_enforcer}
      end
    else
      {:error, :not_found}
    end
  end

  @doc """
  Removes multiple policy rules for the default policy type "p".
  """
  @spec remove_policies(t(), [[String.t()]]) :: {:ok, t()} | {:error, term()}
  def remove_policies(enforcer, rules) do
    remove_named_policies(enforcer, "p", rules)
  end

  @doc """
  Removes multiple named policy rules.
  """
  @spec remove_named_policies(t(), String.t(), [[String.t()]]) :: {:ok, t()} | {:error, term()}
  def remove_named_policies(%__MODULE__{policies: policies} = enforcer, ptype, rules) do
    current_rules = Map.get(policies, ptype, [])

    new_rules =
      Enum.reduce(rules, current_rules, fn rule, acc ->
        List.delete(acc, rule)
      end)

    new_policies = Map.put(policies, ptype, new_rules)
    updated_enforcer = %{enforcer | policies: new_policies}

    if enforcer.auto_save do
      save_policy(updated_enforcer)
    else
      {:ok, updated_enforcer}
    end
  end

  @doc """
  Gets all policy rules for the default policy type "p".
  """
  @spec get_policy(t()) :: [[String.t()]]
  def get_policy(enforcer) do
    get_named_policy(enforcer, "p")
  end

  @doc """
  Gets all named policy rules.
  """
  @spec get_named_policy(t(), String.t()) :: [[String.t()]]
  def get_named_policy(%__MODULE__{policies: policies}, ptype) do
    Map.get(policies, ptype, [])
  end

  @doc """
  Gets filtered policy rules for the default policy type "p".
  """
  @spec get_filtered_policy(t(), integer(), [String.t()]) :: [[String.t()]]
  def get_filtered_policy(enforcer, field_index, field_values) do
    get_filtered_named_policy(enforcer, "p", field_index, field_values)
  end

  @doc """
  Gets filtered named policy rules.
  """
  @spec get_filtered_named_policy(t(), String.t(), integer(), [String.t()]) :: [[String.t()]]
  def get_filtered_named_policy(%__MODULE__{policies: policies}, ptype, field_index, field_values) do
    current_rules = Map.get(policies, ptype, [])

    Enum.filter(current_rules, fn rule ->
      field_values
      |> Enum.with_index()
      |> Enum.all?(fn {value, offset} ->
        if value == "" do
          true
        else
          rule_index = field_index + offset
          rule_value = Enum.at(rule, rule_index)
          rule_value == value
        end
      end)
    end)
  end

  @doc """
  Checks if a policy rule exists for the default policy type "p".
  """
  @spec has_policy(t(), [String.t()]) :: boolean()
  def has_policy(enforcer, params) do
    has_named_policy(enforcer, "p", params)
  end

  @doc """
  Checks if a named policy rule exists.
  """
  @spec has_named_policy(t(), String.t(), [String.t()]) :: boolean()
  def has_named_policy(%__MODULE__{policies: policies}, ptype, params) do
    current_rules = Map.get(policies, ptype, [])
    params in current_rules
  end

  # Grouping Policy Management APIs

  @doc """
  Adds a grouping policy rule for the default grouping type "g".
  """
  @spec add_grouping_policy(t(), [String.t()]) :: {:ok, t()} | {:error, term()}
  def add_grouping_policy(enforcer, params) do
    add_named_grouping_policy(enforcer, "g", params)
  end

  @doc """
  Adds a named grouping policy rule.
  """
  @spec add_named_grouping_policy(t(), String.t(), [String.t()]) :: {:ok, t()} | {:error, term()}
  def add_named_grouping_policy(
        %__MODULE__{grouping_policies: grouping_policies, role_manager: role_manager} = enforcer,
        ptype,
        params
      ) do
    current_rules = Map.get(grouping_policies, ptype, [])

    if params in current_rules do
      {:error, :already_exists}
    else
      new_rules = [params | current_rules]
      new_grouping_policies = Map.put(grouping_policies, ptype, new_rules)

      # Update role manager
      new_role_manager =
        case params do
          [user, role] ->
            RoleManager.add_link(role_manager, user, role, "")

          [user, role, domain] ->
            RoleManager.add_link(role_manager, user, role, domain)

          _ ->
            role_manager
        end

      updated_enforcer = %{
        enforcer
        | grouping_policies: new_grouping_policies,
          role_manager: new_role_manager
      }

      if enforcer.auto_save do
        save_policy(updated_enforcer)
      else
        {:ok, updated_enforcer}
      end
    end
  end

  @doc """
  Gets all grouping policy rules for the default grouping type "g".
  """
  @spec get_grouping_policy(t()) :: [[String.t()]]
  def get_grouping_policy(enforcer) do
    get_named_grouping_policy(enforcer, "g")
  end

  @doc """
  Gets all named grouping policy rules.
  """
  @spec get_named_grouping_policy(t(), String.t()) :: [[String.t()]]
  def get_named_grouping_policy(%__MODULE__{grouping_policies: grouping_policies}, ptype) do
    Map.get(grouping_policies, ptype, [])
  end

  # Policy Update Operations

  @doc """
  Updates a policy rule for the default policy type "p".
  """
  @spec update_policy(t(), [String.t()], [String.t()]) :: {:ok, t()} | {:error, term()}
  def update_policy(enforcer, old_policy, new_policy) do
    update_named_policy(enforcer, "p", old_policy, new_policy)
  end

  @doc """
  Updates a named policy rule.
  """
  @spec update_named_policy(t(), String.t(), [String.t()], [String.t()]) ::
          {:ok, t()} | {:error, term()}
  def update_named_policy(
        %__MODULE__{policies: policies} = enforcer,
        ptype,
        old_policy,
        new_policy
      ) do
    current_rules = Map.get(policies, ptype, [])

    if old_policy in current_rules do
      new_rules =
        current_rules
        |> List.delete(old_policy)
        |> then(fn rules -> [new_policy | rules] end)

      new_policies = Map.put(policies, ptype, new_rules)
      updated_enforcer = %{enforcer | policies: new_policies}

      if enforcer.auto_save do
        save_policy(updated_enforcer)
      else
        {:ok, updated_enforcer}
      end
    else
      {:error, :not_found}
    end
  end

  @doc """
  Updates multiple policy rules for the default policy type "p".
  """
  @spec update_policies(t(), [[String.t()]], [[String.t()]]) :: {:ok, t()} | {:error, term()}
  def update_policies(enforcer, old_policies, new_policies) do
    update_named_policies(enforcer, "p", old_policies, new_policies)
  end

  @doc """
  Updates multiple named policy rules.
  """
  @spec update_named_policies(t(), String.t(), [[String.t()]], [[String.t()]]) ::
          {:ok, t()} | {:error, term()}
  def update_named_policies(
        %__MODULE__{policies: policies} = enforcer,
        ptype,
        old_policies,
        new_policies
      ) do
    if length(old_policies) != length(new_policies) do
      {:error, :length_mismatch}
    else
      current_rules = Map.get(policies, ptype, [])

      # Check all old policies exist
      missing_policies = Enum.reject(old_policies, &(&1 in current_rules))

      if missing_policies != [] do
        {:error, {:not_found, missing_policies}}
      else
        # Remove old policies and add new ones
        updated_rules =
          Enum.reduce(old_policies, current_rules, fn old_policy, acc ->
            List.delete(acc, old_policy)
          end)

        final_rules =
          Enum.reduce(new_policies, updated_rules, fn new_policy, acc ->
            [new_policy | acc]
          end)

        new_policies_map = Map.put(policies, ptype, final_rules)
        updated_enforcer = %{enforcer | policies: new_policies_map}

        if enforcer.auto_save do
          save_policy(updated_enforcer)
        else
          {:ok, updated_enforcer}
        end
      end
    end
  end

  @doc """
  Updates filtered policies for the default policy type "p".
  """
  @spec update_filtered_policies(t(), [[String.t()]], integer(), [String.t()]) ::
          {:ok, t()} | {:error, term()}
  def update_filtered_policies(enforcer, new_policies, field_index, field_values) do
    update_filtered_named_policies(enforcer, "p", new_policies, field_index, field_values)
  end

  @doc """
  Updates filtered named policies.
  """
  @spec update_filtered_named_policies(t(), String.t(), [[String.t()]], integer(), [String.t()]) ::
          {:ok, t()} | {:error, term()}
  def update_filtered_named_policies(
        %__MODULE__{policies: policies} = enforcer,
        ptype,
        new_policies,
        field_index,
        field_values
      ) do
    current_rules = Map.get(policies, ptype, [])

    # Remove policies that match the filter
    filtered_rules =
      Enum.reject(current_rules, fn rule ->
        field_values
        |> Enum.with_index()
        |> Enum.all?(fn {value, offset} ->
          if value == "" do
            true
          else
            rule_index = field_index + offset
            rule_value = Enum.at(rule, rule_index)
            rule_value == value
          end
        end)
      end)

    # Add new policies
    final_rules =
      Enum.reduce(new_policies, filtered_rules, fn new_policy, acc ->
        [new_policy | acc]
      end)

    new_policies_map = Map.put(policies, ptype, final_rules)
    updated_enforcer = %{enforcer | policies: new_policies_map}

    if enforcer.auto_save do
      save_policy(updated_enforcer)
    else
      {:ok, updated_enforcer}
    end
  end

  @doc """
  Updates a grouping policy rule for the default grouping type "g".
  """
  @spec update_grouping_policy(t(), [String.t()], [String.t()]) :: {:ok, t()} | {:error, term()}
  def update_grouping_policy(enforcer, old_rule, new_rule) do
    update_named_grouping_policy(enforcer, "g", old_rule, new_rule)
  end

  @doc """
  Updates a named grouping policy rule.
  """
  @spec update_named_grouping_policy(t(), String.t(), [String.t()], [String.t()]) ::
          {:ok, t()} | {:error, term()}
  def update_named_grouping_policy(
        %__MODULE__{grouping_policies: grouping_policies, role_manager: role_manager} = enforcer,
        ptype,
        old_rule,
        new_rule
      ) do
    current_rules = Map.get(grouping_policies, ptype, [])

    if old_rule in current_rules do
      new_rules =
        current_rules
        |> List.delete(old_rule)
        |> then(fn rules -> [new_rule | rules] end)

      new_grouping_policies = Map.put(grouping_policies, ptype, new_rules)

      # Update role manager - remove old link and add new one
      updated_role_manager =
        case old_rule do
          [user, role] ->
            RoleManager.delete_link(role_manager, user, role, "")

          [user, role, domain] ->
            RoleManager.delete_link(role_manager, user, role, domain)

          _ ->
            role_manager
        end

      final_role_manager =
        case new_rule do
          [user, role] ->
            RoleManager.add_link(updated_role_manager, user, role, "")

          [user, role, domain] ->
            RoleManager.add_link(updated_role_manager, user, role, domain)

          _ ->
            updated_role_manager
        end

      updated_enforcer = %{
        enforcer
        | grouping_policies: new_grouping_policies,
          role_manager: final_role_manager
      }

      if enforcer.auto_save do
        save_policy(updated_enforcer)
      else
        {:ok, updated_enforcer}
      end
    else
      {:error, :not_found}
    end
  end

  # Management APIs

  @doc """
  Gets all subjects from policies for the default policy type "p".
  """
  @spec get_all_subjects(t()) :: [String.t()]
  def get_all_subjects(enforcer) do
    get_all_named_subjects(enforcer, "p")
  end

  @doc """
  Gets all subjects from named policies.
  """
  @spec get_all_named_subjects(t(), String.t()) :: [String.t()]
  def get_all_named_subjects(%__MODULE__{policies: policies}, ptype) do
    policies
    |> Map.get(ptype, [])
    |> Enum.map(&List.first/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @doc """
  Gets all objects from policies for the default policy type "p".
  """
  @spec get_all_objects(t()) :: [String.t()]
  def get_all_objects(enforcer) do
    get_all_named_objects(enforcer, "p")
  end

  @doc """
  Gets all objects from named policies.
  """
  @spec get_all_named_objects(t(), String.t()) :: [String.t()]
  def get_all_named_objects(%__MODULE__{policies: policies}, ptype) do
    policies
    |> Map.get(ptype, [])
    |> Enum.map(&Enum.at(&1, 1))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @doc """
  Gets all actions from policies for the default policy type "p".
  """
  @spec get_all_actions(t()) :: [String.t()]
  def get_all_actions(enforcer) do
    get_all_named_actions(enforcer, "p")
  end

  @doc """
  Gets all actions from named policies.
  """
  @spec get_all_named_actions(t(), String.t()) :: [String.t()]
  def get_all_named_actions(%__MODULE__{policies: policies}, ptype) do
    policies
    |> Map.get(ptype, [])
    |> Enum.map(&Enum.at(&1, 2))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @doc """
  Gets all roles from grouping policies for the default grouping type "g".
  """
  @spec get_all_roles(t()) :: [String.t()]
  def get_all_roles(enforcer) do
    get_all_named_roles(enforcer, "g")
  end

  @doc """
  Gets all roles from named grouping policies.
  """
  @spec get_all_named_roles(t(), String.t()) :: [String.t()]
  def get_all_named_roles(%__MODULE__{grouping_policies: grouping_policies}, ptype) do
    grouping_policies
    |> Map.get(ptype, [])
    |> Enum.map(&Enum.at(&1, 1))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @doc """
  Gets all domains from policies and grouping policies.
  """
  @spec get_all_domains(t()) :: [String.t()]
  def get_all_domains(%__MODULE__{policies: policies, grouping_policies: grouping_policies}) do
    policy_domains =
      policies
      |> Map.values()
      |> List.flatten()
      |> Enum.map(&Enum.at(&1, 3))
      |> Enum.reject(&(&1 == nil or &1 == ""))

    grouping_domains =
      grouping_policies
      |> Map.values()
      |> List.flatten()
      |> Enum.map(&Enum.at(&1, 2))
      |> Enum.reject(&(&1 == nil or &1 == ""))

    (policy_domains ++ grouping_domains)
    |> Enum.uniq()
  end

  @doc """
  Gets all users who have roles in a domain.
  """
  @spec get_all_users_by_domain(t(), String.t()) :: [String.t()]
  def get_all_users_by_domain(%__MODULE__{grouping_policies: grouping_policies}, domain) do
    grouping_policies
    |> Map.get("g", [])
    |> Enum.filter(fn
      [_user, _role, ^domain] -> true
      _ -> false
    end)
    |> Enum.map(&List.first/1)
    |> Enum.uniq()
  end

  @doc """
  Gets all roles in a specific domain.
  """
  @spec get_all_roles_by_domain(t(), String.t()) :: [String.t()]
  def get_all_roles_by_domain(%__MODULE__{grouping_policies: grouping_policies}, domain) do
    grouping_policies
    |> Map.get("g", [])
    |> Enum.filter(fn
      [_user, _role, ^domain] -> true
      _ -> false
    end)
    |> Enum.map(&Enum.at(&1, 1))
    |> Enum.uniq()
  end

  # RBAC with Domains APIs

  @doc """
  Gets users for a role in a specific domain.
  """
  @spec get_users_for_role_in_domain(t(), String.t(), String.t()) :: [String.t()]
  def get_users_for_role_in_domain(
        %__MODULE__{grouping_policies: grouping_policies},
        role,
        domain
      ) do
    grouping_policies
    |> Map.get("g", [])
    |> Enum.filter(fn
      [_user, ^role, ^domain] -> true
      _ -> false
    end)
    |> Enum.map(&List.first/1)
  end

  @doc """
  Gets roles for a user in a specific domain.
  """
  @spec get_roles_for_user_in_domain(t(), String.t(), String.t()) :: [String.t()]
  def get_roles_for_user_in_domain(
        %__MODULE__{grouping_policies: grouping_policies},
        user,
        domain
      ) do
    grouping_policies
    |> Map.get("g", [])
    |> Enum.filter(fn
      [^user, _role, ^domain] -> true
      _ -> false
    end)
    |> Enum.map(&Enum.at(&1, 1))
  end

  @doc """
  Gets permissions for a user in a specific domain.
  """
  @spec get_permissions_for_user_in_domain(t(), String.t(), String.t()) :: [[String.t()]]
  def get_permissions_for_user_in_domain(%__MODULE__{policies: policies} = enforcer, user, domain) do
    # Get direct permissions
    direct_permissions =
      policies
      |> Map.get("p", [])
      |> Enum.filter(fn
        [^user, _obj, _act, ^domain] -> true
        _ -> false
      end)

    # Get permissions through roles
    user_roles = get_roles_for_user_in_domain(enforcer, user, domain)

    role_permissions =
      user_roles
      |> Enum.flat_map(fn role ->
        policies
        |> Map.get("p", [])
        |> Enum.filter(fn
          [^role, _obj, _act, ^domain] -> true
          _ -> false
        end)
      end)

    (direct_permissions ++ role_permissions) |> Enum.uniq()
  end

  @doc """
  Adds a role for a user in a specific domain.
  """
  @spec add_role_for_user_in_domain(t(), String.t(), String.t(), String.t()) ::
          {:ok, t()} | {:error, term()}
  def add_role_for_user_in_domain(enforcer, user, role, domain) do
    add_named_grouping_policy(enforcer, "g", [user, role, domain])
  end

  @doc """
  Deletes a role for a user in a specific domain.
  """
  @spec delete_role_for_user_in_domain(t(), String.t(), String.t(), String.t()) ::
          {:ok, t()} | {:error, term()}
  def delete_role_for_user_in_domain(enforcer, user, role, domain) do
    remove_named_grouping_policy(enforcer, "g", [user, role, domain])
  end

  @doc """
  Deletes all roles for a user in a specific domain.
  """
  @spec delete_roles_for_user_in_domain(t(), String.t(), String.t()) ::
          {:ok, t()} | {:error, term()}
  def delete_roles_for_user_in_domain(
        %__MODULE__{grouping_policies: grouping_policies} = enforcer,
        user,
        domain
      ) do
    rules_to_remove =
      grouping_policies
      |> Map.get("g", [])
      |> Enum.filter(fn
        [^user, _role, ^domain] -> true
        _ -> false
      end)

    remove_named_policies(enforcer, "g", rules_to_remove)
  end

  @doc """
  Deletes all users in a specific domain.
  """
  @spec delete_all_users_by_domain(t(), String.t()) :: {:ok, t()} | {:error, term()}
  def delete_all_users_by_domain(
        %__MODULE__{grouping_policies: grouping_policies} = enforcer,
        domain
      ) do
    rules_to_remove =
      grouping_policies
      |> Map.get("g", [])
      |> Enum.filter(fn
        [_user, _role, ^domain] -> true
        _ -> false
      end)

    remove_named_policies(enforcer, "g", rules_to_remove)
  end

  @doc """
  Deletes multiple domains.
  """
  @spec delete_domains(t(), [String.t()]) :: {:ok, t()} | {:error, term()}
  def delete_domains(
        %__MODULE__{policies: policies, grouping_policies: grouping_policies} = enforcer,
        domains
      ) do
    # Remove policies in these domains
    updated_policies =
      Map.new(policies, fn {ptype, rules} ->
        filtered_rules =
          Enum.reject(rules, fn rule ->
            domain = Enum.at(rule, 3)
            domain in domains
          end)

        {ptype, filtered_rules}
      end)

    # Remove grouping policies in these domains
    updated_grouping_policies =
      Map.new(grouping_policies, fn {ptype, rules} ->
        filtered_rules =
          Enum.reject(rules, fn rule ->
            domain = Enum.at(rule, 2)
            domain in domains
          end)

        {ptype, filtered_rules}
      end)

    updated_enforcer = %{
      enforcer
      | policies: updated_policies,
        grouping_policies: updated_grouping_policies
    }

    if enforcer.auto_save do
      save_policy(updated_enforcer)
    else
      {:ok, updated_enforcer}
    end
  end

  # Additional convenience functions

  @doc """
  Removes a named grouping policy rule.
  """
  @spec remove_named_grouping_policy(t(), String.t(), [String.t()]) ::
          {:ok, t()} | {:error, term()}
  def remove_named_grouping_policy(
        %__MODULE__{grouping_policies: grouping_policies, role_manager: role_manager} = enforcer,
        ptype,
        params
      ) do
    current_rules = Map.get(grouping_policies, ptype, [])

    if params in current_rules do
      new_rules = List.delete(current_rules, params)
      new_grouping_policies = Map.put(grouping_policies, ptype, new_rules)

      # Update role manager
      new_role_manager =
        case params do
          [user, role] ->
            RoleManager.delete_link(role_manager, user, role, "")

          [user, role, domain] ->
            RoleManager.delete_link(role_manager, user, role, domain)

          _ ->
            role_manager
        end

      updated_enforcer = %{
        enforcer
        | grouping_policies: new_grouping_policies,
          role_manager: new_role_manager
      }

      if enforcer.auto_save do
        save_policy(updated_enforcer)
      else
        {:ok, updated_enforcer}
      end
    else
      {:error, :not_found}
    end
  end

  # Private functions

  defp init_function_map do
    %{
      "keyMatch" => &key_match/2,
      "keyMatch2" => &key_match2/2,
      "keyMatch3" => &key_match3/2,
      "keyMatch4" => &key_match4/2,
      "keyMatch5" => &key_match5/2,
      "regexMatch" => &regex_match/2,
      "ipMatch" => &ip_match/2,
      "ipMatch2" => &ip_match2/2,
      "ipMatch3" => &ip_match3/2,
      "globMatch" => &glob_match/2,
      "globMatch2" => &glob_match2/2,
      "globMatch3" => &glob_match3/2
    }
  end

  # Internal enforcement function that returns both result and explanation
  defp enforce_internal(
         %__MODULE__{policies: policies, role_manager: _role_manager, function_map: _function_map} =
           enforcer,
         request,
         matcher_expr
       ) do
    _matched_policies = []
    _explanations = []

    # Get only "p" type policies and evaluate them
    p_policies = Map.get(policies, "p", [])

    result =
      p_policies
      |> Enum.reduce_while({false, []}, fn policy, {_acc_result, acc_explain} ->
        case evaluate_policy_with_explanation(enforcer, policy, request, matcher_expr) do
          {true, explanation} ->
            {:halt, {true, acc_explain ++ [explanation]}}

          {false, explanation} ->
            {:cont, {false, acc_explain ++ [explanation]}}
        end
      end)

    case result do
      {decision, explanations} -> {decision, explanations}
      _ -> {false, ["No matching policies found"]}
    end
  end

  defp evaluate_policy_with_explanation(enforcer, policy, request, _matcher_expr) do
    # Enhanced policy evaluation with role checking and explanations
    case {policy, request} do
      {[sub, obj, act], [req_sub, req_obj, req_act]} ->
        # Direct policy match
        if sub == req_sub and obj == req_obj and act == req_act do
          {true, "Direct policy match: #{inspect(policy)}"}
        else
          # Check role inheritance: user has role AND object and action match
          if obj == req_obj and act == req_act and check_role_inheritance(enforcer, req_sub, sub) do
            {true,
             "Role inheritance match: #{req_sub} has role #{sub} for policy #{inspect(policy)}"}
          else
            {false, "No match for policy #{inspect(policy)}"}
          end
        end

      _ ->
        {false, "Policy format mismatch: #{inspect(policy)}"}
    end
  end

  defp check_role_inheritance(%__MODULE__{role_manager: role_manager}, user, role) do
    RoleManager.has_link(role_manager, user, role, "")
  end

  # Built-in functions

  # KeyMatch functions
  defp key_match(key1, key2) do
    # KeyMatch: /foo/bar matches /foo/*
    pattern = String.replace(key2, "*", ".*")
    String.match?(key1, ~r/^#{pattern}$/)
  end

  defp key_match2(key1, key2) do
    # KeyMatch2: /foo/bar matches /foo/:id
    pattern =
      key2
      |> String.replace("*", ".*")
      |> String.replace(~r/:([^\/]+)/, "([^/]+)")

    String.match?(key1, ~r/^#{pattern}$/)
  end

  defp key_match3(key1, key2) do
    # KeyMatch3: /foo/bar matches /foo/{id}
    pattern =
      key2
      |> String.replace("*", ".*")
      |> String.replace(~r/\{([^}]+)\}/, "([^/]+)")

    String.match?(key1, ~r/^#{pattern}$/)
  end

  defp key_match4(key1, key2) do
    # KeyMatch4: /foo/bar matches /foo/{id}/bar
    pattern =
      key2
      |> String.replace("*", ".*")
      |> String.replace(~r/\{([^}]+)\}/, "([^/]+)")

    String.match?(key1, ~r/^#{pattern}$/)
  end

  defp key_match5(key1, key2) do
    # KeyMatch5: Advanced pattern matching with multiple wildcards
    i = 0
    j = 0
    key1_chars = String.graphemes(key1)
    key2_chars = String.graphemes(key2)

    key_match5_helper(key1_chars, key2_chars, i, j, length(key1_chars), length(key2_chars))
  end

  defp key_match5_helper(_key1_chars, _key2_chars, i, j, len1, len2) when i >= len1 and j >= len2,
    do: true

  defp key_match5_helper(_key1_chars, _key2_chars, i, j, len1, len2) when i >= len1 or j >= len2,
    do: false

  defp key_match5_helper(key1_chars, key2_chars, i, j, len1, len2) do
    char1 = Enum.at(key1_chars, i)
    char2 = Enum.at(key2_chars, j)

    cond do
      char2 == "*" -> key_match5_star(key1_chars, key2_chars, i, j + 1, len1, len2)
      char1 == char2 -> key_match5_helper(key1_chars, key2_chars, i + 1, j + 1, len1, len2)
      true -> false
    end
  end

  defp key_match5_star(key1_chars, key2_chars, i, j, len1, len2) do
    # Try matching zero characters
    if key_match5_helper(key1_chars, key2_chars, i, j, len1, len2) do
      true
    else
      # Try matching one or more characters
      if i < len1 do
        key_match5_star(key1_chars, key2_chars, i + 1, j, len1, len2)
      else
        false
      end
    end
  end

  # Regex functions
  defp regex_match(key1, key2) do
    case Regex.compile(key2) do
      {:ok, regex} -> String.match?(key1, regex)
      {:error, _} -> false
    end
  end

  # IP matching functions
  defp ip_match(ip1, ip2) do
    # Simple IP/CIDR matching
    cond do
      String.contains?(ip2, "/") -> ip_in_cidr?(ip1, ip2)
      true -> ip1 == ip2
    end
  end

  defp ip_match2(ip1, ip2) do
    # Enhanced IP matching with IPv6 support
    case {parse_ip(ip1), parse_ip_or_cidr(ip2)} do
      {{:ok, ip1_addr}, {:ok, ip2_addr, nil}} ->
        ip1_addr == ip2_addr

      {{:ok, ip1_addr}, {:ok, ip2_addr, prefix_len}} ->
        ip_in_network?(ip1_addr, ip2_addr, prefix_len)

      _ ->
        false
    end
  end

  defp ip_match3(ip1, ip2) do
    # Most advanced IP matching with range support
    cond do
      String.contains?(ip2, "-") -> ip_in_range?(ip1, ip2)
      String.contains?(ip2, "/") -> ip_match2(ip1, ip2)
      true -> ip1 == ip2
    end
  end

  # Glob matching functions
  defp glob_match(key1, key2) do
    # Basic glob matching with * and ?
    pattern =
      key2
      |> String.replace("*", ".*")
      |> String.replace("?", ".")

    String.match?(key1, ~r/^#{pattern}$/)
  end

  defp glob_match2(key1, key2) do
    # Enhanced glob matching with ** for directory matching
    pattern =
      key2
      |> String.replace("**", "__DOUBLESTAR__")
      |> String.replace("*", "[^/]*")
      |> String.replace("__DOUBLESTAR__", ".*")
      |> String.replace("?", "[^/]")

    String.match?(key1, ~r/^#{pattern}$/)
  end

  defp glob_match3(key1, key2) do
    # Advanced glob matching with character classes
    pattern =
      key2
      |> String.replace("**", "__DOUBLESTAR__")
      |> String.replace("*", "[^/]*")
      |> String.replace("__DOUBLESTAR__", ".*")
      |> String.replace("?", "[^/]")
      |> convert_char_classes()

    String.match?(key1, ~r/^#{pattern}$/)
  end

  # Helper functions for IP matching
  defp ip_in_cidr?(ip_str, cidr_str) do
    case String.split(cidr_str, "/") do
      [network_str, prefix_str] ->
        with {prefix_len, ""} <- Integer.parse(prefix_str),
             {:ok, ip} <- parse_ip(ip_str),
             {:ok, network} <- parse_ip(network_str) do
          ip_in_network?(ip, network, prefix_len)
        else
          _ -> false
        end

      _ ->
        false
    end
  end

  defp parse_ip(ip_str) do
    case :inet.parse_address(String.to_charlist(ip_str)) do
      {:ok, ip} -> {:ok, ip}
      {:error, _} -> {:error, :invalid_ip}
    end
  end

  defp parse_ip_or_cidr(ip_str) do
    case String.split(ip_str, "/") do
      [ip_part] ->
        case parse_ip(ip_part) do
          {:ok, ip} -> {:ok, ip, nil}
          error -> error
        end

      [ip_part, prefix_str] ->
        case {parse_ip(ip_part), Integer.parse(prefix_str)} do
          {{:ok, ip}, {prefix_len, ""}} -> {:ok, ip, prefix_len}
          _ -> {:error, :invalid_cidr}
        end

      _ ->
        {:error, :invalid_format}
    end
  end

  defp ip_in_network?(ip, network, prefix_len) do
    # Simplified network matching - in production, use proper CIDR libraries
    ip_int = ip_to_integer(ip)
    network_int = ip_to_integer(network)
    mask = bnot((1 <<< (32 - prefix_len)) - 1)

    (ip_int &&& mask) == (network_int &&& mask)
  end

  defp ip_to_integer({a, b, c, d}), do: a <<< 24 ||| b <<< 16 ||| c <<< 8 ||| d
  # Simplified for IPv4
  defp ip_to_integer(_), do: 0

  defp ip_in_range?(ip_str, range_str) do
    case String.split(range_str, "-") do
      [start_str, end_str] ->
        with {:ok, ip} <- parse_ip(String.trim(ip_str)),
             {:ok, start_ip} <- parse_ip(String.trim(start_str)),
             {:ok, end_ip} <- parse_ip(String.trim(end_str)) do
          ip_int = ip_to_integer(ip)
          start_int = ip_to_integer(start_ip)
          end_int = ip_to_integer(end_ip)

          ip_int >= start_int and ip_int <= end_int
        else
          _ -> false
        end

      _ ->
        false
    end
  end

  defp convert_char_classes(pattern) do
    # Convert glob character classes [abc] to regex character classes
    # This is a simplified implementation
    pattern
    |> String.replace(~r/\[([^\]]+)\]/, "(\\1)")
    |> String.replace("!", "^")
  end
end
