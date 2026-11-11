import { Effect, Option } from "effect"
import { createDefaultRedisClient, createRedisClientProvider, getRedisConfig, redisUrlEnvVar } from "../lib/redis.server.js"

export schema VoteKind = "like" | "dislike"

export schema VoteTotals = {
  countryCode: String
  likes: Number
  dislikes: Number
}

export schema VoteTotalsByCountry = Map<String, VoteTotals>
export schema RedisVoteStorageConfig = {
  url: String
}
export schema RedisVoteStorageError = Any
export schema RedisVoteClient = {
  connect: () => Promise<Unknown>
  hGet: (key: String, field: String) => Promise<String | Null>
  hGetAll: (key: String) => Promise<Record<String, String>>
  hIncrBy: (key: String, field: String, increment: Number) => Promise<Number>
}
export schema RedisVoteClientFactory = (config: RedisVoteStorageConfig) => RedisVoteClient
export schema RedisVoteStorageOptions = {
  env?: NodeJS.ProcessEnv
  clientFactory?: RedisVoteClientFactory
}

export getRedisVoteStorageConfig = (env?: NodeJS.ProcessEnv) =>
  => getRedisConfig(Option.getOrUndefined(env), "REDIS_URL must be set to read or write vote totals.")

export validateCountryCode = (countryCode: String) =>
  normalized = countryCode.trim().toUpperCase()
  => match RegExp("^[A-Z][A-Z]$").test(normalized)
    | true => Effect.succeed(normalized)
    | false => Effect.fail(Object.freeze({ code: "invalid_country_code", message: "Country code must be a two-letter ISO country code.", countryCode: countryCode }))

export voteTotalsKey = (voteKind: VoteKind) =>
  match voteKind
    | "like" => "country:votes:likes"
    | _ => "country:votes:dislikes"

export createDefaultRedisVoteClient = (config: RedisVoteStorageConfig): RedisVoteClient =>
  => createDefaultRedisClient(config)

export createRedisVoteStorage = (options?: RedisVoteStorageOptions) =>
  opts = Option.getOrElse(options, () => ({}))
  clientFactory = Option.getOrElse(Option.fromNullishOr(opts.clientFactory), () => createDefaultRedisVoteClient)
  getClient = createRedisClientProvider({
    env: opts.env,
    clientFactory: clientFactory,
    missingConfigMessage: redisUrlEnvVar + " must be set to read or write vote totals.",
    connectionFailureMessage: "Failed to connect to Redis vote storage."
  })

  runRedis = (tryFn: () => Promise<Unknown>, message: String) =>
    Effect.mapError(
      Effect.tryPromise(tryFn),
      (cause: Any) => Object.freeze({ code: "redis_command_failed", message: message, cause: Option.getOrElse(Option.fromNullishOr(cause.cause), () => cause) })
    )

  readCountryVoteTotals = (countryCode: String) =>
    effect {
      normalized <- validateCountryCode(countryCode)
      client <- getClient()
      likes <- runRedis(() => client.hGet(voteTotalsKey("like"), normalized), "Failed to read country vote totals from Redis.")
      dislikes <- runRedis(() => client.hGet(voteTotalsKey("dislike"), normalized), "Failed to read country vote totals from Redis.")
      => {
        countryCode: normalized,
        likes: Number(Option.getOrElse(Option.fromNullishOr(likes), () => 0)),
        dislikes: Number(Option.getOrElse(Option.fromNullishOr(dislikes), () => 0))
      }
    }

  readAllCountryVoteTotals = () =>
    effect {
      client <- getClient()
      likesByCountry <- runRedis(() => client.hGetAll(voteTotalsKey("like")), "Failed to read country vote totals from Redis.")
      dislikesByCountry <- runRedis(() => client.hGetAll(voteTotalsKey("dislike")), "Failed to read country vote totals from Redis.")
      likes = Option.getOrElse(Option.fromNullishOr(likesByCountry), () => Object.freeze({}))
      dislikes = Option.getOrElse(Option.fromNullishOr(dislikesByCountry), () => Object.freeze({}))
      allKeys = Object.keys(likes).concat(Object.keys(dislikes))
      countryCodes = Array.from(Set(allKeys))
      entries = countryCodes.map((code) => [code, {
        countryCode: code,
        likes: Number(Option.getOrElse(Option.fromNullishOr(likes[code]), () => 0)),
        dislikes: Number(Option.getOrElse(Option.fromNullishOr(dislikes[code]), () => 0))
      }])
      => Map(entries)
    }

  incrementCountryVoteTotal = (countryCode: String, voteKind: VoteKind) =>
    effect {
      normalized <- validateCountryCode(countryCode)
      client <- getClient()
      _ <- runRedis(() => client.hIncrBy(voteTotalsKey(voteKind), normalized, 1), "Failed to increment country vote total in Redis.")
      totals <- readCountryVoteTotals(normalized)
      => totals
    }

  => {
    readAllCountryVoteTotals: readAllCountryVoteTotals,
    readCountryVoteTotals: readCountryVoteTotals,
    incrementCountryVoteTotal: incrementCountryVoteTotal
  }

export defaultVoteStorage = createRedisVoteStorage()

export readAllCountryVoteTotals = defaultVoteStorage.readAllCountryVoteTotals
export readCountryVoteTotals = defaultVoteStorage.readCountryVoteTotals
export incrementCountryVoteTotal = defaultVoteStorage.incrementCountryVoteTotal
