import { describe, expect, it } from "vitest";
import React from "react";
import { renderToString } from "react-dom/server";
import { MemoryRouter } from "react-router";
import { Effect } from "effect";

import type { Country } from "../app/countries/country.js";
import {
  HighestFirst,
  LowestFirst,
} from "../app/components/ranking-order-controls/ranking-order-controls.funx";
import {
  sortCountriesByLikes,
  sortCountriesByLikesDescending,
  sortCountriesByLikesAscending,
  isLowestFirst,
  readTopLikedCountries,
  loadTopLikedRouteData,
  loader,
} from "../app/routes/top-liked/top-liked.server.fun";
import { TopLiked } from "../app/routes/top-liked/top-liked.funx";

const mockCountries: readonly Country[] = [
  {
    code: "BR",
    name: "Brazil",
    capital: "Brasília",
    factSnippet: "Rainforests, carnival, and football.",
    flagImageUrl: "https://flagcdn.com/br.svg",
    likes: 450,
    dislikes: 20,
  },
  {
    code: "JP",
    name: "Japan",
    capital: "Tokyo",
    factSnippet: "Vending machines and bullet trains.",
    flagImageUrl: "https://flagcdn.com/jp.svg",
    likes: 1200,
    dislikes: 30,
  },
  {
    code: "CA",
    name: "Canada",
    capital: "Ottawa",
    factSnippet: "Maple syrup and mountains.",
    flagImageUrl: "https://flagcdn.com/ca.svg",
    likes: 450,
    dislikes: 15,
  },
  {
    code: "IS",
    name: "Iceland",
    capital: "Reykjavik",
    factSnippet: "Volcanoes, hot springs, and glaciers.",
    flagImageUrl: "https://flagcdn.com/is.svg",
    likes: 80,
    dislikes: 5,
  },
];

describe("top-liked sorting helpers", () => {
  it("sortCountriesByLikesDescending sorts highest likes first and breaks ties alphabetically by name", () => {
    const sorted = sortCountriesByLikesDescending(mockCountries);
    expect(sorted.map((c) => c.code)).toEqual(["JP", "BR", "CA", "IS"]);
    expect(sorted[0].likes).toBe(1200);
    expect(sorted[1].name).toBe("Brazil"); // Brazil before Canada with equal 450 likes
    expect(sorted[2].name).toBe("Canada");
    expect(sorted[3].likes).toBe(80);
  });

  it("sortCountriesByLikesAscending inverts descending order so lowest likes come first", () => {
    const sorted = sortCountriesByLikesAscending(mockCountries);
    expect(sorted.map((c) => c.code)).toEqual(["IS", "CA", "BR", "JP"]);
    expect(sorted[0].likes).toBe(80);
    expect(sorted[1].name).toBe("Canada");
    expect(sorted[2].name).toBe("Brazil");
    expect(sorted[3].likes).toBe(1200);
  });

  it("sortCountriesByLikes defaults to highest-first when order is omitted or highest-first", () => {
    const defaultSorted = sortCountriesByLikes(mockCountries);
    expect(defaultSorted.map((c) => c.code)).toEqual(["JP", "BR", "CA", "IS"]);

    const highestStrSorted = sortCountriesByLikes(mockCountries, "highest-first");
    expect(highestStrSorted.map((c) => c.code)).toEqual(["JP", "BR", "CA", "IS"]);

    const highestVariantSorted = sortCountriesByLikes(mockCountries, HighestFirst);
    expect(highestVariantSorted.map((c) => c.code)).toEqual(["JP", "BR", "CA", "IS"]);
  });

  it("sortCountriesByLikes sorts lowest-first when order is lowest-first string or variant", () => {
    const lowestStrSorted = sortCountriesByLikes(mockCountries, "lowest-first");
    expect(lowestStrSorted.map((c) => c.code)).toEqual(["IS", "CA", "BR", "JP"]);

    const lowestVariantSorted = sortCountriesByLikes(mockCountries, LowestFirst);
    expect(lowestVariantSorted.map((c) => c.code)).toEqual(["IS", "CA", "BR", "JP"]);
  });

  it("isLowestFirst helper correctly discriminates order values", () => {
    expect(isLowestFirst()).toBe(false);
    expect(isLowestFirst("highest-first")).toBe(false);
    expect(isLowestFirst(HighestFirst)).toBe(false);
    expect(isLowestFirst("lowest-first")).toBe(true);
    expect(isLowestFirst(LowestFirst)).toBe(true);
  });
});

