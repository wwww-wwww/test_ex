defmodule TestWeb.TreeLive do
  use TestWeb, :live_view

  def render(assigns) do
    TestWeb.PageView.render("jxl_from_tree.html", assigns)
  end

  def put_tree(socket, tree) do
    case JxlEx.Base.jxl_from_tree(tree) do
      {:ok, data} ->
        socket
        |> assign(:image, "data:image/jxl;base64, " <> Base.encode64(data))
        |> assign(:tree, Base.encode64(:zlib.gzip(tree)))
        |> assign(:error, nil)

      {:error, err} ->
        socket |> assign(:error, err)

      err ->
        socket |> assign(:error, inspect(err))
    end
  end

  def mount(%{"tree" => data}, _session, socket) do
    case Base.decode64(data) do
      {:ok, tree_data} ->
        try do
          tree =
            :zlib.gunzip(tree_data)

          {:ok, put_tree(socket, tree) |> assign(:tree_txt, tree)}
        catch
          err ->
            {:ok, socket |> assign(:error, inspect(err))}
        end

      err ->
        {:ok, socket |> assign(:error, inspect(err))}
    end
  end

  def mount(_params, session, socket) do
    {:ok, socket}
  end

  def handle_params(%{"tree" => data}, _session, socket) do
    case Base.decode64(data) do
      {:ok, tree_data} ->
        try do
          tree =
            :zlib.gunzip(tree_data)

          {:noreply, put_tree(socket, tree) |> assign(:tree_txt, tree)}
        catch
          err ->
            {:noreply, socket |> assign(:error, inspect(err))}
        end

      err ->
        {:noreply, socket |> assign(:error, inspect(err))}
    end
  end

  def handle_params(_params, _session, socket) do
    {:noreply, socket}
  end

  def handle_event("tree", %{"tree" => tree}, socket) do
    {:noreply, put_tree(socket, tree)}
  end

  def handle_event("compressed_tree", %{"data" => data}, socket) do
    case Base.decode64(data) do
      {:ok, tree_data} ->
        try do
          tree = :zlib.gunzip(tree_data)

          {:noreply, put_tree(socket, tree) |> assign(:tree_txt, tree)}
        catch
          err ->
            {:noreply, socket |> assign(:error, inspect(err))}
        end

      err ->
        {:noreply, socket |> assign(:error, inspect(err))}
    end
  end
end
