import { Effect } from "effect"
import { Country } from "../../countries/country.js"
import type { VoteTotalsByCountry, RedisVoteStorageError } from "../../votes/storage.server.js"
import * as countryReader from "./read-countries.server.js"
import { isLowestFirst as sharedIsLowestFirst, sortCountriesByLikesDescending as sharedSortCountriesByLikesDescending, sortCountriesByLikesAscending as sharedSortCountriesByLikesAscending, sortCountriesByLikes as sharedSortCountriesByLikes } from "./ranking.js"

export schema TopLikedLoaderResult = {
  countries: Array<Country>
}

export schema TopLikedLoaderOptions = {
  order: Unknown
}

export isLowestFirst = sharedIsLowestFirst
export sortCountriesByLikesDescending = sharedSortCountriesByLikesDescending
export sortCountriesByLikesAscending = sharedSortCountriesByLikesAscending
export sortCountriesByLikes = sharedSortCountriesByLikes

export resolveTopLikedOptions = (rawOptions: TopLikedLoaderOptions): TopLikedLoaderOptions => rawOptions or {}

export readTopLikedCountries = countryReader.readTopLikedCountries

export getTopLikedCountries = readTopLikedCountries
export loadTopLikedCountries = readTopLikedCountries

export wrapTopLikedCountries = (countries: Array<Country>) =>
  result = { countries: countries }
  => result

export loadTopLikedRouteData = (options: { order?: Unknown, readTotals?: () => Effect<VoteTotalsByCountry, RedisVoteStorageError>, fixtures?: Array<Country>, logger?: { error: (context: { cause: Unknown }, message: String) => Void } }) =>
  mapped = Effect.map(countryReader.readTopLikedCountries(options), wrapTopLikedCountries)
  => Effect.runPromise(mapped)

export loader = (args: Unknown = {}, options: Unknown = {}) =>
  request = Reflect.get(args or {}, "request")
  url = globalThis.String(Reflect.get(request or {}, "url") or "http://localhost")
  query = (url |> String.split("?"))[1] or ""
  queryWithoutHash = (query |> String.split("#"))[0] or ""
  orderParameter = (queryWithoutHash |> String.split("&") |> Array.findFirst((parameter) => ((parameter |> String.split("="))[0] or "") #= "order")) or ""
  orderParam = (orderParameter |> String.split("="))[1] or ""
  order = match orderParam
    | "lowest-first" => "lowest-first"
    | "highest-first" => "highest-first"
    | _ => Reflect.get(options or {}, "order") or "highest-first"
  resolvedOptions = { ...(options or {}), order: order }
  => loadTopLikedRouteData(resolvedOptions)
