defmodule ScoutApm.PersistentHistogram do
  @name __MODULE__

  def start_link() do
    Agent.start_link(fn -> %{} end, name: @name)
  end

  # This is synchronous.
  def record_timing(key, timing) do
    Agent.update(
      @name,
      fn state ->
        Map.update(
          state,
          key,
          ApproximateHistogram.new(),
          fn histo -> ApproximateHistogram.add(histo, timing) end
        )
      end
    )
  end

  def keys do
    Agent.get(@name, fn state -> Map.keys(state) end)
  end

  # Returns {:ok, percentile} or :error
  def percentile(key, timing) do
    Agent.get(
      @name,
      fn state ->
        case Map.fetch(state, key) do
          {:ok, histo} ->
            p = ApproximateHistogram.percentile(histo, timing)
            {:ok, p}

          _ ->
            :error
        end
      end
    )
  end

  # Returns {:ok, percentile} or :error
  def percentile_for_value(key, value) do
    Agent.get(
      @name,
      fn state ->
        case Map.fetch(state, key) do
          {:ok, histo} ->
            {:ok, ApproximateHistogram.percentile_for_value(histo, value)}

          _ ->
            :error
        end
      end
    )
  end
end
