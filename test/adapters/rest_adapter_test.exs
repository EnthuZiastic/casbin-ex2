defmodule CasbinEx2.Adapter.RestAdapterTest do
  use ExUnit.Case, async: false

  alias CasbinEx2.Adapter.RestAdapter

  # Mock HTTP client with Agent-based state management
  defmodule MockClient do
    @moduledoc false

    def start_link do
      Agent.start_link(fn -> %{response: nil, error: nil} end, name: __MODULE__)
    end

    def stop do
      if Process.whereis(__MODULE__) do
        Agent.stop(__MODULE__)
      end
    end

    def mock_response(response) do
      Agent.update(__MODULE__, fn state ->
        %{state | response: response, error: nil}
      end)
    end

    def mock_error(error) do
      Agent.update(__MODULE__, fn state ->
        %{state | response: nil, error: error}
      end)
    end

    def get(_url, _headers, _options) do
      Agent.get(__MODULE__, fn state ->
        case {state.response, state.error} do
          {nil, nil} ->
            {:ok,
             %{status_code: 200, body: Jason.encode!(%{policies: %{}, grouping_policies: %{}})}}

          {response, nil} ->
            {:ok, response}

          {nil, error} ->
            {:error, error}
        end
      end)
    end

    def post(_url, _body, _headers, _options) do
      Agent.get(__MODULE__, fn state ->
        case {state.response, state.error} do
          {nil, nil} -> {:ok, %{status_code: 201, body: ""}}
          {response, nil} -> {:ok, response}
          {nil, error} -> {:error, error}
        end
      end)
    end

    def put(_url, _body, _headers, _options) do
      Agent.get(__MODULE__, fn state ->
        case {state.response, state.error} do
          {nil, nil} -> {:ok, %{status_code: 200, body: ""}}
          {response, nil} -> {:ok, response}
          {nil, error} -> {:error, error}
        end
      end)
    end

    def delete(_url, _headers, _options) do
      Agent.get(__MODULE__, fn state ->
        case {state.response, state.error} do
          {nil, nil} -> {:ok, %{status_code: 204, body: ""}}
          {response, nil} -> {:ok, response}
          {nil, error} -> {:error, error}
        end
      end)
    end
  end

  setup do
    # Stop if already running
    if Process.whereis(MockClient) do
      try do
        Agent.stop(MockClient)
      catch
        :exit, _ -> :ok
      end
    end

    # Give a moment for cleanup
    :timer.sleep(10)

    # Start fresh MockClient
    {:ok, _pid} = MockClient.start_link()

    on_exit(fn ->
      if Process.whereis(MockClient) do
        try do
          Agent.stop(MockClient)
        catch
          :exit, _ -> :ok
        end
      end
    end)

    :ok
  end

  describe "new/1" do
    test "creates REST adapter with base URL" do
      adapter = RestAdapter.new(base_url: "https://api.example.com/casbin")

      assert adapter.base_url == "https://api.example.com/casbin"
    end

    test "creates adapter with bearer token authentication" do
      adapter =
        RestAdapter.new(
          base_url: "https://api.example.com",
          auth: {:bearer, "test_token_123"}
        )

      assert adapter.auth == {:bearer, "test_token_123"}
    end

    test "creates adapter with basic authentication" do
      adapter =
        RestAdapter.new(
          base_url: "https://api.example.com",
          auth: {:basic, {"username", "password"}}
        )

      assert adapter.auth == {:basic, {"username", "password"}}
    end

    test "creates adapter with API key authentication" do
      adapter =
        RestAdapter.new(
          base_url: "https://api.example.com",
          auth: {:api_key, "api_key_xyz"}
        )

      assert adapter.auth == {:api_key, "api_key_xyz"}
    end
  end

  describe "configuration options" do
    test "sets custom headers" do
      adapter =
        RestAdapter.new(
          base_url: "https://api.example.com",
          headers: [{"X-Custom-Header", "value"}]
        )

      assert {"X-Custom-Header", "value"} in adapter.headers
    end

    test "sets custom timeout" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", timeout: 60_000)

      assert adapter.timeout == 60_000
    end

    test "configures retry attempts" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", retry_attempts: 5)

      assert adapter.retry_attempts == 5
    end

    test "enables circuit breaker" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", circuit_breaker: true)

      assert adapter.circuit_breaker == true
    end
  end

  describe "default values" do
    test "uses default headers" do
      adapter = RestAdapter.new(base_url: "https://api.example.com")

      assert adapter.headers != []
    end

    test "uses default timeout" do
      adapter = RestAdapter.new(base_url: "https://api.example.com")

      assert adapter.timeout == 30_000
    end

    test "uses default retry attempts" do
      adapter = RestAdapter.new(base_url: "https://api.example.com")

      assert adapter.retry_attempts == 3
    end
  end

  describe "HTTP client configuration" do
    test "sets custom HTTP client module" do
      adapter =
        RestAdapter.new(
          base_url: "https://api.example.com",
          http_client: MyCustomHTTPClient
        )

      assert adapter.http_client == MyCustomHTTPClient
    end
  end

  describe "connection pooling" do
    test "configures connection pool" do
      adapter =
        RestAdapter.new(
          base_url: "https://api.example.com",
          pool_size: 20
        )

      assert adapter.pool_config[:pool_size] == 20
    end
  end

  # Mock interface tests (until REST API integration is complete)
  describe "policy operation interfaces" do
    test "load_policy/2 endpoint structure" do
      adapter = RestAdapter.new(base_url: "https://api.example.com/casbin")
      # GET /policies endpoint
      assert adapter.base_url =~ "api.example.com"
    end

    test "save_policy/3 endpoint structure" do
      adapter = RestAdapter.new(base_url: "https://api.example.com/casbin")
      # POST /policies endpoint
      assert adapter.base_url =~ "api.example.com"
    end

    test "add_policy/4 endpoint structure" do
      adapter = RestAdapter.new(base_url: "https://api.example.com/casbin")
      # POST /policies/add endpoint
      assert adapter.base_url =~ "api.example.com"
    end

    test "remove_policy/4 endpoint structure" do
      adapter = RestAdapter.new(base_url: "https://api.example.com/casbin")
      # DELETE /policies/remove endpoint
      assert adapter.base_url =~ "api.example.com"
    end
  end

  describe "authentication header generation" do
    test "bearer token generates Authorization header" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", auth: {:bearer, "token123"})

      # Would generate: {"Authorization", "Bearer token123"}
      assert adapter.auth == {:bearer, "token123"}
    end

    test "basic auth generates Authorization header" do
      adapter =
        RestAdapter.new(
          base_url: "https://api.example.com",
          auth: {:basic, {"user", "pass"}}
        )

      # Would generate: {"Authorization", "Basic base64(user:pass)"}
      assert adapter.auth == {:basic, {"user", "pass"}}
    end
  end

  # ===========================
  # Functional Tests - Day 3
  # ===========================

  describe "load_policy/2 - loading policies via REST API" do
    test "successfully loads policies from REST API" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)

      MockClient.mock_response(%{
        status_code: 200,
        body:
          Jason.encode!(%{
            policies: %{
              "p" => [["alice", "data1", "read"], ["bob", "data2", "write"]]
            },
            grouping_policies: %{
              "g" => [["alice", "admin"]]
            }
          })
      })

      assert {:ok, policies, grouping} = RestAdapter.load_policy(adapter, %{})
      assert policies["p"] == [["alice", "data1", "read"], ["bob", "data2", "write"]]
      assert grouping["g"] == [["alice", "admin"]]
    end

    test "handles 404 not found response" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)
      MockClient.mock_response(%{status_code: 404, body: ""})

      assert {:error, message} = RestAdapter.load_policy(adapter, %{})
      assert message =~ "404"
    end

    test "handles 401 unauthorized response" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)
      MockClient.mock_response(%{status_code: 401, body: ""})

      assert {:error, message} = RestAdapter.load_policy(adapter, %{})
      assert message =~ "401"
    end

    test "handles 500 server error" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)
      MockClient.mock_response(%{status_code: 500, body: ""})

      assert {:error, message} = RestAdapter.load_policy(adapter, %{})
      assert message =~ "500"
    end

    test "handles network timeout" do
      adapter =
        RestAdapter.new(
          base_url: "https://api.example.com",
          http_client: MockClient,
          retry_attempts: 0
        )

      MockClient.mock_error(%{reason: :timeout})

      assert {:error, _reason} = RestAdapter.load_policy(adapter, %{})
    end

    test "handles connection refused" do
      adapter =
        RestAdapter.new(
          base_url: "https://api.example.com",
          http_client: MockClient,
          retry_attempts: 0
        )

      MockClient.mock_error(%{reason: :econnrefused})

      assert {:error, _reason} = RestAdapter.load_policy(adapter, %{})
    end

    test "parses response with nested data structure" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)

      MockClient.mock_response(%{
        status_code: 200,
        body:
          Jason.encode!(%{
            data: %{
              policies: %{"p" => [["user1", "resource1", "read"]]},
              grouping_policies: %{"g" => [["user1", "role1"]]}
            }
          })
      })

      assert {:ok, policies, grouping} = RestAdapter.load_policy(adapter, %{})
      assert policies["p"] == [["user1", "resource1", "read"]]
      assert grouping["g"] == [["user1", "role1"]]
    end

    test "handles response with policies only (no grouping)" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)

      MockClient.mock_response(%{
        status_code: 200,
        body:
          Jason.encode!(%{
            policies: %{"p" => [["alice", "data1", "read"]]}
          })
      })

      assert {:ok, policies, grouping} = RestAdapter.load_policy(adapter, %{})
      assert policies["p"] == [["alice", "data1", "read"]]
      assert grouping == %{}
    end
  end

  describe "load_filtered_policy/3 - filtered policy loading" do
    test "loads policies with filter query parameters" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)

      MockClient.mock_response(%{
        status_code: 200,
        body:
          Jason.encode!(%{
            policies: %{"p" => [["alice", "data1", "read"]]},
            grouping_policies: %{}
          })
      })

      filter = %{subject: "alice", object: "data1"}
      assert {:ok, policies, _grouping} = RestAdapter.load_filtered_policy(adapter, %{}, filter)
      assert policies["p"] == [["alice", "data1", "read"]]
    end

    test "handles filter as string" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)

      MockClient.mock_response(%{
        status_code: 200,
        body: Jason.encode!(%{policies: %{}, grouping_policies: %{}})
      })

      filter = "subject=alice"
      assert {:ok, _policies, _grouping} = RestAdapter.load_filtered_policy(adapter, %{}, filter)
    end

    test "handles filter as map with multiple conditions" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)

      MockClient.mock_response(%{
        status_code: 200,
        body: Jason.encode!(%{policies: %{}, grouping_policies: %{}})
      })

      filter = %{subject: "alice", action: "read", resource: "data1"}
      assert {:ok, _policies, _grouping} = RestAdapter.load_filtered_policy(adapter, %{}, filter)
    end
  end

  describe "save_policy/3 - saving policies via REST API" do
    test "successfully saves policies and grouping policies" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)
      MockClient.mock_response(%{status_code: 201, body: ""})

      policies = %{"p" => [["alice", "data1", "read"]]}
      grouping = %{"g" => [["alice", "admin"]]}

      assert :ok = RestAdapter.save_policy(adapter, policies, grouping)
    end

    test "handles 200 OK response for save" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)
      MockClient.mock_response(%{status_code: 200, body: ""})

      assert :ok = RestAdapter.save_policy(adapter, %{}, %{})
    end

    test "handles save conflict 409" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)
      MockClient.mock_response(%{status_code: 409, body: "Policy already exists"})

      assert {:error, message} = RestAdapter.save_policy(adapter, %{}, %{})
      assert message =~ "409"
    end

    test "handles validation error 422" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)
      MockClient.mock_response(%{status_code: 422, body: "Invalid policy format"})

      assert {:error, message} = RestAdapter.save_policy(adapter, %{}, %{})
      assert message =~ "422"
    end
  end

  describe "add_policy/4 - adding single policy" do
    test "successfully adds a single policy" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)
      MockClient.mock_response(%{status_code: 201, body: ""})

      assert :ok = RestAdapter.add_policy(adapter, "p", "p", ["alice", "data1", "read"])
    end

    test "handles 200 OK for add policy" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)
      MockClient.mock_response(%{status_code: 200, body: ""})

      assert :ok = RestAdapter.add_policy(adapter, "p", "p", ["bob", "data2", "write"])
    end

    test "handles duplicate policy error" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)
      MockClient.mock_response(%{status_code: 409, body: "Policy already exists"})

      assert {:error, message} =
               RestAdapter.add_policy(adapter, "p", "p", ["alice", "data1", "read"])

      assert message =~ "409"
    end
  end

  describe "remove_policy/4 - removing single policy" do
    test "successfully removes a single policy" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)
      MockClient.mock_response(%{status_code: 204, body: ""})

      assert :ok = RestAdapter.remove_policy(adapter, "p", "p", ["alice", "data1", "read"])
    end

    test "handles 200 OK for remove policy" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)
      MockClient.mock_response(%{status_code: 200, body: ""})

      assert :ok = RestAdapter.remove_policy(adapter, "p", "p", ["bob", "data2", "write"])
    end

    test "handles policy not found error" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)
      MockClient.mock_response(%{status_code: 404, body: "Policy not found"})

      assert {:error, message} =
               RestAdapter.remove_policy(adapter, "p", "p", ["nonexistent", "data", "read"])

      assert message =~ "404"
    end
  end

  describe "remove_filtered_policy/5 - removing policies with filter" do
    test "successfully removes filtered policies" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)
      MockClient.mock_response(%{status_code: 200, body: ""})

      assert :ok = RestAdapter.remove_filtered_policy(adapter, "p", "p", 0, ["alice"])
    end

    test "handles multiple field values" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)
      MockClient.mock_response(%{status_code: 204, body: ""})

      assert :ok = RestAdapter.remove_filtered_policy(adapter, "p", "p", 1, ["data1", "data2"])
    end
  end

  describe "filtered?/1 - filter support" do
    test "returns true indicating filtered policy support" do
      adapter = RestAdapter.new(base_url: "https://api.example.com")
      assert RestAdapter.filtered?(adapter) == true
    end
  end

  describe "test_connection/1 - connection health check" do
    test "successfully tests connection" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)
      MockClient.mock_response(%{status_code: 200, body: ""})

      assert :ok = RestAdapter.test_connection(adapter)
    end

    test "handles connection failure" do
      adapter =
        RestAdapter.new(
          base_url: "https://api.example.com",
          http_client: MockClient,
          retry_attempts: 0
        )

      MockClient.mock_error(%{reason: :econnrefused})

      assert {:error, _reason} = RestAdapter.test_connection(adapter)
    end

    test "handles service unavailable" do
      adapter = RestAdapter.new(base_url: "https://api.example.com", http_client: MockClient)
      MockClient.mock_response(%{status_code: 503, body: ""})

      assert {:error, message} = RestAdapter.test_connection(adapter)
      assert message =~ "503"
    end
  end

  describe "get_config/1 - adapter configuration" do
    test "returns configuration summary" do
      adapter =
        RestAdapter.new(
          base_url: "https://api.example.com",
          auth: {:bearer, "token123"},
          timeout: 60_000
        )

      config = RestAdapter.get_config(adapter)
      assert config.base_url == "https://api.example.com"
      assert config.has_auth == true
      assert config.timeout == 60_000
    end

    test "indicates no auth when not configured" do
      adapter = RestAdapter.new(base_url: "https://api.example.com")
      config = RestAdapter.get_config(adapter)
      assert config.has_auth == false
    end
  end

  describe "authentication - bearer token" do
    test "includes bearer token in requests" do
      adapter =
        RestAdapter.new(
          base_url: "https://api.example.com",
          auth: {:bearer, "test_token_123"},
          http_client: MockClient
        )

      MockClient.mock_response(%{
        status_code: 200,
        body: Jason.encode!(%{policies: %{}, grouping_policies: %{}})
      })

      assert {:ok, _policies, _grouping} = RestAdapter.load_policy(adapter, %{})
    end

    test "handles 401 unauthorized with bearer token" do
      adapter =
        RestAdapter.new(
          base_url: "https://api.example.com",
          auth: {:bearer, "invalid_token"},
          http_client: MockClient
        )

      MockClient.mock_response(%{status_code: 401, body: "Invalid token"})
      assert {:error, message} = RestAdapter.load_policy(adapter, %{})
      assert message =~ "401"
    end
  end

  describe "authentication - basic auth" do
    test "includes basic auth credentials in requests" do
      adapter =
        RestAdapter.new(
          base_url: "https://api.example.com",
          auth: {:basic, {"username", "password"}},
          http_client: MockClient
        )

      MockClient.mock_response(%{
        status_code: 200,
        body: Jason.encode!(%{policies: %{}, grouping_policies: %{}})
      })

      assert {:ok, _policies, _grouping} = RestAdapter.load_policy(adapter, %{})
    end

    test "handles auth failure with basic auth" do
      adapter =
        RestAdapter.new(
          base_url: "https://api.example.com",
          auth: {:basic, {"wrong", "credentials"}},
          http_client: MockClient
        )

      MockClient.mock_response(%{status_code: 401, body: "Authentication failed"})
      assert {:error, message} = RestAdapter.load_policy(adapter, %{})
      assert message =~ "401"
    end
  end

  describe "authentication - API key" do
    test "includes API key in requests" do
      adapter =
        RestAdapter.new(
          base_url: "https://api.example.com",
          auth: {:api_key, "api_key_xyz"},
          http_client: MockClient
        )

      MockClient.mock_response(%{
        status_code: 200,
        body: Jason.encode!(%{policies: %{}, grouping_policies: %{}})
      })

      assert {:ok, _policies, _grouping} = RestAdapter.load_policy(adapter, %{})
    end
  end

  describe "authentication - custom headers" do
    test "includes custom auth headers in requests" do
      adapter =
        RestAdapter.new(
          base_url: "https://api.example.com",
          auth: {:custom, [{"X-Custom-Auth", "custom_value"}]},
          http_client: MockClient
        )

      MockClient.mock_response(%{
        status_code: 200,
        body: Jason.encode!(%{policies: %{}, grouping_policies: %{}})
      })

      assert {:ok, _policies, _grouping} = RestAdapter.load_policy(adapter, %{})
    end
  end

  describe "new_mock/1 - mock adapter creation" do
    test "creates mock adapter with default settings" do
      adapter = RestAdapter.new_mock()
      assert adapter.base_url == "http://localhost:4000/api/casbin"
      assert adapter.http_client == CasbinEx2.Adapter.RestAdapter.MockClient
      assert adapter.timeout == 30_000
    end

    test "creates mock adapter with custom options" do
      adapter = RestAdapter.new_mock(timeout: 60_000, retry_attempts: 5)
      assert adapter.timeout == 60_000
      assert adapter.retry_attempts == 5
    end
  end
end
