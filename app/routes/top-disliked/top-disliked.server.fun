import { Effect, Option, Schema } from "effect"
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
    order: Unknown = Reflect.get(resolved, "order")
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
  requestVal: Unknown = Reflect.get(args, "request")
  requestObj: Object = match Schema.decodeUnknownOption(Schema.Record(Schema.String, Schema.Unknown))(requestVal)
    | Some(r) => r
    | None => {}
  urlVal: Unknown = Reflect.get(requestObj, "url")
  url = Option.getOrElse(Schema.decodeUnknownOption(Schema.String)(urlVal), () => "")
  => match url |> String.includes("order=lowest-first")
    | true => loadTopDislikedRouteData({ order: "lowest-first" })
    | _ => loadTopDislikedRouteData({ order: "highest-first" })
