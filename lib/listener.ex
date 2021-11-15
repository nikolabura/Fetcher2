defmodule Fetcher2.Listener do
  use Nostrum.Consumer
  import Fetcher2.Util
  require Logger

  alias Nostrum.Api
  alias Nostrum.Struct.Interaction

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  # @dialyzer {:nowarn_function, handle_interaction: 1}
  defp handle_interaction(%Interaction{data: %{name: "dhall"}} = interaction) do
    # DHALL COMMAND (GET MENU CONTENTS)
    %Interaction{token: token, data: %{options: options}} = interaction
    [%{name: "period", value: meal_period}] = options
    Logger.debug("Meal period: #{meal_period}")

    # Defer response
    response = %{type: 5}
    Api.create_interaction_response(interaction, response)

    query = %Fetcher2.Menu.Query{
      period: meal_period,
      id: %Fetcher2.Menu.Identifier{
        location: :dhall,
        date: DateTime.now!("America/New_York", Tzdata.TimeZoneDatabase) |> DateTime.to_date()
      }
    }

    menu =
      GenServer.call(
        Fetcher2.Menu.Server,
        {:query, query},
        30000
      )

    response = %{
      tts: false,
      username: "",
      avatar_url: "",
      embeds: [Fetcher2.Menu.Embed.build_embed(query, menu)]
    }

    debug(
      Api.request(
        :post,
        Nostrum.Constants.webhook_token(Nostrum.Cache.Me.get().id, token),
        response,
        wait: false
      )
    )
  end

  def handle_event({:READY, event, _ws_state}) do
    Logger.debug("#{event.user.username} is Ready.")
    # Fetcher2.RegisterSlashCommands.register()
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
    handle_interaction(interaction)
  end

  # Default event handler
  def handle_event(_event) do
    :noop
  end
end