describe("top-liked server loader and Effect workflow", () => {
  it("readTopLikedCountries Effect pipeline returns sorted countries using mock options", async () => {
    const totalsMap = new Map([
      ["JP", { countryCode: "JP", likes: 500, dislikes: 10 }],
      ["BR", { countryCode: "BR", likes: 200, dislikes: 5 }],
      ["CA", { countryCode: "CA", likes: 800, dislikes: 2 }],
    ]);

    const result = await Effect.runPromise(
      readTopLikedCountries({
        readTotals: () => Effect.succeed(totalsMap),
        fixtures: mockCountries,
      })
    );

    expect(result.length).toBe(mockCountries.length);
    expect(result[0].code).toBe("CA");
    expect(result[0].likes).toBe(800);
    expect(result[1].code).toBe("JP");
    expect(result[1].likes).toBe(500);
    expect(result[2].code).toBe("BR");
    expect(result[2].likes).toBe(200);
    expect(result[3].code).toBe("IS");
    expect(result[3].likes).toBe(0); // unvoted country gets 0 likes
  });

  it("readTopLikedCountries supports sorting lowest-first via options", async () => {
    const totalsMap = new Map([
      ["JP", { countryCode: "JP", likes: 500, dislikes: 10 }],
      ["CA", { countryCode: "CA", likes: 800, dislikes: 2 }],
    ]);

    const result = await Effect.runPromise(
      readTopLikedCountries({
        readTotals: () => Effect.succeed(totalsMap),
        fixtures: mockCountries,
        order: "lowest-first",
      })
    );

    expect(result[0].likes).toBe(0);
    expect(result[result.length - 1].code).toBe("CA");
    expect(result[result.length - 1].likes).toBe(800);
  });

  it("readTopLikedCountries gracefully falls back to 0 totals on Redis read error", async () => {
    const errorLogger = { error: () => {} };
    const result = await Effect.runPromise(
      readTopLikedCountries({
        readTotals: () =>
          Effect.fail({
            code: "redis_connection_failed",
            message: "Connection failed",
            cause: new Error("ECONNREFUSED"),
          }),
        fixtures: mockCountries,
        logger: errorLogger,
      })
    );

    expect(result.length).toBe(mockCountries.length);
    expect(result.every((c) => c.likes === 0 && c.dislikes === 0)).toBe(true);
    // When all likes are 0, sorted alphabetically by name
    expect(result.map((c) => c.name)).toEqual(["Brazil", "Canada", "Iceland", "Japan"]);
  });

  it("loadTopLikedRouteData executes Effect and wraps result in countries object", async () => {
    const data = await loadTopLikedRouteData({
      fixtures: mockCountries,
      readTotals: () => Effect.succeed(new Map()),
    });

    expect(data).toHaveProperty("countries");
    expect(Array.isArray(data.countries)).toBe(true);
    expect(data.countries.length).toBe(mockCountries.length);
  });

  it("loader parses order search param from request url", async () => {
    const lowestRequest = new Request("https://countryrank.example.com/top-liked?order=lowest-first");
    const lowestData = await loader({ request: lowestRequest });
    expect(Array.isArray(lowestData.countries)).toBe(true);

    const highestRequest = new Request("https://countryrank.example.com/top-liked?order=highest-first");
    const highestData = await loader({ request: highestRequest });
    expect(Array.isArray(highestData.countries)).toBe(true);

    const unrelatedParamRequest = new Request(
      "https://countryrank.example.com/top-liked?note=order%3Dlowest-first&order=highest-first"
    );
    const unrelatedParamData = await loader({ request: unrelatedParamRequest });
    expect(unrelatedParamData.countries.map((country) => country.code)).toEqual(
      highestData.countries.map((country) => country.code)
    );

    const unrelatedValueRequest = new Request(
      "https://countryrank.example.com/top-liked?order=almost-lowest-first"
    );
    const unrelatedValueData = await loader({ request: unrelatedValueRequest });
    expect(unrelatedValueData.countries.map((country) => country.code)).toEqual(
      highestData.countries.map((country) => country.code)
    );

    const emptyArgsData = await loader();
    expect(Array.isArray(emptyArgsData.countries)).toBe(true);
  });
});

describe("TopLiked component rendering", () => {
  it("renders page wrapped in AppShell with header and RankingOrderControls", () => {
    const html = renderToString(
      React.createElement(
        MemoryRouter,
        null,
        React.createElement(TopLiked, { countries: mockCountries })
      )
    );

    expect(html).toContain("Top Liked Countries");
    expect(html).toContain("Community favorites ranked by total likes");
    expect(html).toContain("Highest First");
    expect(html).toContain("Lowest First");
    expect(html).toContain('aria-label="Ranking order"');
    expect(html).toContain('aria-label="Top Liked Countries"');
    expect(html).toContain("Country Rank"); // From AppShell
  });

  it("renders countries in ranked order with like badges and progress", () => {
    const html = renderToString(
      React.createElement(
        MemoryRouter,
        null,
        React.createElement(TopLiked, { countries: mockCountries })
      )
    );

    expect(html).toContain('aria-label="Rank 1"');
    expect(html).toContain('aria-label="Rank 2"');
    expect(html).toContain('aria-label="Rank 3"');
    expect(html).toContain('aria-label="Rank 4"');
    expect(html).toContain("Japan");
    expect(html).toContain("1,200 likes");
    expect(html).toContain("bg-vote-like");
  });

  it("renders lowest-first order correctly when initialOrder is LowestFirst", () => {
    const html = renderToString(
      React.createElement(
        MemoryRouter,
        null,
        React.createElement(TopLiked, {
          countries: mockCountries,
          initialOrder: LowestFirst,
        })
      )
    );

    expect(html).toContain("Top Liked Countries");
    expect(html).toContain('aria-label="Rank 4"');
    expect(html).toContain('aria-label="Rank 1"');
  });

  it("renders empty state message when countries array is empty", () => {
    const html = renderToString(
      React.createElement(
        MemoryRouter,
        null,
        React.createElement(TopLiked, { countries: [] })
      )
    );

    expect(html).toContain("No countries available.");
  });
});
