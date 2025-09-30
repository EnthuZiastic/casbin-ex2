defmodule CasbinEx2.SyncedEnforcer do
  @moduledoc """
  Synchronized enforcer that wraps the basic enforcer with read-write locks
  for thread-safe access in concurrent environments.
  """

  use GenServer

  require Logger

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
    adapter = Keyword.get(opts, :adapter, CasbinEx2.Adapter.FileAdapter.new(""))

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
    case call do
      {:enforce, request} ->
        result = Enforcer.enforce(state.enforcer, request)
        {:reply, result, state}

      {:batch_enforce, requests} ->
        results = Enum.map(requests, &Enforcer.enforce(state.enforcer, &1))
        {:reply, results, state}

      {:get_policy} ->
        policies = Map.get(state.enforcer.policies, "p", [])
        {:reply, policies, state}

      {:get_filtered_policy, field_index, field_values} ->
        policies = get_filtered_policy_impl(state.enforcer, "p", field_index, field_values)
        {:reply, policies, state}

      {:has_policy, params} ->
        result = has_policy_impl(state.enforcer, "p", params)
        {:reply, result, state}

      {:get_grouping_policy} ->
        policies = Map.get(state.enforcer.grouping_policies, "g", [])
        {:reply, policies, state}

      {:get_roles_for_user, user, domain} ->
        roles = CasbinEx2.RoleManager.get_roles(state.enforcer.role_manager, user, domain)
        {:reply, roles, state}

      {:get_users_for_role, role, domain} ->
        users = CasbinEx2.RoleManager.get_users(state.enforcer.role_manager, role, domain)
        {:reply, users, state}

      {:has_role_for_user, user, role, domain} ->
        result = CasbinEx2.RoleManager.has_link(state.enforcer.role_manager, user, role, domain)
        {:reply, result, state}

      {:get_permissions_for_user, user, domain} ->
        permissions = get_permissions_for_user_impl(state.enforcer, user, domain)
        {:reply, permissions, state}

      _ ->
        {:reply, {:error, :unknown_read_operation}, state}
    end
  end

  defp handle_write_operation(call, _from, state) do
    case call do
      {:add_policy, params} ->
        case add_policy_impl(state.enforcer, "p", "p", params) do
          {:ok, new_enforcer} ->
            new_state = %{state | enforcer: new_enforcer}
            update_ets(new_state)
            {:reply, true, new_state}

          {:error, _reason} ->
            {:reply, false, state}
        end

      {:add_policies, rules} ->
        {:ok, new_enforcer} = add_policies_impl(state.enforcer, "p", "p", rules)
        new_state = %{state | enforcer: new_enforcer}
        update_ets(new_state)
        {:reply, true, new_state}

      {:remove_policy, params} ->
        case remove_policy_impl(state.enforcer, "p", "p", params) do
          {:ok, new_enforcer} ->
            new_state = %{state | enforcer: new_enforcer}
            update_ets(new_state)
            {:reply, true, new_state}

          {:error, _reason} ->
            {:reply, false, state}
        end

      {:add_grouping_policy, params} ->
        case add_grouping_policy_impl(state.enforcer, "g", "g", params) do
          {:ok, new_enforcer} ->
            new_state = %{state | enforcer: new_enforcer}
            update_ets(new_state)
            {:reply, true, new_state}

          {:error, _reason} ->
            {:reply, false, state}
        end

      {:remove_grouping_policy, params} ->
        case remove_grouping_policy_impl(state.enforcer, "g", "g", params) do
          {:ok, new_enforcer} ->
            new_state = %{state | enforcer: new_enforcer}
            update_ets(new_state)
            {:reply, true, new_state}

          {:error, _reason} ->
            {:reply, false, state}
        end

      {:load_policy} ->
        case Enforcer.load_policy(state.enforcer) do
          {:ok, new_enforcer} ->
            new_state = %{state | enforcer: new_enforcer}
            update_ets(new_state)
            {:reply, :ok, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      {:save_policy} ->
        case Enforcer.save_policy(state.enforcer) do
          {:ok, new_enforcer} ->
            new_state = %{state | enforcer: new_enforcer}
            {:reply, :ok, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end

      {:build_role_links} ->
        {:ok, new_enforcer} = Enforcer.build_role_links(state.enforcer)
        new_state = %{state | enforcer: new_enforcer}
        update_ets(new_state)
        {:reply, :ok, new_state}

      _ ->
        {:reply, {:error, :unknown_write_operation}, state}
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

  defp has_policy_impl(enforcer, ptype, params) do
    current_rules = Map.get(enforcer.policies, ptype, [])
    params in current_rules
  end

  defp get_permissions_for_user_impl(enforcer, user, domain) do
    # Get direct permissions for user
    current_rules = Map.get(enforcer.policies, "p", [])

    direct_permissions =
      Enum.filter(current_rules, fn rule ->
        case rule do
          [^user | _] when domain == "" -> true
          [^user, _, _, ^domain] -> true
          _ -> false
        end
      end)

    # Get permissions through roles
    roles = CasbinEx2.RoleManager.get_roles(enforcer.role_manager, user, domain)

    role_permissions =
      Enum.flat_map(roles, fn role ->
        Enum.filter(current_rules, fn rule ->
          case rule do
            [^role | _] when domain == "" -> true
            [^role, _, _, ^domain] -> true
            _ -> false
          end
        end)
      end)

    (direct_permissions ++ role_permissions) |> Enum.uniq()
  end
end
