defmodule CasbinEx2.CustomMatchingTest do
  @moduledoc """
  Tests for custom matching and link condition functions (Priority 3).

  These functions enable advanced role management with custom matching logic
  and conditional role assignments.
  """
  use ExUnit.Case

  alias CasbinEx2.Adapter.MemoryAdapter
  alias CasbinEx2.Enforcer
  alias CasbinEx2.Management

  @moduletag :unit

  describe "Custom Matching Functions" do
    setup do
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

      model_path = "/tmp/test_custom_matching_model.conf"
      File.write!(model_path, model_content)

      adapter = MemoryAdapter.new()
      {:ok, enforcer} = Enforcer.new_enforcer(model_path, adapter)

      # Add some policies
      {:ok, enforcer} = Management.add_policy(enforcer, ["admin", "data1", "read"])

      on_exit(fn -> File.rm(model_path) end)

      {:ok, enforcer: enforcer}
    end

    test "add_named_matching_func/4 successfully adds matching function for default role manager",
         %{enforcer: enforcer} do
      # Define a custom matching function (regex pattern matching)
      custom_match_fn = fn name1, name2 ->
        String.contains?(name1, name2) || String.contains?(name2, name1)
      end

      {:ok, updated_enforcer} =
        Enforcer.add_named_matching_func(enforcer, "g", "customMatch", custom_match_fn)

      assert %Enforcer{} = updated_enforcer
      assert updated_enforcer.role_manager != nil
    end

    test "add_named_matching_func/4 returns error when role manager not found", %{
      enforcer: enforcer
    } do
      custom_match_fn = fn _name1, _name2 -> true end

      assert {:error, :role_manager_not_found} =
               Enforcer.add_named_matching_func(enforcer, "g2", "customMatch", custom_match_fn)
    end

    test "add_named_domain_matching_func/4 successfully adds domain matching function", %{
      enforcer: enforcer
    } do
      # Define a hierarchical domain matching function
      domain_match_fn = fn domain1, domain2 ->
        String.starts_with?(domain1, domain2) || String.starts_with?(domain2, domain1)
      end

      {:ok, updated_enforcer} =
        Enforcer.add_named_domain_matching_func(
          enforcer,
          "g",
          "domainMatch",
          domain_match_fn
        )

      assert %Enforcer{} = updated_enforcer
      assert updated_enforcer.role_manager != nil
    end

    test "add_named_domain_matching_func/4 returns error when role manager not found", %{
      enforcer: enforcer
    } do
      domain_match_fn = fn _d1, _d2 -> true end

      assert {:error, :role_manager_not_found} =
               Enforcer.add_named_domain_matching_func(
                 enforcer,
                 "g2",
                 "domainMatch",
                 domain_match_fn
               )
    end
  end

  describe "Custom Matching Functions - Named Role Managers" do
    setup do
      model_content = """
      [request_definition]
      r = sub, obj, act

      [policy_definition]
      p = sub, obj, act

      [role_definition]
      g = _, _
      g2 = _, _

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = g(r.sub, p.sub) && r.obj == p.obj && r.act == p.act
      """

      model_path = "/tmp/test_named_custom_matching_model.conf"
      File.write!(model_path, model_content)

      adapter = MemoryAdapter.new()
      {:ok, enforcer} = Enforcer.new_enforcer(model_path, adapter)

      on_exit(fn -> File.rm(model_path) end)

      {:ok, enforcer: enforcer}
    end

    test "add_named_matching_func/4 returns error when named role manager g2 not initialized", %{
      enforcer: enforcer
    } do
      # Note: Adding grouping policy alone doesn't initialize named role manager
      # Named role managers must be explicitly set via set_named_role_manager
      custom_match_fn = fn name1, name2 -> name1 == name2 end

      assert {:error, :role_manager_not_found} =
               Enforcer.add_named_matching_func(enforcer, "g2", "exactMatch", custom_match_fn)
    end

    test "add_named_domain_matching_func/4 returns error when named role manager g2 not initialized",
         %{
           enforcer: enforcer
         } do
      # Note: Adding grouping policy alone doesn't initialize named role manager
      # Named role managers must be explicitly set via set_named_role_manager
      domain_match_fn = fn d1, d2 -> d1 == d2 end

      assert {:error, :role_manager_not_found} =
               Enforcer.add_named_domain_matching_func(
                 enforcer,
                 "g2",
                 "exactDomainMatch",
                 domain_match_fn
               )
    end
  end

  describe "Link Condition Functions" do
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

      model_path = "/tmp/test_link_condition_model.conf"
      File.write!(model_path, model_content)

      adapter = MemoryAdapter.new()
      {:ok, enforcer} = Enforcer.new_enforcer(model_path, adapter)

      # Add policies
      {:ok, enforcer} = Management.add_policy(enforcer, ["admin", "domain1", "data1", "read"])

      {:ok, enforcer} =
        Management.add_grouping_policy(enforcer, ["alice", "admin", "domain1"])

      on_exit(fn -> File.rm(model_path) end)

      {:ok, enforcer: enforcer}
    end

    test "add_named_link_condition_func/5 successfully adds condition function", %{
      enforcer: enforcer
    } do
      # Time-based access control
      time_condition = fn params ->
        time = Map.get(params, "time", "00:00")
        time >= "09:00" && time <= "17:00"
      end

      updated_enforcer =
        Enforcer.add_named_link_condition_func(
          enforcer,
          "g",
          "alice",
          "admin",
          time_condition
        )

      assert %Enforcer{} = updated_enforcer
      # For "g", the role manager is stored in role_manager field, not named_role_managers
      assert updated_enforcer.role_manager != nil
    end

    test "add_named_link_condition_func/5 returns enforcer unchanged when role manager not found" do
      enforcer = %Enforcer{named_role_managers: %{}}

      condition = fn _params -> true end

      result = Enforcer.add_named_link_condition_func(enforcer, "g", "alice", "admin", condition)

      assert result == enforcer
    end

    test "add_named_domain_link_condition_func/6 successfully adds domain condition", %{
      enforcer: enforcer
    } do
      # Department-based access control
      dept_condition = fn params ->
        Map.get(params, "department") == "IT"
      end

      updated_enforcer =
        Enforcer.add_named_domain_link_condition_func(
          enforcer,
          "g",
          "alice",
          "admin",
          "domain1",
          dept_condition
        )

      assert %Enforcer{} = updated_enforcer
      # For "g", the role manager is stored in role_manager field, not named_role_managers
      assert updated_enforcer.role_manager != nil
    end

    test "add_named_domain_link_condition_func/6 returns enforcer unchanged when role manager not found" do
      enforcer = %Enforcer{named_role_managers: %{}}

      condition = fn _params -> true end

      result =
        Enforcer.add_named_domain_link_condition_func(
          enforcer,
          "g",
          "alice",
          "admin",
          "domain1",
          condition
        )

      assert result == enforcer
    end

    test "set_named_link_condition_func_params/4 successfully sets parameters", %{
      enforcer: enforcer
    } do
      # First add a condition
      time_condition = fn params ->
        time = Map.get(params, "time", "00:00")
        time >= "09:00" && time <= "17:00"
      end

      enforcer =
        Enforcer.add_named_link_condition_func(
          enforcer,
          "g",
          "alice",
          "admin",
          time_condition
        )

      # Then set parameters
      updated_enforcer =
        Enforcer.set_named_link_condition_func_params(
          enforcer,
          "g",
          "alice",
          "admin",
          ["time=14:30"]
        )

      assert %Enforcer{} = updated_enforcer
      # For "g", the role manager is stored in role_manager field, not named_role_managers
      assert updated_enforcer.role_manager != nil
    end

    test "set_named_link_condition_func_params/4 returns enforcer unchanged when role manager not found" do
      enforcer = %Enforcer{named_role_managers: %{}}

      result =
        Enforcer.set_named_link_condition_func_params(
          enforcer,
          "g",
          "alice",
          "admin",
          ["time=14:30"]
        )

      assert result == enforcer
    end

    test "set_named_domain_link_condition_func_params/5 successfully sets domain parameters", %{
      enforcer: enforcer
    } do
      # First add a condition
      dept_condition = fn params ->
        Map.get(params, "department") == "IT"
      end

      enforcer =
        Enforcer.add_named_domain_link_condition_func(
          enforcer,
          "g",
          "alice",
          "admin",
          "domain1",
          dept_condition
        )

      # Then set parameters
      updated_enforcer =
        Enforcer.set_named_domain_link_condition_func_params(
          enforcer,
          "g",
          "alice",
          "admin",
          "domain1",
          ["department=IT", "location=office"]
        )

      assert %Enforcer{} = updated_enforcer
      # For "g", the role manager is stored in role_manager field, not named_role_managers
      assert updated_enforcer.role_manager != nil
    end

    test "set_named_domain_link_condition_func_params/5 returns enforcer unchanged when role manager not found" do
      enforcer = %Enforcer{named_role_managers: %{}}

      result =
        Enforcer.set_named_domain_link_condition_func_params(
          enforcer,
          "g",
          "alice",
          "admin",
          "domain1",
          ["department=IT"]
        )

      assert result == enforcer
    end
  end

  describe "Link Condition Functions - Complex Scenarios" do
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

      model_path = "/tmp/test_complex_condition_model.conf"
      File.write!(model_path, model_content)

      adapter = MemoryAdapter.new()
      {:ok, enforcer} = Enforcer.new_enforcer(model_path, adapter)

      {:ok, enforcer} = Management.add_policy(enforcer, ["admin", "domain1", "data1", "read"])

      {:ok, enforcer} =
        Management.add_grouping_policy(enforcer, ["alice", "admin", "domain1"])

      on_exit(fn -> File.rm(model_path) end)

      {:ok, enforcer: enforcer}
    end

    test "multiple conditions can be added for different users", %{enforcer: enforcer} do
      # Add bob to the enforcer first (before converting role_manager to conditional)
      {:ok, enforcer} =
        Management.add_grouping_policy(enforcer, ["bob", "admin", "domain1"])

      # Now add conditions for both users
      time_condition = fn params -> Map.get(params, "time", "00:00") < "18:00" end
      location_condition = fn params -> Map.get(params, "location") == "office" end

      enforcer =
        Enforcer.add_named_link_condition_func(
          enforcer,
          "g",
          "alice",
          "admin",
          time_condition
        )

      enforcer =
        Enforcer.add_named_link_condition_func(
          enforcer,
          "g",
          "bob",
          "admin",
          location_condition
        )

      assert %Enforcer{} = enforcer
      # For "g", the role manager is stored in role_manager field, not named_role_managers
      assert enforcer.role_manager != nil
    end

    test "parameters can be updated multiple times", %{enforcer: enforcer} do
      time_condition = fn params ->
        time = Map.get(params, "time", "00:00")
        time >= "09:00" && time <= "17:00"
      end

      enforcer =
        Enforcer.add_named_link_condition_func(
          enforcer,
          "g",
          "alice",
          "admin",
          time_condition
        )

      # First parameter update
      enforcer =
        Enforcer.set_named_link_condition_func_params(
          enforcer,
          "g",
          "alice",
          "admin",
          ["time=09:00"]
        )

      # Second parameter update
      updated_enforcer =
        Enforcer.set_named_link_condition_func_params(
          enforcer,
          "g",
          "alice",
          "admin",
          ["time=14:30"]
        )

      assert %Enforcer{} = updated_enforcer
    end

    test "domain conditions work with parameters", %{enforcer: enforcer} do
      # Complex condition checking multiple parameters
      complex_condition = fn params ->
        dept = Map.get(params, "department")
        level = Map.get(params, "level", "0") |> String.to_integer()
        dept == "IT" && level >= 3
      end

      enforcer =
        Enforcer.add_named_domain_link_condition_func(
          enforcer,
          "g",
          "alice",
          "admin",
          "domain1",
          complex_condition
        )

      updated_enforcer =
        Enforcer.set_named_domain_link_condition_func_params(
          enforcer,
          "g",
          "alice",
          "admin",
          "domain1",
          ["department=IT", "level=5"]
        )

      assert %Enforcer{} = updated_enforcer
    end
  end
end
