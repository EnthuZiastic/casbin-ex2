defmodule CasbinEx2.Enforcer do
  @moduledoc """
  The main enforcer struct for Casbin authorization.

  This module provides the core functionality for policy enforcement,
  policy management, and role-based access control (RBAC).
  """

  alias CasbinEx2.Model
  alias CasbinEx2.Policy
  alias CasbinEx2.RoleManager
  alias CasbinEx2.Adapter
  alias CasbinEx2.Effect

  defstruct [
    :model,
    :adapter,
    :watcher,
    :role_manager,
    :function_map,
    :effect_expr,
    :enabled,
    :auto_save,
    :auto_build_role_links,
    :auto_notify_watcher,
    policies: %{},
    grouping_policies: %{}
  ]

  @type t :: %__MODULE__{
    model: Model.t() | nil,
    adapter: Adapter.t() | nil,
    watcher: any() | nil,
    role_manager: RoleManager.t() | nil,
    function_map: map(),
    effect_expr: any() | nil,
    enabled: boolean(),
    auto_save: boolean(),
    auto_build_role_links: boolean(),
    auto_notify_watcher: boolean(),
    policies: map(),
    grouping_policies: map()
  }

  @doc """
  Creates a new enforcer with the given model file and policy adapter.
  """
  @spec new_enforcer(String.t(), Adapter.t()) :: {:ok, t()} | {:error, term()}
  def new_enforcer(model_path, adapter) do
    case init_with_file(model_path, adapter) do
      {:ok, enforcer} -> {:ok, enforcer}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Creates a new enforcer with model file and policy file.
  """
  @spec new_enforcer(String.t(), String.t()) :: {:ok, t()} | {:error, term()}
  def new_enforcer(model_path, policy_path) when is_binary(policy_path) do
    adapter = CasbinEx2.Adapter.FileAdapter.new(policy_path)
    new_enforcer(model_path, adapter)
  end

  @doc """
  Initializes the enforcer with model file and adapter.
  """
  @spec init_with_file(String.t(), Adapter.t()) :: {:ok, t()} | {:error, term()}
  def init_with_file(model_path, adapter) do
    with {:ok, model} <- Model.load_model(model_path),
         {:ok, enforcer} <- init_with_model_and_adapter(model, adapter) do
      {:ok, enforcer}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Initializes the enforcer with model and adapter.
  """
  @spec init_with_model_and_adapter(Model.t(), Adapter.t()) :: {:ok, t()} | {:error, term()}
  def init_with_model_and_adapter(model, adapter) do
    enforcer = %__MODULE__{
      model: model,
      adapter: adapter,
      enabled: true,
      auto_save: true,
      auto_build_role_links: true,
      auto_notify_watcher: true,
      function_map: init_function_map(),
      role_manager: RoleManager.new_role_manager(10)
    }

    case load_policy(enforcer) do
      {:ok, updated_enforcer} -> {:ok, updated_enforcer}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Loads policy from the adapter.
  """
  @spec load_policy(t()) :: {:ok, t()} | {:error, term()}
  def load_policy(%__MODULE__{adapter: adapter, model: model} = enforcer) do
    case Adapter.load_policy(adapter, model) do
      {:ok, policies, grouping_policies} ->
        updated_enforcer = %{enforcer |
          policies: policies,
          grouping_policies: grouping_policies
        }

        if enforcer.auto_build_role_links do
          build_role_links(updated_enforcer)
        else
          {:ok, updated_enforcer}
        end

      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Saves policy to the adapter.
  """
  @spec save_policy(t()) :: {:ok, t()} | {:error, term()}
  def save_policy(%__MODULE__{adapter: adapter, policies: policies, grouping_policies: grouping_policies} = enforcer) do
    case Adapter.save_policy(adapter, policies, grouping_policies) do
      :ok -> {:ok, enforcer}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  The main enforcement function. Returns true if the request is allowed.
  """
  @spec enforce(t(), list()) :: boolean()
  def enforce(%__MODULE__{enabled: false}, _request), do: true

  def enforce(%__MODULE__{model: model, policies: policies} = enforcer, request) do
    # Get the matcher expression from the model
    matcher_expr = Model.get_matcher(model)

    # Evaluate the request against all policies
    policies
    |> Map.values()
    |> List.flatten()
    |> Enum.any?(fn policy ->
      evaluate_policy(enforcer, policy, request, matcher_expr)
    end)
  end

  @doc """
  Builds role inheritance links.
  """
  @spec build_role_links(t()) :: {:ok, t()} | {:error, term()}
  def build_role_links(%__MODULE__{role_manager: role_manager, grouping_policies: grouping_policies} = enforcer) do
    # Clear existing role links
    RoleManager.clear(role_manager)

    # Build role links from grouping policies
    grouping_policies
    |> Map.values()
    |> List.flatten()
    |> Enum.each(fn policy ->
      if length(policy) >= 2 do
        [user, role | domain] = policy
        domain_value = if domain != [], do: hd(domain), else: ""
        RoleManager.add_link(role_manager, user, role, domain_value)
      end
    end)

    {:ok, enforcer}
  end

  @doc """
  Enables or disables the enforcer.
  """
  @spec enable_enforce(t(), boolean()) :: t()
  def enable_enforce(enforcer, enable) do
    %{enforcer | enabled: enable}
  end

  @doc """
  Enables or disables auto-save.
  """
  @spec enable_auto_save(t(), boolean()) :: t()
  def enable_auto_save(enforcer, auto_save) do
    %{enforcer | auto_save: auto_save}
  end

  # Private functions

  defp init_function_map do
    %{
      "keyMatch" => &key_match/2,
      "keyMatch2" => &key_match2/2,
      "regexMatch" => &regex_match/2,
      "ipMatch" => &ip_match/2,
      "globMatch" => &glob_match/2
    }
  end

  defp evaluate_policy(enforcer, policy, request, matcher_expr) do
    # This is a simplified evaluation - in practice, this would parse and evaluate
    # the matcher expression with the policy and request parameters
    # For now, we'll do a simple string-based matching
    case {policy, request} do
      {[sub, obj, act], [req_sub, req_obj, req_act]} ->
        sub == req_sub and obj == req_obj and act == req_act
      _ ->
        false
    end
  end

  # Built-in functions
  defp key_match(key1, key2) do
    # Implementation of keyMatch function
    String.match?(key1, ~r/#{Regex.escape(key2)}/)
  end

  defp key_match2(key1, key2) do
    # Implementation of keyMatch2 function
    key_match(key1, key2)
  end

  defp regex_match(key1, key2) do
    String.match?(key1, ~r/#{key2}/)
  end

  defp ip_match(ip1, ip2) do
    # Simple IP matching - would need proper CIDR implementation
    ip1 == ip2
  end

  defp glob_match(key1, key2) do
    # Simple glob matching
    String.match?(key1, ~r/#{String.replace(key2, "*", ".*")}/)
  end
end