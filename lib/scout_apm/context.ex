defmodule ScoutApm.Context do
  @moduledoc """
  Public API for easily adding Context to a running request.

  These functions must be called from the process handling the request,
  since the correct underlying TrackedRequest is looked up that way.
  """

  @doc """
  Returns :ok on success
  Returns {:error, {:arg, reason}} on failure
  """
  def add(key, value) do
    case ScoutApm.Internal.Context.new(key, value) do
      {:error, _} = err ->
        err

      {:ok, context} ->
        ScoutApm.TrackedRequest.record_context(context)
        :ok
    end
  end
end
