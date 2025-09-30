defmodule CasbinEx2.Adapter.StringAdapter do
  @moduledoc """
  String adapter for loading policies from string content.

  This adapter allows loading policies directly from string content,
  making it ideal for embedded policies, testing, and dynamic policy generation.

  ## Features

  - Load policies from string content
  - Support for multiple string formats (CSV, JSON, custom)
  - Dynamic policy updates
  - Policy validation and formatting
  - Integration with template engines

  ## Supported Formats

  ### CSV Format (default)
  ```
  p, alice, data1, read
  p, bob, data2, write
  g, alice, admin
  ```

  ### JSON Format
  ```json
  {
    "policies": {
      "p": [["alice", "data1", "read"], ["bob", "data2", "write"]]
    },
    "grouping_policies": {
      "g": [["alice", "admin"]]
    }
  }
  ```

  ### Line Format
  ```
  alice, data1, read
  bob, data2, write
  ```

  ## Usage

      # CSV format (default)
      policy_text = "p, alice, data1, read\\np, bob, data2, write"
      adapter = CasbinEx2.Adapter.StringAdapter.new(policy_text)

      # JSON format
      json_policies = ~s({"policies": {"p": [["alice", "data1", "read"]]}})
      adapter = CasbinEx2.Adapter.StringAdapter.new(json_policies, format: :json)

      # Custom format with parser
      adapter = CasbinEx2.Adapter.StringAdapter.new(
        policy_text,
        format: :custom,
        parser: &MyModule.custom_parser/1
      )
  """

  @behaviour CasbinEx2.Adapter

  defstruct [
    :content,
    :format,
    :parser,
    :validator,
    :policies,
    :grouping_policies,
    :last_updated
  ]

  @type format :: :csv | :json | :lines | :custom
  @type parser_fun :: (String.t() -> {:ok, map(), map()} | {:error, term()})
  @type validator_fun :: (map(), map() -> {:ok, map(), map()} | {:error, term()})

  @type t :: %__MODULE__{
          content: String.t(),
          format: format(),
          parser: parser_fun() | nil,
          validator: validator_fun() | nil,
          policies: map(),
          grouping_policies: map(),
          last_updated: DateTime.t()
        }

  @doc """
  Creates a new string adapter.

  ## Parameters

  - `content` - String content containing policy definitions
  - `opts` - Optional configuration
    - `:format` - Content format (:csv, :json, :lines, :custom)
    - `:parser` - Custom parser function for :custom format
    - `:validator` - Optional validator function
    - `:parse_on_create` - Parse content immediately (default: true)

  ## Examples

      # CSV format
      adapter = CasbinEx2.Adapter.StringAdapter.new("p, alice, data1, read")

      # JSON format
      json = ~s({"policies": {"p": [["alice", "data1", "read"]]}})
      adapter = CasbinEx2.Adapter.StringAdapter.new(json, format: :json)

      # Custom parser
      parser = fn content ->
        # Custom parsing logic
        {:ok, %{}, %{}}
      end
      adapter = CasbinEx2.Adapter.StringAdapter.new(
        content,
        format: :custom,
        parser: parser
      )
  """
  @spec new(String.t(), keyword()) :: t()
  def new(content, opts \\ []) when is_binary(content) do
    format = Keyword.get(opts, :format, :csv)
    parser = Keyword.get(opts, :parser)
    validator = Keyword.get(opts, :validator)
    parse_on_create = Keyword.get(opts, :parse_on_create, true)

    adapter = %__MODULE__{
      content: content,
      format: format,
      parser: parser,
      validator: validator,
      policies: %{},
      grouping_policies: %{},
      last_updated: DateTime.utc_now()
    }

    if parse_on_create do
      case parse_content(adapter) do
        {:ok, policies, grouping_policies} ->
          %{adapter | policies: policies, grouping_policies: grouping_policies}

        {:error, _reason} ->
          # Return adapter with empty policies if parsing fails
          adapter
      end
    else
      adapter
    end
  end

  @doc """
  Creates a string adapter from policy and grouping policy maps.

  Generates string content from structured policy data.
  """
  @spec from_policies(map(), map(), keyword()) :: t()
  def from_policies(policies, grouping_policies \\ %{}, opts \\ []) do
    format = Keyword.get(opts, :format, :csv)
    content = format_policies_to_string(policies, grouping_policies, format)

    %__MODULE__{
      content: content,
      format: format,
      parser: nil,
      validator: nil,
      policies: policies,
      grouping_policies: grouping_policies,
      last_updated: DateTime.utc_now()
    }
  end

  @doc """
  Updates the adapter with new string content.

  Re-parses the content and updates internal policy storage.
  """
  @spec update_content(t(), String.t()) :: {:ok, t()} | {:error, term()}
  def update_content(%__MODULE__{} = adapter, new_content) when is_binary(new_content) do
    updated_adapter = %{adapter | content: new_content, last_updated: DateTime.utc_now()}

    case parse_content(updated_adapter) do
      {:ok, policies, grouping_policies} ->
        final_adapter = %{
          updated_adapter
          | policies: policies,
            grouping_policies: grouping_policies
        }

        {:ok, final_adapter}

      {:error, _reason} ->
        # On parsing error, return updated adapter with new content but keep old policies
        {:ok, updated_adapter}
    end
  end

  @doc """
  Validates the current policy content.

  Uses the configured validator or built-in validation.
  """
  @spec validate(t()) :: {:ok, t()} | {:error, term()}
  def validate(
        %__MODULE__{
          validator: validator,
          policies: policies,
          grouping_policies: grouping_policies
        } = adapter
      )
      when is_function(validator, 2) do
    case validator.(policies, grouping_policies) do
      {:ok, validated_policies, validated_grouping} ->
        {:ok, %{adapter | policies: validated_policies, grouping_policies: validated_grouping}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def validate(%__MODULE__{} = adapter) do
    # Built-in validation
    if validate_policy_structure(adapter.policies) and
         validate_policy_structure(adapter.grouping_policies) do
      {:ok, adapter}
    else
      {:error, "Invalid policy structure"}
    end
  end

  @doc """
  Gets policy statistics.
  """
  @spec get_stats(t()) :: %{
          content_size: non_neg_integer(),
          policy_count: non_neg_integer(),
          grouping_policy_count: non_neg_integer(),
          policy_types: [String.t()],
          last_updated: DateTime.t()
        }
  def get_stats(%__MODULE__{} = adapter) do
    %{
      content_size: byte_size(adapter.content),
      policy_count: count_rules(adapter.policies),
      grouping_policy_count: count_rules(adapter.grouping_policies),
      policy_types: Map.keys(adapter.policies) ++ Map.keys(adapter.grouping_policies),
      last_updated: adapter.last_updated
    }
  end

  # Adapter Behaviour Implementation

  @impl CasbinEx2.Adapter
  def load_policy(%__MODULE__{policies: policies, grouping_policies: grouping_policies}, _model) do
    {:ok, policies, grouping_policies}
  end

  @impl CasbinEx2.Adapter
  def load_filtered_policy(%__MODULE__{} = adapter, _model, filter) do
    {:ok, policies, grouping_policies} = load_policy(adapter, nil)

    filtered_policies = apply_filter(policies, filter)
    filtered_grouping = apply_filter(grouping_policies, filter)

    {:ok, filtered_policies, filtered_grouping}
  end

  @impl CasbinEx2.Adapter
  def load_incremental_filtered_policy(%__MODULE__{} = adapter, model, filter) do
    # For string adapter, incremental is the same as full filtered load
    load_filtered_policy(adapter, model, filter)
  end

  @impl CasbinEx2.Adapter
  def filtered?(%__MODULE__{}), do: true

  @impl CasbinEx2.Adapter
  def save_policy(%__MODULE__{} = adapter, policies, grouping_policies) do
    # Update internal state and regenerate content
    content = format_policies_to_string(policies, grouping_policies, adapter.format)

    updated_adapter = %{
      adapter
      | content: content,
        policies: policies,
        grouping_policies: grouping_policies,
        last_updated: DateTime.utc_now()
    }

    # Store updated adapter in process state for future calls
    Process.put(:string_adapter_state, updated_adapter)
    :ok
  end

  @impl CasbinEx2.Adapter
  def add_policy(%__MODULE__{policies: policies} = adapter, _sec, ptype, rule) do
    current_rules = Map.get(policies, ptype, [])
    updated_rules = [rule | current_rules]
    updated_policies = Map.put(policies, ptype, updated_rules)

    save_policy(adapter, updated_policies, adapter.grouping_policies)
  end

  @impl CasbinEx2.Adapter
  def remove_policy(%__MODULE__{policies: policies} = adapter, _sec, ptype, rule) do
    current_rules = Map.get(policies, ptype, [])
    updated_rules = List.delete(current_rules, rule)

    updated_policies =
      if updated_rules == [] do
        Map.delete(policies, ptype)
      else
        Map.put(policies, ptype, updated_rules)
      end

    save_policy(adapter, updated_policies, adapter.grouping_policies)
  end

  @impl CasbinEx2.Adapter
  def remove_filtered_policy(
        %__MODULE__{policies: policies} = adapter,
        _sec,
        ptype,
        field_index,
        field_values
      ) do
    current_rules = Map.get(policies, ptype, [])

    filtered_rules =
      current_rules
      |> Enum.reject(fn rule ->
        matches_filter?(rule, field_index, field_values)
      end)

    updated_policies =
      if filtered_rules == [] do
        Map.delete(policies, ptype)
      else
        Map.put(policies, ptype, filtered_rules)
      end

    save_policy(adapter, updated_policies, adapter.grouping_policies)
  end

  # Private functions

  defp parse_content(%__MODULE__{content: content, format: format, parser: parser}) do
    case format do
      :csv -> parse_csv_content(content)
      :json -> parse_json_content(content)
      :lines -> parse_lines_content(content)
      :custom when is_function(parser, 1) -> parser.(content)
      :custom -> {:error, "Custom parser function required for custom format"}
      _ -> {:error, "Unsupported format: #{format}"}
    end
  end

  defp parse_csv_content(content) do
    {policies, grouping_policies} =
      content
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "#")))
      |> Enum.reduce({%{}, %{}}, fn line, {p_acc, g_acc} ->
        case String.split(line, ",") |> Enum.map(&String.trim/1) do
          ["p" | rest] -> add_policy_rule(p_acc, g_acc, "p", rest)
          ["g" | rest] -> add_grouping_rule(p_acc, g_acc, "g", rest)
          [ptype | rest] when ptype != "" -> add_rule_by_type(p_acc, g_acc, ptype, rest)
          _ -> {p_acc, g_acc}
        end
      end)

    {:ok, policies, grouping_policies}
  rescue
    error -> {:error, "CSV parsing failed: #{inspect(error)}"}
  end

  defp parse_json_content(content) do
    case Jason.decode(content) do
      {:ok, %{"policies" => policies, "grouping_policies" => grouping_policies}} ->
        {:ok, policies, grouping_policies}

      {:ok, %{"policies" => policies}} ->
        {:ok, policies, %{}}

      {:ok, data} when is_map(data) ->
        # Try to infer structure
        {policies, grouping_policies} = infer_json_structure(data)
        {:ok, policies, grouping_policies}

      {:error, reason} ->
        {:error, "JSON parsing failed: #{inspect(reason)}"}
    end
  rescue
    error -> {:error, "JSON parsing failed: #{inspect(error)}"}
  end

  defp parse_lines_content(content) do
    policies =
      content
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn line ->
        line |> String.split(",") |> Enum.map(&String.trim/1)
      end)
      |> Enum.group_by(fn _rule -> "p" end)

    {:ok, policies, %{}}
  rescue
    error -> {:error, "Lines parsing failed: #{inspect(error)}"}
  end

  defp infer_json_structure(data) do
    {policies, grouping_policies} =
      Enum.reduce(data, {%{}, %{}}, fn {key, value}, {p_acc, g_acc} ->
        if String.starts_with?(key, "g") do
          {p_acc, Map.put(g_acc, key, value)}
        else
          {Map.put(p_acc, key, value), g_acc}
        end
      end)

    {policies, grouping_policies}
  end

  defp add_policy_rule(p_acc, g_acc, type, rest) do
    policies = Map.get(p_acc, type, [])
    updated_policies = Map.put(p_acc, type, policies ++ [rest])
    {updated_policies, g_acc}
  end

  defp add_grouping_rule(p_acc, g_acc, type, rest) do
    grouping_policies = Map.get(g_acc, type, [])
    updated_grouping = Map.put(g_acc, type, grouping_policies ++ [rest])
    {p_acc, updated_grouping}
  end

  defp add_rule_by_type(p_acc, g_acc, ptype, rest) do
    if String.starts_with?(ptype, "g") do
      add_grouping_rule(p_acc, g_acc, ptype, rest)
    else
      add_policy_rule(p_acc, g_acc, ptype, rest)
    end
  end

  defp format_policies_to_string(policies, grouping_policies, format) do
    case format do
      :csv -> format_to_csv(policies, grouping_policies)
      :json -> format_to_json(policies, grouping_policies)
      :lines -> format_to_lines(policies, grouping_policies)
      _ -> format_to_csv(policies, grouping_policies)
    end
  end

  defp format_to_csv(policies, grouping_policies) do
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

  defp format_to_json(policies, grouping_policies) do
    data = %{
      "policies" => policies,
      "grouping_policies" => grouping_policies
    }

    Jason.encode!(data, pretty: true)
  end

  defp format_to_lines(policies, _grouping_policies) do
    policies
    |> Map.values()
    |> List.flatten()
    |> Enum.map_join("\n", &Enum.join(&1, ", "))
  end

  defp apply_filter(policies, filter) when is_function(filter, 2) do
    policies
    |> Enum.into(%{}, fn {ptype, rules} ->
      filtered_rules = Enum.filter(rules, &filter.(ptype, &1))
      {ptype, filtered_rules}
    end)
    |> Enum.reject(fn {_ptype, rules} -> Enum.empty?(rules) end)
    |> Enum.into(%{})
  end

  defp apply_filter(policies, _filter), do: policies

  defp matches_filter?(rule, field_index, field_values) do
    field_values
    |> Enum.with_index()
    |> Enum.all?(fn {value, index} ->
      actual_index = field_index + index

      case Enum.at(rule, actual_index) do
        ^value -> true
        nil -> false
        _other -> false
      end
    end)
  end

  defp count_rules(policies) do
    policies
    |> Map.values()
    |> Enum.map(&length/1)
    |> Enum.sum()
  end

  defp validate_policy_structure(policies) when is_map(policies) do
    Enum.all?(policies, fn {_ptype, rules} ->
      is_list(rules) and Enum.all?(rules, &is_list/1)
    end)
  end

  defp validate_policy_structure(_), do: false

  # Built-in validators

  @doc """
  Built-in validator for RBAC policies.

  Ensures proper structure for role-based access control policies.
  """
  @spec rbac_validator(map(), map()) :: {:ok, map(), map()} | {:error, term()}
  def rbac_validator(policies, grouping_policies) do
    with :ok <- validate_rbac_policies(policies),
         :ok <- validate_rbac_grouping(grouping_policies) do
      {:ok, policies, grouping_policies}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_rbac_policies(policies) do
    case Map.get(policies, "p") do
      nil ->
        {:error, "Missing 'p' policy type"}

      rules when is_list(rules) ->
        if Enum.all?(rules, &(length(&1) >= 3)) do
          :ok
        else
          {:error, "RBAC policies must have at least 3 fields (sub, obj, act)"}
        end

      _ ->
        {:error, "Invalid 'p' policy structure"}
    end
  end

  defp validate_rbac_grouping(grouping_policies) do
    case Map.get(grouping_policies, "g") do
      # Grouping policies are optional
      nil ->
        :ok

      rules when is_list(rules) ->
        if Enum.all?(rules, &(length(&1) >= 2)) do
          :ok
        else
          {:error, "RBAC grouping policies must have at least 2 fields (user, role)"}
        end

      _ ->
        {:error, "Invalid 'g' grouping policy structure"}
    end
  end
end
