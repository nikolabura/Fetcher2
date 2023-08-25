require Logger

defmodule Fetcher2.Application do
  use Application

  def start(_type, _args) do
    children = [
      Fetcher2.Listener,
      Fetcher2.Menu.Server,
      Fetcher2.DailyJob
    ]

    Logger.info("Starting Fetcher!")

    :ets.new(:duel_state, [:named_table, :public])

    opts = [strategy: :one_for_one, name: Fetcher2.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
