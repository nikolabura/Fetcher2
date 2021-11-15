defmodule Fetcher2.RegisterSlashCommands do
  require Logger

  def register() do
    dhall = %{
      name: "dhall",
      description: "What's on the dining hall menu?",
      options: [
        %{
          type: 3,
          name: "period",
          description: "The dining period to query.",
          required: true,
          choices: [
            %{name: "breakfast", value: "Breakfast"},
            %{name: "lunch", value: "Lunch"},
            %{name: "dinner", value: "Dinner"},
            %{name: "late night", value: "Late Night"}
          ]
        },
        %{
          type: 3,
          name: "day",
          description: "Which day to query? If excluded, Fetcher will try to read your mind.",
          required: false,
          choices: [
            %{name: "today", value: "today"},
            %{name: "tomorrow", value: "tomorrow"},
            %{name: "yesterday", value: "yesterday"},
            %{name: "monday", value: "monday"},
            %{name: "tuesday", value: "tuesday"},
            %{name: "wednesday", value: "wednesday"},
            %{name: "thursday", value: "thursday"},
            %{name: "friday", value: "friday"},
            %{name: "saturday", value: "saturday"},
            %{name: "sunday", value: "sunday"}
          ]
        }
      ]
    }

    Logger.notice("Registering slash commands now.")
    guild = Application.get_env(:fetcher2, :testserv_guild_id)

    Nostrum.Api.create_guild_application_command(guild, dhall)
  end
end
