defmodule Fetcher2.Menu.Embed do
  alias Fetcher2.Menu.Query
  import Nostrum.Struct.Embed
  require Logger

  @spec build_embed(%Query{}, %{}, %{}) :: %Nostrum.Struct.Embed{}
  def build_embed(query, menu, user_options) do
    %{period: period} = query
    %{id: %{date: date}} = query
    %{"categories" => categories} = menu

    only_vegan = Enum.any?(user_options, fn o -> o.name == "only-vegan" and o.value end)
    only_vegetarian = Enum.any?(user_options, fn o -> o.name == "only-vegetarian" and o.value end)
    only_gf = Enum.any?(user_options, fn o -> o.name == "only-gluten-free" and o.value end)

    fields =
      categories
      |> Enum.filter(fn %{"name" => name} ->
        name not in Application.fetch_env!(:fetcher2, :excluded_dhall_categories)
      end)
      |> Enum.map(fn category ->
        %{"name" => cat_name, "items" => items} = category

        val =
          items
          |> Enum.filter(fn item ->
            filters = item["filters"]

            Enum.empty?(filters) or
              ((not only_vegan or has_name(filters, "Vegan")) and
                 (not only_vegetarian or has_name(filters, "Vegetarian")) and
                 (not only_gf or has_name(filters, "Avoiding Gluten")))
          end)
          |> Enum.map(fn %{"name" => name, "nutrients" => nuts} ->
            String.trim(name) <>
              if cat_name == "BAKERY" do
                %{"value" => sugar_val} =
                  Enum.find(nuts, fn %{"name" => nutname} -> nutname == "Sugar (g)" end)

                " *(#{sugar_val}g sugar)*"
              else
                ""
              end
          end)
          |> Enum.join(", ")

        if val == "" do
          nil
        else
          %Nostrum.Struct.Embed.Field{
            name:  category_icon(cat_name) <> cat_name,
            value: val,
            inline: false
          }
        end
      end)
      |> Enum.filter(&(!is_nil(&1)))

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

    desc1 = if only_vegan, do: "*Only showing :regional_indicator_v: vegan items.*\n", else: ""
    desc2 = if only_vegetarian, do: "*Only showing :leafy_green: vegetarian items.*\n", else: ""
    desc3 = if only_gf, do: "*Only showing :purple_square: gluten-free items.*\n", else: ""

    embed =
      %Nostrum.Struct.Embed{}
      |> put_title("D-Hall __#{period}__ Menu for #{date_string}")
      |> put_description(desc1 <> desc2 <> desc3)
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

  defp has_name(enum_of_maps_with_name, name_to_search) do
    Enum.any?(enum_of_maps_with_name, &(&1["name"] == name_to_search))
  end

  defp category_icon(cat_name) do
    icon = case cat_name do
      # breakfast
      "HOMESTYLE/GRILL" -> ":shallow_pan_of_food:"
      "HOMESTYLE BREAKFAST" -> ":shallow_pan_of_food:"
      "MY PANTRY EXHIBITION" -> ":fork_knife_plate:"
      "BAKERY-DESSERT" -> ":cake:"
      "BAKERY" -> ":cake:"
      # lunch
      "G8/HALAL" -> ":purple_circle:"
      "CREATE YOUR BOWL" -> ":rice:"
      "AVOIDING GLUTEN/HALAL" -> ":purple_circle:"
      "GRILL/HOMESTYLE" -> ":hotsprings:"
      "ROOTED" -> ":salad:"
      "SOUP" -> ":bowl_with_spoon:"
      "PASTA BAR" -> ":spaghetti:"
      "SALAD BAR COMPOSED SALADS" -> ":salad:"
      "COMPOSED SALAD/GRAINS" -> ":salad:"
      "PIZZA/FLATBREADS" -> ":pizza:"
      # late night
      "THE GRILL" -> ":hamburger:"

      _ -> ""
    end

    icon <> "  "
  end
end
