import { Effect, Option, Schema } from "effect"
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
  variables = Option.fromNullishOr(env) |> Option.getOrElse(() => process.env)
  url = Option.map(Option.fromNullishOr(variables[redisUrlEnvVar]), (value) => value |> String.trim)
  nonEmpty = Option.filter(url, (value) => value.length #! 0)
  => Option.getOrNull(nonEmpty)

export getRedisConfig = (env?: NodeJS.ProcessEnv, message?: String) =>
  url = Option.fromNullishOr(resolveRedisUrl(Option.getOrUndefined(env)))
  failureMessage = Option.fromNullishOr(message) |> Option.getOrElse(() => "REDIS_URL must be set to connect to Redis.")
  => match url
    | Some(value) => Effect.succeed({ url: value })
    | None => Effect.fail({ code: "missing_redis_config", message: failureMessage, envVar: redisUrlEnvVar })

export createDefaultRedisClient = (config: RedisConfig) =>
  createClient({ url: config.url })

export createRedisClientProvider = <Client extends RedisConnectableClient>(options: RedisClientProviderOptions<Client>) =>
  mut cachedClient: Option<Client> = Option.none()
  toConnectionError = (err: Unknown) =>
    causeRecord = Schema.decodeUnknownOption(Schema.Struct({ cause: Schema.Unknown }))(err)
    actualCause = match causeRecord
      | Some(rec) => rec.cause
      | None => err
    => {
      code: "redis_connection_failed",
      message: options.connectionFailureMessage,
      cause: actualCause
    }

  connectClient = (config: RedisConfig) =>
    effect {
      client <- Effect.try(() => options.clientFactory(config))
      _ <- Effect.tryPromise(() => client.connect())
      cachedClient = Option.some(client)
      => client
    }
    |> Effect.mapError(toConnectionError)

  getClient = (config: RedisConfig) =>
    cachedClient |> Option.match({
      onSome: (client) => Effect.succeed(client),
      onNone: () => connectClient(config)
    })

  => () => effect {
    config <- getRedisConfig(Option.getOrUndefined(options.env), options.missingConfigMessage)
    client <- getClient(config)
    => client
  }
