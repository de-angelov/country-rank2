import { Effect, Option, Result } from "effect"
import { countryFixtures } from "./fixtures.js"
import { logger, type ApplicationLogger } from "../lib/logger.server.js"
import { readAllCountryVoteTotals } from "../votes/storage.server.js"
import { Country } from "./country.js"
import type { VoteTotalsByCountry, RedisVoteStorageError } from "../votes/storage.server.js"

export schema CountryVoteTotalsOptions = {
  readTotals?: () => Effect<VoteTotalsByCountry, RedisVoteStorageError>
  fixtures?: Array<Country>
  logger?: ApplicationLogger
}

export resolveOptions = (rawOptions?: CountryVoteTotalsOptions) =>
  options = match rawOptions
    | Some(opts) => opts
    | None => {}
  readTotals = match Option.fromNullishOr(options.readTotals)
    | Some(fn) => fn
    | None => readAllCountryVoteTotals
  fixtures = match Option.fromNullishOr(options.fixtures)
    | Some(f) => f
    | None => countryFixtures
  activeLogger = match Option.fromNullishOr(options.logger)
    | Some(l) => l
    | None => logger
  => {
    readTotals,
    fixtures,
    logger: activeLogger
  }

export logRedisTotalsError = (err: Unknown, customLogger?: ApplicationLogger) =>
  activeLogger = match customLogger
    | Some(l) => l
    | None => logger
  => activeLogger.error({ cause: err }, "Failed to read country vote totals from Redis; falling back to zero totals")

export mergeCountriesWithVoteTotals = (countries: Array<Country>, totalsByCountry: VoteTotalsByCountry): Array<Country> =>
  countries |> Array.map((country) =>
    voteTotals = Option.fromNullishOr(totalsByCountry.get(country.code))
    totals = match voteTotals
      | Some(value) => value
      | None => { countryCode: country.code, likes: 0, dislikes: 0 }
    updated = { ...country, likes: totals.likes, dislikes: totals.dislikes }
    => updated
  )

export createFallbackCountries = (countries: Array<Country>): Array<Country> =>
  countries |> Array.map((country) => { ...country, likes: 0, dislikes: 0 })

export readCountriesWithVoteTotals = (options?: CountryVoteTotalsOptions) =>
  effect {
    resolved = resolveOptions(options)
    readTotalsFn = resolved.readTotals
    totalsEffect = readTotalsFn()
    outcome <- Effect.result(totalsEffect)
    countries = match
      | Result.isSuccess(outcome) => mergeCountriesWithVoteTotals(resolved.fixtures, outcome.success)
      | _ =>
        _ = logRedisTotalsError(outcome.failure, resolved.logger)
        createFallbackCountries(resolved.fixtures)
    => countries
  }

export getCountriesWithVoteTotals = readCountriesWithVoteTotals
export loadCountriesWithVoteTotals = readCountriesWithVoteTotals
