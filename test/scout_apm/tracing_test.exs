defmodule ScoutApm.TracingTest do
  use ExUnit.Case, async: true

  setup do
    :code.delete(TracingAnnotationTestModule)
    :code.purge(TracingAnnotationTestModule)
    :ok
  end

  describe "transaction block" do
    test "basic usage" do
      [{TracingAnnotationTestModule, _}] =
        Code.compile_string("""
        defmodule TracingAnnotationTestModule do
          import ScoutApm.Tracing

          def bar(1) do
            transaction(:web, "TracingMacro") do
              1
            end
          end
        end
        """)
    end

    test "usage with import" do
      [{TracingAnnotationTestModule, _}] =
        Code.compile_string("""
        defmodule TracingAnnotationTestModule do
          import ScoutApm.Tracing

          def bar(1) do
            transaction(:web, "TracingMacro") do
              1
            end
          end
        end
        """)
    end
  end

  describe "deftransaction" do
    test "creates histograms with sensible defaults" do
      Code.eval_string("""
      defmodule TracingAnnotationTestModule do
        import ScoutApm.Tracing

        deftransaction add_one(integer) when is_integer(integer) do
          integer + 1
        end

        deftransaction add_one(number) when is_float(number) do
          number + 1.0
        end
      end
      """)

      assert TracingAnnotationTestModule.add_one(1) == 2
      assert TracingAnnotationTestModule.add_one(1.0) == 2.0
      :timer.sleep(50)
      %{reporting_periods: [pid]} = ScoutApm.Store.get()

      Agent.get(pid, fn %{histograms: histograms} ->
        assert Map.has_key?(
                 histograms,
                 "Job/TracingAnnotationTestModule.add_one(integer) when is_integer(integer)"
               )

        assert Map.has_key?(
                 histograms,
                 "Job/TracingAnnotationTestModule.add_one(number) when is_float(number)"
               )
      end)
    end

    test "creates histograms with overridden type and name" do
      Code.eval_string("""
      defmodule TracingAnnotationTestModule do
        import ScoutApm.Tracing

        @transaction_opts [name: "test1", type: "web"]
        deftransaction add_one(integer) when is_integer(integer) do
          integer + 1
        end

        @transaction_opts [name: "test2", type: "background"]
        deftransaction add_one(number) when is_float(number) do
          number + 1.0
        end
      end
      """)

      assert TracingAnnotationTestModule.add_one(1) == 2
      assert TracingAnnotationTestModule.add_one(1.0) == 2.0
      :timer.sleep(50)
      %{reporting_periods: [pid]} = ScoutApm.Store.get()

      Agent.get(pid, fn %{histograms: histograms} ->
        assert Map.has_key?(histograms, "Controller/test1")
        assert Map.has_key?(histograms, "Job/test2")
      end)
    end
  end

  describe "deftiming" do
    test "creates histograms with sensible defaults" do
      Code.eval_string("""
      defmodule TracingAnnotationTestModule do
        import ScoutApm.Tracing

        deftiming add_one(integer) when is_integer(integer) do
          integer + 1
        end

        deftiming add_one(number) when is_float(number) do
          number + 1.0
        end
      end
      """)

      assert TracingAnnotationTestModule.add_one(1) == 2
      assert TracingAnnotationTestModule.add_one(1.0) == 2.0
      :timer.sleep(50)
      %{reporting_periods: [pid]} = ScoutApm.Store.get()

      Agent.get(pid, fn %{histograms: histograms} ->
        assert Map.has_key?(
                 histograms,
                 "Custom/TracingAnnotationTestModule.add_one(integer) when is_integer(integer)"
               )

        assert Map.has_key?(
                 histograms,
                 "Custom/TracingAnnotationTestModule.add_one(number) when is_float(number)"
               )
      end)
    end

    test "creates histograms with overridden type and name" do
      Code.eval_string("""
      defmodule TracingAnnotationTestModule do
        import ScoutApm.Tracing

        @timing_opts [name: "add integers", category: "Adding"]
        deftiming add_one(integer) when is_integer(integer) do
          integer + 1
        end

        @transaction_opts [name: "add floats", type: "web"]
        deftransaction add_one(number) when is_float(number) do
          number + 1.0
        end
      end
      """)

      assert TracingAnnotationTestModule.add_one(1) == 2
      assert TracingAnnotationTestModule.add_one(1.0) == 2.0
      :timer.sleep(50)
      %{reporting_periods: [pid]} = ScoutApm.Store.get()

      Agent.get(pid, fn %{histograms: histograms} ->
        assert Map.has_key?(histograms, "Adding/add integers")
        assert Map.has_key?(histograms, "Controller/add floats")
      end)
    end
  end

  test "marks as error" do
    Code.eval_string("""
    defmodule TracingAnnotationTestModule do
      import ScoutApm.Tracing

      deftransaction add_two(number) do
        ScoutApm.TrackedRequest.mark_error()
        number + 2
      end
    end
    """)

    assert TracingAnnotationTestModule.add_two(2) == 4
    assert TracingAnnotationTestModule.add_two(2) == 4
    assert TracingAnnotationTestModule.add_two(2) == 4
    :timer.sleep(70)
    %{reporting_periods: [pid]} = ScoutApm.Store.get()

    Agent.get(pid, fn %{jobs: jobs} ->
      assert %{count: 3, errors: 3} =
               Map.get(jobs, "default/TracingAnnotationTestModule.add_two(number)")
    end)
  end

  test "marks as ignored" do
    Code.eval_string("""
    defmodule TracingAnnotationTestModule do
      import ScoutApm.Tracing

      deftransaction add_three(number) do
        if number > 2 do
          ScoutApm.TrackedRequest.ignore()
        end
        number + 3
      end
    end
    """)

    assert TracingAnnotationTestModule.add_three(2) == 5
    assert TracingAnnotationTestModule.add_three(3) == 6
    :timer.sleep(70)
    %{reporting_periods: [pid]} = ScoutApm.Store.get()

    Agent.get(pid, fn %{jobs: jobs} ->
      assert %{count: 1, errors: 0} =
               Map.get(jobs, "default/TracingAnnotationTestModule.add_three(number)")
    end)
  end
end
