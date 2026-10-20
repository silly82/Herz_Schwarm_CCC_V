defmodule HerzSchwarmWeb.MonitorTest do
  # Reine Funktionen (MonitorComponents) und statisches Rendern (Phoenix.ConnTest).
  # LiveViewTest braucht :lazy_html, das hier nicht als Dependency eingebunden ist.
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias HerzSchwarmWeb.MonitorComponents, as: MC

  @endpoint HerzSchwarmWeb.Endpoint
  @moduletag :capture_log

  defp badge(attrs) do
    Map.merge(
      %{
        rssi_last: -60,
        rssi_min: -70,
        rssi_avg: -62.5,
        rssi_max: -55,
        samples: [-70, -60, -55],
        last_seen: ~U[2026-10-20 10:00:00Z],
        age_s: 3,
        fw: "1.3.0",
        online: true
      },
      attrs
    )
  end

  setup do
    previous = Application.get_env(:herz_schwarm, :rssi_warn_threshold)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:herz_schwarm, :rssi_warn_threshold, previous),
        else: Application.delete_env(:herz_schwarm, :rssi_warn_threshold)
    end)

    :ok
  end

  describe "normalize/1" do
    test "leerer Snapshot bekommt Defaults (alle Zaehler 0, keine Badges)" do
      m = MC.normalize(%{})
      assert m.badges == %{}
      assert m.bridge.connected == false
      assert m.bridge.uptime_s == nil
      assert m.counters.reconnects == 0
      assert m.counters.commands_sent == 0
    end

    test "nil-Werte crashen nicht" do
      m = MC.normalize(%{counters: nil, bridge: nil, badges: nil})
      assert m.counters.acks == 0
      assert m.badges == %{}
    end
  end

  describe "warnings/2" do
    test "keine Warnung bei verbundener Bridge und gesunden Badges" do
      metrics = MC.normalize(%{badges: %{"AA:BB" => badge(%{})}})
      assert MC.warnings(true, metrics) == []
    end

    test "Bridge getrennt -> Warnung" do
      [msg] = MC.warnings(false, MC.normalize(%{}))
      assert msg =~ "getrennt"
    end

    test "offline Badge nennt die MAC" do
      metrics = MC.normalize(%{badges: %{"AA:BB" => badge(%{online: false, age_s: 42})}})
      [msg] = MC.warnings(true, metrics)
      assert msg =~ "AA:BB"
      assert msg =~ "offline"
      assert msg =~ "42 s"
    end

    test "schwaches Signal unter der Schwelle nennt MAC und Wert" do
      Application.put_env(:herz_schwarm, :rssi_warn_threshold, -75)
      metrics = MC.normalize(%{badges: %{"CC:DD" => badge(%{rssi_last: -82})}})
      [msg] = MC.warnings(true, metrics)
      assert msg =~ "CC:DD"
      assert msg =~ "-82 dBm"
    end

    test "Signal ueber der Schwelle ist keine Warnung" do
      Application.put_env(:herz_schwarm, :rssi_warn_threshold, -75)
      metrics = MC.normalize(%{badges: %{"CC:DD" => badge(%{rssi_last: -60})}})
      assert MC.warnings(true, metrics) == []
    end
  end

  describe "badge_rows/2" do
    test "vereinigt Peers und Snapshot-Badges, offline Badge ohne Peer" do
      peers = [%{mac: "AA:BB", rssi: -58, fw: "1.3.0"}]

      badges = %{
        "AA:BB" => badge(%{}),
        "CC:DD" => badge(%{online: false, age_s: 90, fw: "1.2.0"})
      }

      [a, c] = MC.badge_rows(peers, badges)
      assert a.mac == "AA:BB"
      assert a.online
      assert a.rssi == -60
      assert c.mac == "CC:DD"
      refute c.online
      assert c.age_s == 90
    end

    test "leere Daten ergeben keine Zeilen" do
      assert MC.badge_rows([], %{}) == []
    end

    test "Peer ohne Snapshot-Eintrag gilt als online" do
      [row] = MC.badge_rows([%{mac: "EE:FF", rssi: -70, fw: nil}], %{})
      assert row.online
      assert row.samples == []
      assert row.stats == nil
    end
  end

  describe "sparkline_points/3" do
    test "leere Samples -> keine Punkte" do
      assert MC.sparkline_points([], 100, 20) == ""
    end

    test "einzelner Sample -> ein Punkt" do
      assert MC.sparkline_points([-60], 100, 20) =~ ~r/^\d+(\.\d)?,\d+(\.\d)?$/
    end

    test "staerkeres Signal (hoeherer Wert) liegt weiter oben (kleineres y)" do
      [p1, p2] = MC.sparkline_points([-80, -50], 100, 20) |> String.split(" ")
      [_, y1] = String.split(p1, ",")
      [_, y2] = String.split(p2, ",")
      assert String.to_float(y2) < String.to_float(y1)
    end

    test "gleiche Werte -> keine Division durch 0" do
      points = MC.sparkline_points([-60, -60, -60], 100, 20)
      assert length(String.split(points, " ")) == 3
    end
  end

  describe "filter_log/2" do
    @entries [
      %{at: ~U[2026-10-20 10:00:00Z], level: :debug, source: "a", message: "d"},
      %{at: ~U[2026-10-20 10:00:01Z], level: :info, source: "b", message: "i"},
      %{at: ~U[2026-10-20 10:00:02Z], level: :warn, source: "c", message: "w"},
      %{at: ~U[2026-10-20 10:00:03Z], level: :error, source: "d", message: "e"}
    ]

    test "alle, Mindest-Level info/warn/error" do
      assert length(MC.filter_log(@entries, "all")) == 4
      assert Enum.map(MC.filter_log(@entries, "info"), & &1.level) == [:info, :warn, :error]
      assert Enum.map(MC.filter_log(@entries, "warn"), & &1.level) == [:warn, :error]
      assert Enum.map(MC.filter_log(@entries, "error"), & &1.level) == [:error]
    end

    test "unbekannter Filter zeigt alles" do
      assert length(MC.filter_log(@entries, "quatsch")) == 4
    end
  end

  describe "Formatierung" do
    test "Uptime, Heap, Alter, Zeit robust gegen nil" do
      assert MC.format_duration(nil) == "–"
      assert MC.format_duration(3725) == "1 h 2 min"
      assert MC.format_duration(75) == "1 min 15 s"
      assert MC.format_heap(nil) == "–"
      assert MC.format_heap(2048) == "2 KB"
      assert MC.format_age(nil) == "–"
      assert MC.format_time(nil) == "–"
      assert MC.format_time(~U[2026-10-20 10:01:02Z]) == "10:01:02"
      assert MC.format_datetime(nil) == "–"
      assert MC.format_avg(nil) == "–"
      assert MC.format_avg(-62.5) == "-62.5"
      assert MC.stats_title(nil) == "keine Messwerte"
    end
  end

  describe "Komponenten-Rendering" do
    test "Sparkline als SVG-Polyline" do
      assigns = %{samples: [-70, -60, -55]}
      html = rendered_to_string(~H|<MC.sparkline samples={@samples} />|)
      assert html =~ "<svg"
      assert html =~ "<polyline"
    end

    test "Sparkline ohne Samples zeigt Platzhalter statt SVG" do
      assigns = %{samples: []}
      html = rendered_to_string(~H|<MC.sparkline samples={@samples} />|)
      refute html =~ "<svg"
      assert html =~ "–"
    end

    test "Log-Liste mit Level-Klasse und leerer Zustand" do
      assigns = %{
        entries: [
          %{at: ~U[2026-10-20 10:00:00Z], level: :error, source: "bridge", message: "boom"}
        ]
      }

      html = rendered_to_string(~H|<MC.log_list entries={@entries} />|)
      assert html =~ "log-error"
      assert html =~ "boom"
      assert html =~ "10:00:00"

      assigns = %{entries: []}
      assert rendered_to_string(~H|<MC.log_list entries={@entries} />|) =~ "Keine Einträge."
    end
  end

  describe "Seiten (statisches Rendering)" do
    test "Dashboard zeigt Uptime, Heap, Reconnects, Zaehler und Log-Panel" do
      html = build_conn() |> get("/") |> html_response(200)

      assert html =~ ~s(id="bridge-uptime")
      assert html =~ ~s(id="bridge-heap")
      assert html =~ ~s(id="bridge-reconnects")
      assert html =~ ~s(id="counters")
      assert html =~ ~s(id="log-panel")
      assert html =~ ~s(href="/diagnose")
      # bestehende Bedienelemente bleiben
      assert html =~ "Alle Effekte auf den Badges stoppen"
      assert html =~ "Beat-Steuerung"
      assert html =~ "Ambient Farbe"
    end

    test "Diagnose-Seite zeigt Bridge, Zaehler-Reset, Level-Filter und Log-Clear" do
      html = build_conn() |> get("/diagnose") |> html_response(200)

      assert html =~ ~s(id="bridge-state")
      assert html =~ ~s(id="reset-counters")
      assert html =~ ~s(id="clear-log")
      assert html =~ ~s(id="level-all")
      assert html =~ ~s(id="level-info")
      assert html =~ ~s(id="level-warn")
      assert html =~ ~s(id="level-error")
      assert html =~ ~s(id="poll-status")
      assert html =~ ~s(id="back-link")
    end
  end
end
