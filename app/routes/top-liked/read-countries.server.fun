import { Option } from "effect"
import { Country } from "../../countries/country.js"
import type { VoteTotalsByCountry, RedisVoteStorageError } from "../../votes/storage.server.js"
import { readCountriesWithVoteTotals } from "../../countries/redis-totals.server.js"
import { sortCountriesByLikes } from "./ranking.js"

export readTopLikedCountries = (options: { order?: Unknown, readTotals?: () => Effect<VoteTotalsByCountry, RedisVoteStorageError>, fixtures?: Array<Country>, logger?: { error: (context: { cause: Unknown }, message: String) => Void } }) =>
  effect {
    resolved = { order: Option.getOrUndefined(options.order), readTotals: Option.getOrUndefined(options.readTotals), fixtures: Option.getOrUndefined(options.fixtures), logger: Option.getOrUndefined(options.logger) }
    countries <- readCountriesWithVoteTotals(resolved)
    sorted = sortCountriesByLikes(countries, resolved.order)
    => sorted
  }
