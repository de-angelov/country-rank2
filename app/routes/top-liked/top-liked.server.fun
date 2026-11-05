import { Effect } from "effect"
import { Country } from "../../countries/country.js"
import { readCountriesWithVoteTotals } from "../../countries/redis-totals.server.js"
import { LowestFirst } from "../../components/ranking-order-controls/ranking-order-controls.js"

export schema TopLikedLoaderResult = {
  countries: Array<Country>
}

export schema TopLikedLoaderOptions = {
  order: Unknown
}

export schema TopLikedRequest = {
  url: String
}

export schema TopLikedLoaderArgs = {
  request: TopLikedRequest
}

export isLowestFirst = (order: Unknown): Boolean =>
  match order
    | "lowest-first" => true
    | LowestFirst => true
    | _ => false

export sortCountriesByLikesDescending = (countries: Array<Country>) =>
  sorted = countries.slice().sort((a, b) =>
    difference = b.likes - a.likes
    match difference #= 0
      | true => a.name.localeCompare(b.name)
      | false => difference
  )
  => sorted

export sortCountriesByLikesAscending = (countries: Array<Country>) =>
  sorted = sortCountriesByLikesDescending(countries)
  => sorted.reverse()

export sortCountriesByLikes = (countries: Array<Country>, order: Unknown) =>
  match isLowestFirst(order)
    | true => sortCountriesByLikesAscending(countries)
    | false => sortCountriesByLikesDescending(countries)

export resolveTopLikedOptions = (rawOptions: TopLikedLoaderOptions): TopLikedLoaderOptions => rawOptions

export readTopLikedCountries = (options: TopLikedLoaderOptions) =>
  effect {
    resolved = resolveTopLikedOptions(options)
    countries <- readCountriesWithVoteTotals(resolved)
    sorted = sortCountriesByLikes(countries, resolved.order)
    => sorted
  }

export getTopLikedCountries = readTopLikedCountries
export loadTopLikedCountries = readTopLikedCountries

export wrapTopLikedCountries = (countries: Array<Country>) =>
  result = { countries: countries }
  => result

export loadTopLikedRouteData = (options: TopLikedLoaderOptions) =>
  mapped = Effect.map(readTopLikedCountries(options), wrapTopLikedCountries)
  => Effect.runPromise(mapped)

export loader = (args: TopLikedLoaderArgs) =>
  resolvedArgs = args or { request: { url: "http://localhost" } }
  request = resolvedArgs.request
  order = match request.url.includes("order=lowest-first")
    | true => "lowest-first"
    | false => "highest-first"
  => loadTopLikedRouteData({ order: order })
