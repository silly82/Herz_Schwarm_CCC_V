defmodule HerzSchwarm.BadgeOta do
  @moduledoc """
  Funk-Update der Badges (Badge-FW >= 1.7.0, Bridge-FW >= 0.5.0).

  Ablauf:

    1. Eine Badge-Firmware (`.bin`) wird hochgeladen und hier abgelegt
       (`store_image/1`). Groesse, MD5 und Version (Marker `HERZFW:x.y.z;` im
       Binary) werden dabei gelesen.
    2. Die App liefert die Datei unter `GET /firmware/badge.bin` aus.
    3. `trigger/2` baut den signierten Ausloeser (Modus 13) und schickt ihn ueber
       die Bridge in den Schwarm. Badges mit aelterer Firmware melden sich am
       WLAN aus ihrer `ota_secret.h` an, laden die Datei von der angegebenen
       Adresse, pruefen Groesse und MD5 und starten neu.

  ## Paket (54 Byte, little-endian, identisch zu `OtaTrigger` in der Badge-Firmware)

      magic(4) beatCounter(4) id(4) mode=13(1) ver_major=0(1) ver_minor(1) ver_rel(1) ver_dbg(1)
      ziel_major(1) ziel_minor(1) ziel_patch(1) ip(4) port(2) groesse(4) md5(16) tag(8)

  `tag` sind die ersten 8 Byte von HMAC-SHA256 ueber die 46 Byte davor, mit dem
  gemeinsamen Schluessel (`BADGE_OTA_KEY` hier, `OTA_KEY` in `ota_secret.h`).
  Die Stations-Version im Kopf ist 0.0.0 — Badges erkennen daran eine Station.

  ## Konfiguration

    * Schluessel: Umgebungsvariable `BADGE_OTA_KEY`, sonst
      `config :herz_schwarm, :badge_ota_key`. Ohne Schluessel kein Ausloeser.
    * Ablage: `config :herz_schwarm, :badge_ota_dir`
      (Default `~/.local/share/herz-schwarm`, `nil` = keine Ablage, z. B. in Tests).
  """

  use GenServer
  require Logger

  alias HerzSchwarm.{Bridge, EventLog}

  @magic 0x421337CC
  @mode_ota 13
  @tag_len 8
  @packet_len 54
  # Erstes Byte eines ESP-App-Images (ESP_IMAGE_HEADER_MAGIC)
  @image_magic 0xE9
  # App-Slot der Badges (Partition-Schema "default", 4 MB Flash): 0x140000
  @max_image_bytes 1_310_720
  @marker "HERZFW:"
  @file_name "badge.bin"
  @default_dir "~/.local/share/herz-schwarm"

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Abgelegte Firmware: `%{path:, size:, md5:, version: {maj, min, patch}}` oder `nil`.
  """
  def info(server \\ __MODULE__), do: GenServer.call(server, :info)

  @doc """
  Prueft die Datei `src` und legt sie als aktuelle Badge-Firmware ab.
  `{:ok, info}` oder `{:error, reason}`.
  """
  def store_image(src, server \\ __MODULE__) do
    GenServer.call(server, {:store, src}, 30_000)
  end

  @doc """
  Sendet den Update-Ausloeser. `ip` ist die Adresse dieses Rechners im WLAN der
  Badges (`{a, b, c, d}`), `port` der HTTP-Port der App. `{:ok, id}` oder
  `{:error, reason}` (`:no_image`, `:no_key`, `:not_connected`, ...).
  """
  def trigger(ip, port, server \\ __MODULE__) do
    GenServer.call(server, {:trigger, ip, port})
  end

  @doc "Gemeinsamer Schluessel oder `nil`."
  def key do
    case System.get_env("BADGE_OTA_KEY") || Application.get_env(:herz_schwarm, :badge_ota_key) do
      key when is_binary(key) and key != "" -> key
      _ -> nil
    end
  end

  def key_configured?, do: key() != nil

  @doc "Ablage-Verzeichnis (Config `:badge_ota_dir`) oder `nil`."
  def store_dir do
    case Application.get_env(:herz_schwarm, :badge_ota_dir, @default_dir) do
      nil -> nil
      dir -> Path.expand(dir)
    end
  end

  # --- Reine Hilfsfunktionen (ohne Hardware testbar) ---

  @doc """
  Liest Groesse, MD5 und Version aus einem Firmware-Image.
  `{:ok, %{size:, md5:, version:}}` oder `{:error, reason}`.
  """
  def inspect_image(bin) when is_binary(bin) do
    cond do
      byte_size(bin) == 0 ->
        {:error, :empty_image}

      byte_size(bin) > @max_image_bytes ->
        {:error, :image_too_large}

      :binary.first(bin) != @image_magic ->
        {:error, :not_an_esp_image}

      true ->
        case parse_version(bin) do
          {:ok, version} ->
            {:ok, %{size: byte_size(bin), md5: :erlang.md5(bin), version: version}}

          :error ->
            {:error, :no_version_marker}
        end
    end
  end

  @doc """
  Sucht den Marker `HERZFW:x.y.z;` (ab Badge-FW 1.7.0 im Binary).
  `{:ok, {maj, min, patch}}` oder `:error`.
  """
  def parse_version(bin) when is_binary(bin) do
    with {pos, len} <- :binary.match(bin, @marker),
         start = pos + len,
         rest = binary_part(bin, start, min(12, byte_size(bin) - start)),
         [_, a, b, c] <- Regex.run(~r/\A(\d{1,3})\.(\d{1,3})\.(\d{1,3});/, rest),
         version = {String.to_integer(a), String.to_integer(b), String.to_integer(c)},
         true <- version |> Tuple.to_list() |> Enum.all?(&(&1 <= 255)) do
      {:ok, version}
    else
      _ -> :error
    end
  end

  @doc """
  Baut den signierten Ausloeser (54 Byte). `image` wie aus `inspect_image/1`,
  `id` ist die Kennung des Ausloesers (32 Bit, nie 0).
  """
  def build_packet(
        %{size: size, md5: md5, version: {maj, min, patch}},
        {a, b, c, d},
        port,
        key,
        id
      )
      when byte_size(md5) == 16 and is_binary(key) and port in 1..65_535 and
             id in 1..0xFFFFFFFF do
    signed =
      <<@magic::little-32, 0::little-32, id::little-32, @mode_ota, 0, 0, 0, 0, maj, min, patch, a,
        b, c, d, port::little-16, size::little-32, md5::binary>>

    tag = :hmac |> :crypto.mac(:sha256, key, signed) |> binary_part(0, @tag_len)
    packet = signed <> tag
    @packet_len = byte_size(packet)
    packet
  end

  @doc ~s(Parst "192.168.4.1" zu `{:ok, {192, 168, 4, 1}}` oder `:error`.)
  def parse_ip(str) when is_binary(str) do
    case str |> String.trim() |> String.to_charlist() |> :inet.parse_ipv4strict_address() do
      {:ok, ip} -> {:ok, ip}
      {:error, _} -> :error
    end
  end

  @doc ~s(Formatiert `{192, 168, 4, 1}` als "192.168.4.1".)
  def format_ip(ip) when is_tuple(ip), do: ip |> :inet.ntoa() |> to_string()

  @doc ~s(Formatiert `{1, 7, 0}` als "1.7.0".)
  def format_version({maj, min, patch}), do: "#{maj}.#{min}.#{patch}"

  @doc "IPv4-Adressen dieses Rechners (ohne Loopback) als Vorschlag fuer die Server-Adresse."
  def local_ips do
    case :inet.getifaddrs() do
      {:ok, ifs} ->
        for {_name, opts} <- ifs,
            {:addr, {first, _, _, _} = ip} <- opts,
            first != 127,
            uniq: true,
            do: ip

      _ ->
        []
    end
  end

  # --- Callbacks ---

  @impl true
  def init(opts) do
    dir = Keyword.get_lazy(opts, :dir, &store_dir/0)
    {:ok, %{dir: dir, info: load(dir)}}
  end

  @impl true
  def handle_call(:info, _from, state), do: {:reply, state.info, state}

  def handle_call({:store, _src}, _from, %{dir: nil} = state) do
    {:reply, {:error, :no_store}, state}
  end

  def handle_call({:store, src}, _from, state) do
    path = Path.join(state.dir, @file_name)
    tmp = path <> ".tmp"

    result =
      with {:ok, bin} <- read(src),
           {:ok, meta} <- inspect_image(bin),
           :ok <- File.mkdir_p(state.dir),
           :ok <- File.write(tmp, bin),
           :ok <- File.rename(tmp, path) do
        {:ok, Map.put(meta, :path, path)}
      end

    case result do
      {:ok, info} ->
        EventLog.log(
          :info,
          "badge-ota",
          "Badge-Firmware #{format_version(info.version)} abgelegt (#{info.size} Byte)"
        )

        {:reply, {:ok, info}, %{state | info: info}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:trigger, _ip, _port}, _from, %{info: nil} = state) do
    {:reply, {:error, :no_image}, state}
  end

  def handle_call({:trigger, ip, port}, _from, state) do
    reply =
      case key() do
        nil ->
          {:error, :no_key}

        key ->
          id = new_id()
          packet = build_packet(state.info, ip, port, key, id)

          case Bridge.send_command(%{cmd: "badge_ota", pkt: Base.encode64(packet)}) do
            {:ok, _seq} ->
              EventLog.log(
                :info,
                "badge-ota",
                "Update-Ausloeser gesendet: #{format_version(state.info.version)} von " <>
                  "#{format_ip(ip)}:#{port}"
              )

              {:ok, id}

            {:error, reason} ->
              {:error, reason}
          end
      end

    {:reply, reply, state}
  end

  # --- intern ---

  defp read(src) do
    case File.read(src) do
      {:ok, bin} -> {:ok, bin}
      {:error, reason} -> {:error, {:read_failed, reason}}
    end
  end

  # Beim Start: vorhandene Datei wieder aufnehmen. Kaputt oder fehlend -> nichts abgelegt.
  defp load(nil), do: nil

  defp load(dir) do
    path = Path.join(dir, @file_name)

    with {:ok, bin} <- File.read(path),
         {:ok, meta} <- inspect_image(bin) do
      Map.put(meta, :path, path)
    else
      {:error, :enoent} ->
        nil

      other ->
        Logger.warning("BadgeOta: #{path} nicht nutzbar (#{inspect(other)})")
        nil
    end
  end

  # Kennung des Ausloesers: zufaellig, nie 0 und ausserhalb des Morse-Bereichs 1..99_999
  # (wie die Effekt-IDs in HerzSchwarm.EffectEngine).
  defp new_id, do: :rand.uniform(0xFFFFFFFF - 100_000) + 100_000
end
