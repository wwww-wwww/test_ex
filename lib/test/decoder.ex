defmodule Test.Decoder do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__, hibernate_after: 1_000)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call({:decode, data}, _, state) do
    im =
      JxlEx.Decoder.new!(1)
      |> JxlEx.Decoder.load!(data)
      |> JxlEx.Decoder.next!()

    {:reply, im, state}
  end
end
