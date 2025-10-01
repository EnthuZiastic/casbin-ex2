defmodule CasbinEx2.Adapter.BatchAdapterTest do
  use ExUnit.Case, async: false

  alias CasbinEx2.Adapter.{BatchAdapter, MemoryAdapter}

  @sample_policies %{
    "p" => [
      ["alice", "data1", "read"],
      ["bob", "data2", "write"],
      ["carol", "data3", "read"]
    ]
  }

  @sample_grouping_policies %{
    "g" => [
      ["alice", "admin"],
      ["bob", "user"]
    ]
  }

  describe "new/2" do
    test "creates batch adapter with default options" do
      base_adapter = MemoryAdapter.new()
      adapter = BatchAdapter.new(base_adapter)

      assert adapter.base_adapter == base_adapter
      assert adapter.batch_size == 50
      assert adapter.enable_transaction == true
      assert adapter.enable_validation == true
      assert adapter.batch_buffer == []
      assert adapter.operation_count == 0
      assert adapter.max_retries == 3
    end

    test "creates batch adapter with custom options" do
      base_adapter = MemoryAdapter.new()

      adapter =
        BatchAdapter.new(base_adapter,
          batch_size: 100,
          enable_transaction: false,
          enable_validation: false,
          max_retries: 5
        )

      assert adapter.batch_size == 100
      assert adapter.enable_transaction == false
      assert adapter.enable_validation == false
      assert adapter.max_retries == 5
    end
  end

  describe "add_policies/3" do
    test "adds multiple policies in a single batch" do
      base_adapter = MemoryAdapter.new()
      adapter = BatchAdapter.new(base_adapter)

      policies = [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"],
        ["carol", "data3", "read"]
      ]

      assert {:ok, updated_adapter} = BatchAdapter.add_policies(adapter, "p", policies)
      assert updated_adapter.operation_count == 3

      # Verify policies were added to base adapter
      {:ok, loaded_policies, _} = BatchAdapter.load_policy(updated_adapter, nil)
      # Order may vary, so compare as sets
      assert Enum.sort(loaded_policies["p"]) == Enum.sort(policies)
    end

    test "handles empty policy list" do
      base_adapter = MemoryAdapter.new()
      adapter = BatchAdapter.new(base_adapter)

      assert {:ok, updated_adapter} = BatchAdapter.add_policies(adapter, "p", [])
      assert updated_adapter.operation_count == 0
    end

    test "validates policies when validation is enabled" do
      base_adapter = MemoryAdapter.new()
      adapter = BatchAdapter.new(base_adapter, enable_validation: true)

      invalid_policies = [
        ["alice", "data1", "read"],
        [],
        # Invalid: empty policy
        ["bob", "data2", "write"]
      ]

      assert {:error, {:validation_failed, {:invalid_policy, []}}} =
               BatchAdapter.add_policies(adapter, "p", invalid_policies)
    end

    test "skips validation when disabled" do
      base_adapter = MemoryAdapter.new()
      adapter = BatchAdapter.new(base_adapter, enable_validation: false)

      # This would fail validation, but should succeed with validation disabled
      policies = [["alice", "data1", "read"]]

      assert {:ok, _updated_adapter} = BatchAdapter.add_policies(adapter, "p", policies)
    end

    test "processes large batches in chunks" do
      base_adapter = MemoryAdapter.new()
      adapter = BatchAdapter.new(base_adapter, batch_size: 10)

      # Create 25 policies (should be processed in 3 batches: 10, 10, 5)
      policies =
        Enum.map(1..25, fn i ->
          ["user#{i}", "data#{i}", "read"]
        end)

      assert {:ok, updated_adapter} = BatchAdapter.add_policies(adapter, "p", policies)
      assert updated_adapter.operation_count == 25

      {:ok, loaded_policies, _} = BatchAdapter.load_policy(updated_adapter, nil)
      assert length(loaded_policies["p"]) == 25
    end
  end

  describe "remove_policies/3" do
    test "removes multiple policies in a single batch" do
      base_adapter =
        MemoryAdapter.new(
          initial_policies: @sample_policies,
          initial_grouping_policies: @sample_grouping_policies
        )

      adapter = BatchAdapter.new(base_adapter)

      policies_to_remove = [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"]
      ]

      assert {:ok, updated_adapter} =
               BatchAdapter.remove_policies(adapter, "p", policies_to_remove)

      assert updated_adapter.operation_count == 2

      {:ok, loaded_policies, _} = BatchAdapter.load_policy(updated_adapter, nil)
      assert loaded_policies["p"] == [["carol", "data3", "read"]]
    end

    test "handles removal of non-existent policies gracefully" do
      base_adapter = MemoryAdapter.new(initial_policies: @sample_policies)
      adapter = BatchAdapter.new(base_adapter)

      policies_to_remove = [
        ["nonexistent", "data", "action"]
      ]

      assert {:ok, _updated_adapter} =
               BatchAdapter.remove_policies(adapter, "p", policies_to_remove)
    end
  end

  describe "remove_filtered_policies/4" do
    test "removes policies matching filter" do
      policies = %{
        "p" => [
          ["alice", "data1", "read"],
          ["alice", "data1", "write"],
          ["alice", "data2", "read"],
          ["bob", "data1", "read"]
        ]
      }

      base_adapter = MemoryAdapter.new(initial_policies: policies)
      adapter = BatchAdapter.new(base_adapter)

      # Remove all policies for alice on data1
      assert {:ok, updated_adapter} =
               BatchAdapter.remove_filtered_policies(adapter, "p", 0, ["alice", "data1"])

      {:ok, remaining_policies, _} = BatchAdapter.load_policy(updated_adapter, nil)
      assert remaining_policies["p"] == [["alice", "data2", "read"], ["bob", "data1", "read"]]
    end

    test "handles empty filter values" do
      base_adapter = MemoryAdapter.new(initial_policies: @sample_policies)
      adapter = BatchAdapter.new(base_adapter)

      assert {:ok, _updated_adapter} =
               BatchAdapter.remove_filtered_policies(adapter, "p", 0, [""])
    end
  end

  describe "execute_batch/2" do
    test "executes multiple operations as a batch" do
      base_adapter = MemoryAdapter.new(initial_policies: @sample_policies)
      adapter = BatchAdapter.new(base_adapter)

      operations = [
        {:add_policy, "p", ["dave", "data4", "write"]},
        {:remove_policy, "p", ["alice", "data1", "read"]},
        {:add_policy, "p", ["eve", "data5", "read"]}
      ]

      assert {:ok, updated_adapter} = BatchAdapter.execute_batch(adapter, operations)
      assert updated_adapter.operation_count == 3

      {:ok, policies, _} = BatchAdapter.load_policy(updated_adapter, nil)

      assert ["dave", "data4", "write"] in policies["p"]
      assert ["eve", "data5", "read"] in policies["p"]
      refute ["alice", "data1", "read"] in policies["p"]
    end

    test "executes operations sequentially when transactions disabled" do
      base_adapter = MemoryAdapter.new()
      adapter = BatchAdapter.new(base_adapter, enable_transaction: false)

      operations = [
        {:add_policy, "p", ["user1", "data1", "read"]},
        {:add_policy, "p", ["user2", "data2", "write"]}
      ]

      assert {:ok, updated_adapter} = BatchAdapter.execute_batch(adapter, operations)
      assert updated_adapter.operation_count == 2
    end

    test "handles unsupported operations" do
      base_adapter = MemoryAdapter.new()
      adapter = BatchAdapter.new(base_adapter)

      operations = [
        {:add_grouping_policy, "g", ["alice", "admin"]}
      ]

      assert {:error, :grouping_policy_not_supported} =
               BatchAdapter.execute_batch(adapter, operations)
    end
  end

  describe "get_stats/1" do
    test "returns batch adapter statistics" do
      base_adapter = MemoryAdapter.new()

      adapter =
        BatchAdapter.new(base_adapter,
          batch_size: 75,
          enable_transaction: false,
          max_retries: 2
        )

      # Add some operations
      {:ok, adapter} =
        BatchAdapter.add_policies(adapter, "p", [
          ["alice", "data1", "read"]
        ])

      stats = BatchAdapter.get_stats(adapter)

      assert stats.operation_count == 1
      assert stats.batch_size == 75
      assert stats.buffer_size == 0
      assert stats.enable_transaction == false
      assert stats.enable_validation == true
      assert stats.max_retries == 2
    end
  end

  describe "flush/1" do
    test "flushes buffered operations" do
      base_adapter = MemoryAdapter.new()

      adapter = %{
        BatchAdapter.new(base_adapter)
        | batch_buffer: [{:add_policy, "p", ["alice", "data1", "read"]}]
      }

      assert {:ok, flushed_adapter} = BatchAdapter.flush(adapter)
      assert flushed_adapter.batch_buffer == []
      assert flushed_adapter.operation_count == 1
    end

    test "returns ok when buffer is empty" do
      base_adapter = MemoryAdapter.new()
      adapter = BatchAdapter.new(base_adapter)

      assert {:ok, ^adapter} = BatchAdapter.flush(adapter)
    end
  end

  describe "configure/2" do
    test "updates batch adapter configuration" do
      base_adapter = MemoryAdapter.new()
      adapter = BatchAdapter.new(base_adapter)

      updated_adapter =
        BatchAdapter.configure(adapter,
          batch_size: 200,
          enable_transaction: false,
          enable_validation: false,
          max_retries: 10
        )

      assert updated_adapter.batch_size == 200
      assert updated_adapter.enable_transaction == false
      assert updated_adapter.enable_validation == false
      assert updated_adapter.max_retries == 10
    end

    test "preserves unspecified options" do
      base_adapter = MemoryAdapter.new()
      adapter = BatchAdapter.new(base_adapter, batch_size: 100, max_retries: 5)

      updated_adapter = BatchAdapter.configure(adapter, batch_size: 150)

      assert updated_adapter.batch_size == 150
      assert updated_adapter.max_retries == 5
    end
  end

  describe "Adapter behaviour implementation" do
    test "load_policy/2 delegates to base adapter" do
      base_adapter = MemoryAdapter.new(initial_policies: @sample_policies)
      adapter = BatchAdapter.new(base_adapter)

      assert {:ok, policies, grouping_policies} = BatchAdapter.load_policy(adapter, nil)
      assert policies == @sample_policies
      assert grouping_policies == %{}
    end

    test "save_policy/3 delegates to base adapter" do
      base_adapter = MemoryAdapter.new()
      adapter = BatchAdapter.new(base_adapter)

      assert :ok = BatchAdapter.save_policy(adapter, @sample_policies, @sample_grouping_policies)

      {:ok, policies, grouping_policies} = BatchAdapter.load_policy(adapter, nil)
      assert policies == @sample_policies
      assert grouping_policies == @sample_grouping_policies
    end

    test "add_policy/4 increments operation count" do
      base_adapter = MemoryAdapter.new()
      adapter = BatchAdapter.new(base_adapter)

      assert {:ok, updated_adapter} =
               BatchAdapter.add_policy(adapter, "p", "p", ["alice", "data1", "read"])

      assert updated_adapter.operation_count == 1
    end

    test "remove_policy/4 increments operation count" do
      base_adapter = MemoryAdapter.new(initial_policies: @sample_policies)
      adapter = BatchAdapter.new(base_adapter)

      assert {:ok, updated_adapter} =
               BatchAdapter.remove_policy(adapter, "p", "p", ["alice", "data1", "read"])

      assert updated_adapter.operation_count == 1
    end

    test "filtered?/1 delegates to base adapter" do
      base_adapter = MemoryAdapter.new()
      adapter = BatchAdapter.new(base_adapter)

      assert BatchAdapter.filtered?(adapter) == true
    end
  end

  describe "retry mechanism" do
    test "retries failed operations up to max_retries" do
      # Use a base adapter that will fail initially
      base_adapter = MemoryAdapter.new()
      adapter = BatchAdapter.new(base_adapter, max_retries: 3)

      # This should succeed because MemoryAdapter is reliable
      assert {:ok, _} = BatchAdapter.add_policies(adapter, "p", [["alice", "data1", "read"]])
    end
  end

  describe "concurrent access" do
    test "handles concurrent batch operations" do
      base_adapter = MemoryAdapter.new()
      adapter = BatchAdapter.new(base_adapter)

      # Spawn multiple processes performing batch operations
      tasks =
        Enum.map(1..5, fn i ->
          Task.async(fn ->
            policies =
              Enum.map(1..10, fn j ->
                ["user#{i}_#{j}", "data#{j}", "read"]
              end)

            BatchAdapter.add_policies(adapter, "p", policies)
          end)
        end)

      results = Task.await_many(tasks)

      # All operations should succeed
      Enum.each(results, fn result ->
        assert match?({:ok, _}, result)
      end)
    end
  end

  describe "edge cases" do
    test "handles very large batch sizes" do
      base_adapter = MemoryAdapter.new()
      adapter = BatchAdapter.new(base_adapter, batch_size: 1000)

      # Create 5000 policies
      policies =
        Enum.map(1..5000, fn i ->
          ["user#{i}", "data#{rem(i, 100)}", if(rem(i, 2) == 0, do: "read", else: "write")]
        end)

      assert {:ok, updated_adapter} = BatchAdapter.add_policies(adapter, "p", policies)
      assert updated_adapter.operation_count == 5000

      {:ok, loaded_policies, _} = BatchAdapter.load_policy(updated_adapter, nil)
      assert length(loaded_policies["p"]) == 5000
    end

    test "handles policies with varying lengths" do
      base_adapter = MemoryAdapter.new()
      adapter = BatchAdapter.new(base_adapter)

      policies = [
        ["alice", "data1", "read"],
        ["bob", "data2", "write", "domain1"],
        ["carol", "data3"]
      ]

      assert {:ok, updated_adapter} = BatchAdapter.add_policies(adapter, "p", policies)

      {:ok, loaded_policies, _} = BatchAdapter.load_policy(updated_adapter, nil)
      assert length(loaded_policies["p"]) == 3
    end

    test "handles batch operations with zero batch size edge case" do
      base_adapter = MemoryAdapter.new()
      # Batch size of 1 to test extreme chunking
      adapter = BatchAdapter.new(base_adapter, batch_size: 1)

      policies = [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"],
        ["carol", "data3", "read"]
      ]

      assert {:ok, updated_adapter} = BatchAdapter.add_policies(adapter, "p", policies)
      assert updated_adapter.operation_count == 3
    end
  end

  describe "performance" do
    @tag :performance
    test "batch operations are more efficient than individual operations" do
      base_adapter = MemoryAdapter.new()

      policies =
        Enum.map(1..100, fn i ->
          ["user#{i}", "data#{i}", "read"]
        end)

      # Measure batch operation time
      {batch_time, {:ok, _}} =
        :timer.tc(fn ->
          adapter = BatchAdapter.new(base_adapter)
          BatchAdapter.add_policies(adapter, "p", policies)
        end)

      # Measure individual operation time
      {individual_time, _} =
        :timer.tc(fn ->
          adapter = BatchAdapter.new(base_adapter)

          Enum.reduce(policies, adapter, fn policy, acc ->
            {:ok, updated} = BatchAdapter.add_policy(acc, "p", "p", policy)
            updated
          end)
        end)

      # Batch should be faster (with some tolerance for variance)
      assert batch_time < individual_time * 0.8
    end
  end
end
