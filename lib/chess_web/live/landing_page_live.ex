defmodule ChessWeb.LandingPageLive do
  use ChessWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
