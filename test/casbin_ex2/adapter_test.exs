defmodule CasbinEx2.AdapterTest do
  use ExUnit.Case, async: true

  alias CasbinEx2.Adapter
  alias CasbinEx2.Adapter.{BatchAdapter, FileAdapter, MemoryAdapter, StringAdapter}

  @sample_policies %{
    "p" => [
      ["alice", "data1", "read"],
      ["bob", "data2", "write"]
    ]
  }

  @sample_grouping_policies %{
    "g" => [
      ["alice", "admin"]
    ]
  }

  describe "protocol dispatch with MemoryAdapter" do
    setup do
      adapter =
        MemoryAdapter.new(
          initial_policies: @sample_policies,
          initial_grouping_policies: @sample_grouping_policies
        )

      model = %{}

      {:ok, adapter: adapter, model: model}
    end

    test "load_policy/2 dispatches to MemoryAdapter implementation", %{
      adapter: adapter,
      model: model
    } do
      assert {:ok, policies, grouping_policies} = Adapter.load_policy(adapter, model)
      assert policies == @sample_policies
      assert grouping_policies == @sample_grouping_policies
    end

    test "filtered?/1 dispatches to MemoryAdapter implementation", %{adapter: adapter} do
      assert Adapter.filtered?(adapter) == true
    end

    test "save_policy/3 dispatches to MemoryAdapter implementation", %{adapter: adapter} do
      new_policies = %{"p" => [["carol", "data3", "read"]]}
      new_grouping = %{"g" => [["bob", "user"]]}

      assert :ok = Adapter.save_policy(adapter, new_policies, new_grouping)
    end

    test "add_policy/4 dispatches to MemoryAdapter implementation", %{adapter: adapter} do
      assert :ok = Adapter.add_policy(adapter, "p", "p", ["dave", "data4", "write"])
    end

    test "remove_policy/4 dispatches to MemoryAdapter implementation", %{adapter: adapter} do
      assert :ok = Adapter.remove_policy(adapter, "p", "p", ["alice", "data1", "read"])
    end
  end

  describe "protocol dispatch with FileAdapter" do
    setup do
      # Create a temporary test file
      test_file = "test_policy_#{:rand.uniform(10000)}.csv"
      File.write!(test_file, "p, alice, data1, read\np, bob, data2, write\n")

      adapter = FileAdapter.new(test_file)
      model = %{}

      on_exit(fn ->
        File.rm(test_file)
      end)

      {:ok, adapter: adapter, model: model, test_file: test_file}
    end

    test "load_policy/2 dispatches to FileAdapter implementation", %{
      adapter: adapter,
      model: model
    } do
      assert {:ok, policies, grouping_policies} = Adapter.load_policy(adapter, model)
      assert is_map(policies)
      assert is_map(grouping_policies)
    end

    test "filtered?/1 dispatches to FileAdapter implementation", %{adapter: adapter} do
      result = Adapter.filtered?(adapter)
      assert is_boolean(result)
    end

    test "save_policy/3 dispatches to FileAdapter implementation", %{adapter: adapter} do
      policies = %{"p" => [["carol", "data3", "read"]]}
      grouping = %{"g" => []}

      assert :ok = Adapter.save_policy(adapter, policies, grouping)
    end

    test "add_policy/4 dispatches to FileAdapter implementation", %{adapter: adapter} do
      # FileAdapter returns error for incremental operations
      result = Adapter.add_policy(adapter, "p", "p", ["dave", "data4", "write"])
      assert match?({:error, _}, result)
    end

    test "remove_policy/4 dispatches to FileAdapter implementation", %{adapter: adapter} do
      # FileAdapter returns error for incremental operations
      result = Adapter.remove_policy(adapter, "p", "p", ["alice", "data1", "read"])
      assert match?({:error, _}, result)
    end
  end

  describe "protocol dispatch with StringAdapter" do
    setup do
      policy_string = """
      p, alice, data1, read
      p, bob, data2, write
      g, alice, admin
      """

      adapter = StringAdapter.new(policy_string)
      model = %{}

      {:ok, adapter: adapter, model: model}
    end

    test "load_policy/2 dispatches to StringAdapter implementation", %{
      adapter: adapter,
      model: model
    } do
      assert {:ok, policies, grouping_policies} = Adapter.load_policy(adapter, model)
      assert is_map(policies)
      assert is_map(grouping_policies)
    end

    test "filtered?/1 dispatches to StringAdapter implementation", %{adapter: adapter} do
      result = Adapter.filtered?(adapter)
      assert is_boolean(result)
    end

    test "save_policy/3 dispatches to StringAdapter implementation", %{adapter: adapter} do
      policies = %{"p" => [["carol", "data3", "read"]]}
      grouping = %{"g" => []}

      # StringAdapter supports save operations
      result = Adapter.save_policy(adapter, policies, grouping)
      assert result == :ok
    end

    test "add_policy/4 dispatches to StringAdapter implementation", %{adapter: adapter} do
      # StringAdapter supports incremental operations
      result = Adapter.add_policy(adapter, "p", "p", ["dave", "data4", "write"])
      assert result == :ok
    end

    test "remove_policy/4 dispatches to StringAdapter implementation", %{adapter: adapter} do
      # StringAdapter supports incremental operations
      result = Adapter.remove_policy(adapter, "p", "p", ["alice", "data1", "read"])
      assert result == :ok
    end
  end

  describe "protocol dispatch with BatchAdapter" do
    setup do
      base_adapter =
        MemoryAdapter.new(
          initial_policies: @sample_policies,
          initial_grouping_policies: @sample_grouping_policies
        )

      adapter = BatchAdapter.new(base_adapter, batch_size: 50)
      model = %{}

      {:ok, adapter: adapter, model: model}
    end

    test "load_policy/2 dispatches to BatchAdapter implementation", %{
      adapter: adapter,
      model: model
    } do
      assert {:ok, policies, grouping_policies} = Adapter.load_policy(adapter, model)
      assert policies == @sample_policies
      assert grouping_policies == @sample_grouping_policies
    end

    test "filtered?/1 dispatches to BatchAdapter implementation", %{adapter: adapter} do
      assert Adapter.filtered?(adapter) == true
    end

    test "save_policy/3 dispatches to BatchAdapter implementation", %{adapter: adapter} do
      new_policies = %{"p" => [["carol", "data3", "read"]]}
      new_grouping = %{"g" => [["bob", "user"]]}

      assert :ok = Adapter.save_policy(adapter, new_policies, new_grouping)
    end

    test "add_policy/4 dispatches to BatchAdapter implementation", %{adapter: adapter} do
      assert {:ok, _updated_adapter} =
               Adapter.add_policy(adapter, "p", "p", ["dave", "data4", "write"])
    end

    test "remove_policy/4 dispatches to BatchAdapter implementation", %{adapter: adapter} do
      assert {:ok, _updated_adapter} =
               Adapter.remove_policy(adapter, "p", "p", ["alice", "data1", "read"])
    end
  end

  describe "load_filtered_policy/3 dispatch" do
    test "dispatches to MemoryAdapter with filter" do
      adapter = MemoryAdapter.new(initial_policies: @sample_policies)
      model = %{}
      filter = %{subject: "alice"}

      assert {:ok, _policies, _grouping} =
               Adapter.load_filtered_policy(adapter, model, filter)
    end

    test "dispatches to FileAdapter with filter" do
      test_file = "test_filtered_#{:rand.uniform(10000)}.csv"
      File.write!(test_file, "p, alice, data1, read\n")

      adapter = FileAdapter.new(test_file)
      model = %{}
      filter = %{subject: "alice"}

      result = Adapter.load_filtered_policy(adapter, model, filter)
      assert match?({:ok, _, _}, result) or match?({:error, _}, result)

      File.rm(test_file)
    end

    test "dispatches to StringAdapter with filter" do
      adapter = StringAdapter.new("p, alice, data1, read\n")
      model = %{}
      filter = %{subject: "alice"}

      result = Adapter.load_filtered_policy(adapter, model, filter)
      assert match?({:ok, _, _}, result) or match?({:error, _}, result)
    end

    test "dispatches to BatchAdapter with filter" do
      base_adapter = MemoryAdapter.new(initial_policies: @sample_policies)
      adapter = BatchAdapter.new(base_adapter)
      model = %{}
      filter = %{subject: "alice"}

      assert {:ok, _policies, _grouping} =
               Adapter.load_filtered_policy(adapter, model, filter)
    end
  end

  describe "load_incremental_filtered_policy/3 dispatch" do
    test "dispatches to MemoryAdapter with incremental filter" do
      adapter = MemoryAdapter.new(initial_policies: @sample_policies)
      model = %{}
      filter = %{subject: "alice"}

      assert {:ok, _policies, _grouping} =
               Adapter.load_incremental_filtered_policy(adapter, model, filter)
    end

    test "dispatches to FileAdapter with incremental filter" do
      test_file = "test_incremental_#{:rand.uniform(10000)}.csv"
      File.write!(test_file, "p, alice, data1, read\n")

      adapter = FileAdapter.new(test_file)
      model = %{}
      filter = %{subject: "alice"}

      result = Adapter.load_incremental_filtered_policy(adapter, model, filter)
      assert match?({:ok, _, _}, result) or match?({:error, _}, result)

      File.rm(test_file)
    end

    test "dispatches to StringAdapter with incremental filter" do
      adapter = StringAdapter.new("p, alice, data1, read\n")
      model = %{}
      filter = %{subject: "alice"}

      result = Adapter.load_incremental_filtered_policy(adapter, model, filter)
      assert match?({:ok, _, _}, result) or match?({:error, _}, result)
    end

    test "dispatches to BatchAdapter with incremental filter" do
      base_adapter = MemoryAdapter.new(initial_policies: @sample_policies)
      adapter = BatchAdapter.new(base_adapter)
      model = %{}
      filter = %{subject: "alice"}

      assert {:ok, _policies, _grouping} =
               Adapter.load_incremental_filtered_policy(adapter, model, filter)
    end
  end

  describe "adapter struct access" do
    test "can access __struct__ for MemoryAdapter" do
      adapter = MemoryAdapter.new()
      assert adapter.__struct__ == MemoryAdapter
    end

    test "can access __struct__ for FileAdapter" do
      adapter = FileAdapter.new("test.csv")
      assert adapter.__struct__ == FileAdapter
    end

    test "can access __struct__ for StringAdapter" do
      adapter = StringAdapter.new("")
      assert adapter.__struct__ == StringAdapter
    end

    test "can access __struct__ for BatchAdapter" do
      base_adapter = MemoryAdapter.new()
      adapter = BatchAdapter.new(base_adapter)
      assert adapter.__struct__ == BatchAdapter
    end
  end

  describe "adapter immutability" do
    test "BatchAdapter remains immutable after operations" do
      base_adapter = MemoryAdapter.new(initial_policies: @sample_policies)
      adapter = BatchAdapter.new(base_adapter)
      original_count = adapter.operation_count

      {:ok, updated_adapter} = Adapter.add_policy(adapter, "p", "p", ["new", "data", "read"])

      # Original adapter unchanged
      assert adapter.operation_count == original_count
      # Updated adapter has incremented count
      assert updated_adapter.operation_count == original_count + 1
    end

    test "MemoryAdapter add_policy returns :ok not new adapter" do
      adapter = MemoryAdapter.new(initial_policies: @sample_policies)
      result = Adapter.add_policy(adapter, "p", "p", ["new", "data", "read"])

      # MemoryAdapter returns :ok, not {:ok, updated_adapter}
      assert result == :ok
    end
  end

  describe "error handling" do
    test "StringAdapter handles save_policy operations" do
      adapter = StringAdapter.new("p, alice, data1, read\n")
      policies = %{"p" => [["new_user", "data", "read"]]}
      grouping = %{}

      result = Adapter.save_policy(adapter, policies, grouping)
      # StringAdapter supports save operations
      assert result == :ok
    end

    test "FileAdapter returns empty policies for non-existent file" do
      # FileAdapter with non-existent file returns empty policies, not error
      adapter = FileAdapter.new("/nonexistent/path/policy.csv")
      model = %{}

      result = Adapter.load_policy(adapter, model)
      # FileAdapter returns {:ok, %{}, %{}} for non-existent files
      assert result == {:ok, %{}, %{}}
    end
  end

  describe "adapter polymorphism" do
    test "different adapters can be used interchangeably via protocol" do
      model = %{}

      adapters = [
        MemoryAdapter.new(initial_policies: @sample_policies),
        StringAdapter.new("p, alice, data1, read\n")
      ]

      for adapter <- adapters do
        # All adapters respond to the same protocol methods
        assert {:ok, _policies, _grouping} = Adapter.load_policy(adapter, model)
        assert is_boolean(Adapter.filtered?(adapter))
      end
    end

    test "batch adapter wraps other adapters transparently" do
      model = %{}

      # BatchAdapter can wrap different base adapters
      base_adapters = [
        MemoryAdapter.new(initial_policies: @sample_policies)
      ]

      for base_adapter <- base_adapters do
        adapter = BatchAdapter.new(base_adapter)

        # Protocol works the same way
        assert {:ok, _policies, _grouping} = Adapter.load_policy(adapter, model)
        assert Adapter.filtered?(adapter) == true
      end
    end
  end

  describe "adapter capabilities" do
    test "all adapters implement filtered? callback" do
      adapters = [
        MemoryAdapter.new(),
        FileAdapter.new("test.csv"),
        StringAdapter.new(""),
        BatchAdapter.new(MemoryAdapter.new())
      ]

      for adapter <- adapters do
        result = Adapter.filtered?(adapter)
        assert is_boolean(result), "#{adapter.__struct__} should return boolean for filtered?"
      end
    end

    test "adapters return consistent data structures" do
      model = %{}

      adapters_with_data = [
        MemoryAdapter.new(initial_policies: @sample_policies),
        StringAdapter.new("p, alice, data1, read\n")
      ]

      for adapter <- adapters_with_data do
        assert {:ok, policies, grouping_policies} = Adapter.load_policy(adapter, model)
        assert is_map(policies), "#{adapter.__struct__} should return map for policies"
        assert is_map(grouping_policies), "#{adapter.__struct__} should return map for grouping"
      end
    end
  end
end
