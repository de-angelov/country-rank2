import { Effect, Option, Schema } from "effect"
import { Country } from "../../countries/country.js"
import type { VoteTotalsByCountry, RedisVoteStorageError } from "../../votes/storage.server.js"
import type { ApplicationLogger } from "../../lib/logger.server.js"
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

export loadTopLikedRouteData = (options: { order?: Unknown, readTotals?: () => Effect<VoteTotalsByCountry, RedisVoteStorageError>, fixtures?: Array<Country>, logger?: ApplicationLogger }) =>
  mapped = Effect.map(countryReader.readTopLikedCountries({
    order: Option.getOrUndefined(options.order),
    readTotals: Option.getOrUndefined(options.readTotals),
    fixtures: Option.getOrUndefined(options.fixtures),
    logger: Option.getOrUndefined(options.logger)
  }), wrapTopLikedCountries)
  => Effect.runPromise(mapped)

export loader = (args: Object = {}, options: Object = {}) =>
  requestVal: Unknown = Reflect.get(args, "request")
  requestObj: Object = match Schema.decodeUnknownOption(Schema.Record(Schema.String, Schema.Unknown))(requestVal)
    | Some(r) => r
    | None => {}
  urlVal: Unknown = Reflect.get(requestObj, "url")
  url = Option.getOrElse(Schema.decodeUnknownOption(Schema.String)(urlVal), () => "http://localhost")
  query = match (url |> String.split("?"))[1] | Some(q) => q | None => ""
  queryWithoutHash = match (query |> String.split("#"))[0] | Some(q) => q | None => ""
  orderParameter = match (queryWithoutHash |> String.split("&") |> Array.findFirst((parameter) => (match (parameter |> String.split("="))[0] | Some(p) => p | None => "") #= "order")) | Some(p) => p | None => ""
  orderParam = match (orderParameter |> String.split("="))[1] | Some(p) => p | None => ""
  fallbackOrder: Unknown = Reflect.get(options, "order")
  order = match orderParam
    | "lowest-first" => "lowest-first"
    | "highest-first" => "highest-first"
    | _ => Option.getOrElse(Option.fromNullishOr(fallbackOrder), () => "highest-first")
  => loadTopLikedRouteData({ ...options, order: order })
