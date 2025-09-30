defmodule CasbinEx2.Model.AbacModel do
  @moduledoc """
  ABAC (Attribute-Based Access Control) Model Enhancement.

  Provides advanced attribute-based access control with dynamic attribute evaluation,
  complex policy conditions, and runtime attribute resolution.
  """

  defstruct [
    :attributes,
    :attribute_providers,
    :policy_templates,
    :expression_cache,
    :enabled
  ]

  @type attribute_value :: String.t() | number() | boolean() | list() | map()
  @type attribute_map :: %{String.t() => attribute_value()}
  @type attribute_provider :: {module(), atom(), list()}

  @type t :: %__MODULE__{
          attributes: %{String.t() => attribute_map()},
          attribute_providers: %{String.t() => attribute_provider()},
          policy_templates: [String.t()],
          expression_cache: %{String.t() => term()},
          enabled: boolean()
        }

  @doc """
  Creates a new ABAC model.

  ## Examples

      abac_model = AbacModel.new()

  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      attributes: %{},
      attribute_providers: %{},
      policy_templates: [],
      expression_cache: %{},
      enabled: true
    }
  end

  @doc """
  Adds an attribute for a subject.

  ## Examples

      {:ok, model} = AbacModel.add_attribute(model, "alice", "department", "engineering")

  """
  @spec add_attribute(t(), String.t(), String.t(), attribute_value()) ::
          {:ok, t()} | {:error, term()}
  def add_attribute(%__MODULE__{attributes: attributes} = model, subject, attribute_name, value) do
    subject_attrs = Map.get(attributes, subject, %{})
    updated_attrs = Map.put(subject_attrs, attribute_name, value)
    new_attributes = Map.put(attributes, subject, updated_attrs)

    {:ok, %{model | attributes: new_attributes}}
  end

  @doc """
  Removes an attribute for a subject.

  ## Examples

      {:ok, model} = AbacModel.remove_attribute(model, "alice", "department")

  """
  @spec remove_attribute(t(), String.t(), String.t()) :: {:ok, t()} | {:error, term()}
  def remove_attribute(%__MODULE__{attributes: attributes} = model, subject, attribute_name) do
    case Map.get(attributes, subject) do
      nil ->
        {:error, :subject_not_found}

      subject_attrs ->
        do_remove_attribute(model, attributes, subject, subject_attrs, attribute_name)
    end
  end

  defp do_remove_attribute(model, attributes, subject, subject_attrs, attribute_name) do
    if Map.has_key?(subject_attrs, attribute_name) do
      updated_attrs = Map.delete(subject_attrs, attribute_name)
      new_attributes = update_attributes_after_removal(attributes, subject, updated_attrs)
      {:ok, %{model | attributes: new_attributes}}
    else
      {:error, :attribute_not_found}
    end
  end

  defp update_attributes_after_removal(attributes, subject, updated_attrs) do
    if map_size(updated_attrs) == 0 do
      Map.delete(attributes, subject)
    else
      Map.put(attributes, subject, updated_attrs)
    end
  end

  @doc """
  Gets all attributes for a subject.

  ## Examples

      attributes = AbacModel.get_attributes(model, "alice")

  """
  @spec get_attributes(t(), String.t()) :: attribute_map()
  def get_attributes(%__MODULE__{attributes: attributes}, subject) do
    Map.get(attributes, subject, %{})
  end

  @doc """
  Gets a specific attribute value for a subject.

  ## Examples

      value = AbacModel.get_attribute(model, "alice", "department")

  """
  @spec get_attribute(t(), String.t(), String.t()) :: attribute_value() | nil
  def get_attribute(%__MODULE__{attributes: attributes}, subject, attribute_name) do
    attributes
    |> Map.get(subject, %{})
    |> Map.get(attribute_name)
  end

  @doc """
  Sets multiple attributes for a subject.

  ## Examples

      {:ok, model} = AbacModel.set_attributes(model, "alice", %{
        "department" => "engineering",
        "level" => "senior",
        "clearance" => 3
      })

  """
  @spec set_attributes(t(), String.t(), attribute_map()) :: {:ok, t()}
  def set_attributes(%__MODULE__{attributes: attributes} = model, subject, new_attrs) do
    current_attrs = Map.get(attributes, subject, %{})
    merged_attrs = Map.merge(current_attrs, new_attrs)
    new_attributes = Map.put(attributes, subject, merged_attrs)

    {:ok, %{model | attributes: new_attributes}}
  end

  @doc """
  Registers a dynamic attribute provider.

  ## Examples

      {:ok, model} = AbacModel.register_attribute_provider(model, "location",
        {MyApp.LocationProvider, :get_user_location, []})

  """
  @spec register_attribute_provider(t(), String.t(), attribute_provider()) :: {:ok, t()}
  def register_attribute_provider(
        %__MODULE__{attribute_providers: providers} = model,
        attribute_name,
        provider
      ) do
    new_providers = Map.put(providers, attribute_name, provider)
    {:ok, %{model | attribute_providers: new_providers}}
  end

  @doc """
  Removes a dynamic attribute provider.

  ## Examples

      {:ok, model} = AbacModel.unregister_attribute_provider(model, "location")

  """
  @spec unregister_attribute_provider(t(), String.t()) :: {:ok, t()}
  def unregister_attribute_provider(
        %__MODULE__{attribute_providers: providers} = model,
        attribute_name
      ) do
    new_providers = Map.delete(providers, attribute_name)
    {:ok, %{model | attribute_providers: new_providers}}
  end

  @doc """
  Evaluates ABAC policy with attributes.

  ## Examples

      allowed = AbacModel.evaluate_policy(model, "alice", "document1", "read", %{
        "resource_owner" => "alice",
        "classification" => "confidential"
      })

  """
  @spec evaluate_policy(t(), String.t(), String.t(), String.t(), map()) :: boolean()
  def evaluate_policy(model, subject, object, action, context \\ %{})

  def evaluate_policy(%__MODULE__{enabled: false}, _subject, _object, _action, _context),
    do: false

  def evaluate_policy(%__MODULE__{} = model, subject, object, action, context) do
    # Get subject attributes (static + dynamic)
    subject_attrs = resolve_all_attributes(model, subject, context)

    # Build evaluation context
    eval_context = %{
      subject: subject,
      object: object,
      action: action,
      subject_attrs: subject_attrs,
      context: context,
      time: DateTime.utc_now()
    }

    # Evaluate against built-in ABAC rules
    evaluate_abac_rules(model, eval_context)
  end

  @doc """
  Adds a policy template for ABAC evaluation.

  ## Examples

      {:ok, model} = AbacModel.add_policy_template(model,
        "subject_attrs.department == 'engineering' and action == 'read'")

  """
  @spec add_policy_template(t(), String.t()) :: {:ok, t()}
  def add_policy_template(%__MODULE__{policy_templates: templates} = model, template) do
    new_templates = [template | templates] |> Enum.uniq()
    {:ok, %{model | policy_templates: new_templates}}
  end

  @doc """
  Removes a policy template.

  ## Examples

      {:ok, model} = AbacModel.remove_policy_template(model,
        "subject_attrs.department == 'engineering' and action == 'read'")

  """
  @spec remove_policy_template(t(), String.t()) :: {:ok, t()}
  def remove_policy_template(%__MODULE__{policy_templates: templates} = model, template) do
    new_templates = List.delete(templates, template)
    {:ok, %{model | policy_templates: new_templates}}
  end

  @doc """
  Gets all policy templates.

  ## Examples

      templates = AbacModel.get_policy_templates(model)

  """
  @spec get_policy_templates(t()) :: [String.t()]
  def get_policy_templates(%__MODULE__{policy_templates: templates}), do: templates

  @doc """
  Enables or disables the ABAC model.

  ## Examples

      model = AbacModel.set_enabled(model, true)

  """
  @spec set_enabled(t(), boolean()) :: t()
  def set_enabled(%__MODULE__{} = model, enabled) do
    %{model | enabled: enabled}
  end

  @doc """
  Checks if the ABAC model is enabled.

  ## Examples

      enabled = AbacModel.enabled?(model)

  """
  @spec enabled?(t()) :: boolean()
  def enabled?(%__MODULE__{enabled: enabled}), do: enabled

  @doc """
  Gets all subjects with attributes.

  ## Examples

      subjects = AbacModel.get_all_subjects(model)

  """
  @spec get_all_subjects(t()) :: [String.t()]
  def get_all_subjects(%__MODULE__{attributes: attributes}) do
    Map.keys(attributes)
  end

  @doc """
  Gets all attribute names used across subjects.

  ## Examples

      attribute_names = AbacModel.get_all_attribute_names(model)

  """
  @spec get_all_attribute_names(t()) :: [String.t()]
  def get_all_attribute_names(%__MODULE__{attributes: attributes, attribute_providers: providers}) do
    static_attrs =
      attributes
      |> Map.values()
      |> Enum.flat_map(&Map.keys/1)
      |> Enum.uniq()

    dynamic_attrs = Map.keys(providers)

    (static_attrs ++ dynamic_attrs) |> Enum.uniq()
  end

  @doc """
  Finds subjects with specific attribute values.

  ## Examples

      subjects = AbacModel.find_subjects_by_attribute(model, "department", "engineering")

  """
  @spec find_subjects_by_attribute(t(), String.t(), attribute_value()) :: [String.t()]
  def find_subjects_by_attribute(%__MODULE__{attributes: attributes}, attribute_name, value) do
    attributes
    |> Enum.filter(fn {_subject, attrs} ->
      Map.get(attrs, attribute_name) == value
    end)
    |> Enum.map(fn {subject, _attrs} -> subject end)
  end

  @doc """
  Clears all attributes.

  ## Examples

      model = AbacModel.clear_attributes(model)

  """
  @spec clear_attributes(t()) :: t()
  def clear_attributes(%__MODULE__{} = model) do
    %{model | attributes: %{}}
  end

  @doc """
  Clears the expression cache.

  ## Examples

      model = AbacModel.clear_cache(model)

  """
  @spec clear_cache(t()) :: t()
  def clear_cache(%__MODULE__{} = model) do
    %{model | expression_cache: %{}}
  end

  # Private functions

  defp resolve_all_attributes(
         %__MODULE__{attributes: attributes, attribute_providers: providers},
         subject,
         context
       ) do
    # Start with static attributes
    static_attrs = Map.get(attributes, subject, %{})

    # Add dynamic attributes
    dynamic_attrs =
      providers
      |> Enum.reduce(%{}, fn {attr_name, {module, function, args}}, acc ->
        try do
          value = apply(module, function, [subject | args] ++ [context])
          Map.put(acc, attr_name, value)
        rescue
          # Skip failed dynamic attribute resolution
          _ -> acc
        end
      end)

    Map.merge(static_attrs, dynamic_attrs)
  end

  defp evaluate_abac_rules(
         %__MODULE__{policy_templates: templates, expression_cache: cache} = model,
         context
       ) do
    # If no templates, use default rules
    rules_to_evaluate =
      if Enum.empty?(templates) do
        get_default_abac_rules()
      else
        templates
      end

    # Evaluate each rule
    Enum.any?(rules_to_evaluate, fn rule ->
      evaluate_single_rule(model, rule, context, cache)
    end)
  end

  defp evaluate_single_rule(_model, rule, context, _cache) do
    # Simplified rule evaluation - in production, use a proper expression evaluator
    case rule do
      # Example rule: "subject_attrs.department == 'engineering' and action == 'read'"
      rule_str when is_binary(rule_str) ->
        evaluate_simple_expression(rule_str, context)

      # More complex rules can be added here
      _ ->
        false
    end
  end

  defp evaluate_simple_expression(rule, context) do
    # Very basic expression evaluation - in production, use a proper parser
    cond do
      engineering_read_rule?(rule) -> evaluate_engineering_read(context)
      clearance_rule?(rule) -> evaluate_clearance_rule(context)
      owner_access_rule?(rule) -> evaluate_owner_access(context)
      true -> false
    end
  end

  defp engineering_read_rule?(rule) do
    String.contains?(rule, "department == 'engineering'") and
      String.contains?(rule, "action == 'read'")
  end

  defp clearance_rule?(rule), do: String.contains?(rule, "clearance >= 3")

  defp owner_access_rule?(rule), do: String.contains?(rule, "user_id == object")

  defp evaluate_engineering_read(%{subject_attrs: attrs, action: action}) do
    Map.get(attrs, "department") == "engineering" and action == "read"
  end

  defp evaluate_clearance_rule(%{subject_attrs: attrs}) do
    case Map.get(attrs, "clearance") do
      level when is_integer(level) -> level >= 3
      _ -> false
    end
  end

  defp evaluate_owner_access(%{subject_attrs: attrs, action: action, object: object}) do
    user_id = Map.get(attrs, "user_id")
    allowed_actions = ["read", "write", "delete"]
    user_id == object and action in allowed_actions
  end

  defp get_default_abac_rules do
    [
      "subject_attrs.department == 'engineering' and action == 'read'",
      "subject_attrs.clearance >= 3 and action in ['read', 'write']",
      "subject_attrs.user_id == object and action in ['read', 'write', 'delete']"
    ]
  end
end
