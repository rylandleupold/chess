defmodule ChessWeb.Component.CapturedPieces do
  use ChessWeb, :live_component

  @defaults %{
    color: :white,
    captured_pieces: %{
      queen: 0,
      rook: 0,
      bishop: 0,
      knight: 0,
      pawn: 0
    }
  }

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, @defaults)}
  end

  @impl Phoenix.LiveComponent
  def update(%{type: type, remove: true}, socket) do
    captured_pieces =
      Map.update(socket.assigns.captured_pieces, type, 0, fn n ->
        n - 1
      end)

    {:ok, assign(socket, captured_pieces: captured_pieces)}
  end

  @impl Phoenix.LiveComponent
  def update(%{type: type}, socket) do
    captured_pieces = Map.update!(socket.assigns.captured_pieces, type, fn n -> n + 1 end)
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
        acc ++ [{type, n}]
      end
    end)
  end
end
