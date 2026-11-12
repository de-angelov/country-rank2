import { Effect } from "effect"
import { isLowestFirst as sharedIsLowestFirst, sortCountriesByDislikesDescending as sharedSortCountriesByDislikesDescending, sortCountriesByDislikesAscending as sharedSortCountriesByDislikesAscending, sortCountriesByDislikes as sharedSortCountriesByDislikes } from "./ranking.js"
import { Country } from "../../countries/index.js"
import { readCountriesWithVoteTotals } from "../../countries/redis-totals.server.js"

export schema TopDislikedLoaderResult = {
  countries: Array<Country>
}

export schema TopDislikedLoaderOptions = {
  order: Unknown
}

export isLowestFirst = sharedIsLowestFirst
export sortCountriesByDislikesDescending = sharedSortCountriesByDislikesDescending
export sortCountriesByDislikesAscending = sharedSortCountriesByDislikesAscending
export sortCountriesByDislikes = sharedSortCountriesByDislikes

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

export loader = (args: Object = {}) =>
  request = Reflect.get(args or {}, "request")
  url = globalThis.String(Reflect.get(request or {}, "url") or "")
  => match url |> String.includes("order=lowest-first")
    | true => loadTopDislikedRouteData({ order: "lowest-first" })
    | false => loadTopDislikedRouteData({ order: "highest-first" })
