import { Effect } from "effect"
import { createDefaultRedisClient, createRedisClientProvider, getRedisConfig, redisUrlEnvVar } from "../lib/redis.server.js"

ts {
  import type { RedisClientFactory, RedisConfig } from "../lib/redis.server.js";

  const countryCodePattern = /^[A-Z]{2}$/;

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

  export const getRedisVoteStorageConfig = (env?: NodeJS.ProcessEnv) =>
    getRedisConfig(
      env,
      `${redisUrlEnvVar} must be set to read or write vote totals.`
    );

  export const voteTotalsKey = (voteKind: VoteKind) =>
    `country:votes:${voteKind === "like" ? "likes" : "dislikes"}`;

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

    const withValidCountryCode = <Value extends unknown>(
      countryCode: string,
      fn: (normalizedCountryCode: string) => Effect.Effect<Value, RedisVoteStorageError>
    ): Effect.Effect<Value, RedisVoteStorageError> => {
      const normalizedCountryCode = countryCode.trim().toUpperCase();

      if (!countryCodePattern.test(normalizedCountryCode)) {
        return Effect.fail({
          code: "invalid_country_code",
          message: "Country code must be a two-letter ISO country code.",
          countryCode,
        });
      }

      return fn(normalizedCountryCode);
    };

    const readCountryVoteTotals = (
      countryCode: string
    ): Effect.Effect<VoteTotals, RedisVoteStorageError> =>
      withValidCountryCode(countryCode, (normalizedCountryCode) =>
        getClient().pipe(
          Effect.flatMap((client) =>
            Effect.tryPromise({
              try: () =>
                Promise.all([
                  client.hGet(voteTotalsKey("like"), normalizedCountryCode),
                  client.hGet(voteTotalsKey("dislike"), normalizedCountryCode),
                ]),
              catch: (cause) => ({
                code: "redis_command_failed" as const,
                message: "Failed to read country vote totals from Redis.",
                cause,
              }),
            })
          ),
          Effect.map(([likes, dislikes]) => ({
            countryCode: normalizedCountryCode,
            likes: Number(likes ?? 0),
            dislikes: Number(dislikes ?? 0),
          }))
        )
      );

    const readAllCountryVoteTotals = (): Effect.Effect<
      VoteTotalsByCountry,
      RedisVoteStorageError
    > =>
      getClient().pipe(
        Effect.flatMap((client) =>
          Effect.tryPromise({
            try: () =>
              Promise.all([
                client.hGetAll(voteTotalsKey("like")),
                client.hGetAll(voteTotalsKey("dislike")),
              ]),
            catch: (cause) => ({
              code: "redis_command_failed" as const,
              message: "Failed to read country vote totals from Redis.",
              cause,
            }),
          })
        ),
        Effect.map(([likesByCountry, dislikesByCountry]) => {
          const likes = likesByCountry ?? {};
          const dislikes = dislikesByCountry ?? {};
          const countryCodes = new Set([
            ...Object.keys(likes),
            ...Object.keys(dislikes),
          ]);

          return new Map(
            [...countryCodes].map((countryCode) => [
              countryCode,
              {
                countryCode,
                likes: Number(likes[countryCode] ?? 0),
                dislikes: Number(dislikes[countryCode] ?? 0),
              },
            ])
          );
        })
      );

    const incrementCountryVoteTotal = (
      countryCode: string,
      voteKind: VoteKind
    ): Effect.Effect<VoteTotals, RedisVoteStorageError> =>
      withValidCountryCode(countryCode, (normalizedCountryCode) =>
        getClient().pipe(
          Effect.flatMap((client) =>
            Effect.tryPromise({
              try: () =>
                client.hIncrBy(voteTotalsKey(voteKind), normalizedCountryCode, 1),
              catch: (cause) => ({
                code: "redis_command_failed" as const,
                message: "Failed to increment country vote total in Redis.",
                cause,
              }),
            })
          ),
          Effect.flatMap(() => readCountryVoteTotals(normalizedCountryCode))
        )
      );

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
