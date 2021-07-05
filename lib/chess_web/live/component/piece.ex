defmodule ChessWeb.Component.Piece do
  use ChessWeb, :live_component

  @defaults %{
    type: nil,
    color: nil,
    img: nil
  }

  @impl Phoenix.LiveComponent
  def mount(socket) do
    socket = assign(socket, @defaults)
    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def update(%{type: type, color: color}, socket) do
    socket =
      socket
      |> assign(type: type)
      |> assign(color: color)
      |> assign(img: "/images/#{type}_#{color}.png")

    {:ok, socket}
  end
end
