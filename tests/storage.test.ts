import { Effect, Exit, Cause } from "effect";
import { describe, expect, it, vi } from "vitest";

import {
  createRedisVoteStorage,
  getRedisVoteStorageConfig,
  voteTotalsKey,
  type RedisVoteStorageConfig,
} from "../app/votes/storage.server.fun";

const envWithRedisUrl = {
  REDIS_URL: "redis://localhost:6379",
};

const createClient = (
  initialFields: Partial<Record<"likes" | "dislikes", Record<string, string>>> = {},
  options: Partial<{
    connect: () => Promise<unknown>;
    hGet: (key: string, field: string) => Promise<string | null>;
    hGetAll: (key: string) => Promise<Record<string, string>>;
    hIncrBy: (
      key: string,
      field: string,
      increment: number,
    ) => Promise<number>;
  }> = {},
) => {
  const fields = {
    likes: { ...(initialFields.likes ?? {}) },
    dislikes: { ...(initialFields.dislikes ?? {}) },
  };
  const client = {
    connect: vi.fn(options.connect ?? (() => Promise.resolve())),
    hGet: vi.fn(
      options.hGet ??
        ((key: string, field: string) => {
          const totals =
            key === voteTotalsKey("like") ? fields.likes : fields.dislikes;

          return Promise.resolve(totals[field] ?? null);
        }),
    ),
    hGetAll: vi.fn(
      options.hGetAll ??
        ((key: string) =>
          Promise.resolve(
            key === voteTotalsKey("like") ? fields.likes : fields.dislikes,
          )),
    ),
    hIncrBy: vi.fn(
      options.hIncrBy ??
        ((_key: string, field: string, increment: number) => {
          const totals =
            _key === voteTotalsKey("like") ? fields.likes : fields.dislikes;
          totals[field] = String(Number(totals[field] ?? 0) + increment);

          return Promise.resolve(Number(totals[field]));
        }),
    ),
  };

  return client;
};

const getFailureError = <A, E>(exit: Exit.Exit<A, E>): unknown => {
  if (Exit.isSuccess(exit)) {
    throw new Error("Expected failure, but received success");
  }
  const errorOpt = Cause.findErrorOption(exit.cause);
  if (errorOpt._tag === "Some") {
    return errorOpt.value;
  }
  return exit.cause;
};

describe("getRedisVoteStorageConfig", () => {
  it("returns a clear error when Redis configuration is missing", async () => {
    const exit = await Effect.runPromiseExit(getRedisVoteStorageConfig({}));

    expect(Exit.isFailure(exit)).toBe(true);
    expect(getFailureError(exit)).toMatchObject({
      code: "missing_redis_config",
      envVar: "REDIS_URL",
    });
  });

  it("reads Redis connection details from the environment", async () => {
    const result = await Effect.runPromise(
      getRedisVoteStorageConfig(envWithRedisUrl)
    );

    expect(result).toEqual({
      url: "redis://localhost:6379",
    });
  });
});

