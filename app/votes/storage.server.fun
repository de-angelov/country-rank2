import { Effect, Option } from "effect"
import { createDefaultRedisClient, createRedisClientProvider, getRedisConfig, redisUrlEnvVar } from "../lib/redis.server.js"

export getRedisVoteStorageConfig = (env?: ts { NodeJS.ProcessEnv }) =>
  => getRedisConfig(Option.getOrUndefined(env), "REDIS_URL must be set to read or write vote totals.")

validateCountryCode = (countryCode: String) =>
  normalized = countryCode.trim().toUpperCase()
  => match RegExp("^[A-Z][A-Z]$").test(normalized)
    | true => Effect.succeed(normalized)
    | false => Effect.fail(Object.freeze({ code: "invalid_country_code", message: "Country code must be a two-letter ISO country code.", countryCode: countryCode }))

ts {
  import type { RedisClientFactory, RedisConfig } from "../lib/redis.server.js";

  export type VoteKind = "like" | "dislike";

  export type VoteTotals = Readonly<{
    countryCode: string;
    likes: number;
    dislikes: number;
  }>;

  export type VoteTotalsByCountry = ReadonlyMap<string, VoteTotals>;

  export type RedisVoteStorageConfig = RedisConfig;

  export type RedisVoteStorageError =
    | Readonly<{
        code: "missing_redis_config";
        message: string;
        envVar: typeof redisUrlEnvVar;
      }>
    | Readonly<{
        code: "invalid_country_code";
        message: string;
        countryCode: string;
      }>
    | Readonly<{
        code: "redis_connection_failed" | "redis_command_failed";
        message: string;
        cause: unknown;
      }>;

  export type RedisVoteClient = {
    connect: () => Promise<unknown>;
    hGet: (key: string, field: string) => Promise<string | null>;
    hGetAll: (key: string) => Promise<Record<string, string>>;
    hIncrBy: (key: string, field: string, increment: number) => Promise<number>;
  };

  export type RedisVoteClientFactory = RedisClientFactory<RedisVoteClient>;

  export type RedisVoteStorageOptions = Readonly<{
    env?: NodeJS.ProcessEnv;
    clientFactory?: RedisVoteClientFactory;
  }>;

  export const createDefaultRedisVoteClient: RedisVoteClientFactory = (config) =>
    createDefaultRedisClient(config) as RedisVoteClient;

  export const createRedisVoteStorage = (
    options: RedisVoteStorageOptions = {}
  ) => {
    const clientFactory = options.clientFactory ?? createDefaultRedisVoteClient;
    const getClient = createRedisClientProvider({
      env: options.env,
      clientFactory,
      missingConfigMessage: `${redisUrlEnvVar} must be set to read or write vote totals.`,
      connectionFailureMessage: "Failed to connect to Redis vote storage.",
    });

    const runRedis = <A,>(tryFn: () => Promise<A>, message: string): Effect.Effect<A, RedisVoteStorageError> =>
      Effect.tryPromise({ try: tryFn, catch: (cause): RedisVoteStorageError => ({ code: "redis_command_failed", message, cause }) });

    const readCountryVoteTotals = (
      countryCode: string
    ): Effect.Effect<VoteTotals, RedisVoteStorageError> =>
      Effect.gen(function* () {
        const normalized = yield* validateCountryCode(countryCode);
        const client = yield* getClient();

        const [likes, dislikes] = yield* Effect.all([
          runRedis(
            () => client.hGet(voteTotalsKey("like"), normalized),
            "Failed to read country vote totals from Redis."
          ),
          runRedis(
            () => client.hGet(voteTotalsKey("dislike"), normalized),
            "Failed to read country vote totals from Redis."
          ),
        ]);

        return {
          countryCode: normalized,
          likes: Number(likes ?? 0),
          dislikes: Number(dislikes ?? 0),
        };
      });

    const readAllCountryVoteTotals = (): Effect.Effect<
      VoteTotalsByCountry,
      RedisVoteStorageError
    > =>
      Effect.gen(function* () {
        const client = yield* getClient();

        const [likesByCountry, dislikesByCountry] = yield* Effect.all([
          runRedis(
            () => client.hGetAll(voteTotalsKey("like")),
            "Failed to read country vote totals from Redis."
          ),
          runRedis(
            () => client.hGetAll(voteTotalsKey("dislike")),
            "Failed to read country vote totals from Redis."
          ),
        ]);

        const likes = likesByCountry ?? {};
        const dislikes = dislikesByCountry ?? {};
        const countryCodes = new Set([
          ...Object.keys(likes),
          ...Object.keys(dislikes),
        ]);

        return new Map(
          [...countryCodes].map((code) => [
            code,
            {
              countryCode: code,
              likes: Number(likes[code] ?? 0),
              dislikes: Number(dislikes[code] ?? 0),
            },
          ])
        );
      });

    const incrementCountryVoteTotal = (
      countryCode: string,
      voteKind: VoteKind
    ): Effect.Effect<VoteTotals, RedisVoteStorageError> =>
      Effect.gen(function* () {
        const normalized = yield* validateCountryCode(countryCode);
        const client = yield* getClient();

        yield* runRedis(
          () => client.hIncrBy(voteTotalsKey(voteKind), normalized, 1),
          "Failed to increment country vote total in Redis."
        );

        return yield* readCountryVoteTotals(normalized);
      });

    return {
      readAllCountryVoteTotals,
      readCountryVoteTotals,
      incrementCountryVoteTotal,
    };
  };

  export const defaultVoteStorage = createRedisVoteStorage();

  export const {
    readAllCountryVoteTotals,
    readCountryVoteTotals,
    incrementCountryVoteTotal,
  } = defaultVoteStorage;
}

export voteTotalsKey = (voteKind: VoteKind) =>
  match voteKind
    | "like" => "country:votes:likes"
    | _ => "country:votes:dislikes"
