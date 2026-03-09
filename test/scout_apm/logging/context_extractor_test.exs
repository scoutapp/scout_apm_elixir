defmodule ScoutApm.Logging.ContextExtractorTest do
  use ExUnit.Case

  alias ScoutApm.Logging.ContextExtractor
  alias ScoutApm.TrackedRequest
  alias ScoutApm.Internal.Context

  defp find_attr(context, key) do
    Enum.find_value(context, fn
      {^key, v} -> v
      _ -> nil
    end)
  end

  defp has_attr?(context, key) do
    Enum.any?(context, fn {k, _v} -> k == key end)
  end

  defp make_tr(overrides \\ %{}) do
    defaults = %{
      id: "test-123",
      root_layer: nil,
      layers: [],
      children: [],
      contexts: [],
      collector_fn: nil,
      error: false,
      ignored: false,
      ignoring_depth: 0
    }

    struct(TrackedRequest, Map.merge(defaults, overrides))
  end

  defp make_layer(type, name, opts \\ %{}) do
    defaults = %{
      type: type,
      name: name,
      started_at: ~N[2026-03-06 12:00:00.000000],
      children: []
    }

    struct(ScoutApm.Internal.Layer, Map.merge(defaults, opts))
  end

  describe "extract/0" do
    test "returns empty context when no tracked request" do
      Process.delete(:scout_apm_request)
      context = ContextExtractor.extract()
      assert is_list(context)
    end

    test "extracts context from tracked request" do
      tr =
        make_tr(%{
          id: "test-request-123",
          root_layer: make_layer("Controller", "UsersController#show")
        })

      Process.put(:scout_apm_request, tr)

      try do
        context = ContextExtractor.extract()
        assert find_attr(context, "scout_transaction_id") == "test-request-123"
      after
        Process.delete(:scout_apm_request)
      end
    end
  end

  describe "scout_transaction_id" do
    test "uses scout_transaction_id naming (matching Python/Ruby)" do
      context = ContextExtractor.extract_from_tracked_request(make_tr(%{id: "req-abc"}))
      assert find_attr(context, "scout_transaction_id") == "req-abc"
      refute has_attr?(context, "scout.request_id")
    end
  end

  describe "timing attributes" do
    test "includes scout_start_time from root layer" do
      tr =
        make_tr(%{
          root_layer:
            make_layer("Controller", "Test", %{started_at: ~N[2026-03-06 12:00:00.000000]})
        })

      context = ContextExtractor.extract_from_tracked_request(tr)
      assert find_attr(context, "scout_start_time") == "2026-03-06T12:00:00.000000Z"
    end

    test "includes scout_end_time and scout_duration when root layer is stopped" do
      tr =
        make_tr(%{
          root_layer:
            make_layer("Controller", "Test", %{
              started_at: ~N[2026-03-06 12:00:00.000000],
              stopped_at: ~N[2026-03-06 12:00:01.500000]
            })
        })

      context = ContextExtractor.extract_from_tracked_request(tr)
      assert find_attr(context, "scout_end_time") == "2026-03-06T12:00:01.500000Z"
      assert find_attr(context, "scout_duration") == 1.5
    end

    test "omits end_time and duration when root layer not stopped" do
      tr = make_tr(%{root_layer: make_layer("Controller", "Test")})
      context = ContextExtractor.extract_from_tracked_request(tr)
      assert find_attr(context, "scout_start_time") != nil
      refute has_attr?(context, "scout_end_time")
      refute has_attr?(context, "scout_duration")
    end

    test "omits timing when no root layer" do
      context = ContextExtractor.extract_from_tracked_request(make_tr())
      refute has_attr?(context, "scout_start_time")
    end
  end

  describe "scout_current_operation" do
    test "includes current operation from active layer stack" do
      tr =
        make_tr(%{
          layers: [make_layer("Ecto", "MyApp.Repo")]
        })

      context = ContextExtractor.extract_from_tracked_request(tr)
      assert find_attr(context, "scout_current_operation") == "Ecto/MyApp.Repo"
    end

    test "omits current operation when no active layers" do
      context = ContextExtractor.extract_from_tracked_request(make_tr())
      refute has_attr?(context, "scout_current_operation")
    end
  end

  describe "entrypoint attributes" do
    test "adds controller_entrypoint from active layer" do
      tr = make_tr(%{layers: [make_layer("Controller", "UsersController#show")]})
      context = ContextExtractor.extract_from_tracked_request(tr)
      assert find_attr(context, "controller_entrypoint") == "UsersController#show"
    end

    test "adds job_entrypoint for Job layers" do
      tr = make_tr(%{layers: [make_layer("Job", "MyApp.Workers.EmailWorker")]})
      context = ContextExtractor.extract_from_tracked_request(tr)
      assert find_attr(context, "job_entrypoint") == "MyApp.Workers.EmailWorker"
    end

    test "adds custom_entrypoint for other layer types" do
      tr = make_tr(%{layers: [make_layer("Template", "index.html")]})
      context = ContextExtractor.extract_from_tracked_request(tr)
      assert find_attr(context, "custom_entrypoint") == "index.html"
    end

    test "falls back to root_layer when layers stack is empty" do
      tr = make_tr(%{root_layer: make_layer("Controller", "UsersController#index")})
      context = ContextExtractor.extract_from_tracked_request(tr)
      assert find_attr(context, "controller_entrypoint") == "UsersController#index"
    end

    test "prefers root_layer Controller/Job over active non-Controller layer" do
      tr =
        make_tr(%{
          root_layer: make_layer("Controller", "UsersController#show"),
          layers: [make_layer("Ecto", "MyApp.Repo")]
        })

      context = ContextExtractor.extract_from_tracked_request(tr)
      assert find_attr(context, "controller_entrypoint") == "UsersController#show"
      refute has_attr?(context, "custom_entrypoint")
    end

    test "finds Job entrypoint from layers stack when nested inside Step" do
      # Simulates: Job started, then Step started (Step is current, Job is parent)
      # layers stack is LIFO: [current_step, parent_job]
      tr =
        make_tr(%{
          root_layer: nil,
          layers: [
            make_layer("Step", "PrintToConsole/log_result"),
            make_layer("Job", "MyApp.Workers.EmailWorker")
          ]
        })

      context = ContextExtractor.extract_from_tracked_request(tr)
      assert find_attr(context, "job_entrypoint") == "MyApp.Workers.EmailWorker"
      assert find_attr(context, "scout_current_operation") == "Step/PrintToConsole/log_result"
      refute has_attr?(context, "custom_entrypoint")
    end

    test "finds Controller entrypoint from layers stack when nested inside Ecto" do
      tr =
        make_tr(%{
          root_layer: nil,
          layers: [
            make_layer("Ecto", "MyApp.Repo"),
            make_layer("Controller", "UsersController#show")
          ]
        })

      context = ContextExtractor.extract_from_tracked_request(tr)
      assert find_attr(context, "controller_entrypoint") == "UsersController#show"
      refute has_attr?(context, "custom_entrypoint")
    end

    test "no entrypoint when no layers and no root_layer" do
      context = ContextExtractor.extract_from_tracked_request(make_tr())

      refute has_attr?(context, "controller_entrypoint")
      refute has_attr?(context, "job_entrypoint")
      refute has_attr?(context, "custom_entrypoint")
    end
  end

  describe "custom context - tags" do
    test "uses scout_tag_{key} naming (matching Python)" do
      tr =
        make_tr(%{
          contexts: [%Context{type: :extra, key: "feature", value: "checkout"}]
        })

      context = ContextExtractor.extract_from_tracked_request(tr)
      assert find_attr(context, "scout_tag_feature") == "checkout"
      refute has_attr?(context, "scout.tag.feature")
    end
  end

  describe "custom context - user" do
    test "uses user.{key} naming (matching Ruby)" do
      tr =
        make_tr(%{
          contexts: [%Context{type: :user, key: "id", value: "user-456"}]
        })

      context = ContextExtractor.extract_from_tracked_request(tr)
      assert find_attr(context, "user.id") == "user-456"
      refute has_attr?(context, "scout.user.id")
    end

    test "excludes user ip (matching Ruby, atom key)" do
      tr =
        make_tr(%{
          contexts: [
            %Context{type: :user, key: :ip, value: "127.0.0.1"},
            %Context{type: :user, key: "id", value: "user-456"}
          ]
        })

      context = ContextExtractor.extract_from_tracked_request(tr)
      refute has_attr?(context, "user.ip")
      assert find_attr(context, "user.id") == "user-456"
    end

    test "excludes user ip (matching Ruby)" do
      tr =
        make_tr(%{
          contexts: [
            %Context{type: :user, key: "ip", value: "127.0.0.1"},
            %Context{type: :user, key: "id", value: "user-456"}
          ]
        })

      context = ContextExtractor.extract_from_tracked_request(tr)
      refute has_attr?(context, "user.ip")
      assert find_attr(context, "user.id") == "user-456"
    end
  end

  describe "Logger metadata fallback" do
    test "stash_context stores entrypoint and transaction_id in Logger metadata" do
      # Create a TrackedRequest so stash_context can read the id
      tr = make_tr(%{id: "req-xyz"})
      Process.put(:scout_apm_request, tr)

      ContextExtractor.stash_context("Controller", "UsersController#show")

      assert Logger.metadata()[:scout_entrypoint_key] == "controller_entrypoint"
      assert Logger.metadata()[:scout_entrypoint_name] == "UsersController#show"
      assert Logger.metadata()[:scout_transaction_id] == "req-xyz"
    after
      Process.delete(:scout_apm_request)

      Logger.metadata(
        scout_entrypoint_key: nil,
        scout_entrypoint_name: nil,
        scout_transaction_id: nil
      )
    end

    test "extract/0 uses Logger metadata when no TrackedRequest exists" do
      # Simulate: TrackedRequest existed when stash was called, now it's gone
      tr = make_tr(%{id: "req-abc"})
      Process.put(:scout_apm_request, tr)
      ContextExtractor.stash_context("Controller", "MessageController#create")
      Process.delete(:scout_apm_request)

      context = ContextExtractor.extract()
      assert find_attr(context, "controller_entrypoint") == "MessageController#create"
      assert find_attr(context, "scout_transaction_id") == "req-abc"
    after
      Logger.metadata(
        scout_entrypoint_key: nil,
        scout_entrypoint_name: nil,
        scout_transaction_id: nil
      )
    end

    test "extract/0 uses Logger metadata for Job entrypoint" do
      Process.delete(:scout_apm_request)
      ContextExtractor.stash_context("Job", "Job/EmailWorker")

      context = ContextExtractor.extract()
      assert find_attr(context, "job_entrypoint") == "Job/EmailWorker"
    after
      Logger.metadata(
        scout_entrypoint_key: nil,
        scout_entrypoint_name: nil,
        scout_transaction_id: nil
      )
    end

    test "TrackedRequest takes priority over Logger metadata" do
      ContextExtractor.stash_context("Controller", "OldController#action")

      tr = make_tr(%{layers: [make_layer("Controller", "NewController#action")]})
      Process.put(:scout_apm_request, tr)

      try do
        context = ContextExtractor.extract()
        assert find_attr(context, "controller_entrypoint") == "NewController#action"
      after
        Process.delete(:scout_apm_request)

        Logger.metadata(
          scout_entrypoint_key: nil,
          scout_entrypoint_name: nil,
          scout_transaction_id: nil
        )
      end
    end
  end
end
