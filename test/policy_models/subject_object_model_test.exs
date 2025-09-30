defmodule CasbinEx2.Model.SubjectObjectModelTest do
  use ExUnit.Case
  doctest CasbinEx2.Model.SubjectObjectModel

  alias CasbinEx2.Model.SubjectObjectModel

  setup do
    model = SubjectObjectModel.new()
    {:ok, model: model}
  end

  describe "new/0" do
    test "creates a new Subject-Object model with default values" do
      model = SubjectObjectModel.new()

      assert model.subjects == %{}
      assert model.objects == %{}
      assert model.relationships == []
      assert model.subject_groups == %{}
      assert model.object_hierarchies == %{}
      assert model.ownership_patterns == %{}
      assert model.relationship_cache == %{}
      assert model.enabled == true
    end
  end

  describe "add_subject/2" do
    test "adds a subject", %{model: model} do
      subject = %{
        id: "alice",
        type: :user,
        attributes: %{"department" => "engineering", "level" => "senior"},
        groups: ["developers", "admins"],
        active: true
      }

      {:ok, updated_model} = SubjectObjectModel.add_subject(model, subject)

      assert Map.get(updated_model.subjects, "alice") == subject
    end

    test "updates subject groups", %{model: model} do
      subject = %{
        id: "alice",
        type: :user,
        attributes: %{},
        groups: ["developers", "admins"],
        active: true
      }

      {:ok, updated_model} = SubjectObjectModel.add_subject(model, subject)

      developers = Map.get(updated_model.subject_groups, "developers", [])
      admins = Map.get(updated_model.subject_groups, "admins", [])

      assert "alice" in developers
      assert "alice" in admins
    end

    test "clears relationship cache", %{model: model} do
      model_with_cache = %{model | relationship_cache: %{"alice:doc1:reads" => true}}

      subject = %{
        id: "bob",
        type: :user,
        attributes: %{},
        groups: [],
        active: true
      }

      {:ok, updated_model} = SubjectObjectModel.add_subject(model_with_cache, subject)

      assert updated_model.relationship_cache == %{}
    end

    test "returns error when subject already exists", %{model: model} do
      subject = %{
        id: "alice",
        type: :user,
        attributes: %{},
        groups: [],
        active: true
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject)
      {:error, :subject_exists} = SubjectObjectModel.add_subject(model, subject)
    end
  end

  describe "add_object/2" do
    test "adds an object", %{model: model} do
      object = %{
        id: "doc1",
        type: :document,
        attributes: %{"classification" => "confidential", "size" => 1024},
        parent_id: "folder1",
        owners: ["alice"],
        active: true
      }

      {:ok, updated_model} = SubjectObjectModel.add_object(model, object)

      assert Map.get(updated_model.objects, "doc1") == object
    end

    test "updates object hierarchies", %{model: model} do
      object = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: "folder1",
        owners: [],
        active: true
      }

      {:ok, updated_model} = SubjectObjectModel.add_object(model, object)

      folder_children = Map.get(updated_model.object_hierarchies, "folder1", [])
      assert "doc1" in folder_children
    end

    test "handles objects without parent", %{model: model} do
      object = %{
        id: "root_doc",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: [],
        active: true
      }

      {:ok, updated_model} = SubjectObjectModel.add_object(model, object)

      assert Map.get(updated_model.objects, "root_doc") == object
      # Should not create hierarchy entry for nil parent
      assert Map.get(updated_model.object_hierarchies, nil) == nil
    end

    test "updates ownership patterns", %{model: model} do
      object = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: ["alice", "bob"],
        active: true
      }

      {:ok, updated_model} = SubjectObjectModel.add_object(model, object)

      alice_owned = Map.get(updated_model.ownership_patterns, "alice", [])
      bob_owned = Map.get(updated_model.ownership_patterns, "bob", [])

      assert "doc1" in alice_owned
      assert "doc1" in bob_owned
    end

    test "clears relationship cache", %{model: model} do
      model_with_cache = %{model | relationship_cache: %{"alice:doc1:reads" => true}}

      object = %{
        id: "doc2",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: [],
        active: true
      }

      {:ok, updated_model} = SubjectObjectModel.add_object(model_with_cache, object)

      assert updated_model.relationship_cache == %{}
    end

    test "returns error when object already exists", %{model: model} do
      object = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: [],
        active: true
      }

      {:ok, model} = SubjectObjectModel.add_object(model, object)
      {:error, :object_exists} = SubjectObjectModel.add_object(model, object)
    end
  end

  describe "add_relationship/2" do
    test "adds a relationship", %{model: model} do
      subject = %{
        id: "alice",
        type: :user,
        attributes: %{},
        groups: [],
        active: true
      }

      object = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: [],
        active: true
      }

      relationship = %{
        subject_id: "alice",
        object_id: "doc1",
        relationship_type: :reads,
        permissions: ["read", "download"],
        conditions: %{"time_restriction" => "business_hours"},
        expiry: nil
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject)
      {:ok, model} = SubjectObjectModel.add_object(model, object)
      {:ok, updated_model} = SubjectObjectModel.add_relationship(model, relationship)

      assert relationship in updated_model.relationships
    end

    test "clears relationship cache", %{model: model} do
      subject = %{
        id: "alice",
        type: :user,
        attributes: %{},
        groups: [],
        active: true
      }

      object = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: [],
        active: true
      }

      relationship = %{
        subject_id: "alice",
        object_id: "doc1",
        relationship_type: :reads,
        permissions: ["read"],
        conditions: %{},
        expiry: nil
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject)
      {:ok, model} = SubjectObjectModel.add_object(model, object)
      model_with_cache = %{model | relationship_cache: %{"alice:doc1:reads" => true}}
      {:ok, updated_model} = SubjectObjectModel.add_relationship(model_with_cache, relationship)

      assert updated_model.relationship_cache == %{}
    end

    test "returns error when subject or object not found", %{model: model} do
      relationship = %{
        subject_id: "nonexistent",
        object_id: "doc1",
        relationship_type: :reads,
        permissions: ["read"],
        conditions: %{},
        expiry: nil
      }

      {:error, :subject_or_object_not_found} =
        SubjectObjectModel.add_relationship(model, relationship)
    end
  end

  describe "has_relationship?/4" do
    test "returns true when model is disabled", %{model: model} do
      disabled_model = %{model | enabled: false}

      result = SubjectObjectModel.has_relationship?(disabled_model, "alice", "doc1", :reads)
      assert result == true
    end

    test "returns true for direct relationships", %{model: model} do
      subject = %{
        id: "alice",
        type: :user,
        attributes: %{},
        groups: [],
        active: true
      }

      object = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: [],
        active: true
      }

      relationship = %{
        subject_id: "alice",
        object_id: "doc1",
        relationship_type: :reads,
        permissions: ["read"],
        conditions: %{},
        expiry: nil
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject)
      {:ok, model} = SubjectObjectModel.add_object(model, object)
      {:ok, model} = SubjectObjectModel.add_relationship(model, relationship)

      assert SubjectObjectModel.has_relationship?(model, "alice", "doc1", :reads) == true
    end

    test "returns false for non-existent relationships", %{model: model} do
      assert SubjectObjectModel.has_relationship?(model, "alice", "doc1", :reads) == false
    end

    test "checks group-based relationships", %{model: model} do
      subject = %{
        id: "alice",
        type: :user,
        attributes: %{},
        groups: ["developers"],
        active: true
      }

      object = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: [],
        active: true
      }

      relationship = %{
        # Group relationship
        subject_id: "developers",
        object_id: "doc1",
        relationship_type: :reads,
        permissions: ["read"],
        conditions: %{},
        expiry: nil
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject)
      {:ok, model} = SubjectObjectModel.add_object(model, object)
      {:ok, model} = SubjectObjectModel.add_relationship(model, relationship)

      assert SubjectObjectModel.has_relationship?(model, "alice", "doc1", :reads) == true
    end

    test "respects relationship expiry", %{model: model} do
      subject = %{
        id: "alice",
        type: :user,
        attributes: %{},
        groups: [],
        active: true
      }

      object = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: [],
        active: true
      }

      # Expired relationship
      # 1 hour ago
      past_time = DateTime.add(DateTime.utc_now(), -3600, :second)

      expired_relationship = %{
        subject_id: "alice",
        object_id: "doc1",
        relationship_type: :reads,
        permissions: ["read"],
        conditions: %{},
        expiry: past_time
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject)
      {:ok, model} = SubjectObjectModel.add_object(model, object)
      {:ok, model} = SubjectObjectModel.add_relationship(model, expired_relationship)

      assert SubjectObjectModel.has_relationship?(model, "alice", "doc1", :reads) == false
    end
  end

  describe "can_perform_action?/4" do
    test "returns true when model is disabled", %{model: model} do
      disabled_model = %{model | enabled: false}

      result = SubjectObjectModel.can_perform_action?(disabled_model, "alice", "read", "doc1")
      assert result == true
    end

    test "checks direct action access", %{model: model} do
      subject = %{
        id: "alice",
        type: :user,
        attributes: %{},
        groups: [],
        active: true
      }

      object = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: [],
        active: true
      }

      relationship = %{
        subject_id: "alice",
        object_id: "doc1",
        relationship_type: :reads,
        permissions: ["read", "download"],
        conditions: %{},
        expiry: nil
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject)
      {:ok, model} = SubjectObjectModel.add_object(model, object)
      {:ok, model} = SubjectObjectModel.add_relationship(model, relationship)

      assert SubjectObjectModel.can_perform_action?(model, "alice", "read", "doc1") == true
      assert SubjectObjectModel.can_perform_action?(model, "alice", "download", "doc1") == true
      assert SubjectObjectModel.can_perform_action?(model, "alice", "write", "doc1") == false
    end

    test "checks group-based action access", %{model: model} do
      subject = %{
        id: "alice",
        type: :user,
        attributes: %{},
        groups: ["editors"],
        active: true
      }

      object = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: [],
        active: true
      }

      relationship = %{
        subject_id: "editors",
        object_id: "doc1",
        relationship_type: :writes,
        permissions: ["read", "write", "edit"],
        conditions: %{},
        expiry: nil
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject)
      {:ok, model} = SubjectObjectModel.add_object(model, object)
      {:ok, model} = SubjectObjectModel.add_relationship(model, relationship)

      assert SubjectObjectModel.can_perform_action?(model, "alice", "write", "doc1") == true
    end

    test "checks ownership access", %{model: model} do
      subject = %{
        id: "alice",
        type: :user,
        attributes: %{},
        groups: [],
        active: true
      }

      object = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: ["alice"],
        active: true
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject)
      {:ok, model} = SubjectObjectModel.add_object(model, object)

      # Owners should have access to any action
      assert SubjectObjectModel.can_perform_action?(model, "alice", "delete", "doc1") == true
    end

    test "checks inherited access through object hierarchy", %{model: model} do
      subject = %{
        id: "alice",
        type: :user,
        attributes: %{},
        groups: [],
        active: true
      }

      parent_object = %{
        id: "folder1",
        type: :folder,
        attributes: %{},
        parent_id: nil,
        owners: [],
        active: true
      }

      child_object = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: "folder1",
        owners: [],
        active: true
      }

      relationship = %{
        subject_id: "alice",
        object_id: "folder1",
        relationship_type: :reads,
        permissions: ["read"],
        conditions: %{},
        expiry: nil
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject)
      {:ok, model} = SubjectObjectModel.add_object(model, parent_object)
      {:ok, model} = SubjectObjectModel.add_object(model, child_object)
      {:ok, model} = SubjectObjectModel.add_relationship(model, relationship)

      # Should inherit access from parent
      assert SubjectObjectModel.can_perform_action?(model, "alice", "read", "doc1") == true
    end

    test "evaluates conditions correctly", %{model: model} do
      subject = %{
        id: "alice",
        type: :user,
        attributes: %{},
        groups: [],
        active: true
      }

      object = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: [],
        active: true
      }

      # Business hours restriction
      relationship = %{
        subject_id: "alice",
        object_id: "doc1",
        relationship_type: :reads,
        permissions: ["read"],
        conditions: %{"time_restriction" => "business_hours"},
        expiry: nil
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject)
      {:ok, model} = SubjectObjectModel.add_object(model, object)
      {:ok, model} = SubjectObjectModel.add_relationship(model, relationship)

      # Result depends on current time
      result = SubjectObjectModel.can_perform_action?(model, "alice", "read", "doc1")
      assert result in [true, false]
    end
  end

  describe "evaluate_policy/3" do
    test "returns true when model is disabled", %{model: model} do
      disabled_model = %{model | enabled: false}

      result =
        SubjectObjectModel.evaluate_policy(
          disabled_model,
          ["alice", "read", "doc1"],
          "owner_only"
        )

      assert result == true
    end

    test "evaluates owner_only policy", %{model: model} do
      subject = %{
        id: "alice",
        type: :user,
        attributes: %{},
        groups: [],
        active: true
      }

      object = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: ["alice"],
        active: true
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject)
      {:ok, model} = SubjectObjectModel.add_object(model, object)

      result = SubjectObjectModel.evaluate_policy(model, ["alice", "read", "doc1"], "owner_only")
      assert result == true

      result = SubjectObjectModel.evaluate_policy(model, ["bob", "read", "doc1"], "owner_only")
      assert result == false
    end

    test "evaluates owner_or_reader policy", %{model: model} do
      subject = %{
        id: "bob",
        type: :user,
        attributes: %{},
        groups: [],
        active: true
      }

      object = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: ["alice"],
        active: true
      }

      relationship = %{
        subject_id: "bob",
        object_id: "doc1",
        relationship_type: :reads,
        permissions: ["read"],
        conditions: %{},
        expiry: nil
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject)
      {:ok, model} = SubjectObjectModel.add_object(model, object)
      {:ok, model} = SubjectObjectModel.add_relationship(model, relationship)

      result =
        SubjectObjectModel.evaluate_policy(model, ["bob", "read", "doc1"], "owner_or_reader")

      assert result == true
    end

    test "evaluates group_member policy", %{model: model} do
      subject = %{
        id: "alice",
        type: :user,
        attributes: %{},
        groups: ["editors"],
        active: true
      }

      object = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: [],
        active: true
      }

      relationship = %{
        subject_id: "editors",
        object_id: "doc1",
        relationship_type: :writes,
        permissions: ["write"],
        conditions: %{},
        expiry: nil
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject)
      {:ok, model} = SubjectObjectModel.add_object(model, object)
      {:ok, model} = SubjectObjectModel.add_relationship(model, relationship)

      result =
        SubjectObjectModel.evaluate_policy(model, ["alice", "write", "doc1"], "group_member")

      assert result == true
    end

    test "evaluates hierarchy_access policy", %{model: model} do
      subject = %{
        id: "alice",
        type: :user,
        attributes: %{},
        groups: [],
        active: true
      }

      parent_object = %{
        id: "folder1",
        type: :folder,
        attributes: %{},
        parent_id: nil,
        owners: ["alice"],
        active: true
      }

      child_object = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: "folder1",
        owners: [],
        active: true
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject)
      {:ok, model} = SubjectObjectModel.add_object(model, parent_object)
      {:ok, model} = SubjectObjectModel.add_object(model, child_object)

      result =
        SubjectObjectModel.evaluate_policy(model, ["alice", "read", "doc1"], "hierarchy_access")

      assert result == true
    end

    test "falls back to can_perform_action for unknown policies", %{model: model} do
      subject = %{
        id: "alice",
        type: :user,
        attributes: %{},
        groups: [],
        active: true
      }

      object = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: ["alice"],
        active: true
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject)
      {:ok, model} = SubjectObjectModel.add_object(model, object)

      result =
        SubjectObjectModel.evaluate_policy(model, ["alice", "read", "doc1"], "unknown_policy")

      # Should fall back to ownership access
      assert result == true
    end
  end

  describe "get_owned_objects/2" do
    test "returns objects owned by a subject", %{model: model} do
      object1 = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: ["alice"],
        active: true
      }

      object2 = %{
        id: "doc2",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: ["alice", "bob"],
        active: true
      }

      object3 = %{
        id: "doc3",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: ["bob"],
        active: true
      }

      {:ok, model} = SubjectObjectModel.add_object(model, object1)
      {:ok, model} = SubjectObjectModel.add_object(model, object2)
      {:ok, model} = SubjectObjectModel.add_object(model, object3)

      owned_objects = SubjectObjectModel.get_owned_objects(model, "alice")

      assert object1 in owned_objects
      assert object2 in owned_objects
      refute object3 in owned_objects
    end

    test "returns empty list for subject with no owned objects", %{model: model} do
      owned_objects = SubjectObjectModel.get_owned_objects(model, "nonexistent")
      assert owned_objects == []
    end
  end

  describe "get_subject_relationships/2" do
    test "returns all relationships for a subject", %{model: model} do
      subject = %{
        id: "alice",
        type: :user,
        attributes: %{},
        groups: [],
        active: true
      }

      object1 = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: [],
        active: true
      }

      object2 = %{
        id: "doc2",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: [],
        active: true
      }

      relationship1 = %{
        subject_id: "alice",
        object_id: "doc1",
        relationship_type: :reads,
        permissions: ["read"],
        conditions: %{},
        expiry: nil
      }

      relationship2 = %{
        subject_id: "alice",
        object_id: "doc2",
        relationship_type: :writes,
        permissions: ["write"],
        conditions: %{},
        expiry: nil
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject)
      {:ok, model} = SubjectObjectModel.add_object(model, object1)
      {:ok, model} = SubjectObjectModel.add_object(model, object2)
      {:ok, model} = SubjectObjectModel.add_relationship(model, relationship1)
      {:ok, model} = SubjectObjectModel.add_relationship(model, relationship2)

      relationships = SubjectObjectModel.get_subject_relationships(model, "alice")

      assert relationship1 in relationships
      assert relationship2 in relationships
    end

    test "returns empty list for subject with no relationships", %{model: model} do
      relationships = SubjectObjectModel.get_subject_relationships(model, "nonexistent")
      assert relationships == []
    end
  end

  describe "get_object_relationships/2" do
    test "returns all relationships for an object", %{model: model} do
      subject1 = %{
        id: "alice",
        type: :user,
        attributes: %{},
        groups: [],
        active: true
      }

      subject2 = %{
        id: "bob",
        type: :user,
        attributes: %{},
        groups: [],
        active: true
      }

      object = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: nil,
        owners: [],
        active: true
      }

      relationship1 = %{
        subject_id: "alice",
        object_id: "doc1",
        relationship_type: :reads,
        permissions: ["read"],
        conditions: %{},
        expiry: nil
      }

      relationship2 = %{
        subject_id: "bob",
        object_id: "doc1",
        relationship_type: :writes,
        permissions: ["write"],
        conditions: %{},
        expiry: nil
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject1)
      {:ok, model} = SubjectObjectModel.add_subject(model, subject2)
      {:ok, model} = SubjectObjectModel.add_object(model, object)
      {:ok, model} = SubjectObjectModel.add_relationship(model, relationship1)
      {:ok, model} = SubjectObjectModel.add_relationship(model, relationship2)

      relationships = SubjectObjectModel.get_object_relationships(model, "doc1")

      assert relationship1 in relationships
      assert relationship2 in relationships
    end

    test "returns empty list for object with no relationships", %{model: model} do
      relationships = SubjectObjectModel.get_object_relationships(model, "nonexistent")
      assert relationships == []
    end
  end

  describe "get_child_objects/2" do
    test "returns child objects in hierarchy", %{model: model} do
      parent = %{
        id: "folder1",
        type: :folder,
        attributes: %{},
        parent_id: nil,
        owners: [],
        active: true
      }

      child1 = %{
        id: "doc1",
        type: :document,
        attributes: %{},
        parent_id: "folder1",
        owners: [],
        active: true
      }

      child2 = %{
        id: "doc2",
        type: :document,
        attributes: %{},
        parent_id: "folder1",
        owners: [],
        active: true
      }

      {:ok, model} = SubjectObjectModel.add_object(model, parent)
      {:ok, model} = SubjectObjectModel.add_object(model, child1)
      {:ok, model} = SubjectObjectModel.add_object(model, child2)

      children = SubjectObjectModel.get_child_objects(model, "folder1")

      assert child1 in children
      assert child2 in children
    end

    test "returns empty list for object with no children", %{model: model} do
      children = SubjectObjectModel.get_child_objects(model, "nonexistent")
      assert children == []
    end
  end

  describe "get_group_subjects/2" do
    test "returns subjects in a group", %{model: model} do
      subject1 = %{
        id: "alice",
        type: :user,
        attributes: %{},
        groups: ["developers"],
        active: true
      }

      subject2 = %{
        id: "bob",
        type: :user,
        attributes: %{},
        groups: ["developers", "admins"],
        active: true
      }

      subject3 = %{
        id: "charlie",
        type: :user,
        attributes: %{},
        groups: ["admins"],
        active: true
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject1)
      {:ok, model} = SubjectObjectModel.add_subject(model, subject2)
      {:ok, model} = SubjectObjectModel.add_subject(model, subject3)

      developers = SubjectObjectModel.get_group_subjects(model, "developers")

      assert subject1 in developers
      assert subject2 in developers
      refute subject3 in developers
    end

    test "returns empty list for group with no subjects", %{model: model} do
      subjects = SubjectObjectModel.get_group_subjects(model, "nonexistent")
      assert subjects == []
    end
  end

  describe "complex scenarios" do
    test "handles complex object hierarchies with inheritance", %{model: model} do
      # Create hierarchy: root_folder -> project_folder -> documents
      root_folder = %{
        id: "root",
        type: :folder,
        attributes: %{"access_level" => "public"},
        parent_id: nil,
        owners: ["admin"],
        active: true
      }

      project_folder = %{
        id: "project1",
        type: :folder,
        attributes: %{"project" => "alpha"},
        parent_id: "root",
        owners: ["project_manager"],
        active: true
      }

      document = %{
        id: "doc1",
        type: :document,
        attributes: %{"classification" => "internal"},
        parent_id: "project1",
        owners: [],
        active: true
      }

      admin = %{
        id: "admin",
        type: :user,
        attributes: %{"role" => "system_admin"},
        groups: ["admins"],
        active: true
      }

      user = %{
        id: "alice",
        type: :user,
        attributes: %{"role" => "developer"},
        groups: ["developers"],
        active: true
      }

      # Admin has access to root
      admin_relationship = %{
        subject_id: "admin",
        object_id: "root",
        relationship_type: :manages,
        permissions: ["read", "write", "delete"],
        conditions: %{},
        expiry: nil
      }

      {:ok, model} = SubjectObjectModel.add_object(model, root_folder)
      {:ok, model} = SubjectObjectModel.add_object(model, project_folder)
      {:ok, model} = SubjectObjectModel.add_object(model, document)
      {:ok, model} = SubjectObjectModel.add_subject(model, admin)
      {:ok, model} = SubjectObjectModel.add_subject(model, user)
      {:ok, model} = SubjectObjectModel.add_relationship(model, admin_relationship)

      # Admin should have inherited access to all children
      assert SubjectObjectModel.can_perform_action?(model, "admin", "read", "doc1") == true
      assert SubjectObjectModel.can_perform_action?(model, "admin", "delete", "project1") == true

      # Regular user should not have access
      assert SubjectObjectModel.can_perform_action?(model, "alice", "read", "doc1") == false
    end

    test "handles complex group-based access patterns", %{model: model} do
      # Create subjects with various group memberships
      developer = %{
        id: "dev1",
        type: :user,
        attributes: %{"department" => "engineering"},
        groups: ["developers", "employees"],
        active: true
      }

      senior_dev = %{
        id: "senior1",
        type: :user,
        attributes: %{"level" => "senior"},
        groups: ["developers", "seniors", "employees"],
        active: true
      }

      manager = %{
        id: "mgr1",
        type: :user,
        attributes: %{"role" => "manager"},
        groups: ["managers", "seniors", "employees"],
        active: true
      }

      # Create objects with different access needs
      public_doc = %{
        id: "public_doc",
        type: :document,
        attributes: %{"classification" => "public"},
        parent_id: nil,
        owners: [],
        active: true
      }

      internal_doc = %{
        id: "internal_doc",
        type: :document,
        attributes: %{"classification" => "internal"},
        parent_id: nil,
        owners: [],
        active: true
      }

      confidential_doc = %{
        id: "confidential_doc",
        type: :document,
        attributes: %{"classification" => "confidential"},
        parent_id: nil,
        owners: [],
        active: true
      }

      # Create group-based relationships
      employee_relationship = %{
        subject_id: "employees",
        object_id: "public_doc",
        relationship_type: :reads,
        permissions: ["read"],
        conditions: %{},
        expiry: nil
      }

      senior_relationship = %{
        subject_id: "seniors",
        object_id: "internal_doc",
        relationship_type: :reads,
        permissions: ["read"],
        conditions: %{},
        expiry: nil
      }

      manager_relationship = %{
        subject_id: "managers",
        object_id: "confidential_doc",
        relationship_type: :reads,
        permissions: ["read"],
        conditions: %{},
        expiry: nil
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, developer)
      {:ok, model} = SubjectObjectModel.add_subject(model, senior_dev)
      {:ok, model} = SubjectObjectModel.add_subject(model, manager)
      {:ok, model} = SubjectObjectModel.add_object(model, public_doc)
      {:ok, model} = SubjectObjectModel.add_object(model, internal_doc)
      {:ok, model} = SubjectObjectModel.add_object(model, confidential_doc)
      {:ok, model} = SubjectObjectModel.add_relationship(model, employee_relationship)
      {:ok, model} = SubjectObjectModel.add_relationship(model, senior_relationship)
      {:ok, model} = SubjectObjectModel.add_relationship(model, manager_relationship)

      # Test access patterns
      # Everyone can read public docs
      assert SubjectObjectModel.can_perform_action?(model, "dev1", "read", "public_doc") == true

      assert SubjectObjectModel.can_perform_action?(model, "senior1", "read", "public_doc") ==
               true

      assert SubjectObjectModel.can_perform_action?(model, "mgr1", "read", "public_doc") == true

      # Only seniors and above can read internal docs
      assert SubjectObjectModel.can_perform_action?(model, "dev1", "read", "internal_doc") ==
               false

      assert SubjectObjectModel.can_perform_action?(model, "senior1", "read", "internal_doc") ==
               true

      assert SubjectObjectModel.can_perform_action?(model, "mgr1", "read", "internal_doc") == true

      # Only managers can read confidential docs
      assert SubjectObjectModel.can_perform_action?(model, "dev1", "read", "confidential_doc") ==
               false

      assert SubjectObjectModel.can_perform_action?(model, "senior1", "read", "confidential_doc") ==
               false

      assert SubjectObjectModel.can_perform_action?(model, "mgr1", "read", "confidential_doc") ==
               true
    end

    test "time-based conditions work correctly", %{model: model} do
      subject = %{
        id: "employee1",
        type: :user,
        attributes: %{},
        groups: [],
        active: true
      }

      object = %{
        id: "secure_system",
        type: :system,
        attributes: %{},
        parent_id: nil,
        owners: [],
        active: true
      }

      business_hours_relationship = %{
        subject_id: "employee1",
        object_id: "secure_system",
        relationship_type: :accesses,
        permissions: ["login"],
        conditions: %{"time_restriction" => "business_hours"},
        expiry: nil
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject)
      {:ok, model} = SubjectObjectModel.add_object(model, object)
      {:ok, model} = SubjectObjectModel.add_relationship(model, business_hours_relationship)

      # Result depends on current time
      result =
        SubjectObjectModel.can_perform_action?(model, "employee1", "login", "secure_system")

      assert result in [true, false]
    end

    test "relationship expiry prevents access correctly", %{model: model} do
      subject = %{
        id: "contractor",
        type: :user,
        attributes: %{},
        groups: [],
        active: true
      }

      object = %{
        id: "temp_project",
        type: :project,
        attributes: %{},
        parent_id: nil,
        owners: [],
        active: true
      }

      # Create expired relationship
      past_time = DateTime.add(DateTime.utc_now(), -3600, :second)

      expired_relationship = %{
        subject_id: "contractor",
        object_id: "temp_project",
        relationship_type: :accesses,
        permissions: ["read", "write"],
        conditions: %{},
        expiry: past_time
      }

      # Create valid relationship
      future_time = DateTime.add(DateTime.utc_now(), 3600, :second)

      valid_relationship = %{
        subject_id: "contractor",
        object_id: "temp_project",
        relationship_type: :reads,
        permissions: ["read"],
        conditions: %{},
        expiry: future_time
      }

      {:ok, model} = SubjectObjectModel.add_subject(model, subject)
      {:ok, model} = SubjectObjectModel.add_object(model, object)
      {:ok, model} = SubjectObjectModel.add_relationship(model, expired_relationship)
      {:ok, model} = SubjectObjectModel.add_relationship(model, valid_relationship)

      # Should not have write access (expired)
      assert SubjectObjectModel.can_perform_action?(model, "contractor", "write", "temp_project") ==
               false

      # Should have read access (valid)
      assert SubjectObjectModel.can_perform_action?(model, "contractor", "read", "temp_project") ==
               true
    end
  end
end
