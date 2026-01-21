defmodule ScoutApm.Logging.ContextExtractorTest do
  use ExUnit.Case

  alias ScoutApm.Logging.ContextExtractor
  alias ScoutApm.TrackedRequest
  alias ScoutApm.Internal.Context

  describe "extract/0" do
    test "returns empty context when no tracked request" do
      # Make sure there's no tracked request
      Process.delete(:scout_apm_request)

      context = ContextExtractor.extract()

      # Should only have service.name if configured
      assert is_list(context)
    end

    test "extracts context from tracked request" do
      # Create a tracked request with some data
      tr = %TrackedRequest{
        id: "test-request-123",
        root_layer: %ScoutApm.Internal.Layer{
          type: "Controller",
          name: "UsersController#show",
          started_at: NaiveDateTime.utc_now(),
          children: []
        },
        layers: [],
        children: [],
        contexts: [],
        collector_fn: nil,
        error: false,
        ignored: false,
        ignoring_depth: 0
      }

      Process.put(:scout_apm_request, tr)

      try do
        context = ContextExtractor.extract()

        # Find the request_id in context
        request_id =
          Enum.find_value(context, fn
            {"scout.request_id", v} -> v
            _ -> nil
          end)

        assert request_id == "test-request-123"

        # Find transaction name
        tx_name =
          Enum.find_value(context, fn
            {"scout.transaction_name", v} -> v
            _ -> nil
          end)

        assert tx_name == "Controller/UsersController#show"
      after
        Process.delete(:scout_apm_request)
      end
    end

    test "extracts custom context tags" do
      tr = %TrackedRequest{
        id: "test-123",
        root_layer: nil,
        layers: [],
        children: [],
        contexts: [
          %Context{type: :extra, key: "feature", value: "checkout"},
          %Context{type: :user, key: "id", value: "user-456"}
        ],
        collector_fn: nil,
        error: false,
        ignored: false,
        ignoring_depth: 0
      }

      Process.put(:scout_apm_request, tr)

      try do
        context = ContextExtractor.extract()

        tag_value =
          Enum.find_value(context, fn
            {"scout.tag.feature", v} -> v
            _ -> nil
          end)

        assert tag_value == "checkout"

        user_value =
          Enum.find_value(context, fn
            {"scout.user.id", v} -> v
            _ -> nil
          end)

        assert user_value == "user-456"
      after
        Process.delete(:scout_apm_request)
      end
    end

    test "includes error flag when request has error" do
      tr = %TrackedRequest{
        id: "test-123",
        root_layer: nil,
        layers: [],
        children: [],
        contexts: [],
        collector_fn: nil,
        error: true,
        ignored: false,
        ignoring_depth: 0
      }

      Process.put(:scout_apm_request, tr)

      try do
        context = ContextExtractor.extract()

        has_error =
          Enum.find_value(context, fn
            {"scout.has_error", v} -> v
            _ -> nil
          end)

        assert has_error == true
      after
        Process.delete(:scout_apm_request)
      end
    end
  end
end
