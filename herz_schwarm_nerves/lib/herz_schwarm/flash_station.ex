defmodule HerzSchwarm.FlashStation do
  @moduledoc """
  Erkennt an den Pi angesteckte ESP32-Geräte (Badges/Basisstation) und
  flasht sie mit der lokal gestagten Firmware (siehe `HerzSchwarm.FirmwareSync`).

  Sicherheits-Leitplanken:
  - Der über `:uart_device` konfigurierte Bridge-Port wird NIE als Flash-Ziel
    betrachtet (fest ausgeschlossen, siehe `scan_ports/1`).
  - Badge und Basisstation sind beide `esp32:esp32:esp32s3` — identische
    Chip-ID, dadurch nicht automatisch unterscheidbar. Die Ziel-Firmware
    muss immer explizit gewählt werden (`confirm_flash/2`); im
    Auto-Flash-Modus wird IMMER `:badge` angenommen, nie `:basestation` —
    das ist die einzige sichere Annahme für den "Besucher steckt Badge an"-
    Walk-up-Fall. Basisstation-Updates laufen deshalb auch bei
    aktiviertem Auto-Flash immer über die explizite Bestätigung.

  Portnamen-Falle: `Circuits.UART.enumerate/0` liefert auf macOS volle Pfade
  (`/dev/cu.usbmodem101`), auf Linux (das eigentliche Nerves-Target) aber
  nur den blossen Devicenamen ohne Prefix (`ttyUSB0`, siehe
  `uart_enum_linux.c`). Der konfigurierte Bridge-Port ist mit `/dev/`-Prefix
  hinterlegt. Ein naiver String-Vergleich würde auf dem Pi den Bridge-Port
  NICHT erkennen und die Ausschluss-Logik aushebeln — deshalb wird für den
  Vergleich immer `Path.basename/1` auf beide Seiten angewendet.
  """

  use GenServer
  require Logger

  alias HerzSchwarm.Flasher

  @pubsub HerzSchwarm.PubSub
  @topic "flash_station:events"
  @poll_interval_ms 2_000

  defstruct auto_flash: false, devices: %{}

  @type device :: %{
          status: :awaiting_confirm | :flashing | :done | :error,
          chip: Flasher.chip(),
          target: Flasher.target() | nil,
          detected_at: DateTime.t(),
          result: :ok | {:error, term()} | nil
        }

  # --- Public API ---

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def topic, do: @topic

  @doc "Aktueller Zustand: %{auto_flash: bool, devices: %{port => device}}"
  def get_state, do: GenServer.call(__MODULE__, :get_state)

  def set_auto_flash(enabled) when is_boolean(enabled) do
    GenServer.call(__MODULE__, {:set_auto_flash, enabled})
  end

  @doc "Nutzer bestätigt den Flash für ein erkanntes Gerät und wählt die Ziel-Firmware."
  def confirm_flash(port, target) when target in [:badge, :basestation] do
    GenServer.cast(__MODULE__, {:confirm_flash, port, target})
  end

  @doc "Entfernt ein Gerät aus der Liste (z. B. nach Abstecken oder um einen Fehler wegzuklicken)."
  def dismiss(port), do: GenServer.cast(__MODULE__, {:dismiss, port})

  # --- Callbacks ---

  @impl true
  def init(_opts) do
    schedule_poll()
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, %{auto_flash: state.auto_flash, devices: state.devices}, state}
  end

  def handle_call({:set_auto_flash, enabled}, _from, state) do
    state = %{state | auto_flash: enabled}
    broadcast(:auto_flash_changed, %{auto_flash: enabled})
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast({:confirm_flash, port, target}, state) do
    case Map.get(state.devices, port) do
      %{status: :awaiting_confirm} = device ->
        device = %{device | status: :flashing, target: target}
        state = put_device(state, port, device)
        start_flash(port, target)
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_cast({:dismiss, port}, state) do
    {:noreply, %{state | devices: Map.delete(state.devices, port)}}
  end

  @impl true
  def handle_info(:poll, state) do
    schedule_poll()
    {:noreply, scan_ports(state)}
  end

  def handle_info({:flash_result, port, result}, state) do
    case Map.get(state.devices, port) do
      nil ->
        {:noreply, state}

      device ->
        status = if result == :ok, do: :done, else: :error
        device = %{device | status: status, result: result}
        {:noreply, put_device(state, port, device)}
    end
  end

  # --- Internals ---

  defp scan_ports(state) do
    bridge_port = normalize(Application.get_env(:herz_schwarm, :uart_device))
    live_ports = Circuits.UART.enumerate() |> Map.keys()

    new_ports =
      live_ports
      |> Enum.reject(&(normalize(&1) == bridge_port))
      |> Enum.reject(&Map.has_key?(state.devices, &1))

    state = Enum.reduce(new_ports, state, &handle_new_port(&2, &1))
    drop_unplugged(state, live_ports)
  end

  defp normalize(nil), do: nil
  defp normalize(port), do: Path.basename(port)

  defp handle_new_port(state, port) do
    case Flasher.identify_chip(port) do
      {:ok, :esp32s3} ->
        auto = state.auto_flash

        device = %{
          status: if(auto, do: :flashing, else: :awaiting_confirm),
          chip: :esp32s3,
          target: if(auto, do: :badge, else: nil),
          detected_at: DateTime.utc_now(),
          result: nil
        }

        state = put_device(state, port, device)
        broadcast(:device_detected, %{port: port, chip: :esp32s3, auto_flash: auto})

        if auto, do: start_flash(port, :badge)
        state

      {:ok, other} ->
        Logger.info(
          "FlashStation: #{port} identifiziert als #{inspect(other)}, kein Badge/Basisstation-Ziel — ignoriert"
        )

        state

      {:error, reason} ->
        Logger.debug("FlashStation: Chip-Erkennung an #{port} fehlgeschlagen: #{inspect(reason)}")
        state
    end
  end

  defp drop_unplugged(state, live_ports) do
    devices = Map.filter(state.devices, fn {port, _device} -> port in live_ports end)
    %{state | devices: devices}
  end

  defp start_flash(port, target) do
    parent = self()

    Task.start(fn ->
      result = Flasher.flash(port, target)
      send(parent, {:flash_result, port, result})
    end)
  end

  defp put_device(state, port, device) do
    state = %{state | devices: Map.put(state.devices, port, device)}
    broadcast(:devices_changed, %{devices: state.devices})
    state
  end

  defp schedule_poll, do: Process.send_after(self(), :poll, @poll_interval_ms)

  defp broadcast(event, payload) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:flash_station, event, payload})
  end
end
