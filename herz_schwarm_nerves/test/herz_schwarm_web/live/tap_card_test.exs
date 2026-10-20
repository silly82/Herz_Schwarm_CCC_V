defmodule HerzSchwarmWeb.TapCardTest do
  # Statisches Rendering (Phoenix.ConnTest / rendered_to_string), kein LiveViewTest.
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.Component, only: [sigil_H: 2]
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]

  alias HerzSchwarmWeb.MonitorComponents, as: MC

  @endpoint HerzSchwarmWeb.Endpoint
  @moduletag :capture_log

  defp render_card(taps) do
    assigns = %{taps: taps}
    rendered_to_string(~H"<MC.tap_card taps={@taps} />")
  end

  test "Karte rendert mit Daten: Gesamtsumme, Badge-Zeile, Reset mit Rückfrage" do
    taps = %{
      total: 7,
      badges: %{"AA:BB:CC:DD:EE:FF" => %{count: 7, last_seen: ~U[2026-10-20 10:00:00Z]}},
      updated_at: ~U[2026-10-20 10:00:00Z]
    }

    html = render_card(taps)

    assert html =~ ~s(id="tap-card")
    assert html =~ ~s(id="tap-total")
    assert html =~ ">7<"
    assert html =~ ~s(id="tap-AA:BB:CC:DD:EE:FF")
    assert html =~ "20.10.2026 10:00:00"
    assert html =~ ~s(id="tap-reset")
    assert html =~ ~s(phx-click="tap-reset")
    assert html =~ ~s(data-confirm=)
    refute html =~ "Noch keine Taps"
  end

  test "leerer Zustand zeigt 'Noch keine Taps' ohne Tabelle" do
    html = render_card(%{total: 0, badges: %{}, updated_at: nil})

    assert html =~ "Noch keine Taps."
    assert html =~ ~s(id="tap-total")
    refute html =~ "<table"
  end

  test "Badge ohne letzten Tap (nil) crasht nicht" do
    html =
      render_card(%{total: 0, badges: %{"AA:BB:CC:DD:EE:FF" => %{count: 0, last_seen: nil}}})

    assert html =~ ~s(id="tap-AA:BB:CC:DD:EE:FF")
  end

  test "Dashboard enthaelt die Tap-Karte" do
    html = build_conn() |> get("/") |> html_response(200)

    assert html =~ ~s(id="tap-card")
    assert html =~ "Tap-Counter"
    # bestehende Teile bleiben
    assert html =~ ~s(id="log-panel")
    assert html =~ ~s(id="counters")
  end
end
