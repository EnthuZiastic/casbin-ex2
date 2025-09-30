defmodule CasbinEx2.BenchmarkTest do
  use ExUnit.Case

  alias CasbinEx2.Benchmark

  @moduletag :benchmark

  describe "benchmark functionality" do
    test "enforcement comparison benchmark runs successfully" do
      results = Benchmark.benchmark_enforcement_comparison(iterations: 10, policy_count: 5)

      assert is_map(results)
      assert Map.has_key?(results, :standard_time_ms)
      assert Map.has_key?(results, :cached_time_ms)
      assert Map.has_key?(results, :speedup_factor)
      assert Map.has_key?(results, :iterations)
      assert Map.has_key?(results, :policy_count)

      assert results.iterations == 10
      assert results.policy_count == 5
      assert is_number(results.standard_time_ms)
      assert is_number(results.cached_time_ms)
      assert is_number(results.speedup_factor)
    end

    test "batch processing benchmark runs successfully" do
      results = Benchmark.benchmark_batch_processing(batch_sizes: [1, 5], policy_count: 5)

      assert is_map(results)
      assert Map.has_key?(results, :results)
      assert Map.has_key?(results, :policy_count)
      assert length(results.results) == 2

      Enum.each(results.results, fn batch_result ->
        assert Map.has_key?(batch_result, :batch_size)
        assert Map.has_key?(batch_result, :individual_time_ms)
        assert Map.has_key?(batch_result, :batch_time_ms)
        assert Map.has_key?(batch_result, :speedup_factor)
      end)
    end

    test "cache performance benchmark runs successfully" do
      results =
        Benchmark.benchmark_cache_performance(
          cache_sizes: [10],
          request_patterns: [:random],
          iterations: 5
        )

      assert is_map(results)
      assert Map.has_key?(results, :results)
      assert Map.has_key?(results, :iterations)
      assert length(results.results) == 1

      cache_result = List.first(results.results)
      assert Map.has_key?(cache_result, :cache_size)
      assert Map.has_key?(cache_result, :patterns)
      assert length(cache_result.patterns) == 1

      pattern_result = List.first(cache_result.patterns)
      assert Map.has_key?(pattern_result, :pattern)
      assert Map.has_key?(pattern_result, :execution_time_ms)
      assert Map.has_key?(pattern_result, :cache_stats)
    end

    test "scalability benchmark runs successfully" do
      results = Benchmark.benchmark_scalability(policy_counts: [5, 10], iterations: 5)

      assert is_map(results)
      assert Map.has_key?(results, :results)
      assert Map.has_key?(results, :iterations)
      assert length(results.results) == 2

      Enum.each(results.results, fn scale_result ->
        assert Map.has_key?(scale_result, :policy_count)
        assert Map.has_key?(scale_result, :standard_time_ms)
        assert Map.has_key?(scale_result, :cached_time_ms)
        assert Map.has_key?(scale_result, :speedup_factor)
      end)
    end

    test "server vs direct benchmark runs successfully" do
      results = Benchmark.benchmark_server_vs_direct(iterations: 5, policy_count: 5)

      assert is_map(results)
      assert Map.has_key?(results, :direct_time_ms)
      assert Map.has_key?(results, :server_time_ms)
      assert Map.has_key?(results, :overhead_factor)
      assert Map.has_key?(results, :iterations)
      assert Map.has_key?(results, :policy_count)

      assert results.iterations == 5
      assert results.policy_count == 5
      assert is_number(results.direct_time_ms)
      assert is_number(results.server_time_ms)
      assert is_number(results.overhead_factor)
    end

    @tag :integration
    test "comprehensive benchmarks run successfully" do
      results =
        Benchmark.run_comprehensive_benchmarks(
          iterations: 5,
          policy_count: 5,
          batch_sizes: [1, 3],
          cache_sizes: [5],
          request_patterns: [:random],
          policy_counts: [5]
        )

      assert is_map(results)
      assert Map.has_key?(results, :enforcement_comparison)
      assert Map.has_key?(results, :batch_processing)
      assert Map.has_key?(results, :cache_performance)
      assert Map.has_key?(results, :scalability)
    end
  end
end
