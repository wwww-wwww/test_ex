defmodule Test.Consumer do
  use Nostrum.Consumer

  alias Nostrum.Api

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def do_interaction(
        "jxl_from_tree",
        %{data: %{resolved: %{messages: messages}}} = interaction
      ) do
    case Map.to_list(messages) do
      [{_, %{attachments: attachments, content: content}}] ->
        attachments
        |> Enum.map(fn attachment ->
          HTTPoison.get(attachment["url"])
          |> case do
            {:ok, %HTTPoison.Response{body: body}} ->
              {attachment["filename"], body}

            _ ->
              nil
          end
        end)
        |> Enum.filter(&(&1 != nil))
        |> Kernel.++([{"message", content}])
        |> Enum.filter(&(String.length(elem(&1, 1)) > 0))
        |> Enum.reduce_while(nil, fn {filename, tree}, _ ->
          case JxlEx.tree(tree) do
            {:ok, data} ->
              {:halt, {:ok, filename, data}}

            err ->
              {:cont, inspect(err)}
          end
        end)
        |> case do
          {:ok, filename, data} ->
            GenServer.cast(
              Test.InteractionHandler,
              {:execute,
               fn ->
                 Api.create_followup_message(interaction.token, %{
                   file: %{
                     body: data,
                     name: "#{filename}.jxl"
                   }
                 })
               end}
            )

            %{type: 5}

          nil ->
            %{
              type: 4,
              data: %{content: "This only works on JXL trees!", flags: 64}
            }

          err ->
            %{
              type: 4,
              data: %{content: inspect(err), flags: 64}
            }
        end

      _ ->
        %{
          type: 4,
          data: %{content: "This only works on JXL trees!", flags: 64}
        }
    end
  end

  def do_interaction(
        "Embed",
        %{data: %{resolved: %{messages: messages}}} = interaction
      ) do
    case Map.to_list(messages) do
      [{_, %{attachments: attachments}}] ->
        attachments
        |> Enum.map(&TestWeb.ApiController.map_to_atom(&1).url)
        |> Enum.reduce_while([], fn url, acc ->
          TestWeb.PageController.download(url)
          |> case do
            {:ok, body} ->
              {:cont, acc ++ [{url, body}]}

            _ ->
              {:halt, :err}
          end
        end)
        |> case do
          :err ->
            %{
              type: 4,
              data: %{content: "This only works on JXL files!", flags: 64}
            }

          [] ->
            %{
              type: 4,
              data: %{content: "This only works on JXL files!", flags: 64}
            }

          items ->
            GenServer.cast(Test.InteractionHandler, {:process, items, interaction})

            %{type: 5}
        end

      _ ->
        %{
          type: 4,
          data: %{content: "This only works on JXL files!", flags: 64}
        }
    end
  end

  def do_interaction(name, _interaction) do
    %{
      type: 4,
      data: %{content: "Unhandled interaction #{name}", flags: 64}
    }
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

  def handle_cast({:execute, f}, state) do
    f.()
    {:noreply, state}
  end

  def handle_cast({:process, items, interaction}, state) do
    text =
      items
      |> Enum.map(fn {url, body} ->
        case TestWeb.PageController.decode(body, url, :auto) do
          {:ok, _, "gif", _} ->
            TestWeb.Router.Helpers.page_url(TestWeb.Endpoint, :jxl_auto_gif, q: url)

          {:ok, _, "png", _} ->
            TestWeb.Router.Helpers.page_url(TestWeb.Endpoint, :index)
            |> URI.merge("/#{url}")
            |> URI.to_string()
        end
      end)
      |> Enum.join("\n")

    Api.create_followup_message(interaction.token, %{content: text})

    {:noreply, state}
  end
end
