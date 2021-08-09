defmodule ChessWeb.Component.Modal do
  use ChessWeb, :live_component

  @defaults %{
    leave_duration: 200,
    show: false,
    title: "Modal Title"
  }

  @impl Phoenix.LiveComponent
  def mount(socket) do
    {:ok, assign(socket, @defaults)}
  end

  @impl Phoenix.LiveComponent
  def handle_event("modal-closed", _params, socket) do
    send(self(), {__MODULE__, :modal_closed, id: socket.assigns.id})
    {:noreply, socket}
  end
end
