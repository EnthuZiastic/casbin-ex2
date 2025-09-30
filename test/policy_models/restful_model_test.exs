defmodule CasbinEx2.Model.RestfulModelTest do
  use ExUnit.Case
  doctest CasbinEx2.Model.RestfulModel

  alias CasbinEx2.Model.RestfulModel

  setup do
    model = RestfulModel.new()
    {:ok, model: model}
  end

  describe "new/0" do
    test "creates a new RESTful model with default values" do
      model = RestfulModel.new()

      assert model.routes == %{}
      assert model.path_patterns == %{}
      assert map_size(model.method_hierarchy) > 0
      assert model.parameter_extractors == %{}
      assert model.route_cache == %{}
      assert model.enabled == true
    end
  end

  describe "add_route/4" do
    test "adds a simple route pattern", %{model: model} do
      {:ok, updated_model} = RestfulModel.add_route(model, "alice", :get, "/api/users")

      route_key = "alice:get"
      routes = Map.get(updated_model.routes, route_key, [])

      assert length(routes) == 1
      route = List.first(routes)
      assert route.method == :get
      assert route.path == "/api/users"
      assert route.parameters == []
      assert route.wildcards == false
    end

    test "adds a route with parameters", %{model: model} do
      {:ok, updated_model} = RestfulModel.add_route(model, "alice", :get, "/api/users/:id")

      route_key = "alice:get"
      routes = Map.get(updated_model.routes, route_key, [])

      route = List.first(routes)
      assert route.parameters == ["id"]
    end

    test "adds a route with wildcards", %{model: model} do
      {:ok, updated_model} = RestfulModel.add_route(model, "admin", :get, "/api/admin/*")

      route_key = "admin:get"
      routes = Map.get(updated_model.routes, route_key, [])

      route = List.first(routes)
      assert route.wildcards == true
    end

    test "compiles path patterns", %{model: model} do
      {:ok, updated_model} = RestfulModel.add_route(model, "alice", :get, "/api/users/:id")

      assert Map.has_key?(updated_model.path_patterns, "/api/users/:id")
      regex = Map.get(updated_model.path_patterns, "/api/users/:id")
      assert is_struct(regex, Regex)
    end

    test "returns error when route already exists", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users")
      {:error, :route_exists} = RestfulModel.add_route(model, "alice", :get, "/api/users")
    end

    test "clears cache when adding routes", %{model: model} do
      model_with_cache = %{model | route_cache: %{"alice:get:/api/users" => true}}
      {:ok, updated_model} = RestfulModel.add_route(model_with_cache, "alice", :get, "/api/users")

      assert updated_model.route_cache == %{}
    end
  end

  describe "remove_route/4" do
    test "removes an existing route", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users")
      {:ok, updated_model} = RestfulModel.remove_route(model, "alice", :get, "/api/users")

      route_key = "alice:get"
      routes = Map.get(updated_model.routes, route_key, [])
      assert routes == []
    end

    test "returns error when route not found", %{model: model} do
      {:error, :route_not_found} = RestfulModel.remove_route(model, "alice", :get, "/api/users")
    end

    test "clears cache when removing routes", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users")
      model_with_cache = %{model | route_cache: %{"alice:get:/api/users" => true}}

      {:ok, updated_model} =
        RestfulModel.remove_route(model_with_cache, "alice", :get, "/api/users")

      assert updated_model.route_cache == %{}
    end
  end

  describe "can_access?/4" do
    test "returns true when model is disabled", %{model: model} do
      disabled_model = %{model | enabled: false}

      result = RestfulModel.can_access?(disabled_model, "alice", :get, "/api/users")
      assert result == true
    end

    test "returns true for exact path match", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users")

      assert RestfulModel.can_access?(model, "alice", :get, "/api/users") == true
    end

    test "returns false for non-matching path", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users")

      assert RestfulModel.can_access?(model, "alice", :get, "/api/posts") == false
    end

    test "matches parameterized paths", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users/:id")

      assert RestfulModel.can_access?(model, "alice", :get, "/api/users/123") == true
      assert RestfulModel.can_access?(model, "alice", :get, "/api/users/456") == true
    end

    test "matches wildcard paths", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "admin", :get, "/api/admin/*")

      assert RestfulModel.can_access?(model, "admin", :get, "/api/admin/settings") == true
      assert RestfulModel.can_access?(model, "admin", :get, "/api/admin/users/123") == true
    end

    test "respects method hierarchy", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users")

      # GET should include HEAD and OPTIONS
      assert RestfulModel.can_access?(model, "alice", :head, "/api/users") == true
      assert RestfulModel.can_access?(model, "alice", :options, "/api/users") == true
    end

    test "returns false for wrong method", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users")

      assert RestfulModel.can_access?(model, "alice", :post, "/api/users") == false
    end

    test "returns false for wrong subject", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users")

      assert RestfulModel.can_access?(model, "bob", :get, "/api/users") == false
    end
  end

  describe "evaluate_policy/3" do
    test "returns true when model is disabled", %{model: model} do
      disabled_model = %{model | enabled: false}

      result =
        RestfulModel.evaluate_policy(disabled_model, ["alice", "GET", "/api/users"], "true")

      assert result == true
    end

    test "evaluates route access and policy", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users")

      result =
        RestfulModel.evaluate_policy(model, ["alice", "GET", "/api/users"], "r.sub == 'alice'")

      assert result == true
    end

    test "returns false when route access fails", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users")

      result = RestfulModel.evaluate_policy(model, ["bob", "GET", "/api/users"], "r.sub == 'bob'")
      assert result == false
    end

    test "returns false when policy fails", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users")

      result =
        RestfulModel.evaluate_policy(model, ["alice", "GET", "/api/users"], "r.sub == 'bob'")

      assert result == false
    end

    test "returns false for invalid HTTP method", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users")

      result = RestfulModel.evaluate_policy(model, ["alice", "INVALID", "/api/users"], "true")
      assert result == false
    end

    test "evaluates complex policy expressions", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users")

      result =
        RestfulModel.evaluate_policy(
          model,
          ["alice", "GET", "/api/users"],
          "r.sub == 'alice' && r.act == 'get'"
        )

      assert result == true
    end
  end

  describe "get_routes_for_subject/2" do
    test "returns all routes for a subject", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users")
      {:ok, model} = RestfulModel.add_route(model, "alice", :post, "/api/posts")
      {:ok, model} = RestfulModel.add_route(model, "bob", :get, "/api/files")

      routes = RestfulModel.get_routes_for_subject(model, "alice")

      assert {:get, "/api/users"} in routes
      assert {:post, "/api/posts"} in routes
      refute {:get, "/api/files"} in routes
    end

    test "returns empty list for subject with no routes", %{model: model} do
      routes = RestfulModel.get_routes_for_subject(model, "nonexistent")
      assert routes == []
    end
  end

  describe "extract_path_parameters/3" do
    test "extracts parameters from matching path", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users/:id")

      params = RestfulModel.extract_path_parameters(model, "/api/users/:id", "/api/users/123")

      assert params == %{"id" => "123"}
    end

    test "extracts multiple parameters", %{model: model} do
      {:ok, model} =
        RestfulModel.add_route(model, "alice", :get, "/api/users/:userId/posts/:postId")

      params =
        RestfulModel.extract_path_parameters(
          model,
          "/api/users/:userId/posts/:postId",
          "/api/users/123/posts/456"
        )

      assert params == %{"userId" => "123", "postId" => "456"}
    end

    test "returns empty map for non-matching path", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users/:id")

      params = RestfulModel.extract_path_parameters(model, "/api/users/:id", "/api/posts/123")

      assert params == %{}
    end

    test "returns empty map for unknown pattern", %{model: model} do
      params = RestfulModel.extract_path_parameters(model, "/unknown/pattern", "/some/path")

      assert params == %{}
    end
  end

  describe "complex scenarios" do
    test "handles multiple routes for same subject and method", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users")
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/posts")

      assert RestfulModel.can_access?(model, "alice", :get, "/api/users") == true
      assert RestfulModel.can_access?(model, "alice", :get, "/api/posts") == true
      assert RestfulModel.can_access?(model, "alice", :get, "/api/files") == false
    end

    test "supports complex path patterns", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/v1/users/:id/profile")
      {:ok, model} = RestfulModel.add_route(model, "admin", :get, "/api/*/admin/*")

      assert RestfulModel.can_access?(model, "alice", :get, "/api/v1/users/123/profile") == true
      assert RestfulModel.can_access?(model, "admin", :get, "/api/v1/admin/settings") == true
      assert RestfulModel.can_access?(model, "admin", :get, "/api/v2/admin/users") == true
    end

    test "handles various HTTP methods", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users")
      {:ok, model} = RestfulModel.add_route(model, "alice", :post, "/api/users")
      {:ok, model} = RestfulModel.add_route(model, "alice", :put, "/api/users/:id")
      {:ok, model} = RestfulModel.add_route(model, "alice", :delete, "/api/users/:id")

      assert RestfulModel.can_access?(model, "alice", :get, "/api/users") == true
      assert RestfulModel.can_access?(model, "alice", :post, "/api/users") == true
      assert RestfulModel.can_access?(model, "alice", :put, "/api/users/123") == true
      assert RestfulModel.can_access?(model, "alice", :delete, "/api/users/123") == true
    end

    test "evaluates complex RESTful policies", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users/:id")

      # Policy that checks user can only access their own profile
      policy = "r.sub == 'alice' && r.obj == '/api/users/alice'"
      result = RestfulModel.evaluate_policy(model, ["alice", "GET", "/api/users/alice"], policy)
      assert result == true

      result = RestfulModel.evaluate_policy(model, ["alice", "GET", "/api/users/bob"], policy)
      assert result == false
    end

    test "parameter extraction with complex patterns", %{model: model} do
      {:ok, model} =
        RestfulModel.add_route(
          model,
          "alice",
          :get,
          "/api/v:version/users/:userId/posts/:postId/comments/:commentId"
        )

      params =
        RestfulModel.extract_path_parameters(
          model,
          "/api/v:version/users/:userId/posts/:postId/comments/:commentId",
          "/api/v1/users/123/posts/456/comments/789"
        )

      expected = %{
        "version" => "1",
        "userId" => "123",
        "postId" => "456",
        "commentId" => "789"
      }

      assert params == expected
    end

    test "method hierarchy works correctly", %{model: model} do
      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users")

      # GET should allow HEAD and OPTIONS
      assert RestfulModel.can_access?(model, "alice", :get, "/api/users") == true
      assert RestfulModel.can_access?(model, "alice", :head, "/api/users") == true
      assert RestfulModel.can_access?(model, "alice", :options, "/api/users") == true

      # But not other methods
      assert RestfulModel.can_access?(model, "alice", :post, "/api/users") == false
      assert RestfulModel.can_access?(model, "alice", :put, "/api/users") == false
      assert RestfulModel.can_access?(model, "alice", :delete, "/api/users") == false
    end
  end
end
