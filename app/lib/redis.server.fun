import { Effect, Option } from "effect"
import { createClient } from "redis"

export redisUrlEnvVar = "REDIS_URL"

export schema RedisConfig = {
  url: String
}

export schema RedisConfigurationError = {
  code: "missing_redis_config"
  message: String
  envVar: typeof redisUrlEnvVar
}
export schema RedisConnectionFailure = {
  code: "redis_connection_failed"
  message: String
  cause: Unknown
}
export schema RedisConnectionError = RedisConfigurationError | RedisConnectionFailure

export schema RedisConnectableClient = {
  connect: () => Promise<Unknown>
}

export schema RedisClientFactory<Client> = (config: RedisConfig) => Client

export schema RedisClientProviderOptions<Client> = {
  env?: NodeJS.ProcessEnv
  clientFactory: (config: RedisConfig) => Client
  missingConfigMessage: String
  connectionFailureMessage: String
}

export resolveRedisUrl = (env?: NodeJS.ProcessEnv) =>
  variables = match env
    | Some(e) => e
    | None => process.env
  url = Option.map(Option.fromNullishOr(variables[redisUrlEnvVar]), (value) => value |> String.trim)
  nonEmpty = Option.filter(url, (value) => value.length #! 0)
  => Option.getOrNull(nonEmpty)

export getRedisConfig = (env?: NodeJS.ProcessEnv, message?: String) =>
  url = Option.fromNullishOr(resolveRedisUrl(env))
  failureMessage = match message
    | Some(msg) => msg
    | None => "REDIS_URL must be set to connect to Redis."
  => match url
    | Some(value) => Effect.succeed({ url: value })
    | None => Effect.fail({ code: "missing_redis_config", message: failureMessage, envVar: redisUrlEnvVar })

export createDefaultRedisClient = (config: RedisConfig): RedisConnectableClient =>
  createClient({ url: config.url })

export createRedisClientProvider = <Client>(options: RedisClientProviderOptions<Client>) =>
  mut cachedClient: Option<Client> = Option.none()
  getClient = (config: RedisConfig) =>
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
              (err: Any) => ({
                code: "redis_connection_failed",
                message: options.connectionFailureMessage,
                cause: match Option.fromNullishOr(err.cause)
                  | Some(c) => c
                  | None => err
              })
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
