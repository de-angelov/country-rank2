import { Like as LikeSchema, Dislike as DislikeSchema } from "./country.js"
import type { VoteKind as ImportedVoteKind } from "./country.js"
import type { CountryVoteTotalsOptions as ImportedCountryVoteTotalsOptions } from "./redis-totals.server.js"
import { countryFixtures as importedCountryFixtures, fixtures as importedFixtures } from "./fixtures.js"
import { readCountriesWithVoteTotals as importedReadCountriesWithVoteTotals, getCountriesWithVoteTotals as importedGetCountriesWithVoteTotals, loadCountriesWithVoteTotals as importedLoadCountriesWithVoteTotals, mergeCountriesWithVoteTotals as importedMergeCountriesWithVoteTotals, createFallbackCountries as importedCreateFallbackCountries, logRedisTotalsError as importedLogRedisTotalsError } from "./redis-totals.server.js"

export schema Country = {
  code: String
  name: String
  capital: String
  factSnippet: String
  flagImageUrl: String
  likes: Number
  dislikes: Number
}
export Like = LikeSchema
export Dislike = DislikeSchema
export schema VoteKind = ImportedVoteKind
export schema CountryVoteTotalsOptions = ImportedCountryVoteTotalsOptions
export countryFixtures = importedCountryFixtures
export fixtures = importedFixtures
export readCountriesWithVoteTotals = importedReadCountriesWithVoteTotals
export getCountriesWithVoteTotals = importedGetCountriesWithVoteTotals
export loadCountriesWithVoteTotals = importedLoadCountriesWithVoteTotals
export mergeCountriesWithVoteTotals = importedMergeCountriesWithVoteTotals
export createFallbackCountries = importedCreateFallbackCountries
export logRedisTotalsError = importedLogRedisTotalsError
