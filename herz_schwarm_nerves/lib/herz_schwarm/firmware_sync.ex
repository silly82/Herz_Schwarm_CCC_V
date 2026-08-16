defmodule HerzSchwarm.FirmwareSync do
  @moduledoc """
  Synct die neueste Badge-/Basisstation-Firmware vom GitHub-Release dieses
  Repos auf die lokale (persistente) Firmware-Ablage (`:firmware_dir`),
  damit `HerzSchwarm.FlashStation` sie offline am Event nutzen kann.

  Erwartete Asset-Namen im GitHub-Release: `badge-firmware.bin`,
  `basestation-firmware.bin` (stabile Namen statt versionierter Dateinamen,
  damit der Client nicht parsen muss). Diese Konvention existiert bisher
  NUR hier — `scripts/version.sh tag` erzeugt aktuell nur den Git-Tag, noch
  keinen GitHub-Release mit angehängten Binaries. Das ist ein offener
  Folge-Schritt (`gh release create` o.ä. in den Release-Prozess
  einbinden), nicht Teil dieses Skeletons.

  Sinnvoll nur, wenn der Pi online ist (typischerweise zuhause vor dem
  Event). Am Event selbst läuft alles rein lokal aus `:firmware_dir`, kein
  Netz nötig — ein fehlgeschlagener Sync ist daher nie fatal, nur geloggt.
  """

  use GenServer
  require Logger

  @pubsub HerzSchwarm.PubSub
  @topic "firmware_sync:events"
  @sync_interval_ms :timer.hours(6)
  @assets %{badge: "badge-firmware.bin", basestation: "basestation-firmware.bin"}

  defstruct last_synced_at: nil, staged: %{badge: nil, basestation: nil}, last_error: nil

  @type staged_info :: %{path: String.t(), synced_at: DateTime.t() | nil}
  @type status :: %{
          last_synced_at: DateTime.t() | nil,
          staged: %{badge: staged_info() | nil, basestation: staged_info() | nil},
          last_error: term() | nil
        }

  # --- Public API ---

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def topic, do: @topic

  @spec get_status() :: status()
  def get_status, do: GenServer.call(__MODULE__, :get_status)

  @doc "Stößt sofort einen Sync an (asynchron, Ergebnis kommt per PubSub + get_status/0)."
  def sync_now, do: GenServer.cast(__MODULE__, :sync_now)

  @doc "Lokaler Pfad der aktuell gestagten Firmware für :badge oder :basestation, falls vorhanden."
  @spec local_path(:badge | :basestation) :: String.t() | nil
  def local_path(target) when target in [:badge, :basestation] do
    path = Path.join(firmware_dir(), Map.fetch!(@assets, target))
    if File.exists?(path), do: path
  end

  # --- Callbacks ---

  @impl true
  def init(_opts) do
    File.mkdir_p(firmware_dir())
    schedule_sync()
    {:ok, %__MODULE__{staged: scan_local_staged()}}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply,
     %{last_synced_at: state.last_synced_at, staged: state.staged, last_error: state.last_error},
     state}
  end

  @impl true
  def handle_cast(:sync_now, state) do
    {:noreply, do_sync(state)}
  end

  @impl true
  def handle_info(:sync, state) do
    schedule_sync()
    {:noreply, do_sync(state)}
  end

  # --- Internals ---

  defp do_sync(state) do
    case fetch_latest_release() do
      {:ok, release} ->
        staged = download_assets(release)
        state = %{state | last_synced_at: DateTime.utc_now(), staged: staged, last_error: nil}
        broadcast(:synced, %{staged: staged})
        state

      {:error, reason} ->
        Logger.warning("FirmwareSync: Sync fehlgeschlagen (bleibt bei lokalem Stand): #{inspect(reason)}")
        state = %{state | last_error: reason}
        broadcast(:sync_failed, %{reason: reason})
        state
    end
  end

  defp fetch_latest_release do
    repo = Application.fetch_env!(:herz_schwarm, :firmware_github_repo)
    url = String.to_charlist("https://api.github.com/repos/#{repo}/releases/latest")

    case http_get(url) do
      {:ok, body} -> {:ok, Jason.decode!(body)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp download_assets(release) do
    assets = Map.get(release, "assets", [])

    Enum.reduce(@assets, %{badge: nil, basestation: nil}, fn {target, filename}, acc ->
      case Enum.find(assets, &(&1["name"] == filename)) do
        nil ->
          Logger.debug("FirmwareSync: Asset #{filename} nicht im Release gefunden, überspringe #{target}")
          Map.put(acc, target, Map.get(scan_local_staged(), target))

        %{"browser_download_url" => download_url} ->
          case http_get(String.to_charlist(download_url)) do
            {:ok, body} ->
              path = Path.join(firmware_dir(), filename)
              File.write!(path, body)
              Logger.info("FirmwareSync: #{target} aktualisiert (#{filename}, #{byte_size(body)} Bytes)")
              Map.put(acc, target, %{path: path, synced_at: DateTime.utc_now()})

            {:error, reason} ->
              Logger.warning("FirmwareSync: Download von #{filename} fehlgeschlagen: #{inspect(reason)}")
              Map.put(acc, target, Map.get(scan_local_staged(), target))
          end
      end
    end)
  end

  defp http_get(url) do
    ensure_started()

    headers = [{~c"user-agent", ~c"herz-schwarm-firmware-sync"}]
    ssl_opts = [verify: :verify_peer, cacertfile: CAStore.file_path(), depth: 3]
    http_opts = [ssl: ssl_opts, autoredirect: true, timeout: 30_000]

    case :httpc.request(:get, {url, headers}, http_opts, [body_format: :binary]) do
      {:ok, {{_, 200, _}, _headers, body}} -> {:ok, body}
      {:ok, {{_, status, _}, _headers, _body}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_started do
    Application.ensure_all_started(:inets)
    Application.ensure_all_started(:ssl)
  end

  defp scan_local_staged do
    Map.new(@assets, fn {target, filename} ->
      path = Path.join(firmware_dir(), filename)
      info = if File.exists?(path), do: %{path: path, synced_at: nil}
      {target, info}
    end)
  end

  defp firmware_dir, do: Application.fetch_env!(:herz_schwarm, :firmware_dir)

  defp schedule_sync, do: Process.send_after(self(), :sync, @sync_interval_ms)

  defp broadcast(event, payload) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:firmware_sync, event, payload})
  end
end
