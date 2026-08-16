defmodule HerzSchwarmWeb.FlashStationLive do
  use HerzSchwarmWeb, :live_view

  alias HerzSchwarm.{FlashStation, FirmwareSync}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, FlashStation.topic())
      Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, FirmwareSync.topic())
    end

    flash_state = FlashStation.get_state()
    sync_status = FirmwareSync.get_status()

    {:ok,
     assign(socket,
       auto_flash: flash_state.auto_flash,
       devices: flash_state.devices,
       sync_status: sync_status
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-6">
      <header class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold text-pink-400">
          &#x26A1; Flash-Station
        </h1>
        <a href="/" class="badge badge-info">&#x2190; zur&uuml;ck</a>
      </header>

      <div class="card mb-4">
        <h2>&#x1F4E6; Firmware-Stand</h2>
        <p class="text-sm text-gray-400 mb-3">
          Letzter Sync: {format_time(@sync_status.last_synced_at)}
          <span :if={@sync_status.last_error} class="text-red-400">
            &middot; letzter Sync fehlgeschlagen ({inspect(@sync_status.last_error)})
          </span>
        </p>
        <div class="grid grid-cols-2 gap-3 mb-3">
          <div class="text-sm">
            <span class="text-gray-400">Badge:</span>
            {staged_label(@sync_status.staged.badge)}
          </div>
          <div class="text-sm">
            <span class="text-gray-400">Basisstation:</span>
            {staged_label(@sync_status.staged.basestation)}
          </div>
        </div>
        <button class="btn btn-go" phx-click="sync-now">
          Jetzt synchronisieren
        </button>
      </div>

      <div class="card mb-4">
        <h2>&#x1F916; Auto-Flash</h2>
        <p class="text-sm text-gray-400 mb-3">
          Wenn aktiv, wird jedes erkannte Badge sofort automatisch geflasht
          (Walk-up-Modus). Die Basisstation wird davon nie erfasst — sie
          braucht immer eine explizite Best&auml;tigung unten, da Badge und
          Basisstation hardwareseitig identisch (esp32s3) und nicht
          automatisch unterscheidbar sind.
        </p>
        <label class="flex items-center gap-3 cursor-pointer">
          <input type="checkbox" checked={@auto_flash} phx-click="toggle-auto-flash" />
          <span class={"badge #{if @auto_flash, do: "badge-ok", else: "badge-idle"}"}>
            {if @auto_flash, do: "AN — Badges werden sofort geflasht", else: "AUS — Bestätigung nötig"}
          </span>
        </label>
      </div>

      <div class="card">
        <h2>&#x1F50C; Erkannte Ger&auml;te</h2>
        <p :if={@devices == %{}} class="text-sm text-gray-400">
          Kein Ger&auml;t angesteckt. Badge oder Basisstation per USB an den Pi anschlie&szlig;en.
        </p>
        <div :for={{port, device} <- @devices} class="border-t border-gray-700 py-3 first:border-t-0">
          <div class="flex items-center justify-between mb-2">
            <span class="font-mono text-sm">{port}</span>
            <span class={"badge #{status_badge_class(device.status)}"}>
              {status_label(device.status)}
            </span>
          </div>

          <div :if={device.status == :awaiting_confirm} class="flex gap-2">
            <button class="btn btn-go flex-1" phx-click="confirm-flash" phx-value-port={port} phx-value-target="badge">
              Als Badge flashen
            </button>
            <button class="btn btn-ambient flex-1" phx-click="confirm-flash" phx-value-port={port} phx-value-target="basestation">
              Als Basisstation flashen
            </button>
            <button class="btn btn-stop" phx-click="dismiss" phx-value-port={port}>
              Ignorieren
            </button>
          </div>

          <div :if={device.status in [:done, :error]} class="flex items-center justify-between">
            <span class="text-sm text-gray-400">
              Ziel: {device.target || "?"} &middot; Ergebnis: {inspect(device.result)}
            </span>
            <button class="btn btn-stop" phx-click="dismiss" phx-value-port={port}>
              Ausblenden
            </button>
          </div>
        </div>
      </div>

      <footer class="mt-8 text-center text-xs text-gray-600">
        Bridge-Port ist immer ausgeschlossen &middot; nur esp32s3-Chips werden angefasst
      </footer>
    </div>
    """
  end

  # --- Events ---

  @impl true
  def handle_event("toggle-auto-flash", _params, socket) do
    FlashStation.set_auto_flash(!socket.assigns.auto_flash)
    {:noreply, socket}
  end

  def handle_event("confirm-flash", %{"port" => port, "target" => target}, socket) do
    FlashStation.confirm_flash(port, String.to_existing_atom(target))
    {:noreply, socket}
  end

  def handle_event("dismiss", %{"port" => port}, socket) do
    FlashStation.dismiss(port)
    {:noreply, socket}
  end

  def handle_event("sync-now", _params, socket) do
    FirmwareSync.sync_now()
    {:noreply, socket}
  end

  # --- PubSub ---

  @impl true
  def handle_info({:flash_station, :auto_flash_changed, %{auto_flash: auto_flash}}, socket) do
    {:noreply, assign(socket, auto_flash: auto_flash)}
  end

  def handle_info({:flash_station, :devices_changed, %{devices: devices}}, socket) do
    {:noreply, assign(socket, devices: devices)}
  end

  def handle_info({:flash_station, _event, _payload}, socket), do: {:noreply, socket}

  def handle_info({:firmware_sync, event, _payload}, socket) when event in [:synced, :sync_failed] do
    {:noreply, assign(socket, sync_status: FirmwareSync.get_status())}
  end

  # --- Helpers ---

  defp format_time(nil), do: "noch nie"
  defp format_time(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")

  defp staged_label(nil), do: "nicht vorhanden"
  defp staged_label(%{synced_at: nil}), do: "lokal vorhanden (vor App-Start)"
  defp staged_label(%{synced_at: %DateTime{} = dt}), do: "aktualisiert " <> format_time(dt)

  defp status_label(:awaiting_confirm), do: "wartet auf Bestätigung"
  defp status_label(:flashing), do: "flasht..."
  defp status_label(:done), do: "fertig"
  defp status_label(:error), do: "Fehler"

  defp status_badge_class(:awaiting_confirm), do: "badge-info"
  defp status_badge_class(:flashing), do: "badge-active"
  defp status_badge_class(:done), do: "badge-ok"
  defp status_badge_class(:error), do: "badge-err"
end
