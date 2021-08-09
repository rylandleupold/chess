defmodule ChessWeb.Component.UserIcon do
  use ChessWeb, :live_component

  @defaults %{
    name: "User",
    rating: nil,
    image: nil
  }

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, @defaults)}
  end

  @impl Phoenix.LiveComponent
  def update(%{name: name, rating: rating, image: image}, socket) do
    socket =
      socket
      |> assign(name: name)
      |> assign(rating: rating)
      |> assign(image: image)

    {:ok, socket}
  end
end
