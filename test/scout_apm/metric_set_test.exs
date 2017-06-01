defmodule ScoutApm.MetricSetTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias ScoutApm.MetricSet
  alias ScoutApm.Internal.Metric

  describe "new/0 and new/1" do
    test "creates a MetricSet with default options" do
      set = MetricSet.new()
      assert ScoutApm.MetricSet == set.__struct__
      assert %{
        collapse_all: false,
        compare_desc: false,
        max_types: 100,
      } == set.options
    end

    test "accepts overriding options" do
      set = MetricSet.new(%{max_types: 5})
      assert %{collapse_all: false, compare_desc: false, max_types: 5} == set.options

      set2 = MetricSet.new(%{collapse_all: true, compare_desc: true})
      assert %{collapse_all: true, compare_desc: true, max_types: 100} == set2.options
    end
  end

  describe "absorb" do
    test "adds to metrics" do
      set =
        MetricSet.new
        |> MetricSet.absorb(make_metric("Ecto", "select"))

      assert 1 == Enum.count(MetricSet.to_list(set))
    end

    test "merges if the metric already exists" do
      set =
        MetricSet.new
        |> MetricSet.absorb(make_metric("Ecto", "select"))
        |> MetricSet.absorb(make_metric("Ecto", "select"))
        |> MetricSet.absorb(make_metric("Ecto", "select"))

      assert 1 == Enum.count(MetricSet.to_list(set))
    end

    test "skips metrics when over max_types" do
      set =
        MetricSet.new(%{max_types: 3})
        |> MetricSet.absorb(make_metric("A", "select"))
        |> MetricSet.absorb(make_metric("B", "select"))
        |> MetricSet.absorb(make_metric("C", "select"))
        |> MetricSet.absorb(make_metric("D", "select")) # skipped
        |> MetricSet.absorb(make_metric("E", "select")) # skipped

      assert 3 == Enum.count(MetricSet.to_list(set))
    end
  end

  describe "absorb_all" do
    test "adds to metrics" do
      set =
        MetricSet.new
        |> MetricSet.absorb_all([
             make_metric("Ecto", "select"),
             make_metric("Controller", "foo/bar"),
             make_metric("EEx", "pages/index.html"),
           ])

      assert 3 == Enum.count(MetricSet.to_list(set))
    end
  end

  describe "merge" do
    test "merges the two sets of metrics" do
      set1 = MetricSet.new |> MetricSet.absorb_all([
        make_metric("Ecto", "select"),
        make_metric("Controller", "foo/bar"),
        make_metric("EEx", "pages/index.html"),
      ])

      set2 = MetricSet.new |> MetricSet.absorb_all([
        make_metric("Ecto", "select"),
        make_metric("Ecto", "delete"),
        make_metric("EEx", "pages/layout.html"),
      ])

      merged = MetricSet.merge(set1, set2)

      assert 5 == Enum.count(MetricSet.to_list(merged))
    end
  end

  defp make_metric(type, name, timing \\ 7.5) do
    Metric.from_sampler_value(type, name, timing)
  end
end
