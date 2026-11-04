import type { Effect } from "effect";
import type { Country } from "../../countries/country.js";
import type { CountryVoteTotalsOptions } from "../../countries/redis-totals.server.js";
import type { RankingOrder } from "../../components/ranking-order-controls/ranking-order-controls.js";

export type RankingSortOrder = "highest-first" | "lowest-first" | RankingOrder;

export type TopDislikedLoaderOptions = CountryVoteTotalsOptions & Readonly<{
  order?: RankingSortOrder;
}>;

export interface TopDislikedLoaderResult {
  countries: Array<Country>;
}

export declare const isLowestFirst: (order?: RankingSortOrder) => boolean;

export declare const sortCountriesByDislikes: (
  countries: ReadonlyArray<Country>,
  order?: RankingSortOrder
) => Array<Country>;

export declare const sortCountriesByDislikesDescending: (
  countries: ReadonlyArray<Country>
) => Array<Country>;

export declare const sortCountriesByDislikesAscending: (
  countries: ReadonlyArray<Country>
) => Array<Country>;

export declare const resolveTopDislikedOptions: (rawOptions: unknown) => TopDislikedLoaderOptions;

export declare const readTopDislikedCountries: (
  options?: TopDislikedLoaderOptions | unknown
) => Effect.Effect<Array<Country>, never>;

export declare const getTopDislikedCountries: typeof readTopDislikedCountries;
export declare const loadTopDislikedCountries: typeof readTopDislikedCountries;

export declare const loadTopDislikedRouteData: (
  options?: TopDislikedLoaderOptions
) => Promise<TopDislikedLoaderResult>;

export declare const loader: (
  args?: { request?: Request } | unknown
) => Promise<TopDislikedLoaderResult>;
