defmodule ChessWeb.Component.CapturedPieces do
  use ChessWeb, :live_component

  alias ChessWeb.Component.Piece

  @defaults %{
    color: :white,
    captured_pieces: %{
      queen: 0,
      rook: 0,
      bishop: 0,
      knight: 0,
      pawn: 0
    },
    justify_end: false
  }

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, @defaults)}
  end

  @impl Phoenix.LiveComponent
  def update(%{type: type}, socket) do
    captured_pieces = Map.update!(socket.assigns.captured_pieces, type, fn n -> n + 1 end)
    IO.inspect(captured_pieces)
    {:ok, assign(socket, captured_pieces: captured_pieces)}
  end

  @impl Phoenix.LiveComponent
  def update(%{color: color}, socket) do
    {:ok, assign(socket, color: color)}
  end

  def get_pieces(captured_pieces) do
    types = [:queen, :rook, :bishop, :knight, :pawn]

    Enum.reduce(types, [], fn type, acc ->
      n = captured_pieces[type]

      if n == 0 do
        acc
      else
        new_pieces = for _i <- 1..n, into: [], do: type

        acc ++ new_pieces
      end
    end)
  end
end
