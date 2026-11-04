import type { Effect } from "effect";
import type { Country } from "./country.js";
import type { VoteTotalsByCountry, RedisVoteStorageError } from "../votes/storage.server.js";
import type { ApplicationLogger } from "../lib/logger.server.js";

export type CountryVoteTotalsOptions = Readonly<{
  readTotals?: () => Effect.Effect<VoteTotalsByCountry, RedisVoteStorageError>;
  fixtures?: ReadonlyArray<Country>;
  logger?: Pick<ApplicationLogger, "error">;
}>;

export declare const resolveOptions: (rawOptions: unknown) => {
  readTotals: () => Effect.Effect<VoteTotalsByCountry, RedisVoteStorageError>;
  fixtures: ReadonlyArray<Country>;
  logger: Pick<ApplicationLogger, "error">;
};

export declare const mergeCountriesWithVoteTotals: (
  countries: ReadonlyArray<Country>,
  totalsByCountry: VoteTotalsByCountry
) => Array<Country>;

export declare const createFallbackCountries: (
  countries: ReadonlyArray<Country>
) => Array<Country>;

export declare const logRedisTotalsError: (
  error: unknown,
  customLogger?: Pick<ApplicationLogger, "error">
) => void;

export declare const readCountriesWithVoteTotals: (
  options?: CountryVoteTotalsOptions | unknown
) => Effect.Effect<Array<Country>, never>;

export declare const getCountriesWithVoteTotals: typeof readCountriesWithVoteTotals;
export declare const loadCountriesWithVoteTotals: typeof readCountriesWithVoteTotals;
