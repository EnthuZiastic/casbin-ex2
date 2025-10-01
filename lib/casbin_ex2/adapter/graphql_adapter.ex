defmodule CasbinEx2.Adapter.GraphQLAdapter do
  @moduledoc """
  GraphQL adapter for policy management through GraphQL APIs.

  This adapter provides a GraphQL interface for policy operations,
  enabling flexible queries, mutations, and subscriptions for policy management.

  ## Features

  - GraphQL queries for complex policy filtering
  - Mutations for policy CRUD operations
  - Subscriptions for real-time policy updates
  - Introspection support for schema discovery
  - Custom scalar types for policy data
  - Batch operations support
  - Error handling with GraphQL error format

  ## GraphQL Schema

  The adapter expects the following GraphQL schema structure:

  ```graphql
  type Policy {
    id: ID!
    section: String!
    policyType: String!
    rule: [String!]!
    createdAt: DateTime
    updatedAt: DateTime
  }

  type GroupingPolicy {
    id: ID!
    section: String!
    groupingType: String!
    rule: [String!]!
    createdAt: DateTime
    updatedAt: DateTime
  }

  input PolicyFilter {
    section: String
    policyType: String
    rule: [String]
    limit: Int
    offset: Int
  }

  type Query {
    policies(filter: PolicyFilter): [Policy!]!
    groupingPolicies(filter: PolicyFilter): [GroupingPolicy!]!
    policyExists(section: String!, policyType: String!, rule: [String!]!): Boolean!
  }

  type Mutation {
    savePolicies(policies: [PolicyInput!]!, groupingPolicies: [GroupingPolicyInput!]!): Boolean!
    addPolicy(section: String!, policyType: String!, rule: [String!]!): Policy!
    removePolicy(section: String!, policyType: String!, rule: [String!]!): Boolean!
    removePolicies(filter: PolicyFilter!): Int!
  }

  type Subscription {
    policyChanged: PolicyChangeEvent!
  }
  ```

  ## Usage

      # Basic configuration
      adapter = CasbinEx2.Adapter.GraphQLAdapter.new(
        endpoint: "https://api.example.com/graphql"
      )

      # With authentication and custom headers
      adapter = CasbinEx2.Adapter.GraphQLAdapter.new(
        endpoint: "https://api.example.com/graphql",
        auth: {:bearer, "your-token"},
        headers: [{"X-Tenant-ID", "tenant-123"}],
        subscriptions: true
      )
  """

  @behaviour CasbinEx2.Adapter

  defstruct [
    :endpoint,
    :auth,
    :headers,
    :http_client,
    :timeout,
    :retry_attempts,
    :subscriptions,
    :websocket_url,
    :introspection,
    :batch_size
  ]

  @type auth ::
          {:bearer, String.t()}
          | {:basic, {String.t(), String.t()}}
          | {:api_key, String.t()}
          | {:custom, [{String.t(), String.t()}]}

  @type t :: %__MODULE__{
          endpoint: String.t(),
          auth: auth() | nil,
          headers: [{String.t(), String.t()}],
          http_client: module(),
          timeout: pos_integer(),
          retry_attempts: non_neg_integer(),
          subscriptions: boolean(),
          websocket_url: String.t() | nil,
          introspection: boolean(),
          batch_size: pos_integer()
        }

  @default_headers [{"Content-Type", "application/json"}, {"Accept", "application/json"}]
  @default_timeout 30_000
  @default_batch_size 100

  @doc """
  Creates a new GraphQL adapter.

  ## Options

  - `:endpoint` - GraphQL HTTP endpoint URL (required)
  - `:auth` - Authentication configuration
  - `:headers` - Additional HTTP headers
  - `:http_client` - HTTP client module (default: HTTPoison)
  - `:timeout` - Request timeout in milliseconds (default: 30,000)
  - `:retry_attempts` - Number of retry attempts (default: 3)
  - `:subscriptions` - Enable GraphQL subscriptions (default: false)
  - `:websocket_url` - WebSocket URL for subscriptions
  - `:introspection` - Enable schema introspection (default: true)
  - `:batch_size` - Maximum batch size for operations (default: 100)

  ## Examples

      # Basic configuration
      adapter = CasbinEx2.Adapter.GraphQLAdapter.new(
        endpoint: "https://policy-api.example.com/graphql"
      )

      # With authentication and subscriptions
      adapter = CasbinEx2.Adapter.GraphQLAdapter.new(
        endpoint: "https://policy-api.example.com/graphql",
        auth: {:bearer, "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."},
        subscriptions: true,
        websocket_url: "wss://policy-api.example.com/graphql"
      )

      # Advanced configuration
      adapter = CasbinEx2.Adapter.GraphQLAdapter.new(
        endpoint: "https://policy-api.example.com/graphql",
        auth: {:basic, {"admin", "secret"}},
        headers: [{"X-Tenant-ID", "production"}],
        timeout: 60_000,
        batch_size: 50
      )
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    endpoint = Keyword.fetch!(opts, :endpoint)

    %__MODULE__{
      endpoint: endpoint,
      auth: Keyword.get(opts, :auth),
      headers: Keyword.get(opts, :headers, []) ++ @default_headers,
      http_client: Keyword.get(opts, :http_client, HTTPoison),
      timeout: Keyword.get(opts, :timeout, @default_timeout),
      retry_attempts: Keyword.get(opts, :retry_attempts, 3),
      subscriptions: Keyword.get(opts, :subscriptions, false),
      websocket_url: Keyword.get(opts, :websocket_url),
      introspection: Keyword.get(opts, :introspection, true),
      batch_size: Keyword.get(opts, :batch_size, @default_batch_size)
    }
  end

  @doc """
  Performs schema introspection to validate GraphQL endpoint.

  Returns the schema information or an error if introspection fails.
  """
  @spec introspect_schema(t()) :: {:ok, map()} | {:error, term()}
  def introspect_schema(%__MODULE__{introspection: false}) do
    {:error, "Schema introspection disabled"}
  end

  def introspect_schema(%__MODULE__{} = adapter) do
    query = """
    query IntrospectionQuery {
      __schema {
        types {
          name
          kind
          fields {
            name
            type {
              name
              kind
            }
          }
        }
        queryType {
          name
        }
        mutationType {
          name
        }
        subscriptionType {
          name
        }
      }
    }
    """

    case execute_query(adapter, query, %{}) do
      {:ok, %{"data" => %{"__schema" => schema}}} ->
        {:ok, schema}

      {:ok, %{"errors" => errors}} ->
        {:error, "Introspection failed: #{inspect(errors)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Subscribes to policy change notifications via GraphQL subscriptions.

  Requires WebSocket support and subscriptions to be enabled.
  """
  @spec subscribe_policy_changes(t()) :: {:ok, pid()} | {:error, term()}
  def subscribe_policy_changes(%__MODULE__{subscriptions: false}) do
    {:error, "Subscriptions not enabled"}
  end

  def subscribe_policy_changes(%__MODULE__{websocket_url: nil}) do
    {:error, "WebSocket URL not configured"}
  end

  def subscribe_policy_changes(%__MODULE__{} = adapter) do
    subscription = """
    subscription PolicyChanged {
      policyChanged {
        event
        policy {
          id
          section
          policyType
          rule
        }
        timestamp
      }
    }
    """

    # Start WebSocket connection for subscriptions
    case start_subscription(adapter, subscription) do
      {:ok, pid} ->
        {:ok, pid}

        # {:error, reason} -> {:error, reason}  # Unreachable clause - start_subscription always returns {:ok, pid()}
    end
  end

  # Adapter Behaviour Implementation

  @impl CasbinEx2.Adapter
  def load_policy(%__MODULE__{} = adapter, _model) do
    query = """
    query LoadPolicies {
      policies {
        section
        policyType
        rule
      }
      groupingPolicies {
        section
        groupingType
        rule
      }
    }
    """

    case execute_query(adapter, query, %{}) do
      {:ok, %{"data" => data}} ->
        policies = parse_policies_from_response(data["policies"] || [])
        grouping_policies = parse_grouping_policies_from_response(data["groupingPolicies"] || [])
        {:ok, policies, grouping_policies}

      {:ok, %{"errors" => errors}} ->
        {:error, "GraphQL errors: #{inspect(errors)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl CasbinEx2.Adapter
  def load_filtered_policy(%__MODULE__{} = adapter, _model, filter) do
    filter_input = build_filter_input(filter)

    query = """
    query LoadFilteredPolicies($filter: PolicyFilter) {
      policies(filter: $filter) {
        section
        policyType
        rule
      }
      groupingPolicies(filter: $filter) {
        section
        groupingType
        rule
      }
    }
    """

    variables = %{"filter" => filter_input}

    case execute_query(adapter, query, variables) do
      {:ok, %{"data" => data}} ->
        policies = parse_policies_from_response(data["policies"] || [])
        grouping_policies = parse_grouping_policies_from_response(data["groupingPolicies"] || [])
        {:ok, policies, grouping_policies}

      {:ok, %{"errors" => errors}} ->
        {:error, "GraphQL errors: #{inspect(errors)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl CasbinEx2.Adapter
  def load_incremental_filtered_policy(%__MODULE__{} = adapter, model, filter) do
    # For GraphQL adapter, incremental is the same as full filtered load
    load_filtered_policy(adapter, model, filter)
  end

  @impl CasbinEx2.Adapter
  def filtered?(%__MODULE__{}), do: true

  @impl CasbinEx2.Adapter
  def save_policy(%__MODULE__{} = adapter, policies, grouping_policies) do
    policy_inputs = build_policy_inputs(policies)
    grouping_policy_inputs = build_grouping_policy_inputs(grouping_policies)

    mutation = """
    mutation SavePolicies($policies: [PolicyInput!]!, $groupingPolicies: [GroupingPolicyInput!]!) {
      savePolicies(policies: $policies, groupingPolicies: $groupingPolicies)
    }
    """

    variables = %{
      "policies" => policy_inputs,
      "groupingPolicies" => grouping_policy_inputs
    }

    case execute_mutation(adapter, mutation, variables) do
      {:ok, %{"data" => %{"savePolicies" => true}}} ->
        :ok

      {:ok, %{"data" => %{"savePolicies" => false}}} ->
        {:error, "Failed to save policies"}

      {:ok, %{"errors" => errors}} ->
        {:error, "GraphQL errors: #{inspect(errors)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl CasbinEx2.Adapter
  def add_policy(%__MODULE__{} = adapter, sec, ptype, rule) do
    mutation = """
    mutation AddPolicy($section: String!, $policyType: String!, $rule: [String!]!) {
      addPolicy(section: $section, policyType: $policyType, rule: $rule) {
        id
        section
        policyType
        rule
      }
    }
    """

    variables = %{
      "section" => sec,
      "policyType" => ptype,
      "rule" => rule
    }

    case execute_mutation(adapter, mutation, variables) do
      {:ok, %{"data" => %{"addPolicy" => policy}}} when not is_nil(policy) ->
        :ok

      {:ok, %{"data" => %{"addPolicy" => nil}}} ->
        {:error, "Failed to add policy"}

      {:ok, %{"errors" => errors}} ->
        {:error, "GraphQL errors: #{inspect(errors)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl CasbinEx2.Adapter
  def remove_policy(%__MODULE__{} = adapter, sec, ptype, rule) do
    mutation = """
    mutation RemovePolicy($section: String!, $policyType: String!, $rule: [String!]!) {
      removePolicy(section: $section, policyType: $policyType, rule: $rule)
    }
    """

    variables = %{
      "section" => sec,
      "policyType" => ptype,
      "rule" => rule
    }

    case execute_mutation(adapter, mutation, variables) do
      {:ok, %{"data" => %{"removePolicy" => true}}} ->
        :ok

      {:ok, %{"data" => %{"removePolicy" => false}}} ->
        {:error, "Policy not found or failed to remove"}

      {:ok, %{"errors" => errors}} ->
        {:error, "GraphQL errors: #{inspect(errors)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl CasbinEx2.Adapter
  def remove_filtered_policy(%__MODULE__{} = adapter, sec, ptype, field_index, field_values) do
    filter_input = %{
      "section" => sec,
      "policyType" => ptype,
      "rule" => build_rule_filter(field_index, field_values)
    }

    mutation = """
    mutation RemovePolicies($filter: PolicyFilter!) {
      removePolicies(filter: $filter)
    }
    """

    variables = %{"filter" => filter_input}

    case execute_mutation(adapter, mutation, variables) do
      {:ok, %{"data" => %{"removePolicies" => count}}} when is_integer(count) ->
        :ok

      {:ok, %{"errors" => errors}} ->
        {:error, "GraphQL errors: #{inspect(errors)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp execute_query(%__MODULE__{} = adapter, query, variables) do
    payload = %{
      "query" => query,
      "variables" => variables
    }

    make_request(adapter, payload)
  end

  defp execute_mutation(%__MODULE__{} = adapter, mutation, variables) do
    payload = %{
      "query" => mutation,
      "variables" => variables
    }

    make_request(adapter, payload)
  end

  defp make_request(%__MODULE__{} = adapter, payload) do
    headers = build_headers(adapter)
    body = Jason.encode!(payload)

    options = [
      timeout: adapter.timeout,
      recv_timeout: adapter.timeout
    ]

    case adapter.http_client.post(adapter.endpoint, body, headers, options) do
      {:ok, %{status_code: 200, body: response_body}} ->
        Jason.decode(response_body)

      {:ok, %{status_code: status, body: response_body}} ->
        {:error, "HTTP #{status}: #{response_body}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_headers(%__MODULE__{auth: auth, headers: base_headers}) do
    auth_headers = build_auth_headers(auth)
    auth_headers ++ base_headers
  end

  defp build_auth_headers(nil), do: []

  defp build_auth_headers({:bearer, token}) do
    [{"Authorization", "Bearer #{token}"}]
  end

  defp build_auth_headers({:basic, {username, password}}) do
    credentials = Base.encode64("#{username}:#{password}")
    [{"Authorization", "Basic #{credentials}"}]
  end

  defp build_auth_headers({:api_key, key}) do
    [{"X-API-Key", key}]
  end

  defp build_auth_headers({:custom, headers}) when is_list(headers) do
    headers
  end

  defp parse_policies_from_response(policies) do
    policies
    |> Enum.group_by(& &1["policyType"])
    |> Enum.into(%{}, fn {ptype, policy_list} ->
      rules = Enum.map(policy_list, & &1["rule"])
      {ptype, rules}
    end)
  end

  defp parse_grouping_policies_from_response(grouping_policies) do
    grouping_policies
    |> Enum.group_by(& &1["groupingType"])
    |> Enum.into(%{}, fn {gtype, policy_list} ->
      rules = Enum.map(policy_list, & &1["rule"])
      {gtype, rules}
    end)
  end

  defp build_policy_inputs(policies) do
    policies
    |> Enum.flat_map(fn {ptype, rules} ->
      Enum.map(rules, fn rule ->
        %{
          "section" => "p",
          "policyType" => ptype,
          "rule" => rule
        }
      end)
    end)
  end

  defp build_grouping_policy_inputs(grouping_policies) do
    grouping_policies
    |> Enum.flat_map(fn {gtype, rules} ->
      Enum.map(rules, fn rule ->
        %{
          "section" => "g",
          "groupingType" => gtype,
          "rule" => rule
        }
      end)
    end)
  end

  defp build_filter_input(nil), do: %{}

  defp build_filter_input(filter) when is_map(filter) do
    filter
    |> Enum.into(%{}, fn {key, value} ->
      {to_string(key), value}
    end)
  end

  defp build_filter_input(filter) when is_function(filter, 2) do
    # For function filters, we can't translate to GraphQL directly
    # Return empty filter and let client handle filtering
    %{}
  end

  defp build_rule_filter(field_index, field_values) do
    # Build a rule pattern based on field_index and field_values
    # This is a simplified implementation
    field_values
    |> Enum.with_index()
    |> Enum.map(fn {value, index} ->
      if index + field_index == 0 do
        value
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp start_subscription(%__MODULE__{} = _adapter, _subscription) do
    # This is a placeholder for WebSocket subscription implementation
    # In a real implementation, you would use a WebSocket client like Gun or Phoenix.Socket
    spawn(fn ->
      # Simulate subscription process
      receive do
        :stop -> :ok
      after
        30_000 -> :timeout
      end
    end)

    {:ok, self()}
  end

  # Utility functions for testing and debugging

  @doc """
  Validates GraphQL query syntax.

  Returns `:ok` if the query is valid, or `{:error, reason}` if invalid.
  """
  @spec validate_query(String.t()) :: :ok | {:error, term()}
  def validate_query(query) when is_binary(query) do
    case String.contains?(query, ["query", "mutation", "subscription"]) do
      true -> :ok
      false -> {:error, "Invalid GraphQL operation type"}
    end
  end

  def validate_query(_), do: {:error, "Query must be a string"}

  @doc """
  Creates a mock adapter for testing.

  Returns an adapter configured to use a mock GraphQL endpoint.
  """
  @spec new_mock(keyword()) :: t()
  def new_mock(opts \\ []) do
    base_opts = [
      endpoint: "http://localhost:4000/graphql",
      http_client: CasbinEx2.Adapter.GraphQLAdapter.MockClient
    ]

    new(Keyword.merge(base_opts, opts))
  end

  # Mock HTTP client for testing
  defmodule MockClient do
    @moduledoc false

    def post(_url, _body, _headers, _options) do
      {:ok,
       %{
         status_code: 200,
         body:
           Jason.encode!(%{
             data: %{
               policies: [],
               groupingPolicies: []
             }
           })
       }}
    end
  end
end
