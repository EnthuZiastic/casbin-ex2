defmodule CasbinEx2.Adapter do
  @moduledoc """
  Adapter interface for loading and saving policies.
  """

  alias CasbinEx2.Model

  @type t :: module()

  @doc """
  Loads all policies from the storage.
  """
  @callback load_policy(t(), Model.t()) :: {:ok, map(), map()} | {:error, term()}

  @doc """
  Loads filtered policies from the storage.
  """
  @callback load_filtered_policy(t(), Model.t(), any()) :: {:ok, map(), map()} | {:error, term()}

  @doc """
  Loads incremental filtered policies from the storage.
  """
  @callback load_incremental_filtered_policy(t(), Model.t(), any()) ::
              {:ok, map(), map()} | {:error, term()}

  @doc """
  Checks if the adapter supports filtered loading.
  """
  @callback is_filtered(t()) :: boolean()

  @doc """
  Saves all policies to the storage.
  """
  @callback save_policy(t(), map(), map()) :: :ok | {:error, term()}

  @doc """
  Adds a policy rule to the storage.
  """
  @callback add_policy(t(), String.t(), String.t(), [String.t()]) :: :ok | {:error, term()}

  @doc """
  Removes a policy rule from the storage.
  """
  @callback remove_policy(t(), String.t(), String.t(), [String.t()]) :: :ok | {:error, term()}

  @doc """
  Removes filtered policy rules from the storage.
  """
  @callback remove_filtered_policy(t(), String.t(), String.t(), integer(), [String.t()]) ::
              :ok | {:error, term()}

  @doc """
  Loads all policies using the given adapter.
  """
  @spec load_policy(t(), Model.t()) :: {:ok, map(), map()} | {:error, term()}
  def load_policy(adapter, model) do
    adapter.__struct__.load_policy(adapter, model)
  end

  @doc """
  Loads filtered policies using the given adapter.
  """
  @spec load_filtered_policy(t(), Model.t(), any()) :: {:ok, map(), map()} | {:error, term()}
  def load_filtered_policy(adapter, model, filter) do
    adapter.__struct__.load_filtered_policy(adapter, model, filter)
  end

  @doc """
  Loads incremental filtered policies using the given adapter.
  """
  @spec load_incremental_filtered_policy(t(), Model.t(), any()) ::
          {:ok, map(), map()} | {:error, term()}
  def load_incremental_filtered_policy(adapter, model, filter) do
    adapter.__struct__.load_incremental_filtered_policy(adapter, model, filter)
  end

  @doc """
  Checks if the adapter supports filtered loading.
  """
  @spec is_filtered(t()) :: boolean()
  def is_filtered(adapter) do
    adapter.__struct__.is_filtered(adapter)
  end

  @doc """
  Saves all policies using the given adapter.
  """
  @spec save_policy(t(), map(), map()) :: :ok | {:error, term()}
  def save_policy(adapter, policies, grouping_policies) do
    adapter.__struct__.save_policy(adapter, policies, grouping_policies)
  end

  @doc """
  Adds a policy using the given adapter.
  """
  @spec add_policy(t(), String.t(), String.t(), [String.t()]) :: :ok | {:error, term()}
  def add_policy(adapter, sec, ptype, rule) do
    adapter.__struct__.add_policy(adapter, sec, ptype, rule)
  end

  @doc """
  Removes a policy using the given adapter.
  """
  @spec remove_policy(t(), String.t(), String.t(), [String.t()]) :: :ok | {:error, term()}
  def remove_policy(adapter, sec, ptype, rule) do
    adapter.__struct__.remove_policy(adapter, sec, ptype, rule)
  end
end
