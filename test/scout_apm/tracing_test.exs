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
end
