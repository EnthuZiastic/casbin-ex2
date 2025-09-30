defmodule CasbinEx2Test do
  use ExUnit.Case
  doctest CasbinEx2

  test "module loads correctly" do
    # Simple test to verify the module loads
    assert Code.ensure_loaded?(CasbinEx2)
  end
end
