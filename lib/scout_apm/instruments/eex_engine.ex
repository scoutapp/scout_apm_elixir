defmodule ScoutApm.Instruments.EExEngine do
  @behaviour Phoenix.Template.Engine

  # TODO: Make this name correctly for other template locations
  # Currently it assumes too much about being located under `web/templates`
  def compile(path, name) do
    scout_name = path                  # web/templates/page/index.html.eex
                  |> String.split("/") # [web, templates, page, index.html.eex]
                  |> Enum.drop(2)      # [page, index.html.eex]
                  |> Enum.join("/")    # "page/index.html.eex"

    # Since we only have a single layer of nesting currently, and
    # practically every template will be "under" a layout, don't let the
    # layout become the scope. Once we have deeper nesting, we'll want
    # to allow layouts as scopable layers.
    is_layout = String.starts_with?(scout_name, "layout")

    quoted_template = Phoenix.Template.EExEngine.compile(path, name)

    quote do
      require ScoutApm.Tracing
      ScoutApm.Tracing.timing("EEx", unquote(scout_name), [scopable: !unquote(is_layout)], do: unquote(quoted_template))
    end
  end
end
