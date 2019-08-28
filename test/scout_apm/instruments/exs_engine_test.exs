defmodule ScoutApm.Instruments.ExsEngineTest do
  use ExUnit.Case

  defmodule ExsView do
    use Phoenix.Template,
      root: "./test/support/templates",
      template_engines: %{
        exs: ScoutApm.Instruments.ExsEngine
      }

    def render(template, assigns) do
      render_template(template, assigns)
    end
  end

  describe "compile/2" do
    test "can compile" do
      ScoutApm.Instruments.ExsEngine.compile(
        "./test/support/templates/simple.json.exs",
        "simple.json"
      )
    end
  end

  describe "render/2" do
    test "can render" do
      assert ExsView.render("test/support/templates/simple.json", %{})
    end
  end
end
