defmodule ChessWeb.Component.Piece do
  use ChessWeb, :live_component

  @defaults %{
    id: nil,
    type: nil,
    color: nil,
    img: nil,
    row: 0,
    col: 0,
    dragging: false
  }

  @impl Phoenix.LiveComponent
  def mount(socket) do
    socket = assign(socket, @defaults)
    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("dragging-change", %{"dragging" => dragging}, socket) do
    {:noreply, assign(socket, dragging: dragging)}
  end

  @impl Phoenix.LiveComponent
  def update(%{id: id, type: type, color: color, row: row, col: col}, socket) do
    socket =
      socket
      |> assign(id: id)
      |> assign(type: type)
      |> assign(color: color)
      |> assign(img: get_img_url(type, color))
      |> assign(row: row)
      |> assign(col: col)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def update(%{id: id, type: type, color: color}, socket) do
    socket =
      socket
      |> assign(id: id)
      |> assign(type: type)
      |> assign(color: color)
      |> assign(img: get_img_url(type, color))

    {:ok, socket}
  end

  defp get_img_url(type, color) do
    "/images/#{type}_#{color}.png"
  end
end
