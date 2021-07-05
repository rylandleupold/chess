defmodule ChessWeb.Component.Board do
  use ChessWeb, :live_component

  alias Chess.BoardService

  alias ChessWeb.Component.Piece

  @impl Phoenix.LiveComponent
  def mount(socket) do
    pieces = BoardService.get_initial_board_state()

    socket =
      socket
      |> assign(pieces: pieces)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("square-clicked", %{"row" => row, "col" => col}, socket) do
    IO.inspect("CLICKED")
    {:noreply, socket}
  end
end
