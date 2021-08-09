defmodule ChessWeb.PlayLive do
  use ChessWeb, :live_view

  alias ChessWeb.Component.{Board, Modal, Piece}

  @impl Phoenix.LiveView
  def mount(params, _session, socket) do
    IO.inspect(params)
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end
end
