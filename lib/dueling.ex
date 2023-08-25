defmodule Fetcher2.Dueling do
  require Logger

  alias Nostrum.Api
  alias Nostrum.Struct.Interaction

  def start_duel(interaction) do
    %Interaction{data: %{options: options}} = interaction

    challenger_id = interaction.member.user().id
    [%{value: challenged_id} | _] = options

    # respond
    response = %{
      type: 4,
      data: %{
        content:
          "<@#{challenger_id}> has challenged <@#{challenged_id}> to a duel! :crossed_swords:\n\n<@#{challenged_id}>, make your choice...",
        components: [
          %{
            type: 1,
            components: [
              %{
                type: 2,
                label: "Accept Duel",
                style: 3,
                custom_id: "accept",
                emoji: %{id: 0, name: "⚔️"}
              },
              %{
                type: 2,
                label: "Decline Duel",
                style: 4,
                custom_id: "decline",
                emoji: %{id: 0, name: "😰"}
              }
            ]
          }
        ]
      }
    }

    Api.create_interaction_response!(interaction, response)
  end
end
