if Code.ensure_loaded?(Phoenix.LiveView.HTMLEngine) do
  defmodule ScoutApm.Instruments.HEExEngineTest do
    use ExUnit.Case

    defmodule HEExView do
      use Phoenix.Template,
        root: "./test/support/templates",
        template_engines: %{
          heex: ScoutApm.Instruments.HEExEngine
        }

      def render(template, assigns) do
        render_template(template, assigns)
      end
    end

    describe "compile/2" do
      test "can compile" do
        ScoutApm.Instruments.HEExEngine.compile(
          "./test/support/templates/simple.html.heex",
          "simple.html"
        )
      end
    end

    describe "render/2" do
      test "can render" do
        assert HEExView.render("test/support/templates/simple.html", %{})
      end
    end
  end
end
