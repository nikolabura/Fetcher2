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
        %{"name" => cat_name, "items" => items} = category

        val =
          items
          |> Enum.map(fn %{"name" => name, "nutrients" => nuts} ->
            String.trim(name) <>
              if cat_name == "BAKERY-DESSERT" do
                %{"value" => sugar_val} =
                  Enum.find(nuts, fn %{"name" => nutname} -> nutname == "Sugar (g)" end)

                " *(#{sugar_val}g sugar)*"
              else
                ""
              end
          end)
          |> Enum.join(", ")

        %Nostrum.Struct.Embed.Field{
          name: cat_name,
          value: val,
          inline: false
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
          "Late Night" -> 0x181A2E
        end
      )
      |> put_thumbnail(
        case period do
          "Breakfast" ->
            "https://cdn.discordapp.com/attachments/552980096315686955/909674115370192906/opt__aboutcom__coeus__resources__content_migration__serious_eats__seriouseats.png"

          "Lunch" ->
            "https://cdn.discordapp.com/attachments/552980096315686955/909674915127504927/ROLOS_AF_Sandwich_2.png"

          "Dinner" ->
            "https://cdn.discordapp.com/attachments/552980096315686955/909675166823510056/high-protein-dinners-slow-cooker-meatballs-image-5a04d02.png"

          "Late Night" ->
            "https://cdn.discordapp.com/attachments/552980096315686955/909675297274724393/lidar-physics-5955-scaled.png"
        end
      )

    embed = Map.put(embed, :fields, fields)

    embed
  end
end
