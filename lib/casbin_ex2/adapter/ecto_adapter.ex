defmodule CasbinEx2.Adapter.EctoAdapter do
  @moduledoc """
  Ecto SQL adapter for loading and saving policies from/to a database.
  """

  @behaviour CasbinEx2.Adapter

  import Ecto.Query

  alias CasbinEx2.Model
  alias CasbinEx2.Adapter.EctoAdapter.CasbinRule

  defstruct [:repo]

  @type t :: %__MODULE__{
    repo: module()
  }

  @doc """
  Creates a new Ecto adapter with the given repository.
  """
  @spec new(module()) :: t()
  def new(repo) do
    %__MODULE__{repo: repo}
  end

  @impl CasbinEx2.Adapter
  def load_policy(%__MODULE__{repo: repo}, _model) do
    try do
      rules = repo.all(CasbinRule)

      {policies, grouping_policies} =
        Enum.reduce(rules, {%{}, %{}}, fn rule, {p_acc, g_acc} ->
          rule_list = build_rule_list(rule)

          if String.starts_with?(rule.ptype, "g") do
            # Grouping policy
            current_rules = Map.get(g_acc, rule.ptype, [])
            updated_g = Map.put(g_acc, rule.ptype, [rule_list | current_rules])
            {p_acc, updated_g}
          else
            # Regular policy
            current_rules = Map.get(p_acc, rule.ptype, [])
            updated_p = Map.put(p_acc, rule.ptype, [rule_list | current_rules])
            {updated_p, g_acc}
          end
        end)

      # Reverse lists since we prepended
      policies = Map.new(policies, fn {k, v} -> {k, Enum.reverse(v)} end)
      grouping_policies = Map.new(grouping_policies, fn {k, v} -> {k, Enum.reverse(v)} end)

      {:ok, policies, grouping_policies}
    rescue
      error -> {:error, "Failed to load policies: #{inspect(error)}"}
    end
  end

  @impl CasbinEx2.Adapter
  def save_policy(%__MODULE__{repo: repo}, policies, grouping_policies) do
    try do
      # Start transaction
      repo.transaction(fn ->
        # Clear existing policies
        repo.delete_all(CasbinRule)

        # Insert policy rules
        policy_changesets =
          policies
          |> Enum.flat_map(fn {ptype, rules} ->
            Enum.map(rules, fn rule ->
              create_changeset(ptype, rule)
            end)
          end)

        # Insert grouping policy rules
        grouping_changesets =
          grouping_policies
          |> Enum.flat_map(fn {ptype, rules} ->
            Enum.map(rules, fn rule ->
              create_changeset(ptype, rule)
            end)
          end)

        # Insert all rules
        all_changesets = policy_changesets ++ grouping_changesets

        Enum.each(all_changesets, fn changeset ->
          repo.insert!(changeset)
        end)
      end)

      :ok
    rescue
      error -> {:error, "Failed to save policies: #{inspect(error)}"}
    end
  end

  @impl CasbinEx2.Adapter
  def add_policy(%__MODULE__{repo: repo}, sec, ptype, rule) do
    try do
      changeset = create_changeset(ptype, rule)
      repo.insert!(changeset)
      :ok
    rescue
      error -> {:error, "Failed to add policy: #{inspect(error)}"}
    end
  end

  @impl CasbinEx2.Adapter
  def remove_policy(%__MODULE__{repo: repo}, sec, ptype, rule) do
    try do
      query = build_remove_query(ptype, rule)
      repo.delete_all(query)
      :ok
    rescue
      error -> {:error, "Failed to remove policy: #{inspect(error)}"}
    end
  end

  @impl CasbinEx2.Adapter
  def remove_filtered_policy(%__MODULE__{repo: repo}, sec, ptype, field_index, field_values) do
    try do
      query = build_filtered_remove_query(ptype, field_index, field_values)
      repo.delete_all(query)
      :ok
    rescue
      error -> {:error, "Failed to remove filtered policy: #{inspect(error)}"}
    end
  end

  # Private functions

  defp build_rule_list(%CasbinRule{} = rule) do
    [rule.v0, rule.v1, rule.v2, rule.v3, rule.v4, rule.v5]
    |> Enum.reject(&is_nil/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp create_changeset(ptype, rule) do
    params = %{ptype: ptype}

    # Map rule values to v0-v5 fields
    rule_params =
      rule
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {value, index}, acc ->
        field_name = "v#{index}" |> String.to_atom()
        Map.put(acc, field_name, value)
      end)

    all_params = Map.merge(params, rule_params)
    CasbinRule.changeset(%CasbinRule{}, all_params)
  end

  defp build_remove_query(ptype, rule) do
    base_query = from(r in CasbinRule, where: r.ptype == ^ptype)

    rule
    |> Enum.with_index()
    |> Enum.reduce(base_query, fn {value, index}, query ->
      field = String.to_atom("v#{index}")
      from(r in query, where: field(r, ^field) == ^value)
    end)
  end

  defp build_filtered_remove_query(ptype, field_index, field_values) do
    base_query = from(r in CasbinRule, where: r.ptype == ^ptype)

    field_values
    |> Enum.with_index()
    |> Enum.reduce(base_query, fn {value, offset}, query ->
      if value != "" do
        field_name = String.to_atom("v#{field_index + offset}")
        from(r in query, where: field(r, ^field_name) == ^value)
      else
        query
      end
    end)
  end
end