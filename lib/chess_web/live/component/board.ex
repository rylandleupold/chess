defmodule ChessWeb.Component.Board do
  use ChessWeb, :live_component

  alias Chess.BoardService

  alias ChessWeb.Component.Piece

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {pieces, has_moved} = BoardService.get_initial_board_state()

    socket =
      socket
      |> assign(pieces: pieces)
      |> assign(has_moved: has_moved)
      |> assign(selected: nil)
      |> assign(valid_moves: [])
      |> assign(restricted_moves: [])
      |> assign(en_passant_vulnerable: nil)
      |> assign(next_to_move: :white)
      |> assign(kings: %{white: {1, 5}, black: {8, 5}})

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("square-clicked", %{"row" => row, "col" => col}, socket) do
    row = String.to_integer(row)
    col = String.to_integer(col)
    IO.inspect("#{row}-#{col}")

    if !is_nil(socket.assigns.selected) and {row, col} in socket.assigns.valid_moves do
      # A valid move was chosen for the selected piece
      pieces =
        BoardService.move_pieces(
          socket.assigns.pieces,
          socket.assigns.selected,
          {row, col},
          socket.assigns.en_passant_vulnerable
        )

      en_passant_vulnerable =
        BoardService.decide_en_passant_vulnerable(
          socket.assigns.pieces,
          socket.assigns.selected,
          {row, col}
        )

      has_moved =
        BoardService.decide_has_moved(
          socket.assigns.pieces,
          socket.assigns.selected,
          {row, col},
          socket.assigns.has_moved
        )

      kings =
        BoardService.update_kings(
          socket.assigns.pieces,
          socket.assigns.selected,
          {row, col},
          socket.assigns.kings
        )

      IO.inspect(kings)

      socket =
        socket
        |> assign(pieces: pieces)
        |> assign(selected: nil)
        |> assign(valid_moves: [])
        |> assign(en_passant_vulnerable: en_passant_vulnerable)
        |> assign(has_moved: has_moved)
        |> assign(kings: kings)
        |> assign(next_to_move: toggle_next_to_move(socket.assigns.next_to_move))

      {:noreply, socket}
    else
      if Map.has_key?(socket.assigns.pieces, {row, col}) and
           socket.assigns.selected != {row, col} and
           socket.assigns.next_to_move == socket.assigns.pieces[{row, col}].color do
        # A piece was selected
        valid_moves =
          BoardService.valid_moves(
            socket.assigns.pieces,
            {row, col},
            socket.assigns.en_passant_vulnerable,
            socket.assigns.has_moved
          )

        socket =
          socket
          |> assign(selected: {row, col})
          |> assign(valid_moves: valid_moves)

        {:noreply, socket}
      else
        # An empty square was clicked, or an already selected piece was clicked again
        socket =
          socket
          |> assign(selected: nil)
          |> assign(valid_moves: [])

        {:noreply, socket}
      end
    end
  end

  defp toggle_next_to_move(color) do
    if color == :white do
      :black
    else
      :white
    end
  end

  defp print_pieces(pieces) do
    Enum.each(pieces, fn {row, col} ->
      IO.inspect({row, col, pieces[{row, col}]})
    end)
  end
end
