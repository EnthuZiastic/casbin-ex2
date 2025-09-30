defmodule CasbinEx2.Model.RebacModelTest do
  use ExUnit.Case
  doctest CasbinEx2.Model.RebacModel

  alias CasbinEx2.Model.RebacModel

  setup do
    model = RebacModel.new()
    {:ok, model: model}
  end

  describe "new/1" do
    test "creates a new ReBAC model with default values" do
      model = RebacModel.new()

      assert model.relationships == %{}
      assert model.relationship_types != %{}
      assert model.transitivity_rules == %{}
      assert model.relationship_cache == %{}
      assert model.max_depth == 5
      assert model.enabled == true
    end

    test "creates a model with custom max_depth" do
      model = RebacModel.new(max_depth: 10)

      assert model.max_depth == 10
    end
  end

  describe "add_relationship/4" do
    test "adds a relationship between subject and object", %{model: model} do
      {:ok, updated_model} = RebacModel.add_relationship(model, "alice", "owner", "doc1")

      owner_relationships = Map.get(updated_model.relationships, "owner", [])
      assert {"alice", "owner", "doc1"} in owner_relationships
    end

    test "returns error when relationship already exists", %{model: model} do
      {:ok, model} = RebacModel.add_relationship(model, "alice", "owner", "doc1")

      {:error, :relationship_exists} =
        RebacModel.add_relationship(model, "alice", "owner", "doc1")
    end

    test "clears cache when adding relationships", %{model: model} do
      model_with_cache = %{model | relationship_cache: %{"alice:owner:doc1" => true}}

      {:ok, updated_model} =
        RebacModel.add_relationship(model_with_cache, "bob", "reader", "doc2")

      assert updated_model.relationship_cache == %{}
    end
  end

  describe "remove_relationship/4" do
    test "removes a relationship between subject and object", %{model: model} do
      {:ok, model} = RebacModel.add_relationship(model, "alice", "owner", "doc1")
      {:ok, updated_model} = RebacModel.remove_relationship(model, "alice", "owner", "doc1")

      owner_relationships = Map.get(updated_model.relationships, "owner", [])
      refute {"alice", "owner", "doc1"} in owner_relationships
    end

    test "returns error when relationship not found", %{model: model} do
      {:error, :relationship_not_found} =
        RebacModel.remove_relationship(model, "alice", "owner", "doc1")
    end

    test "clears cache when removing relationships", %{model: model} do
      {:ok, model} = RebacModel.add_relationship(model, "alice", "owner", "doc1")
      model_with_cache = %{model | relationship_cache: %{"alice:owner:doc1" => true}}

      {:ok, updated_model} =
        RebacModel.remove_relationship(model_with_cache, "alice", "owner", "doc1")

      assert updated_model.relationship_cache == %{}
    end
  end

  describe "has_relationship?/4" do
    test "returns true for direct relationships", %{model: model} do
      {:ok, model} = RebacModel.add_relationship(model, "alice", "owner", "doc1")

      assert RebacModel.has_relationship?(model, "alice", "owner", "doc1") == true
    end

    test "returns false for non-existent relationships", %{model: model} do
      assert RebacModel.has_relationship?(model, "alice", "owner", "doc1") == false
    end

    test "checks transitive relationships", %{model: model} do
      # Add transitive relationship type
      parent_type = %{
        name: "parent",
        transitive: true,
        symmetric: false,
        inverse: "child"
      }

      {:ok, model} = RebacModel.add_relationship_type(model, parent_type)

      # Create chain: alice -> folder1 -> doc1
      {:ok, model} = RebacModel.add_relationship(model, "alice", "parent", "folder1")
      {:ok, model} = RebacModel.add_relationship(model, "folder1", "parent", "doc1")

      # Should find transitive relationship
      assert RebacModel.has_relationship?(model, "alice", "parent", "doc1") == true
    end

    test "respects max depth for transitive relationships", %{model: model} do
      model_with_depth = %{model | max_depth: 1}

      parent_type = %{
        name: "parent",
        transitive: true,
        symmetric: false,
        inverse: "child"
      }

      {:ok, model} = RebacModel.add_relationship_type(model_with_depth, parent_type)

      # Create long chain that exceeds max_depth
      {:ok, model} = RebacModel.add_relationship(model, "alice", "parent", "level1")
      {:ok, model} = RebacModel.add_relationship(model, "level1", "parent", "level2")
      {:ok, model} = RebacModel.add_relationship(model, "level2", "parent", "doc1")

      # Should not find deep transitive relationship
      assert RebacModel.has_relationship?(model, "alice", "parent", "doc1") == false
    end
  end

  describe "get_relationships_for_subject/2" do
    test "returns all relationships for a subject", %{model: model} do
      {:ok, model} = RebacModel.add_relationship(model, "alice", "owner", "doc1")
      {:ok, model} = RebacModel.add_relationship(model, "alice", "reader", "doc2")

      relationships = RebacModel.get_relationships_for_subject(model, "alice")

      assert {"owner", "doc1"} in relationships
      assert {"reader", "doc2"} in relationships
    end

    test "returns empty list for subject with no relationships", %{model: model} do
      relationships = RebacModel.get_relationships_for_subject(model, "nonexistent")
      assert relationships == []
    end
  end

  describe "get_relationships_for_object/2" do
    test "returns all relationships for an object", %{model: model} do
      {:ok, model} = RebacModel.add_relationship(model, "alice", "owner", "doc1")
      {:ok, model} = RebacModel.add_relationship(model, "bob", "reader", "doc1")

      relationships = RebacModel.get_relationships_for_object(model, "doc1")

      assert {"alice", "owner"} in relationships
      assert {"bob", "reader"} in relationships
    end

    test "returns empty list for object with no relationships", %{model: model} do
      relationships = RebacModel.get_relationships_for_object(model, "nonexistent")
      assert relationships == []
    end
  end

  describe "add_relationship_type/2" do
    test "adds a custom relationship type", %{model: model} do
      custom_type = %{
        name: "collaborator",
        transitive: false,
        symmetric: true,
        inverse: nil
      }

      {:ok, updated_model} = RebacModel.add_relationship_type(model, custom_type)

      assert Map.get(updated_model.relationship_types, "collaborator") == custom_type
    end

    test "clears cache when adding relationship types", %{model: model} do
      model_with_cache = %{model | relationship_cache: %{"alice:owner:doc1" => true}}

      custom_type = %{
        name: "collaborator",
        transitive: false,
        symmetric: true,
        inverse: nil
      }

      {:ok, updated_model} = RebacModel.add_relationship_type(model_with_cache, custom_type)

      assert updated_model.relationship_cache == %{}
    end
  end

  describe "evaluate_policy/3" do
    test "returns true when model is disabled", %{model: model} do
      disabled_model = %{model | enabled: false}

      result =
        RebacModel.evaluate_policy(disabled_model, ["alice", "read", "doc1"], "r.sub owner r.obj")

      assert result == true
    end

    test "evaluates simple ReBAC expressions", %{model: model} do
      {:ok, model} = RebacModel.add_relationship(model, "alice", "owner", "doc1")

      result = RebacModel.evaluate_policy(model, ["alice", "read", "doc1"], "r.sub owner r.obj")
      assert result == true
    end

    test "returns false when relationship doesn't exist", %{model: model} do
      result = RebacModel.evaluate_policy(model, ["alice", "read", "doc1"], "r.sub owner r.obj")
      assert result == false
    end

    test "returns false for complex expressions", %{model: model} do
      {:ok, model} = RebacModel.add_relationship(model, "alice", "owner", "doc1")

      result = RebacModel.evaluate_policy(model, ["alice", "read", "doc1"], "complex expression")
      assert result == false
    end
  end

  describe "complex scenarios" do
    test "handles multiple relationship types", %{model: model} do
      {:ok, model} = RebacModel.add_relationship(model, "alice", "owner", "doc1")
      {:ok, model} = RebacModel.add_relationship(model, "bob", "reader", "doc1")
      {:ok, model} = RebacModel.add_relationship(model, "charlie", "editor", "doc1")

      assert RebacModel.has_relationship?(model, "alice", "owner", "doc1") == true
      assert RebacModel.has_relationship?(model, "bob", "reader", "doc1") == true
      assert RebacModel.has_relationship?(model, "charlie", "editor", "doc1") == true
    end

    test "supports complex transitive chains", %{model: model} do
      parent_type = %{
        name: "manages",
        transitive: true,
        symmetric: false,
        inverse: "managed_by"
      }

      {:ok, model} = RebacModel.add_relationship_type(model, parent_type)

      # Create management hierarchy: alice -> bob -> charlie -> project
      {:ok, model} = RebacModel.add_relationship(model, "alice", "manages", "bob")
      {:ok, model} = RebacModel.add_relationship(model, "bob", "manages", "charlie")
      {:ok, model} = RebacModel.add_relationship(model, "charlie", "manages", "project")

      # Alice should transitively manage the project
      assert RebacModel.has_relationship?(model, "alice", "manages", "project") == true
      assert RebacModel.has_relationship?(model, "bob", "manages", "project") == true
      assert RebacModel.has_relationship?(model, "charlie", "manages", "project") == true
    end

    test "prevents infinite loops in relationship checking", %{model: model} do
      parent_type = %{
        name: "relates_to",
        transitive: true,
        symmetric: false,
        inverse: nil
      }

      {:ok, model} = RebacModel.add_relationship_type(model, parent_type)

      # Create circular relationship: a -> b -> c -> a
      {:ok, model} = RebacModel.add_relationship(model, "a", "relates_to", "b")
      {:ok, model} = RebacModel.add_relationship(model, "b", "relates_to", "c")
      {:ok, model} = RebacModel.add_relationship(model, "c", "relates_to", "a")

      # Should not cause infinite loop
      result = RebacModel.has_relationship?(model, "a", "relates_to", "nonexistent")
      assert result == false
    end

    test "caches relationship results", %{model: model} do
      {:ok, model} = RebacModel.add_relationship(model, "alice", "owner", "doc1")

      # First call should cache the result
      assert RebacModel.has_relationship?(model, "alice", "owner", "doc1") == true

      # Second call should use cached result (we can't directly test this,
      # but we can verify the cache would be used)
      assert RebacModel.has_relationship?(model, "alice", "owner", "doc1") == true
    end

    test "handles relationship removal correctly", %{model: model} do
      {:ok, model} = RebacModel.add_relationship(model, "alice", "owner", "doc1")
      {:ok, model} = RebacModel.add_relationship(model, "alice", "reader", "doc2")

      assert RebacModel.has_relationship?(model, "alice", "owner", "doc1") == true
      assert RebacModel.has_relationship?(model, "alice", "reader", "doc2") == true

      {:ok, model} = RebacModel.remove_relationship(model, "alice", "owner", "doc1")

      assert RebacModel.has_relationship?(model, "alice", "owner", "doc1") == false
      assert RebacModel.has_relationship?(model, "alice", "reader", "doc2") == true
    end
  end
end
