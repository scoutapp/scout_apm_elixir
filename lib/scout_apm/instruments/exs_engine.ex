defmodule ScoutApm.Instruments.ExsEngine do
  @behaviour Phoenix.Template.Engine

  # TODO: Make this name correctly for other template locations
  def compile(path, name) do
    # web/templates/page/index.html.eex
    scout_name =
      path
      # [web, templates, page, index.html.eex]
      |> String.split("/")
      # [page, index.html.eex]
      |> Enum.drop(2)
      # "page/index.html.eex"
      |> Enum.join("/")

    quoted_template = Phoenix.Template.ExsEngine.compile(path, name)

    quote do
      require ScoutApm.Tracing
      ScoutApm.Tracing.timing("Exs", unquote(scout_name), do: unquote(quoted_template))
    end
  end
end
