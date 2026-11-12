defmodule HerzSchwarmWeb.FirmwareController do
  @moduledoc """
  Liefert die abgelegte Badge-Firmware fuer das Funk-Update aus
  (`GET /firmware/badge.bin`, siehe `HerzSchwarm.BadgeOta`).

  Bewusst ein schlichter Plug ohne Session/CSRF: Abrufer sind die Badges
  (ESP32-HTTPClient). Die Datei ist nicht geheim — geschuetzt ist das Ausloesen
  des Updates (HMAC), und die Badges pruefen Groesse und MD5 aus dem Ausloeser.
  """

  import Plug.Conn

  def init(action), do: action

  def call(conn, :badge) do
    case HerzSchwarm.BadgeOta.info() do
      %{path: path} ->
        conn
        |> put_resp_content_type("application/octet-stream")
        |> send_file(200, path)

      nil ->
        send_resp(conn, 404, "keine Badge-Firmware abgelegt")
    end
  end
end
