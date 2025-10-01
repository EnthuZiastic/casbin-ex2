defmodule CasbinEx2.Dispatcher.Default do
  @moduledoc """
  Default no-op dispatcher implementation.

  This dispatcher does nothing and always returns `:ok`. It's useful for:
  - Single-instance deployments that don't need distributed policy synchronization
  - Testing scenarios where you want to disable dispatching
  - Development environments

  ## Usage

      enforcer = Enforcer.init_with_file("model.conf", "policy.csv")
      enforcer = Enforcer.set_dispatcher(enforcer, CasbinEx2.Dispatcher.Default)
  """

  @behaviour CasbinEx2.Dispatcher

  @impl true
  def add_policies(_sec, _ptype, _rules), do: :ok

  @impl true
  def remove_policies(_sec, _ptype, _rules), do: :ok

  @impl true
  def remove_filtered_policy(_sec, _ptype, _field_index, _field_values), do: :ok

  @impl true
  def clear_policy, do: :ok

  @impl true
  def update_policy(_sec, _ptype, _old_rule, _new_rule), do: :ok

  @impl true
  def update_policies(_sec, _ptype, _old_rules, _new_rules), do: :ok

  @impl true
  def update_filtered_policies(_sec, _ptype, _old_rules, _new_rules), do: :ok
end
