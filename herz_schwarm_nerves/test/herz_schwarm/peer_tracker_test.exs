defmodule HerzSchwarm.PeerTrackerMonitoringTest do
  use ExUnit.Case, async: false

  alias HerzSchwarm.{Bridge, EventLog, Metrics, PeerTracker}

  @mac "A0:F2:62:EC:3B:B4"

  setup do
    send(PeerTracker, {:bridge, :disconnected})
    send(PeerTracker, {:bridge, :connected})
    PeerTracker.get_status()
    Metrics.reset()
    EventLog.clear()
    :ok
  end

  defp peer(mac, rssi, age),
    do:
      send(
        PeerTracker,
        {:bridge, %{"evt" => "peer", "mac" => mac, "rssi" => rssi, "fw" => "1.3.0", "age" => age}}
      )

  defp sweep do
    send(PeerTracker, :sweep)
    PeerTracker.get_status()
  end

  defp messages, do: Enum.map(EventLog.entries(), &{&1.level, &1.message})

  test "peer-Events fuettern Metrics (RSSI, FW)" do
    peer(@mac, -70, 100)
    peer(@mac, -74, 100)
    PeerTracker.get_status()

    b = Metrics.snapshot().badges[@mac]
    assert b.samples == [-70, -74]
    assert b.fw == "1.3.0"
    assert b.online
  end

  test "Peer-Liste wird weiterhin erst nach dem peers-Marker uebernommen" do
    peer(@mac, -70, 100)
    assert PeerTracker.get_status().peers == []
    send(PeerTracker, {:bridge, %{"evt" => "peers"}})
    assert [%{mac: @mac, rssi: -70, fw: "1.3.0", age_ms: 100}] = PeerTracker.get_status().peers
  end

  test "get_status enthaelt keine internen Monitoring-Felder" do
    refute Map.has_key?(PeerTracker.get_status(), :offline)
  end

  test "Verschwinden wird einmal als :warn, Wiederkehr als :info protokolliert" do
    peer(@mac, -70, 60_000)
    sweep()
    sweep()

    assert [{:warn, msg}] = messages()
    assert msg =~ @mac and msg =~ "nicht mehr erreichbar"

    peer(@mac, -66, 0)
    sweep()

    assert {:info, "Badge #{@mac} wieder online"} in messages()
    assert length(messages()) == 2

    # stabil online -> kein weiterer Eintrag
    sweep()
    assert length(messages()) == 2
  end

  test "bei getrennter Bridge wird nicht gesweept" do
    peer(@mac, -70, 60_000)
    send(PeerTracker, {:bridge, :disconnected})
    sweep()
    assert messages() == []
  end

  defp mac_n(n), do: "A0:F2:62:EC:#{String.pad_leading(Integer.to_string(n, 16), 2, "0")}:00"

  defp pong, do: send(PeerTracker, {:bridge, %{"evt" => "pong", "peers" => 0}})
  defp peers_marker, do: send(PeerTracker, {:bridge, %{"evt" => "peers"}})

  test "verlorener peers-Marker: Batch bleibt auf 64 begrenzt, neueste bleiben" do
    for n <- 1..100, do: peer(mac_n(n), -70, 100)
    PeerTracker.get_status()

    peers_marker()
    peers = PeerTracker.get_status().peers

    assert length(peers) == 64
    macs = Enum.map(peers, & &1.mac)
    assert mac_n(100) in macs
    refute mac_n(1) in macs
  end

  test "doppelte MACs im Batch werden dedupliziert (letzter Wert gewinnt)" do
    peer(@mac, -70, 100)
    peer(@mac, -80, 200)
    peer(@mac, -90, 300)
    peers_marker()

    assert [%{mac: @mac, rssi: -90, age_ms: 300}] = PeerTracker.get_status().peers
  end

  test "pong beginnt einen neuen Batch: Rest eines frueheren Polls wird verworfen" do
    peer(mac_n(1), -70, 100)
    pong()
    peer(mac_n(2), -70, 100)
    peers_marker()

    assert [%{mac: mac}] = PeerTracker.get_status().peers
    assert mac == mac_n(2)
  end

  test "identify bei getrennter Bridge gibt den Fehler zurueck" do
    orig = :sys.get_state(Bridge)
    :sys.replace_state(Bridge, fn st -> %{st | connected: false} end)
    on_exit(fn -> :sys.replace_state(Bridge, fn st -> %{st | connected: orig.connected} end) end)

    assert {:error, :not_connected} = PeerTracker.identify(@mac)
  end
end
