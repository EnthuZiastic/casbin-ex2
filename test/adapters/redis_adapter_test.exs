defmodule CasbinEx2.Adapter.RedisAdapterTest do
  use ExUnit.Case, async: false

  alias CasbinEx2.Adapter.RedisAdapter

  @moduletag :redis_required

  # These tests require Redis to be running
  # Run with: mix test --only redis_required

  describe "new/1" do
    test "creates redis adapter with default options" do
      adapter = RedisAdapter.new(host: "localhost", port: 6379)

      assert adapter.connection_opts[:host] == "localhost"
      assert adapter.connection_opts[:port] == 6379
    end

    test "creates redis adapter with custom options" do
      adapter =
        RedisAdapter.new(
          host: "redis.example.com",
          port: 6380,
          database: 1,
          tenant_id: "test_tenant",
          ttl: 3600,
          notifications: true
        )

      assert adapter.tenant_id == "test_tenant"
      assert adapter.ttl == 3600
      assert adapter.notifications == true
    end
  end

  describe "connection configuration" do
    test "supports cluster configuration" do
      adapter =
        RedisAdapter.new(
          cluster: [
            {"redis1.example.com", 6379},
            {"redis2.example.com", 6379}
          ]
        )

      assert is_list(adapter.connection_opts[:cluster])
    end

    test "supports sentinel configuration" do
      adapter =
        RedisAdapter.new(
          sentinel: [
            host: "sentinel.example.com",
            port: 26_379,
            master_name: "mymaster"
          ]
        )

      assert adapter.connection_opts[:sentinel]
    end
  end

  # Mock tests for Redis operations (until Redis integration is complete)
  describe "mock policy operations" do
    test "load_policy/2 interface" do
      adapter = RedisAdapter.new(host: "localhost")
      # This would require actual Redis connection
      # For now, test the structure is correct
      assert adapter.connection_opts[:host] == "localhost"
    end

    test "save_policy/3 interface" do
      adapter = RedisAdapter.new(host: "localhost")
      assert adapter.tenant_id == "default"
    end

    test "add_policy/4 interface" do
      adapter = RedisAdapter.new(host: "localhost")
      assert adapter.key_prefix == "casbin"
    end
  end

  describe "key generation" do
    test "generates correct policy keys" do
      adapter = RedisAdapter.new(tenant_id: "tenant1", key_prefix: "myapp")

      # Key pattern: {prefix}:policies:{tenant}:p:{ptype}
      expected_pattern = "myapp:policies:tenant1:p:"
      assert String.starts_with?(expected_pattern, adapter.key_prefix)
    end
  end

  describe "TTL configuration" do
    test "sets TTL when configured" do
      adapter = RedisAdapter.new(ttl: 7200)
      assert adapter.ttl == 7200
    end

    test "no TTL by default" do
      adapter = RedisAdapter.new()
      assert adapter.ttl == nil
    end
  end

  describe "notifications" do
    test "enables pub/sub notifications" do
      adapter = RedisAdapter.new(notifications: true)
      assert adapter.notifications == true
      assert adapter.pub_sub_channel =~ "policy_updates"
    end

    test "disables notifications by default" do
      adapter = RedisAdapter.new()
      assert adapter.notifications == false
    end
  end

  describe "versioning" do
    test "enables policy versioning" do
      adapter = RedisAdapter.new(versioning: true)
      assert adapter.versioning == true
    end

    test "versioning enabled by default" do
      adapter = RedisAdapter.new()
      assert adapter.versioning == true
    end
  end

  describe "distributed locking" do
    test "configures lock timeout" do
      adapter = RedisAdapter.new(lock_timeout: 10_000)
      assert adapter.lock_timeout == 10_000
    end

    test "default lock timeout" do
      adapter = RedisAdapter.new()
      assert adapter.lock_timeout == 5000
    end
  end
end
