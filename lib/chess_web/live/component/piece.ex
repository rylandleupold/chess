defmodule ChessWeb.Component.Piece do
  use ChessWeb, :live_component

  @defaults %{
    type: nil,
    color: nil,
    img: nil,
    row: nil,
    col: nil,
    selected: false
  }

  @impl Phoenix.LiveComponent
  def mount(socket) do
    socket = assign(socket, @defaults)
    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def update(%{type: type, color: color, row: row, col: col, selected: selected}, socket) do
    socket =
      socket
      |> assign(type: type)
      |> assign(color: color)
      |> assign(img: "/images/#{type}_#{color}.png")
      |> assign(row: row)
      |> assign(col: col)
      |> assign(selected: selected)

    {:ok, socket}
  end
end
