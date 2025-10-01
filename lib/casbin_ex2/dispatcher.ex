defmodule CasbinEx2.Dispatcher do
  @moduledoc """
  Behavior for Casbin policy dispatchers.

  A dispatcher is responsible for synchronizing policy changes across multiple
  enforcer instances in distributed scenarios. When policies are modified in one
  enforcer, the dispatcher notifies all other enforcers to apply the same changes.

  ## Example Use Case

  In a distributed system with multiple application nodes, each running its own
  enforcer instance, the dispatcher ensures that when policies are updated on one
  node, all other nodes receive and apply the same updates.

  ## Callbacks

  All callbacks receive:
  - `sec` - Section type ("p" for policies, "g" for grouping policies)
  - `ptype` - Policy type (e.g., "p", "p2", "g", "g2")
  - Policy rules as lists of strings

  ## Implementation Notes

  Implementations should:
  - Be asynchronous to avoid blocking policy operations
  - Handle network failures gracefully
  - Provide retry logic for failed dispatches
  - Support batching for performance

  ## Example Implementation

      defmodule MyApp.RedisDispatcher do
        @behaviour CasbinEx2.Dispatcher

        def add_policies(sec, ptype, rules) do
          # Publish to Redis channel
          publish("casbin:add", %{sec: sec, ptype: ptype, rules: rules})
        end

        # ... implement other callbacks
      end
  """

  @doc """
  Adds policies to all enforcer instances.

  ## Parameters
  - `sec` - Section type ("p" or "g")
  - `ptype` - Policy type
  - `rules` - List of policy rules to add

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  @callback add_policies(sec :: String.t(), ptype :: String.t(), rules :: [[String.t()]]) ::
              :ok | {:error, term()}

  @doc """
  Removes policies from all enforcer instances.

  ## Parameters
  - `sec` - Section type ("p" or "g")
  - `ptype` - Policy type
  - `rules` - List of policy rules to remove

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  @callback remove_policies(sec :: String.t(), ptype :: String.t(), rules :: [[String.t()]]) ::
              :ok | {:error, term()}

  @doc """
  Removes filtered policies from all enforcer instances.

  ## Parameters
  - `sec` - Section type ("p" or "g")
  - `ptype` - Policy type
  - `field_index` - Index of the field to match (0-based)
  - `field_values` - Values to match for filtering

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  @callback remove_filtered_policy(
              sec :: String.t(),
              ptype :: String.t(),
              field_index :: integer(),
              field_values :: [String.t()]
            ) :: :ok | {:error, term()}

  @doc """
  Clears all policies from all enforcer instances.

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  @callback clear_policy() :: :ok | {:error, term()}

  @doc """
  Updates a policy rule in all enforcer instances.

  ## Parameters
  - `sec` - Section type ("p" or "g")
  - `ptype` - Policy type
  - `old_rule` - The policy rule to replace
  - `new_rule` - The new policy rule

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  @callback update_policy(
              sec :: String.t(),
              ptype :: String.t(),
              old_rule :: [String.t()],
              new_rule :: [String.t()]
            ) :: :ok | {:error, term()}

  @callback update_policies(
              sec :: String.t(),
              ptype :: String.t(),
              old_rules :: [[String.t()]],
              new_rules :: [[String.t()]]
            ) :: :ok | {:error, term()}

  @doc """
  Updates filtered policies in all enforcer instances.

  Removes old rules matching the filter and adds new rules.

  ## Parameters
  - `sec` - Section type ("p" or "g")
  - `ptype` - Policy type
  - `old_rules` - Old policy rules to remove
  - `new_rules` - New policy rules to add

  ## Returns
  - `:ok` on success
  - `{:error, reason}` on failure
  """
  @callback update_filtered_policies(
              sec :: String.t(),
              ptype :: String.t(),
              old_rules :: [[String.t()]],
              new_rules :: [[String.t()]]
            ) :: :ok | {:error, term()}
end
