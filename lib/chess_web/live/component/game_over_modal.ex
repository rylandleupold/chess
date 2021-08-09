defmodule ChessWeb.Component.GameOverModal do
  use ChessWeb, :live_component

  @defaults %{
    leave_duration: 200,
    show: false,
    title: "Game Over",
    winner: nil,
    reason: nil
  }

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, @defaults)}
  end

  defp get_string_from_atom(atom) do
    case atom do
      :white -> "White"
      :black -> "Black"
      :repetition -> "repetition"
      :material -> "insufficient material"
      :checkmate -> "checkmate"
      _ -> ""
    end
  end
end
