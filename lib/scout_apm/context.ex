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
    case ScoutApm.Internal.Context.new(:extra, key, value) do
      {:error, _} = err ->
        err

      {:ok, context} ->
        ScoutApm.TrackedRequest.record_context(context)
        :ok
    end
  end

  @doc """
  A user-specific bit of context. Gets special treatment in the UI, but
  otherwise follows the same rules as the `add` function.
  """
  def add_user(key, value) do
    case ScoutApm.Internal.Context.new(:user, key, value) do
      {:error, _} = err ->
        err

      {:ok, context} ->
        ScoutApm.TrackedRequest.record_context(context)
        :ok
    end
  end
end
