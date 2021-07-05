defmodule ChessWeb.LandingPageLive do
  use ChessWeb, :live_view

  def mount(_params, session, socket) do
    IO.inspect(session)
    {:ok, socket}
  end
end
