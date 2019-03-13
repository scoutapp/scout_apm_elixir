Code.load_file("test/support/test_plug_app.ex")

Application.ensure_started(:telemetry)

ExUnit.start()
