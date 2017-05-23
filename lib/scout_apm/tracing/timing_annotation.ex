defmodule ScoutApm.Tracing.Annotations.Timing do
  @moduledoc false

  defstruct function_name: nil,
            args: nil,
            guards: nil,
            body: nil,
            # The public-facing API calls "type" "category". This is because we also have a "type" for transactions and want to avoid
            # confusion btw them.
            type: nil,
            scout_name: nil

  def new(category, _mod, fun, args, guards, body, opts \\ []) do
    %__MODULE__{
      function_name: fun,
      args: args,
      guards: guards,
      body: body,
      type: category,
      scout_name: opts[:name] || default_scout_name(fun)
    }
  end

  defp default_scout_name(fun) do
    fun
  end
end
