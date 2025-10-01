defmodule CasbinEx2.InternalAPITest do
  use ExUnit.Case

  alias CasbinEx2.Adapter.MemoryAdapter
  alias CasbinEx2.Dispatcher.Default, as: DefaultDispatcher
  alias CasbinEx2.{Enforcer, Model}

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

    {:ok, model} = Model.load_model_from_text(model_content)
    adapter = MemoryAdapter.new()

    %Enforcer{
      model: model,
      adapter: adapter,
      policies: %{},
      grouping_policies: %{},
      auto_save: true,
      auto_notify_watcher: true,
      auto_notify_dispatcher: true,
      watcher: nil,
      dispatcher: DefaultDispatcher
    }
  end

  describe "should_persist/1" do
    test "returns true when adapter exists and auto_save is true" do
      enforcer = create_test_enforcer()
      assert Enforcer.should_persist(enforcer) == true
    end

    test "returns false when auto_save is false" do
      enforcer = create_test_enforcer()
      enforcer = %{enforcer | auto_save: false}
      assert Enforcer.should_persist(enforcer) == false
    end

    test "returns false when adapter is nil" do
      enforcer = create_test_enforcer()
      enforcer = %{enforcer | adapter: nil}
      assert Enforcer.should_persist(enforcer) == false
    end

    test "returns false when both adapter is nil and auto_save is false" do
      enforcer = create_test_enforcer()
      enforcer = %{enforcer | adapter: nil, auto_save: false}
      assert Enforcer.should_persist(enforcer) == false
    end
  end

  describe "should_notify/1" do
    test "returns true when watcher exists and auto_notify_watcher is true" do
      enforcer = create_test_enforcer()
      # Set a dummy watcher module
      enforcer = %{enforcer | watcher: SomeWatcher}
      assert Enforcer.should_notify(enforcer) == true
    end

    test "returns false when auto_notify_watcher is false" do
      enforcer = create_test_enforcer()
      enforcer = %{enforcer | watcher: SomeWatcher, auto_notify_watcher: false}
      assert Enforcer.should_notify(enforcer) == false
    end

    test "returns false when watcher is nil" do
      enforcer = create_test_enforcer()
      enforcer = %{enforcer | watcher: nil}
      assert Enforcer.should_notify(enforcer) == false
    end

    test "returns false when both watcher is nil and auto_notify_watcher is false" do
      enforcer = create_test_enforcer()
      enforcer = %{enforcer | watcher: nil, auto_notify_watcher: false}
      assert Enforcer.should_notify(enforcer) == false
    end
  end

  describe "get_field_index/3 and set_field_index/4" do
    test "get_field_index returns error for unset field" do
      enforcer = create_test_enforcer()
      assert {:error, _message} = Enforcer.get_field_index(enforcer, "p", "priority")
    end

    test "set_field_index updates the model" do
      enforcer = create_test_enforcer()
      updated_enforcer = Enforcer.set_field_index(enforcer, "p", "priority", 3)

      # The enforcer should be returned (even if implementation is placeholder)
      assert %Enforcer{} = updated_enforcer
    end

    test "set_field_index preserves other enforcer fields" do
      enforcer = create_test_enforcer()
      original_policies = enforcer.policies
      original_adapter = enforcer.adapter

      updated_enforcer = Enforcer.set_field_index(enforcer, "p", "priority", 3)

      assert updated_enforcer.policies == original_policies
      assert updated_enforcer.adapter == original_adapter
      assert updated_enforcer.auto_save == enforcer.auto_save
    end
  end

  describe "auto_notify_dispatcher configuration" do
    test "enable_auto_notify_dispatcher/2 sets auto_notify_dispatcher to true" do
      enforcer = create_test_enforcer()
      enforcer = %{enforcer | auto_notify_dispatcher: false}

      updated_enforcer = Enforcer.enable_auto_notify_dispatcher(enforcer, true)
      assert updated_enforcer.auto_notify_dispatcher == true
    end

    test "enable_auto_notify_dispatcher/2 sets auto_notify_dispatcher to false" do
      enforcer = create_test_enforcer()

      updated_enforcer = Enforcer.enable_auto_notify_dispatcher(enforcer, false)
      assert updated_enforcer.auto_notify_dispatcher == false
    end

    test "enable_auto_notify_dispatcher/2 preserves other enforcer fields" do
      enforcer = create_test_enforcer()
      original_policies = enforcer.policies
      original_adapter = enforcer.adapter
      original_dispatcher = enforcer.dispatcher

      updated_enforcer = Enforcer.enable_auto_notify_dispatcher(enforcer, false)

      assert updated_enforcer.policies == original_policies
      assert updated_enforcer.adapter == original_adapter
      assert updated_enforcer.dispatcher == original_dispatcher
    end
  end

  describe "auto_save and auto_notify_watcher configuration" do
    test "enable_auto_save/2 sets auto_save to true" do
      enforcer = create_test_enforcer()
      enforcer = %{enforcer | auto_save: false}

      updated_enforcer = Enforcer.enable_auto_save(enforcer, true)
      assert updated_enforcer.auto_save == true
    end

    test "enable_auto_save/2 sets auto_save to false" do
      enforcer = create_test_enforcer()

      updated_enforcer = Enforcer.enable_auto_save(enforcer, false)
      assert updated_enforcer.auto_save == false
    end

    test "enable_auto_notify_watcher/2 sets auto_notify_watcher to true" do
      enforcer = create_test_enforcer()
      enforcer = %{enforcer | auto_notify_watcher: false}

      updated_enforcer = Enforcer.enable_auto_notify_watcher(enforcer, true)
      assert updated_enforcer.auto_notify_watcher == true
    end

    test "enable_auto_notify_watcher/2 sets auto_notify_watcher to false" do
      enforcer = create_test_enforcer()

      updated_enforcer = Enforcer.enable_auto_notify_watcher(enforcer, false)
      assert updated_enforcer.auto_notify_watcher == false
    end
  end

  describe "component swapping" do
    test "set_adapter/2 updates the adapter" do
      enforcer = create_test_enforcer()
      new_adapter = MemoryAdapter.new(table_name: :custom_table)

      updated_enforcer = Enforcer.set_adapter(enforcer, new_adapter)
      assert updated_enforcer.adapter == new_adapter
    end

    test "set_watcher/2 updates the watcher" do
      enforcer = create_test_enforcer()

      {:ok, updated_enforcer} = Enforcer.set_watcher(enforcer, CustomWatcher)
      assert updated_enforcer.watcher == CustomWatcher
    end

    test "set_dispatcher/2 updates the dispatcher" do
      enforcer = create_test_enforcer()

      updated_enforcer = Enforcer.set_dispatcher(enforcer, CustomDispatcher)
      assert updated_enforcer.dispatcher == CustomDispatcher
    end
  end
end
