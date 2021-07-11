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

    has_moved = %{
      {1, 1} => false,
      {1, 8} => false,
      {8, 1} => false,
      {8, 8} => false,
      {1, 5} => false,
      {8, 5} => false
    }

    {pieces, has_moved}
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

  def valid_moves(pieces, coords, en_passant_vulnerable, has_moved) do
    case Map.get(pieces, coords).type do
      :knight -> valid_knight_moves(pieces, coords)
      :bishop -> valid_bishop_moves(pieces, coords)
      :rook -> valid_rook_moves(pieces, coords)
      :pawn -> valid_pawn_moves(pieces, coords, en_passant_vulnerable)
      :king -> valid_king_moves(pieces, coords, has_moved)
      :queen -> valid_queen_moves(pieces, coords)
    end
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
      for {r_dir, c_dir} <- [{-1, -1}, {-1, 1}, {1, -1}, {1, 1}], into: [] do
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
      for {r_dir, c_dir} <- [{0, -1}, {0, 1}, {1, 0}, {-1, 0}], into: [] do
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

  defp valid_king_moves(pieces, {r, c}, has_moved) do
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
        if !has_moved[king] and !has_moved[{rook_row, 1}] and
             Enum.all?(2..(c - 1), fn col ->
               is_nil(pieces[{rook_row, col}])
             end) do
          [{rook_row, 3}]
        else
          []
        end

    valid_moves ++
      if !has_moved[king] and !has_moved[{rook_row, 8}] and
           Enum.all?(7..(c + 1), fn col ->
             is_nil(pieces[{rook_row, col}])
           end) do
        [{rook_row, 7}]
      else
        []
      end
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
end
