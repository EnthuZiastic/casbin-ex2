defmodule CasbinEx2.Frontend do
  @moduledoc """
  Frontend utilities for JavaScript interoperability and web client integration.

  This module provides helper functions to export Casbin model and policy data
  in formats that are easily consumable by JavaScript frontends and web clients.

  The primary use case is for web applications that need to enforce permissions
  on the client side (with server-side validation) or display permission data
  in user interfaces.
  """

  alias CasbinEx2.Enforcer

  @doc """
  Gets all permission data for a user in a JSON-serializable format.

  This function exports the complete model configuration and all policy rules
  in a format that can be easily consumed by JavaScript clients (casbin.js).

  ## Parameters
  - `enforcer` - The enforcer instance
  - `user` - The username to get permissions for (currently unused but kept for API compatibility)

  ## Returns
  - `{:ok, json_string}` - JSON string containing model and policies
  - `{:error, reason}` - If serialization fails

  ## Output Format
  The returned JSON contains:
  - `"m"` - The model configuration as text
  - `"p"` - All policy rules (as arrays with ptype prefix)
  - `"g"` - All grouping policy rules (as arrays with ptype prefix)

  ## Examples
      iex> {:ok, enforcer} = CasbinEx2.Enforcer.init("examples/rbac_model.conf", "examples/rbac_policy.csv")
      iex> {:ok, json} = CasbinEx2.Frontend.casbin_js_get_permission_for_user(enforcer, "alice")
      iex> data = Jason.decode!(json)
      iex> Map.keys(data)
      ["m", "p", "g"]

      # Example output structure:
      # {
      #   "m": "[request_definition]\\nr = sub, obj, act\\n...",
      #   "p": [
      #     ["p", "alice", "data1", "read"],
      #     ["p", "bob", "data2", "write"]
      #   ],
      #   "g": [
      #     ["g", "alice", "admin"],
      #     ["g", "bob", "user"]
      #   ]
      # }
  """
  @spec casbin_js_get_permission_for_user(Enforcer.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def casbin_js_get_permission_for_user(
        %Enforcer{model: model, policies: policies, grouping_policies: grouping_policies},
        _user
      ) do
    # Build the output map
    output = %{
      "m" => model_to_text(model),
      "p" => format_policies(policies),
      "g" => format_policies(grouping_policies)
    }

    # Encode to JSON
    case Jason.encode(output, escape: :unicode_safe) do
      {:ok, json} -> {:ok, json}
      {:error, reason} -> {:error, "Failed to encode JSON: #{inspect(reason)}"}
    end
  end

  @doc """
  Converts a model struct to its text representation.

  Takes the model configuration and converts it back to the INI-style
  text format used in .conf files.

  ## Parameters
  - `model` - The model struct

  ## Returns
  String representation of the model in INI format
  """
  @spec model_to_text(CasbinEx2.Model.t()) :: String.t()
  def model_to_text(%CasbinEx2.Model{
        request_definition: request_definition,
        policy_definition: policy_definition,
        role_definition: role_definition,
        policy_effect: policy_effect,
        matchers: matchers
      }) do
    sections = []

    # Add request definition
    sections =
      if map_size(request_definition) > 0 do
        request_section =
          "[request_definition]\n" <>
            Enum.map_join(request_definition, "\n", fn {key, value} -> "#{key} = #{value}" end)

        [request_section | sections]
      else
        sections
      end

    # Add policy definition
    sections =
      if map_size(policy_definition) > 0 do
        policy_section =
          "[policy_definition]\n" <>
            Enum.map_join(policy_definition, "\n", fn {key, value} -> "#{key} = #{value}" end)

        [policy_section | sections]
      else
        sections
      end

    # Add role definition
    sections =
      if map_size(role_definition) > 0 do
        role_section =
          "[role_definition]\n" <>
            Enum.map_join(role_definition, "\n", fn {key, value} -> "#{key} = #{value}" end)

        [role_section | sections]
      else
        sections
      end

    # Add policy effect
    sections =
      if map_size(policy_effect) > 0 do
        effect_section =
          "[policy_effect]\n" <>
            Enum.map_join(policy_effect, "\n", fn {key, value} -> "#{key} = #{value}" end)

        [effect_section | sections]
      else
        sections
      end

    # Add matchers
    sections =
      if map_size(matchers) > 0 do
        matcher_section =
          "[matchers]\n" <>
            Enum.map_join(matchers, "\n", fn {key, value} -> "#{key} = #{value}" end)

        [matcher_section | sections]
      else
        sections
      end

    # Join all sections with double newline
    sections
    |> Enum.reverse()
    |> Enum.join("\n\n")
    |> Kernel.<>("\n")
  end

  # Private helper functions

  @spec format_policies(map()) :: [[String.t()]]
  defp format_policies(policies) when is_map(policies) do
    policies
    |> Enum.flat_map(fn {ptype, rules} ->
      Enum.map(rules, fn rule ->
        [ptype | rule]
      end)
    end)
    |> Enum.sort()
  end

  defp format_policies(_), do: []
end
