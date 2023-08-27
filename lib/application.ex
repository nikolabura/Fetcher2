require Logger

defmodule Fetcher2.Application do
  use Application

  def start(_type, _args) do
    children = [
      Fetcher2.Listener,
      Fetcher2.Menu.Server,
      Fetcher2.DailyJob,
      Fetcher2.Dueling
    ]

    Logger.info("Starting Fetcher!")

    opts = [strategy: :one_for_one, name: Fetcher2.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
