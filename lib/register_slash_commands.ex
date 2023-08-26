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
        },
        %{
          type: 5,
          name: "only-vegan",
          description:
            "Only display vegan items. (False by default. Setting this to false has no effect.)",
          required: false
        },
        %{
          type: 5,
          name: "only-vegetarian",
          description:
            "Only display vegetarian items. (False by default. Setting this to false has no effect.)",
          required: false
        },
        %{
          type: 5,
          name: "only-gluten-free",
          description:
            "Only display gluten-free items. (False by default. Setting this to false has no effect.)",
          required: false
        }
      ]
    }

    weather = %{
      name: "weather",
      description: "How's the weather on campus right now?"
    }

    forecast = %{
      name: "forecast",
      description: "What will the weather be like on campus today?"
    }

    duel = %{
      name: "duel",
      description: "Challenge a user to a quick-draw duel.",
      options: [
        %{
          type: 6,
          name: "offender",
          description: "The user you wish to duel.",
          required: true
        }
      ]
    }

    commands = [dhall, weather, forecast, duel]

    Logger.notice("Registering guild-local slash commands now.")
    guild = Application.get_env(:fetcher2, :testserv_guild_id)

    for command <- commands do
      inspect(Nostrum.Api.create_guild_application_command(guild, command))
    end

    if System.get_env("PUSH_GLOBAL_SLASH_COMMANDS") == "1" do
      Logger.warning("PUSHING GLOBAL SLASH COMMANDS NOW!")
      for command <- commands do
        Logger.warning(inspect(Nostrum.Api.create_global_application_command(command)))
      end
    end
  end
end
