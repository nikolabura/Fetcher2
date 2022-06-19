defmodule Fetcher2.Listener do
  use Nostrum.Consumer
  require Fetcher2.Util
  require Logger

  alias Nostrum.Api
  alias Nostrum.Struct.Interaction

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  @dialyzer {:no_return, handle_interaction: 1}
  defp handle_interaction(%Interaction{data: %{name: "dhall"}} = interaction) do
    # DHALL COMMAND (GET MENU CONTENTS)
    %Interaction{token: token, data: %{options: options}} = interaction
    # debug(options)
    %{value: meal_period} = Enum.find(options, fn o -> o.name == "period" end)
    %{value: day_choice} = Enum.find(options, %{value: "default"}, fn o -> o.name == "day" end)
    Logger.debug("Got /dhall request. Meal period: #{meal_period}. Day: #{day_choice}")

    # defer response (real response comes later)
    response = %{type: 5}
    Api.create_interaction_response(interaction, response)
    Process.sleep(10)

    # determine query parameters
    query = %Fetcher2.Menu.Query{
      period: meal_period,
      id: %Fetcher2.Menu.Identifier{
        location: :dhall,
        date: Fetcher2.Menu.Day.determine_day(day_choice)
      }
    }

    # get the menu (ideally cached) from the menu server
    menu =
      GenServer.call(
        Fetcher2.Menu.Server,
        {:query, query},
        30000
      )

    # build the response
    response = %{
      tts: false,
      username: "",
      avatar_url: "",
      embeds: [Fetcher2.Menu.Embed.build_embed(query, menu, options)]
    }

    # send the real response
    {:ok, _} =
      Api.request(
        :post,
        Nostrum.Constants.webhook_token(Nostrum.Cache.Me.get().id, token),
        response,
        wait: false
      )
  end

  @dialyzer {:no_return, handle_interaction: 1}
  defp handle_interaction(%Interaction{data: %{name: "weather"}} = interaction) do
    # WEATHER COMMAND (GET CAMPUS WEATHER)
    %Interaction{token: token, data: %{options: _options}} = interaction
    Logger.debug("Got /weather request")

    # defer response (real response comes later)
    response = %{type: 5}
    Api.create_interaction_response(interaction, response)

    # generate response (call weather API)
    embeds = Fetcher2.Weather.Responder.get_weather_embeds()
    followup = %{tts: false, username: "", avatar_url: "", embeds: embeds}

    # send the real response
    {:ok, _} =
      Api.request(
        :post,
        Nostrum.Constants.webhook_token(Nostrum.Cache.Me.get().id, token),
        followup,
        wait: false
      )
  end

  @dialyzer {:no_return, handle_interaction: 1}
  defp handle_interaction(%Interaction{data: %{name: "forecast"}} = interaction) do
    # FORECAST COMMAND (GET CAMPUS FORECAST FOR THE DAY)
    %Interaction{token: token, data: %{options: _options}} = interaction
    Logger.debug("Got /forecast request")

    # defer response (real response comes later)
    response = %{type: 5}
    Api.create_interaction_response(interaction, response)

    # generate response (call weather API)
    embeds = Fetcher2.Weather.Responder.get_forecast_embeds()
    followup = %{tts: false, username: "", avatar_url: "", embeds: embeds}

    # send the real response
    {:ok, _} =
      Api.request(
        :post,
        Nostrum.Constants.webhook_token(Nostrum.Cache.Me.get().id, token),
        followup,
        wait: false
      )
  end

  def handle_event({:READY, event, _ws_state}) do
    Logger.debug("#{event.user.username} is Ready.")
    Fetcher2.RegisterSlashCommands.register()
  end

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    case msg.content do
      "!ping" ->
        Api.create_message(msg.channel_id, "Pong :dog2:!")

      _ ->
        :ignore
    end
  end

  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    Logger.debug("Incoming interaction from #{interaction.user.username}!")
    handle_interaction(interaction)
  end

  # Default event handler
  def handle_event(_event) do
    :noop
  end
end
