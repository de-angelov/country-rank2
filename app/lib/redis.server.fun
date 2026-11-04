import { Effect, Option } from "effect"
import { createClient } from "redis"

export redisUrlEnvVar = "REDIS_URL"

ts {
  export type RedisConfig = Readonly<{
    url: string;
  }>;

  export type RedisConfigurationError = Readonly<{
    code: "missing_redis_config";
    message: string;
    envVar: typeof redisUrlEnvVar;
  }>;

  export type RedisConnectionFailure = Readonly<{
    code: "redis_connection_failed";
    message: string;
    cause: unknown;
  }>;

  export type RedisConnectionError =
    | RedisConfigurationError
    | RedisConnectionFailure;

  export type RedisConnectableClient = {
    connect: () => Promise<unknown>;
  };

  export type RedisClientFactory<Client extends RedisConnectableClient> = (
    config: RedisConfig
  ) => Client;

  export type RedisClientProviderOptions<Client extends RedisConnectableClient> = Readonly<{
    env?: NodeJS.ProcessEnv;
    clientFactory: RedisClientFactory<Client>;
    missingConfigMessage: string;
    connectionFailureMessage: string;
  }>;

  export const resolveRedisUrl = (env?: NodeJS.ProcessEnv): string | null => {
    const rawEnv = env ?? (typeof process !== "undefined" ? process.env : undefined);
    const url = rawEnv?.[redisUrlEnvVar]?.trim();
    return url && url.length > 0 ? url : null;
  };

  export class ClientCache<Client extends RedisConnectableClient> {
    private clientPromise: Promise<Client> | undefined;
    constructor(private options: RedisClientProviderOptions<Client>) {}

    get(config: RedisConfig): Effect.Effect<Client, RedisConnectionFailure> {
      if (!this.clientPromise) {
        try {
          const client = this.options.clientFactory(config);
          this.clientPromise = Promise.resolve(client.connect()).then(
            () => client,
            (cause) => {
              this.clientPromise = undefined;
              throw cause;
            }
          );
        } catch (cause) {
          this.clientPromise = undefined;
          return Effect.fail({
            code: "redis_connection_failed",
            message: this.options.connectionFailureMessage,
            cause,
          });
        }
      }
      return Effect.tryPromise({
        try: () => this.clientPromise!,
        catch: (cause): RedisConnectionFailure => {
          this.clientPromise = undefined;
          return {
            code: "redis_connection_failed",
            message: this.options.connectionFailureMessage,
            cause,
          };
        },
      });
    }
  }

  export const getRedisConfig = (
    env?: NodeJS.ProcessEnv,
    message: string = `${redisUrlEnvVar} must be set to connect to Redis.`
  ): Effect.Effect<RedisConfig, RedisConfigurationError> => {
    const url = resolveRedisUrl(env);
    if (!url) {
      return Effect.fail({
        code: "missing_redis_config",
        message,
        envVar: redisUrlEnvVar,
      });
    }
    return Effect.succeed({ url });
  };
}

export createDefaultRedisClient = (config: ts { RedisConfig }): ts { RedisConnectableClient } =>
  => createClient({ url: config.url })

ts {
  export const createRedisClientProvider = <Client extends RedisConnectableClient>(
    options: RedisClientProviderOptions<Client>
  ): (() => Effect.Effect<Client, RedisConnectionError>) => {
    const cache = new ClientCache(options);
    return () =>
      Effect.gen(function* () {
        const config = yield* getRedisConfig(
          options.env,
          options.missingConfigMessage
        );
        const client = yield* cache.get(config);
        return client;
      });
  };
}
