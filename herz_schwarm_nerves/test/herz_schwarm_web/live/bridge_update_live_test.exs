defmodule HerzSchwarmWeb.BridgeUpdateLiveTest do
  # Statisches Rendering (Phoenix.ConnTest): LiveViewTest braucht :lazy_html,
  # das hier nicht als Dependency eingebunden ist.
  use ExUnit.Case, async: false

  import Phoenix.ConnTest

  @endpoint HerzSchwarmWeb.Endpoint
  @moduletag :capture_log

  defp pong(extra) do
    Phoenix.PubSub.broadcast(
      HerzSchwarm.PubSub,
      "bridge:events",
      {:bridge, Map.merge(%{"evt" => "pong", "peers" => 2, "uptime" => 5}, extra)}
    )

    # PeerTracker verarbeitet asynchron; Roundtrip abwarten
    HerzSchwarm.PeerTracker.get_status()
  end

  test "Update-Seite zeigt Bridge-Version, OTA-Zustand, Warnhinweis und Upload-Formular" do
    pong(%{"fw" => "0.3.0", "ota" => "idle"})
    html = build_conn() |> get("/bridge-update") |> html_response(200)

    assert html =~ ~r/id="bridge-fw"[^>]*>\s*0\.3\.0/
    assert html =~ ~r/id="bridge-ota"[^>]*>\s*idle/
    assert html =~ "einmalig per USB"
    assert html =~ "nicht vom Strom trennen"
    assert html =~ ~s(id="ota-form")
    assert html =~ ~s(accept=".bin")
    assert html =~ "Update starten"
    # Kein Update aktiv -> kein Fortschrittsbalken
    refute html =~ ~s(id="update-status")
  end

  test "Dashboard zeigt die Bridge-Version und verlinkt auf die Update-Seite" do
    pong(%{"fw" => "0.3.0", "ota" => "writing"})
    html = build_conn() |> get("/") |> html_response(200)

    assert html =~ ~r/id="bridge-fw-link"[^>]*>\s*Bridge-FW 0\.3\.0 \(OTA: writing\)/
    assert html =~ ~s(href="/bridge-update")
    # bestehende Bedienelemente sind noch da
    assert html =~ "Alle Effekte stoppen"
    assert html =~ "Welle senden"
    assert html =~ "Beat-Steuerung"
  end

  test "pong ohne fw (aeltere Bridge) -> Version unbekannt" do
    pong(%{"fw" => nil, "ota" => nil})
    html = build_conn() |> get("/bridge-update") |> html_response(200)
    assert html =~ ~r/id="bridge-fw"[^>]*>\s*unbekannt/
  end
end
