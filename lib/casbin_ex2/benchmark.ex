defmodule CasbinEx2.Benchmark do
  @moduledoc """
  Performance benchmarking utilities for CasbinEx2 enforcement operations.

  This module provides benchmarking capabilities to compare performance between:
  - Cached vs non-cached enforcement
  - Batch vs individual enforcement
  - Various policy sizes and complexity
  - Different storage adapters
  """

  alias CasbinEx2.Adapter.FileAdapter
  alias CasbinEx2.{CachedEnforcer, Enforcer, EnforcerServer}

  require Logger

  @doc """
  Runs comprehensive benchmarks comparing different enforcement strategies.
  """
  def run_comprehensive_benchmarks(opts \\ []) do
    # Logger.info("Starting CasbinEx2 comprehensive benchmarks...")

    results = %{
      enforcement_comparison: benchmark_enforcement_comparison(opts),
      batch_processing: benchmark_batch_processing(opts),
      cache_performance: benchmark_cache_performance(opts),
      scalability: benchmark_scalability(opts)
    }

    print_benchmark_summary(results)
    results
  end

  @doc """
  Benchmarks cached vs non-cached enforcement performance.
  """
  def benchmark_enforcement_comparison(opts \\ []) do
    iterations = Keyword.get(opts, :iterations, 1000)
    policy_count = Keyword.get(opts, :policy_count, 100)

    # Logger.debug(
    #   "Benchmarking enforcement comparison with #{iterations} iterations and #{policy_count} policies"
    # )

    # Setup enforcers
    {enforcer, cached_enforcer_name} = setup_benchmark_enforcers(policy_count)

    # Prepare test requests
    requests = generate_test_requests(iterations)

    # Benchmark standard enforcer
    {standard_time, _} =
      :timer.tc(fn ->
        Enum.each(requests, fn request ->
          Enforcer.enforce(enforcer, request)
        end)
      end)

    # Benchmark cached enforcer
    {cached_time, _} =
      :timer.tc(fn ->
        Enum.each(requests, fn request ->
          CachedEnforcer.enforce(cached_enforcer_name, request)
        end)
      end)

    # Cleanup
    cleanup_benchmark_enforcers(cached_enforcer_name)

    %{
      standard_time_ms: standard_time / 1000,
      cached_time_ms: cached_time / 1000,
      speedup_factor: standard_time / cached_time,
      iterations: iterations,
      policy_count: policy_count
    }
  end

  @doc """
  Benchmarks batch processing performance.
  """
  def benchmark_batch_processing(opts \\ []) do
    batch_sizes = Keyword.get(opts, :batch_sizes, [1, 10, 50, 100, 500])
    policy_count = Keyword.get(opts, :policy_count, 100)

    # Logger.info("Benchmarking batch processing with sizes: #{inspect(batch_sizes)}")

    enforcer = setup_basic_enforcer(policy_count)

    results = Enum.map(batch_sizes, &benchmark_single_batch_size(&1, enforcer))

    %{results: results, policy_count: policy_count}
  end

  @doc """
  Benchmarks cache hit rates and performance under different scenarios.
  """
  def benchmark_cache_performance(opts \\ []) do
    cache_sizes = Keyword.get(opts, :cache_sizes, [10, 50, 100, 500])
    request_patterns = Keyword.get(opts, :request_patterns, [:random, :repeated, :sequential])
    iterations = Keyword.get(opts, :iterations, 1000)

    # Logger.info("Benchmarking cache performance with sizes: #{inspect(cache_sizes)}")

    results =
      Enum.map(cache_sizes, &benchmark_single_cache_size(&1, request_patterns, iterations))

    %{results: results, iterations: iterations}
  end

  @doc """
  Benchmarks scalability with increasing policy counts.
  """
  def benchmark_scalability(opts \\ []) do
    policy_counts = Keyword.get(opts, :policy_counts, [10, 50, 100, 500, 1000])
    iterations = Keyword.get(opts, :iterations, 100)

    # Logger.info("Benchmarking scalability with policy counts: #{inspect(policy_counts)}")

    results = Enum.map(policy_counts, &benchmark_single_policy_count(&1, iterations))

    %{results: results, iterations: iterations}
  end

  @doc """
  Benchmarks EnforcerServer vs direct Enforcer calls.
  """
  def benchmark_server_vs_direct(opts \\ []) do
    iterations = Keyword.get(opts, :iterations, 1000)
    policy_count = Keyword.get(opts, :policy_count, 100)

    # Logger.info("Benchmarking EnforcerServer vs direct Enforcer calls")

    # Setup direct enforcer
    enforcer = setup_basic_enforcer(policy_count)

    # Setup enforcer server
    server_name = :"benchmark_server_#{:erlang.unique_integer([:positive])}"
    model_path = create_test_model_file()
    policy_path = create_test_policy_file(policy_count)

    {:ok, _pid} =
      EnforcerServer.start_link(server_name, model_path, adapter: FileAdapter.new(policy_path))

    requests = generate_test_requests(iterations)

    # Benchmark direct enforcer
    {direct_time, _} =
      :timer.tc(fn ->
        Enum.each(requests, fn request ->
          Enforcer.enforce(enforcer, request)
        end)
      end)

    # Benchmark enforcer server
    {server_time, _} =
      :timer.tc(fn ->
        Enum.each(requests, fn request ->
          EnforcerServer.enforce(server_name, request)
        end)
      end)

    # Cleanup
    GenServer.stop({:via, Registry, {CasbinEx2.EnforcerRegistry, server_name}})
    File.rm(model_path)
    File.rm(policy_path)

    %{
      direct_time_ms: direct_time / 1000,
      server_time_ms: server_time / 1000,
      overhead_factor: server_time / direct_time,
      iterations: iterations,
      policy_count: policy_count
    }
  end

  # Private helper functions

  defp benchmark_single_batch_size(batch_size, enforcer) do
    requests = generate_test_requests(batch_size)

    # Benchmark individual enforcement
    {individual_time, _} =
      :timer.tc(fn ->
        Enum.each(requests, fn request ->
          Enforcer.enforce(enforcer, request)
        end)
      end)

    # Benchmark batch enforcement
    {batch_time, _} =
      :timer.tc(fn ->
        Enforcer.batch_enforce(enforcer, requests)
      end)

    %{
      batch_size: batch_size,
      individual_time_ms: individual_time / 1000,
      batch_time_ms: batch_time / 1000,
      speedup_factor: individual_time / batch_time
    }
  end

  defp benchmark_single_cache_size(cache_size, request_patterns, iterations) do
    pattern_results =
      Enum.map(request_patterns, &benchmark_cache_pattern(&1, cache_size, iterations))

    %{
      cache_size: cache_size,
      patterns: pattern_results
    }
  end

  defp benchmark_cache_pattern(pattern, cache_size, iterations) do
    cached_enforcer_name = setup_cached_enforcer(100, cache_size)
    requests = generate_pattern_requests(pattern, iterations)

    # Warm up cache if needed
    warm_up_cache_if_needed(pattern, cached_enforcer_name, requests, iterations)

    {execution_time, _} =
      :timer.tc(fn ->
        Enum.each(requests, fn request ->
          CachedEnforcer.enforce(cached_enforcer_name, request)
        end)
      end)

    stats = CachedEnforcer.get_cache_stats(cached_enforcer_name)
    cleanup_benchmark_enforcers(cached_enforcer_name)

    %{
      pattern: pattern,
      execution_time_ms: execution_time / 1000,
      cache_stats: stats
    }
  end

  defp benchmark_single_policy_count(policy_count, iterations) do
    {enforcer, cached_enforcer_name} = setup_benchmark_enforcers(policy_count)
    requests = generate_test_requests(iterations)

    # Benchmark standard enforcer
    {standard_time, _} =
      :timer.tc(fn ->
        Enum.each(requests, fn request ->
          Enforcer.enforce(enforcer, request)
        end)
      end)

    # Benchmark cached enforcer
    {cached_time, _} =
      :timer.tc(fn ->
        Enum.each(requests, fn request ->
          CachedEnforcer.enforce(cached_enforcer_name, request)
        end)
      end)

    cleanup_benchmark_enforcers(cached_enforcer_name)

    %{
      policy_count: policy_count,
      standard_time_ms: standard_time / 1000,
      cached_time_ms: cached_time / 1000,
      speedup_factor: standard_time / cached_time
    }
  end

  defp warm_up_cache_if_needed(pattern, cached_enforcer_name, requests, iterations)
       when pattern in [:repeated, :sequential] do
    Enum.take(requests, div(iterations, 10))
    |> Enum.each(fn request ->
      CachedEnforcer.enforce(cached_enforcer_name, request)
    end)
  end

  defp warm_up_cache_if_needed(_pattern, _cached_enforcer_name, _requests, _iterations), do: :ok

  defp setup_benchmark_enforcers(policy_count) do
    enforcer = setup_basic_enforcer(policy_count)
    cached_enforcer_name = setup_cached_enforcer(policy_count, 1000)
    {enforcer, cached_enforcer_name}
  end

  defp setup_basic_enforcer(policy_count) do
    model_path = create_test_model_file()
    policy_path = create_test_policy_file(policy_count)

    adapter = FileAdapter.new(policy_path)
    {:ok, enforcer} = Enforcer.init_with_file(model_path, adapter)

    # Cleanup temporary files
    File.rm(model_path)
    File.rm(policy_path)

    enforcer
  end

  defp setup_cached_enforcer(policy_count, cache_size) do
    model_path = create_test_model_file()
    policy_path = create_test_policy_file(policy_count)

    cached_enforcer_name = :"benchmark_cached_#{:erlang.unique_integer([:positive])}"

    opts = [
      adapter: FileAdapter.new(policy_path),
      cache_size: cache_size,
      enable_cache: true
    ]

    {:ok, _pid} = CachedEnforcer.start_link(cached_enforcer_name, model_path, opts)

    # Cleanup temporary files
    File.rm(model_path)
    File.rm(policy_path)

    cached_enforcer_name
  end

  defp cleanup_benchmark_enforcers(cached_enforcer_name) do
    GenServer.stop(
      {:via, Registry, {CasbinEx2.EnforcerRegistry, :"cached_#{cached_enforcer_name}"}}
    )
  catch
    :exit, _ -> :ok
  end

  defp create_test_model_file do
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
    model_path = "/tmp/benchmark_model_#{test_id}.conf"
    File.write!(model_path, model_content)
    model_path
  end

  defp create_test_policy_file(policy_count) do
    test_id = :erlang.unique_integer([:positive])
    policy_path = "/tmp/benchmark_policy_#{test_id}.csv"

    policies =
      for i <- 1..policy_count do
        user = "user#{rem(i, 10)}"
        resource = "data#{rem(i, 20)}"
        action = Enum.random(["read", "write", "delete"])
        "p, #{user}, #{resource}, #{action}"
      end

    policy_content = Enum.join(policies, "\n")
    File.write!(policy_path, policy_content)
    policy_path
  end

  defp generate_test_requests(count) do
    for _i <- 1..count do
      user = "user#{:rand.uniform(10) - 1}"
      resource = "data#{:rand.uniform(20) - 1}"
      action = Enum.random(["read", "write", "delete"])
      [user, resource, action]
    end
  end

  defp generate_pattern_requests(:random, count) do
    generate_test_requests(count)
  end

  defp generate_pattern_requests(:repeated, count) do
    # 80% repeated requests, 20% unique
    base_requests = generate_test_requests(div(count, 5))

    repeated_requests =
      for _i <- 1..div(count * 4, 5) do
        Enum.random(base_requests)
      end

    Enum.shuffle(base_requests ++ repeated_requests)
  end

  defp generate_pattern_requests(:sequential, count) do
    # Sequential access pattern
    for i <- 1..count do
      user = "user#{rem(i, 5)}"
      resource = "data#{rem(div(i, 5), 10)}"
      action = "read"
      [user, resource, action]
    end
  end

  defp print_benchmark_summary(_results) do
    # Benchmark results logging disabled for cleaner test output
    # Enable by uncommenting the lines below when needed for debugging

    # Logger.info("=== CasbinEx2 Benchmark Results ===")
    # enforcement = results.enforcement_comparison
    # Logger.info("Enforcement Comparison (#{enforcement.iterations} iterations):")
    # Logger.info("  Standard: #{Float.round(enforcement.standard_time_ms, 2)}ms")
    # Logger.info("  Cached: #{Float.round(enforcement.cached_time_ms, 2)}ms")
    # Logger.info("  Speedup: #{Float.round(enforcement.speedup_factor, 2)}x")
    # Logger.info("=== End Benchmark Results ===")
  end
end
