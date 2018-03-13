defmodule ScoutApm.TracingTest do
  use ExUnit.Case, async: true
  setup do
    :code.delete(TracingAnnotationTestModule)
    :code.purge(TracingAnnotationTestModule)
    :ok
  end

  describe "@transaction" do
    test "automatic name" do
      [{TracingAnnotationTestModule, _}] = Code.compile_string(
      """
      defmodule TracingAnnotationTestModule do
        use ScoutApm.Tracing

        @transaction(type: "background")
        def bar do
          1
        end
      end
      """)
    end

    test "explicit name" do
      [{TracingAnnotationTestModule, _}] = Code.compile_string(
      """
      defmodule TracingAnnotationTestModule do
        use ScoutApm.Tracing

        @transaction(type: "background", name: "It's just a test")
        def bar do
          1
        end
      end
      """)
    end

    test "several function clauses" do
      [{TracingAnnotationTestModule, _}] = Code.compile_string(
      """
      defmodule TracingAnnotationTestModule do
        use ScoutApm.Tracing

        @transaction(type: "background", name: "Uno")
        def bar(1) do
          1
        end

        @transaction(type: "background", name: "Dos")
        def bar(2) do
          2
        end

        @transaction(type: "background", name: "XXX")
        def bar(x) do
          x
        end
      end
      """)

      assert [
        {:transaction, :bar, [1]},
        {:transaction, :bar, [2]},
        {:transaction, :bar, [{:x, _, _}]}
      ] = TracingAnnotationTestModule.__info__(:attributes)[:scout_instrumented]
    end
  end

  describe "@timing" do
    test "automatic name" do
      [{TracingAnnotationTestModule, _}] = Code.compile_string(
      """
      defmodule TracingAnnotationTestModule do
        use ScoutApm.Tracing

        @timing(category: "Test")
        def bar do
          1
        end
      end
      """)
    end

    test "explicit name" do
      [{TracingAnnotationTestModule, _}] = Code.compile_string(
      """
      defmodule TracingAnnotationTestModule do
        use ScoutApm.Tracing

        @timing(category: "Test", name: "Bar")
        def bar do
          1
        end
      end
      """)
    end

    test "several function clauses" do
      [{TracingAnnotationTestModule, _}] = Code.compile_string(
      """
      defmodule TracingAnnotationTestModule do
        use ScoutApm.Tracing

        @timing(category: "Test", name: "barOne")
        def bar(1) do
          1
        end

        @timing(category: "Test", name: "barTwo")
        def bar(2) do
          2
        end

        @timing(category: "Test", name: "barXXX")
        def bar(x) do
          x
        end
      end
      """)

      assert [
        {:timing, :bar, [1]},
        {:timing, :bar, [2]},
        {:timing, :bar, [{:x, _, _}]}
      ] = TracingAnnotationTestModule.__info__(:attributes)[:scout_instrumented]
    end
  end

  describe "transaction block" do
    test "basic usage" do
      [{TracingAnnotationTestModule, _}] = Code.compile_string(
      """
      defmodule TracingAnnotationTestModule do
        use ScoutApm.Tracing

        def bar(1) do
          ScoutApm.Tracing.transaction(:web, "TracingMacro") do
            1
          end
        end
      end
      """)
    end

    # Note this lets you leave off the leading `ScoutApm.Tracing.` bit
    test "usage with import" do
      [{TracingAnnotationTestModule, _}] = Code.compile_string(
      """
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
    test "creates histograms with sensible default name" do
      Code.eval_string(
        """
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
      :timer.sleep(10)
      %{reporting_periods: [pid]} = ScoutApm.Store.get()
      Agent.get(pid, fn(%{histograms: histograms}) ->
        assert Map.has_key?(histograms, "Job/TracingAnnotationTestModule.add_one(integer) when is_integer(integer)")
        assert Map.has_key?(histograms, "Job/TracingAnnotationTestModule.add_one(number) when is_float(number)")
      end)
    end

    test "creates histograms with overridden type and name" do
      Code.eval_string(
        """
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
      :timer.sleep(10)
      %{reporting_periods: [pid]} = ScoutApm.Store.get()
      Agent.get(pid, fn(%{histograms: histograms}) ->
        assert Map.has_key?(histograms, "Controller/test1")
        assert Map.has_key?(histograms, "Job/test2")
      end)
    end
  end
end
