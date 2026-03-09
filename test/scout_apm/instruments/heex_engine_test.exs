if Code.ensure_loaded?(Phoenix.LiveView.HTMLEngine) do
  defmodule ScoutApm.Instruments.HEExEngineTest do
    use ExUnit.Case

    describe "compile/2" do
      test "can compile HEEx templates" do
        result =
          ScoutApm.Instruments.HEExEngine.compile(
            "./test/support/templates/simple.html.heex",
            "simple.html"
          )

        # Verify it returns quoted code (AST)
        assert is_tuple(result)

        # Verify it includes our timing instrumentation
        result_string = Macro.to_string(result)
        assert result_string =~ "ScoutApm.Tracing.timing"
        assert result_string =~ "HEEx"
      end

      test "marks layout templates as non-scopable" do
        # Create a temporary layout template for testing
        layout_path = "./test/support/templates/layout/app.html.heex"
        File.mkdir_p!("./test/support/templates/layout")
        File.write!(layout_path, "<html><body><%= @inner_content %></body></html>")

        result =
          ScoutApm.Instruments.HEExEngine.compile(layout_path, "app.html")

        result_string = Macro.to_string(result)
        # Layout should have scopable: !true (which evaluates to false at runtime)
        assert result_string =~ "scopable: !true"

        # Clean up
        File.rm!(layout_path)
        File.rmdir!("./test/support/templates/layout")
      end
    end
  end
end