describe("createRedisVoteStorage", () => {
  it("reads country vote totals from Redis", async () => {
    const client = createClient({
      likes: { US: "12" },
      dislikes: { US: "4" },
    });
    const storage = createRedisVoteStorage({
      env: envWithRedisUrl,
      clientFactory: () => client,
    });

    const result = await Effect.runPromise(
      storage.readCountryVoteTotals("us")
    );

    expect(result).toEqual({
      countryCode: "US",
      likes: 12,
      dislikes: 4,
    });
    expect(client.hGet).toHaveBeenNthCalledWith(
      1,
      voteTotalsKey("like"),
      "US",
    );
    expect(client.hGet).toHaveBeenNthCalledWith(
      2,
      voteTotalsKey("dislike"),
      "US",
    );
  });

  it("defaults missing Redis totals to zero", async () => {
    const client = createClient();
    const storage = createRedisVoteStorage({
      env: envWithRedisUrl,
      clientFactory: () => client,
    });

    const result = await Effect.runPromise(
      storage.readCountryVoteTotals("GB")
    );

    expect(result).toMatchObject({
      likes: 0,
      dislikes: 0,
    });
  });

  it("reads aggregate country vote totals from Redis vote hashes", async () => {
    const client = createClient({
      likes: { JP: "12", DE: "5" },
      dislikes: { JP: "4", GB: "9" },
    });
    const storage = createRedisVoteStorage({
      env: envWithRedisUrl,
      clientFactory: () => client,
    });

    const result = await Effect.runPromise(
      storage.readAllCountryVoteTotals()
    );

    expect([...result.values()]).toEqual([
      {
        countryCode: "JP",
        likes: 12,
        dislikes: 4,
      },
      {
        countryCode: "DE",
        likes: 5,
        dislikes: 0,
      },
      {
        countryCode: "GB",
        likes: 0,
        dislikes: 9,
      },
    ]);
    expect(client.hGetAll).toHaveBeenNthCalledWith(
      1,
      voteTotalsKey("like"),
    );
    expect(client.hGetAll).toHaveBeenNthCalledWith(
      2,
      voteTotalsKey("dislike"),
    );
  });

  it("increments like and dislike totals by country code", async () => {
    const client = createClient({
      likes: { JP: "2" },
      dislikes: { JP: "8" },
    });
    const storage = createRedisVoteStorage({
      env: envWithRedisUrl,
      clientFactory: (config: RedisVoteStorageConfig) => {
        expect(config.url).toBe(envWithRedisUrl.REDIS_URL);

        return client;
      },
    });

    const likeResult = await Effect.runPromise(
      storage.incrementCountryVoteTotal("JP", "like")
    );
    const dislikeResult = await Effect.runPromise(
      storage.incrementCountryVoteTotal("JP", "dislike")
    );

    expect(likeResult).toEqual({
      countryCode: "JP",
      likes: 3,
      dislikes: 8,
    });
    expect(dislikeResult).toEqual({
      countryCode: "JP",
      likes: 3,
      dislikes: 9,
    });
    expect(client.hIncrBy).toHaveBeenNthCalledWith(
      1,
      voteTotalsKey("like"),
      "JP",
      1,
    );
    expect(client.hIncrBy).toHaveBeenNthCalledWith(
      2,
      voteTotalsKey("dislike"),
      "JP",
      1,
    );
  });

  it("does not connect to Redis for invalid country codes", async () => {
    const client = createClient();
    const storage = createRedisVoteStorage({
      env: envWithRedisUrl,
      clientFactory: () => client,
    });

    const exit = await Effect.runPromiseExit(
      storage.readCountryVoteTotals("USA")
    );

    expect(Exit.isFailure(exit)).toBe(true);
    expect(getFailureError(exit)).toMatchObject({
      code: "invalid_country_code",
      countryCode: "USA",
    });
    expect(client.connect).not.toHaveBeenCalled();
  });

  it("returns Redis command failures as result errors", async () => {
    const commandError = new Error("boom");
    const client = createClient(
      {},
      {
        hGet: () => Promise.reject(commandError),
      },
    );
    const storage = createRedisVoteStorage({
      env: envWithRedisUrl,
      clientFactory: () => client,
    });

    const exit = await Effect.runPromiseExit(
      storage.readCountryVoteTotals("DE")
    );

    expect(Exit.isFailure(exit)).toBe(true);
    expect(getFailureError(exit)).toMatchObject({
      code: "redis_command_failed",
      cause: commandError,
    });
  });

  it("returns Redis connection failures as result errors", async () => {
    const connectionError = new Error("refused");
    const client = createClient(
      {},
      {
        connect: () => Promise.reject(connectionError),
      },
    );
    const storage = createRedisVoteStorage({
      env: envWithRedisUrl,
      clientFactory: () => client,
    });

    const exit = await Effect.runPromiseExit(
      storage.readCountryVoteTotals("CA")
    );

    expect(Exit.isFailure(exit)).toBe(true);
    expect(getFailureError(exit)).toMatchObject({
      code: "redis_connection_failed",
      cause: connectionError,
    });
  });
});
