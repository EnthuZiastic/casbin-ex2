defmodule CasbinEx2.Model.SubjectObjectModel do
  @moduledoc """
  Subject-Object Model for enhanced relationship management.

  Provides advanced subject-object relationship modeling with support for
  complex relationships, object hierarchies, subject groups, ownership patterns,
  and dynamic relationship resolution.
  """

  defstruct [
    :subjects,
    :objects,
    :relationships,
    :subject_groups,
    :object_hierarchies,
    :ownership_patterns,
    :relationship_cache,
    :enabled
  ]

  @type subject_type :: :user | :service | :application | :device
  @type object_type :: :document | :resource | :service | :data | :system
  @type relationship_type :: :owns | :reads | :writes | :executes | :manages | :accesses

  @type subject :: %{
          id: String.t(),
          type: subject_type(),
          attributes: %{String.t() => term()},
          groups: [String.t()],
          active: boolean()
        }

  @type object :: %{
          id: String.t(),
          type: object_type(),
          attributes: %{String.t() => term()},
          parent_id: String.t() | nil,
          owners: [String.t()],
          active: boolean()
        }

  @type relationship :: %{
          subject_id: String.t(),
          object_id: String.t(),
          relationship_type: relationship_type(),
          permissions: [String.t()],
          conditions: %{String.t() => term()},
          expiry: DateTime.t() | nil
        }

  @type t :: %__MODULE__{
          subjects: %{String.t() => subject()},
          objects: %{String.t() => object()},
          relationships: [relationship()],
          subject_groups: %{String.t() => [String.t()]},
          object_hierarchies: %{String.t() => [String.t()]},
          ownership_patterns: %{String.t() => [String.t()]},
          relationship_cache: %{String.t() => boolean()},
          enabled: boolean()
        }

  @doc """
  Creates a new Subject-Object model.

  ## Examples

      so_model = SubjectObjectModel.new()

  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      subjects: %{},
      objects: %{},
      relationships: [],
      subject_groups: %{},
      object_hierarchies: %{},
      ownership_patterns: %{},
      relationship_cache: %{},
      enabled: true
    }
  end

  @doc """
  Adds a subject.

  ## Examples

      subject = %{
        id: "alice",
        type: :user,
        attributes: %{"department" => "engineering", "level" => "senior"},
        groups: ["developers", "admins"],
        active: true
      }
      {:ok, model} = SubjectObjectModel.add_subject(model, subject)

  """
  @spec add_subject(t(), subject()) :: {:ok, t()} | {:error, term()}
  def add_subject(%__MODULE__{} = model, subject) do
    if Map.has_key?(model.subjects, subject.id) do
      {:error, :subject_exists}
    else
      updated_subjects = Map.put(model.subjects, subject.id, subject)

      # Update subject groups
      updated_groups =
        Enum.reduce(subject.groups, model.subject_groups, fn group, acc ->
          current_members = Map.get(acc, group, [])
          Map.put(acc, group, [subject.id | current_members])
        end)

      updated_model = %{
        model
        | subjects: updated_subjects,
          subject_groups: updated_groups,
          relationship_cache: %{}
      }

      {:ok, updated_model}
    end
  end

  @doc """
  Adds an object.

  ## Examples

      object = %{
        id: "doc1",
        type: :document,
        attributes: %{"classification" => "confidential", "size" => 1024},
        parent_id: "folder1",
        owners: ["alice"],
        active: true
      }
      {:ok, model} = SubjectObjectModel.add_object(model, object)

  """
  @spec add_object(t(), object()) :: {:ok, t()} | {:error, term()}
  def add_object(%__MODULE__{} = model, object) do
    if Map.has_key?(model.objects, object.id) do
      {:error, :object_exists}
    else
      updated_objects = Map.put(model.objects, object.id, object)

      # Update object hierarchies
      updated_hierarchies =
        case object.parent_id do
          nil ->
            model.object_hierarchies

          parent_id ->
            current_children = Map.get(model.object_hierarchies, parent_id, [])
            Map.put(model.object_hierarchies, parent_id, [object.id | current_children])
        end

      # Update ownership patterns
      updated_ownership =
        Enum.reduce(object.owners, model.ownership_patterns, fn owner, acc ->
          current_owned = Map.get(acc, owner, [])
          Map.put(acc, owner, [object.id | current_owned])
        end)

      updated_model = %{
        model
        | objects: updated_objects,
          object_hierarchies: updated_hierarchies,
          ownership_patterns: updated_ownership,
          relationship_cache: %{}
      }

      {:ok, updated_model}
    end
  end

  @doc """
  Adds a relationship between subject and object.

  ## Examples

      relationship = %{
        subject_id: "alice",
        object_id: "doc1",
        relationship_type: :reads,
        permissions: ["read", "download"],
        conditions: %{"time_restriction" => "business_hours"},
        expiry: nil
      }
      {:ok, model} = SubjectObjectModel.add_relationship(model, relationship)

  """
  @spec add_relationship(t(), relationship()) :: {:ok, t()} | {:error, term()}
  def add_relationship(%__MODULE__{} = model, relationship) do
    # Validate subject (or group) and object exist
    subject_exists =
      Map.has_key?(model.subjects, relationship.subject_id) ||
        Map.has_key?(model.subject_groups, relationship.subject_id)

    object_exists = Map.has_key?(model.objects, relationship.object_id)

    if subject_exists && object_exists do
      updated_relationships = [relationship | model.relationships]

      updated_model = %{
        model
        | relationships: updated_relationships,
          relationship_cache: %{}
      }

      {:ok, updated_model}
    else
      {:error, :subject_or_object_not_found}
    end
  end

  @doc """
  Checks if a subject has a specific relationship to an object.

  ## Examples

      SubjectObjectModel.has_relationship?(model, "alice", "doc1", :reads)

  """
  @spec has_relationship?(t(), String.t(), String.t(), relationship_type()) :: boolean()
  def has_relationship?(%__MODULE__{enabled: false}, _subject_id, _object_id, _rel_type), do: true

  def has_relationship?(%__MODULE__{} = model, subject_id, object_id, relationship_type) do
    cache_key = "#{subject_id}:#{object_id}:#{relationship_type}"

    case Map.get(model.relationship_cache, cache_key) do
      nil ->
        result = check_relationship_exists(model, subject_id, object_id, relationship_type)
        result

      cached_result ->
        cached_result
    end
  end

  @doc """
  Checks if a subject can perform an action on an object.

  ## Examples

      SubjectObjectModel.can_perform_action?(model, "alice", "read", "doc1")

  """
  @spec can_perform_action?(t(), String.t(), String.t(), String.t()) :: boolean()
  def can_perform_action?(%__MODULE__{enabled: false}, _subject_id, _action, _object_id), do: true

  def can_perform_action?(%__MODULE__{} = model, subject_id, action, object_id) do
    # Check direct relationships
    direct_access = check_direct_action_access(model, subject_id, action, object_id)

    # Check group-based access
    group_access = check_group_action_access(model, subject_id, action, object_id)

    # Check ownership access
    ownership_access = check_ownership_access(model, subject_id, action, object_id)

    # Check inherited access through object hierarchy
    inherited_access = check_inherited_access(model, subject_id, action, object_id)

    direct_access || group_access || ownership_access || inherited_access
  end

  @doc """
  Evaluates a subject-object policy against a request.

  ## Examples

      SubjectObjectModel.evaluate_policy(model, ["alice", "read", "doc1"], "owner_or_reader")

  """
  @spec evaluate_policy(t(), [String.t()], String.t()) :: boolean()
  def evaluate_policy(%__MODULE__{enabled: false}, _request, _policy), do: true

  def evaluate_policy(%__MODULE__{} = model, [subject_id, action, object_id], policy) do
    case policy do
      "owner_only" ->
        owner?(model, subject_id, object_id)

      "owner_or_reader" ->
        owner?(model, subject_id, object_id) ||
          has_relationship?(model, subject_id, object_id, :reads)

      "group_member" ->
        has_group_access?(model, subject_id, object_id)

      "hierarchy_access" ->
        can_perform_action?(model, subject_id, action, object_id)

      _ ->
        can_perform_action?(model, subject_id, action, object_id)
    end
  end

  @doc """
  Gets all objects owned by a subject.

  ## Examples

      objects = SubjectObjectModel.get_owned_objects(model, "alice")

  """
  @spec get_owned_objects(t(), String.t()) :: [object()]
  def get_owned_objects(%__MODULE__{} = model, subject_id) do
    owned_object_ids = Map.get(model.ownership_patterns, subject_id, [])

    owned_object_ids
    |> Enum.map(fn object_id -> Map.get(model.objects, object_id) end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Gets all relationships for a subject.

  ## Examples

      relationships = SubjectObjectModel.get_subject_relationships(model, "alice")

  """
  @spec get_subject_relationships(t(), String.t()) :: [relationship()]
  def get_subject_relationships(%__MODULE__{} = model, subject_id) do
    Enum.filter(model.relationships, fn rel -> rel.subject_id == subject_id end)
  end

  @doc """
  Gets all relationships for an object.

  ## Examples

      relationships = SubjectObjectModel.get_object_relationships(model, "doc1")

  """
  @spec get_object_relationships(t(), String.t()) :: [relationship()]
  def get_object_relationships(%__MODULE__{} = model, object_id) do
    Enum.filter(model.relationships, fn rel -> rel.object_id == object_id end)
  end

  @doc """
  Gets all child objects in hierarchy.

  ## Examples

      children = SubjectObjectModel.get_child_objects(model, "folder1")

  """
  @spec get_child_objects(t(), String.t()) :: [object()]
  def get_child_objects(%__MODULE__{} = model, parent_object_id) do
    child_ids = Map.get(model.object_hierarchies, parent_object_id, [])

    child_ids
    |> Enum.map(fn object_id -> Map.get(model.objects, object_id) end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Gets subjects in a group.

  ## Examples

      subjects = SubjectObjectModel.get_group_subjects(model, "developers")

  """
  @spec get_group_subjects(t(), String.t()) :: [subject()]
  def get_group_subjects(%__MODULE__{} = model, group_name) do
    subject_ids = Map.get(model.subject_groups, group_name, [])

    subject_ids
    |> Enum.map(fn subject_id -> Map.get(model.subjects, subject_id) end)
    |> Enum.reject(&is_nil/1)
  end

  # Private functions

  defp check_relationship_exists(%__MODULE__{} = model, subject_id, object_id, relationship_type) do
    check_direct_relationship(model, subject_id, object_id, relationship_type) ||
      check_group_based_relationship(model, subject_id, object_id, relationship_type)
  end

  defp check_direct_relationship(model, subject_id, object_id, relationship_type) do
    Enum.any?(model.relationships, fn rel ->
      rel.subject_id == subject_id &&
        rel.object_id == object_id &&
        rel.relationship_type == relationship_type &&
        relationship_active?(rel)
    end)
  end

  defp check_group_based_relationship(model, subject_id, object_id, relationship_type) do
    case Map.get(model.subjects, subject_id) do
      nil ->
        false

      subject ->
        Enum.any?(subject.groups, fn group ->
          check_group_relationship(model, group, object_id, relationship_type)
        end)
    end
  end

  defp check_direct_action_access(%__MODULE__{} = model, subject_id, action, object_id) do
    Enum.any?(model.relationships, fn rel ->
      rel.subject_id == subject_id &&
        rel.object_id == object_id &&
        action in rel.permissions &&
        relationship_active?(rel) &&
        conditions_met?(rel.conditions)
    end)
  end

  defp check_group_action_access(%__MODULE__{} = model, subject_id, action, object_id) do
    case Map.get(model.subjects, subject_id) do
      nil -> false
      subject -> check_group_action_permissions(model, subject.groups, action, object_id)
    end
  end

  defp check_group_action_permissions(model, groups, action, object_id) do
    Enum.any?(groups, fn group ->
      Enum.any?(model.relationships, fn rel ->
        rel.subject_id == group &&
          rel.object_id == object_id &&
          action in rel.permissions &&
          relationship_active?(rel)
      end)
    end)
  end

  defp check_ownership_access(%__MODULE__{} = model, subject_id, _action, object_id) do
    case Map.get(model.objects, object_id) do
      nil -> false
      object -> subject_id in object.owners
    end
  end

  defp check_inherited_access(%__MODULE__{} = model, subject_id, action, object_id) do
    case Map.get(model.objects, object_id) do
      nil ->
        false

      object ->
        case object.parent_id do
          nil -> false
          parent_id -> can_perform_action?(model, subject_id, action, parent_id)
        end
    end
  end

  defp check_group_relationship(%__MODULE__{} = model, group, object_id, relationship_type) do
    Enum.any?(model.relationships, fn rel ->
      rel.subject_id == group &&
        rel.object_id == object_id &&
        rel.relationship_type == relationship_type &&
        relationship_active?(rel)
    end)
  end

  defp relationship_active?(relationship) do
    case relationship.expiry do
      nil -> true
      expiry -> DateTime.compare(DateTime.utc_now(), expiry) == :lt
    end
  end

  defp conditions_met?(conditions) when map_size(conditions) == 0, do: true

  defp conditions_met?(conditions) do
    # Simple condition evaluation - extend as needed
    Enum.all?(conditions, fn {key, expected_value} ->
      case key do
        "time_restriction" ->
          evaluate_time_restriction(expected_value)

        "ip_restriction" ->
          # Placeholder for IP-based restrictions
          true

        _ ->
          true
      end
    end)
  end

  defp evaluate_time_restriction("business_hours") do
    current_hour = DateTime.utc_now().hour
    current_hour >= 9 && current_hour <= 17
  end

  defp evaluate_time_restriction(_), do: true

  defp owner?(%__MODULE__{} = model, subject_id, object_id) do
    case Map.get(model.objects, object_id) do
      nil -> false
      object -> subject_id in object.owners
    end
  end

  defp has_group_access?(%__MODULE__{} = model, subject_id, object_id) do
    case Map.get(model.subjects, subject_id) do
      nil -> false
      subject -> check_group_relationships_for_object(model, subject.groups, object_id)
    end
  end

  defp check_group_relationships_for_object(model, groups, object_id) do
    Enum.any?(groups, fn group ->
      Enum.any?(model.relationships, fn rel ->
        rel.subject_id == group && rel.object_id == object_id
      end)
    end)
  end
end
