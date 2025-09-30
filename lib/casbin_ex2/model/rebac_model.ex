defmodule CasbinEx2.Model.RebacModel do
  @moduledoc """
  ReBAC (Relationship-Based Access Control) Model.

  Provides relationship-based access control where access decisions are based on
  relationships between subjects and objects in a graph-like structure.
  Supports complex relationship chains, transitive relationships, and dynamic
  relationship resolution.
  """

  defstruct [
    :relationships,
    :relationship_types,
    :transitivity_rules,
    :relationship_cache,
    :max_depth,
    :enabled
  ]

  @type relationship :: {String.t(), String.t(), String.t()}
  @type relationship_type :: %{
          name: String.t(),
          transitive: boolean(),
          symmetric: boolean(),
          inverse: String.t() | nil
        }

  @type t :: %__MODULE__{
          relationships: %{String.t() => [relationship()]},
          relationship_types: %{String.t() => relationship_type()},
          transitivity_rules: %{String.t() => [String.t()]},
          relationship_cache: %{String.t() => boolean()},
          max_depth: pos_integer(),
          enabled: boolean()
        }

  @doc """
  Creates a new ReBAC model.

  ## Examples

      rebac_model = RebacModel.new()
      rebac_model = RebacModel.new(max_depth: 10)

  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      relationships: %{},
      relationship_types: default_relationship_types(),
      transitivity_rules: %{},
      relationship_cache: %{},
      max_depth: Keyword.get(opts, :max_depth, 5),
      enabled: true
    }
  end

  @doc """
  Adds a relationship between subject and object.

  ## Examples

      {:ok, model} = RebacModel.add_relationship(model, "alice", "owner", "doc1")
      {:ok, model} = RebacModel.add_relationship(model, "bob", "reader", "doc1")

  """
  @spec add_relationship(t(), String.t(), String.t(), String.t()) :: {:ok, t()} | {:error, term()}
  def add_relationship(%__MODULE__{} = model, subject, relation, object) do
    relationship = {subject, relation, object}
    _relationship_key = "#{subject}:#{relation}:#{object}"

    current_relationships = Map.get(model.relationships, relation, [])

    if relationship in current_relationships do
      {:error, :relationship_exists}
    else
      new_relationships = [relationship | current_relationships]

      updated_model = %{
        model
        | relationships: Map.put(model.relationships, relation, new_relationships),
          # Clear cache when relationships change
          relationship_cache: %{}
      }

      {:ok, updated_model}
    end
  end

  @doc """
  Removes a relationship between subject and object.

  ## Examples

      {:ok, model} = RebacModel.remove_relationship(model, "alice", "owner", "doc1")

  """
  @spec remove_relationship(t(), String.t(), String.t(), String.t()) ::
          {:ok, t()} | {:error, term()}
  def remove_relationship(%__MODULE__{} = model, subject, relation, object) do
    relationship = {subject, relation, object}
    current_relationships = Map.get(model.relationships, relation, [])

    if relationship in current_relationships do
      new_relationships = List.delete(current_relationships, relationship)

      updated_model = %{
        model
        | relationships: Map.put(model.relationships, relation, new_relationships),
          # Clear cache when relationships change
          relationship_cache: %{}
      }

      {:ok, updated_model}
    else
      {:error, :relationship_not_found}
    end
  end

  @doc """
  Checks if a relationship exists between subject and object.

  ## Examples

      RebacModel.has_relationship?(model, "alice", "owner", "doc1")
      RebacModel.has_relationship?(model, "bob", "reader", "doc1")

  """
  @spec has_relationship?(t(), String.t(), String.t(), String.t()) :: boolean()
  def has_relationship?(%__MODULE__{} = model, subject, relation, object) do
    cache_key = "#{subject}:#{relation}:#{object}"

    case Map.get(model.relationship_cache, cache_key) do
      nil ->
        result = check_relationship_recursive(model, subject, relation, object, 0)
        # Cache the result
        _updated_cache = Map.put(model.relationship_cache, cache_key, result)
        # Note: In a real implementation, you'd want to update the model's cache
        result

      cached_result ->
        cached_result
    end
  end

  @doc """
  Gets all relationships for a subject.

  ## Examples

      relationships = RebacModel.get_relationships_for_subject(model, "alice")

  """
  @spec get_relationships_for_subject(t(), String.t()) :: [{String.t(), String.t()}]
  def get_relationships_for_subject(%__MODULE__{relationships: relationships}, subject) do
    relationships
    |> Map.values()
    |> List.flatten()
    |> Enum.filter(fn {subj, _relation, _object} -> subj == subject end)
    |> Enum.map(fn {_subj, relation, object} -> {relation, object} end)
  end

  @doc """
  Gets all relationships for an object.

  ## Examples

      relationships = RebacModel.get_relationships_for_object(model, "doc1")

  """
  @spec get_relationships_for_object(t(), String.t()) :: [{String.t(), String.t()}]
  def get_relationships_for_object(%__MODULE__{relationships: relationships}, object) do
    relationships
    |> Map.values()
    |> List.flatten()
    |> Enum.filter(fn {_subject, _relation, obj} -> obj == object end)
    |> Enum.map(fn {subject, relation, _obj} -> {subject, relation} end)
  end

  @doc """
  Adds a relationship type with transitivity and symmetry rules.

  ## Examples

      {:ok, model} = RebacModel.add_relationship_type(model, %{
        name: "parent",
        transitive: false,
        symmetric: false,
        inverse: "child"
      })

  """
  @spec add_relationship_type(t(), relationship_type()) :: {:ok, t()}
  def add_relationship_type(%__MODULE__{} = model, relationship_type) do
    updated_types = Map.put(model.relationship_types, relationship_type.name, relationship_type)
    updated_model = %{model | relationship_types: updated_types, relationship_cache: %{}}
    {:ok, updated_model}
  end

  @doc """
  Evaluates a ReBAC policy against a request.

  ## Examples

      RebacModel.evaluate_policy(model, ["alice", "read", "doc1"], "r.sub owner r.obj")

  """
  @spec evaluate_policy(t(), [String.t()], String.t()) :: boolean()
  def evaluate_policy(%__MODULE__{enabled: false}, _request, _policy), do: true

  def evaluate_policy(%__MODULE__{} = model, [subject, action, object], policy) do
    # Parse simple ReBAC policy expressions
    # Example: "r.sub owner r.obj" means subject must have owner relationship to object
    case parse_rebac_expression(policy) do
      {:ok, relation} ->
        has_relationship?(model, subject, relation, object)

      {:error, :complex_expression} ->
        # For complex expressions, you could integrate with an expression evaluator
        evaluate_complex_expression(model, subject, action, object, policy)

      {:error, _reason} ->
        false
    end
  end

  # Private functions

  defp default_relationship_types do
    %{
      "owner" => %{name: "owner", transitive: false, symmetric: false, inverse: nil},
      "reader" => %{name: "reader", transitive: false, symmetric: false, inverse: nil},
      "writer" => %{name: "writer", transitive: false, symmetric: false, inverse: nil},
      "editor" => %{name: "editor", transitive: false, symmetric: false, inverse: nil},
      "parent" => %{name: "parent", transitive: true, symmetric: false, inverse: "child"},
      "child" => %{name: "child", transitive: false, symmetric: false, inverse: "parent"},
      "member" => %{name: "member", transitive: false, symmetric: false, inverse: nil},
      "admin" => %{name: "admin", transitive: false, symmetric: false, inverse: nil}
    }
  end

  defp check_relationship_recursive(
         %__MODULE__{max_depth: max_depth},
         _subject,
         _relation,
         _object,
         depth
       )
       when depth > max_depth,
       do: false

  defp check_relationship_recursive(%__MODULE__{} = model, subject, relation, object, depth) do
    # Direct relationship check
    direct_relationships = Map.get(model.relationships, relation, [])
    direct_match = {subject, relation, object} in direct_relationships

    if direct_match do
      true
    else
      # Check transitive relationships
      relationship_type = Map.get(model.relationship_types, relation)

      if relationship_type && relationship_type.transitive do
        check_transitive_relationship(model, subject, relation, object, depth + 1)
      else
        false
      end
    end
  end

  defp check_transitive_relationship(%__MODULE__{} = model, subject, relation, object, depth) do
    # Find intermediate objects that the subject has the relation to
    intermediate_relationships = Map.get(model.relationships, relation, [])

    intermediate_objects =
      intermediate_relationships
      |> Enum.filter(fn {subj, _rel, _obj} -> subj == subject end)
      |> Enum.map(fn {_subj, _rel, obj} -> obj end)

    # Check if any intermediate object has the relation to the target object
    Enum.any?(intermediate_objects, fn intermediate ->
      check_relationship_recursive(model, intermediate, relation, object, depth)
    end)
  end

  defp parse_rebac_expression(policy) do
    # Simple parser for basic ReBAC expressions
    # Example: "r.sub owner r.obj" -> {:ok, "owner"}
    case String.split(String.trim(policy), " ") do
      ["r.sub", relation, "r.obj"] ->
        {:ok, relation}

      _ ->
        {:error, :complex_expression}
    end
  end

  defp evaluate_complex_expression(_model, _subject, _action, _object, _policy) do
    # Placeholder for complex expression evaluation
    # In a real implementation, you might use a more sophisticated expression parser
    false
  end
end
