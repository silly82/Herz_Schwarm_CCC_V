defmodule HerzSchwarm.MetricsTest do
  use ExUnit.Case, async: false

  alias HerzSchwarm.Metrics

  @mac "A0:F2:62:EC:3B:B4"

  setup do
    Metrics.reset()
    Metrics.set_bridge_state(%{connected: false, port: nil})
    Metrics.reset()
    :ok
  end

  test "snapshot bei leerem Zustand ist gueltig" do
    snap = Metrics.snapshot()

    assert snap.badges == %{}

    assert snap.bridge == %{
             connected: false,
             port: nil,
             since: nil,
             uptime_s: nil,
             free_heap: nil
           }

    assert Map.keys(snap.counters) |> Enum.sort() ==
             Enum.sort(
               ~w(commands_sent acks errors timeouts reconnects triggers wave_starts wave_stops identifies)a
             )

    assert Enum.all?(snap.counters, fn {_k, v} -> v == 0 end)
    assert Metrics.offline_badges() == []
    refute Metrics.badge_online?(@mac)
  end

  test "increment/1,2 und reset_counters" do
    Metrics.increment(:acks)
    Metrics.increment(:acks)
    Metrics.increment(:errors, 5)
    assert %{acks: 2, errors: 5, timeouts: 0} = Metrics.snapshot().counters

    assert :ok = Metrics.reset_counters()
    assert Enum.all?(Metrics.snapshot().counters, fn {_k, v} -> v == 0 end)
  end

  test "unbekannter Zaehler wird abgelehnt" do
    assert_raise FunctionClauseError, fn ->
      apply(Metrics, :increment, [:gibt_es_nicht])
    end
  end

  test "add_rssi: Statistik, Ringpuffer (60), aeltester Wert zuerst" do
    for rssi <- -100..-41, do: Metrics.add_rssi(@mac, rssi, "1.3.0")
    # 60 Werte: -100..-41
    b = Metrics.snapshot().badges[@mac]
    assert length(b.samples) == 60
    assert b.rssi_min == -100 and b.rssi_max == -41 and b.rssi_last == -41
    assert b.fw == "1.3.0" and b.online and b.age_s == 0
    assert %DateTime{} = b.last_seen

    # weitere 10 Werte verdraengen die aeltesten
    for _ <- 1..10, do: Metrics.add_rssi(@mac, -50)
    b = Metrics.snapshot().badges[@mac]
    assert length(b.samples) == 60
    assert hd(b.samples) == -90
    assert List.last(b.samples) == -50
    assert b.fw == "1.3.0"
    assert is_float(b.rssi_avg)
  end

  test "rssi_avg ist der Mittelwert der Samples" do
    Metrics.add_rssi(@mac, -60)
    Metrics.add_rssi(@mac, -70)
    assert Metrics.snapshot().badges[@mac].rssi_avg == -65.0
  end

  test "MAC wird normalisiert, mark_seen legt Badge ohne Messwert an" do
    Metrics.mark_seen("a0:f2:62:ec:3b:b4")
    b = Metrics.snapshot().badges[@mac]
    assert b.online
    assert b.samples == [] and b.rssi_last == nil and b.rssi_avg == nil
  end

  test "Badge-Anzahl ist begrenzt (64), aeltestes Badge faellt heraus" do
    for i <- 1..70 do
      Metrics.add_rssi("00:00:00:00:00:" <> Base.encode16(<<i>>), -70, nil, 10_000 - i)
    end

    badges = Metrics.snapshot().badges
    assert map_size(badges) == 64
    refute Map.has_key?(badges, "00:00:00:00:00:01")
    assert Map.has_key?(badges, "00:00:00:00:00:" <> Base.encode16(<<70>>))
  end

  test "Offline-Erkennung ueber Alter; Badge bleibt mit online: false erhalten" do
    Metrics.add_rssi(@mac, -70, "1.3.0", 30_000)
    Metrics.add_rssi("11:22:33:44:55:66", -60, nil, 100)

    refute Metrics.badge_online?(@mac)
    assert Metrics.badge_online?("11:22:33:44:55:66")
    assert Metrics.offline_badges() == [@mac]

    b = Metrics.snapshot().badges[@mac]
    assert b.online == false
    assert b.age_s >= 30

    # neues Lebenszeichen -> wieder online
    Metrics.add_rssi(@mac, -71, nil, 0)
    assert Metrics.badge_online?(@mac)
    assert Metrics.offline_badges() == []
  end

  test "Offline-Schwelle ist konfigurierbar" do
    on_exit(fn -> Application.put_env(:herz_schwarm, :badge_offline_after_s, 20) end)
    Metrics.add_rssi(@mac, -70, nil, 5_000)
    assert Metrics.badge_online?(@mac)
    Application.put_env(:herz_schwarm, :badge_offline_after_s, 2)
    refute Metrics.badge_online?(@mac)
  end

  test "Config-Defaults" do
    assert Metrics.rssi_warn_threshold() == -85
    assert Metrics.badge_offline_after_s() == 20
  end

  test "set_bridge_state: Verbindung, since, uptime/heap; Trennung leert Laufzeitwerte" do
    Metrics.set_bridge_state(%{connected: true, port: "/dev/ttyACM0"})
    Metrics.set_bridge_state(%{uptime_s: 120, free_heap: 150_000})
    b = Metrics.snapshot().bridge

    assert %{connected: true, port: "/dev/ttyACM0", uptime_s: 120, free_heap: 150_000} = b
    assert %DateTime{} = b.since

    Metrics.set_bridge_state(%{connected: false, port: "/dev/ttyACM0"})
    b = Metrics.snapshot().bridge

    assert %{connected: false, since: nil, uptime_s: nil, free_heap: nil, port: "/dev/ttyACM0"} =
             b
  end

  test "reset: Zaehler und Badges leer, Verbindungszustand bleibt" do
    Metrics.set_bridge_state(%{connected: true, port: "p"})
    Metrics.increment(:acks)
    Metrics.add_rssi(@mac, -70)
    Metrics.reset()
    snap = Metrics.snapshot()

    assert snap.badges == %{}
    assert snap.counters.acks == 0
    assert snap.bridge.connected
  end

  describe "Publikation auf metrics:state" do
    setup do
      Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, "metrics:state")
      # Ruhe abwarten, damit die naechste Aenderung "Leading Edge" ist
      Process.sleep(1_100)
      flush()
      :ok
    end

    test "erste Aenderung geht sofort raus, Schauer wird gedrosselt (>= ~500 ms Abstand)" do
      t0 = System.monotonic_time(:millisecond)
      for _ <- 1..300, do: Metrics.increment(:triggers)

      times = collect_times(t0, 1_300)

      assert length(times) in 2..3,
             "erwartet 1 sofortige + 1 nachlaufende Meldung, war: #{inspect(times)}"

      assert hd(times) < 100

      times
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.each(fn [a, b] -> assert b - a >= 450 end)

      assert %{counters: %{triggers: 300}} = last_metrics()
    end

    test "Bridge-Verbindungswechsel publiziert sofort, auch mitten in der Drosselung" do
      Metrics.increment(:acks)
      assert_receive {:metrics, _}, 100
      Metrics.increment(:acks)
      refute_receive {:metrics, _}, 100
      Metrics.set_bridge_state(%{connected: true, port: "x"})
      assert_receive {:metrics, %{bridge: %{connected: true}}}, 100
    end

    defp flush do
      receive do
        {:metrics, _} -> flush()
      after
        0 -> :ok
      end
    end

    defp collect_times(t0, window) do
      deadline = t0 + window

      Stream.repeatedly(fn ->
        remaining = deadline - System.monotonic_time(:millisecond)

        receive do
          {:metrics, snap} ->
            Process.put(:last_metrics, snap)
            System.monotonic_time(:millisecond) - t0
        after
          max(remaining, 0) -> :done
        end
      end)
      |> Enum.take_while(&(&1 != :done))
    end

    defp last_metrics, do: Process.get(:last_metrics)
  end
end
