defmodule CasbinEx2.Model.AbacModelTest do
  use ExUnit.Case
  doctest CasbinEx2.Model.AbacModel

  alias CasbinEx2.Model.AbacModel

  setup do
    model = AbacModel.new()
    {:ok, model: model}
  end

  describe "new/0" do
    test "creates a new ABAC model with default values" do
      model = AbacModel.new()

      assert model.attributes == %{}
      assert model.attribute_providers == %{}
      assert model.policy_templates == []
      assert model.expression_cache == %{}
      assert model.enabled == true
    end
  end

  describe "add_attribute/4" do
    test "adds an attribute for a subject", %{model: model} do
      {:ok, updated_model} = AbacModel.add_attribute(model, "alice", "department", "engineering")

      assert AbacModel.get_attribute(updated_model, "alice", "department") == "engineering"
    end

    test "adds multiple attributes for the same subject", %{model: model} do
      {:ok, model} = AbacModel.add_attribute(model, "alice", "department", "engineering")
      {:ok, updated_model} = AbacModel.add_attribute(model, "alice", "level", "senior")

      assert AbacModel.get_attribute(updated_model, "alice", "department") == "engineering"
      assert AbacModel.get_attribute(updated_model, "alice", "level") == "senior"
    end

    test "supports different attribute types", %{model: model} do
      {:ok, model} = AbacModel.add_attribute(model, "alice", "department", "engineering")
      {:ok, model} = AbacModel.add_attribute(model, "alice", "clearance", 3)
      {:ok, model} = AbacModel.add_attribute(model, "alice", "active", true)

      {:ok, updated_model} =
        AbacModel.add_attribute(model, "alice", "skills", ["elixir", "python"])

      assert AbacModel.get_attribute(updated_model, "alice", "department") == "engineering"
      assert AbacModel.get_attribute(updated_model, "alice", "clearance") == 3
      assert AbacModel.get_attribute(updated_model, "alice", "active") == true
      assert AbacModel.get_attribute(updated_model, "alice", "skills") == ["elixir", "python"]
    end
  end

  describe "remove_attribute/3" do
    test "removes an attribute for a subject", %{model: model} do
      {:ok, model} = AbacModel.add_attribute(model, "alice", "department", "engineering")
      {:ok, updated_model} = AbacModel.remove_attribute(model, "alice", "department")

      assert AbacModel.get_attribute(updated_model, "alice", "department") == nil
    end

    test "returns error when subject not found", %{model: model} do
      {:error, :subject_not_found} =
        AbacModel.remove_attribute(model, "nonexistent", "department")
    end

    test "returns error when attribute not found", %{model: model} do
      {:ok, model} = AbacModel.add_attribute(model, "alice", "department", "engineering")
      {:error, :attribute_not_found} = AbacModel.remove_attribute(model, "alice", "nonexistent")
    end

    test "removes subject when no attributes remain", %{model: model} do
      {:ok, model} = AbacModel.add_attribute(model, "alice", "department", "engineering")
      {:ok, updated_model} = AbacModel.remove_attribute(model, "alice", "department")

      subjects = AbacModel.get_all_subjects(updated_model)
      refute "alice" in subjects
    end
  end

  describe "get_attributes/2" do
    test "returns all attributes for a subject", %{model: model} do
      {:ok, model} = AbacModel.add_attribute(model, "alice", "department", "engineering")
      {:ok, updated_model} = AbacModel.add_attribute(model, "alice", "level", "senior")

      attributes = AbacModel.get_attributes(updated_model, "alice")

      assert attributes == %{"department" => "engineering", "level" => "senior"}
    end

    test "returns empty map for subject without attributes", %{model: model} do
      attributes = AbacModel.get_attributes(model, "nonexistent")
      assert attributes == %{}
    end
  end

  describe "get_attribute/3" do
    test "returns specific attribute value", %{model: model} do
      {:ok, updated_model} = AbacModel.add_attribute(model, "alice", "department", "engineering")

      assert AbacModel.get_attribute(updated_model, "alice", "department") == "engineering"
    end

    test "returns nil for non-existent attribute", %{model: model} do
      assert AbacModel.get_attribute(model, "alice", "department") == nil
    end
  end

  describe "set_attributes/3" do
    test "sets multiple attributes for a subject", %{model: model} do
      attributes = %{
        "department" => "engineering",
        "level" => "senior",
        "clearance" => 3
      }

      {:ok, updated_model} = AbacModel.set_attributes(model, "alice", attributes)

      assert AbacModel.get_attribute(updated_model, "alice", "department") == "engineering"
      assert AbacModel.get_attribute(updated_model, "alice", "level") == "senior"
      assert AbacModel.get_attribute(updated_model, "alice", "clearance") == 3
    end

    test "merges with existing attributes", %{model: model} do
      {:ok, model} = AbacModel.add_attribute(model, "alice", "existing", "value")

      new_attributes = %{
        "department" => "engineering",
        "level" => "senior"
      }

      {:ok, updated_model} = AbacModel.set_attributes(model, "alice", new_attributes)

      assert AbacModel.get_attribute(updated_model, "alice", "existing") == "value"
      assert AbacModel.get_attribute(updated_model, "alice", "department") == "engineering"
      assert AbacModel.get_attribute(updated_model, "alice", "level") == "senior"
    end
  end

  describe "register_attribute_provider/3" do
    test "registers a dynamic attribute provider", %{model: model} do
      provider = {MyModule, :get_location, []}
      {:ok, updated_model} = AbacModel.register_attribute_provider(model, "location", provider)

      assert updated_model.attribute_providers["location"] == provider
    end
  end

  describe "unregister_attribute_provider/2" do
    test "removes a dynamic attribute provider", %{model: model} do
      provider = {MyModule, :get_location, []}
      {:ok, model} = AbacModel.register_attribute_provider(model, "location", provider)
      {:ok, updated_model} = AbacModel.unregister_attribute_provider(model, "location")

      refute Map.has_key?(updated_model.attribute_providers, "location")
    end
  end

  describe "evaluate_policy/5" do
    test "returns false when model is disabled", %{model: model} do
      disabled_model = AbacModel.set_enabled(model, false)

      result = AbacModel.evaluate_policy(disabled_model, "alice", "document1", "read")
      assert result == false
    end

    test "evaluates policy based on default rules", %{model: model} do
      {:ok, model} = AbacModel.add_attribute(model, "alice", "department", "engineering")

      # This should match the default rule: department == 'engineering' and action == 'read'
      result = AbacModel.evaluate_policy(model, "alice", "document1", "read")
      assert result == true
    end

    test "evaluates policy based on clearance level", %{model: model} do
      {:ok, model} = AbacModel.add_attribute(model, "alice", "clearance", 5)

      # This should match the default rule: clearance >= 3
      result = AbacModel.evaluate_policy(model, "alice", "document1", "read")
      assert result == true
    end

    test "evaluates policy based on ownership", %{model: model} do
      {:ok, model} = AbacModel.add_attribute(model, "alice", "user_id", "document1")

      # This should match the default rule: user_id == object (owner access)
      result = AbacModel.evaluate_policy(model, "alice", "document1", "delete")
      assert result == true
    end

    test "returns false when no rules match", %{model: model} do
      {:ok, model} = AbacModel.add_attribute(model, "alice", "department", "marketing")

      result = AbacModel.evaluate_policy(model, "alice", "document1", "read")
      assert result == false
    end
  end

  describe "add_policy_template/2" do
    test "adds a policy template", %{model: model} do
      template = "subject_attrs.role == 'admin'"
      {:ok, updated_model} = AbacModel.add_policy_template(model, template)

      templates = AbacModel.get_policy_templates(updated_model)
      assert template in templates
    end

    test "prevents duplicate templates", %{model: model} do
      template = "subject_attrs.role == 'admin'"
      {:ok, model} = AbacModel.add_policy_template(model, template)
      {:ok, updated_model} = AbacModel.add_policy_template(model, template)

      templates = AbacModel.get_policy_templates(updated_model)
      assert Enum.count(templates, &(&1 == template)) == 1
    end
  end

  describe "remove_policy_template/2" do
    test "removes a policy template", %{model: model} do
      template = "subject_attrs.role == 'admin'"
      {:ok, model} = AbacModel.add_policy_template(model, template)
      {:ok, updated_model} = AbacModel.remove_policy_template(model, template)

      templates = AbacModel.get_policy_templates(updated_model)
      refute template in templates
    end
  end

  describe "get_policy_templates/1" do
    test "returns all policy templates", %{model: model} do
      template1 = "subject_attrs.role == 'admin'"
      template2 = "subject_attrs.department == 'engineering'"

      {:ok, model} = AbacModel.add_policy_template(model, template1)
      {:ok, updated_model} = AbacModel.add_policy_template(model, template2)

      templates = AbacModel.get_policy_templates(updated_model)
      assert template1 in templates
      assert template2 in templates
    end
  end

  describe "set_enabled/2" do
    test "enables and disables the model", %{model: model} do
      assert AbacModel.enabled?(model) == true

      disabled_model = AbacModel.set_enabled(model, false)
      assert AbacModel.enabled?(disabled_model) == false

      enabled_model = AbacModel.set_enabled(disabled_model, true)
      assert AbacModel.enabled?(enabled_model) == true
    end
  end

  describe "get_all_subjects/1" do
    test "returns all subjects with attributes", %{model: model} do
      {:ok, model} = AbacModel.add_attribute(model, "alice", "department", "engineering")
      {:ok, updated_model} = AbacModel.add_attribute(model, "bob", "department", "marketing")

      subjects = AbacModel.get_all_subjects(updated_model)
      assert "alice" in subjects
      assert "bob" in subjects
    end

    test "returns empty list when no subjects", %{model: model} do
      subjects = AbacModel.get_all_subjects(model)
      assert subjects == []
    end
  end

  describe "get_all_attribute_names/1" do
    test "returns all attribute names including static and dynamic", %{model: model} do
      {:ok, model} = AbacModel.add_attribute(model, "alice", "department", "engineering")
      {:ok, model} = AbacModel.add_attribute(model, "bob", "level", "junior")

      {:ok, updated_model} =
        AbacModel.register_attribute_provider(model, "location", {MyModule, :get_location, []})

      attribute_names = AbacModel.get_all_attribute_names(updated_model)
      assert "department" in attribute_names
      assert "level" in attribute_names
      assert "location" in attribute_names
    end
  end

  describe "find_subjects_by_attribute/3" do
    test "finds subjects with specific attribute values", %{model: model} do
      {:ok, model} = AbacModel.add_attribute(model, "alice", "department", "engineering")
      {:ok, model} = AbacModel.add_attribute(model, "bob", "department", "engineering")
      {:ok, updated_model} = AbacModel.add_attribute(model, "charlie", "department", "marketing")

      engineering_subjects =
        AbacModel.find_subjects_by_attribute(updated_model, "department", "engineering")

      assert "alice" in engineering_subjects
      assert "bob" in engineering_subjects
      refute "charlie" in engineering_subjects
    end

    test "returns empty list when no matches", %{model: model} do
      {:ok, updated_model} = AbacModel.add_attribute(model, "alice", "department", "engineering")

      subjects = AbacModel.find_subjects_by_attribute(updated_model, "department", "nonexistent")
      assert subjects == []
    end
  end

  describe "clear_attributes/1" do
    test "clears all attributes", %{model: model} do
      {:ok, model} = AbacModel.add_attribute(model, "alice", "department", "engineering")
      {:ok, model} = AbacModel.add_attribute(model, "bob", "level", "senior")

      cleared_model = AbacModel.clear_attributes(model)

      assert AbacModel.get_all_subjects(cleared_model) == []
      assert cleared_model.attributes == %{}
    end
  end

  describe "clear_cache/1" do
    test "clears expression cache", %{model: model} do
      # Add some cache entries (normally done during evaluation)
      model_with_cache = %{model | expression_cache: %{"rule1" => :result}}

      cleared_model = AbacModel.clear_cache(model_with_cache)

      assert cleared_model.expression_cache == %{}
    end
  end

  describe "complex scenarios" do
    test "evaluates complex attribute combinations", %{model: model} do
      {:ok, model} = AbacModel.add_attribute(model, "alice", "department", "engineering")
      {:ok, model} = AbacModel.add_attribute(model, "alice", "clearance", 5)
      {:ok, updated_model} = AbacModel.add_attribute(model, "alice", "user_id", "alice")

      # Multiple rules should match
      result1 = AbacModel.evaluate_policy(updated_model, "alice", "document1", "read")
      assert result1 == true

      result2 = AbacModel.evaluate_policy(updated_model, "alice", "alice", "delete")
      assert result2 == true
    end

    test "handles missing attributes gracefully", %{model: model} do
      # No attributes set for alice
      result = AbacModel.evaluate_policy(model, "alice", "document1", "read")
      assert result == false
    end

    test "supports nested attribute structures", %{model: model} do
      nested_attrs = %{
        "profile" => %{
          "department" => "engineering",
          "team" => "backend"
        },
        "permissions" => ["read", "write"]
      }

      {:ok, updated_model} = AbacModel.set_attributes(model, "alice", nested_attrs)

      profile = AbacModel.get_attribute(updated_model, "alice", "profile")
      assert profile["department"] == "engineering"
      assert profile["team"] == "backend"

      permissions = AbacModel.get_attribute(updated_model, "alice", "permissions")
      assert "read" in permissions
      assert "write" in permissions
    end
  end
end
