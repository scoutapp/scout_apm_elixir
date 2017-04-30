defmodule ScoutApm.Instruments.ExsEngine do
  @behaviour Phoenix.Template.Engine

  # TODO: Make this name correctly for other template locations
  def compile(path, name) do
    scout_name = path                  # web/templates/page/index.html.eex
                  |> String.split("/") # [web, templates, page, index.html.eex]
                  |> Enum.drop(2)      # [page, index.html.eex]
                  |> Enum.join("/")    # "page/index.html.eex"

    quoted_template = Phoenix.Template.ExsEngine.compile(path, name)

    quote do
      ScoutApm.Tracing.instrument("Exs", unquote(scout_name), fn -> unquote(quoted_template) end)
    end
  end
end
