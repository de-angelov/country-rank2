import { Effect, Option } from "effect"
import { createClient } from "redis"

export redisUrlEnvVar = "REDIS_URL"

export schema RedisConfig = {
  url: String
}

export schema RedisConfigurationError = ts { Readonly<{ code: "missing_redis_config"; message: string; envVar: typeof redisUrlEnvVar }> }
export schema RedisConnectionFailure = ts { Readonly<{ code: "redis_connection_failed"; message: string; cause: unknown }> }
export schema RedisConnectionError = ts { RedisConfigurationError | RedisConnectionFailure }

export schema RedisConnectableClient = ts { { connect: () => Promise<unknown> } }

export schema RedisClientFactory<Client> = ts { (config: RedisConfig) => Client }

export schema RedisClientProviderOptions<Client> = ts { Readonly<{ env?: NodeJS.ProcessEnv; clientFactory: (config: RedisConfig) => Client; missingConfigMessage: string; connectionFailureMessage: string; }> }

export resolveRedisUrl = (env?: ts { NodeJS.ProcessEnv }) =>
  variables = Option.getOrElse(env, () => process.env)
  url = Option.map(Option.fromNullishOr(variables[redisUrlEnvVar]), (value) => value.trim())
  nonEmpty = Option.filter(url, (value) => value.length #! 0)
  => Option.getOrNull(nonEmpty)

export getRedisConfig = (env?: ts { NodeJS.ProcessEnv }, message?: String) =>
  url = Option.fromNullishOr(resolveRedisUrl(Option.getOrUndefined(env)))
  failureMessage = Option.getOrElse(message, () => "REDIS_URL must be set to connect to Redis.")
  => match url
    | Some(value) => Effect.succeed({ url: value })
    | None => Effect.fail(Object.freeze({ code: "missing_redis_config", message: failureMessage, envVar: redisUrlEnvVar }))

export createDefaultRedisClient = (config: ts { RedisConfig }): ts { RedisConnectableClient } =>
  => createClient({ url: config.url })

export createRedisClientProvider = (options: ts { RedisClientProviderOptions<any> }) =>
  mut cachedClient: Option<ts { any }> = Option.none()
  getClient = (config: ts { RedisConfig }) =>
    match cachedClient
      | Some(client) => Effect.succeed(client)
      | None =>
          Effect.flatMap(
            Effect.mapError(
              Effect.tryPromise(() => {
                client = options.clientFactory(config)
                => Promise.resolve(client.connect()).then(() => client, (cause) => {
                  cachedClient = Option.none()
                  => Promise.reject(cause)
                })
              }),
              (err: ts { any }) => Object.freeze({ code: "redis_connection_failed", message: options.connectionFailureMessage, cause: Option.getOrElse(Option.fromNullishOr(err.cause), () => err) })
            ),
            (client) => {
              cachedClient = Option.some(client)
              => Effect.succeed(client)
            }
          )

  => () => effect {
    config <- getRedisConfig(options.env, options.missingConfigMessage)
    client <- getClient(config)
    => client
  }
