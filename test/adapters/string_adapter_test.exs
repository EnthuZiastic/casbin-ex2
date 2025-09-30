defmodule CasbinEx2.Adapter.StringAdapterTest do
  use ExUnit.Case, async: true

  alias CasbinEx2.Adapter.StringAdapter

  @csv_content """
  p, alice, data1, read
  p, bob, data2, write
  g, alice, admin
  g, bob, user
  """

  @json_content """
  {
    "policies": {
      "p": [["alice", "data1", "read"], ["bob", "data2", "write"]]
    },
    "grouping_policies": {
      "g": [["alice", "admin"], ["bob", "user"]]
    }
  }
  """

  @lines_content """
  alice, data1, read
  bob, data2, write
  carol, data3, read
  """

  describe "new/2" do
    test "creates adapter with CSV format (default)" do
      adapter = StringAdapter.new(@csv_content)

      assert adapter.format == :csv
      assert adapter.content == @csv_content
      assert is_map(adapter.policies)
      assert is_map(adapter.grouping_policies)
    end

    test "creates adapter with JSON format" do
      adapter = StringAdapter.new(@json_content, format: :json)

      assert adapter.format == :json
      assert adapter.policies["p"] == [["alice", "data1", "read"], ["bob", "data2", "write"]]
      assert adapter.grouping_policies["g"] == [["alice", "admin"], ["bob", "user"]]
    end

    test "creates adapter with lines format" do
      adapter = StringAdapter.new(@lines_content, format: :lines)

      assert adapter.format == :lines

      assert adapter.policies["p"] == [
               ["alice", "data1", "read"],
               ["bob", "data2", "write"],
               ["carol", "data3", "read"]
             ]
    end

    test "creates adapter with custom parser" do
      custom_parser = fn content ->
        lines = String.split(content, "\n")

        policies = %{
          "p" =>
            Enum.map(lines, fn line ->
              String.split(line, ",") |> Enum.map(&String.trim/1)
            end)
        }

        {:ok, policies, %{}}
      end

      adapter = StringAdapter.new("test,data", format: :custom, parser: custom_parser)

      assert adapter.format == :custom
      assert adapter.parser == custom_parser
    end

    test "creates adapter without parsing on create" do
      adapter = StringAdapter.new(@csv_content, parse_on_create: false)

      assert adapter.policies == %{}
      assert adapter.grouping_policies == %{}
    end
  end

  describe "from_policies/3" do
    test "creates adapter from policy maps with CSV format" do
      policies = %{"p" => [["alice", "data1", "read"]]}
      grouping_policies = %{"g" => [["alice", "admin"]]}

      adapter = StringAdapter.from_policies(policies, grouping_policies, format: :csv)

      assert adapter.policies == policies
      assert adapter.grouping_policies == grouping_policies
      assert String.contains?(adapter.content, "p, alice, data1, read")
      assert String.contains?(adapter.content, "g, alice, admin")
    end

    test "creates adapter from policy maps with JSON format" do
      policies = %{"p" => [["alice", "data1", "read"]]}
      grouping_policies = %{"g" => [["alice", "admin"]]}

      adapter = StringAdapter.from_policies(policies, grouping_policies, format: :json)

      assert adapter.format == :json
      {:ok, parsed} = Jason.decode(adapter.content)
      assert parsed["policies"] == policies
      assert parsed["grouping_policies"] == grouping_policies
    end
  end

  describe "update_content/2" do
    test "updates content and re-parses policies" do
      adapter = StringAdapter.new("p, alice, data1, read")

      new_content = "p, bob, data2, write\ng, bob, user"
      {:ok, updated_adapter} = StringAdapter.update_content(adapter, new_content)

      assert updated_adapter.content == new_content
      assert updated_adapter.policies["p"] == [["bob", "data2", "write"]]
      assert updated_adapter.grouping_policies["g"] == [["bob", "user"]]
    end

    test "handles parsing errors gracefully" do
      adapter = StringAdapter.new(@csv_content)

      invalid_json = "{invalid json"

      {:ok, updated_adapter} =
        StringAdapter.update_content(%{adapter | format: :json}, invalid_json)

      # Should update content but keep old policies due to parsing error
      assert updated_adapter.content == invalid_json
    end
  end

  describe "validate/1" do
    test "validates policies with built-in validation" do
      adapter = StringAdapter.new(@csv_content)

      assert {:ok, _} = StringAdapter.validate(adapter)
    end

    test "validates policies with custom validator" do
      validator = fn policies, grouping_policies ->
        if map_size(policies) > 0 do
          {:ok, policies, grouping_policies}
        else
          {:error, "No policies found"}
        end
      end

      adapter = StringAdapter.new(@csv_content, validator: validator)

      assert {:ok, _} = StringAdapter.validate(adapter)
    end

    test "rejects invalid policies with custom validator" do
      validator = fn _policies, _grouping_policies ->
        {:error, "Always invalid"}
      end

      adapter = StringAdapter.new(@csv_content, validator: validator)

      assert {:error, "Always invalid"} = StringAdapter.validate(adapter)
    end
  end

  describe "get_stats/1" do
    test "returns adapter statistics" do
      adapter = StringAdapter.new(@csv_content)
      stats = StringAdapter.get_stats(adapter)

      assert is_integer(stats.content_size)
      assert is_integer(stats.policy_count)
      assert is_integer(stats.grouping_policy_count)
      assert is_list(stats.policy_types)
      assert %DateTime{} = stats.last_updated
    end
  end

  describe "adapter behavior implementation" do
    setup do
      adapter = StringAdapter.new(@csv_content)
      {:ok, %{adapter: adapter}}
    end

    test "load_policy/2", %{adapter: adapter} do
      {:ok, policies, grouping_policies} = StringAdapter.load_policy(adapter, nil)

      assert policies["p"] == [["alice", "data1", "read"], ["bob", "data2", "write"]]
      assert grouping_policies["g"] == [["alice", "admin"], ["bob", "user"]]
    end

    test "load_filtered_policy/3 with function filter", %{adapter: adapter} do
      filter = fn _policy_type, rule ->
        Enum.at(rule, 0) == "alice"
      end

      {:ok, filtered_policies, filtered_grouping} =
        StringAdapter.load_filtered_policy(adapter, nil, filter)

      assert filtered_policies["p"] == [["alice", "data1", "read"]]
      assert filtered_grouping["g"] == [["alice", "admin"]]
    end

    test "load_filtered_policy/3 with nil filter", %{adapter: adapter} do
      {:ok, policies, grouping_policies} = StringAdapter.load_filtered_policy(adapter, nil, nil)

      assert policies["p"] == [["alice", "data1", "read"], ["bob", "data2", "write"]]
      assert grouping_policies["g"] == [["alice", "admin"], ["bob", "user"]]
    end

    test "filtered?/1", %{adapter: adapter} do
      assert StringAdapter.filtered?(adapter) == true
    end

    test "save_policy/3", %{adapter: adapter} do
      new_policies = %{"p" => [["carol", "data3", "read"]]}
      new_grouping = %{"g" => [["carol", "user"]]}

      assert :ok = StringAdapter.save_policy(adapter, new_policies, new_grouping)

      # Check that adapter state was updated
      updated_adapter = Process.get(:string_adapter_state, adapter)
      assert updated_adapter.policies == new_policies
      assert updated_adapter.grouping_policies == new_grouping
    end

    test "add_policy/4", %{adapter: adapter} do
      assert :ok = StringAdapter.add_policy(adapter, "p", "p", ["carol", "data3", "read"])

      updated_adapter = Process.get(:string_adapter_state, adapter)
      assert ["carol", "data3", "read"] in updated_adapter.policies["p"]
    end

    test "remove_policy/4", %{adapter: adapter} do
      assert :ok = StringAdapter.remove_policy(adapter, "p", "p", ["alice", "data1", "read"])

      updated_adapter = Process.get(:string_adapter_state, adapter)
      refute ["alice", "data1", "read"] in updated_adapter.policies["p"]
      assert ["bob", "data2", "write"] in updated_adapter.policies["p"]
    end

    test "remove_filtered_policy/5", %{adapter: adapter} do
      assert :ok = StringAdapter.remove_filtered_policy(adapter, "p", "p", 0, ["alice"])

      updated_adapter = Process.get(:string_adapter_state, adapter)
      refute ["alice", "data1", "read"] in updated_adapter.policies["p"]
      assert ["bob", "data2", "write"] in updated_adapter.policies["p"]
    end
  end

  describe "CSV parsing" do
    test "parses standard CSV format correctly" do
      csv = """
      p, alice, data1, read
      p, bob, data2, write
      g, alice, admin
      # This is a comment

      g, bob, user
      """

      adapter = StringAdapter.new(csv)

      assert adapter.policies["p"] == [["alice", "data1", "read"], ["bob", "data2", "write"]]
      assert adapter.grouping_policies["g"] == [["alice", "admin"], ["bob", "user"]]
    end

    test "handles custom policy types" do
      csv = """
      p, alice, data1, read
      p2, bob, data2, write
      g, alice, admin
      g2, bob, manager
      """

      adapter = StringAdapter.new(csv)

      assert adapter.policies["p"] == [["alice", "data1", "read"]]
      assert adapter.policies["p2"] == [["bob", "data2", "write"]]
      assert adapter.grouping_policies["g"] == [["alice", "admin"]]
      assert adapter.grouping_policies["g2"] == [["bob", "manager"]]
    end

    test "ignores empty lines and comments" do
      csv = """
      # Policy file

      p, alice, data1, read

      # Grouping policies
      g, alice, admin

      """

      adapter = StringAdapter.new(csv)

      assert adapter.policies["p"] == [["alice", "data1", "read"]]
      assert adapter.grouping_policies["g"] == [["alice", "admin"]]
    end
  end

  describe "JSON parsing" do
    test "parses complete JSON structure" do
      adapter = StringAdapter.new(@json_content, format: :json)

      assert adapter.policies["p"] == [["alice", "data1", "read"], ["bob", "data2", "write"]]
      assert adapter.grouping_policies["g"] == [["alice", "admin"], ["bob", "user"]]
    end

    test "parses JSON with only policies" do
      json = """
      {
        "policies": {
          "p": [["alice", "data1", "read"]]
        }
      }
      """

      adapter = StringAdapter.new(json, format: :json)

      assert adapter.policies["p"] == [["alice", "data1", "read"]]
      assert adapter.grouping_policies == %{}
    end

    test "infers structure from flat JSON" do
      json = """
      {
        "p": [["alice", "data1", "read"]],
        "g": [["alice", "admin"]],
        "g2": [["bob", "user"]]
      }
      """

      adapter = StringAdapter.new(json, format: :json)

      assert adapter.policies["p"] == [["alice", "data1", "read"]]
      assert adapter.grouping_policies["g"] == [["alice", "admin"]]
      assert adapter.grouping_policies["g2"] == [["bob", "user"]]
    end

    test "handles invalid JSON gracefully" do
      adapter = StringAdapter.new("{invalid json", format: :json)

      # Should create adapter with empty policies due to parsing error
      assert adapter.policies == %{}
      assert adapter.grouping_policies == %{}
    end
  end

  describe "lines parsing" do
    test "parses line-based format" do
      adapter = StringAdapter.new(@lines_content, format: :lines)

      expected = [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"],
        ["carol", "data3", "read"]
      ]

      assert adapter.policies["p"] == expected
      assert adapter.grouping_policies == %{}
    end

    test "handles empty lines" do
      lines = """
      alice, data1, read

      bob, data2, write

      """

      adapter = StringAdapter.new(lines, format: :lines)

      assert adapter.policies["p"] == [["alice", "data1", "read"], ["bob", "data2", "write"]]
    end
  end

  describe "custom format" do
    test "uses custom parser function" do
      custom_parser = fn content ->
        # Parse pipe-separated values
        rules =
          content
          |> String.split("\n")
          |> Enum.reject(&(&1 == ""))
          |> Enum.map(fn line ->
            String.split(line, "|") |> Enum.map(&String.trim/1)
          end)

        policies = %{"custom" => rules}
        {:ok, policies, %{}}
      end

      content = "alice|data1|read\nbob|data2|write"
      adapter = StringAdapter.new(content, format: :custom, parser: custom_parser)

      assert adapter.policies["custom"] == [["alice", "data1", "read"], ["bob", "data2", "write"]]
    end

    test "requires parser function for custom format" do
      adapter = StringAdapter.new("test", format: :custom, parse_on_create: false)

      # Should create adapter but parsing will fail without parser
      {:ok, policies, grouping_policies} = StringAdapter.load_policy(adapter, nil)
      assert policies == %{}
      assert grouping_policies == %{}
    end
  end

  describe "rbac_validator/2" do
    test "validates valid RBAC policies" do
      policies = %{"p" => [["alice", "data1", "read"], ["bob", "data2", "write"]]}
      grouping_policies = %{"g" => [["alice", "admin"]]}

      assert {:ok, ^policies, ^grouping_policies} =
               StringAdapter.rbac_validator(policies, grouping_policies)
    end

    test "rejects policies missing required fields" do
      # Missing action field
      policies = %{"p" => [["alice", "data1"], ["bob"]]}
      grouping_policies = %{}

      assert {:error, _} = StringAdapter.rbac_validator(policies, grouping_policies)
    end

    test "rejects invalid grouping policies" do
      policies = %{"p" => [["alice", "data1", "read"]]}
      # Missing role field
      grouping_policies = %{"g" => [["alice"]]}

      assert {:error, _} = StringAdapter.rbac_validator(policies, grouping_policies)
    end

    test "accepts empty grouping policies" do
      policies = %{"p" => [["alice", "data1", "read"]]}
      grouping_policies = %{}

      assert {:ok, ^policies, ^grouping_policies} =
               StringAdapter.rbac_validator(policies, grouping_policies)
    end
  end

  describe "edge cases" do
    test "handles empty content" do
      adapter = StringAdapter.new("")

      assert adapter.policies == %{}
      assert adapter.grouping_policies == %{}
    end

    test "handles whitespace-only content" do
      adapter = StringAdapter.new("   \n  \t  \n  ")

      assert adapter.policies == %{}
      assert adapter.grouping_policies == %{}
    end

    test "handles malformed CSV lines" do
      csv = """
      p, alice, data1, read
      invalid line without commas
      p, bob, data2, write
      ,,,
      p, carol, data3, read
      """

      adapter = StringAdapter.new(csv)

      # Should parse valid lines and ignore invalid ones
      assert length(adapter.policies["p"]) == 3
    end

    test "handles very large content" do
      large_csv =
        Enum.map_join(1..1000, "\n", fn i ->
          "p, user#{i}, data#{rem(i, 10)}, #{if rem(i, 2) == 0, do: "read", else: "write"}"
        end)

      adapter = StringAdapter.new(large_csv)

      assert length(adapter.policies["p"]) == 1000
    end

    test "preserves order in policy rules" do
      csv = """
      p, alice, data1, read
      p, bob, data2, write
      p, carol, data3, read
      """

      adapter = StringAdapter.new(csv)

      # Order is preserved in document order
      expected = [
        ["alice", "data1", "read"],
        ["bob", "data2", "write"],
        ["carol", "data3", "read"]
      ]

      assert adapter.policies["p"] == expected
    end
  end
end
