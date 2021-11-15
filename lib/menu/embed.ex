defmodule Fetcher2.Menu.Embed do
  alias Fetcher2.Menu.Query
  import Nostrum.Struct.Embed

  @spec build_embed(%Query{}, %{}) :: %Nostrum.Struct.Embed{}
  def build_embed(query, menu) do
    %{period: period} = query
    %{id: %{date: date}} = query
    %{"categories" => categories} = menu

    fields =
      categories
      |> Enum.filter(fn %{"name" => name} ->
        name not in Application.fetch_env!(:fetcher2, :excluded_dhall_categories)
      end)
      |> Enum.map(fn category ->
        %{"name" => name, "items" => items} = category

        val =
          items
          |> Enum.map(fn %{"name" => name} ->
            String.trim(name)
          end)
          |> Enum.join("\n")

        %Nostrum.Struct.Embed.Field{
          name: name,
          value: val,
          inline: true
        }
      end)

    # |> Enum.chunk_every(2)
    # |> Enum.intersperse([
    #  %Nostrum.Struct.Embed.Field{
    #    name: "\u200B",
    #    value: "\u200B",
    #    inline: false
    #  }
    # ])
    # |> IO.inspect()
    # |> Enum.concat()

    date_string = Calendar.strftime(date, "%a, %b %d, %Y")

    embed =
      %Nostrum.Struct.Embed{}
      |> put_title("D-Hall __#{period}__ Menu for #{date_string}")
      |> put_color(
        case period do
          "Breakfast" -> 0xA1DBEF
          "Lunch" -> 0xFBBA55
          "Dinner" -> 0xDA4B51
          "Late Night" -> 0x363B4B
        end
      )

    embed = Map.put(embed, :fields, fields)

    embed
  end
end
