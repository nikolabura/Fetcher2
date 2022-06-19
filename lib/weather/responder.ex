defmodule Fetcher2.Weather.Responder do
  import Nostrum.Struct.Embed
  require Logger

  # umbccoords "39.25565,-76.71207"
  # umbc gridpoint LWX/105,88

  @useragent "(fetcher2, fetcher2@nikolabura.com)"

  def get_weather_embeds do
    [bwi_observation_embed()] ++ umbc_hourly_forecast_embeds()
  end

  def bwi_observation_embed do
    url = "https://api.weather.gov/stations/KBWI/observations/latest?require_qc=false"

    %HTTPoison.Response{body: body} =
      HTTPoison.get!(
        url,
        [{"User-Agent", @useragent}],
        [{:timeout, :infinity}, {:recv_timeout, :infinity}]
      )

    Logger.debug(body)

    %{
      "properties" => %{
        "timestamp" => timestamp,
        "textDescription" => textDescription,
        "icon" => iconUrl,
        "temperature" => %{"value" => tempC},
        "relativeHumidity" => %{"value" => _relHumid}
      }
    } = Jason.decode!(body)

    {:ok, obsTime, _} = DateTime.from_iso8601(timestamp)
    minutes_ago = (DateTime.diff(DateTime.utc_now(), obsTime, :second) / 60) |> trunc

    tempF = (tempC * 1.8 + 32) |> Float.round(1)

    embed =
      %Nostrum.Struct.Embed{}
      |> put_title("Weather at BWI: __#{textDescription}__")
      |> put_thumbnail(iconUrl)
      |> put_description("Observed #{minutes_ago} minutes ago.")
      |> put_field("Temperature", "#{tempC}°C, #{tempF}°F", true)
      #|> put_field("Relative Humidity", "#{relHumid |> trunc |> to_string}%", true)
      |> put_color(celsius_to_color(tempC))

    embed
  end

  def umbc_hourly_forecast_embeds do
    url = "https://api.weather.gov/gridpoints/LWX/105,88/forecast/hourly"

    %HTTPoison.Response{body: body} = HTTPoison.get!(url, [{"User-Agent", @useragent}], [])

    %{"properties" => %{"periods" => periods}} = Jason.decode!(body)

    embeds =
      periods
      |> Enum.take(6)
      |> Enum.map(fn period ->
        %{
          "startTime" => startTime,
          "endTime" => endTime,
          "isDaytime" => _daytime,
          "temperature" => tempF,
          "windSpeed" => wind,
          "icon" => iconUrl,
          "shortForecast" => forecast
        } = period

        tempC = ((tempF - 32) / 1.8) |> trunc

        {:ok, startDt} = NaiveDateTime.from_iso8601(startTime)
        {:ok, endDt} = NaiveDateTime.from_iso8601(endTime)

        %Nostrum.Struct.Embed{}
        |> put_title(
          "#{Calendar.strftime(startDt, "%a %I %p")} to #{Calendar.strftime(endDt, "%I %p")}"
        )
        |> put_thumbnail(iconUrl)
        |> put_description(forecast <> "\n#{tempC}°C, #{tempF}°F" <> ". #{wind}")
        |> put_color(celsius_to_color(tempC))
      end)

    embeds
  end

  defp celsius_to_color(tempC) do
    cond do
      tempC < -10 -> 0x5039C6
      tempC < 0 -> 0x2CACD3
      tempC < 10 -> 0x5AA59E
      tempC < 15 -> 0x43BC98
      tempC < 20 -> 0x4AB575
      tempC < 25 -> 0x3BB355
      tempC < 30 -> 0x8DBD42
      tempC < 35 -> 0xBFA540
      tempC < 40 -> 0xC94C36
      true -> 0xC1141E
    end
  end

  def get_forecast_embeds do
    daily_forecast_embeds()
  end

  defp daily_forecast_embeds do
    url = "https://api.weather.gov/gridpoints/LWX/105,88/forecast"

    %HTTPoison.Response{body: body} = HTTPoison.get!(url, [{"User-Agent", @useragent}], [])

    %{"properties" => %{"periods" => periods}} = Jason.decode!(body)

    embeds =
      periods
      |> Enum.take(3)
      |> Enum.map(fn period ->
        %{
          "number" => number,
          "name" => timeName,
          "startTime" => startTime,
          "endTime" => endTime,
          "isDaytime" => daytime,
          "temperature" => tempF,
          "windSpeed" => _wind,
          "icon" => iconUrl,
          "shortForecast" => _shortForecast,
          "detailedForecast" => detailedForecast
        } = period

        tempC = ((tempF - 32) / 1.8) |> trunc

        {:ok, startDt} = NaiveDateTime.from_iso8601(startTime)
        {:ok, endDt} = NaiveDateTime.from_iso8601(endTime)

        %Nostrum.Struct.Embed{}
        |> put_title(
          "__" <>
            timeName <>
            "__  " <>
            if number == 1 do
              "Now"
            else
              "#{Calendar.strftime(startDt, "#{rem(startDt.hour, 12)} %p")}"
            end <>
            " to " <>
            "#{Calendar.strftime(endDt, "#{rem(endDt.hour, 12)} %p")}" <>
            if not daytime do
              " #{Calendar.strftime(endDt, "%a")}"
            else
              ""
            end
        )
        |> put_thumbnail(iconUrl)
        |> put_description(detailedForecast <> " **#{tempC}°C, #{tempF}°F.**")
        |> put_color(celsius_to_color(tempC))
      end)

    embeds
  end
end
