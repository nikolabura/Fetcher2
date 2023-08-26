defmodule Fetcher2.DailyJob do
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: Fetcher2.DailyJob)
  end

  def init(state) do
    minutes = 5
    Logger.info("Starting daily job server. Scheduling first load in #{minutes} minutes.")
    Process.send_after(self(), :work, minutes * 60 * 1000)
    {:ok, state}
  end

  def handle_info(:work, state) do
    # Do the work you desire here

    today = DateTime.now!("America/New_York", Tzdata.TimeZoneDatabase) |> DateTime.to_date()

    Enum.map(0..2, fn n ->
      Logger.info("Daily job: Querying day #{n}.")

      query = %Fetcher2.Menu.Identifier{
        period: "Breakfast",
        location: :dhall,
        date: Date.add(today, n)
      }

      GenServer.call(
        Fetcher2.Menu.Server,
        {:query, query},
        30000
      )
    end)

    # Reschedule once more
    schedule_work()
    {:noreply, state}
  end

  defp schedule_work() do
    hours = 20
    Logger.info("Daily job will re-execute in #{hours} hours.")
    Process.send_after(self(), :work, hours * 60 * 60 * 1000)
  end
end
