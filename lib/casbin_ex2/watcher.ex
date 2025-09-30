defmodule CasbinEx2.Watcher do
  @moduledoc """
  Watcher interface for policy change notifications.

  Watchers are used to notify other enforcer instances when policies are changed,
  enabling distributed policy synchronization.
  """

  @type t :: module()

  @doc """
  Starts the watcher.
  """
  @callback start_watcher() :: :ok | {:error, term()}

  @doc """
  Stops the watcher.
  """
  @callback stop_watcher() :: :ok

  @doc """
  Sets the update callback function that will be called when policies are updated.
  """
  @callback set_update_callback(function()) :: :ok

  @doc """
  Notifies all watchers about a policy update.
  """
  @callback update() :: :ok

  @doc """
  Updates policies for a specific enforcer instance.
  """
  @callback update_for_enforcer(String.t()) :: :ok

  @doc """
  Starts a watcher and returns its state.
  """
  @spec start_watcher(t()) :: :ok | {:error, term()}
  def start_watcher(watcher) do
    watcher.start_watcher()
  end

  @doc """
  Stops a watcher.
  """
  @spec stop_watcher(t()) :: :ok
  def stop_watcher(watcher) do
    watcher.stop_watcher()
  end

  @doc """
  Sets the update callback for a watcher.
  """
  @spec set_update_callback(t(), function()) :: :ok
  def set_update_callback(watcher, callback) do
    watcher.set_update_callback(callback)
  end

  @doc """
  Triggers an update notification.
  """
  @spec update(t()) :: :ok
  def update(watcher) do
    watcher.update()
  end

  @doc """
  Triggers an update for a specific enforcer.
  """
  @spec update_for_enforcer(t(), String.t()) :: :ok
  def update_for_enforcer(watcher, enforcer_name) do
    watcher.update_for_enforcer(enforcer_name)
  end
end