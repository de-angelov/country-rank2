import { Effect } from "effect"
import { LowestFirst } from "../../components/ranking-order-controls/ranking-order-controls.js"
import { Country } from "../../countries/index.js"
import { readCountriesWithVoteTotals } from "../../countries/redis-totals.server.js"

export schema TopDislikedLoaderResult = {
  countries: Array<Country>
}

export schema TopDislikedLoaderOptions = {
  order: Unknown
}

export isLowestFirst = (order: Unknown) =>
  match order
    | "lowest-first" => true
    | LowestFirst => true
    | _ => false

dislikeComparator = (a: Country, b: Country) =>
  match b.dislikes #! a.dislikes
    | true => b.dislikes - a.dislikes
    | false => a.name.localeCompare(b.name)

export sortCountriesByDislikesDescending = (countries: Array<Country>) =>
  => countries.slice().sort(dislikeComparator)

export sortCountriesByDislikesAscending = (countries: Array<Country>) =>
  => sortCountriesByDislikesDescending(countries).reverse()

export sortCountriesByDislikes = (countries: Array<Country>, order: Unknown) =>
  match isLowestFirst(order)
    | true => sortCountriesByDislikesAscending(countries)
    | false => sortCountriesByDislikesDescending(countries)

export resolveTopDislikedOptions = (rawOptions: Object) => rawOptions or { order: "highest-first" }

export readTopDislikedCountries = (options: Object) =>
  effect {
    resolved = resolveTopDislikedOptions(options)
    countries <- readCountriesWithVoteTotals(resolved)
    order = Reflect.get(resolved, "order")
    sorted = sortCountriesByDislikes(countries, order)
    => sorted
  }

export getTopDislikedCountries = readTopDislikedCountries
export loadTopDislikedCountries = readTopDislikedCountries

export loadTopDislikedRouteData = (options: Object) =>
  routeData = effect {
    countries <- readTopDislikedCountries(options)
    => { countries: countries }
  }
  => Effect.runPromise(routeData)

export loader = (args: Object) =>
  request = Reflect.get(args or {}, "request")
  url = String(Reflect.get(request or {}, "url") or "")
  => match url.includes("order=lowest-first")
    | true => loadTopDislikedRouteData({ order: "lowest-first" })
    | false => loadTopDislikedRouteData({ order: "highest-first" })
