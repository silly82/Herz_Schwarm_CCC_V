defmodule HerzSchwarm.PeerTracker do
  @moduledoc """
  Tracks bridge status and peer information from bridge events.
  Subscribes to bridge PubSub events and re-broadcasts peer updates.
  """

  use GenServer
  require Logger

  @pubsub HerzSchwarm.PubSub
  @bridge_topic "bridge:events"
  @topic "peers:count"

  defstruct [:bridge_connected, :peer_count, :last_pong]

  # --- Public API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  def topic, do: @topic

  # --- Callbacks ---

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(@pubsub, @bridge_topic)

    state = %__MODULE__{
      bridge_connected: false,
      peer_count: 0,
      last_pong: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, Map.from_struct(state), state}
  end

  @impl true
  def handle_info({:bridge, :connected}, state) do
    state = %{state | bridge_connected: true}
    broadcast_status(state)
    {:noreply, state}
  end

  def handle_info({:bridge, :disconnected}, state) do
    state = %{state | bridge_connected: false, peer_count: 0}
    broadcast_status(state)
    {:noreply, state}
  end

  def handle_info({:bridge, %{"evt" => "pong"} = pong}, state) do
    state = %{state | peer_count: pong["peers"] || 0, last_pong: pong}
    broadcast_status(state)
    {:noreply, state}
  end

  def handle_info({:bridge, _event}, state) do
    {:noreply, state}
  end

  defp broadcast_status(state) do
    status = %{
      bridge_connected: state.bridge_connected,
      peer_count: state.peer_count,
      last_pong: state.last_pong
    }

    Phoenix.PubSub.broadcast(@pubsub, @topic, {:peers, status})
  end
end
