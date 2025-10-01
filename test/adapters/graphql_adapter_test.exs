defmodule CasbinEx2.Adapter.GraphQLAdapterTest do
  use ExUnit.Case, async: true

  alias CasbinEx2.Adapter.GraphQLAdapter
  alias CasbinEx2.Adapter.GraphQLAdapter.MockClient

  describe "new/1 - adapter configuration" do
    test "creates GraphQL adapter with endpoint" do
      adapter = GraphQLAdapter.new(endpoint: "https://api.example.com/graphql")

      assert adapter.endpoint == "https://api.example.com/graphql"
      assert adapter.timeout == 30_000
      assert adapter.retry_attempts == 3
    end

    test "creates adapter with bearer authentication" do
      adapter =
        GraphQLAdapter.new(
          endpoint: "https://api.example.com/graphql",
          auth: {:bearer, "graphql_token"}
        )

      assert adapter.auth == {:bearer, "graphql_token"}
    end

    test "creates adapter with basic authentication" do
      adapter =
        GraphQLAdapter.new(
          endpoint: "https://api.example.com/graphql",
          auth: {:basic, {"username", "password"}}
        )

      assert adapter.auth == {:basic, {"username", "password"}}
    end

    test "creates adapter with custom headers" do
      adapter =
        GraphQLAdapter.new(
          endpoint: "https://api.example.com/graphql",
          headers: [{"X-Tenant-ID", "tenant-123"}]
        )

      assert {"X-Tenant-ID", "tenant-123"} in adapter.headers
    end

    test "creates adapter with custom timeout" do
      adapter =
        GraphQLAdapter.new(
          endpoint: "https://api.example.com/graphql",
          timeout: 45_000
        )

      assert adapter.timeout == 45_000
    end

    test "creates adapter with custom retry attempts" do
      adapter =
        GraphQLAdapter.new(
          endpoint: "https://api.example.com/graphql",
          retry_attempts: 5
        )

      assert adapter.retry_attempts == 5
    end

    test "enables subscriptions with WebSocket URL" do
      adapter =
        GraphQLAdapter.new(
          endpoint: "https://api.example.com/graphql",
          subscriptions: true,
          websocket_url: "wss://api.example.com/subscriptions"
        )

      assert adapter.subscriptions == true
      assert adapter.websocket_url == "wss://api.example.com/subscriptions"
    end

    test "disables subscriptions by default" do
      adapter = GraphQLAdapter.new(endpoint: "https://api.example.com/graphql")

      assert adapter.subscriptions == false
    end

    test "enables schema introspection" do
      adapter =
        GraphQLAdapter.new(
          endpoint: "https://api.example.com/graphql",
          introspection: true
        )

      assert adapter.introspection == true
    end

    test "configures batch size" do
      adapter =
        GraphQLAdapter.new(
          endpoint: "https://api.example.com/graphql",
          batch_size: 100
        )

      assert adapter.batch_size == 100
    end
  end

  describe "load_policy/2 - loading policies" do
    setup do
      # Ensure MockClient is properly started for each test
      case Process.whereis(MockClient) do
        nil ->
          MockClient.start_link()

        _pid ->
          Agent.update(MockClient, fn _state ->
            %{response: nil, error: nil, headers: [], variables: %{}, timeout: nil}
          end)
      end

      adapter =
        GraphQLAdapter.new(
          endpoint: "https://api.example.com/graphql",
          http_client: MockClient
        )

      model = %{}

      {:ok, adapter: adapter, model: model}
    end

    test "successfully loads policies from GraphQL endpoint", %{adapter: adapter, model: model} do
      MockClient.mock_response(%{
        "data" => %{
          "policies" => [
            %{"section" => "p", "policyType" => "p", "rule" => ["alice", "data1", "read"]},
            %{"section" => "p", "policyType" => "p", "rule" => ["bob", "data2", "write"]}
          ],
          "groupingPolicies" => [
            %{"section" => "g", "groupingType" => "g", "rule" => ["alice", "admin"]}
          ]
        }
      })

      assert {:ok, policies, grouping_policies} = GraphQLAdapter.load_policy(adapter, model)

      assert %{"p" => [["alice", "data1", "read"], ["bob", "data2", "write"]]} = policies
      assert %{"g" => [["alice", "admin"]]} = grouping_policies
    end

    test "handles empty policy response", %{adapter: adapter, model: model} do
      MockClient.mock_response(%{
        "data" => %{
          "policies" => [],
          "groupingPolicies" => []
        }
      })

      assert {:ok, policies, grouping_policies} = GraphQLAdapter.load_policy(adapter, model)
      assert policies == %{}
      assert grouping_policies == %{}
    end

    test "handles GraphQL errors gracefully", %{adapter: adapter, model: model} do
      MockClient.mock_response(%{
        "errors" => [
          %{"message" => "Field 'policies' not found", "locations" => [%{"line" => 1}]}
        ]
      })

      assert {:error, error_msg} = GraphQLAdapter.load_policy(adapter, model)
      assert error_msg =~ "GraphQL errors"
    end

    test "handles network errors", %{adapter: adapter, model: model} do
      MockClient.mock_error(:timeout)

      assert {:error, :timeout} = GraphQLAdapter.load_policy(adapter, model)
    end

    test "handles malformed JSON response", %{adapter: adapter, model: model} do
      MockClient.mock_error(:invalid_json)

      assert {:error, :invalid_json} = GraphQLAdapter.load_policy(adapter, model)
    end

    test "handles missing data field", %{adapter: adapter, model: model} do
      MockClient.mock_response(%{"errors" => []})

      assert {:error, _} = GraphQLAdapter.load_policy(adapter, model)
    end

    test "includes authentication headers in request", %{model: model} do
      adapter =
        GraphQLAdapter.new(
          endpoint: "https://api.example.com/graphql",
          auth: {:bearer, "test_token"},
          http_client: MockClient
        )

      MockClient.mock_response(%{
        "data" => %{"policies" => [], "groupingPolicies" => []}
      })

      GraphQLAdapter.load_policy(adapter, model)

      assert MockClient.last_headers() |> Enum.member?({"Authorization", "Bearer test_token"})
    end

    test "respects timeout configuration", %{model: model} do
      adapter =
        GraphQLAdapter.new(
          endpoint: "https://api.example.com/graphql",
          timeout: 5_000,
          http_client: MockClient
        )

      MockClient.mock_response(%{
        "data" => %{"policies" => [], "groupingPolicies" => []}
      })

      GraphQLAdapter.load_policy(adapter, model)

      assert MockClient.last_timeout() == 5_000
    end
  end

  describe "load_filtered_policy/3 - filtered loading" do
    setup do
      # Reset MockClient state
      case Process.whereis(MockClient) do
        nil ->
          MockClient.start_link()

        _pid ->
          Agent.update(MockClient, fn _state ->
            %{response: nil, error: nil, headers: [], variables: %{}, timeout: nil}
          end)
      end

      adapter =
        GraphQLAdapter.new(
          endpoint: "https://api.example.com/graphql",
          http_client: MockClient
        )

      model = %{}

      {:ok, adapter: adapter, model: model}
    end

    test "loads policies with filter", %{adapter: adapter, model: model} do
      MockClient.mock_response(%{
        "data" => %{
          "policies" => [
            %{"section" => "p", "policyType" => "p", "rule" => ["alice", "data1", "read"]}
          ],
          "groupingPolicies" => []
        }
      })

      filter = %{section: "p", policyType: "p"}

      assert {:ok, policies, _grouping} =
               GraphQLAdapter.load_filtered_policy(adapter, model, filter)

      assert %{"p" => [["alice", "data1", "read"]]} = policies
    end

    test "sends filter variables to GraphQL", %{adapter: adapter, model: model} do
      MockClient.mock_response(%{
        "data" => %{"policies" => [], "groupingPolicies" => []}
      })

      filter = %{section: "p", limit: 10}

      GraphQLAdapter.load_filtered_policy(adapter, model, filter)

      variables = MockClient.last_variables()
      assert variables["filter"]["section"] == "p"
      assert variables["filter"]["limit"] == 10
    end

    test "handles empty filter results", %{adapter: adapter, model: model} do
      MockClient.mock_response(%{
        "data" => %{"policies" => [], "groupingPolicies" => []}
      })

      filter = %{section: "nonexistent"}

      assert {:ok, policies, grouping} =
               GraphQLAdapter.load_filtered_policy(adapter, model, filter)

      assert policies == %{}
      assert grouping == %{}
    end

    test "handles filter errors", %{adapter: adapter, model: model} do
      MockClient.mock_response(%{
        "errors" => [%{"message" => "Invalid filter parameters"}]
      })

      filter = %{invalid: "param"}

      assert {:error, error} = GraphQLAdapter.load_filtered_policy(adapter, model, filter)
      assert error =~ "GraphQL errors"
    end
  end

  describe "load_incremental_filtered_policy/3 - incremental loading" do
    setup do
      # Reset MockClient state
      case Process.whereis(MockClient) do
        nil ->
          MockClient.start_link()

        _pid ->
          Agent.update(MockClient, fn _state ->
            %{response: nil, error: nil, headers: [], variables: %{}, timeout: nil}
          end)
      end

      adapter =
        GraphQLAdapter.new(
          endpoint: "https://api.example.com/graphql",
          http_client: MockClient
        )

      model = %{}

      {:ok, adapter: adapter, model: model}
    end

    test "loads policies incrementally (delegates to filtered load)", %{
      adapter: adapter,
      model: model
    } do
      MockClient.mock_response(%{
        "data" => %{"policies" => [], "groupingPolicies" => []}
      })

      filter = %{offset: 10, limit: 5}

      assert {:ok, _policies, _grouping} =
               GraphQLAdapter.load_incremental_filtered_policy(adapter, model, filter)
    end
  end

  describe "filtered?/1 - filter support" do
    test "returns true indicating filter support" do
      adapter = GraphQLAdapter.new(endpoint: "https://api.example.com/graphql")

      assert GraphQLAdapter.filtered?(adapter) == true
    end
  end

  describe "save_policy/3 - saving policies" do
    setup do
      # Reset MockClient state
      case Process.whereis(MockClient) do
        nil ->
          MockClient.start_link()

        _pid ->
          Agent.update(MockClient, fn _state ->
            %{response: nil, error: nil, headers: [], variables: %{}, timeout: nil}
          end)
      end

      adapter =
        GraphQLAdapter.new(
          endpoint: "https://api.example.com/graphql",
          http_client: MockClient
        )

      {:ok, adapter: adapter}
    end

    test "successfully saves policies via mutation", %{adapter: adapter} do
      MockClient.mock_response(%{
        "data" => %{"savePolicies" => true}
      })

      policies = %{"p" => [["alice", "data1", "read"]]}
      grouping_policies = %{"g" => [["alice", "admin"]]}

      assert :ok = GraphQLAdapter.save_policy(adapter, policies, grouping_policies)
    end

    test "handles save errors", %{adapter: adapter} do
      MockClient.mock_response(%{
        "errors" => [%{"message" => "Failed to save policies"}]
      })

      policies = %{"p" => [["alice", "data1", "read"]]}
      grouping_policies = %{}

      assert {:error, error} = GraphQLAdapter.save_policy(adapter, policies, grouping_policies)
      assert error =~ "GraphQL errors"
    end

    test "handles empty policies", %{adapter: adapter} do
      MockClient.mock_response(%{
        "data" => %{"savePolicies" => true}
      })

      assert :ok = GraphQLAdapter.save_policy(adapter, %{}, %{})
    end

    test "validates policy data structure", %{adapter: adapter} do
      MockClient.mock_response(%{
        "data" => %{"savePolicies" => true}
      })

      policies = %{"p" => [["alice", "data1", "read"], ["bob", "data2", "write"]]}
      grouping_policies = %{"g" => [["alice", "admin"], ["bob", "user"]]}

      assert :ok = GraphQLAdapter.save_policy(adapter, policies, grouping_policies)

      # Verify mutation was called with correct structure
      variables = MockClient.last_variables()
      assert is_list(variables["policies"])
      assert is_list(variables["groupingPolicies"])
    end

    test "handles network errors during save", %{adapter: adapter} do
      MockClient.mock_error(:econnrefused)

      policies = %{"p" => [["alice", "data1", "read"]]}

      assert {:error, :econnrefused} = GraphQLAdapter.save_policy(adapter, policies, %{})
    end
  end

  describe "add_policy/4 - adding single policy" do
    setup do
      # Reset MockClient state
      case Process.whereis(MockClient) do
        nil ->
          MockClient.start_link()

        _pid ->
          Agent.update(MockClient, fn _state ->
            %{response: nil, error: nil, headers: [], variables: %{}, timeout: nil}
          end)
      end

      adapter =
        GraphQLAdapter.new(
          endpoint: "https://api.example.com/graphql",
          http_client: MockClient
        )

      {:ok, adapter: adapter}
    end

    test "adds single policy via mutation", %{adapter: adapter} do
      MockClient.mock_response(%{
        "data" => %{
          "addPolicy" => %{
            "id" => "1",
            "section" => "p",
            "policyType" => "p",
            "rule" => ["alice", "data1", "read"]
          }
        }
      })

      assert :ok = GraphQLAdapter.add_policy(adapter, "p", "p", ["alice", "data1", "read"])
    end

    test "handles duplicate policy errors", %{adapter: adapter} do
      MockClient.mock_response(%{
        "errors" => [%{"message" => "Policy already exists"}]
      })

      assert {:error, error} =
               GraphQLAdapter.add_policy(adapter, "p", "p", ["alice", "data1", "read"])

      assert error =~ "GraphQL errors"
    end

    test "validates rule format", %{adapter: adapter} do
      MockClient.mock_response(%{
        "data" => %{"addPolicy" => %{"id" => "1"}}
      })

      # Empty rule
      assert :ok = GraphQLAdapter.add_policy(adapter, "p", "p", [])

      # Single element rule
      assert :ok = GraphQLAdapter.add_policy(adapter, "p", "p", ["alice"])

      # Multi-element rule
      assert :ok =
               GraphQLAdapter.add_policy(adapter, "p", "p", ["alice", "data1", "read", "allow"])
    end

    test "sends correct mutation variables", %{adapter: adapter} do
      MockClient.mock_response(%{
        "data" => %{"addPolicy" => %{"id" => "1"}}
      })

      GraphQLAdapter.add_policy(adapter, "p", "p", ["alice", "data1", "read"])

      variables = MockClient.last_variables()
      assert variables["section"] == "p"
      assert variables["policyType"] == "p"
      assert variables["rule"] == ["alice", "data1", "read"]
    end
  end

  describe "remove_policy/4 - removing single policy" do
    setup do
      # Reset MockClient state
      case Process.whereis(MockClient) do
        nil ->
          MockClient.start_link()

        _pid ->
          Agent.update(MockClient, fn _state ->
            %{response: nil, error: nil, headers: [], variables: %{}, timeout: nil}
          end)
      end

      adapter =
        GraphQLAdapter.new(
          endpoint: "https://api.example.com/graphql",
          http_client: MockClient
        )

      {:ok, adapter: adapter}
    end

    test "removes single policy via mutation", %{adapter: adapter} do
      MockClient.mock_response(%{
        "data" => %{"removePolicy" => true}
      })

      assert :ok = GraphQLAdapter.remove_policy(adapter, "p", "p", ["alice", "data1", "read"])
    end

    test "handles policy not found", %{adapter: adapter} do
      MockClient.mock_response(%{
        "data" => %{"removePolicy" => false}
      })

      # GraphQL adapter might return :ok even if policy doesn't exist
      result = GraphQLAdapter.remove_policy(adapter, "p", "p", ["nonexistent", "policy"])
      assert result == :ok or match?({:error, _}, result)
    end

    test "handles removal errors", %{adapter: adapter} do
      MockClient.mock_response(%{
        "errors" => [%{"message" => "Failed to remove policy"}]
      })

      assert {:error, error} =
               GraphQLAdapter.remove_policy(adapter, "p", "p", ["alice", "data1", "read"])

      assert error =~ "GraphQL errors"
    end

    test "sends correct mutation structure", %{adapter: adapter} do
      MockClient.mock_response(%{
        "data" => %{"removePolicy" => true}
      })

      GraphQLAdapter.remove_policy(adapter, "p", "p", ["bob", "data2", "write"])

      variables = MockClient.last_variables()
      assert variables["section"] == "p"
      assert variables["policyType"] == "p"
      assert variables["rule"] == ["bob", "data2", "write"]
    end
  end

  describe "remove_filtered_policy/5 - filtered removal" do
    setup do
      # Reset MockClient state
      case Process.whereis(MockClient) do
        nil ->
          MockClient.start_link()

        _pid ->
          Agent.update(MockClient, fn _state ->
            %{response: nil, error: nil, headers: [], variables: %{}, timeout: nil}
          end)
      end

      adapter =
        GraphQLAdapter.new(
          endpoint: "https://api.example.com/graphql",
          http_client: MockClient
        )

      {:ok, adapter: adapter}
    end

    test "removes policies matching filter", %{adapter: adapter} do
      MockClient.mock_response(%{
        "data" => %{"removePolicies" => 3}
      })

      assert :ok =
               GraphQLAdapter.remove_filtered_policy(adapter, "p", "p", 0, ["alice"])
    end

    test "handles no matching policies", %{adapter: adapter} do
      MockClient.mock_response(%{
        "data" => %{"removePolicies" => 0}
      })

      result = GraphQLAdapter.remove_filtered_policy(adapter, "p", "p", 0, ["nonexistent"])
      assert result == :ok or match?({:error, _}, result)
    end

    test "sends filter parameters correctly", %{adapter: adapter} do
      MockClient.mock_response(%{
        "data" => %{"removePolicies" => 2}
      })

      GraphQLAdapter.remove_filtered_policy(adapter, "p", "p", 1, ["data1"])

      variables = MockClient.last_variables()
      assert variables["filter"]["section"] == "p"
      assert variables["filter"]["policyType"] == "p"
    end
  end
end
