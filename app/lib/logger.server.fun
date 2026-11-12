import { Effect, Option } from "effect"
import { default as pino } from "pino"
import type { Logger as PinoLogger, DestinationStream } from "pino"

export schema ApplicationLogger = Pick<PinoLogger, "debug" | "info" | "warn" | "error">

export logLevelEnvVar = "LOG_LEVEL"
export redactedLogValue = "[Redacted]"
export defaultLogLevel = "info"

export supportedLogLevels = [
  "trace",
  "debug",
  "info",
  "warn",
  "error",
  "fatal",
  "silent"
]

export schema SupportedLogLevel = (typeof supportedLogLevels)[Number]

export sensitiveLogRedactionPaths = [
  "authorization",
  "Authorization",
  "cookie",
  "Cookie",
  "cookies",
  "headers.authorization",
  "headers.Authorization",
  "headers.cookie",
  "headers.Cookie",
  "headers[\"set-cookie\"]",
  "headers[\"Set-Cookie\"]",
  "headers[\"stripe-signature\"]",
  "headers[\"Stripe-Signature\"]",
  "req.headers.authorization",
  "req.headers.Authorization",
  "req.headers.cookie",
  "req.headers.Cookie",
  "req.headers[\"stripe-signature\"]",
  "req.headers[\"Stripe-Signature\"]",
  "request.headers.authorization",
  "request.headers.Authorization",
  "request.headers.cookie",
  "request.headers.Cookie",
  "request.headers[\"stripe-signature\"]",
  "request.headers[\"Stripe-Signature\"]",
  "stripeSignature",
  "stripe_signature",
  "STRIPE_SECRET_KEY",
  "stripeSecretKey",
  "stripe_secret_key",
  "stripe.secretKey",
  "stripe.secret_key",
  "stripe.apiKey",
  "stripe.api_key",
  "stripeApiKey",
  "stripe_api_key",
  "STRIPE_WEBHOOK_SECRET",
  "stripeWebhookSecret",
  "stripe_webhook_secret",
  "webhookSecret",
  "webhook_secret",
  "stripe.webhookSecret",
  "stripe.webhook_secret",
  "rawBody",
  "rawRequestBody",
  "rawWebhookPayload",
  "body.raw",
  "payload.raw",
  "req.rawBody",
  "request.rawBody",
  "stripe.rawPayload",
  "stripe.rawWebhookPayload",
  "card",
  "cardNumber",
  "card_number",
  "cvc",
  "cvv",
  "paymentMethod",
  "payment_method",
  "paymentMethodData",
  "payment_method_data"
]

export schema CreateApplicationLoggerOptions = {
  env?: NodeJS.ProcessEnv
  stream?: DestinationStream
}

export getLogLevel = (env?: NodeJS.ProcessEnv): SupportedLogLevel =>
  rawEnv = env or process.env
  rawLevel = Option.fromNullishOr(rawEnv[logLevelEnvVar])
  configuredLevel = match rawLevel
    | Some(level) => level |> String.trim |> String.toLowerCase
    | None => ""
  match configuredLevel
    | "trace" => "trace"
    | "debug" => "debug"
    | "info" => "info"
    | "warn" => "warn"
    | "error" => "error"
    | "fatal" => "fatal"
    | "silent" => "silent"
    | _ => defaultLogLevel

export createApplicationLogger = (options?: CreateApplicationLoggerOptions) =>
  opts = options or {}
  config = {
    level: getLogLevel(opts.env),
    redact: {
      paths: sensitiveLogRedactionPaths,
      censor: redactedLogValue
    }
  }
  => pino(config, opts.stream)

mut defaultApplicationLogger: Option<PinoLogger> = Option.none()

export getDefaultApplicationLogger = () =>
  match defaultApplicationLogger
    | Some(instance) => instance
    | None =>
      created = createApplicationLogger()
      defaultApplicationLogger = Option.some(created)
      => created

delegateDebug = (...args: Parameters<PinoLogger["debug"]>) =>
  instance = getDefaultApplicationLogger()
  => instance.debug(...args)

delegateInfo = (...args: Parameters<PinoLogger["info"]>) =>
  instance = getDefaultApplicationLogger()
  => instance.info(...args)

delegateWarn = (...args: Parameters<PinoLogger["warn"]>) =>
  instance = getDefaultApplicationLogger()
  => instance.warn(...args)

delegateError = (...args: Parameters<PinoLogger["error"]>) =>
  instance = getDefaultApplicationLogger()
  => instance["error"](...args)

export logger: ApplicationLogger = {
  debug: delegateDebug,
  info: delegateInfo,
  warn: delegateWarn,
  error: delegateError
}

export getLogger = () =>
  effect {
    => logger
  }

export logInfo = (message: String) =>
  effect {
    _ <- Effect.sync(() => logger.info(message))
    => message
  }

export logWarn = (message: String) =>
  effect {
    _ <- Effect.sync(() => logger.warn(message))
    => message
  }

export logError = (message: String) =>
  effect {
    _ <- Effect.sync(() => logger["error"](message))
    => message
  }
