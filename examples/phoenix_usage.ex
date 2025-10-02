defmodule CasbinEx2.Examples.PhoenixUsage do
  @moduledoc """
  Phoenix integration examples for CasbinEx2.

  This module demonstrates how to integrate CasbinEx2 into Phoenix applications
  for authorization control across controllers, plugs, and LiveView.

  ## Setup in Application Supervisor

      children = [
        # Start enforcer on application boot
        {CasbinEx2.EnforceServer,
         [
           name: :phoenix_enforcer,
           model_path: "priv/casbin/rbac_model.conf",
           adapter: CasbinEx2.Adapter.EctoAdapter.new(repo: MyApp.Repo)
         ]}
      ]

  """

  # ============================================================================
  # Example 1: Phoenix Plug for Authorization
  # ============================================================================

  defmodule AuthorizationPlug do
    @moduledoc """
    Plug for checking authorization before controller actions.

    ## Usage in Router

        pipeline :authorized do
          plug AuthorizationPlug, enforcer: :phoenix_enforcer
        end

        scope "/admin", MyAppWeb do
          pipe_through [:browser, :authorized]
          resources "/users", UserController
        end

    """
    import Plug.Conn
    import Phoenix.Controller

    def init(opts), do: opts

    def call(conn, opts) do
      enforcer = Keyword.get(opts, :enforcer, :phoenix_enforcer)
      user = get_session(conn, :current_user)
      resource = conn.request_path
      action = http_method_to_action(conn.method)

      case CasbinEx2.enforce(enforcer, [user, resource, action]) do
        true ->
          conn

        false ->
          conn
          |> put_flash(:error, "Unauthorized access")
          |> redirect(to: "/unauthorized")
          |> halt()
      end
    end

    defp http_method_to_action("GET"), do: "read"
    defp http_method_to_action("POST"), do: "write"
    defp http_method_to_action("PUT"), do: "write"
    defp http_method_to_action("PATCH"), do: "write"
    defp http_method_to_action("DELETE"), do: "delete"
    defp http_method_to_action(_), do: "unknown"
  end

  # ============================================================================
  # Example 2: Controller-Level Authorization
  # ============================================================================

  defmodule MyAppWeb.UserController do
    @moduledoc """
    Example controller with action-level authorization.

    Uses CasbinEx2 for fine-grained authorization control in each action.
    """
    use MyAppWeb, :controller

    def index(conn, _params) do
      user = get_session(conn, :current_user)

      if authorized?(user, "users", "read") do
        users = MyApp.Accounts.list_users()
        render(conn, "index.html", users: users)
      else
        unauthorized(conn)
      end
    end

    def create(conn, %{"user" => user_params}) do
      user = get_session(conn, :current_user)

      if authorized?(user, "users", "write") do
        case MyApp.Accounts.create_user(user_params) do
          {:ok, user} ->
            conn
            |> put_flash(:info, "User created successfully")
            |> redirect(to: ~p"/users/#{user}")

          {:error, changeset} ->
            render(conn, "new.html", changeset: changeset)
        end
      else
        unauthorized(conn)
      end
    end

    def delete(conn, %{"id" => id}) do
      user = get_session(conn, :current_user)

      if authorized?(user, "users", "delete") do
        user_to_delete = MyApp.Accounts.get_user!(id)
        {:ok, _user} = MyApp.Accounts.delete_user(user_to_delete)

        conn
        |> put_flash(:info, "User deleted successfully")
        |> redirect(to: ~p"/users")
      else
        unauthorized(conn)
      end
    end

    defp authorized?(user, resource, action) do
      CasbinEx2.enforce(:phoenix_enforcer, [user, resource, action])
    end

    defp unauthorized(conn) do
      conn
      |> put_status(:forbidden)
      |> put_flash(:error, "You don't have permission for this action")
      |> redirect(to: ~p"/")
      |> halt()
    end
  end

  # ============================================================================
  # Example 3: LiveView Authorization
  # ============================================================================

  defmodule MyAppWeb.AdminLive do
    @moduledoc """
    Example LiveView with authorization checks.

    Demonstrates authorization for initial mount and for individual events.
    """
    use MyAppWeb, :live_view

    def mount(_params, %{"current_user" => user} = _session, socket) do
      if authorized?(user, "admin_panel", "read") do
        {:ok, assign(socket, current_user: user, users: load_users())}
      else
        {:ok,
         socket
         |> put_flash(:error, "Unauthorized")
         |> redirect(to: ~p"/")}
      end
    end

    def handle_event("delete_user", %{"id" => id}, socket) do
      user = socket.assigns.current_user

      if authorized?(user, "users", "delete") do
        MyApp.Accounts.delete_user(id)

        {:noreply,
         socket
         |> put_flash(:info, "User deleted")
         |> assign(users: load_users())}
      else
        {:noreply,
         socket
         |> put_flash(:error, "Not authorized to delete users")}
      end
    end

    def handle_event("promote_to_admin", %{"id" => id}, socket) do
      user = socket.assigns.current_user

      # Only super_admins can promote to admin
      if CasbinEx2.has_role_for_user(:phoenix_enforcer, user, "super_admin") do
        CasbinEx2.add_role_for_user(:phoenix_enforcer, id, "admin")

        {:noreply,
         socket
         |> put_flash(:info, "User promoted to admin")
         |> assign(users: load_users())}
      else
        {:noreply,
         socket
         |> put_flash(:error, "Only super admins can promote to admin")}
      end
    end

    defp authorized?(user, resource, action) do
      CasbinEx2.enforce(:phoenix_enforcer, [user, resource, action])
    end

    defp load_users do
      # Implementation details...
      []
    end
  end

  # ============================================================================
  # Example 4: Helper Module for Authorization
  # ============================================================================

  defmodule MyApp.Authorization do
    @moduledoc """
    Centralized authorization helper module.

    Provides convenient functions for common authorization patterns.
    """

    @enforcer :phoenix_enforcer

    @doc "Check if user is authorized for action"
    def can?(user, resource, action) do
      CasbinEx2.enforce(@enforcer, [user, resource, action])
    end

    @doc "Check if user has specific role"
    def has_role?(user, role) do
      CasbinEx2.has_role_for_user(@enforcer, user, role)
    end

    @doc "Check if user is admin"
    def admin?(user) do
      has_role?(user, "admin") or has_role?(user, "super_admin")
    end

    @doc "Get all permissions for user (including through roles)"
    def permissions_for(user) do
      CasbinEx2.get_implicit_permissions_for_user(@enforcer, user)
    end

    @doc "Grant role to user"
    def grant_role(user, role) do
      CasbinEx2.add_role_for_user(@enforcer, user, role)
    end

    @doc "Revoke role from user"
    def revoke_role(user, role) do
      CasbinEx2.delete_role_for_user(@enforcer, user, role)
    end

    @doc "Add custom permission for user"
    def grant_permission(user, resource, action) do
      CasbinEx2.add_policy(@enforcer, [user, resource, action])
    end

    @doc "Remove permission from user"
    def revoke_permission(user, resource, action) do
      CasbinEx2.remove_policy(@enforcer, [user, resource, action])
    end
  end

  # ============================================================================
  # Example 5: View Helpers for Template Authorization
  # ============================================================================

  defmodule MyAppWeb.AuthorizationHelpers do
    @moduledoc """
    View helpers for conditional rendering based on authorization.

    ## Usage in Templates

        <%= if can?(@current_user, "users", "delete") do %>
          <button phx-click="delete_user">Delete</button>
        <% end %>

    """

    def can?(user, resource, action) do
      MyApp.Authorization.can?(user, resource, action)
    end

    def admin?(user) do
      MyApp.Authorization.admin?(user)
    end

    def has_role?(user, role) do
      MyApp.Authorization.has_role?(user, role)
    end
  end

  # ============================================================================
  # Example 6: Multi-Tenant Authorization
  # ============================================================================

  defmodule MyApp.TenantAuthorization do
    @moduledoc """
    Multi-tenant authorization with domain support.

    Each tenant (organization) has isolated roles and permissions.
    """

    @enforcer :phoenix_enforcer

    @doc "Check if user is authorized within tenant context"
    def can?(user, tenant_id, resource, action) do
      # Use domain-based enforcement
      roles = CasbinEx2.get_roles_for_user_in_domain(@enforcer, user, tenant_id)

      Enum.any?(roles, fn role ->
        CasbinEx2.enforce(@enforcer, [role, tenant_id, resource, action])
      end)
    end

    @doc "Grant tenant-specific role to user"
    def grant_tenant_role(user, role, tenant_id) do
      CasbinEx2.add_role_for_user_in_domain(@enforcer, user, role, tenant_id)
    end

    @doc "Get user's roles in specific tenant"
    def tenant_roles(user, tenant_id) do
      CasbinEx2.get_roles_for_user_in_domain(@enforcer, user, tenant_id)
    end
  end

  # ============================================================================
  # Example 7: API Authorization for JSON APIs
  # ============================================================================

  defmodule MyAppWeb.API.AuthorizationPlug do
    @moduledoc """
    API authorization plug for JSON endpoints.

    Returns 403 Forbidden with JSON error for unauthorized requests.
    """
    import Plug.Conn

    def init(opts), do: opts

    def call(conn, opts) do
      enforcer = Keyword.get(opts, :enforcer, :phoenix_enforcer)

      # Extract user from token/session
      user = get_req_header(conn, "x-user-id") |> List.first()
      resource = conn.path_info |> Enum.join("/")
      action = http_method_to_action(conn.method)

      case CasbinEx2.enforce(enforcer, [user, resource, action]) do
        true ->
          conn

        false ->
          conn
          |> put_status(:forbidden)
          |> Phoenix.Controller.json(%{error: "Unauthorized", code: 403})
          |> halt()
      end
    end

    defp http_method_to_action("GET"), do: "read"
    defp http_method_to_action("POST"), do: "create"
    defp http_method_to_action("PUT"), do: "update"
    defp http_method_to_action("PATCH"), do: "update"
    defp http_method_to_action("DELETE"), do: "delete"
    defp http_method_to_action(_), do: "unknown"
  end

  # ============================================================================
  # Example 8: Absinthe GraphQL Authorization
  # ============================================================================

  defmodule MyAppWeb.Schema.Middleware.Authorize do
    @moduledoc """
    Absinthe middleware for GraphQL authorization.

    ## Usage in Schema

        field :users, list_of(:user) do
          middleware Authorize, resource: "users", action: "read"
          resolve &Resolvers.Users.list_users/3
        end

    """
    @behaviour Absinthe.Middleware

    def call(resolution, opts) do
      resource = Keyword.get(opts, :resource)
      action = Keyword.get(opts, :action)
      user = resolution.context[:current_user]

      if authorized?(user, resource, action) do
        resolution
      else
        Absinthe.Resolution.put_result(resolution, {:error, "Unauthorized"})
      end
    end

    defp authorized?(user, resource, action) do
      CasbinEx2.enforce(:phoenix_enforcer, [user, resource, action])
    end
  end
end
