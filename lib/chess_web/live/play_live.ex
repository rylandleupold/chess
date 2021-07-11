defmodule ChessWeb.PlayLive do
  use ChessWeb, :live_view

  alias ChessWeb.Component.Board

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
