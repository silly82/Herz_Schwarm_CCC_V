defmodule HerzSchwarm.PeerTracker do
  @moduledoc """
  Tracks bridge status and peer information from bridge events.
  Subscribes to bridge PubSub events and re-broadcasts peer updates.

  Peer-Liste: die Bridge (FW >= 0.2.0) antwortet auf "peers" mit je einer
  "peer"-Zeile und einer abschliessenden "peers"-Zeile; erst dann wird die
  gesammelte Liste uebernommen (keine halben Listen in der UI).
  """

  use GenServer
  require Logger

  @pubsub HerzSchwarm.PubSub
  @bridge_topic "bridge:events"
  @topic "peers:count"

  alias HerzSchwarm.Bridge

  defstruct [:bridge_connected, :peer_count, :last_pong, peers: [], pending: []]

  # --- Public API ---

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  def topic, do: @topic

  @doc """
  "Badge finden": nur das Badge mit dieser MAC blinkt ~10 s gruen (Badge-FW >= 1.3.0,
  Bridge-FW >= 0.2.0). MAC wie in der Peer-Liste, z. B. "A0:F2:62:EC:3B:B4".
  """
  def identify(mac) when is_binary(mac) do
    mac = String.upcase(mac)

    if Regex.match?(~r/\A[0-9A-F]{2}(:[0-9A-F]{2}){5}\z/, mac) do
      Bridge.send_command(%{cmd: "identify", mac: mac})
      :ok
    else
      {:error, :invalid_mac}
    end
  end

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
    # Reset peer state on disconnect — peers are no longer reachable
    state = %{
      state
      | bridge_connected: false,
        peer_count: 0,
        last_pong: nil,
        peers: [],
        pending: []
    }

    broadcast_status(state)
    {:noreply, state}
  end

  def handle_info({:bridge, %{"evt" => "pong"} = pong}, state) do
    # Fix: a pong implies the bridge is alive — also set bridge_connected
    state = %{
      state
      | bridge_connected: true,
        peer_count: pong["peers"] || 0,
        last_pong: pong
    }

    broadcast_status(state)
    {:noreply, state}
  end

  def handle_info({:bridge, %{"evt" => "peer", "mac" => mac} = p}, state) do
    peer = %{mac: mac, rssi: p["rssi"], fw: p["fw"] || "?", age_ms: p["age"]}
    {:noreply, %{state | pending: [peer | state.pending]}}
  end

  def handle_info({:bridge, %{"evt" => "peers"}}, state) do
    peers = Enum.sort_by(state.pending, & &1.mac)
    state = %{state | peers: peers, pending: [], peer_count: length(peers)}
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
      last_pong: state.last_pong,
      peers: state.peers
    }

    Phoenix.PubSub.broadcast(@pubsub, @topic, {:peers, status})
  end
end
