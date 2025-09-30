defmodule CasbinEx2.SyncedEnforcer do
  @moduledoc """
  Synchronized enforcer that wraps the basic enforcer with read-write locks
  for thread-safe access in concurrent environments.
  """

  use GenServer

  require Logger

  alias CasbinEx2.Adapter.FileAdapter
  alias CasbinEx2.Enforcer

  defstruct [:enforcer, :lock]

  @type t :: %__MODULE__{
          enforcer: Enforcer.t(),
          lock: :gen_server.server_ref()
        }

  #
  # Client API
  #

  @doc """
  Starts a synced enforcer server.
  """
  def start_link(name, model_path, opts \\ []) do
    GenServer.start_link(
      __MODULE__,
      {name, model_path, opts},
      name: via_tuple(name)
    )
  end

  @doc """
  Performs synchronized authorization enforcement.
  """
  def enforce(name, request) do
    GenServer.call(via_tuple(name), {:enforce, request})
  end

  @doc """
  Performs batch enforcement with read lock.
  """
  def batch_enforce(name, requests) do
    GenServer.call(via_tuple(name), {:batch_enforce, requests})
  end

  # Write operations (require exclusive access)
  def add_policy(name, params) do
    GenServer.call(via_tuple(name), {:add_policy, params})
  end

  def add_policies(name, rules) do
    GenServer.call(via_tuple(name), {:add_policies, rules})
  end

  def remove_policy(name, params) do
    GenServer.call(via_tuple(name), {:remove_policy, params})
  end

  def remove_policies(name, rules) do
    GenServer.call(via_tuple(name), {:remove_policies, rules})
  end

  def remove_filtered_policy(name, field_index, field_values) do
    GenServer.call(via_tuple(name), {:remove_filtered_policy, field_index, field_values})
  end

  def add_grouping_policy(name, params) do
    GenServer.call(via_tuple(name), {:add_grouping_policy, params})
  end

  def remove_grouping_policy(name, params) do
    GenServer.call(via_tuple(name), {:remove_grouping_policy, params})
  end

  def add_role_for_user(name, user, role, domain \\ "") do
    GenServer.call(via_tuple(name), {:add_role_for_user, user, role, domain})
  end

  def delete_role_for_user(name, user, role, domain \\ "") do
    GenServer.call(via_tuple(name), {:delete_role_for_user, user, role, domain})
  end

  def delete_roles_for_user(name, user, domain \\ "") do
    GenServer.call(via_tuple(name), {:delete_roles_for_user, user, domain})
  end

  def load_policy(name) do
    GenServer.call(via_tuple(name), {:load_policy})
  end

  def save_policy(name) do
    GenServer.call(via_tuple(name), {:save_policy})
  end

  def build_role_links(name) do
    GenServer.call(via_tuple(name), {:build_role_links})
  end

  # Read operations (can be concurrent)
  def get_policy(name) do
    GenServer.call(via_tuple(name), {:get_policy})
  end

  def get_filtered_policy(name, field_index, field_values) do
    GenServer.call(via_tuple(name), {:get_filtered_policy, field_index, field_values})
  end

  def has_policy(name, params) do
    GenServer.call(via_tuple(name), {:has_policy, params})
  end

  def get_grouping_policy(name) do
    GenServer.call(via_tuple(name), {:get_grouping_policy})
  end

  def get_roles_for_user(name, user, domain \\ "") do
    GenServer.call(via_tuple(name), {:get_roles_for_user, user, domain})
  end

  def get_users_for_role(name, role, domain \\ "") do
    GenServer.call(via_tuple(name), {:get_users_for_role, role, domain})
  end

  def has_role_for_user(name, user, role, domain \\ "") do
    GenServer.call(via_tuple(name), {:has_role_for_user, user, role, domain})
  end

  def get_permissions_for_user(name, user, domain \\ "") do
    GenServer.call(via_tuple(name), {:get_permissions_for_user, user, domain})
  end

  #
  # Server Callbacks
  #

  @impl GenServer
  def init({name, model_path, opts}) do
    case create_synced_enforcer(name, model_path, opts) do
      {:ok, enforcer} ->
        # Create a simple lock using an Agent
        {:ok, lock_pid} = Agent.start_link(fn -> :unlocked end)

        state = %__MODULE__{
          enforcer: enforcer,
          lock: lock_pid
        }

        Logger.info("Started synced enforcer server '#{name}'")
        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to start synced enforcer server '#{name}': #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl GenServer
  def terminate(_reason, state) do
    # Clean up the lock agent
    if Process.alive?(state.lock) do
      Agent.stop(state.lock)
    end

    :ok
  end

  # Read operations
  @impl GenServer
  def handle_call(call, from, state)
      when elem(call, 0) in [
             :enforce,
             :batch_enforce,
             :get_policy,
             :get_filtered_policy,
             :has_policy,
             :get_grouping_policy,
             :get_roles_for_user,
             :get_users_for_role,
             :has_role_for_user,
             :get_permissions_for_user
           ] do
    with_read_lock(state, fn ->
      handle_read_operation(call, from, state)
    end)
  end

  # Write operations
  def handle_call(call, from, state) do
    with_write_lock(state, fn ->
      handle_write_operation(call, from, state)
    end)
  end

  #
  # Helper Functions
  #

  defp via_tuple(name) do
    {:via, Registry, {CasbinEx2.EnforcerRegistry, :"synced_#{name}"}}
  end

  defp create_synced_enforcer(name, model_path, opts) do
    # Create the underlying enforcer
    adapter = Keyword.get(opts, :adapter, FileAdapter.new(""))

    case Enforcer.init_with_file(model_path, adapter) do
      {:ok, enforcer} ->
        # Store in ETS with a synced prefix
        :ets.insert(:casbin_enforcers_table, {:"synced_#{name}", enforcer})
        {:ok, enforcer}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp with_read_lock(state, fun) do
    # Simple read lock implementation
    # In a production system, you might want a more sophisticated read-write lock
    Agent.get(state.lock, fn _lock_state ->
      fun.()
    end)
  end

  defp with_write_lock(state, fun) do
    # Simple write lock implementation
    Agent.get_and_update(state.lock, fn _lock_state ->
      result = fun.()
      {result, :unlocked}
    end)
  end

  defp handle_read_operation(call, _from, state) do
    case categorize_read_operation(call) do
      {:enforce_type, operation_data} -> handle_enforce_type_operation(state, operation_data)
      {:policy_type, operation_data} -> handle_policy_type_operation(state, operation_data)
      {:role_type, operation_data} -> handle_role_type_operation(state, operation_data)
      :unknown -> {:reply, {:error, :unknown_read_operation}, state}
    end
  end

  defp categorize_read_operation(call) do
    case call do
      {:enforce, request} ->
        {:enforce_type, {:enforce, request}}

      {:batch_enforce, requests} ->
        {:enforce_type, {:batch_enforce, requests}}

      {:get_policy} ->
        {:policy_type, {:get_policy}}

      {:get_filtered_policy, field_index, field_values} ->
        {:policy_type, {:get_filtered_policy, field_index, field_values}}

      {:has_policy, params} ->
        {:policy_type, {:has_policy, params}}

      {:get_grouping_policy} ->
        {:policy_type, {:get_grouping_policy}}

      {:get_roles_for_user, user, domain} ->
        {:role_type, {:get_roles_for_user, user, domain}}

      {:get_users_for_role, role, domain} ->
        {:role_type, {:get_users_for_role, role, domain}}

      {:has_role_for_user, user, role, domain} ->
        {:role_type, {:has_role_for_user, user, role, domain}}

      {:get_permissions_for_user, user, domain} ->
        {:role_type, {:get_permissions_for_user, user, domain}}

      _ ->
        :unknown
    end
  end

  defp handle_enforce_type_operation(state, operation_data) do
    case operation_data do
      {:enforce, request} -> handle_enforce_operation(state, request)
      {:batch_enforce, requests} -> handle_batch_enforce_operation(state, requests)
    end
  end

  defp handle_policy_type_operation(state, operation_data) do
    case operation_data do
      {:get_policy} ->
        handle_simple_read_operation(state, &get_policy_data/1)

      {:get_filtered_policy, field_index, field_values} ->
        handle_filtered_read_operation(state, field_index, field_values)

      {:has_policy, params} ->
        handle_policy_check_operation(state, params)

      {:get_grouping_policy} ->
        handle_simple_read_operation(state, &get_grouping_policy_data/1)
    end
  end

  defp handle_role_type_operation(state, operation_data) do
    case operation_data do
      {:get_roles_for_user, user, domain} ->
        handle_role_operation(state, :get_roles, user, domain)

      {:get_users_for_role, role, domain} ->
        handle_role_operation(state, :get_users, role, domain)

      {:has_role_for_user, user, role, domain} ->
        handle_role_check_operation(state, user, role, domain)

      {:get_permissions_for_user, user, domain} ->
        handle_permissions_operation(state, user, domain)
    end
  end

  defp handle_enforce_operation(state, request) do
    result = Enforcer.enforce(state.enforcer, request)
    {:reply, result, state}
  end

  defp handle_batch_enforce_operation(state, requests) do
    results = Enum.map(requests, &Enforcer.enforce(state.enforcer, &1))
    {:reply, results, state}
  end

  defp handle_simple_read_operation(state, data_func) do
    data = data_func.(state.enforcer)
    {:reply, data, state}
  end

  defp handle_filtered_read_operation(state, field_index, field_values) do
    policies = get_filtered_policy_impl(state.enforcer, "p", field_index, field_values)
    {:reply, policies, state}
  end

  defp handle_policy_check_operation(state, params) do
    result = has_policy_impl(state.enforcer, "p", params)
    {:reply, result, state}
  end

  defp handle_role_operation(state, operation, user_or_role, domain) do
    result =
      case operation do
        :get_roles ->
          CasbinEx2.RoleManager.get_roles(state.enforcer.role_manager, user_or_role, domain)

        :get_users ->
          CasbinEx2.RoleManager.get_users(state.enforcer.role_manager, user_or_role, domain)
      end

    {:reply, result, state}
  end

  defp handle_role_check_operation(state, user, role, domain) do
    result = CasbinEx2.RoleManager.has_link(state.enforcer.role_manager, user, role, domain)
    {:reply, result, state}
  end

  defp handle_permissions_operation(state, user, domain) do
    permissions = get_permissions_for_user_impl(state.enforcer, user, domain)
    {:reply, permissions, state}
  end

  defp get_policy_data(enforcer), do: Map.get(enforcer.policies, "p", [])
  defp get_grouping_policy_data(enforcer), do: Map.get(enforcer.grouping_policies, "g", [])

  defp handle_write_operation(call, _from, state) do
    case call do
      {:add_policy, params} ->
        handle_policy_operation(state, :add_policy, params)

      {:add_policies, rules} ->
        handle_policy_batch_operation(state, :add_policies, rules)

      {:remove_policy, params} ->
        handle_policy_operation(state, :remove_policy, params)

      {:add_grouping_policy, params} ->
        handle_grouping_policy_operation(state, :add_grouping_policy, params)

      {:remove_grouping_policy, params} ->
        handle_grouping_policy_operation(state, :remove_grouping_policy, params)

      {:load_policy} ->
        handle_enforcer_operation(state, &Enforcer.load_policy/1, :ok)

      {:save_policy} ->
        handle_enforcer_operation(state, &Enforcer.save_policy/1, :ok, false)

      {:build_role_links} ->
        handle_enforcer_operation(state, &Enforcer.build_role_links/1, :ok)

      _ ->
        {:reply, {:error, :unknown_write_operation}, state}
    end
  end

  defp handle_policy_operation(state, operation, params) do
    operation_func =
      case operation do
        :add_policy -> &add_policy_impl/4
        :remove_policy -> &remove_policy_impl/4
      end

    case operation_func.(state.enforcer, "p", "p", params) do
      {:ok, new_enforcer} ->
        new_state = %{state | enforcer: new_enforcer}
        update_ets(new_state)
        {:reply, true, new_state}

      {:error, _reason} ->
        {:reply, false, state}
    end
  end

  defp handle_policy_batch_operation(state, :add_policies, rules) do
    {:ok, new_enforcer} = add_policies_impl(state.enforcer, "p", "p", rules)
    new_state = %{state | enforcer: new_enforcer}
    update_ets(new_state)
    {:reply, true, new_state}
  end

  defp handle_grouping_policy_operation(state, operation, params) do
    operation_func =
      case operation do
        :add_grouping_policy -> &add_grouping_policy_impl/4
        :remove_grouping_policy -> &remove_grouping_policy_impl/4
      end

    case operation_func.(state.enforcer, "g", "g", params) do
      {:ok, new_enforcer} ->
        new_state = %{state | enforcer: new_enforcer}
        update_ets(new_state)
        {:reply, true, new_state}

      {:error, _reason} ->
        {:reply, false, state}
    end
  end

  defp handle_enforcer_operation(state, operation_func, success_value, update_ets? \\ true) do
    case operation_func.(state.enforcer) do
      {:ok, new_enforcer} ->
        new_state = %{state | enforcer: new_enforcer}
        if update_ets?, do: update_ets(new_state)
        {:reply, success_value, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp update_ets(state) do
    name = self_name()
    :ets.insert(:casbin_enforcers_table, {name, state.enforcer})
  end

  defp self_name do
    case Registry.keys(CasbinEx2.EnforcerRegistry, self()) do
      [name] -> name
      _ -> :unknown
    end
  end

  # Implementation helpers (similar to EnforcerServer)
  defp add_policy_impl(enforcer, _sec, ptype, rule) do
    %{policies: policies} = enforcer
    current_rules = Map.get(policies, ptype, [])

    if rule in current_rules do
      {:error, :already_exists}
    else
      new_rules = [rule | current_rules]
      new_policies = Map.put(policies, ptype, new_rules)
      new_enforcer = %{enforcer | policies: new_policies}
      {:ok, new_enforcer}
    end
  end

  defp add_policies_impl(enforcer, _sec, ptype, rules) do
    %{policies: policies} = enforcer
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
    new_enforcer = %{enforcer | policies: new_policies}
    {:ok, new_enforcer}
  end

  defp remove_policy_impl(enforcer, _sec, ptype, rule) do
    %{policies: policies} = enforcer
    current_rules = Map.get(policies, ptype, [])

    if rule in current_rules do
      new_rules = List.delete(current_rules, rule)
      new_policies = Map.put(policies, ptype, new_rules)
      new_enforcer = %{enforcer | policies: new_policies}
      {:ok, new_enforcer}
    else
      {:error, :not_found}
    end
  end

  defp add_grouping_policy_impl(enforcer, _sec, ptype, rule) do
    %{grouping_policies: grouping_policies, role_manager: role_manager} = enforcer
    current_rules = Map.get(grouping_policies, ptype, [])

    if rule in current_rules do
      {:error, :already_exists}
    else
      new_rules = [rule | current_rules]
      new_grouping_policies = Map.put(grouping_policies, ptype, new_rules)

      # Update role manager
      new_role_manager =
        case rule do
          [user, role] ->
            CasbinEx2.RoleManager.add_link(role_manager, user, role, "")

          [user, role, domain] ->
            CasbinEx2.RoleManager.add_link(role_manager, user, role, domain)

          _ ->
            role_manager
        end

      new_enforcer = %{
        enforcer
        | grouping_policies: new_grouping_policies,
          role_manager: new_role_manager
      }

      {:ok, new_enforcer}
    end
  end

  defp remove_grouping_policy_impl(enforcer, _sec, ptype, rule) do
    %{grouping_policies: grouping_policies, role_manager: role_manager} = enforcer
    current_rules = Map.get(grouping_policies, ptype, [])

    if rule in current_rules do
      new_rules = List.delete(current_rules, rule)
      new_grouping_policies = Map.put(grouping_policies, ptype, new_rules)

      # Update role manager
      new_role_manager =
        case rule do
          [user, role] ->
            CasbinEx2.RoleManager.delete_link(role_manager, user, role, "")

          [user, role, domain] ->
            CasbinEx2.RoleManager.delete_link(role_manager, user, role, domain)

          _ ->
            role_manager
        end

      new_enforcer = %{
        enforcer
        | grouping_policies: new_grouping_policies,
          role_manager: new_role_manager
      }

      {:ok, new_enforcer}
    else
      {:error, :not_found}
    end
  end

  defp get_filtered_policy_impl(enforcer, ptype, field_index, field_values) do
    current_rules = Map.get(enforcer.policies, ptype, [])

    Enum.filter(current_rules, fn rule ->
      matches_filter_values?(rule, field_index, field_values)
    end)
  end

  defp matches_filter_values?(rule, field_index, field_values) do
    field_values
    |> Enum.with_index()
    |> Enum.all?(fn {value, offset} ->
      matches_field_value?(rule, field_index + offset, value)
    end)
  end

  defp matches_field_value?(_rule, _rule_index, ""), do: true

  defp matches_field_value?(rule, rule_index, value) do
    Enum.at(rule, rule_index) == value
  end

  defp has_policy_impl(enforcer, ptype, params) do
    current_rules = Map.get(enforcer.policies, ptype, [])
    params in current_rules
  end

  defp get_permissions_for_user_impl(enforcer, user, domain) do
    current_rules = Map.get(enforcer.policies, "p", [])
    direct_permissions = filter_user_permissions(current_rules, user, domain)
    role_permissions = get_role_based_permissions(enforcer, current_rules, user, domain)

    (direct_permissions ++ role_permissions) |> Enum.uniq()
  end

  defp filter_user_permissions(current_rules, user, domain) do
    Enum.filter(current_rules, fn rule ->
      matches_user_rule?(rule, user, domain)
    end)
  end

  defp get_role_based_permissions(enforcer, current_rules, user, domain) do
    roles = CasbinEx2.RoleManager.get_roles(enforcer.role_manager, user, domain)

    Enum.flat_map(roles, fn role ->
      filter_role_permissions(current_rules, role, domain)
    end)
  end

  defp filter_role_permissions(current_rules, role, domain) do
    Enum.filter(current_rules, fn rule ->
      matches_user_rule?(rule, role, domain)
    end)
  end

  defp matches_user_rule?([subject | _], target_subject, "") when subject == target_subject,
    do: true

  defp matches_user_rule?([subject, _, _, domain], target_subject, target_domain)
       when subject == target_subject and domain == target_domain,
       do: true

  defp matches_user_rule?(_, _, _), do: false
end
