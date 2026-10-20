defmodule HerzSchwarm.TapCounterTest do
  use ExUnit.Case, async: false

  alias HerzSchwarm.{EventLog, TapCounter}

  @moduletag :capture_log

  @mac "AA:BB:CC:DD:EE:FF"
  @mac2 "11:22:33:44:55:66"

  defp tap_evt(mac, n), do: {:bridge, %{"evt" => "tap", "mac" => mac, "count" => n}}

  # Startet eine eigene Instanz (kein Persistenz-Pfad, sofern nicht angegeben).
  defp start_tc(opts \\ []) do
    name = :"tc_#{System.unique_integer([:positive])}"
    opts = Keyword.merge([name: name, path: nil], opts)
    start_supervised!({TapCounter, opts})
    name
  end

  # Verarbeitet alle bisher eingetroffenen Nachrichten (call ist synchron nach ihnen).
  defp sync(name), do: TapCounter.state(name)

  defp count(state, mac), do: get_in(state, [:badges, mac, :count])

  describe "Merge ueber Maximum" do
    test "hoeherer Wert gewinnt, niedrigerer und 0 werden ignoriert" do
      name = start_tc()

      send(name, tap_evt(@mac, 5))
      send(name, tap_evt(@mac, 3))
      send(name, tap_evt(@mac, 0))
      send(name, tap_evt(@mac, 7))

      state = sync(name)
      assert count(state, @mac) == 7
      assert state.total == 7
    end

    test "Doppelmeldung erzeugt keine Doppelzaehlung" do
      name = start_tc()

      send(name, tap_evt(@mac, 5))
      send(name, tap_evt(@mac, 5))

      assert sync(name).total == 5
    end

    test "Summe ueber mehrere Badges, MAC wird normalisiert (Grossbuchstaben)" do
      name = start_tc()

      send(name, tap_evt("aa:bb:cc:dd:ee:ff", 4))
      send(name, tap_evt(@mac2, 6))

      state = sync(name)
      assert Map.keys(state.badges) |> Enum.sort() == Enum.sort([@mac, @mac2])
      assert state.total == 10
      assert %DateTime{} = state.badges[@mac].last_seen
      assert %DateTime{} = state.updated_at
    end

    test "andere Bridge-Events und ungueltige Taps werden ignoriert" do
      name = start_tc()

      send(name, {:bridge, :connected})
      send(name, {:bridge, %{"evt" => "pong"}})
      send(name, tap_evt(@mac, 0))
      send(name, {:bridge, %{"evt" => "tap", "mac" => @mac, "count" => "12"}})

      state = sync(name)
      assert state.total == 0
      assert state.badges == %{}
      assert state.updated_at == nil
    end

    test "leerer Zustand" do
      name = start_tc()
      assert %{total: 0, badges: %{}, updated_at: nil} = TapCounter.state(name)
    end

    test "Speicher ist auf 64 MACs begrenzt" do
      name = start_tc()

      for i <- 1..70 do
        send(
          name,
          tap_evt("00:00:00:00:00:#{String.pad_leading(Integer.to_string(i, 16), 2, "0")}", 1)
        )
      end

      assert map_size(sync(name).badges) == 64
    end

    test "je 100 Taps eines Badges gibt es einen EventLog-Meilenstein" do
      EventLog.clear()
      name = start_tc()

      send(name, tap_evt(@mac, 99))
      send(name, tap_evt(@mac, 100))
      sync(name)

      assert Enum.any?(EventLog.entries(), &(&1.message == "Badge #{@mac}: 100 Taps erreicht"))
    end
  end

  describe "reset/1" do
    test "Anzeige geht auf 0, weitere Taps zaehlen ab 0, Rohstand bleibt erhalten" do
      name = start_tc()

      send(name, tap_evt(@mac, 5))
      assert :ok = TapCounter.reset(name)
      assert %{total: 0} = TapCounter.state(name)
      assert count(TapCounter.state(name), @mac) == 0

      send(name, tap_evt(@mac, 6))
      state = sync(name)
      assert count(state, @mac) == 1
      assert state.total == 1

      # Alte Rohstaende (<= 5) zaehlen nicht erneut.
      send(name, tap_evt(@mac, 5))
      assert sync(name).total == 1
    end
  end

  describe "Persistenz" do
    @tag :tmp_dir
    test "schreiben und nach Neustart wieder laden (inkl. Reset-Offset)", %{tmp_dir: dir} do
      path = Path.join(dir, "taps.json")
      name = start_tc(path: path)

      send(name, tap_evt(@mac, 5))
      send(name, tap_evt(@mac2, 2))
      TapCounter.reset(name)
      send(name, tap_evt(@mac, 6))
      sync(name)
      stop_supervised!(TapCounter)

      name2 = start_tc(path: path)
      state = TapCounter.state(name2)
      assert count(state, @mac) == 1
      assert count(state, @mac2) == 0
      assert state.total == 1
      assert %DateTime{} = state.badges[@mac].last_seen
    end

    @tag :tmp_dir
    test "fehlende Datei -> leerer Start, kaputte Datei -> leerer Start ohne Crash", %{
      tmp_dir: dir
    } do
      path = Path.join(dir, "taps.json")
      name = start_tc(path: path)
      assert TapCounter.state(name).total == 0
      stop_supervised!(TapCounter)

      File.write!(path, "{kaputt")
      name2 = start_tc(path: path)
      assert TapCounter.state(name2) == %{total: 0, badges: %{}, updated_at: nil}
    end

    @tag :tmp_dir
    test "Drosselung: nur die erste Aenderung schreibt sofort, terminate schreibt den Rest", %{
      tmp_dir: dir
    } do
      path = Path.join(dir, "taps.json")
      name = start_tc(path: path, save_interval_ms: 60_000)

      send(name, tap_evt(@mac, 1))
      sync(name)
      assert read_raw(path) == 1

      send(name, tap_evt(@mac, 2))
      sync(name)
      # innerhalb des Drosselintervalls kein weiteres Schreiben
      assert read_raw(path) == 1
      refute File.exists?(path <> ".tmp")

      stop_supervised!(TapCounter)
      assert read_raw(path) == 2
    end

    @tag :tmp_dir
    test "Schreibfehler crasht den Prozess nicht", %{tmp_dir: dir} do
      # Pfad, dessen Elternelement eine Datei ist -> mkdir_p schlaegt fehl.
      blocker = Path.join(dir, "blocker")
      File.write!(blocker, "x")
      name = start_tc(path: Path.join(blocker, "taps.json"))

      send(name, tap_evt(@mac, 3))
      assert sync(name).total == 3
      assert Process.alive?(Process.whereis(name))
    end
  end

  describe "Publikation" do
    test "{:taps, state} auf taps:state, letzte Aenderung kommt sicher an" do
      Phoenix.PubSub.subscribe(HerzSchwarm.PubSub, TapCounter.topic())
      name = start_tc(publish_interval_ms: 200)

      send(name, tap_evt(@mac, 1))
      assert_receive {:taps, %{total: 1}}, 1_000

      send(name, tap_evt(@mac, 2))
      send(name, tap_evt(@mac, 3))
      assert_receive {:taps, %{total: 3}}, 1_000
    end
  end

  describe "Badge-Limit: Gesamtsumme bleibt monoton (High-Water-Mark)" do
    test "Verdraengung senkt die Gesamtsumme nicht" do
      name = start_tc()

      for i <- 1..64, do: send(name, tap_evt(mac(i), 2))
      assert sync(name).total == 128

      send(name, tap_evt(mac(65), 1))
      state = sync(name)
      assert map_size(state.badges) == 64
      assert state.total == 129
    end

    test "verdraengtes Badge meldet sich wieder: keine Doppelzaehlung, nur neue Taps zaehlen" do
      name = start_tc()

      send(name, tap_evt(@mac, 5))
      for i <- 2..64, do: send(name, tap_evt(mac(i), 1))
      assert sync(name).total == 68

      # @mac ist das am laengsten nicht gesehene Badge und fliegt raus.
      send(name, tap_evt(mac(65), 1))
      state = sync(name)
      refute Map.has_key?(state.badges, @mac)
      assert state.total == 69

      # Alter Rohstand erneut: nichts zaehlt doppelt.
      send(name, tap_evt(@mac, 5))
      assert sync(name).total == 69

      # Zwei neue Taps seit dem Verdraengen: +2.
      send(name, tap_evt(@mac, 7))
      state = sync(name)
      assert count(state, @mac) == 2
      assert state.total == 71
    end

    test "reset/1 setzt auch den verdraengten Anteil auf 0" do
      name = start_tc()

      send(name, tap_evt(@mac, 5))
      for i <- 2..65, do: send(name, tap_evt(mac(i), 1))
      assert sync(name).total == 69

      TapCounter.reset(name)
      assert TapCounter.state(name).total == 0

      send(name, tap_evt(@mac, 6))
      assert sync(name).total == 1
    end

    @tag :tmp_dir
    test "retired_total und retired bleiben ueber Neustart erhalten", %{tmp_dir: dir} do
      path = Path.join(dir, "taps.json")
      name = start_tc(path: path)

      send(name, tap_evt(@mac, 5))
      for i <- 2..65, do: send(name, tap_evt(mac(i), 1))
      assert sync(name).total == 69
      stop_supervised!(TapCounter)

      data = path |> File.read!() |> Jason.decode!()
      assert data["retired_total"] == 5
      assert data["retired"] == %{@mac => 5}

      name2 = start_tc(path: path)
      assert TapCounter.state(name2).total == 69

      # Verdraengtes Badge nach Neustart: keine Doppelzaehlung.
      send(name2, tap_evt(@mac, 5))
      assert sync(name2).total == 69
      send(name2, tap_evt(@mac, 6))
      assert sync(name2).total == 70
    end

    @tag :tmp_dir
    test "alte Datei ohne retired-Felder laedt fehlerfrei", %{tmp_dir: dir} do
      path = Path.join(dir, "taps.json")

      File.write!(
        path,
        Jason.encode!(%{
          "version" => 1,
          "updated_at" => nil,
          "badges" => %{@mac => %{"raw" => 5, "offset" => 2, "last_seen" => nil}}
        })
      )

      name = start_tc(path: path)
      state = TapCounter.state(name)
      assert state.total == 3
      assert count(state, @mac) == 3
    end
  end

  describe "MAC-Validierung" do
    test "ungueltige MACs werden ignoriert und protokolliert" do
      EventLog.clear()
      name = start_tc()

      for bad <- ["xx", "", "%$#", "AA:BB:CC:DD:EE", "AA:BB:CC:DD:EE:FF:00", "AABBCCDDEEFF"] do
        send(name, tap_evt(bad, 3))
      end

      state = sync(name)
      assert state.badges == %{}
      assert state.total == 0
      assert Enum.any?(EventLog.entries(), &String.starts_with?(&1.message, "Ungueltige MAC"))
    end

    test "gueltige Kleinschreibung wird kanonisiert" do
      name = start_tc()

      send(name, tap_evt("aa:bb:cc:dd:ee:ff", 4))
      state = sync(name)
      assert Map.keys(state.badges) == [@mac]
      assert state.total == 4
    end
  end

  defp mac(i) do
    "00:00:00:00:00:" <> String.pad_leading(Integer.to_string(i, 16), 2, "0")
  end

  defp read_raw(path) do
    path |> File.read!() |> Jason.decode!() |> get_in(["badges", @mac, "raw"])
  end
end
