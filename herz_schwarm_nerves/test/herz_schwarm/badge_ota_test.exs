defmodule HerzSchwarm.BadgeOtaTest do
  use ExUnit.Case, async: false

  alias HerzSchwarm.{BadgeOta, Bridge}

  @moduletag :capture_log

  # Kleinstes "Image", das die Pruefungen besteht: ESP-Magic 0xE9 + Versions-Marker.
  defp image(version \\ "1.7.0") do
    <<0xE9, 1, 2, 3>> <> "irgendwas" <> "HERZFW:" <> version <> ";" <> <<0, 255, 254>> <> "rest"
  end

  defp tmp_dir do
    dir = Path.join(System.tmp_dir!(), "badge_ota_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp start_ota(dir) do
    name = :"badge_ota_#{System.unique_integer([:positive])}"
    start_supervised!({BadgeOta, name: name, dir: dir})
    name
  end

  describe "parse_version/1" do
    test "liest den Marker HERZFW:x.y.z;" do
      assert BadgeOta.parse_version(image("1.7.0")) == {:ok, {1, 7, 0}}
      assert BadgeOta.parse_version(image("12.34.56")) == {:ok, {12, 34, 56}}
    end

    test "ohne Marker, unvollstaendig oder ausserhalb eines Bytes -> :error" do
      assert BadgeOta.parse_version(<<0xE9, 0, 0>>) == :error
      assert BadgeOta.parse_version("HERZFW:1.7") == :error
      assert BadgeOta.parse_version("HERZFW:1.7.0") == :error
      assert BadgeOta.parse_version("HERZFW:1.300.0;") == :error
    end
  end

  describe "inspect_image/1" do
    test "liefert Groesse, MD5 und Version" do
      bin = image()

      assert {:ok, %{size: size, md5: md5, version: {1, 7, 0}}} = BadgeOta.inspect_image(bin)
      assert size == byte_size(bin)
      assert md5 == :erlang.md5(bin)
    end

    test "weist leere, fremde und zu grosse Dateien ab" do
      assert BadgeOta.inspect_image("") == {:error, :empty_image}
      assert BadgeOta.inspect_image("kein esp image HERZFW:1.7.0;") == {:error, :not_an_esp_image}
      assert BadgeOta.inspect_image(<<0xE9, 1, 2, 3>>) == {:error, :no_version_marker}

      too_big = <<0xE9>> <> :binary.copy(<<0>>, 1_310_720)
      assert BadgeOta.inspect_image(too_big) == {:error, :image_too_large}
    end
  end

  describe "build_packet/5" do
    # Referenz unabhaengig mit Python berechnet (struct.pack + hmac/sha256, Schluessel "test-key"):
    # dieselbe Bytefolge erwartet die Badge-Firmware (struct OtaTrigger, 54 Byte).
    test "entspricht dem Referenzpaket" do
      meta = %{size: 1000, md5: :binary.list_to_bin(Enum.to_list(0..15)), version: {1, 7, 0}}
      packet = BadgeOta.build_packet(meta, {192, 168, 4, 1}, 4000, "test-key", 0x12345678)

      assert byte_size(packet) == 54

      assert Base.encode16(packet, case: :lower) ==
               "cc37134200000000785634120d00000000010700c0a80401a00fe803000000" <>
                 "0102030405060708090a0b0c0d0e0ff799c69175854ec2"
    end

    test "anderer Schluessel -> anderer Tag, gleicher signierter Teil" do
      meta = %{size: 1000, md5: :binary.copy(<<7>>, 16), version: {1, 7, 0}}
      a = BadgeOta.build_packet(meta, {10, 0, 0, 1}, 4000, "schluessel-a", 100_001)
      b = BadgeOta.build_packet(meta, {10, 0, 0, 1}, 4000, "schluessel-b", 100_001)

      assert binary_part(a, 0, 46) == binary_part(b, 0, 46)
      assert binary_part(a, 46, 8) != binary_part(b, 46, 8)
    end
  end

  describe "parse_ip/1 und format_ip/1" do
    test "IPv4 hin und zurueck" do
      assert BadgeOta.parse_ip(" 192.168.4.1 ") == {:ok, {192, 168, 4, 1}}
      assert BadgeOta.format_ip({192, 168, 4, 1}) == "192.168.4.1"
      assert BadgeOta.parse_ip("192.168.4") == :error
      assert BadgeOta.parse_ip("herz.local") == :error
    end
  end

  describe "Ablage" do
    test "store_image legt die Datei ab, info liefert sie, ein Neustart nimmt sie wieder auf" do
      dir = tmp_dir()
      src = Path.join(dir, "upload.bin")
      File.write!(src, image("1.8.2"))

      ota = start_ota(dir)
      assert BadgeOta.info(ota) == nil

      assert {:ok, info} = BadgeOta.store_image(src, ota)
      assert info.version == {1, 8, 2}
      assert info.path == Path.join(dir, "badge.bin")
      assert File.read!(info.path) == image("1.8.2")
      assert BadgeOta.info(ota) == info

      # Zweite Instanz auf demselben Verzeichnis: laedt die abgelegte Datei beim Start
      other = start_ota_named(dir)
      assert BadgeOta.info(other) == info
    end

    test "ungueltige Datei wird abgewiesen und ersetzt die abgelegte nicht" do
      dir = tmp_dir()
      good = Path.join(dir, "good.bin")
      bad = Path.join(dir, "bad.bin")
      File.write!(good, image())
      File.write!(bad, "kein image")

      ota = start_ota(dir)
      assert {:ok, info} = BadgeOta.store_image(good, ota)
      assert BadgeOta.store_image(bad, ota) == {:error, :not_an_esp_image}
      assert BadgeOta.store_image(Path.join(dir, "fehlt.bin"), ota) ==
               {:error, {:read_failed, :enoent}}

      assert BadgeOta.info(ota) == info
    end

    test "ohne Verzeichnis (dir: nil) ist keine Ablage moeglich" do
      ota = start_ota(nil)
      assert BadgeOta.store_image("egal.bin", ota) == {:error, :no_store}
    end
  end

  describe "trigger/3" do
    setup do
      old_env = System.get_env("BADGE_OTA_KEY")
      old_cfg = Application.get_env(:herz_schwarm, :badge_ota_key)
      System.delete_env("BADGE_OTA_KEY")
      Application.delete_env(:herz_schwarm, :badge_ota_key)

      original = :sys.get_state(Bridge)
      test_pid = self()

      :sys.replace_state(Bridge, fn st ->
        write = fn _pid, data ->
          send(test_pid, {:wire, Jason.decode!(data)})
          :ok
        end

        %{st | connected: true, uart_pid: :fake, write: write}
      end)

      on_exit(fn ->
        if old_env, do: System.put_env("BADGE_OTA_KEY", old_env)

        if old_cfg,
          do: Application.put_env(:herz_schwarm, :badge_ota_key, old_cfg),
          else: Application.delete_env(:herz_schwarm, :badge_ota_key)

        :sys.replace_state(Bridge, fn st ->
          %{
            st
            | connected: original.connected,
              uart_pid: original.uart_pid,
              write: original.write,
              pending: %{}
          }
        end)
      end)

      dir = tmp_dir()
      src = Path.join(dir, "upload.bin")
      File.write!(src, image("1.7.3"))
      {:ok, dir: dir, src: src}
    end

    test "ohne abgelegte Firmware -> :no_image", %{dir: dir} do
      ota = start_ota(dir)
      assert BadgeOta.trigger({192, 168, 4, 1}, 4000, ota) == {:error, :no_image}
      refute_received {:wire, _}
    end

    test "ohne Schluessel -> :no_key, nichts geht auf den Draht", %{dir: dir, src: src} do
      ota = start_ota(dir)
      {:ok, _} = BadgeOta.store_image(src, ota)

      assert BadgeOta.trigger({192, 168, 4, 1}, 4000, ota) == {:error, :no_key}
      refute_received {:wire, _}
    end

    test "sendet badge_ota mit signiertem 54-Byte-Paket", %{dir: dir, src: src} do
      Application.put_env(:herz_schwarm, :badge_ota_key, "geheim")
      ota = start_ota(dir)
      {:ok, info} = BadgeOta.store_image(src, ota)

      assert {:ok, id} = BadgeOta.trigger({192, 168, 4, 1}, 4000, ota)
      assert id > 99_999

      assert_receive {:wire, %{"cmd" => "badge_ota", "pkt" => b64, "seq" => seq}}
      assert is_integer(seq)
      packet = Base.decode64!(b64)
      assert packet == BadgeOta.build_packet(info, {192, 168, 4, 1}, 4000, "geheim", id)

      <<0x421337CC::little-32, _beat::little-32, ^id::little-32, 13, 0, _station::binary-3, 1, 7,
        3, 192, 168, 4, 1, 4000::little-16, size::little-32, md5::binary-16,
        tag::binary-8>> = packet

      assert size == info.size
      assert md5 == info.md5
      assert tag == binary_part(:crypto.mac(:hmac, :sha256, "geheim", binary_part(packet, 0, 46)), 0, 8)
    end

    test "getrennte Bridge -> Fehler wird durchgereicht", %{dir: dir, src: src} do
      Application.put_env(:herz_schwarm, :badge_ota_key, "geheim")
      :sys.replace_state(Bridge, fn st -> %{st | connected: false} end)
      ota = start_ota(dir)
      {:ok, _} = BadgeOta.store_image(src, ota)

      assert BadgeOta.trigger({192, 168, 4, 1}, 4000, ota) == {:error, :not_connected}
    end
  end

  # Zweite Instanz unter anderer Supervisor-ID (start_supervised! erlaubt jede ID nur einmal).
  defp start_ota_named(dir) do
    name = :"badge_ota_#{System.unique_integer([:positive])}"
    start_supervised!(Supervisor.child_spec({BadgeOta, name: name, dir: dir}, id: name))
    name
  end
end
