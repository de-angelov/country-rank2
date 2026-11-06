import { Effect, Option } from "effect"
import { Country } from "../../countries/country.js"
import type { VoteTotalsByCountry, RedisVoteStorageError } from "../../votes/storage.server.js"
import { readCountriesWithVoteTotals } from "../../countries/redis-totals.server.js"
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

export resolveTopLikedOptions = (rawOptions: TopLikedLoaderOptions): TopLikedLoaderOptions => rawOptions

export readTopLikedCountries = (options: { order?: Unknown, readTotals?: () => Effect<VoteTotalsByCountry, RedisVoteStorageError>, fixtures?: Array<Country>, logger?: { error: (context: { cause: Unknown }, message: String) => Void } }) =>
  effect {
    resolved = { order: Option.getOrUndefined(options.order), readTotals: Option.getOrUndefined(options.readTotals), fixtures: Option.getOrUndefined(options.fixtures), logger: Option.getOrUndefined(options.logger) }
    countries <- readCountriesWithVoteTotals(resolved)
    sorted = sortCountriesByLikes(countries, resolved.order)
    => sorted
  }

export getTopLikedCountries = readTopLikedCountries
export loadTopLikedCountries = readTopLikedCountries

export wrapTopLikedCountries = (countries: Array<Country>) =>
  result = { countries: countries }
  => result

export loadTopLikedRouteData = (options: { order?: Unknown, readTotals?: () => Effect<VoteTotalsByCountry, RedisVoteStorageError>, fixtures?: Array<Country>, logger?: { error: (context: { cause: Unknown }, message: String) => Void } }) =>
  mapped = Effect.map(readTopLikedCountries(options), wrapTopLikedCountries)
  => Effect.runPromise(mapped)

export loader = (args: Object = {}) =>
  request = Reflect.get(args or {}, "request")
  url = String(Reflect.get(request or {}, "url") or "http://localhost")
  query = url.split("?")[1] or ""
  queryWithoutHash = query.split("#")[0]
  orderParameter = queryWithoutHash.split("&").find((parameter) => parameter.split("=")[0] #= "order") or ""
  orderParam = orderParameter.split("=")[1] or ""
  order = match orderParam
    | "lowest-first" => "lowest-first"
    | "highest-first" => "highest-first"
    | _ => "highest-first"
  => loadTopLikedRouteData({ order: order })
