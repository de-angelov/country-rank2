import { Effect, Option, Schema } from "effect"
import { Like, Dislike } from "../countries/country.js"
import { countryFixtures } from "../countries/fixtures.js"
import { incrementCountryVoteTotal } from "../votes/storage.server.js"
import type { VoteTotals, RedisVoteStorageError, VoteKind } from "../votes/storage.server.js"

supportedCountryCodes = countryFixtures |> Array.map((country) => country.code |> String.toUpperCase)

readField = (payload: Object, primary: String, fallback: String): Unknown =>
  primaryVal: Unknown = Reflect.get(payload, primary)
  fallbackVal: Unknown = Reflect.get(payload, fallback)
  => Option.getOrElse(Option.fromNullishOr(primaryVal), () => fallbackVal)

normalizePayload = (payload: Object) =>
  rawVote: Unknown = readField(payload, "voteType", "voteKind")
  kindVal: Unknown = Reflect.get(payload, "kind")
  voteType: Unknown = Option.getOrElse(Option.fromNullishOr(rawVote), () => kindVal)
  countryCode: Unknown = readField(payload, "countryCode", "code")
  codeVal: Unknown = Reflect.get(payload, "code")
  voteKindVal: Unknown = Reflect.get(payload, "voteKind")
  => { countryCode: countryCode, code: codeVal, voteType: voteType, voteKind: voteKindVal, kind: kindVal }

export schema NormalizedVote = {
  voteType: VoteKind
  voteKind: Any
}

normalizeVote = (value: Unknown): Option<NormalizedVote> =>
  stringValue = Schema.decodeUnknownOption(Schema.String)(value)
  taggedValue = Schema.decodeUnknownOption(Schema.Struct({ _tag: Schema.String }))(value)
  normalized = match stringValue
    | Some(text) => text |> String.trim |> String.toLowerCase
    | None => match taggedValue
      | Some(tagged) => match tagged._tag
        | "Like" => "like"
        | "Dislike" => "dislike"
        | _ => ""
      | None => ""
  likeVote: NormalizedVote = { voteType: "like", voteKind: Like }
  dislikeVote: NormalizedVote = { voteType: "dislike", voteKind: Dislike }
  => match normalized
    | "like" => Option.some(likeVote)
    | "dislike" => Option.some(dislikeVote)
    | _ => Option.none()

export schema VoteValidationSuccess = {
  ok: true
  data: {
    countryCode: String
    voteType: "like" | "dislike"
    voteKind: Any
  }
}

export schema VoteValidationFailure = {
  ok: false
  error: {
    code: String
    message: String
    fieldErrors: Object
  }
}

export schema VoteValidationResult = VoteValidationSuccess | VoteValidationFailure

export validateVoteRequest = (payload: Object): VoteValidationResult =>
  rawCountryCode: Unknown = readField(payload, "countryCode", "code")
  rawPrimaryVote: Unknown = readField(payload, "voteType", "voteKind")
  kindVal: Unknown = Reflect.get(payload, "kind")
  rawVoteType: Unknown = Option.getOrElse(Option.fromNullishOr(rawPrimaryVote), () => kindVal)
  countryCode = Option.getOrElse(Option.map(Schema.decodeUnknownOption(Schema.String)(rawCountryCode), (value) => value |> String.trim |> String.toUpperCase), () => "")
  validCountry = supportedCountryCodes |> Array.contains(countryCode)
  vote = normalizeVote(rawVoteType)
  validVote = match vote
    | Some(_) => true
    | None => false
  fieldErrors = match [validCountry, validVote]
    | [false, false] => { countryCode: "Country code must match a supported country.", voteType: "Vote type must be like or dislike." }
    | [false, true] => { countryCode: "Country code must match a supported country." }
    | [true, false] => { voteType: "Vote type must be like or dislike." }
    | _ => {}
  createSuccess = (valid: NormalizedVote): VoteValidationSuccess =>
    ({ ok: true, data: { countryCode: countryCode, voteType: valid.voteType, voteKind: valid.voteKind } })
  createFailure: () => VoteValidationFailure = () =>
    ({ ok: false, error: { code: "invalid_vote_request", message: "Vote request payload is invalid.", fieldErrors: fieldErrors } })
  => match vote
    | Some(valid) => match validCountry
      | true => createSuccess(valid)
      | false => createFailure()
    | None => createFailure()

export readVoteRequestPayload = (request: Request) =>
  rawContentType = Option.fromNullishOr(request.headers.get("content-type"))
  contentType = match rawContentType
    | Some(ct) => ct
    | None => ""
  reading = match contentType |> String.includes("application/json")
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
  code = match Option.fromNullishOr(details.code)
    | Some(c) => c
    | None => "redis_command_failed"
  message = match Option.fromNullishOr(details.message)
    | Some(m) => m
    | None => "Failed to increment country vote total."
  statusCode = match Option.fromNullishOr(details.code)
    | Some(c) => c
    | None => ""
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
      | { ok: true, data: valid } =>
          operationEffect = Effect.flatMap(
            Effect.mapError(
              Effect.try(() => incrementCountryVoteTotal(valid.countryCode, valid.voteType)),
              (failure) => failure.cause
            ),
            toStorageEffect
          )
          => operationEffect |> Effect.match({
            onFailure: (failure) => storageErrorResponse(failure),
            onSuccess: (totals) => Response.json({ ok: true, data: { countryCode: totals.countryCode, voteType: valid.voteType, totals: { likes: totals.likes, dislikes: totals.dislikes } } }, { status: 200 })
          })
  }
  => Effect.runPromise(Effect.flatten(result))

export action = (args: Unknown) =>
  request = Option.getOrElse(Schema.decodeUnknownOption(Schema.instanceOf(Request))(args), () => Schema.decodeUnknownSync(Schema.Struct({ request: Schema.instanceOf(Request) }))(args).request)
  => handleVoteRequest(request)

votesActionRoute = () => Option.getOrNull(Option.none())
export default votesActionRoute
