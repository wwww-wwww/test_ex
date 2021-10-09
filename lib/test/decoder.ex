defmodule Test.Decoder do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__, hibernate_after: 1_000)
  end

  def init(state) do
    {:ok, state}
  end

  defp decode_all_frames(dec) do
    case dec |> JxlEx.Decoder.next() do
      {:ok, %{animation: %{is_last: 0}} = im} -> [im] ++ decode_all_frames(dec)
      {:ok, im} -> [im]
      _ -> []
    end
  end

  def handle_call({:decode, data}, _, state) do
    dec = JxlEx.Decoder.new!() |> JxlEx.Decoder.load!(data)

    basic_info = JxlEx.Decoder.basic_info!(dec)
    images = decode_all_frames(dec)

    {:reply, {basic_info, images}, state}
  end

  def decode(data) do
    GenServer.call(__MODULE__, {:decode, data}, 100_000)
  end
end
