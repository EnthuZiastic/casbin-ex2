defmodule CasbinEx2.IncrementalRoleLinksTest do
  @moduledoc """
  Tests for incremental role link building functions.

  These functions are used internally for performance optimization when
  auto_build_role_links is disabled or for manual role link management.
  """
  use ExUnit.Case

  alias CasbinEx2.Adapter.MemoryAdapter
  alias CasbinEx2.Enforcer
  alias CasbinEx2.Management

  @moduletag :unit

  describe "Incremental Role Links - Core Functionality" do
    setup do
      model_content = """
      [request_definition]
      r = sub, dom, obj, act

      [policy_definition]
      p = sub, dom, obj, act

      [role_definition]
      g = _, _, _

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = g(r.sub, p.sub, r.dom) && r.dom == p.dom && r.obj == p.obj && r.act == p.act
      """

      model_path = "/tmp/test_incremental_model.conf"
      File.write!(model_path, model_content)

      adapter = MemoryAdapter.new()
      {:ok, enforcer} = Enforcer.new_enforcer(model_path, adapter)

      # Disable auto_build_role_links to test manual building
      enforcer = Enforcer.enable_auto_build_role_links(enforcer, false)

      # Add policies and grouping policies manually
      {:ok, enforcer} =
        Management.add_policy(enforcer, ["admin", "domain1", "data1", "read"])

      {:ok, enforcer} =
        Management.add_grouping_policy(enforcer, ["alice", "admin", "domain1"])

      {:ok, enforcer} =
        Management.add_grouping_policy(enforcer, ["bob", "editor", "domain1"])

      on_exit(fn -> File.rm(model_path) end)

      {:ok, enforcer: enforcer}
    end

    test "build_incremental_role_links/4 successfully builds role links", %{
      enforcer: enforcer
    } do
      # Build role links for existing grouping policies
      {:ok, updated_enforcer} =
        Enforcer.build_incremental_role_links(
          enforcer,
          :add,
          "g",
          [["alice", "admin", "domain1"], ["bob", "editor", "domain1"]]
        )

      # Verify the function succeeded
      assert %Enforcer{} = updated_enforcer
    end

    test "build_incremental_role_links/4 handles empty rules list", %{enforcer: enforcer} do
      # Should succeed but not change anything
      {:ok, _updated_enforcer} = Enforcer.build_incremental_role_links(enforcer, :add, "g", [])
    end

    test "build_incremental_role_links/4 skips invalid rules", %{enforcer: enforcer} do
      # Mix valid and invalid rules
      mixed_rules = [
        ["charlie", "viewer", "domain1"],
        # Valid rule
        ["invalid"],
        # Invalid - too short
        []
        # Invalid - empty
      ]

      {:ok, _updated_enforcer} =
        Enforcer.build_incremental_role_links(enforcer, :add, "g", mixed_rules)
    end
  end

  describe "Incremental Role Links - Error Handling" do
    test "build_incremental_role_links/4 returns error for nil role_manager" do
      # Create enforcer without initializing role manager
      enforcer = %Enforcer{role_manager: nil}
      rules = [["alice", "admin"]]

      assert {:error, "role manager is not initialized"} =
               Enforcer.build_incremental_role_links(enforcer, :add, "g", rules)
    end

    test "build_incremental_role_links/4 returns error for invalid operation" do
      model_path = "/tmp/test_error_model.conf"

      model_content = """
      [request_definition]
      r = sub, obj, act

      [policy_definition]
      p = sub, obj, act

      [role_definition]
      g = _, _

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act
      """

      File.write!(model_path, model_content)

      adapter = MemoryAdapter.new()
      {:ok, enforcer} = Enforcer.new_enforcer(model_path, adapter)

      rules = [["alice", "admin"]]

      assert {:error, error_msg} =
               Enforcer.build_incremental_role_links(enforcer, :invalid_op, "g", rules)

      assert error_msg =~ "invalid operation"

      File.rm(model_path)
    end
  end

  describe "Incremental Conditional Role Links" do
    setup do
      model_content = """
      [request_definition]
      r = sub, dom, obj, act

      [policy_definition]
      p = sub, dom, obj, act

      [role_definition]
      g = _, _, _

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = g(r.sub, p.sub, r.dom) && r.dom == p.dom && r.obj == p.obj && r.act == p.act
      """

      model_path = "/tmp/test_conditional_model.conf"
      File.write!(model_path, model_content)

      adapter = MemoryAdapter.new()
      {:ok, enforcer} = Enforcer.new_enforcer(model_path, adapter)

      # Disable auto_build_role_links
      enforcer = Enforcer.enable_auto_build_role_links(enforcer, false)

      # Add policies and grouping policies
      {:ok, enforcer} =
        Management.add_policy(enforcer, ["admin", "domain1", "data1", "read"])

      {:ok, enforcer} =
        Management.add_grouping_policy(enforcer, ["alice", "admin", "domain1"])

      on_exit(fn -> File.rm(model_path) end)

      {:ok, enforcer: enforcer}
    end

    test "build_incremental_conditional_role_links/4 successfully builds conditional role links",
         %{enforcer: enforcer} do
      # Build conditional role links
      {:ok, updated_enforcer} =
        Enforcer.build_incremental_conditional_role_links(
          enforcer,
          :add,
          "g",
          [["alice", "admin", "domain1"]]
        )

      # Verify the function succeeded
      assert %Enforcer{} = updated_enforcer
    end

    test "build_incremental_conditional_role_links/4 returns error for nil role_manager" do
      enforcer = %Enforcer{role_manager: nil}
      rules = [["alice", "admin", "domain1"]]

      assert {:error, "role manager is not initialized"} =
               Enforcer.build_incremental_conditional_role_links(enforcer, :add, "g", rules)
    end
  end
end
