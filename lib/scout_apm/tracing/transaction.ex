defmodule ScoutApm.Tracing.Annotations.Transaction do
  @moduledoc false

  defstruct function_name: nil,
            scout_name: nil,
            # can be :web or :background
            type: :web,
            args: nil,
            guards: nil,
            body: nil

  def new(type, mod, fun, args, guards, body, opts \\ []) do
    %__MODULE__{
      type: type,
      scout_name: opts[:name] || default_scout_name(mod, fun),
      function_name: fun,
      args: args,
      guards: guards,
      body: body
    }
  end

  defp default_scout_name(mod, fun) do
    "#{mod}.#{fun}" |> String.replace_prefix("Elixir.", "")
  end
end
