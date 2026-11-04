import type { Effect } from "effect";

export type VoteKind = "like" | "dislike";

export type VoteTotals = Readonly<{
  countryCode: string;
  likes: number;
  dislikes: number;
}>;

export type VoteTotalsByCountry = ReadonlyMap<string, VoteTotals>;

export type RedisVoteStorageError =
  | Readonly<{
      code: "missing_redis_config";
      message: string;
      envVar: string;
    }>
  | Readonly<{
      code: "invalid_country_code";
      message: string;
      countryCode: string;
    }>
  | Readonly<{
      code: "redis_connection_failed" | "redis_command_failed";
      message: string;
      cause: unknown;
    }>;

export declare const voteTotalsKey: (voteKind: VoteKind) => string;

export declare const readAllCountryVoteTotals: () => Effect.Effect<
  VoteTotalsByCountry,
  RedisVoteStorageError
>;

export declare const readCountryVoteTotals: (
  countryCode: string
) => Effect.Effect<VoteTotals, RedisVoteStorageError>;

export declare const incrementCountryVoteTotal: (
  countryCode: string,
  voteKind: VoteKind
) => Effect.Effect<VoteTotals, RedisVoteStorageError>;
