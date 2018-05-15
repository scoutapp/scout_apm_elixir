if Code.ensure_loaded?(PhoenixSlime) do
  defmodule ScoutApm.Instruments.SlimeEngine do
    @behaviour Phoenix.Template.Engine

    # TODO: Make this name correctly for other template locations
    # Currently it assumes too much about being located under `web/templates`
    def compile(path, name) do
      scout_name = path                  # web/templates/page/index.html.slim(e)
                    |> String.split("/") # [web, templates, page, index.html.slim(e)]
                    |> Enum.drop(2)      # [page, index.html.slim(e)]
                    |> Enum.join("/")    # "page/index.html.slim(e)"

      # Since we only have a single layer of nesting currently, and
      # practically every template will be "under" a layout, don't let the
      # layout become the scope. Once we have deeper nesting, we'll want
      # to allow layouts as scopable layers.
      is_layout = String.starts_with?(scout_name, "layout")

      quoted_template = PhoenixSlime.Engine.compile(path, name)

      quote do
        require ScoutApm.Tracing
        ScoutApm.Tracing.timing("Slime", unquote(scout_name), [scopable: !unquote(is_layout)], do: unquote(quoted_template))
      end
    end
  end
end
