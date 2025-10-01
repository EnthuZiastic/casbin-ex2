defmodule CasbinEx2.BuiltinOperatorsTest do
  use ExUnit.Case, async: true

  alias CasbinEx2.Enforcer

  describe "keyGet/2" do
    test "returns matched part from wildcard pattern" do
      {:ok, enforcer} = create_test_enforcer_with_matcher("keyGet(r.obj, p.obj)")

      # Add policy with wildcard
      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "/foo/*", "GET"])

      # The keyGet should extract "bar/baz" from "/foo/bar/baz"
      assert Enforcer.enforce(enforcer, ["alice", "/foo/bar/baz", "GET"])
    end

    test "returns empty string when no match" do
      {:ok, enforcer} = create_test_enforcer_with_matcher("keyGet(r.obj, p.obj) == ''")

      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "/bar/*", "GET"])

      # No match since /foo/bar doesn't start with /bar/
      assert Enforcer.enforce(enforcer, ["alice", "/foo/bar", "GET"])
    end
  end

  describe "keyGet2/3" do
    test "extracts named path variable from pattern" do
      {:ok, enforcer} =
        create_test_enforcer_with_matcher("keyGet2(r.obj, p.obj, 'id') == 'alice'")

      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["user", "/user/:id", "GET"])

      assert Enforcer.enforce(enforcer, ["user", "/user/alice", "GET"])
      refute Enforcer.enforce(enforcer, ["user", "/user/bob", "GET"])
    end

    test "returns empty string when variable not found" do
      {:ok, enforcer} =
        create_test_enforcer_with_matcher("keyGet2(r.obj, p.obj, 'missing') == ''")

      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["user", "/user/:id", "GET"])

      assert Enforcer.enforce(enforcer, ["user", "/user/alice", "GET"])
    end
  end

  describe "keyGet3/3" do
    test "extracts named path variable from curly brace pattern" do
      {:ok, enforcer} =
        create_test_enforcer_with_matcher("keyGet3(r.obj, p.obj, 'project') == 'project1'")

      {:ok, enforcer} =
        CasbinEx2.Management.add_policy(enforcer, ["user", "project/proj_{project}_admin/", "GET"])

      assert Enforcer.enforce(enforcer, ["user", "project/proj_project1_admin/", "GET"])
      refute Enforcer.enforce(enforcer, ["user", "project/proj_project2_admin/", "GET"])
    end

    test "handles multiple variables in pattern" do
      {:ok, enforcer} = create_test_enforcer_with_matcher("keyGet3(r.obj, p.obj, 'id') == '123'")

      {:ok, enforcer} =
        CasbinEx2.Management.add_policy(enforcer, ["user", "/org/{org}/user/{id}", "GET"])

      assert Enforcer.enforce(enforcer, ["user", "/org/acme/user/123", "GET"])
      refute Enforcer.enforce(enforcer, ["user", "/org/acme/user/456", "GET"])
    end
  end

  describe "timeMatch/2" do
    test "matches when current time is between start and end" do
      # Get current time and create a window around it
      now = DateTime.utc_now()
      start_time = DateTime.add(now, -3600, :second) |> DateTime.to_iso8601()
      end_time = DateTime.add(now, 3600, :second) |> DateTime.to_iso8601()

      {:ok, enforcer} =
        create_test_enforcer_with_matcher("timeMatch('#{start_time}', '#{end_time}')")

      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "data1", "read"])

      assert Enforcer.enforce(enforcer, ["alice", "data1", "read"])
    end

    test "allows underscore to ignore start time" do
      now = DateTime.utc_now()
      end_time = DateTime.add(now, 3600, :second) |> DateTime.to_iso8601()

      {:ok, enforcer} = create_test_enforcer_with_matcher("timeMatch('_', '#{end_time}')")

      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "data1", "read"])

      assert Enforcer.enforce(enforcer, ["alice", "data1", "read"])
    end

    test "allows underscore to ignore end time" do
      now = DateTime.utc_now()
      start_time = DateTime.add(now, -3600, :second) |> DateTime.to_iso8601()

      {:ok, enforcer} = create_test_enforcer_with_matcher("timeMatch('#{start_time}', '_')")

      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "data1", "read"])

      assert Enforcer.enforce(enforcer, ["alice", "data1", "read"])
    end

    test "rejects when current time is before start time" do
      now = DateTime.utc_now()
      start_time = DateTime.add(now, 3600, :second) |> DateTime.to_iso8601()
      end_time = DateTime.add(now, 7200, :second) |> DateTime.to_iso8601()

      {:ok, enforcer} =
        create_test_enforcer_with_matcher("timeMatch('#{start_time}', '#{end_time}')")

      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "data1", "read"])

      refute Enforcer.enforce(enforcer, ["alice", "data1", "read"])
    end

    test "rejects when current time is after end time" do
      now = DateTime.utc_now()
      start_time = DateTime.add(now, -7200, :second) |> DateTime.to_iso8601()
      end_time = DateTime.add(now, -3600, :second) |> DateTime.to_iso8601()

      {:ok, enforcer} =
        create_test_enforcer_with_matcher("timeMatch('#{start_time}', '#{end_time}')")

      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "data1", "read"])

      refute Enforcer.enforce(enforcer, ["alice", "data1", "read"])
    end
  end

  describe "integration tests for all operators" do
    test "keyMatch operators work in model matchers" do
      model_text = """
      [request_definition]
      r = sub, obj, act

      [policy_definition]
      p = sub, obj, act

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = r.sub == p.sub && keyMatch(r.obj, p.obj) && r.act == p.act
      """

      {:ok, model} = CasbinEx2.Model.load_model_from_text(model_text)

      {:ok, enforcer} =
        Enforcer.init_with_model_and_adapter(model, CasbinEx2.Adapter.MemoryAdapter.new())

      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["alice", "/data/*", "read"])

      assert Enforcer.enforce(enforcer, ["alice", "/data/file1", "read"])
      assert Enforcer.enforce(enforcer, ["alice", "/data/dir/file2", "read"])
      refute Enforcer.enforce(enforcer, ["alice", "/other/file", "read"])
    end

    test "all ip match operators work" do
      model_text = """
      [request_definition]
      r = ip

      [policy_definition]
      p = network

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = ipMatch(r.ip, p.network)
      """

      {:ok, model} = CasbinEx2.Model.load_model_from_text(model_text)

      {:ok, enforcer} =
        Enforcer.init_with_model_and_adapter(model, CasbinEx2.Adapter.MemoryAdapter.new())

      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["192.168.1.0/24"])

      assert Enforcer.enforce(enforcer, ["192.168.1.100"])
      assert Enforcer.enforce(enforcer, ["192.168.1.1"])
      refute Enforcer.enforce(enforcer, ["192.168.2.1"])
    end

    test "glob match operators work with patterns" do
      model_text = """
      [request_definition]
      r = obj

      [policy_definition]
      p = obj

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = globMatch(r.obj, p.obj)
      """

      {:ok, model} = CasbinEx2.Model.load_model_from_text(model_text)

      {:ok, enforcer} =
        Enforcer.init_with_model_and_adapter(model, CasbinEx2.Adapter.MemoryAdapter.new())

      {:ok, enforcer} = CasbinEx2.Management.add_policy(enforcer, ["/data/**/*.txt"])

      assert Enforcer.enforce(enforcer, ["/data/file.txt"])
      assert Enforcer.enforce(enforcer, ["/data/dir/file.txt"])
      assert Enforcer.enforce(enforcer, ["/data/a/b/c/file.txt"])
      refute Enforcer.enforce(enforcer, ["/data/file.pdf"])
    end
  end

  # Helper function to create test enforcer
  defp create_test_enforcer_with_matcher(matcher) do
    model_text = """
    [request_definition]
    r = sub, obj, act

    [policy_definition]
    p = sub, obj, act

    [policy_effect]
    e = some(where (p.eft == allow))

    [matchers]
    m = #{matcher}
    """

    {:ok, model} = CasbinEx2.Model.load_model_from_text(model_text)
    Enforcer.init_with_model_and_adapter(model, CasbinEx2.Adapter.MemoryAdapter.new())
  end
end
