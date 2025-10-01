defmodule CasbinEx2.Enforcer do
  @moduledoc """
  The main enforcer struct for Casbin authorization.

  This module provides the core functionality for policy enforcement,
  policy management, and role-based access control (RBAC).
  """

  import Bitwise
  alias CasbinEx2.Adapter
  alias CasbinEx2.Adapter.FileAdapter
  alias CasbinEx2.Logger, as: CasbinLogger
  alias CasbinEx2.Management
  alias CasbinEx2.Model
  alias CasbinEx2.RBAC
  alias CasbinEx2.RoleManager
  alias CasbinEx2.Transaction

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
    :auto_notify_dispatcher,
    :log_enabled,
    :accept_json_request,
    :dispatcher,
    :effector,
    :named_role_managers,
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
          auto_notify_dispatcher: boolean(),
          log_enabled: boolean(),
          accept_json_request: boolean(),
          dispatcher: any() | nil,
          effector: any() | nil,
          named_role_managers: map(),
          policies: map(),
          grouping_policies: map()
        }

  @doc """
  Creates a new enforcer with model and adapter.

  ## Examples

      model = CasbinEx2.Model.new()
      adapter = CasbinEx2.Adapter.MemoryAdapter.new()
      enforcer = CasbinEx2.Enforcer.new(model, adapter)
  """
  @spec new(Model.t(), Adapter.t()) :: t()
  def new(model, adapter) do
    case init_with_model_and_adapter(model, adapter) do
      {:ok, enforcer} -> enforcer
      {:error, reason} -> raise "Failed to create enforcer: #{inspect(reason)}"
    end
  end

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
    adapter = FileAdapter.new(policy_path)
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
      auto_notify_dispatcher: false,
      log_enabled: true,
      accept_json_request: false,
      function_map: init_function_map(),
      role_manager: RoleManager.new_role_manager(10),
      named_role_managers: %{}
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
    _start_time = System.monotonic_time(:microsecond)
    {result, explain} = enforce_internal(enforcer, request, matcher_expr)
    _end_time = System.monotonic_time(:microsecond)

    # Log enforcement decision and performance
    _explanation =
      case explain do
        nil -> "No explanation"
        [] -> "No explanation"
        [first | _] -> first
        other -> to_string(other)
      end

    # CasbinLogger.log_enforcement(request, result, explanation)
    # CasbinLogger.log_performance(:enforcement, end_time - start_time, %{request: request})

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
  Batch enforcement for multiple requests with concurrent processing.
  Uses Task.async_stream for better performance on large request batches.
  """
  @spec batch_enforce(t(), [list()]) :: [boolean()]
  def batch_enforce(enforcer, requests) when length(requests) > 10 do
    # Use concurrent processing for larger batches
    requests
    |> Task.async_stream(
      fn request -> enforce(enforcer, request) end,
      max_concurrency: System.schedulers_online(),
      timeout: 5000
    )
    |> Enum.map(fn {:ok, result} -> result end)
  end

  def batch_enforce(enforcer, requests) do
    # Use sequential processing for smaller batches to avoid overhead
    Enum.map(requests, &enforce(enforcer, &1))
  end

  @doc """
  Batch enforcement with custom matcher and concurrent processing.
  """
  @spec batch_enforce_with_matcher(t(), String.t(), [list()]) :: [boolean()]
  def batch_enforce_with_matcher(enforcer, matcher, requests) when length(requests) > 10 do
    # Use concurrent processing for larger batches
    requests
    |> Task.async_stream(
      fn request -> enforce_with_matcher(enforcer, matcher, request) end,
      max_concurrency: System.schedulers_online(),
      timeout: 5000
    )
    |> Enum.map(fn {:ok, result} -> result end)
  end

  def batch_enforce_with_matcher(enforcer, matcher, requests) do
    # Use sequential processing for smaller batches
    Enum.map(requests, &enforce_with_matcher(enforcer, matcher, &1))
  end

  @doc """
  Batch enforcement with explanations for multiple requests.
  """
  @spec batch_enforce_ex(t(), [list()]) :: [{boolean(), [String.t()]}]
  def batch_enforce_ex(enforcer, requests) when length(requests) > 10 do
    # Use concurrent processing for larger batches
    requests
    |> Task.async_stream(
      fn request -> enforce_ex(enforcer, request) end,
      max_concurrency: System.schedulers_online(),
      timeout: 5000
    )
    |> Enum.map(fn {:ok, result} -> result end)
  end

  def batch_enforce_ex(enforcer, requests) do
    # Use sequential processing for smaller batches
    Enum.map(requests, &enforce_ex(enforcer, &1))
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
    process_grouping_policies(role_manager, grouping_policies)

    {:ok, enforcer}
  end

  defp process_grouping_policies(role_manager, grouping_policies) do
    grouping_policies
    |> Map.values()
    |> List.flatten()
    |> Enum.each(fn policy ->
      add_role_link_if_valid(role_manager, policy)
    end)
  end

  defp add_role_link_if_valid(role_manager, policy) do
    case policy do
      policy when is_list(policy) and length(policy) >= 2 ->
        add_role_link_from_policy(role_manager, policy)

      _ ->
        # Skip invalid policies
        :ok
    end
  end

  defp add_role_link_from_policy(role_manager, policy) do
    [user, role | domain] = policy
    domain_value = extract_domain_value(domain)
    RoleManager.add_link(role_manager, user, role, domain_value)
  end

  defp extract_domain_value([]), do: ""
  defp extract_domain_value(domain), do: hd(domain)

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

  @doc """
  Enables or disables auto-build role links.

  When enabled, role links are automatically rebuilt after policy changes.

  ## Examples

      enforcer = enable_auto_build_role_links(enforcer, true)
  """
  @spec enable_auto_build_role_links(t(), boolean()) :: t()
  def enable_auto_build_role_links(enforcer, enable) do
    %{enforcer | auto_build_role_links: enable}
  end

  @doc """
  Enables or disables auto-notify watcher.

  When enabled, the watcher is automatically notified of policy changes.

  ## Examples

      enforcer = enable_auto_notify_watcher(enforcer, true)
  """
  @spec enable_auto_notify_watcher(t(), boolean()) :: t()
  def enable_auto_notify_watcher(enforcer, enable) do
    %{enforcer | auto_notify_watcher: enable}
  end

  @doc """
  Enables or disables auto-notify dispatcher.

  When enabled, the dispatcher is automatically notified of policy changes.

  ## Examples

      enforcer = enable_auto_notify_dispatcher(enforcer, true)
  """
  @spec enable_auto_notify_dispatcher(t(), boolean()) :: t()
  def enable_auto_notify_dispatcher(enforcer, enable) do
    %{enforcer | auto_notify_dispatcher: enable}
  end

  @doc """
  Enables or disables logging.

  ## Examples

      enforcer = enable_log(enforcer, true)
  """
  @spec enable_log(t(), boolean()) :: t()
  def enable_log(enforcer, enable) do
    %{enforcer | log_enabled: enable}
  end

  @doc """
  Checks if logging is enabled.

  ## Examples

      is_log_enabled(enforcer)
      #=> true
  """
  @spec is_log_enabled(t()) :: boolean()
  def is_log_enabled(%__MODULE__{log_enabled: log_enabled}) do
    log_enabled || false
  end

  @doc """
  Enables or disables JSON request acceptance.

  When enabled, the enforcer can parse and accept JSON-formatted requests.

  ## Examples

      enforcer = enable_accept_json_request(enforcer, true)
  """
  @spec enable_accept_json_request(t(), boolean()) :: t()
  def enable_accept_json_request(enforcer, enable) do
    %{enforcer | accept_json_request: enable}
  end

  # Runtime Component Management

  @doc """
  Sets the adapter at runtime.

  ## Examples

      new_adapter = FileAdapter.new("new_policy.csv")
      enforcer = set_adapter(enforcer, new_adapter)
  """
  @spec set_adapter(t(), Adapter.t()) :: t()
  def set_adapter(enforcer, adapter) do
    %{enforcer | adapter: adapter}
  end

  @doc """
  Gets the current adapter.

  ## Examples

      adapter = get_adapter(enforcer)
  """
  @spec get_adapter(t()) :: Adapter.t() | nil
  def get_adapter(%__MODULE__{adapter: adapter}) do
    adapter
  end

  @doc """
  Sets the effector at runtime.

  ## Examples

      enforcer = set_effector(enforcer, custom_effector)
  """
  @spec set_effector(t(), any()) :: t()
  def set_effector(enforcer, effector) do
    %{enforcer | effector: effector}
  end

  @doc """
  Sets the model at runtime.

  ## Examples

      new_model = Model.new()
      enforcer = set_model(enforcer, new_model)
  """
  @spec set_model(t(), Model.t()) :: t()
  def set_model(enforcer, model) do
    %{enforcer | model: model}
  end

  @doc """
  Gets the current model.

  ## Examples

      model = get_model(enforcer)
  """
  @spec get_model(t()) :: Model.t() | nil
  def get_model(%__MODULE__{model: model}) do
    model
  end

  @doc """
  Sets the watcher at runtime.

  ## Examples

      enforcer = set_watcher(enforcer, watcher)
  """
  @spec set_watcher(t(), any()) :: {:ok, t()} | {:error, term()}
  def set_watcher(enforcer, watcher) do
    {:ok, %{enforcer | watcher: watcher}}
  end

  @doc """
  Sets the role manager at runtime.

  ## Examples

      rm = RoleManager.new_role_manager(10)
      enforcer = set_role_manager(enforcer, rm)
  """
  @spec set_role_manager(t(), RoleManager.t()) :: t()
  def set_role_manager(enforcer, role_manager) do
    %{enforcer | role_manager: role_manager}
  end

  @doc """
  Gets the current role manager.

  ## Examples

      rm = get_role_manager(enforcer)
  """
  @spec get_role_manager(t()) :: RoleManager.t() | nil
  def get_role_manager(%__MODULE__{role_manager: role_manager}) do
    role_manager
  end

  @doc """
  Sets a named role manager.

  ## Examples

      rm = RoleManager.new_role_manager(10)
      enforcer = set_named_role_manager(enforcer, "g2", rm)
  """
  @spec set_named_role_manager(t(), String.t(), RoleManager.t()) :: t()
  def set_named_role_manager(enforcer, ptype, role_manager) do
    named_rms = Map.put(enforcer.named_role_managers, ptype, role_manager)
    %{enforcer | named_role_managers: named_rms}
  end

  @doc """
  Gets a named role manager.

  ## Examples

      rm = get_named_role_manager(enforcer, "g2")
  """
  @spec get_named_role_manager(t(), String.t()) :: RoleManager.t() | nil
  def get_named_role_manager(%__MODULE__{named_role_managers: named_rms}, ptype) do
    Map.get(named_rms, ptype)
  end

  # Transaction Support

  @doc """
  Creates a new transaction for atomic policy operations.

  ## Examples

      {:ok, transaction} = new_transaction(enforcer)

  """
  @spec new_transaction(t()) :: {:ok, Transaction.t()}
  def new_transaction(enforcer) do
    Transaction.new(enforcer)
  end

  @doc """
  Commits a transaction, applying all operations atomically.

  ## Examples

      {:ok, updated_enforcer} = commit_transaction(transaction)

  """
  @spec commit_transaction(Transaction.t()) :: {:ok, t()} | {:error, term()}
  def commit_transaction(transaction) do
    case Transaction.commit(transaction) do
      {:ok, updated_enforcer} ->
        CasbinLogger.log_adapter_operation(
          :transaction_commit,
          :success,
          Transaction.operation_count(transaction)
        )

        {:ok, updated_enforcer}

      {:error, reason} = error ->
        CasbinLogger.log_error(
          :transaction_error,
          "Transaction commit failed: #{inspect(reason)}",
          %{transaction_id: Transaction.id(transaction)}
        )

        error
    end
  end

  @doc """
  Rolls back a transaction without applying operations.

  ## Examples

      {:ok, original_enforcer} = rollback_transaction(transaction)

  """
  @spec rollback_transaction(Transaction.t()) :: {:ok, t()}
  def rollback_transaction(transaction) do
    result = Transaction.rollback(transaction)

    CasbinLogger.log_adapter_operation(
      :transaction_rollback,
      :success,
      Transaction.operation_count(transaction)
    )

    result
  end

  # =============================================================================
  # DELEGATION TO MANAGEMENT AND RBAC MODULES
  # =============================================================================
  #
  # The following functions delegate to separate Management and RBAC modules
  # to maintain structural parity with the Golang Casbin implementation.
  # This provides better code organization while maintaining identical API.

  # Management API Delegation (corresponds to management_api.go)
  defdelegate get_all_subjects(enforcer), to: Management
  defdelegate get_all_named_subjects(enforcer, ptype), to: Management
  defdelegate get_all_objects(enforcer), to: Management
  defdelegate get_all_named_objects(enforcer, ptype), to: Management
  defdelegate get_all_actions(enforcer), to: Management
  defdelegate get_all_named_actions(enforcer, ptype), to: Management
  defdelegate get_all_roles(enforcer), to: Management
  defdelegate get_all_named_roles(enforcer, ptype), to: Management

  defdelegate get_policy(enforcer), to: Management
  defdelegate get_named_policy(enforcer, ptype), to: Management
  defdelegate get_filtered_policy(enforcer, field_index, field_values), to: Management

  defdelegate get_filtered_named_policy(enforcer, ptype, field_index, field_values),
    to: Management

  defdelegate get_grouping_policy(enforcer), to: Management
  defdelegate get_named_grouping_policy(enforcer, ptype), to: Management
  defdelegate get_filtered_grouping_policy(enforcer, field_index, field_values), to: Management

  defdelegate get_filtered_named_grouping_policy(enforcer, ptype, field_index, field_values),
    to: Management

  defdelegate has_policy(enforcer, params), to: Management
  defdelegate has_named_policy(enforcer, ptype, params), to: Management
  defdelegate has_grouping_policy(enforcer, params), to: Management
  defdelegate has_named_grouping_policy(enforcer, ptype, params), to: Management

  defdelegate add_policy(enforcer, params), to: Management
  defdelegate add_named_policy(enforcer, ptype, params), to: Management
  defdelegate add_policies(enforcer, rules), to: Management
  defdelegate add_named_policies(enforcer, ptype, rules), to: Management

  defdelegate remove_policy(enforcer, params), to: Management
  defdelegate remove_named_policy(enforcer, ptype, params), to: Management
  defdelegate remove_policies(enforcer, rules), to: Management
  defdelegate remove_named_policies(enforcer, ptype, rules), to: Management
  defdelegate remove_filtered_policy(enforcer, field_index, field_values), to: Management

  defdelegate remove_filtered_named_policy(enforcer, ptype, field_index, field_values),
    to: Management

  defdelegate update_policy(enforcer, old_rule, new_rule), to: Management
  defdelegate update_named_policy(enforcer, ptype, old_rule, new_rule), to: Management
  defdelegate update_policies(enforcer, old_rules, new_rules), to: Management
  defdelegate update_named_policies(enforcer, ptype, old_rules, new_rules), to: Management

  # RBAC API Delegation (corresponds to rbac_api.go)
  defdelegate get_roles_for_user(enforcer, user), to: RBAC
  defdelegate get_roles_for_user(enforcer, user, domain), to: RBAC
  defdelegate get_users_for_role(enforcer, role), to: RBAC
  defdelegate get_users_for_role(enforcer, role, domain), to: RBAC
  defdelegate has_role_for_user(enforcer, user, role), to: RBAC
  defdelegate has_role_for_user(enforcer, user, role, domain), to: RBAC

  defdelegate add_role_for_user(enforcer, user, role), to: RBAC
  defdelegate add_role_for_user(enforcer, user, role, domain), to: RBAC

  defdelegate delete_role_for_user(enforcer, user, role), to: RBAC
  defdelegate delete_role_for_user(enforcer, user, role, domain), to: RBAC
  defdelegate delete_roles_for_user(enforcer, user), to: RBAC
  defdelegate delete_roles_for_user(enforcer, user, domain), to: RBAC

  defdelegate delete_user(enforcer, user), to: RBAC
  defdelegate delete_role(enforcer, role), to: RBAC
  defdelegate delete_permission(enforcer, permission), to: RBAC

  defdelegate add_permission_for_user(enforcer, user, permission), to: RBAC
  defdelegate add_permissions_for_user(enforcer, user, permissions), to: RBAC
  defdelegate delete_permission_for_user(enforcer, user, permission), to: RBAC
  defdelegate delete_permissions_for_user(enforcer, user), to: RBAC

  defdelegate get_named_permissions_for_user(enforcer, ptype, user), to: RBAC
  defdelegate get_named_permissions_for_user(enforcer, ptype, user, domain), to: RBAC
  defdelegate has_permission_for_user(enforcer, user, permission), to: RBAC

  # Domain-specific RBAC functions
  defdelegate get_users_for_role_in_domain(enforcer, role, domain), to: RBAC
  defdelegate get_roles_for_user_in_domain(enforcer, user, domain), to: RBAC
  defdelegate get_permissions_for_user_in_domain(enforcer, user, domain), to: RBAC
  defdelegate add_role_for_user_in_domain(enforcer, user, role, domain), to: RBAC
  defdelegate delete_role_for_user_in_domain(enforcer, user, role, domain), to: RBAC

  # =============================================================================
  # LEGACY IMPLEMENTATIONS (TO BE REMOVED)
  # =============================================================================
  #
  # The following are the original implementations that will be removed
  # once delegation is confirmed working. They are kept temporarily for
  # backward compatibility during the transition.

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
      CasbinLogger.log_error(:policy_error, "Policy already exists: #{ptype} #{inspect(params)}")
      {:error, :already_exists}
    else
      new_rules = [params | current_rules]
      new_policies = Map.put(policies, ptype, new_rules)
      updated_enforcer = %{enforcer | policies: new_policies}

      CasbinLogger.log_policy_change(:add, ptype, params)

      maybe_save_policy(updated_enforcer, enforcer.auto_save)
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
  Removes multiple named grouping policy rules.
  """
  @spec remove_named_grouping_policies(t(), String.t(), [[String.t()]]) ::
          {:ok, t()} | {:error, term()}
  def remove_named_grouping_policies(
        %__MODULE__{grouping_policies: grouping_policies} = enforcer,
        ptype,
        rules
      ) do
    current_rules = Map.get(grouping_policies, ptype, [])

    new_rules =
      Enum.reduce(rules, current_rules, fn rule, acc ->
        List.delete(acc, rule)
      end)

    new_grouping_policies = Map.put(grouping_policies, ptype, new_rules)
    updated_enforcer = %{enforcer | grouping_policies: new_grouping_policies}

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
      rule_matches_filter?(rule, field_index, field_values)
    end)
  end

  defp rule_matches_filter?(rule, field_index, field_values) do
    field_values
    |> Enum.with_index()
    |> Enum.all?(fn {value, offset} ->
      field_value_matches?(rule, field_index + offset, value)
    end)
  end

  defp field_value_matches?(_rule, _rule_index, ""), do: true

  defp field_value_matches?(rule, rule_index, value) do
    Enum.at(rule, rule_index) == value
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

  @doc """
  Removes filtered policy rules for the default policy type "p".
  """
  @spec remove_filtered_policy(t(), integer(), [String.t()]) :: {:ok, t()} | {:error, term()}
  def remove_filtered_policy(enforcer, field_index, field_values) do
    remove_filtered_named_policy(enforcer, "p", field_index, field_values)
  end

  @doc """
  Removes filtered named policy rules.
  """
  @spec remove_filtered_named_policy(t(), String.t(), integer(), [String.t()]) ::
          {:ok, t()} | {:error, term()}
  def remove_filtered_named_policy(
        %__MODULE__{policies: policies} = enforcer,
        ptype,
        field_index,
        field_values
      ) do
    current_rules = Map.get(policies, ptype, [])

    # Filter out rules that match the criteria
    filtered_rules =
      Enum.reject(current_rules, fn rule ->
        rule_matches_filter?(rule, field_index, field_values)
      end)

    new_policies = Map.put(policies, ptype, filtered_rules)
    updated_enforcer = %{enforcer | policies: new_policies}

    if enforcer.auto_save do
      save_policy(updated_enforcer)
    else
      {:ok, updated_enforcer}
    end
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
  Adds multiple named grouping policy rules.
  """
  @spec add_named_grouping_policies(t(), String.t(), [[String.t()]]) ::
          {:ok, t()} | {:error, term()}
  def add_named_grouping_policies(
        %__MODULE__{grouping_policies: grouping_policies, role_manager: role_manager} = enforcer,
        ptype,
        rules
      ) do
    current_rules = Map.get(grouping_policies, ptype, [])

    new_rules =
      Enum.reduce(rules, current_rules, fn rule, acc ->
        if rule in acc do
          acc
        else
          [rule | acc]
        end
      end)

    new_grouping_policies = Map.put(grouping_policies, ptype, new_rules)

    # Update role manager for all new rules
    updated_role_manager =
      Enum.reduce(rules, role_manager, fn params, rm ->
        case params do
          [user, role] ->
            RoleManager.add_link(rm, user, role, "")

          [user, role, domain] ->
            RoleManager.add_link(rm, user, role, domain)

          _ ->
            rm
        end
      end)

    updated_enforcer = %{
      enforcer
      | grouping_policies: new_grouping_policies,
        role_manager: updated_role_manager
    }

    if enforcer.auto_save do
      save_policy(updated_enforcer)
    else
      {:ok, updated_enforcer}
    end
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
    case validate_policy_lengths(old_policies, new_policies) do
      :ok -> perform_policy_update(enforcer, policies, ptype, old_policies, new_policies)
      error -> error
    end
  end

  defp validate_policy_lengths(old_policies, new_policies) do
    if length(old_policies) == length(new_policies) do
      :ok
    else
      {:error, :length_mismatch}
    end
  end

  defp perform_policy_update(enforcer, policies, ptype, old_policies, new_policies) do
    current_rules = Map.get(policies, ptype, [])

    case validate_existing_policies(old_policies, current_rules) do
      :ok ->
        execute_policy_update(
          enforcer,
          policies,
          ptype,
          current_rules,
          old_policies,
          new_policies
        )

      error ->
        error
    end
  end

  defp validate_existing_policies(old_policies, current_rules) do
    missing_policies = Enum.reject(old_policies, &(&1 in current_rules))

    if missing_policies == [] do
      :ok
    else
      {:error, {:not_found, missing_policies}}
    end
  end

  defp execute_policy_update(enforcer, policies, ptype, current_rules, old_policies, new_policies) do
    updated_rules = remove_old_policies(old_policies, current_rules)
    final_rules = add_new_policies(new_policies, updated_rules)
    updated_enforcer = %{enforcer | policies: Map.put(policies, ptype, final_rules)}

    if enforcer.auto_save do
      save_policy(updated_enforcer)
    else
      {:ok, updated_enforcer}
    end
  end

  defp remove_old_policies(old_policies, current_rules) do
    Enum.reduce(old_policies, current_rules, fn old_policy, acc ->
      List.delete(acc, old_policy)
    end)
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
    filtered_rules = filter_matching_policies(current_rules, field_index, field_values)
    final_rules = add_new_policies(new_policies, filtered_rules)

    updated_enforcer = %{enforcer | policies: Map.put(policies, ptype, final_rules)}

    if enforcer.auto_save do
      save_policy(updated_enforcer)
    else
      {:ok, updated_enforcer}
    end
  end

  defp filter_matching_policies(current_rules, field_index, field_values) do
    Enum.reject(current_rules, fn rule ->
      matches_filter_criteria?(rule, field_index, field_values)
    end)
  end

  defp matches_filter_criteria?(rule, field_index, field_values) do
    field_values
    |> Enum.with_index()
    |> Enum.all?(fn {value, offset} ->
      field_matches?(rule, field_index + offset, value)
    end)
  end

  defp field_matches?(_rule, _rule_index, ""), do: true

  defp field_matches?(rule, rule_index, value) do
    Enum.at(rule, rule_index) == value
  end

  defp add_new_policies(new_policies, filtered_rules) do
    Enum.reduce(new_policies, filtered_rules, fn new_policy, acc ->
      [new_policy | acc]
    end)
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
      # Only flatten one level
      |> Enum.flat_map(& &1)
      |> Enum.filter(&is_list/1)
      |> Enum.map(&Enum.at(&1, 3))
      |> Enum.reject(&(&1 == nil or &1 == ""))

    grouping_domains =
      grouping_policies
      |> Map.values()
      # Only flatten one level
      |> Enum.flat_map(& &1)
      |> Enum.filter(&is_list/1)
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

    remove_named_grouping_policies(enforcer, "g", rules_to_remove)
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

    remove_named_grouping_policies(enforcer, "g", rules_to_remove)
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
         %__MODULE__{
           policies: policies,
           grouping_policies: grouping_policies,
           function_map: function_map,
           role_manager: role_manager
         } = _enforcer,
         request,
         matcher_expr
       ) do
    # Add g function to function map for role inheritance checking
    enhanced_function_map =
      Map.put(function_map, "g", fn arg1, arg2, arg3 ->
        check_grouping_policy(grouping_policies, arg1, arg2, arg3) ||
          CasbinEx2.RoleManager.has_link(role_manager, arg1, arg2, arg3)
      end)

    # Get only "p" type policies and evaluate them using the matcher expression
    p_policies = Map.get(policies, "p", [])

    result =
      p_policies
      |> Enum.reduce_while({false, []}, fn policy, {_acc_result, _acc_explain} ->
        case evaluate_matcher_expression(matcher_expr, request, policy, enhanced_function_map) do
          {:ok, true} ->
            explanation = "Policy matched: #{inspect(policy)} with request: #{inspect(request)}"
            {:halt, {true, [explanation]}}

          {:ok, false} ->
            explanation =
              "Policy did not match: #{inspect(policy)} with request: #{inspect(request)}"

            {:cont, {false, [explanation]}}

          {:error, reason} ->
            explanation = "Error evaluating policy #{inspect(policy)}: #{reason}"
            {:cont, {false, [explanation]}}
        end
      end)

    case result do
      {decision, explanations} -> {decision, explanations}
      _ -> {false, ["No matching policies found"]}
    end
  end

  # Check if a grouping policy exists for the given arguments
  defp check_grouping_policy(grouping_policies, arg1, arg2, arg3) do
    g_policies = Map.get(grouping_policies, "g", [])

    Enum.any?(g_policies, fn policy ->
      case policy do
        [p_arg1, p_arg2, p_arg3] ->
          arg1 == p_arg1 && arg2 == p_arg2 && arg3 == p_arg3

        [p_arg1, p_arg2] when arg3 == "" ->
          # Handle 2-argument case where domain is empty
          arg1 == p_arg1 && arg2 == p_arg2

        _ ->
          false
      end
    end)
  end

  # Evaluate matcher expression by substituting values and calling functions
  defp evaluate_matcher_expression(matcher_expr, request, policy, function_map) do
    # Parse and evaluate the expression
    # For now, implement a simple parser for expressions like:
    # "ipMatch(r.sub, p.sub) && r.obj == p.obj && r.act == p.act"

    case parse_and_evaluate_expression(matcher_expr, request, policy, function_map) do
      {:ok, result} when is_boolean(result) -> {:ok, result}
      # Non-boolean results are treated as false
      {:ok, _result} -> {:ok, false}
      {:error, reason} -> {:error, reason}
    end
  rescue
    e -> {:error, "Expression evaluation error: #{inspect(e)}"}
  end

  # Simple expression parser and evaluator
  defp parse_and_evaluate_expression(expr, request, policy, function_map) do
    # Handle basic expressions with && operator
    if String.contains?(expr, "&&") do
      parts = String.split(expr, "&&") |> Enum.map(&String.trim/1)
      evaluate_and_expression(parts, request, policy, function_map)
    else
      # Single expression
      evaluate_single_expression(expr, request, policy, function_map)
    end
  end

  defp evaluate_and_expression(parts, request, policy, function_map) do
    results =
      Enum.map(parts, fn part ->
        case evaluate_single_expression(part, request, policy, function_map) do
          {:ok, result} -> result
          {:error, _reason} -> false
        end
      end)

    # All parts must be true for AND expression
    all_true = Enum.all?(results, fn result -> result == true end)
    {:ok, all_true}
  end

  defp evaluate_single_expression(expr, request, policy, function_map) do
    cond do
      # Handle function calls like "ipMatch(r.sub, p.sub)"
      String.contains?(expr, "(") and String.contains?(expr, ")") ->
        evaluate_function_call(expr, request, policy, function_map)

      # Handle equality comparisons like "r.obj == p.obj"
      String.contains?(expr, "==") ->
        evaluate_equality(expr, request, policy)

      # Handle other comparisons (>=, <=, etc.)
      String.contains?(expr, ">=") ->
        evaluate_comparison(expr, request, policy, ">=")

      String.contains?(expr, "<=") ->
        evaluate_comparison(expr, request, policy, "<=")

      true ->
        {:error, "Unsupported expression: #{expr}"}
    end
  end

  defp evaluate_function_call(expr, request, policy, function_map) do
    # Parse function call like "ipMatch(r.sub, p.sub)"
    case parse_function_call(expr) do
      {:ok, func_name, args_str} ->
        execute_function_call(func_name, args_str, request, policy, function_map)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_function_call(expr) do
    case Regex.run(~r/^(\w+)\((.+)\)$/, String.trim(expr)) do
      [_, func_name, args_str] -> {:ok, func_name, args_str}
      nil -> {:error, "Invalid function call syntax: #{expr}"}
    end
  end

  defp execute_function_call(func_name, args_str, request, policy, function_map) do
    case Map.get(function_map, func_name) do
      nil ->
        {:error, "Unknown function: #{func_name}"}

      func ->
        args = String.split(args_str, ",") |> Enum.map(&String.trim/1)
        substitute_and_call_function(func, args, request, policy, func_name)
    end
  end

  defp substitute_and_call_function(func, args, request, policy, func_name) do
    # Substitute r.* and p.* values
    substituted_args =
      Enum.map(args, fn arg ->
        substitute_parameter(String.trim(arg), request, policy)
      end)

    case {substituted_args, func_name} do
      {[arg1, arg2], "g"} ->
        # Call g function with 2 arguments, adding empty string as 3rd arg
        result = func.(arg1, arg2, "")
        {:ok, result}

      {[arg1, arg2], _} ->
        # Call regular function with 2 arguments (like ipMatch, keyMatch, etc.)
        result = func.(arg1, arg2)
        {:ok, result}

      {[arg1, arg2, arg3], _} ->
        # Call the function with 3 arguments (like g(r.sub, p.sub, r.dom))
        result = func.(arg1, arg2, arg3)
        {:ok, result}

      _ ->
        {:error, "Function calls with #{length(substituted_args)} arguments not supported yet"}
    end
  rescue
    e -> {:error, "Function call error: #{inspect(e)}"}
  end

  defp evaluate_equality(expr, request, policy) do
    [left, right] = String.split(expr, "==") |> Enum.map(&String.trim/1)

    left_val = substitute_parameter(left, request, policy)
    right_val = substitute_parameter(right, request, policy)

    {:ok, left_val == right_val}
  end

  defp evaluate_comparison(expr, request, policy, operator) do
    [left, right] = String.split(expr, operator) |> Enum.map(&String.trim/1)

    left_val = substitute_parameter(left, request, policy)
    right_val = substitute_parameter(right, request, policy)

    result = perform_comparison(left_val, right_val, operator)
    {:ok, result}
  end

  defp perform_comparison(left_val, right_val, operator) do
    case {parse_number(left_val), parse_number(right_val)} do
      {{:ok, left_num}, {:ok, right_num}} ->
        numeric_comparison(left_num, right_num, operator)

      _ ->
        string_comparison(left_val, right_val, operator)
    end
  end

  defp numeric_comparison(left_num, right_num, operator) do
    case operator do
      ">=" -> left_num >= right_num
      "<=" -> left_num <= right_num
      ">" -> left_num > right_num
      "<" -> left_num < right_num
    end
  end

  defp string_comparison(left_val, right_val, operator) do
    case operator do
      ">=" -> left_val >= right_val
      "<=" -> left_val <= right_val
      ">" -> left_val > right_val
      "<" -> left_val < right_val
    end
  end

  # Request parameter substitution - handle different model types based on request size
  defp substitute_parameter("r.sub", request, _policy), do: Enum.at(request, 0, "")

  defp substitute_parameter("r.obj", request, _policy) do
    case length(request) do
      # Standard: [sub, obj, act]
      3 ->
        Enum.at(request, 1, "")

      4 ->
        # Check if it's domain-based [sub, dom, obj, act] or time-based [sub, obj, act, time]
        # We can detect this by checking if the 4th element looks like a timestamp
        fourth = Enum.at(request, 3, "")

        if timestamp?(fourth) do
          # Time-based: [sub, obj, act, time]
          Enum.at(request, 1, "")
        else
          # Domain-based: [sub, dom, obj, act]
          Enum.at(request, 2, "")
        end

      # Default to standard
      _ ->
        Enum.at(request, 1, "")
    end
  end

  defp substitute_parameter("r.act", request, _policy) do
    case length(request) do
      # Standard: [sub, obj, act]
      3 ->
        Enum.at(request, 2, "")

      4 ->
        fourth = Enum.at(request, 3, "")

        if timestamp?(fourth) do
          # Time-based: [sub, obj, act, time]
          Enum.at(request, 2, "")
        else
          # Domain-based: [sub, dom, obj, act]
          Enum.at(request, 3, "")
        end

      # Default to standard
      _ ->
        Enum.at(request, 2, "")
    end
  end

  # Domain-based: [sub, dom, obj, act]
  defp substitute_parameter("r.dom", request, _policy), do: Enum.at(request, 1, "")
  # Time-based: [sub, obj, act, time]
  defp substitute_parameter("r.time", request, _policy), do: Enum.at(request, 3, "")

  # Policy parameter substitution - similar logic for policies
  defp substitute_parameter("p.sub", _request, policy), do: Enum.at(policy, 0, "")

  defp substitute_parameter("p.obj", _request, policy) do
    case length(policy) do
      # Standard: [sub, obj, act]
      3 -> Enum.at(policy, 1, "")
      # Domain-based: [sub, dom, obj, act]
      4 -> Enum.at(policy, 2, "")
      # Time-based: [sub, obj, act, start_time, end_time]
      5 -> Enum.at(policy, 1, "")
      # Default to standard
      _ -> Enum.at(policy, 1, "")
    end
  end

  defp substitute_parameter("p.act", _request, policy) do
    case length(policy) do
      # Standard: [sub, obj, act]
      3 -> Enum.at(policy, 2, "")
      # Domain-based: [sub, dom, obj, act]
      4 -> Enum.at(policy, 3, "")
      # Time-based: [sub, obj, act, start_time, end_time]
      5 -> Enum.at(policy, 2, "")
      # Default to standard
      _ -> Enum.at(policy, 2, "")
    end
  end

  # Domain-based: [sub, dom, obj, act]
  defp substitute_parameter("p.dom", _request, policy), do: Enum.at(policy, 1, "")
  # Time-based: [sub, obj, act, start_time, end_time]
  defp substitute_parameter("p.start_time", _request, policy), do: Enum.at(policy, 3, "")
  # Time-based: [sub, obj, act, start_time, end_time]
  defp substitute_parameter("p.end_time", _request, policy), do: Enum.at(policy, 4, "")
  defp substitute_parameter(literal, _request, _policy), do: literal

  # Helper to detect if a string looks like a timestamp (all digits)
  defp timestamp?(str) when is_binary(str) do
    String.match?(str, ~r/^\d+$/)
  end

  defp timestamp?(_), do: false

  defp parse_number(str) when is_binary(str) do
    case Integer.parse(str) do
      {num, ""} ->
        {:ok, num}

      _ ->
        case Float.parse(str) do
          {num, ""} -> {:ok, num}
          _ -> {:error, :not_a_number}
        end
    end
  end

  defp parse_number(num) when is_number(num), do: {:ok, num}
  defp parse_number(_), do: {:error, :not_a_number}

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
    # IP/CIDR matching following Go's net.ParseIP and net.ParseCIDR
    case :inet.parse_address(String.to_charlist(ip1)) do
      {:ok, ip1_addr} ->
        handle_ip_match(ip1_addr, ip2)

      _ ->
        false
    end
  end

  defp handle_ip_match(ip1_addr, ip2) do
    if String.contains?(ip2, "/") do
      handle_cidr_match(ip1_addr, ip2)
    else
      handle_direct_ip_match(ip1_addr, ip2)
    end
  end

  defp handle_cidr_match(ip1_addr, ip2) do
    case String.split(ip2, "/") do
      [network_str, prefix_str] ->
        parse_and_match_cidr(ip1_addr, network_str, prefix_str)

      _ ->
        false
    end
  end

  defp parse_and_match_cidr(ip1_addr, network_str, prefix_str) do
    case {:inet.parse_address(String.to_charlist(network_str)), Integer.parse(prefix_str)} do
      {{:ok, network_addr}, {prefix_len, ""}} ->
        ip_in_cidr_network(ip1_addr, network_addr, prefix_len)

      _ ->
        false
    end
  end

  defp handle_direct_ip_match(ip1_addr, ip2) do
    case :inet.parse_address(String.to_charlist(ip2)) do
      {:ok, ip2_addr} ->
        ip1_addr == ip2_addr

      _ ->
        # If ip2 is not a valid IP address (e.g., it's a role name like "alice"),
        # we return true assuming role-based access has already been validated
        # by the g() function in the matcher expression
        true
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

  # Proper CIDR network matching using Elixir's bitwise operations
  defp ip_in_cidr_network(ip, network, prefix_len) do
    case {ip, network} do
      {{a1, b1, c1, d1}, {a2, b2, c2, d2}} ->
        # IPv4 CIDR matching
        import Bitwise

        ip_int = a1 <<< 24 ||| b1 <<< 16 ||| c1 <<< 8 ||| d1
        network_int = a2 <<< 24 ||| b2 <<< 16 ||| c2 <<< 8 ||| d2

        # Create subnet mask: for /24, mask = 0xFFFFFF00
        mask = bnot((1 <<< (32 - prefix_len)) - 1)

        (ip_int &&& mask) == (network_int &&& mask)

      _ ->
        # For now, only support IPv4. IPv6 support can be added later if needed
        false
    end
  end

  defp ip_in_network?(ip, network, prefix_len) do
    # Legacy function for backward compatibility
    ip_in_cidr_network(ip, network, prefix_len)
  end

  defp ip_to_integer({a, b, c, d}) do
    import Bitwise
    a <<< 24 ||| b <<< 16 ||| c <<< 8 ||| d
  end

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

  # Extended RBAC API - Additional functions for permissions and roles

  @doc """
  Updates multiple grouping policy rules.
  """
  @spec update_grouping_policies(t(), [[String.t()]], [[String.t()]]) ::
          {:ok, t()} | {:error, term()}
  def update_grouping_policies(enforcer, old_rules, new_rules) do
    update_named_grouping_policies(enforcer, "g", old_rules, new_rules)
  end

  @doc """
  Updates multiple named grouping policy rules.
  """
  @spec update_named_grouping_policies(t(), String.t(), [[String.t()]], [[String.t()]]) ::
          {:ok, t()} | {:error, term()}
  def update_named_grouping_policies(_enforcer, _ptype, old_rules, new_rules)
      when length(old_rules) != length(new_rules) do
    {:error, :rule_count_mismatch}
  end

  def update_named_grouping_policies(enforcer, ptype, old_rules, new_rules) do
    Enum.zip(old_rules, new_rules)
    |> Enum.reduce_while({:ok, enforcer}, &update_rule_pair(&1, &2, ptype))
  end

  defp update_rule_pair({old_rule, new_rule}, {:ok, acc_enforcer}, ptype) do
    case update_named_grouping_policy(acc_enforcer, ptype, old_rule, new_rule) do
      {:ok, updated_enforcer} -> {:cont, {:ok, updated_enforcer}}
      error -> {:halt, error}
    end
  end

  @doc """
  Gets direct permissions for a user (does not include permissions through roles).
  Returns permissions in [obj, act] format.
  """
  @spec get_permissions_for_user(t(), String.t(), String.t()) :: [[String.t()]]
  def get_permissions_for_user(%__MODULE__{policies: policies} = _enforcer, user, domain \\ "") do
    get_permissions_for_user_direct(policies, user, domain)
    |> Enum.map(fn
      [_user, obj, act] -> [obj, act]
      [_user, obj, act, _domain] -> [obj, act]
      other -> other
    end)
  end

  @doc """
  Gets implicit permissions for a user (includes permissions through roles).
  """
  @spec get_implicit_permissions_for_user(t(), String.t(), String.t()) :: [[String.t()]]
  def get_implicit_permissions_for_user(
        %__MODULE__{role_manager: role_manager, policies: policies} = _enforcer,
        user,
        domain \\ ""
      ) do
    # Get direct permissions
    direct_permissions = get_permissions_for_user_direct(policies, user, domain)

    # Get permissions through roles
    role_permissions =
      case CasbinEx2.RoleManager.get_roles(role_manager, user, domain) do
        roles when is_list(roles) ->
          Enum.flat_map(roles, fn role ->
            get_permissions_for_user_direct(policies, role, domain)
          end)

        _ ->
          []
      end

    (direct_permissions ++ role_permissions) |> Enum.uniq()
  end

  @doc """
  Gets implicit roles for a user (includes inherited roles).
  """
  @spec get_implicit_roles_for_user(t(), String.t(), String.t()) :: [String.t()]
  def get_implicit_roles_for_user(
        %__MODULE__{role_manager: role_manager} = _enforcer,
        user,
        domain \\ ""
      ) do
    case CasbinEx2.RoleManager.get_roles(role_manager, user, domain) do
      roles when is_list(roles) -> roles
      _ -> []
    end
  end

  @doc """
  Checks if a user has a specific permission.
  """
  @spec has_permission_for_user(t(), String.t(), [String.t()]) :: boolean()
  def has_permission_for_user(enforcer, user, permission) do
    permissions = get_implicit_permissions_for_user(enforcer, user)
    # Extract object and action from policy format [user, obj, act] -> [obj, act]
    extracted_permissions =
      Enum.map(permissions, fn
        [_user, obj, act] -> [obj, act]
        [_user, obj, act, _domain] -> [obj, act]
        other -> other
      end)

    permission in extracted_permissions
  end

  @doc """
  Deletes a user (removes all policies and grouping policies for the user).
  """
  @spec delete_user(t(), String.t()) :: {:ok, t()} | {:error, term()}
  def delete_user(
        %__MODULE__{
          policies: policies,
          grouping_policies: grouping_policies,
          role_manager: role_manager
        } = enforcer,
        user
      ) do
    # First, get all roles for the user and remove them from role manager
    user_roles =
      grouping_policies
      |> Map.get("g", [])
      |> Enum.filter(fn
        [^user, _role] -> true
        [^user, _role, _domain] -> true
        _ -> false
      end)

    # Remove each role link from role manager
    updated_role_manager =
      Enum.reduce(user_roles, role_manager, fn
        [^user, role], acc -> CasbinEx2.RoleManager.delete_link(acc, user, role, "")
        [^user, role, domain], acc -> CasbinEx2.RoleManager.delete_link(acc, user, role, domain)
      end)

    # Remove user from all policies
    new_policies = remove_user_from_policies(policies, user)

    # Remove user from all grouping policies (roles)
    new_grouping_policies = remove_user_from_grouping_policies(grouping_policies, user)

    updated_enforcer = %{
      enforcer
      | policies: new_policies,
        grouping_policies: new_grouping_policies,
        role_manager: updated_role_manager
    }

    if enforcer.auto_save do
      save_policy(updated_enforcer)
    else
      {:ok, updated_enforcer}
    end
  end

  @doc """
  Deletes a role (removes all grouping policies for the role).
  """
  @spec delete_role(t(), String.t()) :: {:ok, t()} | {:error, term()}
  def delete_role(
        %__MODULE__{grouping_policies: grouping_policies, role_manager: role_manager} = enforcer,
        role
      ) do
    # First, get all user-role relationships for this role and remove them from role manager
    role_relationships =
      grouping_policies
      |> Map.get("g", [])
      |> Enum.filter(fn
        [_user, ^role] -> true
        [_user, ^role, _domain] -> true
        _ -> false
      end)

    # Remove each role link from role manager
    updated_role_manager =
      Enum.reduce(role_relationships, role_manager, fn
        [user, ^role], acc -> CasbinEx2.RoleManager.delete_link(acc, user, role, "")
        [user, ^role, domain], acc -> CasbinEx2.RoleManager.delete_link(acc, user, role, domain)
      end)

    # Remove role from all grouping policies
    new_grouping_policies = remove_role_from_grouping_policies(grouping_policies, role)

    updated_enforcer = %{
      enforcer
      | grouping_policies: new_grouping_policies,
        role_manager: updated_role_manager
    }

    if enforcer.auto_save do
      save_policy(updated_enforcer)
    else
      {:ok, updated_enforcer}
    end
  end

  @doc """
  Deletes a permission (removes the permission from all policies).
  """
  @spec delete_permission(t(), [String.t()]) :: {:ok, t()} | {:error, term()}
  def delete_permission(%__MODULE__{policies: policies} = enforcer, permission) do
    # Remove permission from all policies
    new_policies = remove_permission_from_policies(policies, permission)

    updated_enforcer = %{enforcer | policies: new_policies}

    if enforcer.auto_save do
      save_policy(updated_enforcer)
    else
      {:ok, updated_enforcer}
    end
  end

  @doc """
  Gets all users who have a specific permission.
  """
  @spec get_users_for_permission(t(), [String.t()]) :: [String.t()]
  def get_users_for_permission(%__MODULE__{policies: policies} = _enforcer, permission) do
    policies
    |> Map.get("p", [])
    |> Enum.filter(fn policy ->
      case policy do
        [_user | perm] -> perm == permission
        _ -> false
      end
    end)
    |> Enum.map(&List.first/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  @doc """
  Adds multiple roles for a user.
  """
  @spec add_roles_for_user(t(), String.t(), [String.t()], String.t()) ::
          {:ok, t()} | {:error, term()}
  def add_roles_for_user(enforcer, user, roles, domain \\ "") do
    rules =
      Enum.map(roles, fn role ->
        if domain == "", do: [user, role], else: [user, role, domain]
      end)

    add_named_grouping_policies(enforcer, "g", rules)
  end

  @doc """
  Adds multiple permissions for a user.
  """
  @spec add_permissions_for_user(t(), String.t(), [[String.t()]]) :: {:ok, t()} | {:error, term()}
  def add_permissions_for_user(enforcer, user, permissions) do
    rules =
      Enum.map(permissions, fn permission ->
        [user | permission]
      end)

    add_named_policies(enforcer, "p", rules)
  end

  @doc """
  Deletes specific permissions for a user.
  """
  @spec delete_permissions_for_user(t(), String.t(), [[String.t()]]) ::
          {:ok, t()} | {:error, term()}
  def delete_permissions_for_user(%__MODULE__{policies: policies} = enforcer, user, permissions) do
    # Remove specific permissions for the user
    new_policies =
      policies
      |> Enum.map(&filter_user_specific_permissions(&1, user, permissions))
      |> Enum.into(%{})

    updated_enforcer = %{enforcer | policies: new_policies}

    if enforcer.auto_save do
      save_policy(updated_enforcer)
    else
      {:ok, updated_enforcer}
    end
  end

  @doc """
  Deletes all permissions for a user.
  """
  @spec delete_permissions_for_user(t(), String.t()) :: {:ok, t()} | {:error, term()}
  def delete_permissions_for_user(%__MODULE__{policies: policies} = enforcer, user) do
    # Remove all policies where the user is the subject
    new_policies = remove_user_from_policies(policies, user)

    updated_enforcer = %{enforcer | policies: new_policies}

    if enforcer.auto_save do
      save_policy(updated_enforcer)
    else
      {:ok, updated_enforcer}
    end
  end

  # Helper functions for RBAC operations

  defp get_permissions_for_user_direct(policies, user, domain) do
    policies
    |> Map.get("p", [])
    |> Enum.filter(fn policy ->
      case policy do
        [^user, _obj, _act, ^domain] -> true
        [^user, _obj, _act] when domain == "" -> true
        _ -> false
      end
    end)
  end

  defp remove_user_from_policies(policies, user) do
    policies
    |> Enum.map(&filter_user_policy_rules(&1, user))
    |> Enum.into(%{})
  end

  defp filter_user_policy_rules({ptype, rules}, user) do
    filtered_rules = Enum.reject(rules, &starts_with_user?(&1, user))
    {ptype, filtered_rules}
  end

  defp starts_with_user?([user | _], user), do: true
  defp starts_with_user?(_, _), do: false

  defp filter_user_specific_permissions({ptype, rules}, user, permissions) do
    filtered_rules = Enum.reject(rules, &matches_user_permission?(&1, user, permissions))
    {ptype, filtered_rules}
  end

  defp matches_user_permission?([user | perm], user, permissions), do: perm in permissions
  defp matches_user_permission?(_, _, _), do: false

  defp remove_user_from_grouping_policies(grouping_policies, user) do
    grouping_policies
    |> Enum.map(&filter_user_grouping_rules(&1, user))
    |> Enum.into(%{})
  end

  defp filter_user_grouping_rules({ptype, rules}, user) do
    filtered_rules = Enum.reject(rules, &matches_user?(&1, user))
    {ptype, filtered_rules}
  end

  defp matches_user?([user | _], user), do: true
  defp matches_user?(_, _), do: false

  defp remove_role_from_grouping_policies(grouping_policies, role) do
    grouping_policies
    |> Enum.map(&filter_role_rules(&1, role))
    |> Enum.into(%{})
  end

  defp filter_role_rules({ptype, rules}, role) do
    filtered_rules = Enum.reject(rules, &matches_role?(&1, role))
    {ptype, filtered_rules}
  end

  defp matches_role?([_user, role], role), do: true
  defp matches_role?([_user, role, _domain], role), do: true
  defp matches_role?(_, _), do: false

  defp remove_permission_from_policies(policies, permission) do
    policies
    |> Enum.map(&filter_permission_rules(&1, permission))
    |> Enum.into(%{})
  end

  defp filter_permission_rules({ptype, rules}, permission) do
    filtered_rules = Enum.reject(rules, &matches_permission?(&1, permission))
    {ptype, filtered_rules}
  end

  defp matches_permission?([_user | perm], permission), do: perm == permission
  defp matches_permission?(_, _), do: false

  defp maybe_save_policy(enforcer, true) do
    case save_policy(enforcer) do
      {:ok, saved_enforcer} ->
        CasbinLogger.log_adapter_operation(:save_policy, :success, 1)
        {:ok, saved_enforcer}

      {:error, reason} = error ->
        CasbinLogger.log_error(:save_error, "Failed to save policy: #{inspect(reason)}")
        error
    end
  end

  defp maybe_save_policy(enforcer, false), do: {:ok, enforcer}

  # Role Manager Configuration Functions

  @doc """
  Adds a custom matching function to a named role manager.

  ## Parameters
  - `enforcer` - The enforcer struct
  - `ptype` - Policy type (e.g., "g", "g2")
  - `name` - Name of the matching function
  - `fn` - The matching function

  ## Returns
  Boolean indicating success

  ## Examples

      enforcer = add_named_matching_func(enforcer, "g", "custom_match", fn name1, name2 ->
        String.downcase(name1) == String.downcase(name2)
      end)
  """
  @spec add_named_matching_func(t(), String.t(), String.t(), function()) :: t()
  def add_named_matching_func(enforcer, ptype, name, func) do
    case Map.get(enforcer.named_role_managers, ptype) do
      nil ->
        # Role manager not found for this ptype
        enforcer

      role_manager ->
        # Add matching function to the role manager
        # Note: This requires RoleManager to support add_matching_func/3
        updated_rm = RoleManager.add_matching_func(role_manager, name, func)
        named_rms = Map.put(enforcer.named_role_managers, ptype, updated_rm)
        %{enforcer | named_role_managers: named_rms}
    end
  end

  @doc """
  Adds a domain-specific matching function to a named role manager.

  ## Parameters
  - `enforcer` - The enforcer struct
  - `ptype` - Policy type (e.g., "g", "g2")
  - `name` - Name of the matching function
  - `fn` - The domain matching function

  ## Returns
  Updated enforcer

  ## Examples

      enforcer = add_named_domain_matching_func(enforcer, "g", "domain_match", fn name1, name2, domain ->
        String.downcase(name1) == String.downcase(name2) && domain == "admin"
      end)
  """
  @spec add_named_domain_matching_func(t(), String.t(), String.t(), function()) :: t()
  def add_named_domain_matching_func(enforcer, ptype, name, func) do
    case Map.get(enforcer.named_role_managers, ptype) do
      nil ->
        enforcer

      role_manager ->
        # Add domain matching function to the role manager
        updated_rm = RoleManager.add_domain_matching_func(role_manager, name, func)
        named_rms = Map.put(enforcer.named_role_managers, ptype, updated_rm)
        %{enforcer | named_role_managers: named_rms}
    end
  end

  @doc """
  Adds a conditional link function for a specific user-role relationship.
  The link is only valid when the condition function returns true.

  ## Parameters
  - `enforcer` - The enforcer struct
  - `ptype` - Policy type (e.g., "g")
  - `user` - User name
  - `role` - Role name
  - `fn` - Condition function that validates the link

  ## Returns
  Updated enforcer

  ## Examples

      enforcer = add_named_link_condition_func(enforcer, "g", "alice", "admin", fn params ->
        params["time"] < "18:00"
      end)
  """
  @spec add_named_link_condition_func(t(), String.t(), String.t(), String.t(), function()) :: t()
  def add_named_link_condition_func(enforcer, ptype, _user, _role, _func) do
    # This requires conditional role manager support
    # For now, we'll store it in metadata or return enforcer unchanged
    # When ConditionalRoleManager is implemented, this will delegate to it
    case Map.get(enforcer.named_role_managers, ptype) do
      nil ->
        enforcer

      _role_manager ->
        # TODO: When ConditionalRoleManager is implemented, use:
        # updated_rm = ConditionalRoleManager.add_link_condition_func(role_manager, user, role, func)
        # For now, just return enforcer
        enforcer
    end
  end

  @doc """
  Adds a conditional link function for a specific user-role-domain relationship.
  The link is only valid when the condition function returns true.

  ## Parameters
  - `enforcer` - The enforcer struct
  - `ptype` - Policy type (e.g., "g")
  - `user` - User name
  - `role` - Role name
  - `domain` - Domain name
  - `fn` - Condition function that validates the link

  ## Returns
  Updated enforcer

  ## Examples

      enforcer = add_named_domain_link_condition_func(enforcer, "g", "alice", "admin", "domain1", fn params ->
        params["department"] == "IT"
      end)
  """
  @spec add_named_domain_link_condition_func(
          t(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          function()
        ) :: t()
  def add_named_domain_link_condition_func(enforcer, ptype, _user, _role, _domain, _func) do
    # This requires conditional role manager support
    case Map.get(enforcer.named_role_managers, ptype) do
      nil ->
        enforcer

      _role_manager ->
        # TODO: When ConditionalRoleManager is implemented, use:
        # updated_rm = ConditionalRoleManager.add_domain_link_condition_func(role_manager, user, role, domain, func)
        enforcer
    end
  end

  @doc """
  Sets parameters for a conditional link function.

  ## Parameters
  - `enforcer` - The enforcer struct
  - `ptype` - Policy type
  - `user` - User name
  - `role` - Role name
  - `params` - List of parameter values

  ## Returns
  Updated enforcer

  ## Examples

      enforcer = set_named_link_condition_func_params(enforcer, "g", "alice", "admin", ["time=09:00", "location=office"])
  """
  @spec set_named_link_condition_func_params(
          t(),
          String.t(),
          String.t(),
          String.t(),
          [String.t()]
        ) :: t()
  def set_named_link_condition_func_params(enforcer, ptype, _user, _role, _params) do
    # This requires conditional role manager support
    case Map.get(enforcer.named_role_managers, ptype) do
      nil ->
        enforcer

      _role_manager ->
        # TODO: When ConditionalRoleManager is implemented, use:
        # updated_rm = ConditionalRoleManager.set_link_condition_func_params(role_manager, user, role, params)
        enforcer
    end
  end

  @doc """
  Sets parameters for a conditional domain link function.

  ## Parameters
  - `enforcer` - The enforcer struct
  - `ptype` - Policy type
  - `user` - User name
  - `role` - Role name
  - `domain` - Domain name
  - `params` - List of parameter values

  ## Returns
  Updated enforcer

  ## Examples

      enforcer = set_named_domain_link_condition_func_params(enforcer, "g", "alice", "admin", "domain1", ["dept=IT"])
  """
  @spec set_named_domain_link_condition_func_params(
          t(),
          String.t(),
          String.t(),
          String.t(),
          String.t(),
          [String.t()]
        ) :: t()
  def set_named_domain_link_condition_func_params(enforcer, ptype, _user, _role, _domain, _params) do
    # This requires conditional role manager support
    case Map.get(enforcer.named_role_managers, ptype) do
      nil ->
        enforcer

      _role_manager ->
        # TODO: When ConditionalRoleManager is implemented, use:
        # updated_rm = ConditionalRoleManager.set_domain_link_condition_func_params(role_manager, user, role, domain, params)
        enforcer
    end
  end

  # Internal API Functions

  @doc """
  Checks if policies should be persisted to the adapter.

  Returns true if both an adapter is set and auto_save is enabled.

  ## Examples

      should_persist(enforcer)
      # Returns: true (if adapter exists and auto_save is true)
  """
  @spec should_persist(t()) :: boolean()
  def should_persist(%__MODULE__{adapter: adapter, auto_save: auto_save}) do
    adapter != nil and auto_save
  end

  @doc """
  Checks if policy changes should trigger watcher notifications.

  Returns true if both a watcher is set and auto_notify_watcher is enabled.

  ## Examples

      should_notify(enforcer)
      # Returns: true (if watcher exists and auto_notify_watcher is true)
  """
  @spec should_notify(t()) :: boolean()
  def should_notify(%__MODULE__{watcher: watcher, auto_notify_watcher: auto_notify_watcher}) do
    watcher != nil and auto_notify_watcher
  end

  @doc """
  Gets the field index for a policy type field.

  ## Parameters
  - `enforcer` - The enforcer struct
  - `ptype` - Policy type (e.g., "p", "p2")
  - `field` - Field name (e.g., "sub", "obj", "act")

  ## Returns
  - `{:ok, index}` on success
  - `{:error, reason}` if field not found

  ## Examples

      {:ok, index} = get_field_index(enforcer, "p", "sub")
      # Returns: {:ok, 0}
  """
  @spec get_field_index(t(), String.t(), String.t()) :: {:ok, integer()} | {:error, term()}
  def get_field_index(%__MODULE__{model: model}, ptype, field) do
    case Model.get_field_index(model, ptype, field) do
      {:ok, index} -> {:ok, index}
      error -> error
    end
  end

  @doc """
  Sets the field index for a policy type field.

  ## Parameters
  - `enforcer` - The enforcer struct
  - `ptype` - Policy type (e.g., "p", "p2")
  - `field` - Field name (e.g., "sub", "obj", "act")
  - `index` - The index to set

  ## Returns
  Updated enforcer

  ## Examples

      enforcer = set_field_index(enforcer, "p", "custom_field", 5)
  """
  @spec set_field_index(t(), String.t(), String.t(), integer()) :: t()
  def set_field_index(%__MODULE__{model: model} = enforcer, ptype, field, index) do
    updated_model = Model.set_field_index(model, ptype, field, index)
    %{enforcer | model: updated_model}
  end

  @doc """
  Updates a policy rule without triggering watcher or dispatcher notifications.

  This is an internal function used for distributed scenarios where the
  update originated from another enforcer instance.

  ## Parameters
  - `enforcer` - The enforcer struct
  - `sec` - Section type ("p" or "g")
  - `ptype` - Policy type
  - `old_rule` - The existing rule to replace
  - `new_rule` - The new rule

  ## Returns
  - `{:ok, enforcer, true}` if rule was updated
  - `{:ok, enforcer, false}` if rule was not found
  - `{:error, reason}` on failure
  """
  @spec update_policy_without_notify(t(), String.t(), String.t(), [String.t()], [String.t()]) ::
          {:ok, t(), boolean()} | {:error, term()}
  def update_policy_without_notify(enforcer, sec, ptype, old_rule, new_rule) do
    # Note: Dispatcher notification intentionally skipped for "without_notify" functions
    # These are used when the change originated from another enforcer instance

    case sec do
      "p" ->
        case Management.update_named_policy(enforcer, ptype, old_rule, new_rule) do
          {:ok, updated_enforcer} -> {:ok, updated_enforcer, true}
          {:error, reason} -> {:error, reason}
        end

      "g" ->
        case Management.update_named_grouping_policy(enforcer, ptype, old_rule, new_rule) do
          {:ok, updated_enforcer} -> {:ok, updated_enforcer, true}
          {:error, reason} -> {:error, reason}
        end

      _ ->
        {:error, "invalid section type, must be 'p' or 'g'"}
    end
  end

  @doc """
  Updates multiple policy rules without triggering watcher or dispatcher notifications.

  ## Parameters
  - `enforcer` - The enforcer struct
  - `sec` - Section type ("p" or "g")
  - `ptype` - Policy type
  - `old_rules` - List of existing rules to replace
  - `new_rules` - List of new rules (must match length of old_rules)

  ## Returns
  - `{:ok, enforcer, true}` if rules were updated
  - `{:ok, enforcer, false}` if no rules were updated
  - `{:error, reason}` on failure
  """
  @spec update_policies_without_notify(
          t(),
          String.t(),
          String.t(),
          [[String.t()]],
          [[String.t()]]
        ) :: {:ok, t(), boolean()} | {:error, term()}
  def update_policies_without_notify(enforcer, sec, ptype, old_rules, new_rules) do
    if length(old_rules) != length(new_rules) do
      {:error,
       "the length of old_rules (#{length(old_rules)}) must equal the length of new_rules (#{length(new_rules)})"}
    else
      case sec do
        "p" ->
          case Management.update_named_policies(enforcer, ptype, old_rules, new_rules) do
            {:ok, updated_enforcer} -> {:ok, updated_enforcer, true}
            {:error, reason} -> {:error, reason}
          end

        "g" ->
          case Management.update_named_grouping_policies(enforcer, ptype, old_rules, new_rules) do
            {:ok, updated_enforcer} -> {:ok, updated_enforcer, true}
            {:error, reason} -> {:error, reason}
          end

        _ ->
          {:error, "invalid section type, must be 'p' or 'g'"}
      end
    end
  end

  @doc """
  Removes filtered policies without triggering watcher or dispatcher notifications.

  ## Parameters
  - `enforcer` - The enforcer struct
  - `sec` - Section type ("p" or "g")
  - `ptype` - Policy type
  - `field_index` - Index of the field to match (0-based)
  - `field_values` - Values to match for filtering

  ## Returns
  - `{:ok, enforcer, true}` if policies were removed
  - `{:ok, enforcer, false}` if no policies matched
  - `{:error, reason}` on failure
  """
  @spec remove_filtered_policy_without_notify(
          t(),
          String.t(),
          String.t(),
          integer(),
          [String.t()]
        ) :: {:ok, t()} | {:error, term()}
  def remove_filtered_policy_without_notify(enforcer, sec, ptype, field_index, field_values) do
    if length(field_values) == 0 do
      {:error, "field_values cannot be empty"}
    else
      case sec do
        "p" ->
          Management.remove_filtered_named_policy(enforcer, ptype, field_index, field_values)

        "g" ->
          Management.remove_filtered_named_grouping_policy(
            enforcer,
            ptype,
            field_index,
            field_values
          )

        _ ->
          {:error, "invalid section type, must be 'p' or 'g'"}
      end
    end
  end

  @doc """
  Updates filtered policies without triggering watcher or dispatcher notifications.

  Removes policies matching the filter and adds new policies.

  ## Parameters
  - `enforcer` - The enforcer struct
  - `sec` - Section type ("p" or "g")
  - `ptype` - Policy type
  - `new_rules` - New rules to add after removing filtered policies
  - `field_index` - Index of the field to match (0-based)
  - `field_values` - Values to match for filtering

  ## Returns
  - `{:ok, enforcer, old_rules}` with the removed rules
  - `{:error, reason}` on failure
  """
  @spec update_filtered_policies_without_notify(
          t(),
          String.t(),
          String.t(),
          [[String.t()]],
          integer(),
          [String.t()]
        ) :: {:ok, t(), [[String.t()]]} | {:error, term()}
  def update_filtered_policies_without_notify(
        enforcer,
        sec,
        ptype,
        new_rules,
        field_index,
        field_values
      ) do
    # Get the old rules that will be removed
    old_rules =
      case sec do
        "p" ->
          Management.get_filtered_named_policy(enforcer, ptype, field_index, field_values)

        "g" ->
          Management.get_filtered_named_grouping_policy(
            enforcer,
            ptype,
            field_index,
            field_values
          )

        _ ->
          []
      end

    # Remove filtered policies
    case remove_filtered_policy_without_notify(enforcer, sec, ptype, field_index, field_values) do
      {:ok, updated_enforcer, _} ->
        # Add new policies
        case sec do
          "p" ->
            case Management.add_named_policies(updated_enforcer, ptype, new_rules) do
              {:ok, final_enforcer} -> {:ok, final_enforcer, old_rules}
              {:error, reason} -> {:error, reason}
            end

          "g" ->
            case Management.add_named_grouping_policies(updated_enforcer, ptype, new_rules) do
              {:ok, final_enforcer} -> {:ok, final_enforcer, old_rules}
              {:error, reason} -> {:error, reason}
            end

          _ ->
            {:error, "invalid section type, must be 'p' or 'g'"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
