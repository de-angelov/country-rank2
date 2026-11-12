import { Country } from "../../countries/country.js"
import { LowestFirst } from "../../components/ranking-order-controls/ranking-order-controls.js"

export isLowestFirst = (order?: Unknown): Boolean =>
  match order
    | Some(value) => match value
      | "lowest-first" => true
      | LowestFirst => true
      | _ => false
    | None => false

dislikeComparator = (a: Country, b: Country) =>
  match b.dislikes #! a.dislikes
    | true => b.dislikes - a.dislikes
    | false => a.name.localeCompare(b.name)

export sortCountriesByDislikesDescending = (countries: Array<Country>) =>
  countries.slice().sort(dislikeComparator)

export sortCountriesByDislikesAscending = (countries: Array<Country>) =>
  sortCountriesByDislikesDescending(countries).reverse()

export sortCountriesByDislikes = (countries: Array<Country>, order: Unknown = "highest-first") =>
  match isLowestFirst(order)
    | true => sortCountriesByDislikesAscending(countries)
    | false => sortCountriesByDislikesDescending(countries)

