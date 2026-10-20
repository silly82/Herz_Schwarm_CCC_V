defmodule HerzSchwarmWeb.BridgeUpdateLive do
  @moduledoc """
  Firmware-Update der ESP32-Bridge ueber die bestehende UART-Verbindung
  (siehe `HerzSchwarm.BridgeUpdater`).
  """

  use HerzSchwarmWeb, :live_view

  alias HerzSchwarm.{Bridge, BridgeUpdater, PeerTracker}

  @max_file_size 2 * 1024 * 1024

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, "peers:count")
      Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, BridgeUpdater.topic())
    end

    peers = PeerTracker.get_status()

    socket =
      socket
      |> assign(
        bridge_connected: Bridge.connected?(),
        bridge_fw: pong_field(peers.last_pong, "fw"),
        bridge_ota: pong_field(peers.last_pong, "ota"),
        update: updater_payload(BridgeUpdater.state()),
        start_error: nil
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
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-6">
      <header class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-pink-400">&#x1F501; Bridge-Update</h1>
        <div class="flex items-center gap-3">
          <span class={"badge #{if @bridge_connected, do: "badge-ok", else: "badge-err"}"}>
            Bridge: {if @bridge_connected, do: "verbunden", else: "getrennt"}
          </span>
          <.link navigate={~p"/"} class="badge badge-info">&larr; Dashboard</.link>
        </div>
      </header>

      <div class="card mb-6">
        <h2>&#x1F4DF; Bridge-Firmware</h2>
        <dl class="grid grid-cols-2 gap-2 text-sm">
          <dt class="text-gray-400">Version</dt>
          <dd id="bridge-fw" class="font-mono">{@bridge_fw || "unbekannt"}</dd>
          <dt class="text-gray-400">OTA-Zustand</dt>
          <dd id="bridge-ota" class="font-mono">{@bridge_ota || "unbekannt"}</dd>
        </dl>
        <p :if={@bridge_fw == nil} class="text-xs text-gray-500 mt-2">
          Die Version kommt aus der Status-Antwort (pong) der Bridge; Firmware &lt; 0.3.0 meldet keine.
          Solche Bridges k&ouml;nnen noch nicht per OTA aktualisiert werden (einmal per USB flashen).
        </p>
      </div>

      <div class="card mb-6 border border-yellow-700">
        <h2 class="text-yellow-400">&#x26A0;&#xFE0F; Hinweis</h2>
        <p class="text-sm text-gray-300">
          Erstes Flashen mit OTA-f&auml;higem Partition-Schema muss einmalig per USB erfolgen.
          W&auml;hrend des Updates die Bridge nicht vom Strom trennen.
        </p>
      </div>

      <div class="card mb-6">
        <h2>&#x1F4E4; Firmware hochladen</h2>
        <form id="ota-form" phx-change="validate" phx-submit="start">
          <.live_file_input
            upload={@uploads.firmware}
            class="text-sm text-gray-300 mb-3"
            disabled={running?(@update)}
          />

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
              {error_to_string(err)}
            </p>
          </div>
          <p :for={err <- upload_errors(@uploads.firmware)} class="text-red-400 text-sm mb-2">
            {error_to_string(err)}
          </p>

          <div class="flex gap-2">
            <button
              type="submit"
              class="btn btn-go flex-1"
              disabled={!can_start?(assigns)}
            >
              &#x25B6; Update starten
            </button>
            <button
              :if={running?(@update)}
              type="button"
              class="btn btn-stop flex-1"
              phx-click="cancel"
            >
              &#x23F9; Abbrechen
            </button>
          </div>
        </form>
        <p :if={@start_error} id="start-error" class="text-sm text-red-400 mt-3">{@start_error}</p>
      </div>

      <div :if={@update.state != :idle} class="card" id="update-status">
        <h2>&#x1F4C8; Fortschritt</h2>
        <div class="w-full h-3 bg-gray-800 rounded overflow-hidden mb-2">
          <div
            class={"h-3 #{if @update.state == :error, do: "bg-red-500", else: "bg-pink-500"}"}
            style={"width: #{@update.percent}%"}
          >
          </div>
        </div>
        <p class="text-sm font-mono mb-1">
          {@update.percent}&nbsp;% &middot; {format_bytes(@update.offset)} / {format_bytes(
            @update.size
          )}
        </p>
        <p id="update-state" class="text-sm text-gray-300">{state_text(@update)}</p>
        <p :if={@update.error} id="update-error" class="text-sm text-red-400 mt-1">
          Fehler: {@update.error}
        </p>
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

  def handle_event("start", _params, socket) do
    results =
      consume_uploaded_entries(socket, :firmware, fn %{path: path}, _entry ->
        # begin_update liest die Datei synchron; der Upload-Tempfile wird erst danach geloescht
        {:ok, BridgeUpdater.begin_update(path)}
      end)

    case results do
      [{:ok, _ref}] -> {:noreply, assign(socket, start_error: nil)}
      [{:error, reason}] -> {:noreply, assign(socket, start_error: start_error_text(reason))}
      [] -> {:noreply, assign(socket, start_error: "Bitte zuerst eine .bin-Datei auswählen.")}
    end
  end

  def handle_event("cancel", _params, socket) do
    BridgeUpdater.cancel()
    {:noreply, socket}
  end

  # --- PubSub ---

  @impl true
  def handle_info({:bridge_update, payload}, socket) do
    {:noreply, assign(socket, update: payload)}
  end

  def handle_info({:peers, status}, socket) do
    {:noreply,
     assign(socket,
       bridge_connected: status.bridge_connected,
       bridge_fw: pong_field(status.last_pong, "fw"),
       bridge_ota: pong_field(status.last_pong, "ota")
     )}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # --- Helpers ---

  defp pong_field(%{} = pong, key), do: pong[key]
  defp pong_field(_, _key), do: nil

  # Gleiche Form wie die "bridge:update"-Nachrichten
  defp updater_payload(s) do
    %{
      state: s.state,
      phase: s.phase,
      offset: s.offset,
      size: s.size,
      percent: if(s.state == :done, do: 100, else: percent(s.offset, s.size)),
      error: s.error
    }
  end

  defp percent(_offset, 0), do: 0
  defp percent(offset, size), do: div(offset * 100, size)

  defp running?(%{state: :running}), do: true
  defp running?(_), do: false

  defp can_start?(assigns) do
    assigns.bridge_connected and not running?(assigns.update) and
      assigns.uploads.firmware.entries != [] and
      Enum.all?(assigns.uploads.firmware.entries, & &1.done?)
  end

  defp state_text(%{state: :running, phase: :begin}), do: "Bridge bereitet den Flash-Slot vor …"
  defp state_text(%{state: :running, phase: :end}), do: "Bridge prüft das Image …"
  defp state_text(%{state: :running}), do: "Übertrage Firmware …"

  defp state_text(%{state: :done}),
    do: "Fertig. Die Bridge startet neu und verbindet sich gleich wieder."

  defp state_text(%{state: :error}), do: "Update fehlgeschlagen."
  defp state_text(_), do: ""

  defp start_error_text(:busy), do: "Es läuft bereits ein Update."
  defp start_error_text(:not_connected), do: "Bridge nicht verbunden."
  defp start_error_text(:bridge_down), do: "Bridge-Prozess nicht erreichbar."
  defp start_error_text(:empty_image), do: "Die Datei ist leer."
  defp start_error_text(:image_too_large), do: "Die Datei ist größer als 2 MB."

  defp start_error_text(:not_an_esp_image),
    do: "Keine gültige ESP32-Firmware (erwartet: App-Image, z. B. esp32_bridge.ino.bin)."

  defp start_error_text({:read_failed, reason}), do: "Datei nicht lesbar: #{inspect(reason)}"
  defp start_error_text(reason), do: "Start fehlgeschlagen: #{inspect(reason)}"

  defp error_to_string(:too_large), do: "Datei ist größer als 2 MB."
  defp error_to_string(:not_accepted), do: "Nur .bin-Dateien erlaubt."
  defp error_to_string(:too_many_files), do: "Nur eine Datei erlaubt."
  defp error_to_string(other), do: "Upload-Fehler: #{inspect(other)}"

  defp format_bytes(n) when n >= 1024 * 1024, do: "#{Float.round(n / 1024 / 1024, 2)} MB"
  defp format_bytes(n) when n >= 1024, do: "#{Float.round(n / 1024, 1)} kB"
  defp format_bytes(n), do: "#{n} B"
end
