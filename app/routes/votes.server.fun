import { Effect } from "effect"
import { Like, Dislike } from "../countries/country.js"
import { countryFixtures } from "../countries/fixtures.js"
import { incrementCountryVoteTotal } from "../votes/storage.server.js"

ts {
  import type { VoteKind as DomainVoteKind } from "../countries/country.js";
  import type { VoteKind as StorageVoteKind, VoteTotals, RedisVoteStorageError } from "../votes/storage.server.js";

  export type VoteRequestPayload = Readonly<{
    countryCode?: unknown;
    code?: unknown;
    voteType?: unknown;
    voteKind?: unknown;
    kind?: unknown;
  }>;

  export type VoteRequestValidationError = Readonly<{
    code: "invalid_vote_request";
    message: string;
    fieldErrors: Readonly<{
      countryCode?: string;
      voteType?: string;
    }>;
  }>;

  export type VoteRequestValid = Readonly<{
    countryCode: string;
    voteType: StorageVoteKind;
    voteKind: DomainVoteKind;
  }>;

  export type VoteValidationResult =
    | { ok: true; data: VoteRequestValid; error?: never }
    | { ok: false; error: VoteRequestValidationError; data?: never };

  const supportedCountryCodes = new Set(
    countryFixtures.map((c) => c.code.toUpperCase())
  );

  export const validateVoteRequest = (
    payload: VoteRequestPayload
  ): VoteValidationResult => {
    const rawCountryCode = payload.countryCode ?? payload.code;
    const rawVoteType = payload.voteType ?? payload.voteKind ?? payload.kind;

    const countryCode =
      typeof rawCountryCode === "string" ? rawCountryCode.trim().toUpperCase() : "";
    const fieldErrors: { countryCode?: string; voteType?: string } = {};

    if (!countryCode || !supportedCountryCodes.has(countryCode)) {
      fieldErrors.countryCode = "Country code must match a supported country.";
    }

    let storageVote: StorageVoteKind | undefined;
    let domainVote: DomainVoteKind | undefined;

    if (typeof rawVoteType === "string") {
      const normalized = rawVoteType.trim().toLowerCase();
      if (normalized === "like") {
        storageVote = "like";
        domainVote = Like;
      } else if (normalized === "dislike") {
        storageVote = "dislike";
        domainVote = Dislike;
      }
    } else if (rawVoteType && typeof rawVoteType === "object" && "_tag" in rawVoteType) {
      const tag = (rawVoteType as { _tag: string })._tag;
      if (tag === "Like") {
        storageVote = "like";
        domainVote = Like;
      } else if (tag === "Dislike") {
        storageVote = "dislike";
        domainVote = Dislike;
      }
    }

    if (!storageVote || !domainVote) {
      fieldErrors.voteType = "Vote type must be like or dislike.";
    }

    if (!storageVote || !domainVote || Object.keys(fieldErrors).length > 0) {
      return {
        ok: false,
        error: {
          code: "invalid_vote_request",
          message: "Vote request payload is invalid.",
          fieldErrors,
        },
      };
    }

    return {
      ok: true,
      data: {
        countryCode,
        voteType: storageVote,
        voteKind: domainVote,
      },
    };
  };

  export const readVoteRequestPayload = async (
    request: Request
  ): Promise<VoteRequestPayload> => {
    const contentType = request.headers.get("content-type") ?? "";
    if (contentType.includes("application/json")) {
      const body: unknown = await request.json().catch(() => ({}));
      if (body && typeof body === "object") {
        const b = body as Record<string, unknown>;
        return {
          countryCode: b.countryCode ?? b.code,
          code: b.code,
          voteType: b.voteType ?? b.voteKind ?? b.kind,
          voteKind: b.voteKind,
          kind: b.kind,
        };
      }
      return {};
    }

    const formData = await request.formData().catch(() => new FormData());
    return {
      countryCode: formData.get("countryCode") ?? formData.get("code"),
      code: formData.get("code"),
      voteType: formData.get("voteType") ?? formData.get("voteKind") ?? formData.get("kind"),
      voteKind: formData.get("voteKind"),
      kind: formData.get("kind"),
    };
  };

  export const handleVoteRequest = async (request: Request): Promise<Response> => {
    const payload = await readVoteRequestPayload(request);
    const result = validateVoteRequest(payload);

    if (!result.ok) {
      return Response.json(
        {
          ok: false,
          error: result.error,
        },
        { status: 400 }
      );
    }

    const { countryCode, voteType } = result.data;

    try {
      const op = incrementCountryVoteTotal(countryCode, voteType);
      const totals: VoteTotals = Effect.isEffect(op)
        ? await Effect.runPromise(op)
        : await (op as unknown as Promise<VoteTotals>);

      return Response.json(
        {
          ok: true,
          data: {
            countryCode: totals.countryCode,
            voteType,
            totals: {
              likes: totals.likes,
              dislikes: totals.dislikes,
            },
          },
        },
        { status: 200 }
      );
    } catch (error: any) {
      const code = error?.code as RedisVoteStorageError["code"] | undefined;
      const status =
        code === "invalid_country_code"
          ? 400
          : code === "missing_redis_config" ||
            code === "redis_connection_failed" ||
            code === "redis_command_failed"
          ? 503
          : 500;

      const errorBody: Record<string, unknown> = {
        code: code ?? "redis_command_failed",
        message: error?.message ?? "Failed to increment country vote total.",
      };

      if (error?.envVar) {
        errorBody.envVar = error.envVar;
      }
      if (error?.countryCode) {
        errorBody.countryCode = error.countryCode;
      }

      return Response.json(
        {
          ok: false,
          error: errorBody,
        },
        { status }
      );
    }
  };

  export async function action(args: { request: Request } | Request): Promise<Response> {
    const request = args instanceof Request ? args : args.request;
    return handleVoteRequest(request);
  }

  export default function VotesActionRoute() {
    return null;
  }
}
