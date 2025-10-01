defmodule CasbinEx2.Adapter.ContextAdapterTest do
  use ExUnit.Case, async: false

  alias CasbinEx2.Adapter.{ContextAdapter, MemoryAdapter}

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

  describe "new/3" do
    test "creates context adapter with default options" do
      base_adapter = MemoryAdapter.new()
      adapter = ContextAdapter.new(base_adapter)

      assert adapter.base_adapter == base_adapter
      assert adapter.default_context == %{}
      assert adapter.context_processors == []
      assert adapter.middleware == []
    end

    test "creates context adapter with custom options" do
      base_adapter = MemoryAdapter.new()
      default_context = %{tenant_id: "test-tenant", environment: "test"}

      processor = fn context -> Map.put(context, :processed, true) end
      middleware = fn _op, _args, _ctx -> :continue end

      adapter =
        ContextAdapter.new(
          base_adapter,
          default_context,
          context_processors: [processor],
          middleware: [middleware]
        )

      assert adapter.default_context == default_context
      assert length(adapter.context_processors) == 1
      assert length(adapter.middleware) == 1
    end
  end

  describe "context management" do
    test "sets and gets context" do
      base_adapter = MemoryAdapter.new()
      adapter = ContextAdapter.new(base_adapter)

      context = %{request_id: "req-123", user_id: "user-456"}
      ContextAdapter.set_context(context)

      retrieved_context = ContextAdapter.get_context(adapter)
      assert retrieved_context.request_id == "req-123"
      assert retrieved_context.user_id == "user-456"

      ContextAdapter.clear_context()
    end

    test "merges request context with default context" do
      default_context = %{tenant_id: "default-tenant", environment: "production"}
      base_adapter = MemoryAdapter.new()
      adapter = ContextAdapter.new(base_adapter, default_context)

      request_context = %{request_id: "req-123", tenant_id: "override-tenant"}
      ContextAdapter.set_context(request_context)

      merged_context = ContextAdapter.get_context(adapter)
      # Request overrides default
      assert merged_context.tenant_id == "override-tenant"
      # Default preserved
      assert merged_context.environment == "production"
      # Request added
      assert merged_context.request_id == "req-123"

      ContextAdapter.clear_context()
    end

    test "applies context processors" do
      processor1 = fn context -> Map.put(context, :step1, true) end
      processor2 = fn context -> Map.put(context, :step2, Map.get(context, :step1, false)) end

      base_adapter = MemoryAdapter.new()

      adapter =
        ContextAdapter.new(base_adapter, %{}, context_processors: [processor1, processor2])

      ContextAdapter.set_context(%{original: true})

      processed_context = ContextAdapter.get_context(adapter)
      assert processed_context.original == true
      assert processed_context.step1 == true
      assert processed_context.step2 == true

      ContextAdapter.clear_context()
    end

    test "clears context" do
      base_adapter = MemoryAdapter.new()
      _adapter = ContextAdapter.new(base_adapter)

      ContextAdapter.set_context(%{test: true})
      assert Process.get(:casbin_context) != nil

      ContextAdapter.clear_context()
      assert Process.get(:casbin_context) == nil
    end

    test "executes function with context" do
      base_adapter = MemoryAdapter.new()
      adapter = ContextAdapter.new(base_adapter)

      # Set initial context
      ContextAdapter.set_context(%{initial: true})

      result =
        ContextAdapter.with_context(%{temp: true}, fn ->
          context = ContextAdapter.get_context(adapter)
          assert context.temp == true
          refute Map.has_key?(context, :initial)
          "test_result"
        end)

      # Context should be restored
      final_context = ContextAdapter.get_context(adapter)
      assert final_context.initial == true
      refute Map.has_key?(final_context, :temp)
      assert result == "test_result"

      ContextAdapter.clear_context()
    end
  end

  describe "adapter behavior with context" do
    setup do
      base_adapter =
        MemoryAdapter.new(
          initial_policies: @sample_policies,
          initial_grouping_policies: @sample_grouping_policies
        )

      adapter = ContextAdapter.new(base_adapter)
      {:ok, %{adapter: adapter}}
    end

    test "load_policy/2 delegates to base adapter", %{adapter: adapter} do
      {:ok, policies, grouping_policies} = ContextAdapter.load_policy(adapter, nil)
      assert policies == @sample_policies
      assert grouping_policies == @sample_grouping_policies
    end

    test "save_policy/3 delegates to base adapter", %{adapter: adapter} do
      new_policies = %{"p" => [["carol", "data3", "read"]]}
      assert :ok = ContextAdapter.save_policy(adapter, new_policies, %{})
    end

    test "add_policy/4 delegates to base adapter", %{adapter: adapter} do
      assert :ok = ContextAdapter.add_policy(adapter, "p", "p", ["dave", "data4", "write"])
    end

    test "remove_policy/4 delegates to base adapter", %{adapter: adapter} do
      assert :ok = ContextAdapter.remove_policy(adapter, "p", "p", ["alice", "data1", "read"])
    end

    test "filtered?/1 delegates to base adapter", %{adapter: adapter} do
      assert ContextAdapter.filtered?(adapter) == true
    end
  end

  describe "middleware execution" do
    test "middleware can intercept operations" do
      # Middleware that blocks all operations
      blocking_middleware = fn _operation, _args, _context ->
        {:error, "Blocked by middleware"}
      end

      base_adapter = MemoryAdapter.new()
      adapter = ContextAdapter.new(base_adapter, %{}, middleware: [blocking_middleware])

      assert {:error, "Blocked by middleware"} = ContextAdapter.load_policy(adapter, nil)
    end

    test "middleware can modify operation results" do
      # Middleware that intercepts load_policy and returns custom data
      intercepting_middleware = fn
        :load_policy, _args, _context ->
          {:ok, %{"custom" => [["test", "data", "action"]]}, %{}}

        _operation, _args, _context ->
          :continue
      end

      base_adapter = MemoryAdapter.new(initial_policies: @sample_policies)
      adapter = ContextAdapter.new(base_adapter, %{}, middleware: [intercepting_middleware])

      {:ok, policies, grouping_policies} = ContextAdapter.load_policy(adapter, nil)
      assert policies == %{"custom" => [["test", "data", "action"]]}
      assert grouping_policies == %{}
    end

    test "middleware chain processes in order" do
      # First middleware adds context info
      middleware1 = fn operation, args, context ->
        Process.put(:middleware1_called, {operation, args, context})
        :continue
      end

      # Second middleware can see what first middleware did
      middleware2 = fn operation, args, context ->
        first_call = Process.get(:middleware1_called)
        Process.put(:middleware2_called, {operation, args, context, first_call})
        :continue
      end

      base_adapter = MemoryAdapter.new(initial_policies: @sample_policies)
      adapter = ContextAdapter.new(base_adapter, %{}, middleware: [middleware1, middleware2])

      ContextAdapter.set_context(%{test_context: true})
      ContextAdapter.load_policy(adapter, nil)

      # Check that both middleware were called
      assert Process.get(:middleware1_called) != nil
      assert Process.get(:middleware2_called) != nil

      ContextAdapter.clear_context()
    end
  end

  describe "built-in context processors" do
    test "add_timestamp_processor adds timestamp" do
      context = %{existing: true}
      processed = ContextAdapter.add_timestamp_processor(context)

      assert processed.existing == true
      assert %DateTime{} = processed.timestamp
    end

    test "add_timestamp_processor preserves existing timestamp" do
      existing_time = DateTime.utc_now()
      context = %{timestamp: existing_time}
      processed = ContextAdapter.add_timestamp_processor(context)

      assert processed.timestamp == existing_time
    end

    test "add_request_id_processor adds request ID" do
      context = %{existing: true}
      processed = ContextAdapter.add_request_id_processor(context)

      assert processed.existing == true
      assert is_binary(processed.request_id)
      assert String.length(processed.request_id) == 32
    end

    test "validate_context_processor validates required fields" do
      validator = ContextAdapter.validate_context_processor([:tenant_id, :user_id])

      # Valid context
      valid_context = %{tenant_id: "tenant-123", user_id: "user-456", extra: "data"}
      assert validator.(valid_context) == valid_context

      # Invalid context
      invalid_context = %{tenant_id: "tenant-123"}

      assert_raise ArgumentError, ~r/Missing required context fields/, fn ->
        validator.(invalid_context)
      end
    end
  end

  describe "built-in middleware" do
    test "audit_middleware executes without errors" do
      base_adapter = MemoryAdapter.new()

      adapter =
        ContextAdapter.new(base_adapter, %{}, middleware: [&ContextAdapter.audit_middleware/3])

      ContextAdapter.set_context(%{user_id: "test-user"})

      # Test that audit middleware doesn't interfere with normal operation
      assert {:ok, %{}, %{}} = ContextAdapter.load_policy(adapter, nil)

      ContextAdapter.clear_context()
    end

    test "performance_middleware stores start time" do
      base_adapter = MemoryAdapter.new()

      adapter =
        ContextAdapter.new(base_adapter, %{},
          middleware: [&ContextAdapter.performance_middleware/3]
        )

      ContextAdapter.load_policy(adapter, nil)

      context = ContextAdapter.get_context(adapter)
      assert is_integer(context.start_time)
    end

    test "cache_middleware handles cache operations" do
      base_adapter = MemoryAdapter.new(initial_policies: @sample_policies)

      adapter =
        ContextAdapter.new(base_adapter, %{}, middleware: [&ContextAdapter.cache_middleware/3])

      # First call should continue to base adapter
      result1 = ContextAdapter.load_policy(adapter, nil)
      assert {:ok, _policies, _grouping} = result1

      # Cache middleware doesn't actually cache in this test setup (no cache backend)
      # But it should still work
      result2 = ContextAdapter.load_policy(adapter, nil)
      assert result1 == result2
    end

    test "tenant_isolation_middleware validates tenant ID" do
      base_adapter = MemoryAdapter.new()

      adapter =
        ContextAdapter.new(base_adapter, %{},
          middleware: [&ContextAdapter.tenant_isolation_middleware/3]
        )

      # Without tenant ID
      assert {:error, "Tenant ID required for this operation"} =
               ContextAdapter.load_policy(adapter, nil)

      # With valid tenant ID
      ContextAdapter.set_context(%{tenant_id: "valid-tenant"})
      # Should continue to base adapter (which will succeed)
      {:ok, _policies, _grouping} = ContextAdapter.load_policy(adapter, nil)

      # With invalid tenant ID
      ContextAdapter.set_context(%{tenant_id: 123})
      assert {:error, "Invalid tenant ID format"} = ContextAdapter.load_policy(adapter, nil)

      ContextAdapter.clear_context()
    end
  end

  describe "integration scenarios" do
    test "full context-aware workflow" do
      # Setup adapter with multiple processors and middleware
      processors = [
        &ContextAdapter.add_timestamp_processor/1,
        &ContextAdapter.add_request_id_processor/1,
        ContextAdapter.validate_context_processor([:tenant_id])
      ]

      middleware = [
        &ContextAdapter.audit_middleware/3,
        &ContextAdapter.tenant_isolation_middleware/3
      ]

      base_adapter =
        MemoryAdapter.new(
          initial_policies: @sample_policies,
          initial_grouping_policies: @sample_grouping_policies
        )

      adapter =
        ContextAdapter.new(
          base_adapter,
          %{environment: "test"},
          context_processors: processors,
          middleware: middleware
        )

      # Set required context
      ContextAdapter.set_context(%{tenant_id: "tenant-123", operation: "test"})

      # Test that middleware doesn't interfere with normal operation
      {:ok, policies, grouping_policies} = ContextAdapter.load_policy(adapter, nil)
      assert policies == @sample_policies
      assert grouping_policies == @sample_grouping_policies

      # Verify context was processed
      final_context = ContextAdapter.get_context(adapter)
      assert final_context.tenant_id == "tenant-123"
      assert final_context.environment == "test"
      assert %DateTime{} = final_context.timestamp
      assert is_binary(final_context.request_id)

      ContextAdapter.clear_context()
    end

    test "context isolation between operations" do
      base_adapter = MemoryAdapter.new()
      adapter = ContextAdapter.new(base_adapter, %{global: true})

      # Operation 1 with specific context
      ContextAdapter.with_context(%{operation: "op1", user: "alice"}, fn ->
        context = ContextAdapter.get_context(adapter)
        assert context.operation == "op1"
        assert context.user == "alice"
        assert context.global == true
      end)

      # Operation 2 with different context
      ContextAdapter.with_context(%{operation: "op2", user: "bob"}, fn ->
        context = ContextAdapter.get_context(adapter)
        assert context.operation == "op2"
        assert context.user == "bob"
        assert context.global == true
      end)

      # No context bleeding
      final_context = ContextAdapter.get_context(adapter)
      assert final_context == %{global: true}
    end

    test "error handling preserves context" do
      failing_middleware = fn _operation, _args, _context ->
        raise "Middleware error"
      end

      base_adapter = MemoryAdapter.new()
      adapter = ContextAdapter.new(base_adapter, %{}, middleware: [failing_middleware])

      ContextAdapter.set_context(%{preserve_me: true})

      assert_raise RuntimeError, "Middleware error", fn ->
        ContextAdapter.load_policy(adapter, nil)
      end

      # Context should still be preserved after error
      context = ContextAdapter.get_context(adapter)
      assert context.preserve_me == true

      ContextAdapter.clear_context()
    end
  end

  describe "edge cases" do
    test "handles nil context gracefully" do
      base_adapter = MemoryAdapter.new()
      adapter = ContextAdapter.new(base_adapter)

      # No context set
      context = ContextAdapter.get_context(adapter)
      assert context == %{}
    end

    test "handles empty middleware list" do
      base_adapter =
        MemoryAdapter.new(
          initial_policies: @sample_policies,
          initial_grouping_policies: @sample_grouping_policies
        )

      adapter = ContextAdapter.new(base_adapter, %{}, middleware: [])

      {:ok, policies, grouping_policies} = ContextAdapter.load_policy(adapter, nil)
      assert policies == @sample_policies
      assert grouping_policies == @sample_grouping_policies
    end

    test "handles empty context processors list" do
      base_adapter = MemoryAdapter.new()
      adapter = ContextAdapter.new(base_adapter, %{default: true}, context_processors: [])

      ContextAdapter.set_context(%{request: true})
      context = ContextAdapter.get_context(adapter)

      assert context.default == true
      assert context.request == true
    end

    test "handles context processor exceptions" do
      failing_processor = fn _context ->
        raise "Processor error"
      end

      base_adapter = MemoryAdapter.new()
      adapter = ContextAdapter.new(base_adapter, %{}, context_processors: [failing_processor])

      assert_raise RuntimeError, "Processor error", fn ->
        ContextAdapter.get_context(adapter)
      end
    end
  end
end
