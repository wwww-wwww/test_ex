defmodule Test.Consumer do
  use Nostrum.Consumer

  alias Nostrum.Api
  alias Nostrum.Struct.Interaction

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def do_interaction(
        "Embed",
        %Interaction{data: %{resolved: %{messages: messages}}} = interaction
      ) do
    case Map.to_list(messages) do
      [{_, %{attachments: [%{url: url}]}}] ->
        TestWeb.PageController.download(url)
        |> case do
          {:ok, body} ->
            Api.create_interaction_response(interaction, %{
              type: 5
            })

            JxlEx.Decoder.new!(1)
            |> JxlEx.Decoder.load!(body)
            |> JxlEx.Decoder.basic_info!()
            |> Map.get(:have_animation)
            |> if do
              GenServer.cast(
                Test.InteractionHandler,
                {:decode, body, url, :gif, interaction,
                 %{
                   content:
                     TestWeb.Router.Helpers.page_url(TestWeb.Endpoint, :jxl_auto_gif, q: url)
                 }}
              )
            else
              GenServer.cast(
                Test.InteractionHandler,
                {:decode, body, url, :png, interaction,
                 %{
                   content:
                     TestWeb.Router.Helpers.page_url(TestWeb.Endpoint, :index)
                     |> URI.merge("/#{url}")
                     |> URI.to_string()
                 }}
              )
            end

          _ ->
            Api.create_interaction_response(interaction, %{
              type: 4,
              data: %{content: "This only works on JXL files!", flags: 64}
            })
        end

      _ ->
        Api.create_interaction_response(interaction, %{
          type: 4,
          data: %{content: "This only works on JXL files!", flags: 64}
        })
    end
  end

  def do_interaction(name, interaction) do
    Api.create_interaction_response(interaction, %{
      type: 1,
      data: %{content: "Unhandled interaction #{name}: #{inspect(interaction)}", flags: 64}
    })
  end

  def handle_event({:INTERACTION_CREATE, %Interaction{data: %{name: name}} = interaction, _}) do
    do_interaction(name, interaction)
  end

  def handle_event(_event) do
    :noop
  end
end

defmodule Test.InteractionHandler do
  use GenServer
  alias Nostrum.Api

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__, hibernate_after: 1_000)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_cast({:decode, body, url, type, interaction, data}, state) do
    TestWeb.PageController.decode(body, url, type)

    Api.create_followup_message(interaction.token, data)

    {:noreply, state}
  end
end
