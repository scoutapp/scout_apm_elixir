defmodule ScoutApm.Instruments.ExsEngineTest do
  use ExUnit.Case

  describe "compile/2" do
    test "can compile ExS templates" do
      result =
        ScoutApm.Instruments.ExsEngine.compile(
          "./test/support/templates/simple.json.exs",
          "simple.json"
        )

      # Verify it returns quoted code (AST)
      assert is_tuple(result)

      # Verify it includes our timing instrumentation
      result_string = Macro.to_string(result)
      assert result_string =~ "ScoutApm.Tracing.timing"
      assert result_string =~ "Exs"
    end
  end
end
