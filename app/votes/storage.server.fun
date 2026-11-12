import { Array, Effect, Number, Option, Record } from "effect"
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
  getRedisConfig(env, "REDIS_URL must be set to read or write vote totals.")

export validateCountryCode = (countryCode: String) =>
  normalized = countryCode |> String.trim |> String.toUpperCase
  => match RegExp("^[A-Z][A-Z]$").test(normalized)
    | true => Effect.succeed(normalized)
    | false => Effect.fail({ code: "invalid_country_code", message: "Country code must be a two-letter ISO country code.", countryCode: countryCode })

export voteTotalsKey = (voteKind: VoteKind) =>
  match voteKind
    | "like" => "country:votes:likes"
    | _ => "country:votes:dislikes"

export createDefaultRedisVoteClient = (config: RedisVoteStorageConfig): RedisVoteClient =>
  createDefaultRedisClient(config)

export createRedisVoteStorage = (options?: RedisVoteStorageOptions) =>
  opts = match options
    | Some(o) => o
    | None => {}
  clientFactory = match Option.fromNullishOr(opts.clientFactory)
    | Some(factory) => factory
    | None => createDefaultRedisVoteClient
  getClient = createRedisClientProvider({
    env: opts.env,
    clientFactory,
    missingConfigMessage: redisUrlEnvVar + " must be set to read or write vote totals.",
    connectionFailureMessage: "Failed to connect to Redis vote storage."
  })

  runRedis = (tryFn: () => Promise<Unknown>, message: String) =>
    Effect.mapError(
      Effect.tryPromise(tryFn),
      (cause: Any) => ({
        code: "redis_command_failed",
        message: message,
        cause: match Option.fromNullishOr(cause.cause)
          | Some(c) => c
          | None => cause
      })
    )

  parseVoteCount = (rawCount: Option<String>) =>
    match rawCount
      | Some(str) => match Number.parse(str)
        | Some(n) => n
        | None => 0
      | None => 0

  readCountryVoteTotals = (countryCode: String) =>
    effect {
      normalized <- validateCountryCode(countryCode)
      client <- getClient()
      likes <- runRedis(() => client.hGet(voteTotalsKey("like"), normalized), "Failed to read country vote totals from Redis.")
      dislikes <- runRedis(() => client.hGet(voteTotalsKey("dislike"), normalized), "Failed to read country vote totals from Redis.")
      => {
        countryCode: normalized,
        likes: parseVoteCount(Option.fromNullishOr(likes)),
        dislikes: parseVoteCount(Option.fromNullishOr(dislikes))
      }
    }

  readAllCountryVoteTotals = () =>
    effect {
      client <- getClient()
      likesByCountry <- runRedis(() => client.hGetAll(voteTotalsKey("like")), "Failed to read country vote totals from Redis.")
      dislikesByCountry <- runRedis(() => client.hGetAll(voteTotalsKey("dislike")), "Failed to read country vote totals from Redis.")
      likes = match Option.fromNullishOr(likesByCountry)
        | Some(l) => l
        | None => {}
      dislikes = match Option.fromNullishOr(dislikesByCountry)
        | Some(d) => d
        | None => {}
      allKeys = Array.appendAll(Record.keys(likes), Record.keys(dislikes))
      countryCodes = Array.dedupe(allKeys)
      entries = countryCodes |> Array.map((code) => [code, {
        countryCode: code,
        likes: parseVoteCount(likes[code]),
        dislikes: parseVoteCount(dislikes[code])
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
