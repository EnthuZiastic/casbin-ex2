defmodule CasbinEx2.CachedEnforcerTest do
  use ExUnit.Case

  alias CasbinEx2.Adapter.FileAdapter
  alias CasbinEx2.CachedEnforcer

  @moduletag :unit

  setup do
    # Create a unique test instance name for each test to avoid conflicts
    test_name = :"test_cached_enforcer_#{:erlang.unique_integer([:positive])}"

    # Create temporary model file
    model_content = """
    [request_definition]
    r = sub, obj, act

    [policy_definition]
    p = sub, obj, act

    [role_definition]
    g = _, _, _

    [policy_effect]
    e = some(where (p.eft == allow))

    [matchers]
    m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
    """

    test_id = :erlang.unique_integer([:positive])
    model_path = "/tmp/cached_test_model_#{test_id}.conf"
    policy_path = "/tmp/cached_test_policy_#{test_id}.csv"

    File.write!(model_path, model_content)

    # Create policy file with test data
    policy_content = """
    p, alice, data1, read
    p, bob, data2, write
    p, charlie, data3, read
    g, alice, admin
    """

    File.write!(policy_path, policy_content)

    adapter = FileAdapter.new(policy_path)

    opts = [
      adapter: adapter,
      cache_size: 100,
      enable_cache: true
    ]

    {:ok, _pid} = CachedEnforcer.start_link(test_name, model_path, opts)

    on_exit(fn ->
      # Cleanup files
      File.rm(model_path)
      File.rm(policy_path)

      # Stop the server if it's still running
      try do
        GenServer.stop({:via, Registry, {CasbinEx2.EnforcerRegistry, :"cached_#{test_name}"}})
      catch
        :exit, _ -> :ok
      end
    end)

    {:ok, name: test_name, model_path: model_path, policy_path: policy_path}
  end

  describe "cached enforcement" do
    test "enforces policies with caching enabled", %{name: name} do
      # First call should be a cache miss
      assert CachedEnforcer.enforce(name, ["alice", "data1", "read"]) == true
      assert CachedEnforcer.enforce(name, ["bob", "data2", "write"]) == true
      assert CachedEnforcer.enforce(name, ["charlie", "data1", "read"]) == false

      # Second call should be a cache hit
      assert CachedEnforcer.enforce(name, ["alice", "data1", "read"]) == true
      assert CachedEnforcer.enforce(name, ["bob", "data2", "write"]) == true
      assert CachedEnforcer.enforce(name, ["charlie", "data1", "read"]) == false
    end

    test "cache statistics are accurate", %{name: name} do
      # Make some enforcement calls
      CachedEnforcer.enforce(name, ["alice", "data1", "read"])
      CachedEnforcer.enforce(name, ["bob", "data2", "write"])
      # Cache hit
      CachedEnforcer.enforce(name, ["alice", "data1", "read"])

      stats = CachedEnforcer.get_cache_stats(name)
      assert stats.cache_enabled == true
      assert stats.max_cache_size == 100
      # Two unique requests cached
      assert stats.cache_size == 2
    end

    test "cache can be disabled and enabled", %{name: name} do
      # Enable cache and make a call
      assert :ok = CachedEnforcer.enable_cache(name, true)
      assert CachedEnforcer.enforce(name, ["alice", "data1", "read"]) == true

      stats = CachedEnforcer.get_cache_stats(name)
      assert stats.cache_enabled == true
      assert stats.cache_size == 1

      # Disable cache
      assert :ok = CachedEnforcer.enable_cache(name, false)
      stats = CachedEnforcer.get_cache_stats(name)
      assert stats.cache_enabled == false
      # Cache should be cleared when disabled
      assert stats.cache_size == 0

      # Enforcement should still work
      assert CachedEnforcer.enforce(name, ["bob", "data2", "write"]) == true
    end

    test "cache size can be adjusted", %{name: name} do
      # Set smaller cache size
      assert :ok = CachedEnforcer.set_cache_size(name, 2)

      # Make more calls than cache size
      CachedEnforcer.enforce(name, ["alice", "data1", "read"])
      CachedEnforcer.enforce(name, ["bob", "data2", "write"])
      CachedEnforcer.enforce(name, ["charlie", "data3", "read"])

      stats = CachedEnforcer.get_cache_stats(name)
      assert stats.max_cache_size == 2
      # Should not exceed cache size
      assert stats.cache_size <= 2
    end
  end

  describe "cache invalidation" do
    test "cache is invalidated when policies are added", %{name: name} do
      # Make enforcement call and cache result
      assert CachedEnforcer.enforce(name, ["david", "data4", "read"]) == false

      stats = CachedEnforcer.get_cache_stats(name)
      assert stats.cache_size == 1

      # Add a policy that affects the request
      CachedEnforcer.add_policy(name, ["david", "data4", "read"])

      # Cache should be invalidated
      stats = CachedEnforcer.get_cache_stats(name)
      assert stats.cache_size == 0

      # New enforcement should return true
      assert CachedEnforcer.enforce(name, ["david", "data4", "read"]) == true
    end

    test "cache is invalidated when policies are removed", %{name: name} do
      # Make enforcement call that should succeed
      assert CachedEnforcer.enforce(name, ["alice", "data1", "read"]) == true

      stats = CachedEnforcer.get_cache_stats(name)
      assert stats.cache_size == 1

      # Remove the policy
      CachedEnforcer.remove_policy(name, ["alice", "data1", "read"])

      # Cache should be invalidated
      stats = CachedEnforcer.get_cache_stats(name)
      assert stats.cache_size == 0

      # New enforcement should return false
      assert CachedEnforcer.enforce(name, ["alice", "data1", "read"]) == false
    end

    test "cache is invalidated when grouping policies are modified", %{name: name} do
      # Make enforcement call and cache result
      assert CachedEnforcer.enforce(name, ["eve", "admin_data", "read"]) == false

      stats = CachedEnforcer.get_cache_stats(name)
      assert stats.cache_size == 1

      # Add grouping policy
      CachedEnforcer.add_grouping_policy(name, ["eve", "admin"])

      # Cache should be invalidated
      stats = CachedEnforcer.get_cache_stats(name)
      assert stats.cache_size == 0
    end

    test "manual cache invalidation works", %{name: name} do
      # Make some enforcement calls
      CachedEnforcer.enforce(name, ["alice", "data1", "read"])
      CachedEnforcer.enforce(name, ["bob", "data2", "write"])

      stats = CachedEnforcer.get_cache_stats(name)
      assert stats.cache_size == 2

      # Manually invalidate cache
      assert :ok = CachedEnforcer.invalidate_cache(name)

      stats = CachedEnforcer.get_cache_stats(name)
      assert stats.cache_size == 0
    end

    test "cache invalidation on policy reload", %{name: name} do
      # Make enforcement call and cache result
      CachedEnforcer.enforce(name, ["alice", "data1", "read"])

      stats = CachedEnforcer.get_cache_stats(name)
      assert stats.cache_size == 1

      # Reload policies
      CachedEnforcer.load_policy(name)

      # Cache should be invalidated
      stats = CachedEnforcer.get_cache_stats(name)
      assert stats.cache_size == 0
    end
  end

  describe "policy delegation" do
    test "can retrieve policies without affecting cache", %{name: name} do
      # Make enforcement call to populate cache
      CachedEnforcer.enforce(name, ["alice", "data1", "read"])

      stats_before = CachedEnforcer.get_cache_stats(name)

      # Get policies (read-only operation)
      policies = CachedEnforcer.get_policy(name)
      assert is_list(policies)
      assert ["alice", "data1", "read"] in policies

      # Cache should not be affected
      stats_after = CachedEnforcer.get_cache_stats(name)
      assert stats_after.cache_size == stats_before.cache_size
    end

    test "can retrieve grouping policies without affecting cache", %{name: name} do
      # Make enforcement call to populate cache
      CachedEnforcer.enforce(name, ["alice", "data1", "read"])

      stats_before = CachedEnforcer.get_cache_stats(name)

      # Get grouping policies (read-only operation)
      grouping_policies = CachedEnforcer.get_grouping_policy(name)
      assert is_list(grouping_policies)
      assert ["alice", "admin"] in grouping_policies

      # Cache should not be affected
      stats_after = CachedEnforcer.get_cache_stats(name)
      assert stats_after.cache_size == stats_before.cache_size
    end

    test "can check policy existence without affecting cache", %{name: name} do
      # Make enforcement call to populate cache
      CachedEnforcer.enforce(name, ["alice", "data1", "read"])

      stats_before = CachedEnforcer.get_cache_stats(name)

      # Check policy existence (read-only operation)
      assert CachedEnforcer.has_policy(name, ["alice", "data1", "read"]) == true
      assert CachedEnforcer.has_policy(name, ["nonexistent", "policy", "rule"]) == false

      # Cache should not be affected
      stats_after = CachedEnforcer.get_cache_stats(name)
      assert stats_after.cache_size == stats_before.cache_size
    end
  end

  describe "cache performance" do
    test "large number of requests are handled efficiently", %{name: name} do
      # Set a reasonable cache size
      CachedEnforcer.set_cache_size(name, 50)

      # Make many enforcement calls with some repeated requests
      requests = [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"],
        ["charlie", "data3", "read"],
        # Duplicate
        ["alice", "data1", "read"],
        # Duplicate
        ["bob", "data2", "write"],
        ["david", "data4", "delete"],
        ["eve", "data5", "update"],
        # Duplicate again
        ["alice", "data1", "read"]
      ]

      # All requests should complete successfully
      results =
        Enum.map(requests, fn request ->
          CachedEnforcer.enforce(name, request)
        end)

      assert length(results) == length(requests)

      # Cache should contain unique requests only
      stats = CachedEnforcer.get_cache_stats(name)
      unique_requests = Enum.uniq(requests) |> length()
      assert stats.cache_size == unique_requests
    end

    test "cache behaves correctly under concurrent access", %{name: name} do
      # Test concurrent access to the cache
      request = ["alice", "data1", "read"]

      # Spawn multiple processes making the same request
      tasks =
        for _i <- 1..10 do
          Task.async(fn ->
            CachedEnforcer.enforce(name, request)
          end)
        end

      # All should get the same result
      results = Task.await_many(tasks)
      assert Enum.all?(results, &(&1 == true))

      # Only one cache entry should exist
      stats = CachedEnforcer.get_cache_stats(name)
      assert stats.cache_size == 1
    end
  end

  describe "error handling" do
    test "cached enforcer handles enforcement errors gracefully", %{name: name} do
      # Test with malformed request (this should not crash the server)
      result = CachedEnforcer.enforce(name, ["invalid"])
      assert is_boolean(result)

      # Server should still be responsive
      assert CachedEnforcer.enforce(name, ["alice", "data1", "read"]) == true
    end

    test "cache operations work when cache is disabled", %{name: name} do
      # Disable cache
      CachedEnforcer.enable_cache(name, false)

      # These operations should still work
      assert is_map(CachedEnforcer.get_cache_stats(name))
      assert :ok = CachedEnforcer.invalidate_cache(name)
      assert :ok = CachedEnforcer.set_cache_size(name, 200)

      # Enforcement should still work
      assert CachedEnforcer.enforce(name, ["alice", "data1", "read"]) == true
    end
  end
end
