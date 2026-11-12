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

byLikes = Order.mapInput(Order.Number, (c: Country) => c.likes) |> Order.flip
byName = Order.mapInput(Order.String, (c: Country) => c.name)
likeOrder = Order.combine(byLikes, byName)

export sortCountriesByLikesDescending = (countries: Array<Country>) =>
  countries |> Array.sort(likeOrder)

export sortCountriesByLikesAscending = (countries: Array<Country>) =>
  sorted = sortCountriesByLikesDescending(countries)
  => sorted |> Array.reverse

export sortCountriesByLikes = (countries: Array<Country>, order: Unknown = "highest-first") =>
  match isLowestFirst(order)
    | true => sortCountriesByLikesAscending(countries)
    | false => sortCountriesByLikesDescending(countries)

