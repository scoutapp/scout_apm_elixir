defmodule ScoutApm.Error.ParameterFilterTest do
  use ExUnit.Case

  alias ScoutApm.Error.ParameterFilter

  describe "filter/1" do
    test "returns nil for nil input" do
      assert ParameterFilter.filter(nil) == nil
    end

    test "filters password keys" do
      params = %{"password" => "secret123", "username" => "john"}
      result = ParameterFilter.filter(params)

      assert result["password"] == "[FILTERED]"
      assert result["username"] == "john"
    end

    test "filters token keys" do
      params = %{"token" => "abc123", "auth_token" => "xyz789", "data" => "value"}
      result = ParameterFilter.filter(params)

      assert result["token"] == "[FILTERED]"
      assert result["auth_token"] == "[FILTERED]"
      assert result["data"] == "value"
    end

    test "filters api_key and apikey" do
      params = %{"api_key" => "key1", "apikey" => "key2", "public_id" => "123"}
      result = ParameterFilter.filter(params)

      assert result["api_key"] == "[FILTERED]"
      assert result["apikey"] == "[FILTERED]"
      assert result["public_id"] == "123"
    end

    test "filters secret and secret_key" do
      params = %{"secret" => "shhh", "secret_key" => "very_secret"}
      result = ParameterFilter.filter(params)

      assert result["secret"] == "[FILTERED]"
      assert result["secret_key"] == "[FILTERED]"
    end

    test "filters credit card related keys" do
      params = %{"card[number]" => "4111111111111111", "name" => "John"}
      result = ParameterFilter.filter(params)

      assert result["card[number]"] == "[FILTERED]"
      assert result["name"] == "John"
    end

    test "filters case-insensitively" do
      params = %{"PASSWORD" => "secret", "Password" => "secret2", "pAssWoRd" => "secret3"}
      result = ParameterFilter.filter(params)

      assert result["PASSWORD"] == "[FILTERED]"
      assert result["Password"] == "[FILTERED]"
      assert result["pAssWoRd"] == "[FILTERED]"
    end

    test "filters nested maps" do
      params = %{
        "user" => %{
          "email" => "test@example.com",
          "password" => "secret"
        },
        "public" => "data"
      }

      result = ParameterFilter.filter(params)

      assert result["user"]["email"] == "test@example.com"
      assert result["user"]["password"] == "[FILTERED]"
      assert result["public"] == "data"
    end

    test "filters lists" do
      params = [%{"password" => "secret"}, %{"name" => "john"}]
      result = ParameterFilter.filter(params)

      assert Enum.at(result, 0)["password"] == "[FILTERED]"
      assert Enum.at(result, 1)["name"] == "john"
    end

    test "handles atom keys" do
      params = %{password: "secret", username: "john"}
      result = ParameterFilter.filter(params)

      assert result[:password] == "[FILTERED]"
      assert result[:username] == "john"
    end

    test "preserves non-sensitive data types" do
      params = %{
        "string" => "hello",
        "number" => 42,
        "float" => 3.14,
        "boolean" => true,
        "atom" => :value
      }

      result = ParameterFilter.filter(params)

      assert result["string"] == "hello"
      assert result["number"] == 42
      assert result["float"] == 3.14
      assert result["boolean"] == true
      assert result["atom"] == "value"
    end
  end
end
