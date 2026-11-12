import { Effect, Option } from "effect"
import { Country } from "../../countries/country.js"
import type { CountryVoteTotalsOptions } from "../../countries/redis-totals.server.js"
import { readCountriesWithVoteTotals } from "../../countries/redis-totals.server.js"
import { sortCountriesByLikes } from "./ranking.js"

export schema ReadTopLikedCountriesOptions = CountryVoteTotalsOptions & {
  order?: Unknown
}

export readTopLikedCountries = (options: ReadTopLikedCountriesOptions) =>
  effect {
    resolved = { readTotals: options.readTotals, fixtures: options.fixtures, logger: options.logger }
    countries <- readCountriesWithVoteTotals(resolved)
    sorted = sortCountriesByLikes(countries, options.order)
    => sorted
  }
