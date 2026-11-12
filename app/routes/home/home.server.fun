import { Country } from "../../countries/index.js"
import { Effect } from "effect"
import type { CountryVoteTotalsOptions } from "../../countries/index.js"
import { readCountriesWithVoteTotals } from "../../countries/redis-totals.server.js"

export schema HomeLoaderResult = {
  countries: Array<Country>
}
export schema HomeLoaderOptions = CountryVoteTotalsOptions
export schema HomeRouteData = HomeLoaderResult

export readHomeCountries = (options?: CountryVoteTotalsOptions) =>
  match options
    | Some(opts) => readCountriesWithVoteTotals(opts)
    | None => readCountriesWithVoteTotals()

export getHomeCountries = readHomeCountries
export loadHomeCountries = readHomeCountries

export loadHomeRouteData = (options?: CountryVoteTotalsOptions) =>
  result = effect {
    countries <- match options
      | Some(opts) => readHomeCountries(opts)
      | None => readHomeCountries()
    => { countries: countries }
  }
  => Effect.runPromise(result)

export loader = (_args: Unknown = {}) => loadHomeRouteData()
