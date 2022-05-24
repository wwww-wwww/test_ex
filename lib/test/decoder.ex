defmodule Test.Decoder do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__, hibernate_after: 1_000)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call({:decode, data}, _, state) do
    {:reply, JxlEx.Decoder.decode!(data, 1), state}
  end

  def decode(data) do
    GenServer.call(__MODULE__, {:decode, data}, 100_000)
  end
end
