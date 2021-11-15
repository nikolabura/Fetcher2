defmodule Fetcher2.Menu.Day do
  # %{name: "today", value: "today"},
  # %{name: "tomorrow", value: "tomorrow"},
  # %{name: "yesterday", value: "yesterday"},
  # %{name: "monday", value: "monday"},
  # %{name: "tuesday", value: "tuesday"},
  # %{name: "wednesday", value: "wednesday"},
  # %{name: "thursday", value: "thursday"},
  # %{name: "friday", value: "friday"},
  # %{name: "saturday", value: "saturday"},
  # %{name: "sunday", value: "sunday"}

  @spec determine_day(String.t()) :: Date.t()
  def determine_day(day_choice) do
    now = DateTime.now!("America/New_York", Tzdata.TimeZoneDatabase)

    # no date supplied means default to today, or tomorrow if after 9pm
    day_choice =
      if day_choice == "default" do
        if now.hour > 21, do: "tomorrow", else: "today"
      else
        day_choice
      end

    today = DateTime.to_date(now)

    case day_choice do
      "today" -> today
      "tomorrow" -> Date.add(today, 1)
      "yesterday" -> Date.add(today, -1)
      "monday" -> matching_day_of_week(today, 1)
      "tuesday" -> matching_day_of_week(today, 2)
      "wednesday" -> matching_day_of_week(today, 3)
      "thursday" -> matching_day_of_week(today, 4)
      "friday" -> matching_day_of_week(today, 5)
      "saturday" -> matching_day_of_week(today, 6)
      "sunday" -> matching_day_of_week(today, 7)
    end
  end

  @spec matching_day_of_week(Date.t(), integer) :: Date.t()
  defp matching_day_of_week(today, target) do
    Stream.map(-1..10, &Date.add(today, &1))
    |> Stream.filter(&(Date.day_of_week(&1) == target))
    |> Stream.take(1)
    |> Enum.at(0)
  end
end
