import { Country } from "../../countries/index.js"
import type { CountryVoteTotalsOptions } from "../../countries/index.js"
import { readCountriesWithVoteTotals } from "../../countries/redis-totals.server.js"

export schema HomeLoaderResult = {
  countries: Array<Country>
}
export schema HomeLoaderOptions = CountryVoteTotalsOptions
export schema HomeRouteData = HomeLoaderResult

export readHomeCountries = (options: CountryVoteTotalsOptions) => readCountriesWithVoteTotals(options)

export getHomeCountries = readHomeCountries
export loadHomeCountries = readHomeCountries

export loadHomeRouteData = (options: CountryVoteTotalsOptions) =>
  effect {
    countries <- readHomeCountries(options)
    => { countries: countries }
  }

export loader = (_args: Unknown) => loadHomeRouteData({})
