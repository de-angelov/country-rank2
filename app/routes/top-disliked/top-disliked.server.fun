import { Effect } from "effect"
import { readCountriesWithVoteTotals } from "../../countries/redis-totals.server.js"

ts {
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

  export const isLowestFirst = (order?: RankingSortOrder): boolean => {
    if (!order) return false;
    if (order === "lowest-first") return true;
    if (typeof order === "object" && "_tag" in order && order._tag === "LowestFirst") return true;
    return false;
  };

  export const sortCountriesByDislikesDescending = (
    countries: ReadonlyArray<Country>
  ): Array<Country> =>
    [...countries].sort((a, b) => {
      if (b.dislikes !== a.dislikes) {
        return b.dislikes - a.dislikes;
      }
      return a.name.localeCompare(b.name);
    });

  export const sortCountriesByDislikesAscending = (
    countries: ReadonlyArray<Country>
  ): Array<Country> =>
    [...sortCountriesByDislikesDescending(countries)].reverse();

  export const sortCountriesByDislikes = (
    countries: ReadonlyArray<Country>,
    order?: RankingSortOrder
  ): Array<Country> =>
    isLowestFirst(order)
      ? sortCountriesByDislikesAscending(countries)
      : sortCountriesByDislikesDescending(countries);

  export const resolveTopDislikedOptions = (rawOptions: unknown): TopDislikedLoaderOptions =>
    (rawOptions ?? {}) as TopDislikedLoaderOptions;
}

export readTopDislikedCountries = (options: Unknown) =>
  effect {
    resolved = resolveTopDislikedOptions(options)
    countries <- readCountriesWithVoteTotals(resolved)
    sorted = sortCountriesByDislikes(countries, resolved.order)
    => sorted
  }

export getTopDislikedCountries = readTopDislikedCountries
export loadTopDislikedCountries = readTopDislikedCountries

ts {
  export const loadTopDislikedRouteData = async (
    options?: TopDislikedLoaderOptions
  ): Promise<TopDislikedLoaderResult> => {
    const countries = await Effect.runPromise(readTopDislikedCountries(options));
    return { countries };
  };

  export const loader = async (
    args?: { request?: Request } | unknown
  ): Promise<TopDislikedLoaderResult> => {
    let order: RankingSortOrder | undefined;
    if (args && typeof args === "object" && "request" in args) {
      const maybeRequest = (args as { request?: unknown }).request;
      if (maybeRequest instanceof Request) {
        const url = new URL(maybeRequest.url);
        const orderParam = url.searchParams.get("order");
        if (orderParam === "lowest-first" || orderParam === "highest-first") {
          order = orderParam;
        }
      }
    }
    return loadTopDislikedRouteData({ order });
  };
}
