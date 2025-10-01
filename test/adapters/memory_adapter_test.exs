defmodule CasbinEx2.Adapter.MemoryAdapterTest do
  use ExUnit.Case, async: false

  alias CasbinEx2.Adapter.{FileAdapter, MemoryAdapter}

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

  describe "new/1" do
    test "creates adapter with default options" do
      adapter = MemoryAdapter.new()

      assert is_atom(adapter.table_name)
      assert adapter.notifications == false
      assert adapter.versioning == false
      assert adapter.version == 0
      assert adapter.subscribers == []
    end

    test "creates adapter with custom options" do
      adapter =
        MemoryAdapter.new(
          table_name: :custom_table,
          notifications: true,
          versioning: true
        )

      assert adapter.table_name == :custom_table
      assert adapter.notifications == true
      assert adapter.versioning == true
    end

    test "creates adapter with initial policies" do
      adapter =
        MemoryAdapter.new(
          initial_policies: @sample_policies,
          initial_grouping_policies: @sample_grouping_policies
        )

      {:ok, policies, grouping_policies} = MemoryAdapter.load_policy(adapter, nil)
      assert policies == @sample_policies
      assert grouping_policies == @sample_grouping_policies
    end
  end

  describe "from_adapter/3" do
    test "creates memory adapter from file adapter" do
      # Create a temporary file with policies
      temp_file = "/tmp/test_policies_#{:rand.uniform(10000)}.csv"
      File.write!(temp_file, "p, alice, data1, read\ng, alice, admin")

      file_adapter = FileAdapter.new(temp_file)

      {:ok, model} =
        CasbinEx2.Model.load_model_from_text("""
        [request_definition]
        r = sub, obj, act

        [policy_definition]
        p = sub, obj, act

        [role_definition]
        g = _, _

        [policy_effect]
        e = some(where (p.eft == allow))

        [matchers]
        m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act
        """)

      assert {:ok, memory_adapter} = MemoryAdapter.from_adapter(file_adapter, model)

      {:ok, policies, grouping_policies} = MemoryAdapter.load_policy(memory_adapter, model)
      assert policies["p"] == [["alice", "data1", "read"]]
      assert grouping_policies["g"] == [["alice", "admin"]]

      # Cleanup
      File.rm!(temp_file)
    end
  end

  describe "save_policy/3 and load_policy/2" do
    test "saves and loads policies correctly" do
      adapter = MemoryAdapter.new()

      assert :ok = MemoryAdapter.save_policy(adapter, @sample_policies, @sample_grouping_policies)

      {:ok, policies, grouping_policies} = MemoryAdapter.load_policy(adapter, nil)
      assert policies == @sample_policies
      assert grouping_policies == @sample_grouping_policies
    end

    test "overwrites existing policies" do
      adapter = MemoryAdapter.new(initial_policies: @sample_policies)

      new_policies = %{"p" => [["new_user", "new_data", "read"]]}
      assert :ok = MemoryAdapter.save_policy(adapter, new_policies, %{})

      {:ok, policies, grouping_policies} = MemoryAdapter.load_policy(adapter, nil)
      assert policies == new_policies
      assert grouping_policies == %{}
    end
  end

  describe "add_policy/4" do
    test "adds new policy rule" do
      adapter = MemoryAdapter.new(initial_policies: @sample_policies)

      assert :ok = MemoryAdapter.add_policy(adapter, "p", "p", ["dave", "data4", "write"])

      {:ok, policies, _} = MemoryAdapter.load_policy(adapter, nil)
      assert ["dave", "data4", "write"] in policies["p"]
    end

    test "adds to existing policy type" do
      adapter = MemoryAdapter.new()

      assert :ok = MemoryAdapter.add_policy(adapter, "p", "p", ["user1", "data1", "read"])
      assert :ok = MemoryAdapter.add_policy(adapter, "p", "p", ["user2", "data2", "write"])

      {:ok, policies, _} = MemoryAdapter.load_policy(adapter, nil)
      assert length(policies["p"]) == 2
      assert ["user1", "data1", "read"] in policies["p"]
      assert ["user2", "data2", "write"] in policies["p"]
    end
  end

  describe "remove_policy/4" do
    test "removes existing policy rule" do
      adapter = MemoryAdapter.new(initial_policies: @sample_policies)

      assert :ok = MemoryAdapter.remove_policy(adapter, "p", "p", ["alice", "data1", "read"])

      {:ok, policies, _} = MemoryAdapter.load_policy(adapter, nil)
      refute ["alice", "data1", "read"] in policies["p"]
      assert ["bob", "data2", "write"] in policies["p"]
    end

    test "handles non-existent policy rule gracefully" do
      adapter = MemoryAdapter.new(initial_policies: @sample_policies)

      assert :ok =
               MemoryAdapter.remove_policy(adapter, "p", "p", ["nonexistent", "data", "action"])

      {:ok, policies, _} = MemoryAdapter.load_policy(adapter, nil)
      assert policies == @sample_policies
    end
  end

  describe "remove_filtered_policy/5" do
    test "removes policies matching filter" do
      policies = %{
        "p" => [
          ["alice", "data1", "read"],
          ["alice", "data1", "write"],
          ["alice", "data2", "read"],
          ["bob", "data1", "read"]
        ]
      }

      adapter = MemoryAdapter.new(initial_policies: policies)

      # Remove all policies for alice on data1
      assert :ok = MemoryAdapter.remove_filtered_policy(adapter, "p", "p", 0, ["alice", "data1"])

      {:ok, remaining_policies, _} = MemoryAdapter.load_policy(adapter, nil)
      assert remaining_policies["p"] == [["alice", "data2", "read"], ["bob", "data1", "read"]]
    end

    test "removes policies matching partial filter" do
      policies = %{
        "p" => [
          ["alice", "data1", "read"],
          ["alice", "data2", "read"],
          ["bob", "data1", "write"]
        ]
      }

      adapter = MemoryAdapter.new(initial_policies: policies)

      # Remove all read actions
      assert :ok = MemoryAdapter.remove_filtered_policy(adapter, "p", "p", 2, ["read"])

      {:ok, remaining_policies, _} = MemoryAdapter.load_policy(adapter, nil)
      assert remaining_policies["p"] == [["bob", "data1", "write"]]
    end
  end

  describe "load_filtered_policy/3" do
    test "loads policies with function filter" do
      adapter = MemoryAdapter.new(initial_policies: @sample_policies)

      filter = fn _policy_type, rule ->
        Enum.at(rule, 0) == "alice"
      end

      {:ok, filtered_policies, _} = MemoryAdapter.load_filtered_policy(adapter, nil, filter)
      assert filtered_policies["p"] == [["alice", "data1", "read"]]
    end

    test "returns all policies when filter is nil" do
      adapter = MemoryAdapter.new(initial_policies: @sample_policies)

      {:ok, policies, _} = MemoryAdapter.load_filtered_policy(adapter, nil, nil)
      assert policies == @sample_policies
    end
  end

  describe "filtered?/1" do
    test "returns true for memory adapter" do
      adapter = MemoryAdapter.new()
      assert MemoryAdapter.filtered?(adapter) == true
    end
  end

  describe "versioning" do
    test "increments version when versioning is enabled" do
      adapter = MemoryAdapter.new(versioning: true)
      assert MemoryAdapter.get_version(adapter) == 0

      MemoryAdapter.save_policy(adapter, @sample_policies, %{})
      updated_adapter = Process.get(:memory_adapter_state, adapter)
      assert MemoryAdapter.get_version(updated_adapter) == 1
    end

    test "does not track version when versioning is disabled" do
      adapter = MemoryAdapter.new(versioning: false)
      assert MemoryAdapter.get_version(adapter) == nil

      MemoryAdapter.save_policy(adapter, @sample_policies, %{})
      updated_adapter = Process.get(:memory_adapter_state, adapter)
      assert MemoryAdapter.get_version(updated_adapter) == nil
    end
  end

  describe "notifications" do
    test "subscribes to notifications when enabled" do
      adapter = MemoryAdapter.new(notifications: true)
      updated_adapter = MemoryAdapter.subscribe(adapter)

      assert self() in updated_adapter.subscribers
    end

    test "raises error when notifications are disabled" do
      adapter = MemoryAdapter.new(notifications: false)

      assert_raise RuntimeError, "Notifications not enabled", fn ->
        MemoryAdapter.subscribe(adapter)
      end
    end

    test "unsubscribes from notifications" do
      adapter = MemoryAdapter.new(notifications: true)
      subscribed_adapter = MemoryAdapter.subscribe(adapter)
      unsubscribed_adapter = MemoryAdapter.unsubscribe(subscribed_adapter)

      refute self() in unsubscribed_adapter.subscribers
    end
  end

  describe "get_memory_stats/1" do
    test "returns memory usage statistics" do
      adapter =
        MemoryAdapter.new(
          initial_policies: @sample_policies,
          initial_grouping_policies: @sample_grouping_policies
        )

      stats = MemoryAdapter.get_memory_stats(adapter)

      assert is_integer(stats.table_size)
      assert is_integer(stats.memory_bytes)
      assert stats.policy_count == 3
      assert stats.grouping_policy_count == 2
    end
  end

  describe "clear/1" do
    test "clears all policies" do
      adapter = MemoryAdapter.new(initial_policies: @sample_policies, versioning: true)

      cleared_adapter = MemoryAdapter.clear(adapter)

      {:ok, policies, grouping_policies} = MemoryAdapter.load_policy(cleared_adapter, nil)
      assert policies == %{}
      assert grouping_policies == %{}
      assert cleared_adapter.version == 1
    end
  end

  describe "concurrent access" do
    test "handles concurrent reads safely" do
      adapter = MemoryAdapter.new(initial_policies: @sample_policies)

      # Spawn multiple processes reading concurrently
      tasks =
        Enum.map(1..10, fn _ ->
          Task.async(fn ->
            {:ok, policies, _} = MemoryAdapter.load_policy(adapter, nil)
            policies
          end)
        end)

      results = Task.await_many(tasks)

      # All results should be identical
      Enum.each(results, fn policies ->
        assert policies == @sample_policies
      end)
    end

    test "handles concurrent writes safely" do
      adapter = MemoryAdapter.new()

      # Spawn multiple processes writing concurrently
      tasks =
        Enum.map(1..10, fn i ->
          Task.async(fn ->
            MemoryAdapter.add_policy(adapter, "p", "p", ["user#{i}", "data#{i}", "read"])
          end)
        end)

      results = Task.await_many(tasks)

      # All writes should succeed
      Enum.each(results, fn result ->
        assert result == :ok
      end)

      {:ok, policies, _} = MemoryAdapter.load_policy(adapter, nil)
      assert length(policies["p"]) == 10
    end
  end

  describe "edge cases" do
    test "handles empty policies" do
      adapter = MemoryAdapter.new()

      assert :ok = MemoryAdapter.save_policy(adapter, %{}, %{})

      {:ok, policies, grouping_policies} = MemoryAdapter.load_policy(adapter, nil)
      assert policies == %{}
      assert grouping_policies == %{}
    end

    test "handles policies with empty rule lists" do
      adapter = MemoryAdapter.new()

      assert :ok = MemoryAdapter.save_policy(adapter, %{"p" => []}, %{"g" => []})

      {:ok, policies, grouping_policies} = MemoryAdapter.load_policy(adapter, nil)
      assert policies == %{"p" => []}
      assert grouping_policies == %{"g" => []}
    end

    test "handles large number of policies" do
      large_policies = %{
        "p" =>
          Enum.map(1..1000, fn i ->
            ["user#{i}", "data#{rem(i, 10)}", if(rem(i, 2) == 0, do: "read", else: "write")]
          end)
      }

      adapter = MemoryAdapter.new()
      assert :ok = MemoryAdapter.save_policy(adapter, large_policies, %{})

      {:ok, policies, _} = MemoryAdapter.load_policy(adapter, nil)
      assert length(policies["p"]) == 1000
    end
  end
end
