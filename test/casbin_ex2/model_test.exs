defmodule CasbinEx2.ModelTest do
  use ExUnit.Case

  alias CasbinEx2.Model

  @moduletag :unit

  describe "load_model/1" do
    test "loads model from file successfully" do
      model_content = """
      [request_definition]
      r = sub, obj, act

      [policy_definition]
      p = sub, obj, act, eft

      [role_definition]
      g = _, _

      [policy_effect]
      e = some(where (p.eft == allow))

      [matchers]
      m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
      """

      model_path = "/tmp/test_model.conf"
      File.write!(model_path, model_content)

      assert {:ok, model} = Model.load_model(model_path)
      assert %Model{} = model

      # Check sections were parsed correctly
      assert model.request_definition["r"] == "sub, obj, act"
      assert model.policy_definition["p"] == "sub, obj, act, eft"
      assert model.role_definition["g"] == "_, _"
      assert model.policy_effect["e"] == "some(where (p.eft == allow))"
      assert model.matchers["m"] == "r.sub == p.sub && r.obj == p.obj && r.act == p.act"

      File.rm(model_path)
    end

    test "returns error for non-existent file" do
      assert {:error, _reason} = Model.load_model("/non/existent/file.conf")
    end
  end

  describe "load_model_from_text/1" do
    test "loads model from text content" do
      model_content = """
      [request_definition]
      r = sub, obj, act

      [policy_definition]
      p = sub, obj, act

      [matchers]
      m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
      """

      assert {:ok, model} = Model.load_model_from_text(model_content)
      assert %Model{} = model
      assert model.request_definition["r"] == "sub, obj, act"
    end

    test "handles comments and empty lines" do
      model_content = """
      # This is a comment
      [request_definition]
      r = sub, obj, act

      # Another comment
      [policy_definition]
      p = sub, obj, act

      # Empty lines should be ignored

      [matchers]
      m = r.sub == p.sub && r.obj == p.obj && r.act == p.act
      """

      assert {:ok, model} = Model.load_model_from_text(model_content)
      assert %Model{} = model
    end
  end

  describe "get_matcher/1" do
    test "returns matcher expression" do
      model = %Model{
        matchers: %{"m" => "r.sub == p.sub && r.obj == p.obj && r.act == p.act"}
      }

      assert Model.get_matcher(model) == "r.sub == p.sub && r.obj == p.obj && r.act == p.act"
    end

    test "returns nil when no matcher" do
      model = %Model{matchers: %{}}
      assert Model.get_matcher(model) == nil
    end
  end

  describe "get_policy_effect/1" do
    test "returns policy effect expression" do
      model = %Model{
        policy_effect: %{"e" => "some(where (p.eft == allow))"}
      }

      assert Model.get_policy_effect(model) == "some(where (p.eft == allow))"
    end
  end

  describe "get_request_tokens/1" do
    test "returns request tokens" do
      model = %Model{
        request_definition: %{"r" => "sub, obj, act"}
      }

      tokens = Model.get_request_tokens(model)
      assert tokens == ["sub", "obj", "act"]
    end

    test "handles empty request definition" do
      model = %Model{request_definition: %{}}
      tokens = Model.get_request_tokens(model)
      assert tokens == []
    end
  end

  describe "get_policy_tokens/2" do
    test "returns policy tokens for given type" do
      model = %Model{
        policy_definition: %{
          "p" => "sub, obj, act",
          "p2" => "sub, obj, act, domain"
        }
      }

      tokens = Model.get_policy_tokens(model, "p")
      assert tokens == ["sub", "obj", "act"]

      tokens2 = Model.get_policy_tokens(model, "p2")
      assert tokens2 == ["sub", "obj", "act", "domain"]
    end
  end

  describe "get_role_tokens/2" do
    test "returns role tokens for given type" do
      model = %Model{
        role_definition: %{
          "g" => "_, _",
          "g2" => "_, _, _"
        }
      }

      tokens = Model.get_role_tokens(model, "g")
      assert tokens == ["_", "_"]

      tokens2 = Model.get_role_tokens(model, "g2")
      assert tokens2 == ["_", "_", "_"]
    end
  end
end