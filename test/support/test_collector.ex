defmodule ScoutApm.TestCollector do
  use GenServer
  @behaviour ScoutApm.Collector

  def start_link() do
    options = []
    GenServer.start_link(__MODULE__, options, name: __MODULE__)
  end

  @impl GenServer
  def init(_) do
    {:ok, %{messages: []}}
  end

  @impl ScoutApm.Collector
  def send(message) when is_map(message) do
    GenServer.cast(__MODULE__, {:send, message})
  end

  def messages do
    GenServer.call(__MODULE__, :messages)
  end

  def clear_messages do
    GenServer.call(__MODULE__, :clear_messages)
  end

  @impl GenServer
  def handle_cast({:send, message}, %{messages: messages} = state) when is_map(message) do
    {:noreply, %{state | messages: [message | messages]}}
  end

  @impl GenServer
  def handle_call(:messages, _from, %{messages: messages} = state) do
    {:reply, Enum.reverse(messages), state}
  end

  def handle_call(:clear_messages, _from, state) do
    {:reply, :ok, %{state | messages: []}}
  end
end
