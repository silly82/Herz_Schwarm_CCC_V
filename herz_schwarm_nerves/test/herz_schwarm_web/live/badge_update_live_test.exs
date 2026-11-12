defmodule HerzSchwarmWeb.BadgeUpdateLiveTest do
  # Statisches Rendering (Phoenix.ConnTest), wie in BridgeUpdateLiveTest.
  use ExUnit.Case, async: false

  import Phoenix.ConnTest

  alias HerzSchwarm.BadgeOta

  @endpoint HerzSchwarmWeb.Endpoint
  @moduletag :capture_log

  # Setzt den Zustand des laufenden BadgeOta-Prozesses fuer einen Test und stellt ihn wieder her.
  defp with_info(info) do
    original = :sys.get_state(BadgeOta)
    :sys.replace_state(BadgeOta, fn st -> %{st | info: info} end)
    on_exit(fn -> :sys.replace_state(BadgeOta, fn _ -> original end) end)
  end

  defp without_key do
    old_env = System.get_env("BADGE_OTA_KEY")
    old_cfg = Application.get_env(:herz_schwarm, :badge_ota_key)
    System.delete_env("BADGE_OTA_KEY")
    Application.delete_env(:herz_schwarm, :badge_ota_key)

    on_exit(fn ->
      if old_env, do: System.put_env("BADGE_OTA_KEY", old_env)
      if old_cfg, do: Application.put_env(:herz_schwarm, :badge_ota_key, old_cfg)
    end)
  end

  test "Seite ohne abgelegte Firmware und ohne Schluessel" do
    with_info(nil)
    without_key()

    html = build_conn() |> get("/badge-update") |> html_response(200)

    assert html =~ "Badge-Update per Funk"
    assert html =~ ~s(id="badge-fw-form")
    assert html =~ ~s(accept=".bin")
    assert html =~ ~s(id="badge-fw-none")
    assert html =~ ~s(id="key-missing")
    assert html =~ ~s(id="badge-ota-form")
    assert html =~ "Update an alle Badges senden"
    refute html =~ ~s(id="badge-fw-info")
  end

  test "Seite zeigt Version, Groesse und MD5 der abgelegten Firmware" do
    with_info(%{
      path: "/nicht/vorhanden/badge.bin",
      size: 2048,
      md5: :binary.copy(<<0xAB>>, 16),
      version: {1, 7, 0}
    })

    html = build_conn() |> get("/badge-update") |> html_response(200)

    assert html =~ ~r/id="badge-fw-version"[^>]*>\s*1\.7\.0/
    assert html =~ "2.0 kB"
    assert html =~ String.duplicate("ab", 16)
    refute html =~ ~s(id="badge-fw-none")
  end

  test "Dashboard verlinkt auf die Badge-Update-Seite" do
    html = build_conn() |> get("/") |> html_response(200)
    assert html =~ ~s(href="/badge-update")
  end

  describe "GET /firmware/badge.bin" do
    test "404 ohne abgelegte Firmware" do
      with_info(nil)
      conn = build_conn() |> get("/firmware/badge.bin")
      assert response(conn, 404) =~ "keine Badge-Firmware"
    end

    test "liefert die abgelegte Datei mit Content-Length" do
      dir = Path.join(System.tmp_dir!(), "badge_fw_#{System.unique_integer([:positive])}")
      File.mkdir_p!(dir)
      on_exit(fn -> File.rm_rf(dir) end)
      path = Path.join(dir, "badge.bin")
      body = <<0xE9>> <> :binary.copy(<<1, 2, 3, 4>>, 500)
      File.write!(path, body)

      with_info(%{path: path, size: byte_size(body), md5: :erlang.md5(body), version: {1, 7, 0}})

      conn = build_conn() |> get("/firmware/badge.bin")
      assert response(conn, 200) == body
      [content_type | _] = Plug.Conn.get_resp_header(conn, "content-type")
      assert content_type =~ "application/octet-stream"
    end
  end
end
