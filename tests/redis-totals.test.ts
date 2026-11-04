import { Effect } from "effect";
import { describe, expect, it, vi } from "vitest";

import { countryFixtures, fixtures } from "../app/countries/fixtures.fun";
import {
  createFallbackCountries,
  getCountriesWithVoteTotals,
  loadCountriesWithVoteTotals,
  logRedisTotalsError,
  mergeCountriesWithVoteTotals,
  readCountriesWithVoteTotals,
} from "../app/countries/redis-totals.server.fun";
import type { Country } from "../app/countries/country.fun";
import type {
  VoteTotals,
  VoteTotalsByCountry,
  RedisVoteStorageError,
} from "../app/votes/storage.server.fun";

const sampleFixtures: Array<Country> = [
  {
    code: "BG",
    name: "Bulgaria",
    capital: "Sofia",
    flagImageUrl: "https://example.com/bg.svg",
    factSnippet: "Oldest country in Europe that hasn't changed its name.",
    likes: 999,
    dislikes: 888,
  },
  {
    code: "US",
    name: "United States",
    capital: "Washington, D.C.",
    flagImageUrl: "https://example.com/us.svg",
    factSnippet: "Home to Yellowstone, the world's first national park.",
    likes: 500,
    dislikes: 300,
  },
  {
    code: "JP",
    name: "Japan",
    capital: "Tokyo",
    flagImageUrl: "https://example.com/jp.svg",
    factSnippet: "An island archipelago featuring Mount Fuji.",
    likes: 200,
    dislikes: 100,
  },
];

