import { Effect, Option, Result } from "effect"
import { countryFixtures } from "./fixtures.js"
import { logger } from "../lib/logger.server.js"
import { readAllCountryVoteTotals } from "../votes/storage.server.js"
import { Country } from "./country.js"
import type { VoteTotalsByCountry, RedisVoteStorageError } from "../votes/storage.server.js"

export schema CountryVoteTotalsOptions = {
  readTotals?: Unknown
  fixtures?: Array<Country>
  logger?: Unknown
}

toTotalsEffect = (operation: ts { any }): Effect<VoteTotalsByCountry, RedisVoteStorageError> =>
  => operation

toFixtures = (items: ts { any }): Array<Country> =>
  => items

toTarget = (val: ts { any }): Object =>
  => val

export resolveOptions = (rawOptions?: Unknown) =>
  options = Option.getOrElse(rawOptions, () => ({}))
  optionsObj = toTarget(options)
  rawReadTotals = Option.fromNullishOr(Reflect.get(optionsObj, "readTotals"))
  readTotals = match rawReadTotals
    | Some(fn) => fn
    | None => readAllCountryVoteTotals
  rawFixtures = Option.fromNullishOr(Reflect.get(optionsObj, "fixtures"))
  fixtures = match rawFixtures
    | Some(customFixtures) => toFixtures(customFixtures)
    | None => countryFixtures
  rawLogger = Option.fromNullishOr(Reflect.get(optionsObj, "logger"))
  activeLogger = match rawLogger
    | Some(customLogger) => customLogger
    | None => logger
  => {
    readTotals: readTotals,
    fixtures: fixtures,
    logger: activeLogger
  }

export logRedisTotalsError = (err: Unknown, customLogger?: Unknown) =>
  activeLogger = match customLogger
    | Some(loggerInstance) => loggerInstance
    | None => logger
  loggerObj = toTarget(activeLogger)
  logFn = Reflect.get(loggerObj, "error")
  => Reflect.apply(logFn, loggerObj, [{ cause: err }, "Failed to read country vote totals from Redis; falling back to zero totals"])

export mergeCountriesWithVoteTotals = (countries: Array<Country>, totalsByCountry: VoteTotalsByCountry): Array<Country> =>
  => countries.map((country) =>
    voteTotals = Option.fromNullishOr(totalsByCountry.get(country.code))
    totals = match voteTotals
      | Some(value) => value
      | None => { countryCode: country.code, likes: 0, dislikes: 0 }
    updated = { ...country, likes: totals.likes, dislikes: totals.dislikes }
    => updated
  )

export createFallbackCountries = (countries: Array<Country>): Array<Country> =>
  => countries.map((country) => { ...country, likes: 0, dislikes: 0 })

export readCountriesWithVoteTotals = (options?: Unknown) =>
  effect {
    resolved = resolveOptions(Option.getOrUndefined(options))
    readTotalsFn = resolved.readTotals
    totalsEffect = toTotalsEffect(readTotalsFn())
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
