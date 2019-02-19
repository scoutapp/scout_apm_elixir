defmodule ScoutApm.TestTracing do
  import ScoutApm.Tracing

  def transaction_block(_) do
    transaction(:web, "TracingMacro") do
      1
    end
  end

  deftransaction add_one(integer) when is_integer(integer) do
    integer + 1
  end

  deftransaction add_one(number) when is_float(number) do
    number + 1.0
  end

  deftransaction add_one_with_error(number) do
    ScoutApm.TrackedRequest.mark_error()
    number + 1
  end

  @transaction_opts [name: "test1", type: "web"]
  deftransaction add_two(integer) when is_integer(integer) do
    integer + 2
  end

  @transaction_opts [name: "test2", type: "background"]
  deftransaction add_two(number) when is_float(number) do
    number + 2.0
  end

  deftiming add_three(integer) when is_integer(integer) do
    integer + 3
  end

  deftiming add_three(number) when is_float(number) do
    number + 3.0
  end

  @timing_opts [name: "add integers", category: "Adding"]
  deftiming add_four(integer) when is_integer(integer) do
    integer + 4
  end

  @transaction_opts [name: "add floats", type: "web"]
  deftransaction add_four(number) when is_float(number) do
    number + 4.0
  end
end
