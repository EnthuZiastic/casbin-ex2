defmodule CasbinEx2.Model.MultiTenancyModelTest do
  use ExUnit.Case
  doctest CasbinEx2.Model.MultiTenancyModel

  alias CasbinEx2.Model.MultiTenancyModel

  setup do
    model = MultiTenancyModel.new()
    {:ok, model: model}
  end

  describe "new/1" do
    test "creates a new Multi-Tenancy model with default values" do
      model = MultiTenancyModel.new()

      assert model.tenants == %{}
      assert model.tenant_hierarchy == %{}
      assert model.tenant_policies == %{}
      assert model.tenant_users == %{}
      assert model.cross_tenant_permissions == []
      assert model.isolation_level == :moderate
      assert model.enabled == true
    end

    test "creates a model with custom isolation level" do
      model = MultiTenancyModel.new(isolation_level: :strict)

      assert model.isolation_level == :strict
    end
  end

  describe "add_tenant/2" do
    test "adds a root tenant", %{model: model} do
      tenant = %{
        id: "tenant1",
        name: "Acme Corp",
        parent_id: nil,
        level: 0,
        metadata: %{"industry" => "tech"},
        active: true
      }

      {:ok, updated_model} = MultiTenancyModel.add_tenant(model, tenant)

      assert Map.get(updated_model.tenants, "tenant1") == tenant
      assert Map.get(updated_model.tenant_policies, "tenant1") == %{}
      assert Map.get(updated_model.tenant_users, "tenant1") == %{}
    end

    test "adds a child tenant and updates hierarchy", %{model: model} do
      parent_tenant = %{
        id: "parent",
        name: "Parent Corp",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      child_tenant = %{
        id: "child",
        name: "Child Corp",
        parent_id: "parent",
        level: 1,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, parent_tenant)
      {:ok, updated_model} = MultiTenancyModel.add_tenant(model, child_tenant)

      assert Map.get(updated_model.tenants, "child") == child_tenant
      parent_children = Map.get(updated_model.tenant_hierarchy, "parent", [])
      assert "child" in parent_children
    end

    test "returns error when tenant already exists", %{model: model} do
      tenant = %{
        id: "tenant1",
        name: "Acme Corp",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant)
      {:error, :tenant_exists} = MultiTenancyModel.add_tenant(model, tenant)
    end
  end

  describe "remove_tenant/2" do
    test "removes a tenant with no children", %{model: model} do
      tenant = %{
        id: "tenant1",
        name: "Acme Corp",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant)
      {:ok, updated_model} = MultiTenancyModel.remove_tenant(model, "tenant1")

      assert Map.get(updated_model.tenants, "tenant1") == nil
      assert Map.get(updated_model.tenant_policies, "tenant1") == nil
      assert Map.get(updated_model.tenant_users, "tenant1") == nil
    end

    test "removes tenant from parent's children list", %{model: model} do
      parent = %{
        id: "parent",
        name: "Parent Corp",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      child = %{
        id: "child",
        name: "Child Corp",
        parent_id: "parent",
        level: 1,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, parent)
      {:ok, model} = MultiTenancyModel.add_tenant(model, child)
      {:ok, updated_model} = MultiTenancyModel.remove_tenant(model, "child")

      parent_children = Map.get(updated_model.tenant_hierarchy, "parent", [])
      refute "child" in parent_children
    end

    test "returns error when tenant has children", %{model: model} do
      parent = %{
        id: "parent",
        name: "Parent Corp",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      child = %{
        id: "child",
        name: "Child Corp",
        parent_id: "parent",
        level: 1,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, parent)
      {:ok, model} = MultiTenancyModel.add_tenant(model, child)

      {:error, :tenant_has_children} = MultiTenancyModel.remove_tenant(model, "parent")
    end

    test "returns error when tenant not found", %{model: model} do
      {:error, :tenant_not_found} = MultiTenancyModel.remove_tenant(model, "nonexistent")
    end

    test "removes cross-tenant permissions involving the tenant", %{model: model} do
      tenant1 = %{
        id: "tenant1",
        name: "Tenant 1",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      tenant2 = %{
        id: "tenant2",
        name: "Tenant 2",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      permission = %{
        from_tenant: "tenant1",
        to_tenant: "tenant2",
        subject: "alice",
        action: "read",
        resource_pattern: "shared/*"
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant1)
      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant2)
      {:ok, model} = MultiTenancyModel.add_cross_tenant_permission(model, permission)
      {:ok, updated_model} = MultiTenancyModel.remove_tenant(model, "tenant1")

      refute permission in updated_model.cross_tenant_permissions
    end
  end

  describe "add_user_to_tenant/4" do
    test "adds a user with roles to a tenant", %{model: model} do
      tenant = %{
        id: "tenant1",
        name: "Acme Corp",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant)

      {:ok, updated_model} =
        MultiTenancyModel.add_user_to_tenant(model, "tenant1", "alice", ["admin", "user"])

      tenant_users = Map.get(updated_model.tenant_users, "tenant1")
      assert Map.get(tenant_users, "alice") == ["admin", "user"]
    end

    test "returns error when tenant not found", %{model: model} do
      {:error, :tenant_not_found} =
        MultiTenancyModel.add_user_to_tenant(model, "nonexistent", "alice", ["admin"])
    end
  end

  describe "add_tenant_policy/4" do
    test "adds a policy to a tenant", %{model: model} do
      tenant = %{
        id: "tenant1",
        name: "Acme Corp",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant)

      {:ok, updated_model} =
        MultiTenancyModel.add_tenant_policy(model, "tenant1", "p", ["alice", "read", "doc1"])

      tenant_policies = Map.get(updated_model.tenant_policies, "tenant1")
      p_policies = Map.get(tenant_policies, "p", [])
      assert ["alice", "read", "doc1"] in p_policies
    end

    test "returns error when tenant not found", %{model: model} do
      {:error, :tenant_not_found} =
        MultiTenancyModel.add_tenant_policy(model, "nonexistent", "p", ["alice", "read", "doc1"])
    end
  end

  describe "add_cross_tenant_permission/2" do
    test "adds cross-tenant permission for moderate isolation", %{model: model} do
      tenant1 = %{
        id: "tenant1",
        name: "Tenant 1",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      tenant2 = %{
        id: "tenant2",
        name: "Tenant 2",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      permission = %{
        from_tenant: "tenant1",
        to_tenant: "tenant2",
        subject: "alice",
        action: "read",
        resource_pattern: "shared/*"
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant1)
      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant2)
      {:ok, updated_model} = MultiTenancyModel.add_cross_tenant_permission(model, permission)

      assert permission in updated_model.cross_tenant_permissions
    end

    test "rejects cross-tenant permission for strict isolation", %{model: model} do
      strict_model = %{model | isolation_level: :strict}

      permission = %{
        from_tenant: "tenant1",
        to_tenant: "tenant2",
        subject: "alice",
        action: "read",
        resource_pattern: "shared/*"
      }

      {:error, :cross_tenant_access_forbidden} =
        MultiTenancyModel.add_cross_tenant_permission(strict_model, permission)
    end

    test "returns error when tenant not found", %{model: model} do
      permission = %{
        from_tenant: "nonexistent1",
        to_tenant: "nonexistent2",
        subject: "alice",
        action: "read",
        resource_pattern: "shared/*"
      }

      {:error, :tenant_not_found} =
        MultiTenancyModel.add_cross_tenant_permission(model, permission)
    end
  end

  describe "can_access?/5" do
    test "returns true when model is disabled", %{model: model} do
      disabled_model = %{model | enabled: false}

      result = MultiTenancyModel.can_access?(disabled_model, "tenant1", "alice", "read", "doc1")
      assert result == true
    end

    test "grants access to tenant users", %{model: model} do
      tenant = %{
        id: "tenant1",
        name: "Acme Corp",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant)
      {:ok, model} = MultiTenancyModel.add_user_to_tenant(model, "tenant1", "alice", ["user"])

      {:ok, model} =
        MultiTenancyModel.add_tenant_policy(model, "tenant1", "p", ["alice", "read", "doc1"])

      assert MultiTenancyModel.can_access?(model, "tenant1", "alice", "read", "doc1") == true
    end

    test "denies access to non-tenant users", %{model: model} do
      tenant = %{
        id: "tenant1",
        name: "Acme Corp",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant)

      assert MultiTenancyModel.can_access?(model, "tenant1", "alice", "read", "doc1") == false
    end

    test "supports cross-tenant access with moderate isolation", %{model: model} do
      tenant1 = %{
        id: "tenant1",
        name: "Tenant 1",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      tenant2 = %{
        id: "tenant2",
        name: "Tenant 2",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      permission = %{
        from_tenant: "tenant1",
        to_tenant: "tenant2",
        subject: "alice",
        action: "read",
        resource_pattern: "shared*"
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant1)
      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant2)
      {:ok, model} = MultiTenancyModel.add_cross_tenant_permission(model, permission)

      assert MultiTenancyModel.can_access?(model, "tenant2", "alice", "read", "shared_doc") ==
               true
    end

    test "blocks cross-tenant access with strict isolation", %{model: model} do
      strict_model = %{model | isolation_level: :strict}

      tenant1 = %{
        id: "tenant1",
        name: "Tenant 1",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      tenant2 = %{
        id: "tenant2",
        name: "Tenant 2",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(strict_model, tenant1)
      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant2)
      {:ok, model} = MultiTenancyModel.add_user_to_tenant(model, "tenant1", "alice", ["user"])

      assert MultiTenancyModel.can_access?(model, "tenant2", "alice", "read", "doc1") == false
    end

    test "supports inherited access from parent tenants with relaxed isolation", %{model: model} do
      relaxed_model = %{model | isolation_level: :relaxed}

      parent = %{
        id: "parent",
        name: "Parent Corp",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      child = %{
        id: "child",
        name: "Child Corp",
        parent_id: "parent",
        level: 1,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(relaxed_model, parent)
      {:ok, model} = MultiTenancyModel.add_tenant(model, child)
      {:ok, model} = MultiTenancyModel.add_user_to_tenant(model, "parent", "alice", ["admin"])

      {:ok, model} =
        MultiTenancyModel.add_tenant_policy(model, "parent", "p", ["alice", "read", "doc1"])

      # Alice should inherit access in child tenant
      assert MultiTenancyModel.can_access?(model, "child", "alice", "read", "doc1") == true
    end
  end

  describe "evaluate_policy/3" do
    test "returns true when model is disabled", %{model: model} do
      disabled_model = %{model | enabled: false}

      result =
        MultiTenancyModel.evaluate_policy(
          disabled_model,
          ["tenant1", "alice", "read", "doc1"],
          "tenant_user"
        )

      assert result == true
    end

    test "evaluates tenant_user policy", %{model: model} do
      tenant = %{
        id: "tenant1",
        name: "Acme Corp",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant)
      {:ok, model} = MultiTenancyModel.add_user_to_tenant(model, "tenant1", "alice", ["user"])

      result =
        MultiTenancyModel.evaluate_policy(
          model,
          ["tenant1", "alice", "read", "doc1"],
          "tenant_user"
        )

      assert result == true

      result =
        MultiTenancyModel.evaluate_policy(
          model,
          ["tenant1", "bob", "read", "doc1"],
          "tenant_user"
        )

      assert result == false
    end

    test "evaluates tenant_admin policy", %{model: model} do
      tenant = %{
        id: "tenant1",
        name: "Acme Corp",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant)
      {:ok, model} = MultiTenancyModel.add_user_to_tenant(model, "tenant1", "alice", ["admin"])
      {:ok, model} = MultiTenancyModel.add_user_to_tenant(model, "tenant1", "bob", ["user"])

      result =
        MultiTenancyModel.evaluate_policy(
          model,
          ["tenant1", "alice", "read", "doc1"],
          "tenant_admin"
        )

      assert result == true

      result =
        MultiTenancyModel.evaluate_policy(
          model,
          ["tenant1", "bob", "read", "doc1"],
          "tenant_admin"
        )

      assert result == false
    end

    test "evaluates cross_tenant_allowed policy", %{model: model} do
      moderate_model = %{model | isolation_level: :moderate}
      strict_model = %{model | isolation_level: :strict}

      result =
        MultiTenancyModel.evaluate_policy(
          moderate_model,
          ["tenant1", "alice", "read", "doc1"],
          "cross_tenant_allowed"
        )

      assert result == true

      result =
        MultiTenancyModel.evaluate_policy(
          strict_model,
          ["tenant1", "alice", "read", "doc1"],
          "cross_tenant_allowed"
        )

      assert result == false
    end

    test "evaluates tenant_hierarchy policy", %{model: model} do
      tenant = %{
        id: "tenant1",
        name: "Acme Corp",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant)
      {:ok, model} = MultiTenancyModel.add_user_to_tenant(model, "tenant1", "alice", ["user"])

      {:ok, model} =
        MultiTenancyModel.add_tenant_policy(model, "tenant1", "p", ["alice", "read", "doc1"])

      result =
        MultiTenancyModel.evaluate_policy(
          model,
          ["tenant1", "alice", "read", "doc1"],
          "tenant_hierarchy"
        )

      assert result == true
    end
  end

  describe "get_tenant_descendants/2" do
    test "returns all descendants of a tenant", %{model: model} do
      parent = %{
        id: "parent",
        name: "Parent Corp",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      child1 = %{
        id: "child1",
        name: "Child 1",
        parent_id: "parent",
        level: 1,
        metadata: %{},
        active: true
      }

      child2 = %{
        id: "child2",
        name: "Child 2",
        parent_id: "parent",
        level: 1,
        metadata: %{},
        active: true
      }

      grandchild = %{
        id: "grandchild",
        name: "Grandchild",
        parent_id: "child1",
        level: 2,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, parent)
      {:ok, model} = MultiTenancyModel.add_tenant(model, child1)
      {:ok, model} = MultiTenancyModel.add_tenant(model, child2)
      {:ok, model} = MultiTenancyModel.add_tenant(model, grandchild)

      descendants = MultiTenancyModel.get_tenant_descendants(model, "parent")

      assert "child1" in descendants
      assert "child2" in descendants
      assert "grandchild" in descendants
    end

    test "returns empty list for tenant with no descendants", %{model: model} do
      tenant = %{
        id: "tenant1",
        name: "Lonely Tenant",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant)

      descendants = MultiTenancyModel.get_tenant_descendants(model, "tenant1")
      assert descendants == []
    end

    test "prevents infinite loops in circular hierarchies", %{model: model} do
      # This shouldn't happen in normal usage, but test defensive coding
      descendants = MultiTenancyModel.get_tenant_descendants(model, "nonexistent")
      assert descendants == []
    end
  end

  describe "get_tenant_ancestors/2" do
    test "returns all ancestors of a tenant", %{model: model} do
      grandparent = %{
        id: "grandparent",
        name: "Grandparent Corp",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      parent = %{
        id: "parent",
        name: "Parent Corp",
        parent_id: "grandparent",
        level: 1,
        metadata: %{},
        active: true
      }

      child = %{
        id: "child",
        name: "Child Corp",
        parent_id: "parent",
        level: 2,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, grandparent)
      {:ok, model} = MultiTenancyModel.add_tenant(model, parent)
      {:ok, model} = MultiTenancyModel.add_tenant(model, child)

      ancestors = MultiTenancyModel.get_tenant_ancestors(model, "child")

      assert ancestors == ["parent", "grandparent"]
    end

    test "returns empty list for root tenant", %{model: model} do
      tenant = %{
        id: "root",
        name: "Root Tenant",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant)

      ancestors = MultiTenancyModel.get_tenant_ancestors(model, "root")
      assert ancestors == []
    end

    test "returns empty list for nonexistent tenant", %{model: model} do
      ancestors = MultiTenancyModel.get_tenant_ancestors(model, "nonexistent")
      assert ancestors == []
    end
  end

  describe "get_all_tenant_users/2" do
    test "returns direct users for moderate isolation", %{model: model} do
      tenant = %{
        id: "tenant1",
        name: "Acme Corp",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant)
      {:ok, model} = MultiTenancyModel.add_user_to_tenant(model, "tenant1", "alice", ["admin"])
      {:ok, model} = MultiTenancyModel.add_user_to_tenant(model, "tenant1", "bob", ["user"])

      users = MultiTenancyModel.get_all_tenant_users(model, "tenant1")

      assert Map.get(users, "alice") == ["admin"]
      assert Map.get(users, "bob") == ["user"]
    end

    test "includes inherited users for relaxed isolation", %{model: model} do
      relaxed_model = %{model | isolation_level: :relaxed}

      parent = %{
        id: "parent",
        name: "Parent Corp",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      child = %{
        id: "child",
        name: "Child Corp",
        parent_id: "parent",
        level: 1,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(relaxed_model, parent)
      {:ok, model} = MultiTenancyModel.add_tenant(model, child)
      {:ok, model} = MultiTenancyModel.add_user_to_tenant(model, "parent", "alice", ["admin"])
      {:ok, model} = MultiTenancyModel.add_user_to_tenant(model, "child", "bob", ["user"])

      users = MultiTenancyModel.get_all_tenant_users(model, "child")

      # Should include both direct users and inherited users
      # inherited from parent
      assert Map.get(users, "alice") == ["admin"]
      # direct user
      assert Map.get(users, "bob") == ["user"]
    end

    test "does not include inherited users for non-relaxed isolation", %{model: model} do
      parent = %{
        id: "parent",
        name: "Parent Corp",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      child = %{
        id: "child",
        name: "Child Corp",
        parent_id: "parent",
        level: 1,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, parent)
      {:ok, model} = MultiTenancyModel.add_tenant(model, child)
      {:ok, model} = MultiTenancyModel.add_user_to_tenant(model, "parent", "alice", ["admin"])
      {:ok, model} = MultiTenancyModel.add_user_to_tenant(model, "child", "bob", ["user"])

      users = MultiTenancyModel.get_all_tenant_users(model, "child")

      # Should only include direct users
      # not inherited
      assert Map.get(users, "alice") == nil
      # direct user
      assert Map.get(users, "bob") == ["user"]
    end
  end

  describe "complex scenarios" do
    test "handles multi-level tenant hierarchies with various access patterns", %{model: model} do
      # Create hierarchy: enterprise -> division -> department
      enterprise = %{
        id: "enterprise",
        name: "Enterprise Corp",
        parent_id: nil,
        level: 0,
        metadata: %{"type" => "enterprise"},
        active: true
      }

      division = %{
        id: "division1",
        name: "Engineering Division",
        parent_id: "enterprise",
        level: 1,
        metadata: %{"type" => "division"},
        active: true
      }

      department = %{
        id: "dept1",
        name: "Backend Department",
        parent_id: "division1",
        level: 2,
        metadata: %{"type" => "department"},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, enterprise)
      {:ok, model} = MultiTenancyModel.add_tenant(model, division)
      {:ok, model} = MultiTenancyModel.add_tenant(model, department)

      # Add users at different levels
      {:ok, model} = MultiTenancyModel.add_user_to_tenant(model, "enterprise", "ceo", ["admin"])

      {:ok, model} =
        MultiTenancyModel.add_user_to_tenant(model, "division1", "director", ["manager"])

      {:ok, model} = MultiTenancyModel.add_user_to_tenant(model, "dept1", "alice", ["developer"])

      # Add policies
      {:ok, model} =
        MultiTenancyModel.add_tenant_policy(model, "enterprise", "p", ["ceo", "read", "*"])

      {:ok, model} =
        MultiTenancyModel.add_tenant_policy(model, "division1", "p", [
          "director",
          "read",
          "division_docs"
        ])

      {:ok, model} =
        MultiTenancyModel.add_tenant_policy(model, "dept1", "p", ["alice", "read", "dept_docs"])

      # Test access patterns
      assert MultiTenancyModel.can_access?(model, "enterprise", "ceo", "read", "*") == true

      assert MultiTenancyModel.can_access?(
               model,
               "division1",
               "director",
               "read",
               "division_docs"
             ) == true

      assert MultiTenancyModel.can_access?(model, "dept1", "alice", "read", "dept_docs") == true

      # Test cross-tenant access (should fail for non-relaxed)
      assert MultiTenancyModel.can_access?(model, "dept1", "director", "read", "dept_docs") ==
               false
    end

    test "handles complex cross-tenant permission patterns", %{model: model} do
      tenant1 = %{
        id: "tenant1",
        name: "Company A",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      tenant2 = %{
        id: "tenant2",
        name: "Company B",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      tenant3 = %{
        id: "tenant3",
        name: "Company C",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant1)
      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant2)
      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant3)

      # Create cross-tenant permissions for collaboration
      permission1 = %{
        from_tenant: "tenant1",
        to_tenant: "tenant2",
        subject: "alice",
        action: "read",
        resource_pattern: "shared/*"
      }

      permission2 = %{
        from_tenant: "tenant2",
        to_tenant: "tenant3",
        subject: "bob",
        action: "write",
        resource_pattern: "collaboration/*"
      }

      {:ok, model} = MultiTenancyModel.add_cross_tenant_permission(model, permission1)
      {:ok, model} = MultiTenancyModel.add_cross_tenant_permission(model, permission2)

      # Test cross-tenant access
      assert MultiTenancyModel.can_access?(model, "tenant2", "alice", "read", "shared/document") ==
               true

      assert MultiTenancyModel.can_access?(
               model,
               "tenant3",
               "bob",
               "write",
               "collaboration/project"
             ) == true

      assert MultiTenancyModel.can_access?(model, "tenant1", "bob", "write", "anything") == false
    end

    test "resource pattern matching works correctly", %{model: model} do
      tenant1 = %{
        id: "tenant1",
        name: "Company A",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      tenant2 = %{
        id: "tenant2",
        name: "Company B",
        parent_id: nil,
        level: 0,
        metadata: %{},
        active: true
      }

      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant1)
      {:ok, model} = MultiTenancyModel.add_tenant(model, tenant2)

      # Permission with wildcard pattern
      permission = %{
        from_tenant: "tenant1",
        to_tenant: "tenant2",
        subject: "alice",
        action: "read",
        resource_pattern: "documents/public/*"
      }

      {:ok, model} = MultiTenancyModel.add_cross_tenant_permission(model, permission)

      # Should match pattern
      assert MultiTenancyModel.can_access?(
               model,
               "tenant2",
               "alice",
               "read",
               "documents/public/readme.txt"
             ) == true

      assert MultiTenancyModel.can_access?(
               model,
               "tenant2",
               "alice",
               "read",
               "documents/public/subfolder/file.txt"
             ) == true

      # Should not match pattern
      assert MultiTenancyModel.can_access?(
               model,
               "tenant2",
               "alice",
               "read",
               "documents/private/secret.txt"
             ) == false

      assert MultiTenancyModel.can_access?(
               model,
               "tenant2",
               "alice",
               "read",
               "other/document.txt"
             ) == false
    end
  end
end
