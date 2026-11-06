import { Effect, Option, Result } from "effect"
import { countryFixtures } from "./fixtures.js"
import { logger } from "../lib/logger.server.js"
import { readAllCountryVoteTotals } from "../votes/storage.server.js"
import { Country } from "./country.js"
import type { VoteTotalsByCountry, RedisVoteStorageError } from "../votes/storage.server.js"

ts {
  import type { ApplicationLogger } from "../lib/logger.server.js";

  export type CountryVoteTotalsOptions = Readonly<{
    readTotals?: () => Effect.Effect<VoteTotalsByCountry, RedisVoteStorageError>;
    fixtures?: ReadonlyArray<Country>;
    logger?: Pick<ApplicationLogger, "error">;
  }>;

  export const resolveOptions = (rawOptions: unknown) => {
    const options = (rawOptions ?? {}) as CountryVoteTotalsOptions;
    return {
      readTotals: options.readTotals ?? readAllCountryVoteTotals,
      fixtures: options.fixtures ?? countryFixtures,
      logger: options.logger ?? logger,
    };
  };

  export const logRedisTotalsError = (
    error: unknown,
    customLogger?: Pick<ApplicationLogger, "error">
  ): void => {
    const activeLogger = customLogger ?? logger;
    activeLogger.error(
      { cause: error },
      "Failed to read country vote totals from Redis; falling back to zero totals"
    );
  };
}

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

export readCountriesWithVoteTotals = (options: Unknown) =>
  effect {
    resolved = resolveOptions(options)
    outcome <- Effect.result(resolved.readTotals())
    countries = match
      | Result.isSuccess(outcome) => mergeCountriesWithVoteTotals(resolved.fixtures, outcome.success)
      | _ =>
        _ = logRedisTotalsError(outcome.failure, resolved.logger)
        createFallbackCountries(resolved.fixtures)
    => countries
  }

export getCountriesWithVoteTotals = readCountriesWithVoteTotals
export loadCountriesWithVoteTotals = readCountriesWithVoteTotals
