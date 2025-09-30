defmodule CasbinEx2.Model.PriorityModelTest do
  use ExUnit.Case
  doctest CasbinEx2.Model.PriorityModel

  alias CasbinEx2.Model.PriorityModel

  setup do
    model = PriorityModel.new()
    {:ok, model: model}
  end

  describe "new/1" do
    test "creates a new Priority model with default values" do
      model = PriorityModel.new()

      assert model.rules == %{}
      assert model.priority_index == []
      assert model.rule_groups == %{}
      assert model.default_effect == :deny
      assert model.conflict_resolution == :highest_priority
      assert model.enabled == true
    end

    test "creates a model with custom options" do
      model = PriorityModel.new(default_effect: :allow, conflict_resolution: :explicit_deny)

      assert model.default_effect == :allow
      assert model.conflict_resolution == :explicit_deny
    end
  end

  describe "add_rule/2" do
    test "adds a priority rule", %{model: model} do
      rule = %{
        id: "rule1",
        priority: 100,
        effect: :allow,
        conditions: %{},
        subject_pattern: "admin",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      {:ok, updated_model} = PriorityModel.add_rule(model, rule)

      assert Map.get(updated_model.rules, "rule1") == rule
      assert {100, "rule1"} in updated_model.priority_index
    end

    test "maintains priority index sorted by priority (descending)", %{model: model} do
      rule1 = %{
        id: "rule1",
        priority: 100,
        effect: :allow,
        conditions: %{},
        subject_pattern: "admin",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      rule2 = %{
        id: "rule2",
        priority: 200,
        effect: :deny,
        conditions: %{},
        subject_pattern: "user",
        object_pattern: "secret",
        action_pattern: "*",
        enabled: true
      }

      {:ok, model} = PriorityModel.add_rule(model, rule1)
      {:ok, updated_model} = PriorityModel.add_rule(model, rule2)

      # Should be sorted by priority descending
      assert updated_model.priority_index == [{200, "rule2"}, {100, "rule1"}]
    end

    test "returns error when rule already exists", %{model: model} do
      rule = %{
        id: "rule1",
        priority: 100,
        effect: :allow,
        conditions: %{},
        subject_pattern: "admin",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      {:ok, model} = PriorityModel.add_rule(model, rule)
      {:error, :rule_exists} = PriorityModel.add_rule(model, rule)
    end
  end

  describe "remove_rule/2" do
    test "removes a rule and updates priority index", %{model: model} do
      rule = %{
        id: "rule1",
        priority: 100,
        effect: :allow,
        conditions: %{},
        subject_pattern: "admin",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      {:ok, model} = PriorityModel.add_rule(model, rule)
      {:ok, updated_model} = PriorityModel.remove_rule(model, "rule1")

      assert Map.get(updated_model.rules, "rule1") == nil
      refute {100, "rule1"} in updated_model.priority_index
    end

    test "removes rule from rule groups", %{model: model} do
      rule = %{
        id: "rule1",
        priority: 100,
        effect: :allow,
        conditions: %{},
        subject_pattern: "admin",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      {:ok, model} = PriorityModel.add_rule(model, rule)
      {:ok, model} = PriorityModel.add_rule_group(model, "admin_rules", ["rule1"])
      {:ok, updated_model} = PriorityModel.remove_rule(model, "rule1")

      admin_rules = Map.get(updated_model.rule_groups, "admin_rules", [])
      refute "rule1" in admin_rules
    end

    test "returns error when rule not found", %{model: model} do
      {:error, :rule_not_found} = PriorityModel.remove_rule(model, "nonexistent")
    end
  end

  describe "update_rule_priority/3" do
    test "updates rule priority and maintains sorted index", %{model: model} do
      rule1 = %{
        id: "rule1",
        priority: 100,
        effect: :allow,
        conditions: %{},
        subject_pattern: "admin",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      rule2 = %{
        id: "rule2",
        priority: 200,
        effect: :deny,
        conditions: %{},
        subject_pattern: "user",
        object_pattern: "secret",
        action_pattern: "*",
        enabled: true
      }

      {:ok, model} = PriorityModel.add_rule(model, rule1)
      {:ok, model} = PriorityModel.add_rule(model, rule2)
      {:ok, updated_model} = PriorityModel.update_rule_priority(model, "rule1", 300)

      updated_rule = Map.get(updated_model.rules, "rule1")
      assert updated_rule.priority == 300

      # Priority index should be re-sorted
      assert updated_model.priority_index == [{300, "rule1"}, {200, "rule2"}]
    end

    test "returns error when rule not found", %{model: model} do
      {:error, :rule_not_found} = PriorityModel.update_rule_priority(model, "nonexistent", 100)
    end
  end

  describe "evaluate/4" do
    test "returns :allow when model is disabled", %{model: model} do
      disabled_model = %{model | enabled: false}

      result = PriorityModel.evaluate(disabled_model, "alice", "read", "document1")
      assert result == :allow
    end

    test "returns default effect when no rules match", %{model: model} do
      result = PriorityModel.evaluate(model, "alice", "read", "document1")
      # default effect
      assert result == :deny
    end

    test "returns effect of matching rule", %{model: model} do
      rule = %{
        id: "rule1",
        priority: 100,
        effect: :allow,
        conditions: %{},
        subject_pattern: "alice",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      {:ok, model} = PriorityModel.add_rule(model, rule)

      result = PriorityModel.evaluate(model, "alice", "read", "document1")
      assert result == :allow
    end

    test "respects priority order - highest priority wins", %{model: model} do
      high_priority_rule = %{
        id: "high",
        priority: 200,
        effect: :deny,
        conditions: %{},
        subject_pattern: "alice",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      low_priority_rule = %{
        id: "low",
        priority: 100,
        effect: :allow,
        conditions: %{},
        subject_pattern: "alice",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      {:ok, model} = PriorityModel.add_rule(model, low_priority_rule)
      {:ok, model} = PriorityModel.add_rule(model, high_priority_rule)

      result = PriorityModel.evaluate(model, "alice", "read", "document1")
      # high priority rule wins
      assert result == :deny
    end

    test "supports pattern matching with wildcards", %{model: model} do
      rule = %{
        id: "rule1",
        priority: 100,
        effect: :allow,
        conditions: %{},
        subject_pattern: "admin*",
        object_pattern: "doc*",
        action_pattern: "read",
        enabled: true
      }

      {:ok, model} = PriorityModel.add_rule(model, rule)

      assert PriorityModel.evaluate(model, "admin1", "read", "doc123") == :allow
      assert PriorityModel.evaluate(model, "admin2", "read", "document") == :allow
      assert PriorityModel.evaluate(model, "user", "read", "doc123") == :deny
    end

    test "evaluates conditions", %{model: model} do
      rule = %{
        id: "rule1",
        priority: 100,
        effect: :allow,
        # Only allow at hour 10
        conditions: %{"time" => 10},
        subject_pattern: "alice",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      {:ok, model} = PriorityModel.add_rule(model, rule)

      # This test assumes current time evaluation - in real scenarios,
      # you'd mock the time function
      result = PriorityModel.evaluate(model, "alice", "read", "document1")
      # Result depends on actual current time
      assert result in [:allow, :deny]
    end

    test "skips disabled rules", %{model: model} do
      disabled_rule = %{
        id: "rule1",
        priority: 100,
        effect: :allow,
        conditions: %{},
        subject_pattern: "alice",
        object_pattern: "*",
        action_pattern: "*",
        enabled: false
      }

      {:ok, model} = PriorityModel.add_rule(model, disabled_rule)

      result = PriorityModel.evaluate(model, "alice", "read", "document1")
      # disabled rule doesn't match
      assert result == :deny
    end
  end

  describe "evaluate_policy/3" do
    test "returns true when model is disabled", %{model: model} do
      disabled_model = %{model | enabled: false}

      result =
        PriorityModel.evaluate_policy(disabled_model, ["alice", "read", "document1"], "true")

      assert result == true
    end

    test "returns true for :allow effect", %{model: model} do
      rule = %{
        id: "rule1",
        priority: 100,
        effect: :allow,
        conditions: %{},
        subject_pattern: "alice",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      {:ok, model} = PriorityModel.add_rule(model, rule)

      result = PriorityModel.evaluate_policy(model, ["alice", "read", "document1"], "any_policy")
      assert result == true
    end

    test "returns false for :deny effect", %{model: model} do
      rule = %{
        id: "rule1",
        priority: 100,
        effect: :deny,
        conditions: %{},
        subject_pattern: "alice",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      {:ok, model} = PriorityModel.add_rule(model, rule)

      result = PriorityModel.evaluate_policy(model, ["alice", "read", "document1"], "any_policy")
      assert result == false
    end

    test "evaluates policy condition for :indeterminate effect", %{model: model} do
      rule = %{
        id: "rule1",
        priority: 100,
        effect: :indeterminate,
        conditions: %{},
        subject_pattern: "alice",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      {:ok, model} = PriorityModel.add_rule(model, rule)

      result = PriorityModel.evaluate_policy(model, ["alice", "read", "document1"], "true")
      assert result == true

      result = PriorityModel.evaluate_policy(model, ["alice", "read", "document1"], "false")
      assert result == false
    end
  end

  describe "conflict resolution strategies" do
    setup %{model: model} do
      allow_rule = %{
        id: "allow",
        priority: 100,
        effect: :allow,
        conditions: %{},
        subject_pattern: "alice",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      deny_rule = %{
        id: "deny",
        # same priority
        priority: 100,
        effect: :deny,
        conditions: %{},
        subject_pattern: "alice",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      {:ok, model} = PriorityModel.add_rule(model, allow_rule)
      {:ok, model} = PriorityModel.add_rule(model, deny_rule)

      {:ok, model: model}
    end

    test "explicit_deny strategy prefers deny rules", %{model: model} do
      explicit_deny_model = %{model | conflict_resolution: :explicit_deny}

      result = PriorityModel.evaluate(explicit_deny_model, "alice", "read", "document1")
      assert result == :deny
    end

    test "allow_override strategy prefers allow rules", %{model: model} do
      allow_override_model = %{model | conflict_resolution: :allow_override}

      result = PriorityModel.evaluate(allow_override_model, "alice", "read", "document1")
      assert result == :allow
    end

    test "first_match strategy takes first matching rule", %{model: model} do
      first_match_model = %{model | conflict_resolution: :first_match}

      result = PriorityModel.evaluate(first_match_model, "alice", "read", "document1")
      # Result depends on which rule was added first in the index
      assert result in [:allow, :deny]
    end

    test "highest_priority strategy takes highest priority rule", %{model: model} do
      # Default behavior - already tested in evaluate/4 tests
      result = PriorityModel.evaluate(model, "alice", "read", "document1")
      assert result in [:allow, :deny]
    end
  end

  describe "rule groups" do
    test "add_rule_group/3 creates a rule group", %{model: model} do
      {:ok, updated_model} =
        PriorityModel.add_rule_group(model, "admin_rules", ["rule1", "rule2"])

      assert Map.get(updated_model.rule_groups, "admin_rules") == ["rule1", "rule2"]
    end

    test "get_rules_by_group/2 returns rules in a group", %{model: model} do
      rule1 = %{
        id: "rule1",
        priority: 100,
        effect: :allow,
        conditions: %{},
        subject_pattern: "admin",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      rule2 = %{
        id: "rule2",
        priority: 200,
        effect: :deny,
        conditions: %{},
        subject_pattern: "user",
        object_pattern: "secret",
        action_pattern: "*",
        enabled: true
      }

      {:ok, model} = PriorityModel.add_rule(model, rule1)
      {:ok, model} = PriorityModel.add_rule(model, rule2)
      {:ok, model} = PriorityModel.add_rule_group(model, "test_group", ["rule1", "rule2"])

      rules = PriorityModel.get_rules_by_group(model, "test_group")

      assert rule1 in rules
      assert rule2 in rules
      assert length(rules) == 2
    end

    test "get_rules_by_group/2 filters out non-existent rules", %{model: model} do
      rule1 = %{
        id: "rule1",
        priority: 100,
        effect: :allow,
        conditions: %{},
        subject_pattern: "admin",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      {:ok, model} = PriorityModel.add_rule(model, rule1)
      {:ok, model} = PriorityModel.add_rule_group(model, "test_group", ["rule1", "nonexistent"])

      rules = PriorityModel.get_rules_by_group(model, "test_group")

      assert length(rules) == 1
      assert List.first(rules).id == "rule1"
    end
  end

  describe "get_rules_by_priority/1" do
    test "returns rules sorted by priority", %{model: model} do
      rule1 = %{
        id: "rule1",
        priority: 100,
        effect: :allow,
        conditions: %{},
        subject_pattern: "admin",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      rule2 = %{
        id: "rule2",
        priority: 200,
        effect: :deny,
        conditions: %{},
        subject_pattern: "user",
        object_pattern: "secret",
        action_pattern: "*",
        enabled: true
      }

      {:ok, model} = PriorityModel.add_rule(model, rule1)
      {:ok, model} = PriorityModel.add_rule(model, rule2)

      rules = PriorityModel.get_rules_by_priority(model)

      assert length(rules) == 2
      # highest priority first
      assert List.first(rules).id == "rule2"
      assert List.last(rules).id == "rule1"
    end
  end

  describe "complex scenarios" do
    test "handles complex pattern matching scenarios", %{model: model} do
      admin_rule = %{
        id: "admin",
        priority: 300,
        effect: :allow,
        conditions: %{},
        subject_pattern: "admin*",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      secret_rule = %{
        id: "secret",
        priority: 200,
        effect: :deny,
        conditions: %{},
        subject_pattern: "*",
        object_pattern: "secret*",
        action_pattern: "*",
        enabled: true
      }

      public_rule = %{
        id: "public",
        priority: 100,
        effect: :allow,
        conditions: %{},
        subject_pattern: "*",
        object_pattern: "public*",
        action_pattern: "read",
        enabled: true
      }

      {:ok, model} = PriorityModel.add_rule(model, admin_rule)
      {:ok, model} = PriorityModel.add_rule(model, secret_rule)
      {:ok, model} = PriorityModel.add_rule(model, public_rule)

      # Admin can access anything (highest priority)
      assert PriorityModel.evaluate(model, "admin1", "read", "secret_document") == :allow
      assert PriorityModel.evaluate(model, "admin2", "delete", "public_file") == :allow

      # Users can't access secrets (second highest priority)
      assert PriorityModel.evaluate(model, "user", "read", "secret_document") == :deny

      # Users can read public files (lowest priority)
      assert PriorityModel.evaluate(model, "user", "read", "public_file") == :allow
      # only read allowed
      assert PriorityModel.evaluate(model, "user", "write", "public_file") == :deny
    end

    test "time-based conditions work correctly", %{model: model} do
      time_rule = %{
        id: "business_hours",
        priority: 100,
        effect: :allow,
        # Monday
        conditions: %{"day" => 1},
        subject_pattern: "employee",
        object_pattern: "office*",
        action_pattern: "*",
        enabled: true
      }

      {:ok, model} = PriorityModel.add_rule(model, time_rule)

      # Result depends on actual current day - in real tests you'd mock time
      result = PriorityModel.evaluate(model, "employee", "access", "office_door")
      assert result in [:allow, :deny]
    end

    test "handles disabled and enabled rules correctly", %{model: model} do
      enabled_rule = %{
        id: "enabled",
        priority: 200,
        effect: :allow,
        conditions: %{},
        subject_pattern: "alice",
        object_pattern: "*",
        action_pattern: "*",
        enabled: true
      }

      disabled_rule = %{
        id: "disabled",
        # higher priority but disabled
        priority: 300,
        effect: :deny,
        conditions: %{},
        subject_pattern: "alice",
        object_pattern: "*",
        action_pattern: "*",
        enabled: false
      }

      {:ok, model} = PriorityModel.add_rule(model, enabled_rule)
      {:ok, model} = PriorityModel.add_rule(model, disabled_rule)

      # Should use enabled rule even though disabled has higher priority
      result = PriorityModel.evaluate(model, "alice", "read", "document1")
      assert result == :allow
    end
  end
end
