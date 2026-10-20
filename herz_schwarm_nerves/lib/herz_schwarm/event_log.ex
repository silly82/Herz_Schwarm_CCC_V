defmodule HerzSchwarm.EventLog do
  @moduledoc """
  Ringpuffer fuer Diagnose-Meldungen (Bridge, Effekte, Peers).

  * `log/3` ist asynchron (`cast`) und blockiert den Aufrufer nie.
  * Hoechstens 500 Eintraege; aelteste fallen heraus.
  * Anti-Spam: ist eine Meldung identisch (Level, Quelle, Text) zur
    unmittelbar vorherigen und kommt sie innerhalb von 1 s nach deren
    letztem Auftreten, wird sie *zusammengefasst*: der vorhandene Eintrag
    bekommt `n + 1`, es entsteht kein neuer Eintrag und es wird **kein**
    weiteres `{:event, entry}` publiziert (Clients sehen den aktuellen `n`
    beim naechsten `entries/0`).
  * Neue Eintraege werden als `{:event, entry}` auf Topic `"eventlog"`
    publiziert.

  Eintrag: `%{at: DateTime.t, level: atom, source: String.t, message: String.t, n: pos_integer}`
  (`entries/0` liefert die neuesten zuerst).
  """

  use GenServer

  @pubsub HerzSchwarm.PubSub
  @topic "eventlog"
  @levels [:debug, :info, :warn, :error]
  @max_entries 500
  @merge_window_ms 1_000
  @max_message_bytes 500

  defstruct entries: [], last_mono: nil

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def topic, do: @topic

  @doc "Protokolliert eine Meldung (`level in [:debug, :info, :warn, :error]`)."
  def log(level, source, message) when level in @levels and is_binary(source) do
    GenServer.cast(__MODULE__, {:log, level, source, normalize_message(message)})
  end

  @doc "Alle Eintraege, neueste zuerst."
  def entries do
    GenServer.call(__MODULE__, :entries)
  end

  @doc "Leert den Puffer."
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  # --- Callbacks ---

  @impl true
  def init(_opts), do: {:ok, %__MODULE__{}}

  @impl true
  def handle_call(:entries, _from, state), do: {:reply, state.entries, state}

  def handle_call(:clear, _from, _state), do: {:reply, :ok, %__MODULE__{}}

  @impl true
  def handle_cast({:log, level, source, message}, state) do
    now = System.monotonic_time(:millisecond)

    case state.entries do
      [%{level: ^level, source: ^source, message: ^message} = head | rest]
      when is_integer(state.last_mono) and now - state.last_mono <= @merge_window_ms ->
        {:noreply, %{state | entries: [%{head | n: head.n + 1} | rest], last_mono: now}}

      entries ->
        entry = %{at: DateTime.utc_now(), level: level, source: source, message: message, n: 1}
        Phoenix.PubSub.broadcast(@pubsub, @topic, {:event, entry})

        {:noreply, %{state | entries: Enum.take([entry | entries], @max_entries), last_mono: now}}
    end
  end

  # Steuerzeichen (außer Tab/Zeilenumbruch) entfernen, dann auf 500 Zeichen kürzen.
  defp normalize_message(message) when is_binary(message) do
    cleaned = String.replace(message, ~r/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")

    if String.length(cleaned) > @max_message_bytes do
      String.slice(cleaned, 0, @max_message_bytes) <> "…"
    else
      cleaned
    end
  end

  defp normalize_message(message), do: message |> inspect() |> normalize_message()
end
