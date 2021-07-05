defmodule ChessWeb.PlayLive do
  use ChessWeb, :live_view

  alias ChessWeb.Component.Board

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    IO.inspect(socket)
    {:ok, socket}
  end
end
