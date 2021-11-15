defmodule Fetcher2.RegisterSlashCommands do
  require Logger

  def register() do
    dhall = %{
      name: "dhall",
      description: "What's on the dining hall menu?",
      options: [
        %{
          # ApplicationCommandType::STRING
          type: 3,
          name: "period",
          description: "The dining period to query.",
          required: true,
          choices: [
            %{
              name: "breakfast",
              value: "Breakfast"
            },
            %{
              name: "lunch",
              value: "Lunch"
            },
            %{
              name: "dinner",
              value: "Dinner"
            },
            %{
              name: "late night",
              value: "Late Night"
            }
          ]
        }
      ]
    }

    Logger.notice("Registering slash commands now.")
    guild = Application.get_env(:fetcher2, :testserv_guild_id)

    Nostrum.Api.create_guild_application_command(guild, dhall)
  end
end
