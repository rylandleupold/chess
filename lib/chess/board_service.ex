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
    positions = [
      {1, :rook},
      {2, :knight},
      {3, :bishop},
      {4, :queen},
      {5, :king},
      {6, :bishop},
      {7, :knight},
      {8, :rook}
    ]

    pieces =
      Enum.reduce(positions, %{}, fn {col, type}, acc ->
        acc
        |> Map.put({1, col}, %{type: type, color: :white})
        |> Map.put({8, col}, %{type: type, color: :black})
      end)

    pieces =
      Enum.reduce(1..8, pieces, fn col, acc ->
        acc
        |> Map.put({2, col}, %{type: :pawn, color: :white})
        |> Map.put({7, col}, %{type: :pawn, color: :black})
      end)

    {pieces, @default_has_moved}
  end

  def move_pieces(
        pieces,
        {r_start, c_start},
        {r_dest, c_dest},
        en_passant_vulnerable
      ) do
    if type(pieces, {r_start, c_start}) == :pawn and !has_piece?(pieces, {r_dest, c_dest}) and
         en_passant_vulnerable == {r_start, c_dest} do
      pawn_to_move = piece(pieces, {r_start, c_start})

      captured_piece = piece(pieces, en_passant_vulnerable)

      pieces =
        pieces
        |> put_piece(pawn_to_move, {r_dest, c_dest})
        |> remove_piece({r_start, c_start})
        |> remove_piece(en_passant_vulnerable)

      {pieces, captured_piece}
    else
      if type(pieces, {r_start, c_start}) == :king and abs(c_dest - c_start) > 1 do
        king_to_move = piece(pieces, {r_start, c_start})

        {c_start_rook, c_dest_rook} = if c_dest - c_start == 2, do: {8, 6}, else: {1, 4}
        rook_to_move = piece(pieces, {r_start, c_start_rook})

        pieces =
          pieces
          |> put_piece(king_to_move, {r_dest, c_dest})
          |> put_piece(rook_to_move, {r_start, c_dest_rook})
          |> remove_piece({r_start, c_start})
          |> remove_piece({r_start, c_start_rook})

        {pieces, nil}
      else
        piece_to_move = piece(pieces, {r_start, c_start})

        captured_piece = piece(pieces, {r_dest, c_dest})

        pieces =
          pieces
          |> put_piece(piece_to_move, {r_dest, c_dest})
          |> remove_piece({r_start, c_start})

        {pieces, captured_piece}
      end
    end
  end

  def decide_en_passant_vulnerable(pieces, {r_start, c_start}, {r_dest, c_dest}) do
    if type(pieces, {r_start, c_start}) == :pawn and abs(r_dest - r_start) > 1 do
      {r_dest, c_dest}
    else
      nil
    end
  end

  def decide_has_moved(pieces, {r_start, c_start}, {_r_dest, c_dest}, has_moved) do
    expected_row = if is_white?(pieces, {r_start, c_start}), do: 1, else: 8

    if is_king?(pieces, {r_start, c_start}) and !has_moved[{expected_row, 5}] do
      has_moved = Map.put(has_moved, {r_start, c_start}, true)

      case abs(c_dest - c_start) do
        2 -> Map.put(has_moved, {expected_row, 8}, true)
        3 -> Map.put(has_moved, {expected_row, 1}, true)
        _ -> has_moved
      end
    else
      if is_rook?(pieces, {r_start, c_start}) and c_start == 1 and
           !has_moved[{expected_row, 1}] do
        Map.put(has_moved, {expected_row, 1}, true)
      else
        if is_rook?(pieces, {r_start, c_start}) and c_start == 8 and
             !has_moved[{expected_row, 8}] do
          Map.put(has_moved, {expected_row, 8}, true)
        else
          has_moved
        end
      end
    end
  end

  def update_kings(pieces, {r_start, c_start}, {r_dest, c_dest}, kings) do
    piece = piece(pieces, {r_start, c_start})

    if is_king?(pieces, {r_start, c_start}) do
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
    case type(pieces, coords) do
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
      {potential_pieces, _captured_piece} = move_pieces(pieces, piece, move, en_passant_vulnerble)
      potential_king = if is_king?(pieces, piece), do: move, else: king
      in_check?(potential_pieces, potential_king)
    end)
  end

  defp valid_knight_moves(pieces, {r, c}) do
    Enum.reduce(@knight_moves, [], fn {r_offset, c_offset}, acc ->
      r_dest = r + r_offset
      c_dest = c + c_offset

      dest_piece = piece(pieces, {r_dest, c_dest})

      if valid_square?({r_dest, c_dest}) and
           (is_nil(dest_piece) or dest_piece.color != color(pieces, {r, c})) do
        [{r_dest, c_dest} | acc]
      else
        acc
      end
    end)
  end

  defp valid_bishop_moves(pieces, {r, c}) do
    valid_moves =
      for {r_dir, c_dir} <- @bishop_lines, into: [] do
        Enum.reduce_while(1..8, [], fn i, acc ->
          r_dest = r + i * r_dir
          c_dest = c + i * c_dir

          if valid_square?({r_dest, c_dest}) do
            case piece(pieces, {r_dest, c_dest}) do
              nil ->
                {:cont, [{r_dest, c_dest} | acc]}

              piece ->
                if piece.color != color(pieces, {r, c}) do
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

          if valid_square?({r_dest, c_dest}) do
            case piece(pieces, {r_dest, c_dest}) do
              nil ->
                {:cont, [{r_dest, c_dest} | acc]}

              piece ->
                if piece.color != color(pieces, {r, c}) do
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

        if valid_square?({r_dest, c_dest}) and
             (!has_piece?(pieces, {r_dest, c_dest}) or
                !same_color?(pieces, {r_dest, c_dest}, {r, c})) do
          [{r_dest, c_dest} | acc]
        else
          acc
        end
      end)

    rook_row = if is_white?(pieces, {r, c}), do: 1, else: 8
    king = if is_white?(pieces, {r, c}), do: {1, 5}, else: {8, 5}

    valid_moves =
      valid_moves ++
        if !check do
          castling_moves =
            if !has_moved[king] and !has_moved[{rook_row, 1}] and
                 Enum.all?(2..(c - 1), fn col ->
                   !has_piece?(pieces, {rook_row, col})
                 end) do
              [{rook_row, 3}]
            else
              []
            end

          castling_moves ++
            if !has_moved[king] and !has_moved[{rook_row, 8}] and
                 Enum.all?(7..(c + 1), fn col ->
                   !has_piece?(pieces, {rook_row, col})
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
      case color(pieces, {r, c}) do
        :black -> {-1, 7}
        :white -> {1, 2}
      end

    valid_moves =
      Enum.filter([{r + r_dir, c + 1}, {r + r_dir, c - 1}], fn {r_dest, c_dest} ->
        valid_square?({r_dest, c_dest}) and has_piece?(pieces, {r_dest, c_dest}) and
          !same_color?(pieces, {r_dest, c_dest}, {r, c})
      end)

    valid_moves =
      valid_moves ++
        Enum.filter([{r + r_dir, c + 1}, {r + r_dir, c - 1}], fn {r_dest, c_dest} ->
          valid_square?({r_dest, c_dest}) and !has_piece?(pieces, {r_dest, c_dest}) and
            en_passant_vulnerable == {r, c_dest}
        end)

    valid_moves =
      valid_moves ++
        if !has_piece?(pieces, {r + r_dir, c}) do
          [{r + r_dir, c}]
        else
          []
        end

    valid_moves =
      valid_moves ++
        if r == starting_row and !has_piece?(pieces, {r + r_dir, c}) and
             !has_piece?(pieces, {r + 2 * r_dir, c}) do
          [{r + 2 * r_dir, c}]
        else
          []
        end

    valid_moves
  end

  def in_check?(pieces, {r_king, c_king} = king) do
    attacking_pawn_direction = if is_white?(pieces, king), do: 1, else: -1

    in_check_by_knight =
      Enum.any?(@knight_moves, fn {r_offset, c_offset} ->
        r_dest = r_king + r_offset
        c_dest = c_king + c_offset

        has_piece?(pieces, {r_dest, c_dest}) and !same_color?(pieces, {r_dest, c_dest}, king) and
          is_knight?(pieces, {r_dest, c_dest})
      end)

    in_check_by_pawn =
      Enum.any?(
        [
          {r_king + attacking_pawn_direction, c_king - 1},
          {r_king + attacking_pawn_direction, c_king + 1}
        ],
        fn pawn ->
          has_piece?(pieces, pawn) and !same_color?(pieces, pawn, king) and is_pawn?(pieces, pawn)
        end
      )

    in_check_by_king =
      Enum.any?(@king_moves, fn {r_offset, c_offset} ->
        r_dest = r_king + r_offset
        c_dest = c_king + c_offset

        has_piece?(pieces, {r_dest, c_dest}) and !same_color?(pieces, {r_dest, c_dest}, king) and
          is_king?(pieces, {r_dest, c_dest})
      end)

    in_check_by_other =
      Enum.any?(@rook_lines ++ @bishop_lines, fn {r_dir, c_dir} ->
        Enum.reduce_while(1..8, false, fn i, _acc ->
          r_dest = r_king + i * r_dir
          c_dest = c_king + i * c_dir

          potential_attackers =
            if {r_dir, c_dir} in @rook_lines, do: [:rook, :queen], else: [:bishop, :queen]

          if valid_square?({r_dest, c_dest}) do
            case piece(pieces, {r_dest, c_dest}) do
              nil ->
                {:cont, false}

              piece ->
                if piece.color != color(pieces, king) and piece.type in potential_attackers do
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

    in_check_by_knight or in_check_by_king or
      in_check_by_pawn or in_check_by_other
  end

  def game_over?(pieces, in_check, valid_moves_for_check, history, current_board) do
    current_board_bitstring = history[current_board]

    repetitions =
      Enum.reduce(history, 0, fn {_key, board_bitstring}, acc ->
        if board_bitstring == current_board_bitstring, do: acc + 1, else: acc
      end)

    if repetitions >= 3 do
      {true, :repetition}
    else
      if insufficient_material?(pieces) do
        {true, :material}
      else
        if in_check and Enum.empty?(valid_moves_for_check) do
          {true, :checkmate}
        else
          {false, nil}
        end
      end
    end
  end

  def valid_moves_for_check(pieces, {_r_king, _c_king} = king, en_passant_vulnerable) do
    valid_king_moves =
      Enum.filter(valid_king_moves(pieces, king, @default_has_moved, true), fn king_dest ->
        {potential_pieces, _captured_piece} =
          move_pieces(pieces, king, king_dest, en_passant_vulnerable)

        !in_check?(potential_pieces, king_dest)
      end)

    valid_other_moves =
      Enum.reduce(pieces, %{}, fn {piece, _piece_info}, acc ->
        if same_color?(pieces, piece, king) and !is_king?(pieces, piece) do
          valid_piece_moves =
            Enum.filter(valid_moves(pieces, piece, en_passant_vulnerable), fn piece_dest ->
              {potential_pieces, _captured_piece} =
                move_pieces(pieces, piece, piece_dest, en_passant_vulnerable)

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
    if is_pawn?(pieces, piece) and r_dest in [1, 8] do
      {true, {r_dest, c_dest}}
    else
      {false, nil}
    end
  end

  def get_board_bitstring(pieces, has_moved, en_passant_vulnerable) when is_map(pieces) do
    board_bitstring =
      Enum.reduce(Map.keys(pieces), <<>>, fn {r, c}, acc ->
        %{color: color, type: type} = piece(pieces, {r, c})
        row_bits = <<r - 1::3>>
        col_bits = <<c - 1::3>>

        piece_bits =
          case type do
            :pawn -> <<0::3>>
            :knight -> <<1::3>>
            :bishop -> <<2::3>>
            :rook -> <<3::3>>
            :queen -> <<4::3>>
            :king -> <<5::3>>
          end

        color_bit = if color == :white, do: <<1::1>>, else: <<0::1>>

        <<acc::bitstring, row_bits::bits, col_bits::bitstring, piece_bits::bitstring,
          color_bit::bitstring>>
      end)

    en_passant_bitstring =
      case en_passant_vulnerable do
        nil ->
          <<0::6>>

        {r, c} ->
          r_bits = <<r::3>>
          c_bits = <<c::3>>
          <<r_bits::bitstring, c_bits::bitstring>>
      end

    has_moved_bitstring =
      Enum.reduce(has_moved, <<>>, fn {_key, value}, acc ->
        has_moved_bit = if value, do: <<1::1>>, else: <<0::1>>

        <<acc::bitstring, has_moved_bit::bitstring>>
      end)

    <<has_moved_bitstring::bitstring, en_passant_bitstring::bitstring,
      board_bitstring::bitstring>>
  end

  def extract_board_from_bitstring(board_bitstring) do
    {has_moved, en_passant_vulnerable, pieces_bitstring} =
      separate_board_bitstring(board_bitstring)

    pieces =
      for <<r::3, c::3, piece::3, color::1 <- pieces_bitstring>>,
        into: %{},
        do: get_pieces_entry(r, c, piece, color)

    en_passant_vulnerable =
      case en_passant_vulnerable do
        {0, 0} -> nil
        pawn -> pawn
      end

    has_moved =
      Enum.reduce(has_moved, %{}, fn {key, value}, acc ->
        Map.put(acc, key, integer_to_bool(value))
      end)

    {pieces, en_passant_vulnerable, has_moved}
  end

  def get_captured_piece(cur_board_bitstring, prev_board_bitstring, next_to_move) do
    {cur_pieces, _, _} = extract_board_from_bitstring(cur_board_bitstring)
    {prev_pieces, _, _} = extract_board_from_bitstring(prev_board_bitstring)

    captured_pieces =
      (transform_pieces_to_list(prev_pieces) -- transform_pieces_to_list(cur_pieces))
      |> Enum.reject(fn piece ->
        piece.color == next_to_move
      end)

    if Enum.empty?(captured_pieces) do
      nil
    else
      Enum.at(captured_pieces, 0)
    end
  end

  def get_move(cur_board_bitstring, next_board_bitstring, next_to_move) do
    {cur_pieces, _, _} = extract_board_from_bitstring(cur_board_bitstring)
    {next_pieces, _, _} = extract_board_from_bitstring(next_board_bitstring)

    {start_square, _} =
      Enum.find(cur_pieces, fn {square, piece} ->
        piece.color == next_to_move and piece(next_pieces, square) != piece
      end)

    {dest_square, _} =
      Enum.find(next_pieces, fn {square, piece} ->
        piece.color == next_to_move and piece(cur_pieces, square) != piece
      end)

    {start_square, dest_square}
  end

  defp separate_board_bitstring(board_bitstring) do
    <<has_moved_11::1, has_moved_15::1, has_moved_18::1, has_moved_81::1, has_moved_85::1,
      has_moved_88::1, en_passant_r::3, en_passant_c::3, rest::bitstring>> = board_bitstring

    has_moved = %{
      {1, 1} => has_moved_11,
      {1, 8} => has_moved_18,
      {8, 1} => has_moved_81,
      {8, 8} => has_moved_88,
      {1, 5} => has_moved_15,
      {8, 5} => has_moved_85
    }

    {has_moved, {en_passant_r, en_passant_c}, rest}
  end

  defp get_pieces_entry(r, c, type_bits, color_bit) do
    type =
      case(type_bits) do
        0 -> :pawn
        1 -> :knight
        2 -> :bishop
        3 -> :rook
        4 -> :queen
        5 -> :king
        6 -> :pawn
      end

    color = if color_bit == 0, do: :black, else: :white

    {{r + 1, c + 1}, %{color: color, type: type}}
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

  defp integer_to_bool(n) do
    if n == 0, do: false, else: true
  end

  defp insufficient_material?(pieces) do
    {{white_knight, white_bishop}, {black_knight, black_bishop}} =
      Enum.reduce_while(pieces, {{0, 0}, {0, 0}}, fn {_key, %{color: color, type: type}},
                                                     {{white_knight, white_bishop},
                                                      {black_knight, black_bishop}} ->
        case {color, type} do
          {:white, :knight} ->
            {:cont, {{white_knight + 1, white_bishop}, {black_knight, black_bishop}}}

          {:white, :bishop} ->
            {:cont, {{white_knight, white_bishop + 1}, {black_knight, black_bishop}}}

          {:black, :knight} ->
            {:cont, {{white_knight, white_bishop}, {black_knight + 1, black_bishop}}}

          {:black, :bishop} ->
            {:cont, {{white_knight, white_bishop}, {black_knight, black_bishop + 1}}}

          {_, :king} ->
            {:cont, {{white_knight, white_bishop}, {black_knight, black_bishop}}}

          _other ->
            {:halt, {{10, 10}, {10, 10}}}
        end
      end)

    white_count = white_knight + white_bishop
    black_count = black_knight + black_bishop

    (white_count < 2 and black_count < 2) or
      (black_count == 0 and white_count == 2 and white_knight == 2) or
      (white_count == 0 and black_count == 2 and black_knight == 2)
  end

  defp transform_pieces_to_list(pieces) do
    Enum.reduce(Map.to_list(pieces), [], fn {_square, piece}, acc ->
      [piece | acc]
    end)
  end

  defp piece(pieces, {row, col}) do
    pieces[{row, col}]
  end

  defp color(pieces, {row, col}) do
    pieces
    |> Map.get({row, col}, %{})
    |> Map.get(:color)
  end

  defp is_white?(pieces, {row, col}) do
    color(pieces, {row, col}) == :white
  end

  defp type(pieces, {row, col}) do
    pieces
    |> Map.get({row, col}, %{})
    |> Map.get(:type)
  end

  defp is_king?(pieces, {row, col}) do
    type(pieces, {row, col}) == :king
  end

  defp is_rook?(pieces, {row, col}) do
    type(pieces, {row, col}) == :rook
  end

  defp is_knight?(pieces, {row, col}) do
    type(pieces, {row, col}) == :knight
  end

  defp is_pawn?(pieces, {row, col}) do
    type(pieces, {row, col}) == :pawn
  end

  defp valid_square?({row, col}) do
    row in 1..8 and col in 1..8
  end

  defp has_piece?(pieces, {row, col}) do
    case Map.get(pieces, {row, col}, nil) do
      nil -> false
      _ -> true
    end
  end

  defp put_piece(pieces, piece, {row, col}) do
    Map.put(pieces, {row, col}, piece)
  end

  defp remove_piece(pieces, {row, col}) do
    Map.delete(pieces, {row, col})
  end

  defp same_color?(pieces, {row1, col1}, {row2, col2}) do
    color(pieces, {row1, col1}) == color(pieces, {row2, col2})
  end
end
