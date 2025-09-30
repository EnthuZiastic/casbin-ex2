defmodule CasbinEx2.Application do
  @moduledoc """
  Application module for CasbinEx2.
  """

  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: CasbinEx2.EnforcerRegistry},
      CasbinEx2.EnforcerSupervisor
    ]

    # Create ETS table for enforcer persistence
    :ets.new(:casbin_enforcers_table, [:public, :named_table])

    opts = [strategy: :one_for_one, name: CasbinEx2.Supervisor]
    Supervisor.start_link(children, opts)
  end
end