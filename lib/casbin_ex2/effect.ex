defmodule CasbinEx2.Effect do
  @moduledoc """
  Effect evaluation system for Casbin policies.

  Handles different policy effects including allow, deny, indeterminate, and priority.
  """

  @type effect_type :: :allow | :deny | :indeterminate
  @type effect_result :: :allow | :deny | :indeterminate

  @effect_allow "allow"
  @effect_deny "deny"
  @effect_indeterminate "indeterminate"

  @doc """
  Evaluates the policy effect based on the effect expression and matched policies.
  """
  @spec evaluate_effect(String.t(), [%{effect: String.t(), decision: boolean()}]) ::
          effect_result()
  def evaluate_effect(effect_expr, policy_results) do
    case normalize_effect_expr(effect_expr) do
      "some(where (p.eft == allow))" ->
        evaluate_some_allow(policy_results)

      "!some(where (p.eft == deny))" ->
        evaluate_not_some_deny(policy_results)

      "some(where (p.eft == allow)) && !some(where (p.eft == deny))" ->
        evaluate_allow_and_deny(policy_results)

      "priority(p.eft) || deny" ->
        evaluate_priority_or_deny(policy_results)

      "subjectPriority(p.sub, p.eft) || deny" ->
        evaluate_subject_priority_or_deny(policy_results)

      _ ->
        # Default: some allow
        evaluate_some_allow(policy_results)
    end
  end

  @doc """
  Creates a policy result with effect and decision.
  """
  @spec create_policy_result(String.t(), boolean()) :: %{effect: String.t(), decision: boolean()}
  def create_policy_result(effect, decision) do
    %{effect: effect, decision: decision}
  end

  @doc """
  Determines the effect type from a policy rule.
  """
  @spec get_effect_from_policy([String.t()]) :: String.t()
  def get_effect_from_policy(policy) do
    # Check if policy has an explicit effect column
    case Enum.at(policy, -1) do
      "allow" -> @effect_allow
      "deny" -> @effect_deny
      # Default to allow
      _ -> @effect_allow
    end
  end

  @doc """
  Converts string effect to atom.
  """
  @spec effect_to_atom(String.t()) :: effect_type()
  def effect_to_atom(@effect_allow), do: :allow
  def effect_to_atom(@effect_deny), do: :deny
  def effect_to_atom(@effect_indeterminate), do: :indeterminate
  def effect_to_atom(_), do: :allow

  @doc """
  Converts atom effect to string.
  """
  @spec atom_to_effect(effect_type()) :: String.t()
  def atom_to_effect(:allow), do: @effect_allow
  def atom_to_effect(:deny), do: @effect_deny
  def atom_to_effect(:indeterminate), do: @effect_indeterminate

  # Private functions

  defp normalize_effect_expr(expr) do
    expr
    |> String.trim()
    |> String.downcase()
  end

  # some(where (p.eft == allow)) - allows if any policy allows
  defp evaluate_some_allow(policy_results) do
    has_allow =
      Enum.any?(policy_results, fn result ->
        result.decision and result.effect == @effect_allow
      end)

    if has_allow, do: :allow, else: :deny
  end

  # !some(where (p.eft == deny)) - denies if any policy denies
  defp evaluate_not_some_deny(policy_results) do
    has_deny =
      Enum.any?(policy_results, fn result ->
        result.decision and result.effect == @effect_deny
      end)

    if has_deny, do: :deny, else: :allow
  end

  # some(where (p.eft == allow)) && !some(where (p.eft == deny))
  # Allows only if there's an allow and no deny
  defp evaluate_allow_and_deny(policy_results) do
    has_allow =
      Enum.any?(policy_results, fn result ->
        result.decision and result.effect == @effect_allow
      end)

    has_deny =
      Enum.any?(policy_results, fn result ->
        result.decision and result.effect == @effect_deny
      end)

    cond do
      has_deny -> :deny
      has_allow -> :allow
      true -> :deny
    end
  end

  # priority(p.eft) || deny - uses priority ordering
  defp evaluate_priority_or_deny(policy_results) do
    case filter_matching_results(policy_results) do
      [] -> :deny
      results -> evaluate_highest_priority_effect(results)
    end
  end

  defp filter_matching_results(policy_results) do
    Enum.filter(policy_results, & &1.decision)
  end

  defp evaluate_highest_priority_effect(results) do
    results
    |> sort_by_effect_priority()
    |> List.first()
    |> map_effect_to_result()
  end

  defp sort_by_effect_priority(results) do
    Enum.sort_by(results, &effect_priority/1)
  end

  defp effect_priority(%{effect: effect}) do
    case effect do
      @effect_deny -> 0
      @effect_allow -> 1
      @effect_indeterminate -> 2
      _ -> 3
    end
  end

  defp map_effect_to_result(%{effect: effect}) do
    case effect do
      @effect_deny -> :deny
      @effect_allow -> :allow
      @effect_indeterminate -> :indeterminate
      _ -> :deny
    end
  end

  # subjectPriority(p.sub, p.eft) || deny - uses subject-based priority
  defp evaluate_subject_priority_or_deny(policy_results) do
    # Group by subject and evaluate priority within each subject
    policy_results
    |> Enum.filter(& &1.decision)
    |> Enum.group_by(& &1[:subject])
    |> Enum.map(fn {_subject, subject_results} ->
      evaluate_priority_or_deny(subject_results)
    end)
    |> case do
      [] ->
        :deny

      results ->
        # If any subject allows, allow; if any denies, deny
        cond do
          :deny in results -> :deny
          :allow in results -> :allow
          true -> :indeterminate
        end
    end
  end

  @doc """
  Evaluates complex effect expressions with custom logic.
  """
  @spec evaluate_custom_effect(String.t(), [%{effect: String.t(), decision: boolean()}]) ::
          effect_result()
  def evaluate_custom_effect(expression, policy_results) do
    expr = String.trim(expression)

    case classify_effect_expression(expr) do
      :priority -> evaluate_priority_or_deny(policy_results)
      :subject_priority -> evaluate_subject_priority_or_deny(policy_results)
      :not_some_deny -> evaluate_not_some_deny(policy_results)
      :allow_and_deny -> evaluate_allow_and_deny(policy_results)
      :default -> evaluate_some_allow(policy_results)
    end
  end

  defp classify_effect_expression(expr) do
    cond do
      contains_priority_not_subject?(expr) -> :priority
      String.contains?(expr, "subjectPriority") -> :subject_priority
      contains_not_deny?(expr) -> :not_some_deny
      contains_allow_and_not_deny?(expr) -> :allow_and_deny
      true -> :default
    end
  end

  defp contains_priority_not_subject?(expr) do
    String.contains?(expr, "priority") and not String.contains?(expr, "subjectPriority")
  end

  defp contains_not_deny?(expr) do
    String.contains?(expr, "!") and String.contains?(expr, "deny")
  end

  defp contains_allow_and_not_deny?(expr) do
    String.contains?(expr, "allow") and String.contains?(expr, "&&") and
      String.contains?(expr, "!") and String.contains?(expr, "deny")
  end

  @doc """
  Creates an effect evaluator function for a given expression.
  """
  @spec create_evaluator(String.t()) :: ([%{effect: String.t(), decision: boolean()}] ->
                                           effect_result())
  def create_evaluator(effect_expr) do
    fn policy_results -> evaluate_effect(effect_expr, policy_results) end
  end

  @doc """
  Validates an effect expression.
  """
  @spec validate_effect_expression(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def validate_effect_expression(expr) when is_binary(expr) do
    normalized = normalize_effect_expr(expr)

    known_expressions = [
      "some(where (p.eft == allow))",
      "!some(where (p.eft == deny))",
      "some(where (p.eft == allow)) && !some(where (p.eft == deny))",
      "priority(p.eft) || deny",
      "subjectpriority(p.sub, p.eft) || deny"
    ]

    if normalized in known_expressions do
      {:ok, normalized}
    else
      {:error, "Unknown effect expression: #{expr}"}
    end
  end

  def validate_effect_expression(_), do: {:error, "Effect expression must be a string"}
end
