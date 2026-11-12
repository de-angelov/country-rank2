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
  getRedisConfig(Option.getOrUndefined(env), "REDIS_URL must be set to read or write vote totals.")

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
  opts = options or {}
  clientFactory = opts.clientFactory or createDefaultRedisVoteClient
  getClient = createRedisClientProvider({
    env: opts.env,
    clientFactory,
    missingConfigMessage: redisUrlEnvVar + " must be set to read or write vote totals.",
    connectionFailureMessage: "Failed to connect to Redis vote storage."
  })

  runRedis = (tryFn: () => Promise<Unknown>, message: String) =>
    Effect.mapError(
      Effect.tryPromise(tryFn),
      (cause: Any) => ({ code: "redis_command_failed", message: message, cause: cause.cause or cause })
    )

  readCountryVoteTotals = (countryCode: String) =>
    effect {
      normalized <- validateCountryCode(countryCode)
      client <- getClient()
      likes <- runRedis(() => client.hGet(voteTotalsKey("like"), normalized), "Failed to read country vote totals from Redis.")
      dislikes <- runRedis(() => client.hGet(voteTotalsKey("dislike"), normalized), "Failed to read country vote totals from Redis.")
      => {
        countryCode: normalized,
        likes: Number(likes or 0),
        dislikes: Number(dislikes or 0)
      }
    }

  readAllCountryVoteTotals = () =>
    effect {
      client <- getClient()
      likesByCountry <- runRedis(() => client.hGetAll(voteTotalsKey("like")), "Failed to read country vote totals from Redis.")
      dislikesByCountry <- runRedis(() => client.hGetAll(voteTotalsKey("dislike")), "Failed to read country vote totals from Redis.")
      likes = likesByCountry or {}
      dislikes = dislikesByCountry or {}
      allKeys = Array.appendAll(Record.keys(likes), Record.keys(dislikes))
      countryCodes = Array.fromIterable(Set(allKeys))
      entries = countryCodes |> Array.map((code) => [code, {
        countryCode: code,
        likes: Number(likes[code] or 0),
        dislikes: Number(dislikes[code] or 0)
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
