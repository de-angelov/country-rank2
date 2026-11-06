import { Effect } from "effect";
import { beforeEach, describe, expect, it, vi } from "vitest";

import {
  action,
  handleVoteRequest,
  validateVoteRequest,
} from "../app/routes/votes.server.fun";
import * as voteStorage from "../app/votes/storage.server.fun";

vi.mock("../app/votes/storage.server.fun", async (importOriginal) => {
  const actual = await importOriginal<typeof voteStorage>();
  return {
    ...actual,
    incrementCountryVoteTotal: vi.fn(),
  };
});

const readJson = async (response: Response) =>
  (await response.json()) as unknown;

describe("vote action route", () => {
  beforeEach(() => {
    vi.mocked(voteStorage.incrementCountryVoteTotal).mockReset();
  });

  describe("validateVoteRequest", () => {
    it("accepts supported country codes and vote types", () => {
      const result = validateVoteRequest({
        countryCode: "jp",
        voteType: "like",
      });

      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(result.data.countryCode).toBe("JP");
        expect(result.data.voteType).toBe("like");
        expect(result.data.voteKind).toBeDefined();
      }
    });

    it("accepts alternative field names and casings", () => {
      const result = validateVoteRequest({
        code: "FR",
        voteKind: "Dislike",
      });

      expect(result.ok).toBe(true);
      if (result.ok) {
        expect(result.data.countryCode).toBe("FR");
        expect(result.data.voteType).toBe("dislike");
      }
    });

    it("accepts domain vote tags without accepting unrelated object tags", () => {
      expect(validateVoteRequest({ code: "JP", kind: { _tag: "Like" } }).ok).toBe(true);
      expect(validateVoteRequest({ code: "JP", kind: { _tag: "like" } }).ok).toBe(false);
    });

    it("returns typed validation errors for unsupported country code and invalid vote type", () => {
      const result = validateVoteRequest({
        countryCode: "XX",
        voteType: "upvote",
      });

      expect(result.ok).toBe(false);
      if (!result.ok) {
        expect(result.error).toEqual({
          code: "invalid_vote_request",
          message: "Vote request payload is invalid.",
          fieldErrors: {
            countryCode: "Country code must match a supported country.",
            voteType: "Vote type must be like or dislike.",
          },
        });
      }
    });
  });

  describe("action handler", () => {
    it("increments vote total for valid FormData payload", async () => {
      vi.mocked(voteStorage.incrementCountryVoteTotal).mockReturnValue(
        Effect.succeed({
          countryCode: "JP",
          likes: 7,
          dislikes: 4,
        })
      );

      const formData = new FormData();
      formData.set("countryCode", "jp");
      formData.set("voteType", "dislike");

      const response = await action({
        request: new Request("https://example.test/votes", {
          method: "POST",
          body: formData,
        }),
      });

      expect(response.status).toBe(200);
      expect(await readJson(response)).toEqual({
        ok: true,
        data: {
          countryCode: "JP",
          voteType: "dislike",
          totals: {
            likes: 7,
            dislikes: 4,
          },
        },
      });
      expect(voteStorage.incrementCountryVoteTotal).toHaveBeenCalledWith(
        "JP",
        "dislike"
      );
    });

    it("increments vote total for valid JSON payload", async () => {
      vi.mocked(voteStorage.incrementCountryVoteTotal).mockReturnValue(
        Effect.succeed({
          countryCode: "US",
          likes: 12,
          dislikes: 2,
        })
      );

      const response = await action({
        request: new Request("https://example.test/votes", {
          method: "POST",
          headers: {
            "content-type": "application/json",
          },
          body: JSON.stringify({
            countryCode: "US",
            voteType: "like",
          }),
        }),
      });

      expect(response.status).toBe(200);
      expect(await readJson(response)).toEqual({
        ok: true,
        data: {
          countryCode: "US",
          voteType: "like",
          totals: {
            likes: 12,
            dislikes: 2,
          },
        },
      });
      expect(voteStorage.incrementCountryVoteTotal).toHaveBeenCalledWith(
        "US",
        "like"
      );
    });

    it("returns typed validation error response for invalid JSON payload", async () => {
      const response = await action({
        request: new Request("https://example.test/votes", {
          method: "POST",
          headers: {
            "content-type": "application/json",
          },
          body: JSON.stringify({
            countryCode: "XX",
            voteType: "upvote",
          }),
        }),
      });

      expect(response.status).toBe(400);
      expect(await readJson(response)).toEqual({
        ok: false,
        error: {
          code: "invalid_vote_request",
          message: "Vote request payload is invalid.",
          fieldErrors: {
            countryCode: "Country code must match a supported country.",
            voteType: "Vote type must be like or dislike.",
          },
        },
      });
      expect(voteStorage.incrementCountryVoteTotal).not.toHaveBeenCalled();
    });

    it("returns 503 when Redis command fails", async () => {
      vi.mocked(voteStorage.incrementCountryVoteTotal).mockReturnValue(
        Effect.fail({
          code: "redis_command_failed",
          message: "Failed to increment country vote total in Redis.",
          cause: new Error("connection reset"),
        })
      );

      const response = await action({
        request: new Request("https://example.test/votes", {
          method: "POST",
          headers: {
            "content-type": "application/json",
          },
          body: JSON.stringify({
            countryCode: "DE",
            voteType: "like",
          }),
        }),
      });

      expect(response.status).toBe(503);
      expect(await readJson(response)).toEqual({
        ok: false,
        error: {
          code: "redis_command_failed",
          message: "Failed to increment country vote total in Redis.",
        },
      });
    });

    it("returns 503 when Redis config is missing", async () => {
      vi.mocked(voteStorage.incrementCountryVoteTotal).mockReturnValue(
        Effect.fail({
          code: "missing_redis_config",
          message: "REDIS_URL must be set.",
          envVar: "REDIS_URL",
        })
      );

      const response = await handleVoteRequest(
        new Request("https://example.test/votes", {
          method: "POST",
          headers: {
            "content-type": "application/json",
          },
          body: JSON.stringify({
            countryCode: "FR",
            voteType: "dislike",
          }),
        })
      );

      expect(response.status).toBe(503);
      expect(await readJson(response)).toEqual({
        ok: false,
        error: {
          code: "missing_redis_config",
          message: "REDIS_URL must be set.",
          envVar: "REDIS_URL",
        },
      });
    });

    it("returns validation errors for malformed JSON", async () => {
      const response = await handleVoteRequest(new Request("https://example.test/votes", {
        method: "POST", headers: { "content-type": "application/json" }, body: "{",
      }));
      expect(response.status).toBe(400);
      expect(voteStorage.incrementCountryVoteTotal).not.toHaveBeenCalled();
    });

    it("returns 500 when storage throws an unexpected error", async () => {
      vi.mocked(voteStorage.incrementCountryVoteTotal).mockImplementation(() => { throw new Error("unexpected"); });
      const response = await handleVoteRequest(new Request("https://example.test/votes", {
        method: "POST", headers: { "content-type": "application/json" },
        body: JSON.stringify({ countryCode: "JP", voteType: "like" }),
      }));
      expect(response.status).toBe(500);
      expect(await readJson(response)).toMatchObject({ ok: false, error: { code: "redis_command_failed" } });
    });

    it("supports a Promise-returning storage adapter", async () => {
      vi.mocked(voteStorage.incrementCountryVoteTotal).mockReturnValue(
        Promise.resolve({ countryCode: "JP", likes: 2, dislikes: 1 }) as unknown as ReturnType<typeof voteStorage.incrementCountryVoteTotal>,
      );
      const response = await handleVoteRequest(new Request("https://example.test/votes", {
        method: "POST", headers: { "content-type": "application/json" },
        body: JSON.stringify({ countryCode: "JP", voteType: "like" }),
      }));
      expect(response.status).toBe(200);
      expect(await readJson(response)).toMatchObject({ data: { totals: { likes: 2, dislikes: 1 } } });
    });
  });
});
