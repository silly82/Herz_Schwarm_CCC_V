defmodule HerzSchwarmWeb.BadgeUpdateLive do
  @moduledoc """
  Funk-Update der Badges: Firmware ablegen und den Update-Ausloeser senden
  (siehe `HerzSchwarm.BadgeOta`).
  """

  use HerzSchwarmWeb, :live_view

  alias HerzSchwarm.{BadgeOta, Bridge, PeerTracker}

  @max_file_size 2 * 1024 * 1024
  @default_port 4000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, "peers:count")
    end

    peers = PeerTracker.get_status()

    socket =
      socket
      |> assign(
        bridge_connected: Bridge.connected?(),
        peers: peers.peers,
        info: BadgeOta.info(),
        key_configured: BadgeOta.key_configured?(),
        ip: default_ip(),
        port: Integer.to_string(default_port()),
        store_error: nil,
        trigger_msg: nil,
        trigger_error: nil
      )
      |> allow_upload(:firmware,
        accept: ~w(.bin),
        max_entries: 1,
        max_file_size: @max_file_size
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns, :target, if(assigns.info, do: BadgeOta.format_version(assigns.info.version)))

    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-6">
      <header class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-pink-400">&#x1F4E1; Badge-Update per Funk</h1>
        <div class="flex items-center gap-3">
          <span class={"badge #{if @bridge_connected, do: "badge-ok", else: "badge-err"}"}>
            Bridge: {if @bridge_connected, do: "verbunden", else: "getrennt"}
          </span>
          <.link navigate={~p"/"} class="badge badge-info">&larr; Dashboard</.link>
        </div>
      </header>

      <div class="card mb-6 border border-yellow-700">
        <h2 class="text-yellow-400">&#x26A0;&#xFE0F; Voraussetzungen</h2>
        <ul class="list-disc pl-5 text-sm text-gray-300">
          <li>
            Badges ab Firmware 1.7.0, einmalig per USB geflasht und mit <code>ota_secret.h</code>
            gebaut (WLAN-Zugang und Schlüssel). Auch die Update-Datei muss mit dieser Datei gebaut sein.
          </li>
          <li>
            Dieser Rechner ist im WLAN der Badges erreichbar; die Adresse unten ist seine Adresse dort.
          </li>
          <li>
            Nur Badges mit <strong>älterer</strong>
            Version aktualisieren sich. Sie verlassen dafür kurz den Schwarm und starten danach neu.
          </li>
        </ul>
        <p :if={!@key_configured} id="key-missing" class="text-sm text-red-400 mt-2">
          Kein Schlüssel gesetzt: Umgebungsvariable <code>BADGE_OTA_KEY</code>
          mit demselben Text wie <code>OTA_KEY</code>
          in <code>ota_secret.h</code>
          setzen und die App neu starten.
        </p>
      </div>

      <div class="card mb-6">
        <h2>&#x1F4E4; Badge-Firmware ablegen</h2>
        <form id="badge-fw-form" phx-change="validate" phx-submit="store">
          <.live_file_input upload={@uploads.firmware} class="text-sm text-gray-300 mb-3" />

          <div :for={entry <- @uploads.firmware.entries} class="text-sm text-gray-400 mb-2">
            <span class="font-mono">{entry.client_name}</span>
            ({format_bytes(entry.client_size)}) &middot; Upload {entry.progress}&nbsp;%
            <button
              type="button"
              class="text-pink-400 ml-2"
              phx-click="cancel-upload"
              phx-value-ref={entry.ref}
            >
              &times;
            </button>
            <p :for={err <- upload_errors(@uploads.firmware, entry)} class="text-red-400">
              {upload_error_text(err)}
            </p>
          </div>
          <p :for={err <- upload_errors(@uploads.firmware)} class="text-red-400 text-sm mb-2">
            {upload_error_text(err)}
          </p>

          <button type="submit" class="btn btn-go w-full" disabled={!upload_ready?(assigns)}>
            &#x1F4BE; Ablegen
          </button>
        </form>
        <p :if={@store_error} id="store-error" class="text-sm text-red-400 mt-3">{@store_error}</p>

        <dl :if={@info} id="badge-fw-info" class="grid grid-cols-2 gap-2 text-sm mt-4">
          <dt class="text-gray-400">Abgelegte Version</dt>
          <dd id="badge-fw-version" class="font-mono">{@target}</dd>
          <dt class="text-gray-400">Größe</dt>
          <dd class="font-mono">{format_bytes(@info.size)}</dd>
          <dt class="text-gray-400">MD5</dt>
          <dd class="font-mono break-all">{Base.encode16(@info.md5, case: :lower)}</dd>
        </dl>
        <p :if={!@info} id="badge-fw-none" class="text-sm text-gray-400 mt-3">
          Noch keine Badge-Firmware abgelegt.
        </p>
      </div>

      <div class="card mb-6">
        <h2>&#x1F680; Update auslösen</h2>
        <form id="badge-ota-form" phx-change="target" phx-submit="trigger">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-3">
            <label class="text-sm text-gray-400">
              Adresse dieses Rechners im Badge-WLAN
              <input
                id="ota-ip"
                type="text"
                name="ip"
                value={@ip}
                placeholder="192.168.4.1"
                class="block w-full mt-1 px-2 py-1 rounded bg-gray-900 border border-gray-700 font-mono text-gray-100"
              />
            </label>
            <label class="text-sm text-gray-400">
              Port
              <input
                id="ota-port"
                type="number"
                name="port"
                min="1"
                max="65535"
                value={@port}
                class="block w-full mt-1 px-2 py-1 rounded bg-gray-900 border border-gray-700 font-mono text-gray-100"
              />
            </label>
          </div>
          <button type="submit" class="btn btn-go w-full" disabled={!can_trigger?(assigns)}>
            &#x25B6; Update an alle Badges senden
          </button>
        </form>
        <p :if={@trigger_msg} id="trigger-msg" class="text-sm text-gray-300 mt-3">{@trigger_msg}</p>
        <p :if={@trigger_error} id="trigger-error" class="text-sm text-red-400 mt-3">
          {@trigger_error}
        </p>
      </div>

      <div class="card">
        <h2>&#x1F50E; Badges</h2>
        <p :if={@peers == []} class="text-sm text-gray-400">
          Keine Badges in Funkreichweite der Bridge (Liste aktualisiert alle 5 s).
        </p>
        <table :if={@peers != []} class="w-full text-sm">
          <thead>
            <tr class="text-left text-gray-400">
              <th class="py-1">MAC</th>
              <th>FW</th>
              <th>Stand</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={p <- @peers} class="border-t border-gray-800">
              <td class="py-1 font-mono whitespace-nowrap">{p.mac}</td>
              <td class="font-mono">{p.fw}</td>
              <td>{peer_status(p.fw, @target)}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # --- Events ---

  @impl true
  def handle_event("validate", _params, socket), do: {:noreply, socket}

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :firmware, ref)}
  end

  def handle_event("store", _params, socket) do
    results =
      consume_uploaded_entries(socket, :firmware, fn %{path: path}, _entry ->
        # store_image liest die Datei synchron; der Upload-Tempfile wird erst danach geloescht
        {:ok, BadgeOta.store_image(path)}
      end)

    case results do
      [{:ok, info}] ->
        {:noreply, assign(socket, info: info, store_error: nil, trigger_msg: nil)}

      [{:error, reason}] ->
        {:noreply, assign(socket, store_error: store_error_text(reason))}

      [] ->
        {:noreply, assign(socket, store_error: "Bitte zuerst eine .bin-Datei auswählen.")}
    end
  end

  def handle_event("target", params, socket) do
    {:noreply,
     assign(socket,
       ip: Map.get(params, "ip", socket.assigns.ip),
       port: Map.get(params, "port", socket.assigns.port)
     )}
  end

  def handle_event("trigger", params, socket) do
    ip_str = Map.get(params, "ip", socket.assigns.ip)
    port_str = Map.get(params, "port", socket.assigns.port)
    socket = assign(socket, ip: ip_str, port: port_str)

    with {:ok, ip} <- parse_ip(ip_str),
         {:ok, port} <- parse_port(port_str),
         {:ok, _id} <- BadgeOta.trigger(ip, port) do
      msg =
        "Auslöser gesendet. Badges mit älterer Firmware laden jetzt von " <>
          "http://#{BadgeOta.format_ip(ip)}:#{port}/firmware/badge.bin und starten danach neu."

      {:noreply, assign(socket, trigger_msg: msg, trigger_error: nil)}
    else
      {:error, reason} ->
        {:noreply, assign(socket, trigger_msg: nil, trigger_error: trigger_error_text(reason))}
    end
  end

  # --- PubSub ---

  @impl true
  def handle_info({:peers, status}, socket) do
    {:noreply, assign(socket, bridge_connected: status.bridge_connected, peers: status.peers)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # --- Helpers ---

  defp default_ip do
    case BadgeOta.local_ips() do
      [ip | _] -> BadgeOta.format_ip(ip)
      [] -> ""
    end
  end

  defp default_port do
    case HerzSchwarmWeb.Endpoint.config(:http) do
      opts when is_list(opts) -> Keyword.get(opts, :port, @default_port)
      _ -> @default_port
    end
  end

  defp parse_ip(str) do
    case BadgeOta.parse_ip(str) do
      {:ok, ip} -> {:ok, ip}
      :error -> {:error, :invalid_ip}
    end
  end

  defp parse_port(str) do
    case Integer.parse(String.trim(str)) do
      {port, ""} when port in 1..65_535 -> {:ok, port}
      _ -> {:error, :invalid_port}
    end
  end

  defp upload_ready?(assigns) do
    assigns.uploads.firmware.entries != [] and
      Enum.all?(assigns.uploads.firmware.entries, & &1.done?)
  end

  defp can_trigger?(assigns) do
    assigns.bridge_connected and assigns.info != nil and assigns.key_configured
  end

  defp peer_status(_fw, nil), do: "—"
  defp peer_status(fw, target) when fw == target, do: "aktuell"
  defp peer_status(_fw, _target), do: "älter oder anders"

  defp store_error_text(:no_store), do: "Keine Ablage konfiguriert (badge_ota_dir)."
  defp store_error_text(:empty_image), do: "Die Datei ist leer."
  defp store_error_text(:image_too_large), do: "Die Datei ist größer als der App-Slot der Badges."

  defp store_error_text(:not_an_esp_image),
    do: "Keine gültige ESP32-Firmware (erwartet: Herz_Schwarm_CCC_V.ino.bin)."

  defp store_error_text(:no_version_marker),
    do: "Keine Versionskennung gefunden — die Datei muss eine Badge-Firmware ab 1.7.0 sein."

  defp store_error_text({:read_failed, reason}), do: "Datei nicht lesbar: #{inspect(reason)}"
  defp store_error_text(reason), do: "Ablegen fehlgeschlagen: #{inspect(reason)}"

  defp trigger_error_text(:invalid_ip), do: "Ungültige Adresse (erwartet z. B. 192.168.4.1)."
  defp trigger_error_text(:invalid_port), do: "Ungültiger Port (1–65535)."
  defp trigger_error_text(:no_image), do: "Noch keine Badge-Firmware abgelegt."
  defp trigger_error_text(:no_key), do: "Kein Schlüssel gesetzt (BADGE_OTA_KEY)."

  defp trigger_error_text(reason) when reason in [:not_connected, :bridge_down],
    do: "Bridge getrennt."

  defp trigger_error_text(reason), do: "Senden fehlgeschlagen: #{inspect(reason)}"

  defp upload_error_text(:too_large), do: "Datei ist größer als 2 MB."
  defp upload_error_text(:not_accepted), do: "Nur .bin-Dateien erlaubt."
  defp upload_error_text(:too_many_files), do: "Nur eine Datei erlaubt."
  defp upload_error_text(other), do: "Upload-Fehler: #{inspect(other)}"

  defp format_bytes(n) when n >= 1024 * 1024, do: "#{Float.round(n / 1024 / 1024, 2)} MB"
  defp format_bytes(n) when n >= 1024, do: "#{Float.round(n / 1024, 1)} kB"
  defp format_bytes(n), do: "#{n} B"
end
