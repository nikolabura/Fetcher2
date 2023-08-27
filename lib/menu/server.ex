defmodule Fetcher2.Menu.Identifier do
  use TypedStruct

  typedstruct enforce: true do
    field(:date, Calendar.date())
    field(:location, :dhall)
    field(:period, String.t())
  end
end

defmodule Fetcher2.Menu.Server do
  use GenServer
  require Logger
  alias Fetcher2.Menu.Identifier

  def start_link(default) do
    GenServer.start_link(__MODULE__, default, name: Fetcher2.Menu.Server)
  end

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:query, identifier}, _from, map) do
    menu_categories =
      case map do
        %{^identifier => menu} -> menu
        %{} -> api_request(identifier)
      end

    {:reply, menu_categories, Map.put(map, identifier, menu_categories)}
  end

  # should return the categories array for a specific date, for the requested meal period
  @spec api_request(Identifier.t()) :: %{}
  defp api_request(%Identifier{date: date, period: period, location: :dhall}) do
    datestr = Date.to_string(date)

    # url = "https://api.dineoncampus.com/v1/location/menu?site_id=5751fd3690975b60e04893e2&platform=0&location_id=61f9b37cb63f1ed3696abfbe&date=#{datestr}"
    # url = "https://api.dineoncampus.com/v1/location/61f9d7c8a9f13a15d7c1a25e/periods/64e917d7c625af0b584c6658?platform=0&date=#{datestr}"
    preliminary_url =
      "https://api.dineoncampus.com/v1/location/61f9d7c8a9f13a15d7c1a25e/periods?platform=0&date=#{datestr}"

    Logger.info("New API request for #{period}. Requesting preliminary: #{preliminary_url}")

    %HTTPoison.Response{body: body} =
      HTTPoison.get!(
        preliminary_url,
        [],
        [{:timeout, 1000 * 30}, {:recv_timeout, 1000 * 30}]
      )

    %{"periods" => periods} = Jason.decode!(body)
    # period_ids = Enum.map(periods, fn p -> {p["name"], p["id"]} end) |> Map.new()
    # IO.inspect(period_ids)
    relevant_period_id = Enum.find(periods, fn p -> p["name"] == period end)["id"]

    if relevant_period_id == nil,
      do: raise("Meal period #{period} not found in DineOnCampus meal period listing.")

    followup_url =
      "https://api.dineoncampus.com/v1/location/61f9d7c8a9f13a15d7c1a25e/periods/#{relevant_period_id}?platform=0&date=#{datestr}"

    Logger.info("Making followup request to #{followup_url}")

    %HTTPoison.Response{body: body} =
      HTTPoison.get!(
        followup_url,
        [],
        [{:timeout, 1000 * 30}, {:recv_timeout, 1000 * 30}]
      )

    %{"menu" => %{"periods" => %{"categories" => menu_categories}}} = Jason.decode!(body)
    menu_categories
  end
end
