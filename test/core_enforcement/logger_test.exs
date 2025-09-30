defmodule CasbinEx2.LoggerTest do
  use ExUnit.Case
  doctest CasbinEx2.Logger

  alias CasbinEx2.Logger, as: CasbinLogger

  setup do
    # Start the logger if not already started
    case GenServer.whereis(CasbinLogger) do
      nil -> CasbinLogger.start_link()
      _pid -> :ok
    end

    # Reset logger state
    CasbinLogger.disable_log()
    CasbinLogger.clear_buffer()

    :ok
  end

  describe "start_link/1" do
    test "starts the logger GenServer" do
      # The logger should already be started from setup
      assert Process.whereis(CasbinLogger) != nil
    end
  end

  describe "enable_log/1 and disable_log/0" do
    test "enables and disables logging" do
      # Initially disabled
      config = CasbinLogger.get_config()
      refute config.enabled

      # Enable logging
      :ok = CasbinLogger.enable_log()
      config = CasbinLogger.get_config()
      assert config.enabled

      # Disable logging
      :ok = CasbinLogger.disable_log()
      config = CasbinLogger.get_config()
      refute config.enabled
    end

    test "enables logging with custom options" do
      :ok = CasbinLogger.enable_log(level: :debug, output: :file, format: :json)
      config = CasbinLogger.get_config()

      assert config.enabled
      assert config.level == :debug
      assert config.output == :file
      assert config.format == :json
    end
  end

  describe "set_log_level/1" do
    test "sets the log level" do
      :ok = CasbinLogger.set_log_level(:debug)
      config = CasbinLogger.get_config()
      assert config.level == :debug

      :ok = CasbinLogger.set_log_level(:error)
      config = CasbinLogger.get_config()
      assert config.level == :error
    end
  end

  describe "set_output/1" do
    test "sets the output type" do
      :ok = CasbinLogger.set_output(:file)
      config = CasbinLogger.get_config()
      assert config.output == :file

      :ok = CasbinLogger.set_output(:console)
      config = CasbinLogger.get_config()
      assert config.output == :console
    end
  end

  describe "add_filter/1 and remove_filter/1" do
    test "adds and removes event type filters" do
      # Initially no filters
      config = CasbinLogger.get_config()
      assert config.filters == []

      # Add filter
      :ok = CasbinLogger.add_filter(:enforcement)
      config = CasbinLogger.get_config()
      assert :enforcement in config.filters

      # Add another filter
      :ok = CasbinLogger.add_filter(:policy_change)
      config = CasbinLogger.get_config()
      assert :enforcement in config.filters
      assert :policy_change in config.filters

      # Remove filter
      :ok = CasbinLogger.remove_filter(:enforcement)
      config = CasbinLogger.get_config()
      refute :enforcement in config.filters
      assert :policy_change in config.filters
    end

    test "prevents duplicate filters" do
      :ok = CasbinLogger.add_filter(:enforcement)
      :ok = CasbinLogger.add_filter(:enforcement)

      config = CasbinLogger.get_config()
      assert Enum.count(config.filters, &(&1 == :enforcement)) == 1
    end
  end

  describe "log_enforcement/4" do
    test "logs enforcement decisions when enabled" do
      CasbinLogger.enable_log(level: :info)

      :ok =
        CasbinLogger.log_enforcement(
          ["alice", "data1", "read"],
          true,
          "Direct policy match",
          %{policy_id: "p1"}
        )

      # Give some time for async processing
      Process.sleep(10)

      logs = CasbinLogger.get_recent_logs(10)
      assert length(logs) >= 1

      log_entry = hd(logs)
      assert log_entry.event_type == :enforcement
      assert log_entry.level == :info
      assert String.contains?(log_entry.message, "Enforcement")
      assert log_entry.metadata.request == ["alice", "data1", "read"]
      assert log_entry.metadata.result == true
    end

    test "does not log when disabled" do
      CasbinLogger.disable_log()

      :ok =
        CasbinLogger.log_enforcement(
          ["alice", "data1", "read"],
          true,
          "Direct policy match"
        )

      # Give some time for async processing
      Process.sleep(10)

      logs = CasbinLogger.get_recent_logs(10)
      assert Enum.empty?(logs)
    end

    test "respects log level filtering" do
      CasbinLogger.enable_log(level: :warn)

      # This should not be logged (info < warn)
      :ok =
        CasbinLogger.log_enforcement(
          ["alice", "data1", "read"],
          true,
          "Direct policy match"
        )

      # Give some time for async processing
      Process.sleep(10)

      logs = CasbinLogger.get_recent_logs(10)
      assert Enum.empty?(logs)
    end

    test "respects event type filtering" do
      CasbinLogger.enable_log(level: :info)
      # Only log policy changes
      CasbinLogger.add_filter(:policy_change)

      # This should not be logged (enforcement not in filter)
      :ok =
        CasbinLogger.log_enforcement(
          ["alice", "data1", "read"],
          true,
          "Direct policy match"
        )

      # Give some time for async processing
      Process.sleep(10)

      logs = CasbinLogger.get_recent_logs(10)
      assert Enum.empty?(logs)
    end
  end

  describe "log_policy_change/4" do
    test "logs policy changes when enabled" do
      CasbinLogger.enable_log(level: :info)

      :ok =
        CasbinLogger.log_policy_change(
          :add,
          "p",
          ["alice", "data1", "read"],
          %{timestamp: System.system_time()}
        )

      # Give some time for async processing
      Process.sleep(10)

      logs = CasbinLogger.get_recent_logs(10)
      assert length(logs) >= 1

      log_entry = hd(logs)
      assert log_entry.event_type == :policy_change
      assert log_entry.level == :info
      assert String.contains?(log_entry.message, "Policy add")
      assert log_entry.metadata.action == :add
      assert log_entry.metadata.ptype == "p"
      assert log_entry.metadata.params == ["alice", "data1", "read"]
    end
  end

  describe "log_role_operation/5" do
    test "logs role management operations" do
      CasbinLogger.enable_log(level: :info)

      :ok =
        CasbinLogger.log_role_operation(
          :add_link,
          "alice",
          "admin",
          "domain1",
          %{enforcer_id: "e1"}
        )

      # Give some time for async processing
      Process.sleep(10)

      logs = CasbinLogger.get_recent_logs(10)
      assert length(logs) >= 1

      log_entry = hd(logs)
      assert log_entry.event_type == :role_management
      assert log_entry.level == :info
      assert String.contains?(log_entry.message, "Role add_link")
      assert log_entry.metadata.operation == :add_link
      assert log_entry.metadata.user == "alice"
      assert log_entry.metadata.role == "admin"
      assert log_entry.metadata.domain == "domain1"
    end
  end

  describe "log_adapter_operation/4" do
    test "logs adapter operations" do
      CasbinLogger.enable_log(level: :info)

      :ok =
        CasbinLogger.log_adapter_operation(
          :load_policy,
          :success,
          150,
          %{adapter_type: "file"}
        )

      # Give some time for async processing
      Process.sleep(10)

      logs = CasbinLogger.get_recent_logs(10)
      assert length(logs) >= 1

      log_entry = hd(logs)
      assert log_entry.event_type == :adapter
      assert log_entry.level == :info
      assert String.contains?(log_entry.message, "Adapter load_policy")
      assert log_entry.metadata.operation == :load_policy
      assert log_entry.metadata.status == :success
      assert log_entry.metadata.result == 150
    end
  end

  describe "log_watcher_event/3" do
    test "logs watcher events" do
      CasbinLogger.enable_log(level: :info)

      :ok =
        CasbinLogger.log_watcher_event(
          :policy_update,
          "Policy updated from external source",
          %{source: "redis"}
        )

      # Give some time for async processing
      Process.sleep(10)

      logs = CasbinLogger.get_recent_logs(10)
      assert length(logs) >= 1

      log_entry = hd(logs)
      assert log_entry.event_type == :watcher
      assert log_entry.level == :info
      assert String.contains?(log_entry.message, "Watcher policy_update")
      assert log_entry.metadata.event_type == :policy_update
    end
  end

  describe "log_error/3" do
    test "logs error events" do
      CasbinLogger.enable_log(level: :error)

      :ok =
        CasbinLogger.log_error(
          :enforcement_error,
          "Invalid policy format",
          %{policy: ["alice"]}
        )

      # Give some time for async processing
      Process.sleep(10)

      logs = CasbinLogger.get_recent_logs(10)
      assert length(logs) >= 1

      log_entry = hd(logs)
      assert log_entry.event_type == :error
      assert log_entry.level == :error
      assert String.contains?(log_entry.message, "Error enforcement_error")
      assert log_entry.metadata.error_type == :enforcement_error
    end
  end

  describe "log_performance/3" do
    test "logs performance metrics" do
      CasbinLogger.enable_log(level: :debug)

      :ok =
        CasbinLogger.log_performance(
          :enforcement,
          1500,
          %{request_count: 100}
        )

      # Give some time for async processing
      Process.sleep(10)

      logs = CasbinLogger.get_recent_logs(10)
      assert length(logs) >= 1

      log_entry = hd(logs)
      assert log_entry.event_type == :performance
      assert log_entry.level == :debug
      assert String.contains?(log_entry.message, "Performance enforcement")
      assert log_entry.metadata.operation == :enforcement
      assert log_entry.metadata.duration_us == 1500
    end

    test "does not log performance when level is too high" do
      # debug < info
      CasbinLogger.enable_log(level: :info)

      :ok =
        CasbinLogger.log_performance(
          :enforcement,
          1500,
          %{request_count: 100}
        )

      # Give some time for async processing
      Process.sleep(10)

      logs = CasbinLogger.get_recent_logs(10)
      assert Enum.empty?(logs)
    end
  end

  describe "get_recent_logs/1" do
    test "returns recent log entries" do
      CasbinLogger.enable_log(level: :info)

      # Add multiple log entries
      :ok = CasbinLogger.log_enforcement(["alice", "data1", "read"], true, "Match 1")
      :ok = CasbinLogger.log_enforcement(["bob", "data2", "write"], false, "Match 2")
      :ok = CasbinLogger.log_policy_change(:add, "p", ["charlie", "data3", "read"])

      # Give some time for async processing
      Process.sleep(10)

      logs = CasbinLogger.get_recent_logs(2)
      assert length(logs) == 2

      all_logs = CasbinLogger.get_recent_logs(10)
      assert length(all_logs) >= 3
    end
  end

  describe "flush/0" do
    test "flushes the log buffer" do
      CasbinLogger.enable_log(level: :info)

      :ok = CasbinLogger.log_enforcement(["alice", "data1", "read"], true, "Test")

      # Give some time for async processing
      Process.sleep(10)

      logs_before = CasbinLogger.get_recent_logs(10)
      assert length(logs_before) >= 1

      :ok = CasbinLogger.flush()

      # After flush, the buffer should be cleared
      logs_after = CasbinLogger.get_recent_logs(10)
      assert Enum.empty?(logs_after)
    end
  end

  describe "clear_buffer/0" do
    test "clears the log buffer" do
      CasbinLogger.enable_log(level: :info)

      :ok = CasbinLogger.log_enforcement(["alice", "data1", "read"], true, "Test")

      # Give some time for async processing
      Process.sleep(10)

      logs_before = CasbinLogger.get_recent_logs(10)
      assert length(logs_before) >= 1

      :ok = CasbinLogger.clear_buffer()

      logs_after = CasbinLogger.get_recent_logs(10)
      assert Enum.empty?(logs_after)
    end
  end

  describe "buffer management" do
    test "maintains buffer size limit" do
      CasbinLogger.enable_log(level: :info, buffer_size: 3)

      # Add more entries than buffer size
      for i <- 1..5 do
        :ok = CasbinLogger.log_enforcement(["user#{i}", "data", "read"], true, "Test #{i}")
      end

      # Give some time for async processing
      Process.sleep(10)

      logs = CasbinLogger.get_recent_logs(10)
      # Should not exceed buffer size
      assert length(logs) <= 3
    end
  end

  describe "log levels" do
    test "respects log level hierarchy" do
      CasbinLogger.enable_log(level: :warn)

      # These should not be logged
      # debug level
      :ok = CasbinLogger.log_performance(:test, 100)
      # Give some time for async processing
      Process.sleep(10)

      logs_after_debug = CasbinLogger.get_recent_logs(10)
      debug_count = length(logs_after_debug)

      # info level
      :ok = CasbinLogger.log_enforcement(["alice", "data1", "read"], true, "Test")
      # Give some time for async processing
      Process.sleep(10)

      logs_after_info = CasbinLogger.get_recent_logs(10)
      info_count = length(logs_after_info)

      # Info should not be logged (info < warn)
      assert info_count == debug_count

      # This should be logged
      # error level
      :ok = CasbinLogger.log_error(:test_error, "Test error")
      # Give some time for async processing
      Process.sleep(10)

      logs_after_error = CasbinLogger.get_recent_logs(10)
      error_count = length(logs_after_error)

      # Error should be logged (error >= warn)
      assert error_count > info_count
    end
  end

  describe "configuration" do
    test "get_config returns current configuration" do
      CasbinLogger.enable_log(
        level: :debug,
        output: :file,
        format: :json,
        buffer_size: 200,
        flush_interval: 10_000
      )

      CasbinLogger.add_filter(:enforcement)
      CasbinLogger.add_filter(:policy_change)

      config = CasbinLogger.get_config()

      assert config.enabled == true
      assert config.level == :debug
      assert config.output == :file
      assert config.format == :json
      assert config.buffer_size == 200
      assert config.flush_interval == 10_000
      assert :enforcement in config.filters
      assert :policy_change in config.filters
    end
  end

  describe "edge cases" do
    test "handles empty metadata gracefully" do
      CasbinLogger.enable_log(level: :info)

      :ok = CasbinLogger.log_enforcement(["alice", "data1", "read"], true, "Test", %{})

      # Give some time for async processing
      Process.sleep(10)

      logs = CasbinLogger.get_recent_logs(1)
      assert length(logs) == 1

      log_entry = hd(logs)
      assert is_map(log_entry.metadata)
    end

    test "handles nil metadata gracefully" do
      CasbinLogger.enable_log(level: :info)

      # Test with explicit empty metadata
      :ok = CasbinLogger.log_policy_change(:add, "p", ["alice", "data1", "read"])

      # Give some time for async processing
      Process.sleep(10)

      logs = CasbinLogger.get_recent_logs(1)
      assert length(logs) == 1

      log_entry = hd(logs)
      assert is_map(log_entry.metadata)
    end
  end
end
