defmodule CasbinEx2.Adapter.FileAdapter do
  @moduledoc """
  File adapter for loading and saving policies from/to a file.
  """

  @behaviour CasbinEx2.Adapter


  defstruct [:file_path]

  @type t :: %__MODULE__{
    file_path: String.t()
  }

  @doc """
  Creates a new file adapter.
  """
  @spec new(String.t()) :: t()
  def new(file_path) do
    %__MODULE__{file_path: file_path}
  end

  @impl CasbinEx2.Adapter
  def load_policy(%__MODULE__{file_path: file_path}, _model) do
    case File.read(file_path) do
      {:ok, content} ->
        parse_policies(content)
      {:error, :enoent} ->
        # File doesn't exist, return empty policies
        {:ok, %{}, %{}}
      {:error, reason} ->
        {:error, "Failed to read policy file: #{reason}"}
    end
  end

  @impl CasbinEx2.Adapter
  def save_policy(%__MODULE__{file_path: file_path}, policies, grouping_policies) do
    content = format_policies(policies, grouping_policies)

    case File.write(file_path, content) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to write policy file: #{reason}"}
    end
  end

  @impl CasbinEx2.Adapter
  def add_policy(%__MODULE__{}, _sec, _ptype, _rule) do
    # For file adapter, we don't support incremental additions
    # Users should call save_policy instead
    {:error, "File adapter does not support incremental policy additions"}
  end

  @impl CasbinEx2.Adapter
  def remove_policy(%__MODULE__{}, _sec, _ptype, _rule) do
    # For file adapter, we don't support incremental removals
    # Users should call save_policy instead
    {:error, "File adapter does not support incremental policy removals"}
  end

  @impl CasbinEx2.Adapter
  def remove_filtered_policy(%__MODULE__{}, _sec, _ptype, _field_index, _field_values) do
    # For file adapter, we don't support incremental removals
    # Users should call save_policy instead
    {:error, "File adapter does not support incremental policy removals"}
  end

  @impl CasbinEx2.Adapter
  def is_filtered(%__MODULE__{}) do
    false
  end

  @impl CasbinEx2.Adapter
  def load_filtered_policy(%__MODULE__{}, _model, _filter) do
    # File adapter doesn't support filtered loading
    {:error, "File adapter does not support filtered policy loading"}
  end

  @impl CasbinEx2.Adapter
  def load_incremental_filtered_policy(%__MODULE__{}, _model, _filter) do
    # File adapter doesn't support incremental filtered loading
    {:error, "File adapter does not support incremental filtered policy loading"}
  end

  # Private functions

  defp parse_policies(content) do
    {policies, grouping_policies} =
      content
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
      |> Enum.reduce({%{}, %{}}, fn line, {p_acc, g_acc} ->
        case String.split(line, ",") |> Enum.map(&String.trim/1) do
          ["p" | rest] ->
            type = "p"
            policies = Map.get(p_acc, type, [])
            updated_policies = Map.put(p_acc, type, [rest | policies])
            {updated_policies, g_acc}

          ["g" | rest] ->
            type = "g"
            grouping_policies = Map.get(g_acc, type, [])
            updated_grouping = Map.put(g_acc, type, [rest | grouping_policies])
            {p_acc, updated_grouping}

          [ptype | rest] when ptype != "" ->
            # Handle custom policy types (p2, p3, etc.) and grouping types (g2, g3, etc.)
            if String.starts_with?(ptype, "g") do
              grouping_policies = Map.get(g_acc, ptype, [])
              updated_grouping = Map.put(g_acc, ptype, [rest | grouping_policies])
              {p_acc, updated_grouping}
            else
              policies = Map.get(p_acc, ptype, [])
              updated_policies = Map.put(p_acc, ptype, [rest | policies])
              {updated_policies, g_acc}
            end

          _ ->
            {p_acc, g_acc}
        end
      end)

    # Reverse the lists since we prepended
    policies = Map.new(policies, fn {k, v} -> {k, Enum.reverse(v)} end)
    grouping_policies = Map.new(grouping_policies, fn {k, v} -> {k, Enum.reverse(v)} end)

    {:ok, policies, grouping_policies}
  end

  defp format_policies(policies, grouping_policies) do
    policy_lines =
      policies
      |> Enum.flat_map(fn {ptype, rules} ->
        Enum.map(rules, fn rule ->
          ([ptype] ++ rule) |> Enum.join(", ")
        end)
      end)

    grouping_lines =
      grouping_policies
      |> Enum.flat_map(fn {gtype, rules} ->
        Enum.map(rules, fn rule ->
          ([gtype] ++ rule) |> Enum.join(", ")
        end)
      end)

    (policy_lines ++ grouping_lines) |> Enum.join("\n")
  end
end