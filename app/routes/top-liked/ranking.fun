import { Country } from "../../countries/country.js"
import { LowestFirst } from "../../components/ranking-order-controls/ranking-order-controls.js"

export isLowestFirst = (order: Unknown): Boolean =>
  match order
    | "lowest-first" => true
    | LowestFirst => true
    | _ => false

export sortCountriesByLikesDescending = (countries: Array<Country>) =>
  sorted = countries.slice().sort((a, b) =>
    difference = b.likes - a.likes
    match difference #= 0
      | true => a.name.localeCompare(b.name)
      | false => difference
  )
  => sorted

export sortCountriesByLikesAscending = (countries: Array<Country>) =>
  sorted = sortCountriesByLikesDescending(countries)
  => sorted.reverse()

export sortCountriesByLikes = (countries: Array<Country>, order: Unknown) =>
  match isLowestFirst(order)
    | true => sortCountriesByLikesAscending(countries)
    | false => sortCountriesByLikesDescending(countries)

