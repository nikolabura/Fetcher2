defmodule Fetcher2.Menu.Query do
  use TypedStruct

  typedstruct enforce: true do
    field(:id, Fetcher2.Menu.Identifier)
    field(:period, String.t())
  end
end

defmodule Fetcher2.Menu.Identifier do
  use TypedStruct

  typedstruct enforce: true do
    field(:date, Calendar.date())
    field(:location, :dhall)
  end
end

defmodule Fetcher2.Menu.Server do
  use GenServer
  require Logger
  alias Fetcher2.Menu.Identifier
  alias Fetcher2.Menu.Query

  def start_link(default) do
    GenServer.start_link(__MODULE__, default, name: Fetcher2.Menu.Server)
  end

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:query, %Query{id: id, period: meal_period}}, _from, map) do
    whole_menu =
      case map do
        %{^id => menu} -> menu
        %{} -> api_request(id)
      end

    %{"periods" => periods} = whole_menu
    menu = Enum.find(periods, fn p -> match?(%{"name" => ^meal_period}, p) end)

    {:reply, menu, Map.put(map, id, whole_menu)}
  end

  @spec api_request(Identifier.t()) :: %{}
  defp api_request(%Identifier{date: date, location: :dhall}) do
    datestr = Date.to_string(date)

    url =
      "https://api.dineoncampus.com/v1/location/menu?site_id=5751fd3690975b60e04893e2&platform=0&location_id=61f9b37cb63f1ed3696abfbe&date=#{datestr}"

    Logger.info("New API request for #{url}")

    %HTTPoison.Response{body: body} =
      HTTPoison.get!(
        url,
        [],
        [{:timeout, :infinity}, {:recv_timeout, :infinity}]
      )

    %{"menu" => menu} = Jason.decode!(body)
    menu
  end
end
