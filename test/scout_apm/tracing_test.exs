defmodule ScoutApm.TracingTest do
  use ExUnit.Case, async: true
  alias ScoutApm.Tracing

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
      end
      """)
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
      end
      """)
    end
  end
end
