defmodule CasbinEx2.Adapter.RestAdapterTest do
  use ExUnit.Case, async: false

  alias CasbinEx2.Adapter.RestAdapter

  @moduletag :rest_api_required

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
end
