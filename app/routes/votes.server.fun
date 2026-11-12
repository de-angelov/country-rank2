import { Effect, Option, Schema } from "effect"
import { Like, Dislike } from "../countries/country.js"
import { countryFixtures } from "../countries/fixtures.js"
import { incrementCountryVoteTotal } from "../votes/storage.server.js"
import type { VoteTotals, RedisVoteStorageError } from "../votes/storage.server.js"

supportedCountryCodes = countryFixtures.map((country) => country.code.toUpperCase())

readField = (payload: Object, primary: String, fallback: String) =>
  Option.getOrElse(Option.fromNullishOr(Reflect.get(payload, primary)), () => Reflect.get(payload, fallback))

normalizePayload = (payload: Object) =>
  voteType = Option.getOrElse(Option.fromNullishOr(readField(payload, "voteType", "voteKind")), () => Reflect.get(payload, "kind"))
  => { countryCode: readField(payload, "countryCode", "code"), code: Reflect.get(payload, "code"), voteType: voteType, voteKind: Reflect.get(payload, "voteKind"), kind: Reflect.get(payload, "kind") }

normalizeVote = (value: Unknown) =>
  stringValue = Schema.decodeUnknownOption(Schema.String)(value)
  taggedValue = Schema.decodeUnknownOption(Schema.Struct({ _tag: Schema.String }))(value)
  normalized = match stringValue
    | Some(text) => text.trim().toLowerCase()
    | None => match taggedValue
      | Some(tagged) => match tagged._tag
        | "Like" => "like"
        | "Dislike" => "dislike"
        | _ => ""
      | None => ""
  => match normalized
    | "like" => Option.some(Object.freeze({ voteType: "like", voteKind: Like }))
    | "dislike" => Option.some(Object.freeze({ voteType: "dislike", voteKind: Dislike }))
    | _ => Option.none()

export validateVoteRequest = (payload: Object) =>
  rawCountryCode = readField(payload, "countryCode", "code")
  rawVoteType = Option.getOrElse(Option.fromNullishOr(readField(payload, "voteType", "voteKind")), () => Reflect.get(payload, "kind"))
  countryCode = Option.getOrElse(Option.map(Schema.decodeUnknownOption(Schema.String)(rawCountryCode), (value) => value.trim().toUpperCase()), () => "")
  validCountry = supportedCountryCodes.includes(countryCode)
  vote = normalizeVote(rawVoteType)
  validVote = match vote
    | Some(_) => true
    | None => false
  fieldErrors = match [validCountry, validVote]
    | [false, false] => { countryCode: "Country code must match a supported country.", voteType: "Vote type must be like or dislike." }
    | [false, true] => { countryCode: "Country code must match a supported country." }
    | [true, false] => { voteType: "Vote type must be like or dislike." }
    | _ => {}
  => match vote
    | Some(valid) => match validCountry
      | true => Object.freeze({ ok: true, data: { countryCode: countryCode, voteType: valid.voteType, voteKind: valid.voteKind } })
      | false => Object.freeze({ ok: false, error: { code: "invalid_vote_request", message: "Vote request payload is invalid.", fieldErrors: fieldErrors } })
    | None => Object.freeze({ ok: false, error: { code: "invalid_vote_request", message: "Vote request payload is invalid.", fieldErrors: fieldErrors } })

export readVoteRequestPayload = (request: Request) =>
  contentType = Option.fromNullishOrElse(request.headers.get("content-type"), "")
  reading = match contentType.includes("application/json")
    | true => Effect.map(Effect.option(Effect.tryPromise(() => request.json())), (body) => match body
      | Some(value) => match Schema.decodeUnknownOption(Schema.Record(Schema.String, Schema.Unknown))(value)
        | Some(record) => normalizePayload(record)
        | None => {}
      | None => {}
    )
    | false => Effect.map(Effect.option(Effect.tryPromise(() => request.formData())), (body) => match body
      | Some(form) => normalizePayload({ countryCode: form.get("countryCode"), code: form.get("code"), voteType: form.get("voteType"), voteKind: form.get("voteKind"), kind: form.get("kind") })
      | None => {}
    )
  => Effect.runPromise(reading)

storageErrorResponse = (failure: Unknown) =>
  detailSchema = Schema.Struct({ code: Schema.optional(Schema.String), message: Schema.optional(Schema.String), envVar: Schema.optional(Schema.String), countryCode: Schema.optional(Schema.String) })
  details = Option.getOrElse(Schema.decodeUnknownOption(detailSchema)(failure), () => Schema.decodeUnknownSync(detailSchema)({}))
  code = Option.fromNullishOrElse(details.code, "redis_command_failed")
  message = Option.fromNullishOrElse(details.message, "Failed to increment country vote total.")
  statusCode = Option.fromNullishOrElse(details.code, "")
  status = match statusCode
    | "invalid_country_code" => 400
    | "missing_redis_config" => 503
    | "redis_connection_failed" => 503
    | "redis_command_failed" => 503
    | _ => 500
  envDetails = match Option.fromNullishOr(details.envVar)
    | Some(envVar) => { envVar: envVar }
    | None => {}
  countryDetails = match Option.fromNullishOr(details.countryCode)
    | Some(countryCode) => { countryCode: countryCode }
    | None => {}
  errorBody = { code: code, message: message, ...envDetails, ...countryDetails }
  => Response.json({ ok: false, error: errorBody }, { status: status })

toStorageEffect = (operation: Effect<VoteTotals, RedisVoteStorageError> | Promise<VoteTotals>): Effect<VoteTotals, Unknown> =>
  when Effect.isEffect(operation) => operation
  => Effect.mapError(Effect.tryPromise(() => operation), (failure) => failure.cause)

export handleVoteRequest = (request: Request) =>
  result = effect {
    payload <- js readVoteRequestPayload(request)
    validation = validateVoteRequest(payload)
    => match validation
      | { ok: false } => Effect.succeed(Response.json(validation, { status: 400 }))
      | { ok: true, data: valid } => Effect["match"](Effect.flatMap(Effect.mapError(Effect.try(() => incrementCountryVoteTotal(valid.countryCode, valid.voteType)), (failure) => failure.cause), toStorageEffect), { onFailure: (failure) => storageErrorResponse(failure), onSuccess: (totals) => Response.json({ ok: true, data: { countryCode: totals.countryCode, voteType: valid.voteType, totals: { likes: totals.likes, dislikes: totals.dislikes } } }, { status: 200 }) })
  }
  => Effect.runPromise(Effect.flatten(result))

export action = (args: Unknown) =>
  request = Option.getOrElse(Schema.decodeUnknownOption(Schema.instanceOf(Request))(args), () => Schema.decodeUnknownSync(Schema.Struct({ request: Schema.instanceOf(Request) }))(args).request)
  => handleVoteRequest(request)

votesActionRoute = () => Option.getOrNull(Option.none())
export default votesActionRoute
