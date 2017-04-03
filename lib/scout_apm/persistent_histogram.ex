defmodule ScoutApm.PersistentHistogram do
  def start_link() do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def record_timing(key, timing) do
    pid = Process.whereis(__MODULE__)
    Agent.cast(pid,
      fn state ->
        Map.update(state, key, ApproximateHistogram.new(),
                   fn histo ->
                     ApproximateHistogram.add(histo, timing)
                   end
                 )
      end
    )
  end

  def keys do
    pid = Process.whereis(__MODULE__)
    Agent.get(pid,
      fn state ->
        Map.keys(state)
      end
    )
  end

  # This will error if you ask for a key that doesn't exist.
  def percentile(key, timing) do
    pid = Process.whereis(__MODULE__)
    Agent.get(pid,
      fn state ->
        {:ok, histo} = Map.fetch(state, key)
        ApproximateHistogram.percentile(histo, timing)
      end
    )
  end

  # This will error if you ask for a key that doesn't exist.
  def percentile_for_value(key, value) do
    pid = Process.whereis(__MODULE__)
    Agent.get(pid,
      fn state ->
        {:ok, histo} = Map.fetch(state, key)
        ApproximateHistogram.percentile_for_value(histo, value)
      end
    )
  end
end
