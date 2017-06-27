defmodule ScoutApm.Tracing.Annotations do
  @moduledoc false
  # This modules encapsulates the metaprogramming bits to track transactions and instrument functions.
  # See `ScoutApm.Tracing`, the public-facing API, for usage.

  import ScoutApm.Tracing

  # Whenever a function is defined, look for a +@transaction+ module attribute. We then delete
  # these attributes as we find them - this is what associates a module attribute with a function.
  #
  # There's a good amount of almost-duplicate code handling the annotations and adding the appropiate
  # timing/transaction wrapper functions.
  def on_definition(env, _kind, fun, args, guards, body) do
    mod = env.module

    collect_transactions(mod,fun,args,guards,body)
    collect_timings(mod,fun,args,guards,body)
  end

  defmacro before_compile(env) do
    mod = env.module
    transactions = instrument_transactions(mod)
    timings = instrument_timings(mod)
    quote do
      unquote_splicing(transactions)
      unquote_splicing(timings)
    end
  end

  defp collect_transactions(mod,fun,args,guards,body) do
    transaction_info = Module.get_attribute(mod, :transaction)
    if transaction_info do
      # These are accumulated into a list. We'll iterate over them in `before_compile/` and
      # add the transaction instrumentation.
      Module.put_attribute(mod, :scout_transactions,
                             ScoutApm.Tracing.Annotations.Transaction.new(
                              transaction_info[:type],
                              mod,
                              fun,
                              args,
                              guards,
                              body,
                              name: transaction_info[:name]
                             )
                          )
      Module.delete_attribute(mod, :transaction)
    end
  end

  defp collect_timings(mod,fun,args,guards,body) do
    timing_info = Module.get_attribute(mod, :timing)
    if timing_info do
      # These are accumulated into a list. We'll iterate over them in `before_compile/` and
      # add the timing instrumentation.
      Module.put_attribute(mod, :scout_timings,
                             ScoutApm.Tracing.Annotations.Timing.new(
                              timing_info[:category],
                              mod,
                              fun,
                              args,
                              guards,
                              body,
                              name: timing_info[:name]
                             )
                          )

      Module.delete_attribute(mod, :timing)
    end
  end

  ### Transaction Instrumentation ###

  defp instrument_transactions(mod) do
    mod
    |> Module.get_attribute(:scout_transactions)
    |> Enum.reverse
    |> Enum.map(
      fn(%ScoutApm.Tracing.Annotations.Transaction{} = transaction_data) ->
        override = {transaction_data.function_name, length(transaction_data.args)}
        if !Module.overridable?(mod, override) do
          Module.make_overridable(mod, [override])
        end

        # Records the fact we overrode this
        attrs = Module.get_attribute(mod, :scout_instrumented) || []
        new_attrs = [{:transaction, transaction_data.function_name, transaction_data.args}] ++ Enum.reverse(attrs)
        Module.put_attribute(mod, :scout_instrumented, Enum.reverse(new_attrs))

        body = build_transaction_body(transaction_data)
        if length(transaction_data.guards) > 0 do
          quote do
            def unquote(transaction_data.function_name)(unquote_splicing(transaction_data.args)) when unquote_splicing(transaction_data.guards) do
              unquote(body)
            end
          end
        else
          quote do
            def unquote(transaction_data.function_name)(unquote_splicing(transaction_data.args))  do
              unquote(body)
            end
          end
        end

      end)
  end

  defp build_transaction_body(%ScoutApm.Tracing.Annotations.Transaction{} = transaction_data) do
    quote do
      transaction(unquote(transaction_data.type), unquote(transaction_data.scout_name)) do
        unquote(transaction_data.body)
      end
    end
  end

  ### Timing Instrumentation ###

  defp instrument_timings(mod) do
    Module.get_attribute(mod, :scout_timings)
      |> Enum.reverse
      |> Enum.map(
        fn(%ScoutApm.Tracing.Annotations.Timing{} = timing_data) ->
          override = {timing_data.function_name, length(timing_data.args)}
          if !Module.overridable?(mod, override) do
            Module.make_overridable(mod, [override])
          end

          # Records the fact we overrode this
          attrs = Module.get_attribute(mod, :scout_instrumented) || []
          new_attrs = [{:timing, timing_data.function_name, timing_data.args}] ++ Enum.reverse(attrs)
          Module.put_attribute(mod, :scout_instrumented, Enum.reverse(new_attrs))


          body = build_timing_body(timing_data)
          if length(timing_data.guards) > 0 do
            quote do
              def unquote(timing_data.function_name)(unquote_splicing(timing_data.args)) when unquote_splicing(timing_data.guards) do
                unquote(body)
              end
            end
          else
            quote do
              def unquote(timing_data.function_name)(unquote_splicing(timing_data.args))  do
                unquote(body)
              end
            end
          end

        end)
  end

  defp build_timing_body(%ScoutApm.Tracing.Annotations.Timing{} = timing_data) do
    quote do
      timing(unquote(timing_data.type), unquote(timing_data.scout_name)) do
        unquote(timing_data.body)
      end
    end
  end
end