describe("redis-totals.server", () => {
  describe("pure helpers", () => {
    it("mergeCountriesWithVoteTotals updates likes/dislikes from Redis totals and defaults unvoted to 0", () => {
      const mockTotals: VoteTotalsByCountry = new Map<string, VoteTotals>([
        ["BG", { countryCode: "BG", likes: 42, dislikes: 3 }],
        ["US", { countryCode: "US", likes: 17, dislikes: 0 }],
      ]);

      const merged = mergeCountriesWithVoteTotals(sampleFixtures, mockTotals);

      expect(merged).toHaveLength(3);

      const bg = merged.find((c) => c.code === "BG");
      expect(bg).toBeDefined();
      expect(bg?.likes).toBe(42);
      expect(bg?.dislikes).toBe(3);
      expect(bg?.name).toBe("Bulgaria");
      expect(bg?.capital).toBe("Sofia");
      expect(bg?.factSnippet).toBe(sampleFixtures[0].factSnippet);
      expect(bg?.flagImageUrl).toBe(sampleFixtures[0].flagImageUrl);

      const us = merged.find((c) => c.code === "US");
      expect(us?.likes).toBe(17);
      expect(us?.dislikes).toBe(0);

      // JP was not in Redis totals map; should default to 0 likes and 0 dislikes
      const jp = merged.find((c) => c.code === "JP");
      expect(jp?.likes).toBe(0);
      expect(jp?.dislikes).toBe(0);
      expect(jp?.name).toBe("Japan");
    });

    it("createFallbackCountries sets likes and dislikes to 0 while preserving metadata", () => {
      const fallbacks = createFallbackCountries(sampleFixtures);

      expect(fallbacks).toHaveLength(3);
      for (const country of fallbacks) {
        expect(country.likes).toBe(0);
        expect(country.dislikes).toBe(0);
      }

      expect(fallbacks[0].code).toBe("BG");
      expect(fallbacks[0].name).toBe("Bulgaria");
      expect(fallbacks[1].code).toBe("US");
      expect(fallbacks[2].code).toBe("JP");
    });

    it("logRedisTotalsError delegates to provided logger.error", () => {
      const mockLogger = { error: vi.fn() };
      const err = new Error("Redis down");

      logRedisTotalsError(err, mockLogger);

      expect(mockLogger.error).toHaveBeenCalledTimes(1);
      expect(mockLogger.error).toHaveBeenCalledWith(
        { cause: err },
        expect.stringContaining("Failed to read country vote totals from Redis")
      );
    });
  });

  describe("readCountriesWithVoteTotals Effect execution", () => {
    it("merges fixture countries with mock Redis totals on success", async () => {
      const mockTotals: VoteTotalsByCountry = new Map<string, VoteTotals>([
        ["BG", { countryCode: "BG", likes: 88, dislikes: 12 }],
      ]);

      const mockLogger = { error: vi.fn() };
      const readTotals = () => Effect.succeed(mockTotals);

      const effect = readCountriesWithVoteTotals({
        readTotals,
        fixtures: sampleFixtures,
        logger: mockLogger,
      });

      const result = await Effect.runPromise(effect);

      expect(result).toHaveLength(3);
      const bg = result.find((c) => c.code === "BG");
      expect(bg?.likes).toBe(88);
      expect(bg?.dislikes).toBe(12);

      const us = result.find((c) => c.code === "US");
      expect(us?.likes).toBe(0);
      expect(us?.dislikes).toBe(0);

      const jp = result.find((c) => c.code === "JP");
      expect(jp?.likes).toBe(0);
      expect(jp?.dislikes).toBe(0);

      expect(mockLogger.error).not.toHaveBeenCalled();
    });

    it("falls back to zero likes/dislikes and logs error on Redis connection failure", async () => {
      const redisError: RedisVoteStorageError = {
        code: "redis_connection_failed",
        message: "Could not connect to Redis instance",
        cause: new Error("ECONNREFUSED"),
      };

      const mockLogger = { error: vi.fn() };
      const readTotals = () => Effect.fail(redisError);

      const effect = readCountriesWithVoteTotals({
        readTotals,
        fixtures: sampleFixtures,
        logger: mockLogger,
      });

      const result = await Effect.runPromise(effect);

      expect(result).toHaveLength(3);
      for (const country of result) {
        expect(country.likes).toBe(0);
        expect(country.dislikes).toBe(0);
      }

      expect(mockLogger.error).toHaveBeenCalledTimes(1);
      expect(mockLogger.error).toHaveBeenCalledWith(
        { cause: redisError },
        expect.stringContaining("Failed to read country vote totals from Redis")
      );
    });

    it("falls back to zero likes/dislikes on missing Redis config error", async () => {
      const redisError: RedisVoteStorageError = {
        code: "missing_redis_config",
        message: "REDIS_URL environment variable is missing",
        envVar: "REDIS_URL",
      };

      const mockLogger = { error: vi.fn() };
      const readTotals = () => Effect.fail(redisError);

      const result = await Effect.runPromise(
        readCountriesWithVoteTotals({
          readTotals,
          fixtures: sampleFixtures,
          logger: mockLogger,
        })
      );

      expect(result).toHaveLength(3);
      expect(result[0].code).toBe("BG");
      expect(result[0].likes).toBe(0);
      expect(result[0].dislikes).toBe(0);
      expect(mockLogger.error).toHaveBeenCalledTimes(1);
    });

    it("falls back to zero likes/dislikes on command failure", async () => {
      const redisError: RedisVoteStorageError = {
        code: "redis_command_failed",
        message: "hGetAll command timed out",
        cause: new Error("ETIMEDOUT"),
      };

      const mockLogger = { error: vi.fn() };
      const readTotals = () => Effect.fail(redisError);

      const result = await Effect.runPromise(
        readCountriesWithVoteTotals({
          readTotals,
          fixtures: sampleFixtures,
          logger: mockLogger,
        })
      );

      expect(result).toHaveLength(3);
      expect(result.every((c) => c.likes === 0 && c.dislikes === 0)).toBe(true);
      expect(mockLogger.error).toHaveBeenCalledTimes(1);
    });

    it("works with real fixtures and maps all 249 countries", async () => {
      const mockTotals: VoteTotalsByCountry = new Map<string, VoteTotals>([
        ["AD", { countryCode: "AD", likes: 1234, dislikes: 56 }],
      ]);

      const result = await Effect.runPromise(
        readCountriesWithVoteTotals({
          readTotals: () => Effect.succeed(mockTotals),
          fixtures: countryFixtures,
        })
      );

      expect(result).toHaveLength(249);
      expect(result).toHaveLength(fixtures.length);

      const ad = result.find((c) => c.code === "AD");
      expect(ad?.name).toBe("Andorra");
      expect(ad?.likes).toBe(1234);
      expect(ad?.dislikes).toBe(56);

      // Other countries default to 0
      const other = result.find((c) => c.code !== "AD");
      expect(other?.likes).toBe(0);
      expect(other?.dislikes).toBe(0);
    });

    it("exports getCountriesWithVoteTotals and loadCountriesWithVoteTotals aliases", () => {
      expect(getCountriesWithVoteTotals).toBe(readCountriesWithVoteTotals);
      expect(loadCountriesWithVoteTotals).toBe(readCountriesWithVoteTotals);
    });
  });
});
