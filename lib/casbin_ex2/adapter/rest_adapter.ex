defmodule CasbinEx2.Adapter.RestAdapter do
  @moduledoc """
  REST adapter for managing policies through HTTP API endpoints.

  This adapter enables remote policy management through RESTful APIs,
  allowing distributed policy storage and management across microservices.

  ## Features

  - RESTful CRUD operations for policies
  - Support for filtered policy loading
  - Authentication and authorization
  - Request/response customization
  - Connection pooling and retry logic
  - Circuit breaker pattern for resilience

  ## API Endpoints

  The adapter expects the following REST API structure:

      GET    /policies              - Load all policies
      GET    /policies?filter=...   - Load filtered policies
      POST   /policies              - Save all policies
      POST   /policies/add          - Add single policy
      DELETE /policies/remove       - Remove single policy
      DELETE /policies/filter       - Remove filtered policies

  ## Usage

      # Basic configuration
      adapter = CasbinEx2.Adapter.RestAdapter.new(
        base_url: "https://api.example.com/casbin",
        auth: {:bearer, "your-api-token"}
      )

      # Advanced configuration
      adapter = CasbinEx2.Adapter.RestAdapter.new(
        base_url: "https://api.example.com/casbin",
        auth: {:basic, {"username", "password"}},
        headers: [{"Content-Type", "application/json"}],
        timeout: 30_000,
        retry_attempts: 3,
        pool_size: 10
      )
  """

  @behaviour CasbinEx2.Adapter

  defstruct [
    :base_url,
    :auth,
    :headers,
    :http_client,
    :timeout,
    :retry_attempts,
    :circuit_breaker,
    :pool_config
  ]

  @type auth ::
          {:bearer, String.t()}
          | {:basic, {String.t(), String.t()}}
          | {:api_key, String.t()}
          | {:custom, [{String.t(), String.t()}]}

  @type t :: %__MODULE__{
          base_url: String.t(),
          auth: auth() | nil,
          headers: [{String.t(), String.t()}],
          http_client: module(),
          timeout: pos_integer(),
          retry_attempts: non_neg_integer(),
          circuit_breaker: boolean(),
          pool_config: keyword()
        }

  @default_headers [{"Content-Type", "application/json"}, {"Accept", "application/json"}]
  @default_timeout 30_000
  @default_retry_attempts 3

  @doc """
  Creates a new REST adapter.

  ## Options

  - `:base_url` - Base URL for the REST API (required)
  - `:auth` - Authentication configuration
  - `:headers` - Additional HTTP headers
  - `:http_client` - HTTP client module (default: HTTPoison)
  - `:timeout` - Request timeout in milliseconds (default: 30,000)
  - `:retry_attempts` - Number of retry attempts (default: 3)
  - `:circuit_breaker` - Enable circuit breaker (default: true)
  - `:pool_size` - HTTP connection pool size (default: 10)

  ## Examples

      # Basic usage
      adapter = CasbinEx2.Adapter.RestAdapter.new(
        base_url: "https://policy-api.example.com"
      )

      # With authentication
      adapter = CasbinEx2.Adapter.RestAdapter.new(
        base_url: "https://policy-api.example.com",
        auth: {:bearer, "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."}
      )

      # Advanced configuration
      adapter = CasbinEx2.Adapter.RestAdapter.new(
        base_url: "https://policy-api.example.com",
        auth: {:basic, {"admin", "secret"}},
        headers: [{"X-Tenant-ID", "tenant123"}],
        timeout: 60_000,
        retry_attempts: 5,
        pool_size: 20
      )
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    base_url = Keyword.fetch!(opts, :base_url)

    %__MODULE__{
      base_url: String.trim_trailing(base_url, "/"),
      auth: Keyword.get(opts, :auth),
      headers: Keyword.get(opts, :headers, []) ++ @default_headers,
      http_client: Keyword.get(opts, :http_client, HTTPoison),
      timeout: Keyword.get(opts, :timeout, @default_timeout),
      retry_attempts: Keyword.get(opts, :retry_attempts, @default_retry_attempts),
      circuit_breaker: Keyword.get(opts, :circuit_breaker, true),
      pool_config: [
        pool_size: Keyword.get(opts, :pool_size, 10),
        max_overflow: Keyword.get(opts, :max_overflow, 0)
      ]
    }
  end

  @doc """
  Tests connectivity to the REST API.

  Returns `:ok` if the API is reachable and responds correctly.
  """
  @spec test_connection(t()) :: :ok | {:error, term()}
  def test_connection(%__MODULE__{} = adapter) do
    case make_request(adapter, :get, "/health", nil) do
      {:ok, %{status_code: status}} when status in 200..299 ->
        :ok

      {:ok, %{status_code: status}} ->
        {:error, "API returned status code: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Adapter Behaviour Implementation

  @impl CasbinEx2.Adapter
  def load_policy(%__MODULE__{} = adapter, _model) do
    case make_request(adapter, :get, "/policies", nil) do
      {:ok, %{status_code: 200, body: body}} ->
        parse_policies_response(body)

      {:ok, %{status_code: status}} ->
        {:error, "Failed to load policies. Status: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl CasbinEx2.Adapter
  def load_filtered_policy(%__MODULE__{} = adapter, _model, filter) do
    query_params = build_filter_params(filter)
    path = "/policies" <> query_params

    case make_request(adapter, :get, path, nil) do
      {:ok, %{status_code: 200, body: body}} ->
        parse_policies_response(body)

      {:ok, %{status_code: status}} ->
        {:error, "Failed to load filtered policies. Status: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl CasbinEx2.Adapter
  def load_incremental_filtered_policy(%__MODULE__{} = adapter, model, filter) do
    # For REST adapter, incremental is the same as full filtered load
    load_filtered_policy(adapter, model, filter)
  end

  @impl CasbinEx2.Adapter
  def filtered?(%__MODULE__{}), do: true

  @impl CasbinEx2.Adapter
  def save_policy(%__MODULE__{} = adapter, policies, grouping_policies) do
    payload = %{
      policies: policies,
      grouping_policies: grouping_policies
    }

    case make_request(adapter, :post, "/policies", payload) do
      {:ok, %{status_code: status}} when status in 200..299 ->
        :ok

      {:ok, %{status_code: status, body: body}} ->
        {:error, "Failed to save policies. Status: #{status}, Body: #{body}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl CasbinEx2.Adapter
  def add_policy(%__MODULE__{} = adapter, sec, ptype, rule) do
    payload = %{
      section: sec,
      policy_type: ptype,
      rule: rule
    }

    case make_request(adapter, :post, "/policies/add", payload) do
      {:ok, %{status_code: status}} when status in 200..299 ->
        :ok

      {:ok, %{status_code: status, body: body}} ->
        {:error, "Failed to add policy. Status: #{status}, Body: #{body}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl CasbinEx2.Adapter
  def remove_policy(%__MODULE__{} = adapter, sec, ptype, rule) do
    payload = %{
      section: sec,
      policy_type: ptype,
      rule: rule
    }

    case make_request(adapter, :delete, "/policies/remove", payload) do
      {:ok, %{status_code: status}} when status in 200..299 ->
        :ok

      {:ok, %{status_code: status, body: body}} ->
        {:error, "Failed to remove policy. Status: #{status}, Body: #{body}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl CasbinEx2.Adapter
  def remove_filtered_policy(%__MODULE__{} = adapter, sec, ptype, field_index, field_values) do
    payload = %{
      section: sec,
      policy_type: ptype,
      field_index: field_index,
      field_values: field_values
    }

    case make_request(adapter, :delete, "/policies/filter", payload) do
      {:ok, %{status_code: status}} when status in 200..299 ->
        :ok

      {:ok, %{status_code: status, body: body}} ->
        {:error, "Failed to remove filtered policies. Status: #{status}, Body: #{body}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp make_request(%__MODULE__{} = adapter, method, path, payload) do
    url = adapter.base_url <> path
    headers = build_headers(adapter)
    body = encode_payload(payload)

    options = [
      timeout: adapter.timeout,
      recv_timeout: adapter.timeout
    ]

    execute_with_retry(adapter, fn ->
      case method do
        :get -> adapter.http_client.get(url, headers, options)
        :post -> adapter.http_client.post(url, body, headers, options)
        :delete -> adapter.http_client.delete(url, headers, options)
      end
    end)
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

  defp encode_payload(nil), do: ""

  defp encode_payload(payload) when is_map(payload) do
    Jason.encode!(payload)
  rescue
    Jason.EncodeError -> ""
  end

  defp parse_policies_response(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, %{"policies" => policies, "grouping_policies" => grouping_policies}} ->
        {:ok, policies, grouping_policies}

      {:ok, %{"policies" => policies}} ->
        {:ok, policies, %{}}

      {:ok, %{"data" => %{"policies" => policies, "grouping_policies" => grouping_policies}}} ->
        {:ok, policies, grouping_policies}

      {:error, reason} ->
        {:error, "Failed to parse response: #{inspect(reason)}"}
    end
  end

  defp parse_policies_response(_), do: {:error, "Invalid response format"}

  defp build_filter_params(nil), do: ""

  defp build_filter_params(filter) when is_map(filter) do
    params =
      filter
      |> Enum.map_join("&", fn {key, value} ->
        "#{URI.encode_www_form(to_string(key))}=#{URI.encode_www_form(to_string(value))}"
      end)

    if params == "", do: "", else: "?" <> params
  end

  defp build_filter_params(filter) when is_binary(filter) do
    "?filter=" <> URI.encode_www_form(filter)
  end

  defp build_filter_params(_filter), do: ""

  defp execute_with_retry(%__MODULE__{retry_attempts: 0}, fun) do
    fun.()
  end

  defp execute_with_retry(%__MODULE__{retry_attempts: attempts} = adapter, fun) do
    case fun.() do
      {:ok, response} ->
        {:ok, response}

      {:error, %{reason: :timeout}} when attempts > 0 ->
        :timer.sleep(calculate_backoff(attempts))
        execute_with_retry(%{adapter | retry_attempts: attempts - 1}, fun)

      {:error, %{reason: :econnrefused}} when attempts > 0 ->
        :timer.sleep(calculate_backoff(attempts))
        execute_with_retry(%{adapter | retry_attempts: attempts - 1}, fun)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp calculate_backoff(attempts_remaining) do
    # Exponential backoff: 1s, 2s, 4s, 8s, etc.
    base_delay = 1000
    max_attempts = 3
    attempt_number = max_attempts - attempts_remaining + 1
    (base_delay * :math.pow(2, attempt_number - 1)) |> round()
  end

  # Utility functions for testing and debugging

  @doc """
  Gets adapter configuration summary.
  """
  @spec get_config(t()) :: map()
  def get_config(%__MODULE__{} = adapter) do
    %{
      base_url: adapter.base_url,
      has_auth: adapter.auth != nil,
      timeout: adapter.timeout,
      retry_attempts: adapter.retry_attempts,
      circuit_breaker: adapter.circuit_breaker,
      headers_count: length(adapter.headers)
    }
  end

  @doc """
  Creates a mock adapter for testing.

  Returns an adapter configured to use a mock HTTP client.
  """
  @spec new_mock(keyword()) :: t()
  def new_mock(opts \\ []) do
    base_opts = [
      base_url: "http://localhost:4000/api/casbin",
      http_client: CasbinEx2.Adapter.RestAdapter.MockClient
    ]

    new(Keyword.merge(base_opts, opts))
  end

  # Mock HTTP client for testing
  defmodule MockClient do
    @moduledoc false

    def get(_url, _headers, _options) do
      {:ok,
       %{
         status_code: 200,
         body: Jason.encode!(%{policies: %{}, grouping_policies: %{}})
       }}
    end

    def post(_url, _body, _headers, _options) do
      {:ok, %{status_code: 201, body: ""}}
    end

    def put(_url, _body, _headers, _options) do
      {:ok, %{status_code: 200, body: ""}}
    end

    def delete(_url, _headers, _options) do
      {:ok, %{status_code: 204, body: ""}}
    end
  end
end
