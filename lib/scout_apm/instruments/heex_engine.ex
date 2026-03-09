if Code.ensure_loaded?(Phoenix.LiveView.HTMLEngine) do
  defmodule ScoutApm.Instruments.HEExEngine do
    @moduledoc """
    Scout APM instrumentation for Phoenix HEEx templates (.heex files).

    This engine wraps `Phoenix.LiveView.HTMLEngine` to provide automatic timing
    instrumentation for HEEx template rendering.

    ## Requirements

    - Phoenix LiveView 0.17+
    - Phoenix 1.6+

    ## Configuration

    Add to your `config/config.exs`:

        config :phoenix, :template_engines,
          heex: ScoutApm.Instruments.HEExEngine

    The engine will automatically instrument all `.heex` template files in your application.

    ## Notes

    - This module is only compiled when `Phoenix.LiveView.HTMLEngine` is available
    - Layout templates are marked as non-scopable to prevent them from becoming transaction names
    - Compatible with both Phoenix 1.6 (web/templates) and 1.7+ (lib/my_app_web/controllers) directory structures
    """

    @behaviour Phoenix.Template.Engine

    # TODO: Make this name correctly for other template locations
    # Currently it assumes too much about being located under `lib/{app}_web/templates`
    def compile(path, name) do
      # lib/my_app_web/templates/page/index.html.heex
      # OR lib/my_app_web/controllers/page_html/index.html.heex (Phoenix 1.7+)
      scout_name =
        path
        # Split on forward slashes
        |> String.split("/")
        # Drop the first parts until we get to meaningful template path
        # This handles both old-style (web/templates) and new-style (controllers) paths
        |> drop_path_prefix()
        # "page/index.html.heex" or "page_html/index.html.heex"
        |> Enum.join("/")

      # Since we only have a single layer of nesting currently, and
      # practically every template will be "under" a layout, don't let the
      # layout become the scope. Once we have deeper nesting, we'll want
      # to allow layouts as scopable layers.
      is_layout = String.contains?(scout_name, "layout")

      quoted_template = Phoenix.LiveView.HTMLEngine.compile(path, name)

      quote do
        require ScoutApm.Tracing

        ScoutApm.Tracing.timing("HEEx", unquote(path), [scopable: !unquote(is_layout)],
          do: unquote(quoted_template)
        )
      end
    end

    # Drop path components until we reach the meaningful template path
    # Handles: web/templates/*, lib/my_app_web/templates/*, lib/my_app_web/controllers/*
    defp drop_path_prefix(path_parts) do
      cond do
        # Old style: web/templates/page/index.html.heex
        Enum.member?(path_parts, "templates") ->
          path_parts
          |> Enum.drop_while(&(&1 != "templates"))
          |> Enum.drop(1)

        # New style: lib/my_app_web/controllers/page_html/index.html.heex
        Enum.member?(path_parts, "controllers") ->
          path_parts
          |> Enum.drop_while(&(&1 != "controllers"))
          |> Enum.drop(1)

        # Fallback: just drop first 2 parts (maintains backward compatibility)
        true ->
          Enum.drop(path_parts, 2)
      end
    end
  end
end
