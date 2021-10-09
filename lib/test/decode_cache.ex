defmodule Test.DecodeCacheDecoder do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__, hibernate_after: 1_000)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call({:get, url, f, args}, _, state) do
    r =
      case Test.DecodeCache.get(url) do
        nil -> apply(f, args) |> Test.DecodeCache.put(url)
        data -> data
      end

    {:reply, r, state}
  end

  def get(url, f, args) do
    GenServer.call(__MODULE__, {:get, url, f, args}, 100_000)
  end
end

defmodule Test.DecodeCache do
  use GenServer

  defstruct bucket: nil, routine: false

  @routine_interval 3600
  @cache_duration 3600

  def start_link(_) do
    bucket = :ets.new(:decode_results, [:set, :public])

    GenServer.start_link(__MODULE__, %__MODULE__{bucket: bucket},
      name: __MODULE__,
      hibernate_after: 1_000
    )
  end

  def init(state) do
    {:ok, state}
  end

  def ets_get(table, url) do
    (:ets.member(table, url) and :ets.lookup_element(table, url, 2) |> elem(0)) || nil
  end

  def ets_put(table, url, data) do
    current_time = :os.system_time(:second)
    :ets.insert(table, {url, {data, current_time}})
    data
  end

  def handle_call({:get, url}, _, state) do
    {:reply, ets_get(state.bucket, url), state}
  end

  def handle_call({:put, url, data}, _, state) do
    current_time = :os.system_time(:second)

    state =
      if not state.routine do
        Process.send_after(__MODULE__, :routine, @routine_interval)
        %{state | routine: true}
      else
        state
      end

    {:reply, ets_put(state.bucket, url, data), state}
  end

  def handle_call(:cache_size, _, state) do
    {:reply, :ets.tab2list(state.bucket) |> length, state}
  end

  def handle_info(:routine, state) do
    current_time = :os.system_time(:second)

    :ets.tab2list(state.bucket)
    |> Enum.each(fn {id, {_, time}} ->
      if current_time - time > @cache_duration do
        :ets.delete(state.bucket, id)
      end
    end)

    continue = :ets.tab2list(state.bucket) |> length() > 0

    if continue do
      Process.send_after(__MODULE__, :routine, @routine_interval)
    end

    {:noreply, %{state | routine: continue}}
  end

  def get(url) do
    GenServer.call(__MODULE__, {:get, url})
  end

  def put(data, url) do
    GenServer.call(__MODULE__, {:put, url, data})
    data
  end

  def cache_size() do
    GenServer.call(__MODULE__, :cache_size)
  end
end
