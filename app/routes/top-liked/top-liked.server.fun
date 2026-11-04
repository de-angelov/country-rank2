import { Effect } from "effect"
import { readCountriesWithVoteTotals } from "../../countries/redis-totals.server.js"

ts {
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

  export const isLowestFirst = (order?: RankingSortOrder): boolean => {
    if (!order) return false;
    if (order === "lowest-first") return true;
    if (typeof order === "object" && "_tag" in order && order._tag === "LowestFirst") return true;
    return false;
  };

  export const sortCountriesByLikesDescending = (
    countries: ReadonlyArray<Country>
  ): Array<Country> =>
    [...countries].sort((a, b) => {
      if (b.likes !== a.likes) {
        return b.likes - a.likes;
      }
      return a.name.localeCompare(b.name);
    });

  export const sortCountriesByLikesAscending = (
    countries: ReadonlyArray<Country>
  ): Array<Country> =>
    [...sortCountriesByLikesDescending(countries)].reverse();

  export const sortCountriesByLikes = (
    countries: ReadonlyArray<Country>,
    order?: RankingSortOrder
  ): Array<Country> =>
    isLowestFirst(order)
      ? sortCountriesByLikesAscending(countries)
      : sortCountriesByLikesDescending(countries);

  export const resolveTopLikedOptions = (rawOptions: unknown): TopLikedLoaderOptions =>
    (rawOptions ?? {}) as TopLikedLoaderOptions;
}

export readTopLikedCountries = (options: Unknown) =>
  effect {
    resolved = resolveTopLikedOptions(options)
    countries <- readCountriesWithVoteTotals(resolved)
    sorted = sortCountriesByLikes(countries, resolved.order)
    => sorted
  }

export getTopLikedCountries = readTopLikedCountries
export loadTopLikedCountries = readTopLikedCountries

ts {
  export const loadTopLikedRouteData = async (
    options?: TopLikedLoaderOptions
  ): Promise<TopLikedLoaderResult> => {
    const countries = await Effect.runPromise(readTopLikedCountries(options));
    return { countries };
  };

  export const loader = async (
    args?: { request?: Request } | unknown
  ): Promise<TopLikedLoaderResult> => {
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
    return loadTopLikedRouteData({ order });
  };
}
