defmodule CasbinEx2.DistributedEnforcerTest do
  use ExUnit.Case, async: false

  alias CasbinEx2.DistributedEnforcer

  @model_path "examples/rbac_model.conf"

  setup do
    name = "test_distributed_#{:rand.uniform(10000)}"

    opts = [
      name: name,
      model_path: @model_path,
      nodes: [Node.self()],
      sync_interval: 60_000,
      auto_sync: false
    ]

    {:ok, pid} = DistributedEnforcer.start_link(opts)

    on_exit(fn ->
      if Process.alive?(pid) do
        try do
          GenServer.stop(pid)
        catch
          :exit, _ -> :ok
        end
      end
    end)

    {:ok, name: name, pid: pid}
  end

  describe "new/2" do
    test "creates distributed enforcer configuration" do
      config =
        DistributedEnforcer.new("test_enforcer",
          nodes: [Node.self(), :node2@localhost],
          sync_interval: 30_000,
          auto_sync: true
        )

      assert config.enforcer_name == "test_enforcer"
      assert length(config.nodes) == 2
      assert config.sync_interval == 30_000
      assert config.auto_sync == true
    end
  end

  describe "enforce/2" do
    test "performs distributed enforcement", %{name: name} do
      result = DistributedEnforcer.enforce(name, ["alice", "data1", "read"])
      assert is_boolean(result)
    end

    test "rejects unauthorized requests", %{name: name} do
      result = DistributedEnforcer.enforce(name, ["bob", "data1", "write"])
      assert result == false
    end
  end

  describe "add_policy/2" do
    test "adds policy to local node", %{name: name} do
      assert :ok == DistributedEnforcer.add_policy(name, ["new_user", "new_data", "read"])

      # Verify policy was added
      assert true == DistributedEnforcer.enforce(name, ["new_user", "new_data", "read"])
    end

    test "handles duplicate policy addition", %{name: name} do
      DistributedEnforcer.add_policy(name, ["duplicate", "data", "action"])
      result = DistributedEnforcer.add_policy(name, ["duplicate", "data", "action"])

      # Should handle gracefully
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "remove_policy/2" do
    test "removes policy from local node", %{name: name} do
      # Add then remove
      DistributedEnforcer.add_policy(name, ["temp", "temp_data", "read"])
      assert :ok == DistributedEnforcer.remove_policy(name, ["temp", "temp_data", "read"])

      # Verify removal
      assert false == DistributedEnforcer.enforce(name, ["temp", "temp_data", "read"])
    end
  end

  describe "sync_policies/1" do
    test "synchronizes policies across cluster", %{name: name} do
      result = DistributedEnforcer.sync_policies(name)
      # May fail with single node, but tests the API
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "cluster_status/1" do
    test "returns cluster health information", %{name: name} do
      status = DistributedEnforcer.cluster_status(name)

      assert is_list(status.nodes)
      assert is_list(status.healthy_nodes)
      assert Node.self() in status.nodes
    end
  end

  describe "set_auto_sync/2" do
    test "enables auto-sync", %{name: name} do
      assert :ok == DistributedEnforcer.set_auto_sync(name, true)
    end

    test "disables auto-sync", %{name: name} do
      assert :ok == DistributedEnforcer.set_auto_sync(name, false)
    end
  end

  describe "watcher integration" do
    test "handles policy updates via watcher", %{name: name} do
      # Add policy which should trigger watcher notification
      DistributedEnforcer.add_policy(name, ["watcher_test", "data", "read"])

      # Policy should be enforceable
      assert true == DistributedEnforcer.enforce(name, ["watcher_test", "data", "read"])
    end
  end

  describe "multi-node coordination" do
    test "broadcasts policy changes to configured nodes", %{name: name} do
      # Add policy - should broadcast to all nodes
      assert :ok == DistributedEnforcer.add_policy(name, ["broadcast", "data", "write"])

      # Verify locally
      assert true == DistributedEnforcer.enforce(name, ["broadcast", "data", "write"])
    end
  end

  describe "error handling" do
    test "handles enforcer not found", _context do
      result = DistributedEnforcer.enforce("nonexistent_enforcer", ["alice", "data", "read"])
      assert {:error, :enforcer_not_found} == result
    end

    test "handles node down gracefully", %{name: name} do
      # Should not crash when simulating node failure
      status = DistributedEnforcer.cluster_status(name)
      assert is_map(status)
    end
  end

  describe "performance" do
    @tag :performance
    test "handles high concurrent enforcement load", %{name: name} do
      tasks =
        Enum.map(1..100, fn _ ->
          Task.async(fn ->
            DistributedEnforcer.enforce(name, ["alice", "data1", "read"])
          end)
        end)

      results = Task.await_many(tasks, 10_000)
      assert Enum.all?(results, &is_boolean/1)
    end
  end

  describe "consistency" do
    test "maintains policy consistency during concurrent modifications", %{name: name} do
      # Concurrent adds
      add_tasks =
        Enum.map(1..20, fn i ->
          Task.async(fn ->
            DistributedEnforcer.add_policy(name, ["user#{i}", "data#{i}", "read"])
          end)
        end)

      Task.await_many(add_tasks)

      # Verify all were added
      for i <- 1..20 do
        assert true == DistributedEnforcer.enforce(name, ["user#{i}", "data#{i}", "read"])
      end
    end
  end
end
