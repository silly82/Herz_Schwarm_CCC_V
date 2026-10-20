defmodule HerzSchwarmWeb.DashboardLiveTest do
  # Statisches Rendering (Phoenix.ConnTest): LiveViewTest braucht :lazy_html,
  # das hier nicht als Dependency eingebunden ist. Geprüft wird die HEEx-Struktur:
  # phx-change feuert in LiveView nur für Inputs innerhalb eines <form>.
  use ExUnit.Case, async: false

  import Phoenix.ConnTest

  @endpoint HerzSchwarmWeb.Endpoint
  @moduletag :capture_log

  defp dashboard_html do
    build_conn() |> get("/") |> html_response(200)
  end

  # Liefert den gesamten <form id="...">...</form>-Block (inkl. Öffnungs-Tag).
  defp form_block(html, id) do
    case Regex.run(~r/<form[^>]*id="#{id}"[^>]*>.*?<\/form>/s, html) do
      [block] -> block
      nil -> flunk("kein <form id=\"#{id}\"> gefunden")
    end
  end

  test "BPM-Slider liegt in einem Formular mit phx-change=set-bpm" do
    html = dashboard_html()
    form = form_block(html, "bpm-form")

    assert form =~ ~r/<form[^>]*phx-change="set-bpm"/
    assert form =~ ~r/<input[^>]*type="range"[^>]*name="bpm"/
    assert form =~ ~r/name="bpm"[^>]*phx-debounce="120"|phx-debounce="120"[^>]*name="bpm"/
  end

  test "Farbwähler liegt in einem Formular mit phx-change=set-color" do
    html = dashboard_html()
    form = form_block(html, "color-form")

    assert form =~ ~r/<form[^>]*phx-change="set-color"/
    assert form =~ ~r/<input[^>]*type="color"[^>]*name="color"/
    assert form =~ ~r/name="color"[^>]*phx-debounce="80"|phx-debounce="80"[^>]*name="color"/
    # Hex-Vorschau ist im selben Block
    assert form =~ ~s(id="color-hex")
  end

  test "keine verschachtelten Formulare und kein phx-change außerhalb der Formulare" do
    html = dashboard_html()

    # Jedes <form> wird geschlossen, bevor das nächste beginnt.
    opens = Regex.scan(~r/<form\b/, html) |> length()
    closes = Regex.scan(~r/<\/form>/, html) |> length()
    assert opens == closes
    assert opens >= 2

    # Die einzelnen phx-change-Bindings sitzen nur in den beiden Formularen.
    assert length(Regex.scan(~r/phx-change="set-(bpm|color)"/, html)) == 2
  end

  test "Start-Button ist vorhanden und das Dashboard rendert weiter" do
    html = dashboard_html()
    assert html =~ "Start"
    assert html =~ "Ambient senden"
  end
end
