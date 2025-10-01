defmodule CasbinEx2.Model do
  @moduledoc """
  Model represents the model configuration for Casbin.

  The model contains the request definition, policy definition,
  role definition, policy effect, and matchers.
  """

  defstruct [
    :request_definition,
    :policy_definition,
    :role_definition,
    :policy_effect,
    :matchers,
    field_index_map: %{}
  ]

  @type t :: %__MODULE__{
          request_definition: map(),
          policy_definition: map(),
          role_definition: map(),
          policy_effect: map(),
          matchers: map(),
          field_index_map: %{String.t() => %{String.t() => integer()}}
        }

  @doc """
  Loads a model from a configuration file.
  """
  @spec load_model(String.t()) :: {:ok, t()} | {:error, term()}
  def load_model(model_path) do
    case File.read(model_path) do
      {:ok, content} ->
        parse_model(content)

      {:error, reason} ->
        {:error, "Failed to read model file: #{reason}"}
    end
  end

  @doc """
  Loads a model from text content.
  """
  @spec load_model_from_text(String.t()) :: {:ok, t()} | {:error, term()}
  def load_model_from_text(text) do
    parse_model(text)
  end

  @doc """
  Gets the matcher expression from the model.
  """
  @spec get_matcher(t()) :: String.t() | nil
  def get_matcher(%__MODULE__{matchers: matchers}) do
    case Map.get(matchers, "m") do
      nil -> nil
      value when is_binary(value) -> value
      value when is_map(value) -> Map.get(value, "m")
    end
  end

  @doc """
  Gets the policy effect from the model.
  """
  @spec get_policy_effect(t()) :: String.t() | nil
  def get_policy_effect(%__MODULE__{policy_effect: policy_effect}) do
    case Map.get(policy_effect, "e") do
      nil -> nil
      value when is_binary(value) -> value
      value when is_map(value) -> Map.get(value, "e")
    end
  end

  @doc """
  Gets request tokens from the model.
  """
  @spec get_request_tokens(t()) :: [String.t()]
  def get_request_tokens(%__MODULE__{request_definition: request_definition}) do
    case Map.get(request_definition, "r") do
      nil ->
        []

      value when is_binary(value) ->
        value
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      value when is_map(value) ->
        Map.get(value, "r", "")
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
    end
  end

  @doc """
  Gets policy tokens from the model.
  """
  @spec get_policy_tokens(t(), String.t()) :: [String.t()]
  def get_policy_tokens(%__MODULE__{policy_definition: policy_definition}, policy_type) do
    case Map.get(policy_definition, policy_type) do
      nil ->
        []

      value when is_binary(value) ->
        value
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      value when is_map(value) ->
        Map.get(value, policy_type, "")
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
    end
  end

  @doc """
  Gets role tokens from the model.
  """
  @spec get_role_tokens(t(), String.t()) :: [String.t()]
  def get_role_tokens(%__MODULE__{role_definition: role_definition}, role_type) do
    case Map.get(role_definition, role_type) do
      nil ->
        []

      value when is_binary(value) ->
        value
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      value when is_map(value) ->
        Map.get(value, role_type, "")
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
    end
  end

  # Private functions

  defp parse_model(content) do
    sections = parse_sections(content)

    model = %__MODULE__{
      request_definition: Map.get(sections, "request_definition", %{}),
      policy_definition: Map.get(sections, "policy_definition", %{}),
      role_definition: Map.get(sections, "role_definition", %{}),
      policy_effect: Map.get(sections, "policy_effect", %{}),
      matchers: Map.get(sections, "matchers", %{})
    }

    {:ok, model}
  rescue
    error -> {:error, "Failed to parse model: #{inspect(error)}"}
  end

  defp parse_sections(content) do
    content
    |> String.split("\n")
    |> Enum.reduce({%{}, nil}, fn line, {sections, current_section} ->
      line = String.trim(line)

      cond do
        # Skip empty lines and comments
        line == "" or String.starts_with?(line, "#") ->
          {sections, current_section}

        # Section header
        String.starts_with?(line, "[") and String.ends_with?(line, "]") ->
          section_name =
            line
            |> String.slice(1..-2//1)
            |> String.trim()

          {sections, section_name}

        # Key-value pair
        String.contains?(line, "=") and current_section != nil ->
          [key, value] = String.split(line, "=", parts: 2)
          key = String.trim(key)
          value = String.trim(value)

          section_map = Map.get(sections, current_section, %{})
          updated_section = Map.put(section_map, key, value)
          updated_sections = Map.put(sections, current_section, updated_section)

          {updated_sections, current_section}

        true ->
          {sections, current_section}
      end
    end)
    |> elem(0)
  end

  @doc """
  Gets the field index for a specific policy type and field name.

  Field indices are used to map custom field names to positions in policy rules.
  For example, mapping "priority" to index 3 in a policy rule.

  ## Parameters
  - `model` - The model struct
  - `ptype` - Policy type (e.g., "p", "p2")
  - `field` - Field name (e.g., "priority", "domain")

  ## Returns
  - `{:ok, index}` - The field index if found
  - `{:error, message}` - If field index is not set

  ## Note
  This is a placeholder implementation. In the full version, this would:
  1. Check a field_index_map stored in the model
  2. Search policy_definition tokens for pattern matches
  3. Cache the result for future lookups
  """
  @spec get_field_index(t(), String.t(), String.t()) :: {:ok, integer()} | {:error, String.t()}
  def get_field_index(model, ptype, field) do
    # First check if the field index is cached
    case get_in(model.field_index_map, [ptype, field]) do
      nil ->
        # Not in cache, try to find it in the policy tokens
        find_field_index_in_tokens(model, ptype, field)

      index ->
        {:ok, index}
    end
  end

  defp find_field_index_in_tokens(model, ptype, field) do
    # Look for the pattern "ptype_field" in policy definition tokens
    # For example, for ptype="p" and field="priority", look for "p_priority"
    pattern = "#{ptype}_#{field}"

    case get_in(model.policy_definition, [ptype]) do
      nil ->
        {:error, "Policy type #{ptype} not found"}

      policy_def ->
        # Parse the policy definition to get tokens
        tokens = String.split(policy_def, ",") |> Enum.map(&String.trim/1)

        case Enum.find_index(tokens, &(&1 == pattern)) do
          nil ->
            {:error,
             "#{field} index is not set, please use enforcer.set_field_index() to set index"}

          index ->
            {:ok, index}
        end
    end
  end

  @doc """
  Sets the field index for a specific policy type and field name.

  This allows custom field names to be mapped to specific positions in policy rules.

  ## Parameters
  - `model` - The model struct
  - `ptype` - Policy type (e.g., "p", "p2")
  - `field` - Field name (e.g., "priority", "domain")
  - `index` - The zero-based index position

  ## Returns
  Updated model

  ## Note
  This is a placeholder implementation. In the full version, this would:
  1. Store the field index in a field_index_map
  2. Allow get_field_index to retrieve it later
  3. Support custom field ordering in policies
  """
  @spec set_field_index(t(), String.t(), String.t(), integer()) :: t()
  def set_field_index(model, ptype, field, index) do
    # Store the field index in the field_index_map
    # Structure: %{ptype => %{field => index}}
    updated_map =
      model.field_index_map
      |> Map.put_new(ptype, %{})
      |> put_in([ptype, field], index)

    %{model | field_index_map: updated_map}
  end
end
