defmodule ChessWeb.Component.Board do
  use ChessWeb, :live_component

  alias Chess.BoardService

  alias ChessWeb.Component.{Piece, QueeningModal}

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
      |> assign(in_check: false)
      |> assign(checkmate: false)
      |> assign(valid_moves_for_check: %{})
      |> assign(queening: false)
      |> assign(queening_square: nil)

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("selected-queening-piece", %{"type" => type, "color" => color}, socket) do
    type = String.to_atom(type)
    color = String.to_atom(color)

    pieces =
      Map.put(socket.assigns.pieces, socket.assigns.queening_square, %{type: type, color: color})

    socket =
      socket
      |> assign(pieces: pieces)
      |> assign(queening: false)

    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("square-clicked", %{"row" => row, "col" => col}, socket) do
    row = String.to_integer(row)
    col = String.to_integer(col)
    # IO.inspect("#{row}-#{col}")

    if !socket.assigns.queening and !socket.assigns.checkmate do
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

        next_to_move = toggle_next_to_move(socket.assigns.next_to_move)

        in_check =
          BoardService.in_check?(
            pieces,
            kings[next_to_move]
          )

        {queening, queening_square} =
          BoardService.handle_queening(socket.assigns.pieces, socket.assigns.selected, {row, col})

        valid_moves_for_check =
          if in_check do
            BoardService.valid_moves_for_check(
              pieces,
              kings[next_to_move],
              en_passant_vulnerable
            )
          else
            %{}
          end

        checkmate = in_check and Enum.empty?(valid_moves_for_check)

        socket =
          socket
          |> assign(pieces: pieces)
          |> assign(selected: nil)
          |> assign(valid_moves: [])
          |> assign(en_passant_vulnerable: en_passant_vulnerable)
          |> assign(has_moved: has_moved)
          |> assign(kings: kings)
          |> assign(next_to_move: next_to_move)
          |> assign(in_check: in_check)
          |> assign(valid_moves_for_check: valid_moves_for_check)
          |> assign(checkmate: checkmate)
          |> assign(queening: queening)
          |> assign(queening_square: queening_square)

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

          valid_moves =
            if socket.assigns.in_check do
              filter_valid_moves_for_check(
                valid_moves,
                {row, col},
                socket.assigns.valid_moves_for_check
              )
            else
              BoardService.reject_self_checking_moves(
                socket.assigns.pieces,
                valid_moves,
                {row, col},
                socket.assigns.kings[socket.assigns.next_to_move],
                socket.assigns.en_passant_vulnerable
              )
            end

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
    else
      {:noreply, socket}
    end
  end

  defp toggle_next_to_move(color) do
    if color == :white do
      :black
    else
      :white
    end
  end

  defp filter_valid_moves_for_check(valid_moves, piece, valid_moves_for_check) do
    Enum.reduce(valid_moves, [], fn move, acc ->
      if !is_nil(valid_moves_for_check[piece]) and
           Enum.member?(valid_moves_for_check[piece], move) do
        [move | acc]
      else
        acc
      end
    end)
  end
end
