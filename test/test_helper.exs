# Start the Registries for DistributedEnforcer and SyncedEnforcer tests if not already started
case Registry.start_link(keys: :unique, name: CasbinEx2.EnforcerRegistry) do
  {:ok, _pid} -> :ok
  {:error, {:already_started, _pid}} -> :ok
end

case Registry.start_link(keys: :unique, name: CasbinEx2.Registry) do
  {:ok, _pid} -> :ok
  {:error, {:already_started, _pid}} -> :ok
end

ExUnit.start()
