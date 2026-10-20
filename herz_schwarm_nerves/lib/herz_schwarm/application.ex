defmodule HerzSchwarm.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        {Phoenix.PubSub, name: HerzSchwarm.PubSub},
        HerzSchwarm.Metrics,
        HerzSchwarm.EventLog,
        HerzSchwarm.TapCounter,
        HerzSchwarm.Bridge,
        HerzSchwarm.EffectEngine,
        HerzSchwarm.PeerTracker,
        HerzSchwarm.BridgeUpdater,
        HerzSchwarmWeb.Telemetry,
        HerzSchwarmWeb.Endpoint
      ]

    opts = [strategy: :one_for_one, name: HerzSchwarm.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    HerzSchwarmWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
