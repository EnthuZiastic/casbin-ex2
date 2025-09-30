defmodule CasbinEx2.EnforcerSupervisor do
  @moduledoc """
  A supervisor that starts `Enforcer` processes dynamically.
  """

  use DynamicSupervisor

  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new `Enforcer` process and supervises it
  """
  def start_enforcer(name, model_path, opts \\ []) do
    child_spec = %{
      id: CasbinEx2.EnforcerServer,
      start: {CasbinEx2.EnforcerServer, :start_link, [name, model_path, opts]},
      restart: :permanent
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Stops an enforcer process by name
  """
  def stop_enforcer(name) do
    case Registry.lookup(CasbinEx2.EnforcerRegistry, name) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)

      [] ->
        {:error, :not_found}
    end
  end
end
