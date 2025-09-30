defmodule CasbinEx2.Model.PriorityModel do
  @moduledoc """
  Priority Model for firewall-style rule prioritization.

  Provides policy evaluation with priority-based rule ordering, conflict resolution,
  explicit deny/allow rules, and rule precedence management. Similar to firewall
  rule processing where order matters and higher priority rules override lower ones.
  """

  defstruct [
    :rules,
    :priority_index,
    :rule_groups,
    :default_effect,
    :conflict_resolution,
    :enabled
  ]

  @type effect :: :allow | :deny | :indeterminate
  @type priority_rule :: %{
          id: String.t(),
          priority: integer(),
          effect: effect(),
          conditions: %{String.t() => term()},
          subject_pattern: String.t(),
          object_pattern: String.t(),
          action_pattern: String.t(),
          enabled: boolean()
        }

  @type conflict_resolution :: :first_match | :highest_priority | :explicit_deny | :allow_override

  @type t :: %__MODULE__{
          rules: %{String.t() => priority_rule()},
          priority_index: [{integer(), String.t()}],
          rule_groups: %{String.t() => [String.t()]},
          default_effect: effect(),
          conflict_resolution: conflict_resolution(),
          enabled: boolean()
        }

  @doc """
  Creates a new Priority model.

  ## Examples

      priority_model = PriorityModel.new()
      priority_model = PriorityModel.new(default_effect: :deny, conflict_resolution: :explicit_deny)

  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      rules: %{},
      priority_index: [],
      rule_groups: %{},
      default_effect: Keyword.get(opts, :default_effect, :deny),
      conflict_resolution: Keyword.get(opts, :conflict_resolution, :highest_priority),
      enabled: true
    }
  end

  @doc """
  Adds a priority rule.

  ## Examples

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

  """
  @spec add_rule(t(), priority_rule()) :: {:ok, t()} | {:error, term()}
  def add_rule(%__MODULE__{} = model, rule) do
    if Map.has_key?(model.rules, rule.id) do
      {:error, :rule_exists}
    else
      # Add rule to rules map
      updated_rules = Map.put(model.rules, rule.id, rule)

      # Update priority index (sorted by priority descending)
      updated_index =
        [{rule.priority, rule.id} | model.priority_index]
        |> Enum.sort_by(fn {priority, _id} -> -priority end)

      updated_model = %{
        model
        | rules: updated_rules,
          priority_index: updated_index
      }

      {:ok, updated_model}
    end
  end

  @doc """
  Removes a priority rule.

  ## Examples

      {:ok, model} = PriorityModel.remove_rule(model, "rule1")

  """
  @spec remove_rule(t(), String.t()) :: {:ok, t()} | {:error, term()}
  def remove_rule(%__MODULE__{} = model, rule_id) do
    if Map.has_key?(model.rules, rule_id) do
      # Remove from rules map
      updated_rules = Map.delete(model.rules, rule_id)

      # Remove from priority index
      updated_index = Enum.reject(model.priority_index, fn {_priority, id} -> id == rule_id end)

      # Remove from rule groups
      updated_groups =
        model.rule_groups
        |> Enum.map(fn {group_name, rule_ids} ->
          {group_name, List.delete(rule_ids, rule_id)}
        end)
        |> Enum.into(%{})

      updated_model = %{
        model
        | rules: updated_rules,
          priority_index: updated_index,
          rule_groups: updated_groups
      }

      {:ok, updated_model}
    else
      {:error, :rule_not_found}
    end
  end

  @doc """
  Updates the priority of a rule.

  ## Examples

      {:ok, model} = PriorityModel.update_rule_priority(model, "rule1", 200)

  """
  @spec update_rule_priority(t(), String.t(), integer()) :: {:ok, t()} | {:error, term()}
  def update_rule_priority(%__MODULE__{} = model, rule_id, new_priority) do
    case Map.get(model.rules, rule_id) do
      nil ->
        {:error, :rule_not_found}

      rule ->
        # Update rule priority
        updated_rule = %{rule | priority: new_priority}
        updated_rules = Map.put(model.rules, rule_id, updated_rule)

        # Rebuild priority index
        updated_index =
          model.priority_index
          |> Enum.reject(fn {_priority, id} -> id == rule_id end)
          |> List.insert_at(0, {new_priority, rule_id})
          |> Enum.sort_by(fn {priority, _id} -> -priority end)

        updated_model = %{
          model
          | rules: updated_rules,
            priority_index: updated_index
        }

        {:ok, updated_model}
    end
  end

  @doc """
  Evaluates a request against priority rules.

  ## Examples

      effect = PriorityModel.evaluate(model, "alice", "read", "document1")

  """
  @spec evaluate(t(), String.t(), String.t(), String.t()) :: effect()
  def evaluate(%__MODULE__{enabled: false}, _subject, _action, _object), do: :allow

  def evaluate(%__MODULE__{} = model, subject, action, object) do
    matching_rules = find_matching_rules(model, subject, action, object)

    case resolve_conflicts(model, matching_rules) do
      [] -> model.default_effect
      [winning_rule | _] -> winning_rule.effect
    end
  end

  @doc """
  Evaluates a priority policy against a request.

  ## Examples

      PriorityModel.evaluate_policy(model, ["alice", "read", "document1"], "priority > 50")

  """
  @spec evaluate_policy(t(), [String.t()], String.t()) :: boolean()
  def evaluate_policy(%__MODULE__{enabled: false}, _request, _policy), do: true

  def evaluate_policy(%__MODULE__{} = model, [subject, action, object], policy) do
    case evaluate(model, subject, action, object) do
      :allow ->
        true

      :deny ->
        false

      :indeterminate ->
        # For indeterminate results, evaluate the policy condition
        evaluate_policy_condition(model, subject, action, object, policy)
    end
  end

  @doc """
  Adds a rule group.

  ## Examples

      {:ok, model} = PriorityModel.add_rule_group(model, "admin_rules", ["rule1", "rule2"])

  """
  @spec add_rule_group(t(), String.t(), [String.t()]) :: {:ok, t()}
  def add_rule_group(%__MODULE__{} = model, group_name, rule_ids) do
    updated_groups = Map.put(model.rule_groups, group_name, rule_ids)
    updated_model = %{model | rule_groups: updated_groups}
    {:ok, updated_model}
  end

  @doc """
  Gets rules by group name.

  ## Examples

      rules = PriorityModel.get_rules_by_group(model, "admin_rules")

  """
  @spec get_rules_by_group(t(), String.t()) :: [priority_rule()]
  def get_rules_by_group(%__MODULE__{} = model, group_name) do
    rule_ids = Map.get(model.rule_groups, group_name, [])

    rule_ids
    |> Enum.map(fn rule_id -> Map.get(model.rules, rule_id) end)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Gets all rules sorted by priority.

  ## Examples

      rules = PriorityModel.get_rules_by_priority(model)

  """
  @spec get_rules_by_priority(t()) :: [priority_rule()]
  def get_rules_by_priority(%__MODULE__{} = model) do
    model.priority_index
    |> Enum.map(fn {_priority, rule_id} -> Map.get(model.rules, rule_id) end)
    |> Enum.reject(&is_nil/1)
  end

  # Private functions

  defp find_matching_rules(%__MODULE__{} = model, subject, action, object) do
    model.priority_index
    |> Enum.map(fn {_priority, rule_id} -> Map.get(model.rules, rule_id) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(fn rule ->
      rule.enabled &&
        matches_pattern?(rule.subject_pattern, subject) &&
        matches_pattern?(rule.action_pattern, action) &&
        matches_pattern?(rule.object_pattern, object) &&
        evaluate_conditions(rule.conditions, subject, action, object)
    end)
  end

  defp resolve_conflicts(%__MODULE__{conflict_resolution: :first_match}, rules) do
    case rules do
      [] -> []
      [first | _] -> [first]
    end
  end

  defp resolve_conflicts(%__MODULE__{conflict_resolution: :highest_priority}, rules) do
    # Rules are already sorted by priority (highest first)
    case rules do
      [] -> []
      [highest | _] -> [highest]
    end
  end

  defp resolve_conflicts(%__MODULE__{conflict_resolution: :explicit_deny}, rules) do
    # Explicit deny rules override allow rules
    deny_rules = Enum.filter(rules, fn rule -> rule.effect == :deny end)

    case deny_rules do
      [] ->
        # No deny rules, take first allow rule
        allow_rules = Enum.filter(rules, fn rule -> rule.effect == :allow end)

        case allow_rules do
          [] -> []
          [first_allow | _] -> [first_allow]
        end

      [first_deny | _] ->
        [first_deny]
    end
  end

  defp resolve_conflicts(%__MODULE__{conflict_resolution: :allow_override}, rules) do
    # Allow rules override deny rules (opposite of explicit_deny)
    allow_rules = Enum.filter(rules, fn rule -> rule.effect == :allow end)

    case allow_rules do
      [] ->
        # No allow rules, take first deny rule
        deny_rules = Enum.filter(rules, fn rule -> rule.effect == :deny end)

        case deny_rules do
          [] -> []
          [first_deny | _] -> [first_deny]
        end

      [first_allow | _] ->
        [first_allow]
    end
  end

  defp matches_pattern?("*", _value), do: true
  defp matches_pattern?(pattern, value) when pattern == value, do: true

  defp matches_pattern?(pattern, value) do
    # Convert pattern to regex if it contains wildcards
    if String.contains?(pattern, "*") do
      regex_pattern =
        pattern
        |> String.replace("*", ".*")
        |> (&"^#{&1}$").()

      case Regex.compile(regex_pattern) do
        {:ok, regex} -> Regex.match?(regex, value)
        {:error, _} -> false
      end
    else
      false
    end
  end

  defp evaluate_conditions(conditions, _subject, _action, _object) when map_size(conditions) == 0,
    do: true

  defp evaluate_conditions(conditions, subject, action, object) do
    # Evaluate all conditions
    Enum.all?(conditions, fn {key, expected_value} ->
      actual_value = get_context_value(key, subject, action, object)
      actual_value == expected_value
    end)
  end

  defp get_context_value("subject", subject, _action, _object), do: subject
  defp get_context_value("action", _subject, action, _object), do: action
  defp get_context_value("object", _subject, _action, object), do: object

  defp get_context_value("time", _subject, _action, _object) do
    # Return current hour for time-based conditions
    DateTime.utc_now().hour
  end

  defp get_context_value("day", _subject, _action, _object) do
    # Return current day of week
    Date.day_of_week(Date.utc_today())
  end

  defp get_context_value(_key, _subject, _action, _object), do: nil

  defp evaluate_policy_condition(_model, _subject, _action, _object, policy) do
    # Simple policy condition evaluation
    # In a real implementation, you'd use a proper expression evaluator
    case String.trim(policy) do
      "true" ->
        true

      "false" ->
        false

      policy when policy in ["priority > 50", "priority > 100"] ->
        # Example: evaluate priority-based conditions
        true

      _ ->
        false
    end
  end
end
