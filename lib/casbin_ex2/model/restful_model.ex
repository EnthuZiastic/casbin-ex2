defmodule CasbinEx2.Model.RestfulModel do
  @moduledoc """
  RESTful Model for HTTP method and path pattern support.

  Provides RESTful access control for HTTP-based applications with support for
  HTTP methods, path patterns, wildcards, parameter extraction, and RESTful
  resource hierarchies.
  """

  defstruct [
    :routes,
    :path_patterns,
    :method_hierarchy,
    :parameter_extractors,
    :route_cache,
    :enabled
  ]

  @type http_method :: :get | :post | :put | :patch | :delete | :head | :options
  @type route_pattern :: %{
          method: http_method(),
          path: String.t(),
          parameters: [String.t()],
          wildcards: boolean()
        }

  @type t :: %__MODULE__{
          routes: %{String.t() => [route_pattern()]},
          path_patterns: %{String.t() => Regex.t()},
          method_hierarchy: %{http_method() => [http_method()]},
          parameter_extractors: %{String.t() => function()},
          route_cache: %{String.t() => boolean()},
          enabled: boolean()
        }

  @doc """
  Creates a new RESTful model.

  ## Examples

      restful_model = RestfulModel.new()

  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      routes: %{},
      path_patterns: %{},
      method_hierarchy: default_method_hierarchy(),
      parameter_extractors: %{},
      route_cache: %{},
      enabled: true
    }
  end

  @doc """
  Adds a RESTful route pattern.

  ## Examples

      {:ok, model} = RestfulModel.add_route(model, "alice", :get, "/api/users/:id")
      {:ok, model} = RestfulModel.add_route(model, "admin", :post, "/api/admin/*")

  """
  @spec add_route(t(), String.t(), http_method(), String.t()) :: {:ok, t()} | {:error, term()}
  def add_route(%__MODULE__{} = model, subject, method, path_pattern) do
    route_key = "#{subject}:#{method}"

    route = %{
      method: method,
      path: path_pattern,
      parameters: extract_parameters(path_pattern),
      wildcards: String.contains?(path_pattern, "*")
    }

    current_routes = Map.get(model.routes, route_key, [])

    if route in current_routes do
      {:error, :route_exists}
    else
      new_routes = [route | current_routes]
      compiled_pattern = compile_path_pattern(path_pattern)

      updated_model = %{
        model
        | routes: Map.put(model.routes, route_key, new_routes),
          path_patterns: Map.put(model.path_patterns, path_pattern, compiled_pattern),
          # Clear cache when routes change
          route_cache: %{}
      }

      {:ok, updated_model}
    end
  end

  @doc """
  Removes a RESTful route pattern.

  ## Examples

      {:ok, model} = RestfulModel.remove_route(model, "alice", :get, "/api/users/:id")

  """
  @spec remove_route(t(), String.t(), http_method(), String.t()) :: {:ok, t()} | {:error, term()}
  def remove_route(%__MODULE__{} = model, subject, method, path_pattern) do
    route_key = "#{subject}:#{method}"
    current_routes = Map.get(model.routes, route_key, [])

    route_to_remove = %{
      method: method,
      path: path_pattern,
      parameters: extract_parameters(path_pattern),
      wildcards: String.contains?(path_pattern, "*")
    }

    if route_to_remove in current_routes do
      new_routes = List.delete(current_routes, route_to_remove)

      updated_model = %{
        model
        | routes: Map.put(model.routes, route_key, new_routes),
          # Clear cache when routes change
          route_cache: %{}
      }

      {:ok, updated_model}
    else
      {:error, :route_not_found}
    end
  end

  @doc """
  Checks if a subject can access a RESTful resource.

  ## Examples

      RestfulModel.can_access?(model, "alice", :get, "/api/users/123")
      RestfulModel.can_access?(model, "admin", :post, "/api/admin/settings")

  """
  @spec can_access?(t(), String.t(), http_method(), String.t()) :: boolean()
  def can_access?(%__MODULE__{enabled: false}, _subject, _method, _path), do: true

  def can_access?(%__MODULE__{} = model, subject, method, path) do
    cache_key = "#{subject}:#{method}:#{path}"

    case Map.get(model.route_cache, cache_key) do
      nil ->
        result = check_route_access(model, subject, method, path)
        # Note: In a real implementation, you'd want to update the model's cache
        result

      cached_result ->
        cached_result
    end
  end

  @doc """
  Evaluates a RESTful policy against a request.

  ## Examples

      RestfulModel.evaluate_policy(model, ["alice", "GET", "/api/users/123"], "r.sub == 'alice' && r.act == 'GET'")

  """
  @spec evaluate_policy(t(), [String.t()], String.t()) :: boolean()
  def evaluate_policy(%__MODULE__{enabled: false}, _request, _policy), do: true

  def evaluate_policy(%__MODULE__{} = model, [subject, method_str, path], policy) do
    method = method_from_string(method_str)

    case method do
      {:ok, http_method} ->
        # Check route access
        route_access = can_access?(model, subject, http_method, path)

        # Evaluate additional policy conditions
        policy_result = evaluate_restful_policy_expression(subject, http_method, path, policy)

        route_access && policy_result

      {:error, _reason} ->
        false
    end
  end

  @doc """
  Gets all routes for a subject.

  ## Examples

      routes = RestfulModel.get_routes_for_subject(model, "alice")

  """
  @spec get_routes_for_subject(t(), String.t()) :: [{http_method(), String.t()}]
  def get_routes_for_subject(%__MODULE__{routes: routes}, subject) do
    routes
    |> Enum.filter(fn {route_key, _patterns} ->
      String.starts_with?(route_key, "#{subject}:")
    end)
    |> Enum.flat_map(fn {_route_key, patterns} ->
      Enum.map(patterns, fn pattern -> {pattern.method, pattern.path} end)
    end)
  end

  @doc """
  Extracts parameters from a path against a pattern.

  ## Examples

      params = RestfulModel.extract_path_parameters(model, "/api/users/:id", "/api/users/123")
      # Returns: %{"id" => "123"}

  """
  @spec extract_path_parameters(t(), String.t(), String.t()) :: %{String.t() => String.t()}
  def extract_path_parameters(%__MODULE__{} = model, pattern, actual_path) do
    case Map.get(model.path_patterns, pattern) do
      nil ->
        %{}

      regex ->
        case Regex.named_captures(regex, actual_path) do
          nil -> %{}
          captures -> captures
        end
    end
  end

  # Private functions

  defp default_method_hierarchy do
    %{
      get: [:get, :head, :options],
      post: [:post],
      put: [:put, :patch],
      patch: [:patch],
      delete: [:delete],
      head: [:head],
      options: [:options]
    }
  end

  defp extract_parameters(path_pattern) do
    ~r/:([a-zA-Z_][a-zA-Z0-9_]*)/
    |> Regex.scan(path_pattern, capture: :all_but_first)
    |> List.flatten()
  end

  defp compile_path_pattern(path_pattern) do
    # Convert path pattern to regex
    # /api/users/:id -> ^/api/users/(?<id>[^/]+)$
    # /api/admin/* -> ^/api/admin/.*$

    # Replace parameter patterns first
    parameter_pattern =
      Regex.replace(~r/:([a-zA-Z_][a-zA-Z0-9_]*)/, path_pattern, "(?<\\1>[^/]+)")

    # Replace wildcard patterns
    wildcard_pattern = String.replace(parameter_pattern, "*", ".*")

    # Anchor the pattern
    anchored_pattern = "^#{wildcard_pattern}$"

    {:ok, regex} = Regex.compile(anchored_pattern)
    regex
  end

  defp check_route_access(%__MODULE__{} = model, subject, method, path) do
    check_direct_route_match(model, subject, method, path) ||
      check_hierarchy_route_match(model, subject, method, path)
  end

  defp check_direct_route_match(model, subject, method, path) do
    route_key = "#{subject}:#{method}"
    routes = Map.get(model.routes, route_key, [])

    Enum.any?(routes, fn route ->
      matches_path_pattern?(model, route.path, path)
    end)
  end

  defp check_hierarchy_route_match(model, subject, method, path) do
    applicable_route_methods = find_applicable_route_methods(model, method)

    Enum.any?(applicable_route_methods, fn route_method ->
      check_alternative_route_match(model, subject, route_method, path)
    end)
  end

  defp find_applicable_route_methods(model, method) do
    Enum.filter(Map.keys(model.method_hierarchy), fn route_method ->
      method_alternatives = Map.get(model.method_hierarchy, route_method, [])
      method in method_alternatives
    end)
  end

  defp check_alternative_route_match(model, subject, route_method, path) do
    route_key = "#{subject}:#{route_method}"
    alt_routes = Map.get(model.routes, route_key, [])

    Enum.any?(alt_routes, fn route ->
      matches_path_pattern?(model, route.path, path)
    end)
  end

  defp matches_path_pattern?(%__MODULE__{} = model, pattern, path) do
    case Map.get(model.path_patterns, pattern) do
      nil -> false
      regex -> Regex.match?(regex, path)
    end
  end

  defp method_from_string(method_str) do
    case String.downcase(method_str) do
      "get" -> {:ok, :get}
      "post" -> {:ok, :post}
      "put" -> {:ok, :put}
      "patch" -> {:ok, :patch}
      "delete" -> {:ok, :delete}
      "head" -> {:ok, :head}
      "options" -> {:ok, :options}
      _ -> {:error, :invalid_method}
    end
  end

  defp evaluate_restful_policy_expression(subject, method, path, policy) do
    # Simple policy expression evaluator for RESTful policies
    # Replace placeholders with actual values
    evaluated_policy =
      policy
      |> String.replace("r.sub", "'#{subject}'")
      |> String.replace("r.act", "'#{method}'")
      |> String.replace("r.obj", "'#{path}'")

    # Basic evaluation - in a real implementation, you'd use a proper expression evaluator
    case evaluated_policy do
      policy when policy in ["true", "'true'"] ->
        true

      policy when policy in ["false", "'false'"] ->
        false

      _ ->
        # For complex expressions, use a simple pattern matcher
        evaluate_simple_expression(evaluated_policy)
    end
  end

  defp evaluate_simple_expression(expression) do
    # Very basic expression evaluation - extend as needed
    cond do
      String.contains?(expression, " && ") ->
        expression
        |> String.split(" && ")
        |> Enum.all?(&evaluate_simple_condition/1)

      String.contains?(expression, " || ") ->
        expression
        |> String.split(" || ")
        |> Enum.any?(&evaluate_simple_condition/1)

      true ->
        evaluate_simple_condition(expression)
    end
  end

  defp evaluate_simple_condition(condition) do
    # Basic condition evaluation
    cond do
      String.contains?(condition, " == ") ->
        [left, right] = String.split(condition, " == ", parts: 2)
        String.trim(left) == String.trim(right)

      String.contains?(condition, " != ") ->
        [left, right] = String.split(condition, " != ", parts: 2)
        String.trim(left) != String.trim(right)

      true ->
        false
    end
  end
end
