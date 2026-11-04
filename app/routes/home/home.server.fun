import { Effect } from "effect"
import { readCountriesWithVoteTotals } from "../../countries/redis-totals.server.js"

ts {
  import type { Country } from "../../countries/country.js";
  import type { CountryVoteTotalsOptions } from "../../countries/redis-totals.server.js";
  import { countryFixtures } from "../../countries/fixtures.js";
  import { createFallbackCountries } from "../../countries/redis-totals.server.js";

  export type HomeLoaderOptions = CountryVoteTotalsOptions;

  export interface HomeLoaderResult {
    countries: Array<Country>;
  }

  export type HomeRouteData = HomeLoaderResult;

  export const resolveHomeOptions = (rawOptions: unknown): HomeLoaderOptions =>
    (rawOptions ?? {}) as HomeLoaderOptions;
}

export readHomeCountries = (options: Unknown) =>
  effect {
    resolved = resolveHomeOptions(options)
    countries <- readCountriesWithVoteTotals(resolved)
    => countries
  }

export getHomeCountries = readHomeCountries
export loadHomeCountries = readHomeCountries

ts {
  export const loadHomeRouteData = async (
    options?: HomeLoaderOptions
  ): Promise<HomeLoaderResult> => {
    try {
      const countries = await Effect.runPromise(readHomeCountries(options));
      return { countries };
    } catch {
      const fixtures = options?.fixtures ?? countryFixtures;
      return { countries: createFallbackCountries(fixtures) };
    }
  };

  export const loader = async (
    _args?: { request?: Request } | unknown
  ): Promise<HomeLoaderResult> => {
    return loadHomeRouteData();
  };
}
