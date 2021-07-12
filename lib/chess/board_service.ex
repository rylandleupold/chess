defmodule Chess.BoardService do
  @knight_moves [
    {-2, -1},
    {-2, 1},
    {2, -1},
    {2, 1},
    {-1, -2},
    {-1, 2},
    {1, -2},
    {1, 2}
  ]

  @king_moves [
    {-1, -1},
    {-1, 0},
    {-1, 1},
    {0, -1},
    {0, 1},
    {1, -1},
    {1, 0},
    {1, 1}
  ]

  @rook_lines [{0, -1}, {0, 1}, {1, 0}, {-1, 0}]

  @bishop_lines [{-1, -1}, {-1, 1}, {1, -1}, {1, 1}]

  @default_has_moved %{
    {1, 1} => false,
    {1, 8} => false,
    {8, 1} => false,
    {8, 8} => false,
    {1, 5} => false,
    {8, 5} => false
  }

  def get_initial_board_state() do
    pieces = %{
      {1, 1} => %{type: :rook, color: :white},
      {1, 2} => %{type: :knight, color: :white},
      {1, 3} => %{type: :bishop, color: :white},
      {1, 4} => %{type: :queen, color: :white},
      {1, 5} => %{type: :king, color: :white},
      {1, 6} => %{type: :bishop, color: :white},
      {1, 7} => %{type: :knight, color: :white},
      {1, 8} => %{type: :rook, color: :white},
      {8, 1} => %{type: :rook, color: :black},
      {8, 2} => %{type: :knight, color: :black},
      {8, 3} => %{type: :bishop, color: :black},
      {8, 4} => %{type: :queen, color: :black},
      {8, 5} => %{type: :king, color: :black},
      {8, 6} => %{type: :bishop, color: :black},
      {8, 7} => %{type: :knight, color: :black},
      {8, 8} => %{type: :rook, color: :black}
    }

    pieces =
      Enum.reduce(1..8, pieces, fn c, acc ->
        acc
        |> Map.put({2, c}, %{type: :pawn, color: :white})
        |> Map.put({7, c}, %{type: :pawn, color: :black})
      end)

    {pieces, @default_has_moved}
  end

  def move_pieces(pieces, {r_start, c_start}, {r_dest, c_dest}, en_passant_vulnerable) do
    if pieces[{r_start, c_start}].type == :pawn and is_nil(pieces[{r_dest, c_dest}]) and
         en_passant_vulnerable == {r_start, c_dest} do
      pawn_to_move = pieces[{r_start, c_start}]

      pieces
      |> Map.put({r_dest, c_dest}, pawn_to_move)
      |> Map.delete({r_start, c_start})
      |> Map.delete(en_passant_vulnerable)
    else
      if pieces[{r_start, c_start}].type == :king and abs(c_dest - c_start) > 1 do
        king_to_move = pieces[{r_start, c_start}]

        {c_start_rook, c_dest_rook} = if c_dest - c_start == 2, do: {8, 6}, else: {1, 4}
        rook_to_move = pieces[{r_start, c_start_rook}]

        pieces
        |> Map.put({r_dest, c_dest}, king_to_move)
        |> Map.put({r_start, c_dest_rook}, rook_to_move)
        |> Map.delete({r_start, c_start})
        |> Map.delete({r_start, c_start_rook})
      else
        piece_to_move = pieces[{r_start, c_start}]

        pieces
        |> Map.put({r_dest, c_dest}, piece_to_move)
        |> Map.delete({r_start, c_start})
      end
    end
  end

  def decide_en_passant_vulnerable(pieces, {r_start, c_start}, {r_dest, c_dest}) do
    if pieces[{r_start, c_start}].type == :pawn and abs(r_dest - r_start) > 1 do
      {r_dest, c_dest}
    else
      nil
    end
  end

  def decide_has_moved(pieces, {r_start, c_start}, {_r_dest, c_dest}, has_moved) do
    expected_row = if pieces[{r_start, c_start}].color == :white, do: 1, else: 8

    if pieces[{r_start, c_start}].type == :king and !has_moved[{expected_row, 5}] do
      has_moved = Map.put(has_moved, {r_start, c_start}, true)

      case abs(c_dest - c_start) do
        2 -> Map.put(has_moved, {expected_row, 8}, true)
        3 -> Map.put(has_moved, {expected_row, 1}, true)
        _ -> has_moved
      end
    else
      if pieces[{r_start, c_start}].type == :rook and c_start == 1 and
           !has_moved[{expected_row, 1}] do
        Map.put(has_moved, {expected_row, 1}, true)
      else
        if pieces[{r_start, c_start}].type == :rook and c_start == 8 and
             !has_moved[{expected_row, 8}] do
          Map.put(has_moved, {expected_row, 8}, true)
        else
          has_moved
        end
      end
    end
  end

  def update_kings(pieces, {r_start, c_start}, {r_dest, c_dest}, kings) do
    piece = pieces[{r_start, c_start}]

    if piece.type == :king do
      Map.put(kings, piece.color, {r_dest, c_dest})
    else
      kings
    end
  end

  def valid_moves(
        pieces,
        coords,
        en_passant_vulnerable \\ {-1, -1},
        has_moved \\ @default_has_moved
      ) do
    case Map.get(pieces, coords).type do
      :knight -> valid_knight_moves(pieces, coords)
      :bishop -> valid_bishop_moves(pieces, coords)
      :rook -> valid_rook_moves(pieces, coords)
      :pawn -> valid_pawn_moves(pieces, coords, en_passant_vulnerable)
      :king -> valid_king_moves(pieces, coords, has_moved)
      :queen -> valid_queen_moves(pieces, coords)
    end
  end

  def reject_self_checking_moves(pieces, moves, piece, king, en_passant_vulnerble) do
    Enum.reject(moves, fn move ->
      potential_pieces = move_pieces(pieces, piece, move, en_passant_vulnerble)
      potential_king = if pieces[piece].type == :king, do: move, else: king
      in_check?(potential_pieces, potential_king)
    end)
  end

  defp valid_knight_moves(pieces, {r, c}) do
    valid_moves =
      Enum.reduce(@knight_moves, [], fn {r_offset, c_offset}, acc ->
        r_dest = r + r_offset
        c_dest = c + c_offset

        dest_piece = Map.get(pieces, {r_dest, c_dest})

        if r_dest in 1..8 and c_dest in 1..8 and
             (is_nil(dest_piece) or dest_piece.color != pieces[{r, c}].color) do
          [{r_dest, c_dest} | acc]
        else
          acc
        end
      end)

    valid_moves
  end

  defp valid_bishop_moves(pieces, {r, c}) do
    valid_moves =
      for {r_dir, c_dir} <- @bishop_lines, into: [] do
        Enum.reduce_while(1..8, [], fn i, acc ->
          r_dest = r + i * r_dir
          c_dest = c + i * c_dir

          if r_dest in 1..8 and c_dest in 1..8 do
            case Map.get(pieces, {r_dest, c_dest}) do
              nil ->
                {:cont, [{r_dest, c_dest} | acc]}

              piece ->
                if piece.color != pieces[{r, c}].color do
                  {:halt, [{r_dest, c_dest} | acc]}
                else
                  {:halt, acc}
                end
            end
          else
            {:halt, acc}
          end
        end)
      end

    List.flatten(valid_moves)
  end

  defp valid_rook_moves(pieces, {r, c}) do
    valid_moves =
      for {r_dir, c_dir} <- @rook_lines, into: [] do
        Enum.reduce_while(1..8, [], fn i, acc ->
          r_dest = r + i * r_dir
          c_dest = c + i * c_dir

          if r_dest in 1..8 and c_dest in 1..8 do
            case Map.get(pieces, {r_dest, c_dest}) do
              nil ->
                {:cont, [{r_dest, c_dest} | acc]}

              piece ->
                if piece.color != pieces[{r, c}].color do
                  {:halt, [{r_dest, c_dest} | acc]}
                else
                  {:halt, acc}
                end
            end
          else
            {:halt, acc}
          end
        end)
      end

    List.flatten(valid_moves)
  end

  defp valid_king_moves(pieces, {r, c}, has_moved, check \\ false) do
    valid_moves =
      Enum.reduce(@king_moves, [], fn {r_offset, c_offset}, acc ->
        r_dest = r + r_offset
        c_dest = c + c_offset

        if r_dest in 1..8 and c_dest in 1..8 and
             (is_nil(pieces[{r_dest, c_dest}]) or
                pieces[{r_dest, c_dest}].color != pieces[{r, c}].color) do
          [{r_dest, c_dest} | acc]
        else
          acc
        end
      end)

    rook_row = if pieces[{r, c}].color == :white, do: 1, else: 8
    king = if pieces[{r, c}].color == :white, do: {1, 5}, else: {8, 5}

    valid_moves =
      valid_moves ++
        if !check do
          castling_moves =
            if !has_moved[king] and !has_moved[{rook_row, 1}] and
                 Enum.all?(2..(c - 1), fn col ->
                   is_nil(pieces[{rook_row, col}])
                 end) do
              [{rook_row, 3}]
            else
              []
            end

          castling_moves ++
            if !has_moved[king] and !has_moved[{rook_row, 8}] and
                 Enum.all?(7..(c + 1), fn col ->
                   is_nil(pieces[{rook_row, col}])
                 end) do
              [{rook_row, 7}]
            else
              []
            end
        else
          []
        end

    valid_moves
  end

  defp valid_queen_moves(pieces, {r, c}) do
    valid_rook_moves(pieces, {r, c}) ++ valid_bishop_moves(pieces, {r, c})
  end

  defp valid_pawn_moves(pieces, {r, c}, en_passant_vulnerable) do
    {r_dir, starting_row} =
      case pieces[{r, c}].color do
        :black -> {-1, 7}
        :white -> {1, 2}
      end

    valid_moves =
      Enum.filter([{r + r_dir, c + 1}, {r + r_dir, c - 1}], fn {r_dest, c_dest} ->
        r_dest in 1..8 and c_dest in 1..8 and !is_nil(pieces[{r_dest, c_dest}]) and
          pieces[{r_dest, c_dest}].color != pieces[{r, c}].color
      end)

    valid_moves =
      valid_moves ++
        Enum.filter([{r + r_dir, c + 1}, {r + r_dir, c - 1}], fn {r_dest, c_dest} ->
          r_dest in 1..8 and c_dest in 1..8 and is_nil(pieces[{r_dest, c_dest}]) and
            en_passant_vulnerable == {r, c_dest}
        end)

    valid_moves =
      valid_moves ++
        if is_nil(pieces[{r + r_dir, c}]) do
          [{r + r_dir, c}]
        else
          []
        end

    valid_moves =
      valid_moves ++
        if r == starting_row and is_nil(pieces[{r + r_dir, c}]) and
             is_nil(pieces[{r + 2 * r_dir, c}]) do
          [{r + 2 * r_dir, c}]
        else
          []
        end

    valid_moves
  end

  def in_check?(pieces, {r_king, c_king} = king) do
    attacking_pawn_direction = if pieces[king].color == :white, do: 1, else: -1

    in_check_by_knight =
      Enum.any?(@knight_moves, fn {r_offset, c_offset} ->
        r_dest = r_king + r_offset
        c_dest = c_king + c_offset

        !is_nil(pieces[{r_dest, c_dest}]) and pieces[{r_dest, c_dest}].color != pieces[king].color and
          pieces[{r_dest, c_dest}].type == :knight
      end)

    in_check_by_pawn =
      Enum.any?(
        [
          {r_king + attacking_pawn_direction, c_king - 1},
          {r_king + attacking_pawn_direction, c_king + 1}
        ],
        fn pawn ->
          !is_nil(pieces[pawn]) and pieces[pawn].color != pieces[king].color and
            pieces[pawn].type == :pawn
        end
      )

    in_check_by_other =
      Enum.any?(@rook_lines ++ @bishop_lines, fn {r_dir, c_dir} ->
        Enum.reduce_while(1..8, false, fn i, _acc ->
          r_dest = r_king + i * r_dir
          c_dest = c_king + i * c_dir

          potential_attackers =
            if {r_dir, c_dir} in @rook_lines, do: [:rook, :queen], else: [:bishop, :queen]

          if r_dest in 1..8 and c_dest in 1..8 do
            case Map.get(pieces, {r_dest, c_dest}) do
              nil ->
                {:cont, false}

              piece ->
                if piece.color != pieces[king].color and piece.type in potential_attackers do
                  {:halt, true}
                else
                  {:halt, false}
                end
            end
          else
            {:halt, false}
          end
        end)
      end)

    in_check_by_knight or
      in_check_by_pawn or in_check_by_other
  end

  def valid_moves_for_check(pieces, {_r_king, _c_king} = king, en_passant_vulnerable) do
    valid_king_moves =
      Enum.filter(valid_king_moves(pieces, king, @default_has_moved, true), fn king_dest ->
        potential_pieces = move_pieces(pieces, king, king_dest, en_passant_vulnerable)
        !in_check?(potential_pieces, king_dest)
      end)

    valid_other_moves =
      Enum.reduce(pieces, %{}, fn {piece, piece_info}, acc ->
        if piece_info.color == pieces[king].color and piece_info.type != :king do
          valid_piece_moves =
            Enum.filter(valid_moves(pieces, piece, en_passant_vulnerable), fn piece_dest ->
              potential_pieces = move_pieces(pieces, piece, piece_dest, en_passant_vulnerable)
              !in_check?(potential_pieces, king)
            end)

          Map.put(acc, piece, valid_piece_moves)
        else
          acc
        end
      end)

    valid_other_moves
    |> Map.put(king, valid_king_moves)
    |> remove_empty_entries()
  end

  def handle_queening(pieces, piece, {r_dest, c_dest}) do
    if pieces[piece].type == :pawn and r_dest in [1, 8] do
      {true, {r_dest, c_dest}}
    else
      {false, nil}
    end
  end

  defp remove_empty_entries(map) do
    Enum.reduce(map, %{}, fn {key, lst}, acc ->
      if Enum.empty?(lst) do
        acc
      else
        Map.put(acc, key, lst)
      end
    end)
  end
end
