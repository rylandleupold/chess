defmodule ChessWeb.Component.QueeningModal do
  use ChessWeb, :live_component

  alias ChessWeb.Component.Piece

  @defaults %{
    leave_duration: 200,
    background_color: "bg-gray-500"
  }

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, @defaults)}
  end
end
