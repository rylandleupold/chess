defmodule ChessWeb.Component.Board do
  use ChessWeb, :live_component

  alias Chess.BoardService

  alias ChessWeb.Component.{Piece, QueeningModal, CapturedPieces, UserIcon, GameOverModal}

  @impl Phoenix.LiveComponent
  def mount(socket) do
    socket = assign(socket, get_default_socket())

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("selected-queening-piece", %{"type" => type, "color" => color}, socket) do
    type = String.to_atom(type)
    color = String.to_atom(color)

    pieces =
      Map.put(socket.assigns.pieces, socket.assigns.queening_square, %{type: type, color: color})

    board_bitstring =
      BoardService.get_board_bitstring(
        pieces,
        socket.assigns.has_moved,
        socket.assigns.en_passant_vulnerable
      )

    history = Map.put(socket.assigns.history, socket.assigns.current_board, board_bitstring)

    socket =
      socket
      |> assign(pieces: pieces)
      |> assign(queening: false)
      |> assign(history: history)

    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event("keyup", %{"key" => "ArrowLeft"}, socket) do
    prev_board = socket.assigns.current_board - 1

    if prev_board <= 0 do
      history = socket.assigns.history

      socket =
        socket
        |> assign(get_default_socket())
        |> assign(history: history)

      {:noreply, socket}
    else
      prev_board_bitstring = socket.assigns.history[prev_board]
      cur_board_bitstring = socket.assigns.history[socket.assigns.current_board]

      socket = assign(socket, get_socket_from_board_bitstring(prev_board_bitstring, prev_board))

      captured_piece =
        BoardService.get_captured_piece(
          cur_board_bitstring,
          prev_board_bitstring,
          socket.assigns.next_to_move
        )

      if !is_nil(captured_piece) do
        color = Atom.to_string(captured_piece.color)

        send_update(CapturedPieces,
          id: "captured-#{color}-pieces",
          type: captured_piece.type,
          remove: true
        )
      end

      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveComponent
  def handle_event("keyup", %{"key" => "ArrowRight"}, socket) do
    next_board = socket.assigns.current_board + 1

    case Map.get(socket.assigns.history, next_board) do
      nil ->
        {:noreply, socket}

      next_board_bitstring ->
        current_board_bitstring = socket.assigns.history[socket.assigns.current_board]

        {start_square, dest_square} =
          BoardService.get_move(
            current_board_bitstring,
            next_board_bitstring,
            socket.assigns.next_to_move
          )

        {:noreply, socket} =
          handle_valid_move(dest_square, assign(socket, selected: start_square), true)

        if socket.assigns.queening do
          {next_pieces, _, _} = BoardService.extract_board_from_bitstring(next_board_bitstring)

          socket =
            socket
            |> assign(pieces: next_pieces)
            |> assign(queening: false)
            |> assign(queening_square: nil)

          {:noreply, socket}
        else
          {:noreply, socket}
        end
    end
  end

  @impl Phoenix.LiveComponent
  def handle_event("keyup", _params, socket) do
    {:noreply, socket}
  end

  @impl Phoenix.LiveComponent
  def handle_event(
        "mousedown",
        %{"col" => col, "row" => row},
        socket
      ) do
    col = String.to_integer(col)
    row = String.to_integer(row)

    cond do
      socket.assigns.game_over -> {:noreply, socket}
      socket.assigns.queening -> {:noreply, socket}
      {row, col} in socket.assigns.valid_moves -> handle_valid_move({row, col}, socket)
      Map.has_key?(socket.assigns.pieces, {row, col}) -> select_piece({row, col}, socket)
      true -> clear_selection(socket)
    end
  end

  @impl Phoenix.LiveComponent
  def handle_event(
        "mouseup",
        %{"col" => col, "row" => row},
        socket
      ) do
    col = String.to_integer(col)
    row = String.to_integer(row)

    if is_nil(socket.assigns.selected) do
      {:noreply, socket}
    else
      cond do
        socket.assigns.queening ->
          {:noreply, socket}

        socket.assigns.game_over ->
          {:noreply, socket}

        {row, col} in socket.assigns.valid_moves ->
          handle_valid_move({row, col}, socket)

        {row, col} == socket.assigns.selected ->
          if socket.assigns.selected == socket.assigns.already_selected do
            clear_selection(socket)
          else
            {:noreply, assign(socket, already_selected: socket.assigns.selected)}
          end

        true ->
          {:noreply, assign(socket, already_selected: socket.assigns.selected)}
      end
    end
  end

  defp select_piece({row, col}, socket) do
    piece = Map.get(socket.assigns.pieces, {row, col})

    if piece.color == socket.assigns.next_to_move do
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
      socket =
        socket
        |> assign(selected: {row, col})
        |> assign(valid_moves: [])

      {:noreply, socket}
    end
  end

  defp clear_selection(socket) do
    socket =
      socket
      |> assign(selected: nil)
      |> assign(already_selected: nil)
      |> assign(valid_moves: [])

    {:noreply, socket}
  end

  defp handle_valid_move({row, col}, socket, keep_history \\ false) do
    # A valid move was chosen for the selected piece
    next_to_move = toggle_next_to_move(socket.assigns.next_to_move)

    last_move_squares = [socket.assigns.selected, {row, col}]

    # Update the board
    {pieces, captured_piece} =
      BoardService.move_pieces(
        socket.assigns.pieces,
        socket.assigns.selected,
        {row, col},
        socket.assigns.en_passant_vulnerable
      )

    # Update captured pieces if necessary
    if !is_nil(captured_piece) do
      case captured_piece.color do
        :white ->
          send_update(CapturedPieces, id: "captured-white-pieces", type: captured_piece.type)

        :black ->
          send_update(CapturedPieces, id: "captured-black-pieces", type: captured_piece.type)
      end
    end

    en_passant_vulnerable =
      BoardService.decide_en_passant_vulnerable(
        socket.assigns.pieces,
        socket.assigns.selected,
        {row, col}
      )

    # Update whether the kings or rooks have moved (for castling)
    has_moved =
      BoardService.decide_has_moved(
        socket.assigns.pieces,
        socket.assigns.selected,
        {row, col},
        socket.assigns.has_moved
      )

    # Update king's position, if necessary
    kings =
      BoardService.update_kings(
        socket.assigns.pieces,
        socket.assigns.selected,
        {row, col},
        socket.assigns.kings
      )

    in_check =
      BoardService.in_check?(
        pieces,
        kings[next_to_move]
      )

    # Check for queening
    {queening, queening_square} =
      BoardService.handle_queening(socket.assigns.pieces, socket.assigns.selected, {row, col})

    # If now in check, calculate the valid moves for the next turn
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

    current_board = socket.assigns.current_board + 1

    board_bitstring = BoardService.get_board_bitstring(pieces, has_moved, en_passant_vulnerable)

    history = update_history(socket.assigns.history, current_board, board_bitstring, keep_history)

    {game_over, reason} =
      BoardService.game_over?(pieces, in_check, valid_moves_for_check, history, current_board)

    if game_over do
      assigns = [
        id: "game-over-modal",
        winner: socket.assigns.next_to_move,
        reason: reason,
        show: true
      ]

      send_update(GameOverModal, assigns)
    end

    socket =
      socket
      |> assign(pieces: pieces)
      |> assign(selected: nil)
      |> assign(last_move_squares: last_move_squares)
      |> assign(valid_moves: [])
      |> assign(en_passant_vulnerable: en_passant_vulnerable)
      |> assign(has_moved: has_moved)
      |> assign(kings: kings)
      |> assign(next_to_move: next_to_move)
      |> assign(in_check: in_check)
      |> assign(valid_moves_for_check: valid_moves_for_check)
      |> assign(game_over: game_over)
      |> assign(game_over_reason: reason)
      |> assign(queening: queening)
      |> assign(queening_square: queening_square)
      |> assign(history: history)
      |> assign(current_board: current_board)

    {:noreply, socket}
  end

  defp toggle_next_to_move(color) do
    if color == :white, do: :black, else: :white
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

  defp update_history(history, current_board, board_bitstring, keep_history) do
    if keep_history do
      history
    else
      history
      |> Enum.reduce(%{}, fn {key, value}, acc ->
        if key >= current_board do
          acc
        else
          Map.put(acc, key, value)
        end
      end)
      |> Map.put(current_board, board_bitstring)
    end
  end

  defp get_kings(pieces) do
    Enum.reduce(pieces, %{}, fn {square, %{color: color, type: type}}, acc ->
      case type do
        :king -> Map.put(acc, color, square)
        _ -> acc
      end
    end)
  end

  def get_square_background({row, col}, assigns) do
    case {rem(row, 2) == rem(col, 2), {row, col} in assigns.last_move_squares} do
      {true, true} -> "last-move-light"
      {false, true} -> "last-move-dark"
      {true, false} -> "bg-brown-300"
      {false, false} -> "bg-brown-600"
    end
  end

  def get_square_overlay({row, col}, assigns) do
    cond do
      assigns.selected == {row, col} ->
        "square selected border-4 rounded-sm w-full h-full"

      true ->
        "bg-transparent border-0 w-full h-full"
    end
  end

  def get_circle_overlay({row, col}, assigns) do
    cond do
      {row, col} in assigns.valid_moves ->
        if is_nil(assigns.pieces[{row, col}]) do
          "select-circle rounded-full bg-brown-800 opacity-60"
        else
          "select-circle-piece rounded-full border-6 border-brown-800 opacity-60"
        end

      true ->
        ""
    end
  end

  defp get_default_socket() do
    {pieces, has_moved} = BoardService.get_initial_board_state()

    %{
      pieces: pieces,
      has_moved: has_moved,
      selected: nil,
      already_selected: nil,
      last_move_squares: [],
      valid_moves: [],
      en_passant_vulnerable: nil,
      next_to_move: :white,
      kings: %{white: {1, 5}, black: {8, 5}},
      in_check: false,
      game_over: false,
      game_over_reason: nil,
      valid_moves_for_check: %{},
      queening: false,
      queening_square: nil,
      history: %{0 => BoardService.get_board_bitstring(pieces, has_moved, nil)},
      current_board: 0
    }
  end

  defp get_socket_from_board_bitstring(board_bitstring, board_id) do
    {pieces, en_passant_vulnerable, has_moved} =
      BoardService.extract_board_from_bitstring(board_bitstring)

    kings = get_kings(pieces)

    next_to_move = if rem(board_id, 2) == 1, do: :black, else: :white

    in_check =
      BoardService.in_check?(
        pieces,
        kings[next_to_move]
      )

    # If now in check, calculate the valid moves for the next turn
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

    %{
      pieces: pieces,
      has_moved: has_moved,
      selected: nil,
      already_selected: nil,
      last_move_squares: [],
      valid_moves: [],
      en_passant_vulnerable: en_passant_vulnerable,
      next_to_move: next_to_move,
      kings: kings,
      in_check: in_check,
      game_over: false,
      game_over_reason: nil,
      valid_moves_for_check: valid_moves_for_check,
      queening: false,
      queening_square: nil,
      current_board: board_id
    }
  end
end
