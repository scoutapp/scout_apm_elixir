defmodule ScoutApm.Instruments.EExEngineTest do
  use ExUnit.Case

  describe "compile/2" do
    test "can compile EEx templates" do
      result =
        ScoutApm.Instruments.EExEngine.compile(
          "./test/support/templates/simple.html.eex",
          "simple.html"
        )

      # Verify it returns quoted code (AST)
      assert is_tuple(result)

      # Verify it includes our timing instrumentation
      result_string = Macro.to_string(result)
      assert result_string =~ "ScoutApm.Tracing.timing"
      assert result_string =~ "EEx"
    end
  end
end
