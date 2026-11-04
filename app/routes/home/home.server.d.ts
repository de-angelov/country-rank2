import type { Effect } from "effect";
import type { Country } from "../../countries/country.js";
import type { CountryVoteTotalsOptions } from "../../countries/redis-totals.server.js";

export type HomeLoaderOptions = CountryVoteTotalsOptions;

export interface HomeLoaderResult {
  countries: Array<Country>;
}

export type HomeRouteData = HomeLoaderResult;

export declare const resolveHomeOptions: (rawOptions: unknown) => HomeLoaderOptions;

export declare const readHomeCountries: (
  options?: HomeLoaderOptions | unknown
) => Effect.Effect<Array<Country>, never>;

export declare const getHomeCountries: typeof readHomeCountries;
export declare const loadHomeCountries: typeof readHomeCountries;

export declare const loadHomeRouteData: (
  options?: HomeLoaderOptions
) => Promise<HomeLoaderResult>;

export declare const loader: (
  args?: { request?: Request } | unknown
) => Promise<HomeLoaderResult>;
