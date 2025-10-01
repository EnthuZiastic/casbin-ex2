defmodule CasbinEx2.DispatcherTest do
  use ExUnit.Case

  alias CasbinEx2.Adapter.MemoryAdapter
  alias CasbinEx2.{Dispatcher, Enforcer}

  # Test dispatcher that records all calls
  defmodule TestDispatcher do
    @behaviour Dispatcher

    def start_link do
      Agent.start_link(fn -> [] end, name: __MODULE__)
    end

    def get_calls do
      Agent.get(__MODULE__, & &1)
    end

    def clear_calls do
      Agent.update(__MODULE__, fn _ -> [] end)
    end

    @impl true
    def add_policies(sec, ptype, rules) do
      Agent.update(__MODULE__, fn calls ->
        [{:add_policies, sec, ptype, rules} | calls]
      end)

      :ok
    end

    @impl true
    def remove_policies(sec, ptype, rules) do
      Agent.update(__MODULE__, fn calls ->
        [{:remove_policies, sec, ptype, rules} | calls]
      end)

      :ok
    end

    @impl true
    def remove_filtered_policy(sec, ptype, field_index, field_values) do
      Agent.update(__MODULE__, fn calls ->
        [{:remove_filtered_policy, sec, ptype, field_index, field_values} | calls]
      end)

      :ok
    end

    @impl true
    def clear_policy do
      Agent.update(__MODULE__, fn calls ->
        [{:clear_policy} | calls]
      end)

      :ok
    end

    @impl true
    def update_policy(sec, ptype, old_rule, new_rule) do
      Agent.update(__MODULE__, fn calls ->
        [{:update_policy, sec, ptype, old_rule, new_rule} | calls]
      end)

      :ok
    end

    @impl true
    def update_policies(sec, ptype, old_rules, new_rules) do
      Agent.update(__MODULE__, fn calls ->
        [{:update_policies, sec, ptype, old_rules, new_rules} | calls]
      end)

      :ok
    end

    @impl true
    def update_filtered_policies(sec, ptype, old_rules, new_rules) do
      Agent.update(__MODULE__, fn calls ->
        [{:update_filtered_policies, sec, ptype, old_rules, new_rules} | calls]
      end)

      :ok
    end
  end

  setup_all do
    {:ok, _pid} = TestDispatcher.start_link()
    :ok
  end

  setup do
    TestDispatcher.clear_calls()
    :ok
  end

  describe "CasbinEx2.Dispatcher.Default" do
    alias CasbinEx2.Dispatcher.Default, as: DefaultDispatcher

    test "all methods return :ok without side effects" do
      assert :ok = DefaultDispatcher.add_policies("p", "p", [["alice", "data1", "read"]])

      assert :ok =
               DefaultDispatcher.remove_policies("p", "p", [["alice", "data1", "read"]])

      assert :ok = DefaultDispatcher.remove_filtered_policy("p", "p", 0, ["alice"])
      assert :ok = DefaultDispatcher.clear_policy()

      assert :ok =
               DefaultDispatcher.update_policy("p", "p", ["alice", "data1", "read"], [
                 "alice",
                 "data2",
                 "read"
               ])

      assert :ok =
               DefaultDispatcher.update_policies(
                 "p",
                 "p",
                 [["alice", "data1", "read"]],
                 [["alice", "data2", "read"]]
               )

      assert :ok =
               DefaultDispatcher.update_filtered_policies(
                 "p",
                 "p",
                 [["alice", "data1", "read"]],
                 [["alice", "data2", "read"]]
               )
    end
  end

  defp create_test_enforcer do
    model_content = """
    [request_definition]
    r = sub, obj, act

    [policy_definition]
    p = sub, obj, act

    [policy_effect]
    e = some(where (p.eft == allow))

    [matchers]
    m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
    """

    {:ok, model} = CasbinEx2.Model.load_model_from_text(model_content)
    adapter = MemoryAdapter.new()

    %Enforcer{
      model: model,
      adapter: adapter,
      policies: %{},
      grouping_policies: %{},
      dispatcher: CasbinEx2.Dispatcher.Default,
      auto_notify_dispatcher: false
    }
  end

  describe "enforcer configuration" do
    test "set_dispatcher/2 sets the dispatcher module" do
      enforcer = create_test_enforcer()

      updated_enforcer = Enforcer.set_dispatcher(enforcer, TestDispatcher)

      assert updated_enforcer.dispatcher == TestDispatcher
    end

    test "enable_auto_notify_dispatcher/2 enables dispatcher notifications" do
      enforcer = create_test_enforcer()

      updated_enforcer = Enforcer.enable_auto_notify_dispatcher(enforcer, true)

      assert updated_enforcer.auto_notify_dispatcher == true
    end

    test "enable_auto_notify_dispatcher/2 disables dispatcher notifications" do
      enforcer =
        create_test_enforcer()
        |> Enforcer.enable_auto_notify_dispatcher(true)

      updated_enforcer = Enforcer.enable_auto_notify_dispatcher(enforcer, false)

      assert updated_enforcer.auto_notify_dispatcher == false
    end
  end

  describe "dispatcher module behavior validation" do
    test "TestDispatcher implements all required callbacks" do
      # Verify callbacks work by calling them
      assert :ok = TestDispatcher.add_policies("p", "p", [["alice", "data1", "read"]])
      assert :ok = TestDispatcher.remove_policies("p", "p", [["alice", "data1", "read"]])
      assert :ok = TestDispatcher.remove_filtered_policy("p", "p", 0, ["alice"])
      assert :ok = TestDispatcher.clear_policy()

      assert :ok =
               TestDispatcher.update_policy("p", "p", ["alice", "data1", "read"], [
                 "alice",
                 "data2",
                 "read"
               ])

      assert :ok =
               TestDispatcher.update_policies(
                 "p",
                 "p",
                 [["alice", "data1", "read"]],
                 [["alice", "data2", "read"]]
               )

      assert :ok =
               TestDispatcher.update_filtered_policies(
                 "p",
                 "p",
                 [["alice", "data1", "read"]],
                 [["alice", "data2", "read"]]
               )

      # Verify calls were recorded
      calls = TestDispatcher.get_calls()
      assert length(calls) == 7
    end

    test "Default dispatcher implements all required callbacks" do
      alias CasbinEx2.Dispatcher.Default, as: DefaultDispatcher

      # Verify all callbacks exist and return :ok
      assert :ok = DefaultDispatcher.add_policies("p", "p", [["alice", "data1", "read"]])
      assert :ok = DefaultDispatcher.remove_policies("p", "p", [["alice", "data1", "read"]])
      assert :ok = DefaultDispatcher.remove_filtered_policy("p", "p", 0, ["alice"])
      assert :ok = DefaultDispatcher.clear_policy()

      assert :ok =
               DefaultDispatcher.update_policy("p", "p", ["alice", "data1", "read"], [
                 "alice",
                 "data2",
                 "read"
               ])

      assert :ok =
               DefaultDispatcher.update_policies(
                 "p",
                 "p",
                 [["alice", "data1", "read"]],
                 [["alice", "data2", "read"]]
               )

      assert :ok =
               DefaultDispatcher.update_filtered_policies(
                 "p",
                 "p",
                 [["alice", "data1", "read"]],
                 [["alice", "data2", "read"]]
               )
    end
  end
end
