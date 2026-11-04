import type { Effect } from "effect";
import type { Country } from "../../countries/country.js";
import type { CountryVoteTotalsOptions } from "../../countries/redis-totals.server.js";
import type { RankingOrder } from "../../components/ranking-order-controls/ranking-order-controls.js";

export type RankingSortOrder = "highest-first" | "lowest-first" | RankingOrder;

export type TopLikedLoaderOptions = CountryVoteTotalsOptions & Readonly<{
  order?: RankingSortOrder;
}>;

export interface TopLikedLoaderResult {
  countries: Array<Country>;
}

export declare const isLowestFirst: (order?: RankingSortOrder) => boolean;

export declare const sortCountriesByLikes: (
  countries: ReadonlyArray<Country>,
  order?: RankingSortOrder
) => Array<Country>;

export declare const sortCountriesByLikesDescending: (
  countries: ReadonlyArray<Country>
) => Array<Country>;

export declare const sortCountriesByLikesAscending: (
  countries: ReadonlyArray<Country>
) => Array<Country>;

export declare const resolveTopLikedOptions: (rawOptions: unknown) => TopLikedLoaderOptions;

export declare const readTopLikedCountries: (
  options?: TopLikedLoaderOptions | unknown
) => Effect.Effect<Array<Country>, never>;

export declare const getTopLikedCountries: typeof readTopLikedCountries;
export declare const loadTopLikedCountries: typeof readTopLikedCountries;

export declare const loadTopLikedRouteData: (
  options?: TopLikedLoaderOptions
) => Promise<TopLikedLoaderResult>;

export declare const loader: (
  args?: { request?: Request } | unknown
) => Promise<TopLikedLoaderResult>;
