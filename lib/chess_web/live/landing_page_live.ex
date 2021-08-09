defmodule ChessWeb.LandingPageLive do
  use ChessWeb, :live_view

  alias ChessWeb.Component.{Modal, Piece}

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
