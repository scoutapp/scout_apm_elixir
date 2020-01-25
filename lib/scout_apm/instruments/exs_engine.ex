defmodule ScoutApm.Instruments.ExsEngine do
  @behaviour Phoenix.Template.Engine

  # TODO: Make this name correctly for other template locations
  def compile(path, name) do
    quoted_template = Phoenix.Template.ExsEngine.compile(path, name)

    quote do
      require ScoutApm.Tracing
      ScoutApm.Tracing.timing("Exs", unquote(path), do: unquote(quoted_template))
    end
  end
end
