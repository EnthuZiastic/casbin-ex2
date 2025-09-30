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
  def filtered?(%__MODULE__{}) do
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
      |> prepare_policy_lines()
      |> Enum.reduce({%{}, %{}}, fn line, {p_acc, g_acc} ->
        process_policy_line(line, p_acc, g_acc)
      end)

    # Reverse the lists since we prepended
    policies = Map.new(policies, fn {k, v} -> {k, Enum.reverse(v)} end)
    grouping_policies = Map.new(grouping_policies, fn {k, v} -> {k, Enum.reverse(v)} end)

    {:ok, policies, grouping_policies}
  end

  defp prepare_policy_lines(content) do
    content
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
  end

  defp process_policy_line(line, p_acc, g_acc) do
    case String.split(line, ",") |> Enum.map(&String.trim/1) do
      ["p" | rest] -> add_policy_rule(p_acc, g_acc, "p", rest)
      ["g" | rest] -> add_grouping_rule(p_acc, g_acc, "g", rest)
      [ptype | rest] when ptype != "" -> add_custom_rule(p_acc, g_acc, ptype, rest)
      _ -> {p_acc, g_acc}
    end
  end

  defp add_policy_rule(p_acc, g_acc, type, rest) do
    policies = Map.get(p_acc, type, [])
    updated_policies = Map.put(p_acc, type, [rest | policies])
    {updated_policies, g_acc}
  end

  defp add_grouping_rule(p_acc, g_acc, type, rest) do
    grouping_policies = Map.get(g_acc, type, [])
    updated_grouping = Map.put(g_acc, type, [rest | grouping_policies])
    {p_acc, updated_grouping}
  end

  defp add_custom_rule(p_acc, g_acc, ptype, rest) do
    if String.starts_with?(ptype, "g") do
      add_grouping_rule(p_acc, g_acc, ptype, rest)
    else
      add_policy_rule(p_acc, g_acc, ptype, rest)
    end
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
