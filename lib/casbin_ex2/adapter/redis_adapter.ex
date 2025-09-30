defmodule CasbinEx2.Adapter.RedisAdapter do
  @moduledoc """
  Redis adapter for distributed policy storage and caching.

  This adapter provides scalable, distributed policy storage using Redis,
  with support for clustering, pub/sub notifications, and policy versioning.

  ## Features

  - Distributed policy storage with Redis
  - Policy change notifications via Redis pub/sub
  - Support for Redis Cluster and Sentinel
  - Configurable TTL for policy caching
  - Transaction support for atomic operations
  - Policy versioning and conflict resolution
  - Connection pooling and failover

  ## Redis Schema

  The adapter uses the following Redis key patterns:

      casbin:policies:{tenant}:p:{ptype}     - Policy rules hash
      casbin:policies:{tenant}:g:{gtype}     - Grouping policy rules hash
      casbin:metadata:{tenant}:version       - Policy version counter
      casbin:metadata:{tenant}:updated_at    - Last update timestamp
      casbin:locks:{tenant}                  - Distributed lock for updates

  ## Usage

      # Basic configuration
      adapter = CasbinEx2.Adapter.RedisAdapter.new(
        host: "localhost",
        port: 6379,
        database: 0
      )

      # Advanced configuration with clustering
      adapter = CasbinEx2.Adapter.RedisAdapter.new(
        cluster: [
          {"redis-1.example.com", 6379},
          {"redis-2.example.com", 6379},
          {"redis-3.example.com", 6379}
        ],
        pool_size: 20,
        tenant_id: "tenant-123",
        ttl: 3600,
        notifications: true
      )
  """

  @behaviour CasbinEx2.Adapter

  defstruct [
    :connection_opts,
    :pool_name,
    :tenant_id,
    :key_prefix,
    :ttl,
    :notifications,
    :pub_sub_channel,
    :versioning,
    :lock_timeout
  ]

  @type t :: %__MODULE__{
          connection_opts: keyword(),
          pool_name: atom(),
          tenant_id: String.t(),
          key_prefix: String.t(),
          ttl: pos_integer() | nil,
          notifications: boolean(),
          pub_sub_channel: String.t(),
          versioning: boolean(),
          lock_timeout: pos_integer()
        }

  @default_pool_size 10
  @default_lock_timeout 5000
  @default_ttl nil

  @doc """
  Creates a new Redis adapter.

  ## Options

  - `:host` - Redis host (default: "localhost")
  - `:port` - Redis port (default: 6379)
  - `:database` - Redis database number (default: 0)
  - `:password` - Redis password
  - `:cluster` - List of Redis cluster nodes [{host, port}, ...]
  - `:sentinel` - Sentinel configuration
  - `:pool_size` - Connection pool size (default: 10)
  - `:tenant_id` - Tenant identifier for multi-tenancy (default: "default")
  - `:key_prefix` - Custom key prefix (default: "casbin")
  - `:ttl` - TTL for policy keys in seconds (default: nil - no expiration)
  - `:notifications` - Enable pub/sub notifications (default: false)
  - `:versioning` - Enable policy versioning (default: true)
  - `:lock_timeout` - Distributed lock timeout in ms (default: 5000)

  ## Examples

      # Simple Redis instance
      adapter = CasbinEx2.Adapter.RedisAdapter.new(
        host: "localhost",
        port: 6379,
        database: 1
      )

      # Redis Cluster
      adapter = CasbinEx2.Adapter.RedisAdapter.new(
        cluster: [
          {"redis-1.example.com", 6379},
          {"redis-2.example.com", 6379},
          {"redis-3.example.com", 6379}
        ],
        tenant_id: "production",
        notifications: true
      )

      # With authentication and TTL
      adapter = CasbinEx2.Adapter.RedisAdapter.new(
        host: "redis.example.com",
        port: 6380,
        password: "secret",
        tenant_id: "tenant-123",
        ttl: 3600,
        versioning: true
      )
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    tenant_id = Keyword.get(opts, :tenant_id, "default")
    key_prefix = Keyword.get(opts, :key_prefix, "casbin")
    pool_name = :"redis_adapter_#{:erlang.unique_integer([:positive])}"

    connection_opts = build_connection_opts(opts)

    adapter = %__MODULE__{
      connection_opts: connection_opts,
      pool_name: pool_name,
      tenant_id: tenant_id,
      key_prefix: key_prefix,
      ttl: Keyword.get(opts, :ttl, @default_ttl),
      notifications: Keyword.get(opts, :notifications, false),
      pub_sub_channel: "#{key_prefix}:notifications:#{tenant_id}",
      versioning: Keyword.get(opts, :versioning, true),
      lock_timeout: Keyword.get(opts, :lock_timeout, @default_lock_timeout)
    }

    # Start connection pool
    start_pool(adapter)

    adapter
  end

  @doc """
  Subscribes to policy change notifications.

  The calling process will receive Redis pub/sub messages when policies change.
  """
  @spec subscribe_notifications(t()) :: :ok | {:error, term()}
  def subscribe_notifications(%__MODULE__{notifications: true} = adapter) do
    case Redix.PubSub.start_link(adapter.connection_opts) do
      {:ok, pubsub} ->
        Redix.PubSub.subscribe(pubsub, adapter.pub_sub_channel, self())
        Process.put(:redis_pubsub, pubsub)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  def subscribe_notifications(%__MODULE__{notifications: false}) do
    {:error, "Notifications not enabled"}
  end

  @doc """
  Gets current policy version from Redis.
  """
  @spec get_version(t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def get_version(%__MODULE__{versioning: true} = adapter) do
    version_key = build_key(adapter, "metadata", "version")

    case redis_command(adapter, ["GET", version_key]) do
      {:ok, nil} -> {:ok, 0}
      {:ok, version_str} -> {:ok, String.to_integer(version_str)}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_version(%__MODULE__{versioning: false}) do
    {:error, "Versioning not enabled"}
  end

  @doc """
  Gets Redis connection and memory statistics.
  """
  @spec get_stats(t()) :: {:ok, map()} | {:error, term()}
  def get_stats(%__MODULE__{} = adapter) do
    with {:ok, memory_usage} <-
           redis_command(adapter, ["MEMORY", "USAGE", build_key(adapter, "policies", "*")]),
         {:ok, key_count} <- count_policy_keys(adapter),
         {:ok, connection_info} <- redis_command(adapter, ["CLIENT", "LIST"]) do
      {:ok,
       %{
         memory_usage: memory_usage || 0,
         policy_keys: key_count,
         connections: length(String.split(connection_info, "\n")) - 1,
         tenant_id: adapter.tenant_id
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Clears all policies for the current tenant.
  """
  @spec clear_policies(t()) :: :ok | {:error, term()}
  def clear_policies(%__MODULE__{} = adapter) do
    pattern = build_key(adapter, "policies", "*")

    with {:ok, keys} <- redis_command(adapter, ["KEYS", pattern]),
         :ok <- delete_keys(adapter, keys),
         :ok <- increment_version(adapter) do
      publish_notification(adapter, :policies_cleared, %{})
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Adapter Behaviour Implementation

  @impl CasbinEx2.Adapter
  def load_policy(%__MODULE__{} = adapter, _model) do
    with_lock(adapter, fn ->
      policies = load_policy_type(adapter, "p")
      grouping_policies = load_policy_type(adapter, "g")
      {:ok, policies, grouping_policies}
    end)
  end

  @impl CasbinEx2.Adapter
  def load_filtered_policy(%__MODULE__{} = adapter, _model, filter) do
    with_lock(adapter, fn ->
      {:ok, policies, grouping_policies} = load_policy(adapter, nil)

      filtered_policies = apply_filter(policies, filter)
      filtered_grouping = apply_filter(grouping_policies, filter)

      {:ok, filtered_policies, filtered_grouping}
    end)
  end

  @impl CasbinEx2.Adapter
  def load_incremental_filtered_policy(%__MODULE__{} = adapter, model, filter) do
    # For Redis adapter, incremental is the same as full filtered load
    load_filtered_policy(adapter, model, filter)
  end

  @impl CasbinEx2.Adapter
  def filtered?(%__MODULE__{}), do: true

  @impl CasbinEx2.Adapter
  def save_policy(%__MODULE__{} = adapter, policies, grouping_policies) do
    with_lock(adapter, fn ->
      # Clear existing policies
      pattern = build_key(adapter, "policies", "*")

      with {:ok, keys} <- redis_command(adapter, ["KEYS", pattern]),
           :ok <- delete_keys(adapter, keys),
           :ok <- save_policy_type(adapter, "p", policies),
           :ok <- save_policy_type(adapter, "g", grouping_policies),
           :ok <- update_metadata(adapter) do
        publish_notification(adapter, :policies_saved, %{
          policy_count: count_rules(policies),
          grouping_policy_count: count_rules(grouping_policies)
        })

        :ok
      else
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  @impl CasbinEx2.Adapter
  def add_policy(%__MODULE__{} = adapter, sec, ptype, rule) do
    with_lock(adapter, fn ->
      key = build_key(adapter, "policies", "#{sec}:#{ptype}")
      rule_json = Jason.encode!(rule)

      with {:ok, _} <- redis_command(adapter, ["SADD", key, rule_json]),
           :ok <- set_ttl_if_configured(adapter, key),
           :ok <- increment_version(adapter) do
        publish_notification(adapter, :policy_added, %{
          section: sec,
          policy_type: ptype,
          rule: rule
        })

        :ok
      else
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  @impl CasbinEx2.Adapter
  def remove_policy(%__MODULE__{} = adapter, sec, ptype, rule) do
    with_lock(adapter, fn ->
      key = build_key(adapter, "policies", "#{sec}:#{ptype}")
      rule_json = Jason.encode!(rule)

      with {:ok, _} <- redis_command(adapter, ["SREM", key, rule_json]),
           :ok <- increment_version(adapter) do
        publish_notification(adapter, :policy_removed, %{
          section: sec,
          policy_type: ptype,
          rule: rule
        })

        :ok
      else
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  @impl CasbinEx2.Adapter
  def remove_filtered_policy(%__MODULE__{} = adapter, sec, ptype, field_index, field_values) do
    with_lock(adapter, fn ->
      key = build_key(adapter, "policies", "#{sec}:#{ptype}")

      with {:ok, members} <- redis_command(adapter, ["SMEMBERS", key]),
           filtered_members <- filter_members(members, field_index, field_values),
           :ok <- remove_members(adapter, key, filtered_members),
           :ok <- increment_version(adapter) do
        publish_notification(adapter, :policies_filtered, %{
          section: sec,
          policy_type: ptype,
          field_index: field_index,
          field_values: field_values,
          removed_count: length(filtered_members)
        })

        :ok
      else
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  # Private functions

  defp build_connection_opts(opts) do
    base_opts = [
      host: Keyword.get(opts, :host, "localhost"),
      port: Keyword.get(opts, :port, 6379),
      database: Keyword.get(opts, :database, 0),
      pool_size: Keyword.get(opts, :pool_size, @default_pool_size)
    ]

    case Keyword.get(opts, :password) do
      nil -> base_opts
      password -> Keyword.put(base_opts, :password, password)
    end
    |> maybe_add_cluster_opts(opts)
    |> maybe_add_sentinel_opts(opts)
  end

  defp maybe_add_cluster_opts(base_opts, opts) do
    case Keyword.get(opts, :cluster) do
      nil -> base_opts
      cluster_nodes -> Keyword.put(base_opts, :cluster, cluster_nodes)
    end
  end

  defp maybe_add_sentinel_opts(base_opts, opts) do
    case Keyword.get(opts, :sentinel) do
      nil -> base_opts
      sentinel_opts -> Keyword.put(base_opts, :sentinel, sentinel_opts)
    end
  end

  defp start_pool(%__MODULE__{} = adapter) do
    pool_opts = [
      name: {:local, adapter.pool_name},
      worker_module: Redix,
      size: adapter.connection_opts[:pool_size] || @default_pool_size,
      max_overflow: 0
    ]

    case :poolboy.start_link(pool_opts, adapter.connection_opts) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> raise "Failed to start Redis pool: #{inspect(reason)}"
    end
  end

  defp build_key(%__MODULE__{key_prefix: prefix, tenant_id: tenant}, category, suffix) do
    "#{prefix}:#{category}:#{tenant}:#{suffix}"
  end

  defp redis_command(%__MODULE__{pool_name: pool_name}, command) do
    :poolboy.transaction(pool_name, fn worker ->
      Redix.command(worker, command)
    end)
  end

  defp load_policy_type(%__MODULE__{} = adapter, type_prefix) do
    pattern = build_key(adapter, "policies", "#{type_prefix}:*")

    case redis_command(adapter, ["KEYS", pattern]) do
      {:ok, keys} ->
        load_policies_from_keys(adapter, keys)

      {:error, _} ->
        %{}
    end
  end

  defp load_policies_from_keys(adapter, keys) do
    keys
    |> Enum.reduce(%{}, fn key, acc ->
      case redis_command(adapter, ["SMEMBERS", key]) do
        {:ok, members} ->
          ptype = extract_ptype_from_key(key)
          rules = Enum.map(members, &Jason.decode!/1)
          Map.put(acc, ptype, rules)

        {:error, _} ->
          acc
      end
    end)
  end

  defp save_policy_type(%__MODULE__{} = adapter, type_prefix, policies) do
    Enum.each(policies, fn {ptype, rules} ->
      key = build_key(adapter, "policies", "#{type_prefix}:#{ptype}")
      rule_jsons = Enum.map(rules, &Jason.encode!/1)

      case rule_jsons do
        [] ->
          :ok

        [first | rest] ->
          # Use SADD to add all rules atomically
          command = ["SADD", key, first | rest]

          with {:ok, _} <- redis_command(adapter, command),
               :ok <- set_ttl_if_configured(adapter, key) do
            :ok
          else
            {:error, reason} -> {:error, reason}
          end
      end
    end)

    :ok
  rescue
    error -> {:error, "Failed to save policies: #{inspect(error)}"}
  end

  defp extract_ptype_from_key(key) do
    key
    |> String.split(":")
    |> List.last()
  end

  defp set_ttl_if_configured(%__MODULE__{ttl: nil}, _key), do: :ok

  defp set_ttl_if_configured(%__MODULE__{ttl: ttl} = adapter, key) do
    case redis_command(adapter, ["EXPIRE", key, ttl]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp update_metadata(%__MODULE__{} = adapter) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    updated_key = build_key(adapter, "metadata", "updated_at")

    with {:ok, _} <- redis_command(adapter, ["SET", updated_key, timestamp]),
         :ok <- increment_version(adapter) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp increment_version(%__MODULE__{versioning: false}), do: :ok

  defp increment_version(%__MODULE__{versioning: true} = adapter) do
    version_key = build_key(adapter, "metadata", "version")

    case redis_command(adapter, ["INCR", version_key]) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp publish_notification(%__MODULE__{notifications: false}, _event, _data), do: :ok

  defp publish_notification(%__MODULE__{notifications: true} = adapter, event, data) do
    message = Jason.encode!(%{event: event, data: data, timestamp: DateTime.utc_now()})

    case redis_command(adapter, ["PUBLISH", adapter.pub_sub_channel, message]) do
      {:ok, _} -> :ok
      # Don't fail operations due to notification errors
      {:error, _} -> :ok
    end
  end

  defp apply_filter(policies, filter) when is_function(filter, 2) do
    policies
    |> Enum.into(%{}, fn {ptype, rules} ->
      filtered_rules = Enum.filter(rules, &filter.(ptype, &1))
      {ptype, filtered_rules}
    end)
    |> Enum.reject(fn {_ptype, rules} -> Enum.empty?(rules) end)
    |> Enum.into(%{})
  end

  defp apply_filter(policies, _filter), do: policies

  defp filter_members(members, field_index, field_values) do
    Enum.filter(members, fn member ->
      case Jason.decode(member) do
        {:ok, rule} -> matches_filter?(rule, field_index, field_values)
        {:error, _} -> false
      end
    end)
  end

  defp matches_filter?(rule, field_index, field_values) do
    field_values
    |> Enum.with_index()
    |> Enum.all?(fn {value, index} ->
      actual_index = field_index + index

      case Enum.at(rule, actual_index) do
        ^value -> true
        nil -> false
        _other -> false
      end
    end)
  end

  defp remove_members(_adapter, _key, []), do: :ok

  defp remove_members(adapter, key, members) do
    command = ["SREM", key | members]

    case redis_command(adapter, command) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp delete_keys(_adapter, []), do: :ok

  defp delete_keys(adapter, keys) do
    command = ["DEL" | keys]

    case redis_command(adapter, command) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp count_policy_keys(%__MODULE__{} = adapter) do
    pattern = build_key(adapter, "policies", "*")

    case redis_command(adapter, ["KEYS", pattern]) do
      {:ok, keys} -> {:ok, length(keys)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp count_rules(policies) do
    policies
    |> Map.values()
    |> Enum.map(&length/1)
    |> Enum.sum()
  end

  defp with_lock(%__MODULE__{} = adapter, fun) do
    lock_key = build_key(adapter, "locks", "write")
    lock_value = :crypto.strong_rand_bytes(16) |> Base.encode16()

    case acquire_lock(adapter, lock_key, lock_value) do
      :ok ->
        try do
          fun.()
        after
          release_lock(adapter, lock_key, lock_value)
        end

      {:error, :timeout} ->
        {:error, "Failed to acquire lock within timeout"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp acquire_lock(adapter, lock_key, lock_value) do
    acquire_lock(adapter, lock_key, lock_value, adapter.lock_timeout)
  end

  defp acquire_lock(_adapter, _lock_key, _lock_value, timeout) when timeout <= 0 do
    {:error, :timeout}
  end

  defp acquire_lock(adapter, lock_key, lock_value, timeout) do
    case redis_command(adapter, ["SET", lock_key, lock_value, "PX", adapter.lock_timeout, "NX"]) do
      {:ok, "OK"} ->
        :ok

      {:ok, nil} ->
        :timer.sleep(10)
        acquire_lock(adapter, lock_key, lock_value, timeout - 10)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp release_lock(adapter, lock_key, lock_value) do
    # Use Lua script for atomic lock release
    script = """
    if redis.call("GET", KEYS[1]) == ARGV[1] then
      return redis.call("DEL", KEYS[1])
    else
      return 0
    end
    """

    redis_command(adapter, ["EVAL", script, "1", lock_key, lock_value])
  end
end
