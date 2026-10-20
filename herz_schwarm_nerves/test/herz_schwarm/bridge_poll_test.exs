defmodule HerzSchwarm.BridgePollTest do
  @moduledoc "Poll-Kette der Bridge: nach mehrfachem Reconnect laeuft genau eine Kette."
  use ExUnit.Case, async: false

  alias HerzSchwarm.Bridge

  setup do
    test = self()

    write = fn _pid, data ->
      send(test, {:wrote, data})
      :ok
    end

    orig = :sys.get_state(Bridge)
    cancel_poll_timer(orig.poll_timer)

    :sys.replace_state(Bridge, fn st ->
      %{st | connected: true, uart_pid: :fake, write: write, poll_timer: nil}
    end)

    on_exit(fn ->
      :sys.replace_state(Bridge, fn st ->
        cancel_poll_timer(st.poll_timer)

        %{
          st
          | connected: orig.connected,
            uart_pid: orig.uart_pid,
            write: orig.write,
            poll_timer: nil
        }
      end)
    end)

    :ok
  end

  defp cancel_poll_timer(nil), do: :ok
  defp cancel_poll_timer(ref), do: Process.cancel_timer(ref)

  test "mehrfache Reconnects: alte Poll-Timer sind abgebrochen, nur eine Kette bleibt" do
    refs =
      for _ <- 1..3 do
        st = :sys.replace_state(Bridge, &Bridge.start_polling/1)
        st.poll_timer
      end

    [old1, old2, current] = refs
    assert Process.read_timer(old1) == false
    assert Process.read_timer(old2) == false
    assert is_integer(Process.read_timer(current))
  end

  test "veraltete Poll-Ausloeser werden ignoriert, aktuelle Generation pollt" do
    stale_gen = :sys.get_state(Bridge).poll_gen
    :sys.replace_state(Bridge, &Bridge.start_polling/1)
    current_gen = :sys.get_state(Bridge).poll_gen
    assert current_gen == stale_gen + 1

    send(Bridge, {:poll_status, stale_gen})
    :sys.get_state(Bridge)
    refute_received {:wrote, _}

    send(Bridge, {:poll_status, current_gen})
    :sys.get_state(Bridge)
    assert_received {:wrote, _status}
    assert_received {:wrote, _peers}
  end
end
