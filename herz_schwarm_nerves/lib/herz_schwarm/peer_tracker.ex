defmodule HerzSchwarm.PeerTracker do
  @moduledoc """
  Tracks bridge status and peer information from bridge events.
  Subscribes to bridge PubSub events and re-broadcasts peer updates.

  Peer-Liste: die Bridge (FW >= 0.2.0) antwortet auf "peers" mit je einer
  "peer"-Zeile und einer abschliessenden "peers"-Zeile; erst dann wird die
  gesammelte Liste uebernommen (keine halben Listen in der UI).

  Monitoring: jedes `peer`-Event geht (mit RSSI, FW und Alter) an
  `HerzSchwarm.Metrics`. Ein Sweep (1 s) vergleicht `Metrics.offline_badges/0`
  mit dem zuletzt bekannten Stand und protokolliert Verschwinden (`:warn`) und
  Wiederkehr (`:info`) im `HerzSchwarm.EventLog`. Waehrend die Bridge getrennt
  ist, wird nicht gesweept (sonst wuerden alle Badges als verschwunden gemeldet).
  """

  use GenServer
  require Logger

  @pubsub HerzSchwarm.PubSub
  @bridge_topic "bridge:events"
  @topic "peers:count"

  @sweep_ms 1_000

  # Obergrenze fuer einen Peer-Batch (mehr Badges gibt es im Schwarm nicht).
  @max_peers 64

  alias HerzSchwarm.{Bridge, EventLog, Metrics}

  defstruct [
    :bridge_connected,
    :peer_count,
    :last_pong,
    peers: [],
    pending: [],
    offline: MapSet.new()
  ]

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
      # Fehler (z. B. Bridge getrennt) werden durchgereicht, damit die UI sie anzeigen kann.
      with {:ok, _seq} <- Bridge.send_command(%{cmd: "identify", mac: mac}) do
        Metrics.increment(:identifies)
        Metrics.increment(:commands_sent)
        EventLog.log(:info, "peer", "Identify gesendet an #{mac}")
        :ok
      end
    else
      {:error, :invalid_mac}
    end
  end

  # --- Callbacks ---

  @impl true
  def init(_opts) do
    Phoenix.PubSub.subscribe(@pubsub, @bridge_topic)
    Process.send_after(self(), :sweep, @sweep_ms)

    state = %__MODULE__{
      bridge_connected: false,
      peer_count: 0,
      last_pong: nil
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state |> Map.from_struct() |> Map.delete(:offline), state}
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
        pending: [],
        offline: MapSet.new()
    }

    broadcast_status(state)
    {:noreply, state}
  end

  def handle_info({:bridge, %{"evt" => "pong"} = pong}, state) do
    # Die Bridge antwortet auf einen Poll zuerst mit pong (status), dann mit den
    # peer-Zeilen. Ein pong markiert also den Beginn eines neuen Batches: ein
    # unvollstaendiger Rest eines frueheren Polls (verlorener "peers"-Marker) wird verworfen.
    # Ein pong impliziert zudem, dass die Bridge lebt: bridge_connected setzen.
    state = %{
      state
      | bridge_connected: true,
        peer_count: pong["peers"] || 0,
        last_pong: pong,
        pending: []
    }

    broadcast_status(state)
    {:noreply, state}
  end

  def handle_info({:bridge, %{"evt" => "peer", "mac" => mac} = p}, state) do
    peer = %{mac: mac, rssi: p["rssi"], fw: p["fw"] || "?", age_ms: p["age"]}
    Metrics.add_rssi(mac, p["rssi"], p["fw"], p["age"])

    # Dedup nach MAC (letzter Wert gewinnt), Batch hart auf @max_peers begrenzt (neueste bleiben).
    pending =
      [peer | Enum.reject(state.pending, &(&1.mac == mac))]
      |> Enum.take(@max_peers)

    {:noreply, %{state | pending: pending}}
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

  def handle_info(:sweep, state) do
    Process.send_after(self(), :sweep, @sweep_ms)
    {:noreply, if(state.bridge_connected, do: sweep_offline(state), else: state)}
  end

  # Offline-Uebergaenge protokollieren (nur Aenderungen gegenueber dem letzten Sweep).
  defp sweep_offline(state) do
    offline = MapSet.new(Metrics.offline_badges())

    for mac <- MapSet.difference(offline, state.offline) do
      EventLog.log(
        :warn,
        "peer",
        "Badge #{mac} nicht mehr erreichbar (> #{Metrics.badge_offline_after_s()} s ohne Signal)"
      )
    end

    for mac <- MapSet.difference(state.offline, offline), Metrics.badge_online?(mac) do
      EventLog.log(:info, "peer", "Badge #{mac} wieder online")
    end

    %{state | offline: offline}
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
