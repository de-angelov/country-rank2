import { Order } from "effect"
import { Country } from "../../countries/country.js"
import { LowestFirst } from "../../components/ranking-order-controls/ranking-order-controls.js"

export isLowestFirst = (order?: Unknown): Boolean =>
  match order
    | Some(value) => match value
      | "lowest-first" => true
      | LowestFirst => true
      | _ => false
    | None => false

byDislikes = Order.mapInput(Order.Number, (c: Country) => c.dislikes) |> Order.flip
byName = Order.mapInput(Order.String, (c: Country) => c.name)
dislikeOrder = Order.combine(byDislikes, byName)

export sortCountriesByDislikesDescending = (countries: Array<Country>) =>
  countries |> Array.sort(dislikeOrder)

export sortCountriesByDislikesAscending = (countries: Array<Country>) =>
  sortCountriesByDislikesDescending(countries) |> Array.reverse

export sortCountriesByDislikes = (countries: Array<Country>, order: Unknown = "highest-first") =>
  match isLowestFirst(order)
    | true => sortCountriesByDislikesAscending(countries)
    | false => sortCountriesByDislikesDescending(countries)

