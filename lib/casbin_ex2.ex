defmodule CasbinEx2 do
  @moduledoc """
  CasbinEx2 is an Elixir implementation of the Casbin authorization library.

  Casbin is a powerful and efficient open-source access control library.
  It provides support for enforcing authorization based on various access control models.

  ## Features

  - Multiple built-in models: ACL, RBAC, ABAC
  - Support for multiple adapters (File, Ecto SQL)
  - Process-based enforcement with GenServer
  - Cached enforcement for better performance
  - Synchronized enforcement for thread safety
  - Dynamic supervisor for managing enforcer processes

  ## Basic Usage

      # Start an enforcer
      {:ok, _pid} = CasbinEx2.start_enforcer(:my_enforcer, "path/to/model.conf")

      # Add a policy
      CasbinEx2.add_policy(:my_enforcer, ["alice", "data1", "read"])

      # Check permissions
      CasbinEx2.enforce(:my_enforcer, ["alice", "data1", "read"])  # true

  """

  alias CasbinEx2.EnforcerServer
  alias CasbinEx2.EnforcerSupervisor

  @doc """
  Starts a new enforcer process.
  """
  def start_enforcer(name, model_path, opts \\ []) do
    EnforcerSupervisor.start_enforcer(name, model_path, opts)
  end

  @doc """
  Stops an enforcer process.
  """
  def stop_enforcer(name) do
    EnforcerSupervisor.stop_enforcer(name)
  end

  @doc """
  Performs authorization enforcement.
  """
  def enforce(name, request) do
    EnforcerServer.enforce(name, request)
  end

  @doc """
  Adds a policy rule.
  """
  def add_policy(name, params) do
    EnforcerServer.add_policy(name, params)
  end

  @doc """
  Removes a policy rule.
  """
  def remove_policy(name, params) do
    EnforcerServer.remove_policy(name, params)
  end

  @doc """
  Gets all policy rules.
  """
  def get_policy(name) do
    EnforcerServer.get_policy(name)
  end

  @doc """
  Checks if a policy rule exists.
  """
  def has_policy(name, params) do
    EnforcerServer.has_policy(name, params)
  end

  @doc """
  Adds a role for a user.
  """
  def add_role_for_user(name, user, role, domain \\ "") do
    EnforcerServer.add_role_for_user(name, user, role, domain)
  end

  @doc """
  Deletes a role for a user.
  """
  def delete_role_for_user(name, user, role, domain \\ "") do
    EnforcerServer.delete_role_for_user(name, user, role, domain)
  end

  @doc """
  Gets all roles for a user.
  """
  def get_roles_for_user(name, user, domain \\ "") do
    EnforcerServer.get_roles_for_user(name, user, domain)
  end

  @doc """
  Gets all users for a role.
  """
  def get_users_for_role(name, role, domain \\ "") do
    EnforcerServer.get_users_for_role(name, role, domain)
  end

  @doc """
  Checks if a user has a role.
  """
  def has_role_for_user(name, user, role, domain \\ "") do
    EnforcerServer.has_role_for_user(name, user, role, domain)
  end

  @doc """
  Loads policy from the adapter.
  """
  def load_policy(name) do
    EnforcerServer.load_policy(name)
  end

  @doc """
  Saves policy to the adapter.
  """
  def save_policy(name) do
    EnforcerServer.save_policy(name)
  end
end
