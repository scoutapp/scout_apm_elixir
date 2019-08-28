defmodule ScoutApm.Instruments.EExEngineTest do
  use ExUnit.Case

  defmodule EExView do
    use Phoenix.Template,
      root: "./test/support/templates",
      template_engines: %{
        eex: ScoutApm.Instruments.EExEngine
      }

    def render(template, assigns) do
      render_template(template, assigns)
    end
  end

  describe "compile/2" do
    test "can compile" do
      ScoutApm.Instruments.EExEngine.compile(
        "./test/support/templates/simple.html.eex",
        "simple.html"
      )
    end
  end

  describe "render/2" do
    test "can render" do
      assert EExView.render("test/support/templates/simple.html", %{})
    end
  end
end
