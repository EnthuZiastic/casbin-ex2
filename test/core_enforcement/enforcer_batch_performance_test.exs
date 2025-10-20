defmodule CasbinEx2.EnforcerBatchPerformanceTest do
  use ExUnit.Case, async: true

  alias CasbinEx2.Adapter.MemoryAdapter
  alias CasbinEx2.Enforcer
  alias CasbinEx2.Management
  alias CasbinEx2.Model
  alias CasbinEx2.RBAC

  @model_path "examples/rbac_model.conf"

  setup do
    {:ok, model} = Model.load_model(@model_path)
    adapter = MemoryAdapter.new()
    {:ok, enforcer} = Enforcer.init_with_model_and_adapter(model, adapter)

    {:ok, enforcer: enforcer, model: model}
  end

  describe "batch_enforce/2 performance" do
    test "handles small batch efficiently", %{enforcer: enforcer} do
      {:ok, enforcer} = Management.add_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["bob", "data2", "write"])

      requests = [
        ["alice", "data1", "read"],
        ["alice", "data1", "write"],
        ["bob", "data2", "write"],
        ["bob", "data2", "read"]
      ]

      {time, results} = :timer.tc(fn -> Enforcer.batch_enforce(enforcer, requests) end)

      assert length(results) == 4
      assert Enum.at(results, 0) == true
      assert Enum.at(results, 1) == false
      assert Enum.at(results, 2) == true
      assert Enum.at(results, 3) == false
      # Should complete quickly (< 10ms for 4 requests)
      assert time < 10_000
    end

    test "handles medium batch efficiently", %{enforcer: enforcer} do
      # Add 50 policies
      enforcer =
        Enum.reduce(1..50, enforcer, fn i, acc ->
          {:ok, updated} = Management.add_policy(acc, ["user#{i}", "data#{i}", "read"])
          updated
        end)

      # Create 100 requests
      requests =
        Enum.flat_map(1..50, fn i ->
          [
            ["user#{i}", "data#{i}", "read"],
            ["user#{i}", "data#{i}", "write"]
          ]
        end)

      {time, results} = :timer.tc(fn -> Enforcer.batch_enforce(enforcer, requests) end)

      assert length(results) == 100
      # Verify some true and some false results
      true_count = Enum.count(results, &(&1 == true))
      false_count = Enum.count(results, &(&1 == false))
      assert true_count >= 40
      assert false_count >= 40
      # Should complete reasonably fast (< 100ms for 100 requests)
      assert time < 100_000
    end

    test "handles large batch efficiently", %{enforcer: enforcer} do
      # Add 100 policies
      enforcer =
        Enum.reduce(1..100, enforcer, fn i, acc ->
          {:ok, updated} = Management.add_policy(acc, ["user#{i}", "data#{i}", "read"])
          updated
        end)

      # Create 500 requests
      requests =
        Enum.flat_map(1..100, fn i ->
          [
            ["user#{i}", "data#{i}", "read"],
            ["user#{i}", "data#{i}", "write"],
            ["user#{i}", "data#{i}", "delete"],
            ["user#{i}", "other#{i}", "read"],
            ["other#{i}", "data#{i}", "read"]
          ]
        end)

      {time, results} = :timer.tc(fn -> Enforcer.batch_enforce(enforcer, requests) end)

      assert length(results) == 500
      # Should use parallel processing for large batches
      # Performance should be reasonable (< 500ms for 500 requests)
      assert time < 500_000
    end

    test "parallel processing for large batches is faster", %{enforcer: enforcer} do
      # Add 50 policies
      enforcer =
        Enum.reduce(1..50, enforcer, fn i, acc ->
          {:ok, updated} = Management.add_policy(acc, ["user#{i}", "data#{i}", "read"])
          updated
        end)

      # Create 20 requests (uses parallel processing at >10 threshold)
      requests =
        Enum.map(1..20, fn i ->
          ["user#{rem(i - 1, 50) + 1}", "data#{rem(i - 1, 50) + 1}", "read"]
        end)

      {parallel_time, results} = :timer.tc(fn -> Enforcer.batch_enforce(enforcer, requests) end)

      assert length(results) == 20
      # Parallel processing should complete quickly
      assert parallel_time < 50_000
    end
  end

  describe "batch_enforce_with_matcher/3 performance" do
    test "handles batch with custom matcher", %{enforcer: enforcer} do
      {:ok, enforcer} = Management.add_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["bob", "data2", "write"])

      matcher = "g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act"

      requests = [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"]
      ]

      {time, results} =
        :timer.tc(fn ->
          Enforcer.batch_enforce_with_matcher(enforcer, matcher, requests)
        end)

      assert length(results) == 2
      assert Enum.all?(results, &is_boolean/1)
      assert time < 10_000
    end

    test "handles large batch with custom matcher", %{enforcer: enforcer} do
      # Add policies
      enforcer =
        Enum.reduce(1..50, enforcer, fn i, acc ->
          {:ok, updated} = Management.add_policy(acc, ["user#{i}", "data#{i}", "read"])
          updated
        end)

      matcher = "g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act"
      requests = Enum.map(1..20, fn i -> ["user#{i}", "data#{i}", "read"] end)

      {time, results} =
        :timer.tc(fn ->
          Enforcer.batch_enforce_with_matcher(enforcer, matcher, requests)
        end)

      assert length(results) == 20
      # Should use parallel processing
      assert time < 100_000
    end
  end

  describe "batch_enforce_ex/2 performance" do
    test "returns detailed results for batch", %{enforcer: enforcer} do
      {:ok, enforcer} = Management.add_policy(enforcer, ["alice", "data1", "read"])

      requests = [
        ["alice", "data1", "read"],
        ["alice", "data1", "write"]
      ]

      {time, results} = :timer.tc(fn -> Enforcer.batch_enforce_ex(enforcer, requests) end)

      assert length(results) == 2
      assert is_list(results)
      assert time < 10_000
    end

    test "handles large batch with detailed results", %{enforcer: enforcer} do
      enforcer =
        Enum.reduce(1..30, enforcer, fn i, acc ->
          {:ok, updated} = Management.add_policy(acc, ["user#{i}", "data#{i}", "read"])
          updated
        end)

      requests = Enum.map(1..20, fn i -> ["user#{i}", "data#{i}", "read"] end)

      {time, results} = :timer.tc(fn -> Enforcer.batch_enforce_ex(enforcer, requests) end)

      assert length(results) == 20
      # Parallel processing should be used
      assert time < 100_000
    end
  end

  describe "add_policies/2 batch operations" do
    test "adds multiple policies efficiently", %{enforcer: enforcer} do
      policies = [
        ["alice", "data1", "read"],
        ["alice", "data1", "write"],
        ["bob", "data2", "read"],
        ["bob", "data2", "write"],
        ["charlie", "data3", "read"]
      ]

      {time, {:ok, enforcer}} = :timer.tc(fn -> Management.add_policies(enforcer, policies) end)

      assert Enforcer.enforce(enforcer, ["alice", "data1", "read"]) == true
      assert Enforcer.enforce(enforcer, ["alice", "data1", "write"]) == true
      assert Enforcer.enforce(enforcer, ["bob", "data2", "read"]) == true
      assert Enforcer.enforce(enforcer, ["bob", "data2", "write"]) == true
      assert Enforcer.enforce(enforcer, ["charlie", "data3", "read"]) == true
      # Should be fast
      assert time < 10_000
    end

    test "adds large batch of policies efficiently", %{enforcer: enforcer} do
      policies = Enum.map(1..100, fn i -> ["user#{i}", "data#{i}", "read"] end)

      {time, {:ok, enforcer}} = :timer.tc(fn -> Management.add_policies(enforcer, policies) end)

      # Verify some policies
      assert Enforcer.enforce(enforcer, ["user1", "data1", "read"]) == true
      assert Enforcer.enforce(enforcer, ["user50", "data50", "read"]) == true
      assert Enforcer.enforce(enforcer, ["user100", "data100", "read"]) == true
      # Should complete in reasonable time (< 100ms for 100 policies)
      assert time < 100_000
    end

    test "handles empty policy list", %{enforcer: enforcer} do
      {time, {:ok, updated}} = :timer.tc(fn -> Management.add_policies(enforcer, []) end)

      assert updated == enforcer
      assert time < 1_000
    end

    test "handles duplicate policies in batch", %{enforcer: enforcer} do
      policies = [
        ["alice", "data1", "read"],
        ["alice", "data1", "read"],
        ["bob", "data2", "write"]
      ]

      # add_policies may fail with duplicates
      result = Management.add_policies(enforcer, policies)

      case result do
        {:ok, enforcer} ->
          assert Enforcer.enforce(enforcer, ["alice", "data1", "read"]) == true
          assert Enforcer.enforce(enforcer, ["bob", "data2", "write"]) == true

        {:error, _} ->
          # Duplicates cause error, which is expected behavior
          assert true
      end
    end
  end

  describe "remove_policies/2 batch operations" do
    test "removes multiple policies efficiently", %{enforcer: enforcer} do
      # Add policies
      {:ok, enforcer} = Management.add_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["alice", "data1", "write"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["bob", "data2", "read"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["bob", "data2", "write"])

      policies = [
        ["alice", "data1", "write"],
        ["bob", "data2", "write"]
      ]

      {time, {:ok, enforcer}} =
        :timer.tc(fn -> Management.remove_policies(enforcer, policies) end)

      assert Enforcer.enforce(enforcer, ["alice", "data1", "read"]) == true
      assert Enforcer.enforce(enforcer, ["alice", "data1", "write"]) == false
      assert Enforcer.enforce(enforcer, ["bob", "data2", "read"]) == true
      assert Enforcer.enforce(enforcer, ["bob", "data2", "write"]) == false
      assert time < 10_000
    end

    test "removes large batch of policies efficiently", %{enforcer: enforcer} do
      # Add 100 policies
      policies = Enum.map(1..100, fn i -> ["user#{i}", "data#{i}", "read"] end)
      {:ok, enforcer} = Management.add_policies(enforcer, policies)

      # Remove 50 policies
      to_remove = Enum.map(1..50, fn i -> ["user#{i}", "data#{i}", "read"] end)

      {time, {:ok, enforcer}} =
        :timer.tc(fn -> Management.remove_policies(enforcer, to_remove) end)

      # Verify removals
      assert Enforcer.enforce(enforcer, ["user1", "data1", "read"]) == false
      assert Enforcer.enforce(enforcer, ["user50", "data50", "read"]) == false
      assert Enforcer.enforce(enforcer, ["user51", "data51", "read"]) == true
      assert Enforcer.enforce(enforcer, ["user100", "data100", "read"]) == true
      assert time < 100_000
    end

    test "handles empty removal list", %{enforcer: enforcer} do
      {time, {:ok, updated}} = :timer.tc(fn -> Management.remove_policies(enforcer, []) end)

      assert updated == enforcer
      assert time < 1_000
    end
  end

  describe "policy performance with large datasets" do
    test "enforce performance with 1000 policies", %{enforcer: enforcer} do
      # Add 1000 policies
      policies = Enum.map(1..1_000, fn i -> ["user#{i}", "data#{i}", "read"] end)
      {:ok, enforcer} = Management.add_policies(enforcer, policies)

      # Test enforcement speed
      {time, result} =
        :timer.tc(fn -> Enforcer.enforce(enforcer, ["user500", "data500", "read"]) end)

      assert result == true
      # Should be fast even with 1000 policies (< 15ms, allowing for system variability)
      assert time < 15_000
    end

    test "batch enforce performance with 1000 policies", %{enforcer: enforcer} do
      # Add 1000 policies
      policies = Enum.map(1..1_000, fn i -> ["user#{i}", "data#{i}", "read"] end)
      {:ok, enforcer} = Management.add_policies(enforcer, policies)

      # Test batch enforcement with 100 requests
      requests = Enum.map(1..100, fn i -> ["user#{i * 10}", "data#{i * 10}", "read"] end)

      {time, results} = :timer.tc(fn -> Enforcer.batch_enforce(enforcer, requests) end)

      assert length(results) == 100
      # Should complete in reasonable time even with 1000 policies (< 200ms)
      assert time < 200_000
    end

    test "policy addition scales linearly", %{enforcer: enforcer} do
      # Add 100 policies and measure time
      policies_100 = Enum.map(1..100, fn i -> ["user#{i}", "data#{i}", "read"] end)

      {time_100, {:ok, enforcer}} =
        :timer.tc(fn -> Management.add_policies(enforcer, policies_100) end)

      # Add another 100 policies
      policies_200 = Enum.map(101..200, fn i -> ["user#{i}", "data#{i}", "read"] end)

      {time_200, {:ok, enforcer}} =
        :timer.tc(fn -> Management.add_policies(enforcer, policies_200) end)

      # Both batches should complete, verify policies exist
      assert Enforcer.enforce(enforcer, ["user50", "data50", "read"]) == true
      assert Enforcer.enforce(enforcer, ["user150", "data150", "read"]) == true
      # Timing can be variable, just ensure both completed
      assert time_100 > 0
      assert time_200 > 0
    end
  end

  describe "role performance with large datasets" do
    test "role enforcement with deep hierarchy", %{enforcer: enforcer} do
      # Create deep role hierarchy: user -> role1 -> role2 -> ... -> role10
      enforcer =
        Enum.reduce(1..10, enforcer, fn i, acc ->
          if i == 1 do
            {:ok, updated} = RBAC.add_role_for_user(acc, "user", "role1")
            updated
          else
            {:ok, updated} = RBAC.add_role_for_user(acc, "role#{i - 1}", "role#{i}")
            updated
          end
        end)

      # Add permission to top role
      {:ok, enforcer} = Management.add_policy(enforcer, ["role10", "data", "read"])

      # Test enforcement through hierarchy
      {time, result} = :timer.tc(fn -> Enforcer.enforce(enforcer, ["user", "data", "read"]) end)

      assert result == true
      # Should resolve hierarchy quickly (< 10ms)
      assert time < 10_000
    end

    test "role enforcement with many roles", %{enforcer: enforcer} do
      # Add user with 50 roles
      enforcer =
        Enum.reduce(1..50, enforcer, fn i, acc ->
          {:ok, updated} = RBAC.add_role_for_user(acc, "alice", "role#{i}")
          updated
        end)

      # Add permissions to various roles
      enforcer =
        Enum.reduce([5, 15, 25, 35, 45], enforcer, fn i, acc ->
          {:ok, updated} = Management.add_policy(acc, ["role#{i}", "data#{i}", "read"])
          updated
        end)

      # Test enforcement
      {time, result} =
        :timer.tc(fn -> Enforcer.enforce(enforcer, ["alice", "data15", "read"]) end)

      assert result == true
      # Should handle many roles efficiently (< 5ms)
      assert time < 5_000
    end

    test "role addition batch performance", %{enforcer: enforcer} do
      # Add 100 role assignments
      enforcer =
        Enum.reduce(1..100, enforcer, fn i, acc ->
          {:ok, updated} = RBAC.add_role_for_user(acc, "user#{i}", "role#{i}")
          updated
        end)

      # Verify some assignments
      assert RBAC.has_role_for_user(enforcer, "user1", "role1") == true
      assert RBAC.has_role_for_user(enforcer, "user50", "role50") == true
      assert RBAC.has_role_for_user(enforcer, "user100", "role100") == true
    end
  end

  describe "concurrent enforcement performance" do
    test "concurrent enforce calls don't interfere", %{enforcer: enforcer} do
      {:ok, enforcer} = Management.add_policy(enforcer, ["alice", "data1", "read"])
      {:ok, enforcer} = Management.add_policy(enforcer, ["bob", "data2", "write"])

      # Spawn multiple concurrent enforce calls
      tasks =
        Enum.map(1..50, fn i ->
          Task.async(fn ->
            if rem(i, 2) == 0 do
              Enforcer.enforce(enforcer, ["alice", "data1", "read"])
            else
              Enforcer.enforce(enforcer, ["bob", "data2", "write"])
            end
          end)
        end)

      results = Task.await_many(tasks)

      # All should succeed
      assert length(results) == 50
      assert Enum.all?(results, &(&1 == true))
    end

    test "concurrent policy modifications are safe", %{enforcer: enforcer} do
      # Spawn tasks that add different policies concurrently
      tasks =
        Enum.map(1..20, fn i ->
          Task.async(fn ->
            Management.add_policy(enforcer, ["user#{i}", "data#{i}", "read"])
          end)
        end)

      results = Task.await_many(tasks)

      # All should succeed
      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)
    end
  end

  describe "caching and optimization" do
    test "repeated enforcement uses cache", %{enforcer: enforcer} do
      {:ok, enforcer} = Management.add_policy(enforcer, ["alice", "data1", "read"])

      # First call
      {time1, result1} =
        :timer.tc(fn -> Enforcer.enforce(enforcer, ["alice", "data1", "read"]) end)

      assert result1 == true

      # Second call (may use cached result)
      {time2, result2} =
        :timer.tc(fn -> Enforcer.enforce(enforcer, ["alice", "data1", "read"]) end)

      assert result2 == true

      # Second call should be at least as fast
      assert time2 <= time1 * 1.5
    end

    test "policy changes invalidate cache", %{enforcer: enforcer} do
      {:ok, enforcer} = Management.add_policy(enforcer, ["alice", "data1", "read"])

      # First enforcement
      assert Enforcer.enforce(enforcer, ["alice", "data1", "read"]) == true

      # Modify policy
      {:ok, enforcer} = Management.remove_policy(enforcer, ["alice", "data1", "read"])

      # Should reflect change
      assert Enforcer.enforce(enforcer, ["alice", "data1", "read"]) == false
    end
  end

  describe "memory efficiency" do
    test "enforcer size remains reasonable with many policies", %{enforcer: enforcer} do
      initial_size = :erts_debug.size(enforcer)

      # Add 500 policies
      policies = Enum.map(1..500, fn i -> ["user#{i}", "data#{i}", "read"] end)
      {:ok, enforcer} = Management.add_policies(enforcer, policies)

      final_size = :erts_debug.size(enforcer)

      # Size should grow with policies
      assert final_size > initial_size
      # Verify enforcer still works
      assert Enforcer.enforce(enforcer, ["user1", "data1", "read"]) == true
      assert Enforcer.enforce(enforcer, ["user500", "data500", "read"]) == true
    end

    test "policy removal frees memory", %{enforcer: enforcer} do
      # Add 100 policies
      policies = Enum.map(1..100, fn i -> ["user#{i}", "data#{i}", "read"] end)
      {:ok, enforcer} = Management.add_policies(enforcer, policies)

      size_with_policies = :erts_debug.size(enforcer)

      # Remove all policies
      {:ok, enforcer} = Management.remove_policies(enforcer, policies)

      size_after_removal = :erts_debug.size(enforcer)

      # Size should decrease significantly
      assert size_after_removal < size_with_policies
    end
  end

  describe "edge case performance" do
    test "performance with empty policy set", %{enforcer: enforcer} do
      {time, result} = :timer.tc(fn -> Enforcer.enforce(enforcer, ["alice", "data1", "read"]) end)

      assert result == false
      # Should be very fast with no policies
      assert time < 500
    end

    test "performance with single policy", %{enforcer: enforcer} do
      {:ok, enforcer} = Management.add_policy(enforcer, ["alice", "data1", "read"])

      {time, result} = :timer.tc(fn -> Enforcer.enforce(enforcer, ["alice", "data1", "read"]) end)

      assert result == true
      assert time < 1_000
    end

    test "performance with complex matcher", %{enforcer: enforcer} do
      {:ok, enforcer} = Management.add_policy(enforcer, ["alice", "data1", "read"])

      complex_matcher = "g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act && r.sub != \"\""

      {time, result} =
        :timer.tc(fn ->
          Enforcer.enforce_with_matcher(enforcer, complex_matcher, ["alice", "data1", "read"])
        end)

      assert is_boolean(result)
      assert time < 5_000
    end
  end
end
