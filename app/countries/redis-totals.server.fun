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
  options = Option.fromNullishOrElse(rawOptions, {})
  readTotals = Option.fromNullishOrElse(options.readTotals, readAllCountryVoteTotals)
  fixtures = Option.fromNullishOrElse(options.fixtures, countryFixtures)
  activeLogger = Option.fromNullishOrElse(options.logger, logger)
  => {
    readTotals,
    fixtures,
    logger: activeLogger
  }

export logRedisTotalsError = (err: Unknown, customLogger?: ApplicationLogger) =>
  activeLogger = Option.fromNullishOrElse(customLogger, logger)
  => activeLogger.error({ cause: err }, "Failed to read country vote totals from Redis; falling back to zero totals")

export mergeCountriesWithVoteTotals = (countries: Array<Country>, totalsByCountry: VoteTotalsByCountry): Array<Country> =>
  countries.map((country) =>
    voteTotals = Option.fromNullishOr(totalsByCountry.get(country.code))
    totals = match voteTotals
      | Some(value) => value
      | None => { countryCode: country.code, likes: 0, dislikes: 0 }
    updated = { ...country, likes: totals.likes, dislikes: totals.dislikes }
    => updated
  )

export createFallbackCountries = (countries: Array<Country>): Array<Country> =>
  countries.map((country) => { ...country, likes: 0, dislikes: 0 })

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
