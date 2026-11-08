import { describe, expect, it } from "vitest";
import React from "react";
import { renderToString } from "react-dom/server";
import { MemoryRouter, RouterProvider, createMemoryRouter } from "react-router";
import { Effect } from "effect";

import type { Country } from "../app/countries/country.js";
import {
  HighestFirst,
  LowestFirst,
} from "../app/components/ranking-order-controls/ranking-order-controls.funx";
import {
  sortCountriesByDislikes,
  sortCountriesByDislikesDescending,
  sortCountriesByDislikesAscending,
  isLowestFirst,
  readTopDislikedCountries,
  loadTopDislikedRouteData,
  loader,
} from "../app/routes/top-disliked/top-disliked.server.fun";
import TopDislikedDefault, { TopDisliked } from "../app/routes/top-disliked/top-disliked.funx";

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
    dislikes: 80,
  },
  {
    code: "CA",
    name: "Canada",
    capital: "Ottawa",
    factSnippet: "Maple syrup and mountains.",
    flagImageUrl: "https://flagcdn.com/ca.svg",
    likes: 450,
    dislikes: 20,
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

describe("top-disliked sorting helpers", () => {
  it("sortCountriesByDislikesDescending sorts highest dislikes first and breaks ties alphabetically by name", () => {
    const sorted = sortCountriesByDislikesDescending(mockCountries);
    expect(sorted.map((c) => c.code)).toEqual(["JP", "BR", "CA", "IS"]);
    expect(sorted[0].dislikes).toBe(80);
    expect(sorted[1].name).toBe("Brazil"); // Brazil before Canada with equal 20 dislikes
    expect(sorted[2].name).toBe("Canada");
    expect(sorted[3].dislikes).toBe(5);
  });

  it("sortCountriesByDislikesAscending inverts descending order so lowest dislikes come first", () => {
    const sorted = sortCountriesByDislikesAscending(mockCountries);
    expect(sorted.map((c) => c.code)).toEqual(["IS", "CA", "BR", "JP"]);
    expect(sorted[0].dislikes).toBe(5);
    expect(sorted[1].name).toBe("Canada");
    expect(sorted[2].name).toBe("Brazil");
    expect(sorted[3].dislikes).toBe(80);
  });

  it("sortCountriesByDislikes defaults to highest-first when order is omitted or highest-first", () => {
    const defaultSorted = sortCountriesByDislikes(mockCountries);
    expect(defaultSorted.map((c) => c.code)).toEqual(["JP", "BR", "CA", "IS"]);

    const highestStrSorted = sortCountriesByDislikes(mockCountries, "highest-first");
    expect(highestStrSorted.map((c) => c.code)).toEqual(["JP", "BR", "CA", "IS"]);

    const highestVariantSorted = sortCountriesByDislikes(mockCountries, HighestFirst);
    expect(highestVariantSorted.map((c) => c.code)).toEqual(["JP", "BR", "CA", "IS"]);
  });

  it("sortCountriesByDislikes sorts lowest-first when order is lowest-first string or variant", () => {
    const lowestStrSorted = sortCountriesByDislikes(mockCountries, "lowest-first");
    expect(lowestStrSorted.map((c) => c.code)).toEqual(["IS", "CA", "BR", "JP"]);

    const lowestVariantSorted = sortCountriesByDislikes(mockCountries, LowestFirst);
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

describe("top-disliked server loader and Effect workflow", () => {
  it("readTopDislikedCountries Effect pipeline returns sorted countries using mock options", async () => {
    const totalsMap = new Map([
      ["JP", { countryCode: "JP", likes: 500, dislikes: 100 }],
      ["BR", { countryCode: "BR", likes: 200, dislikes: 50 }],
      ["CA", { countryCode: "CA", likes: 800, dislikes: 200 }],
    ]);

    const result = await Effect.runPromise(
      readTopDislikedCountries({
        readTotals: () => Effect.succeed(totalsMap),
        fixtures: mockCountries,
      })
    );

    expect(result.length).toBe(mockCountries.length);
    expect(result[0].code).toBe("CA");
    expect(result[0].dislikes).toBe(200);
    expect(result[1].code).toBe("JP");
    expect(result[1].dislikes).toBe(100);
    expect(result[2].code).toBe("BR");
    expect(result[2].dislikes).toBe(50);
    expect(result[3].code).toBe("IS");
    expect(result[3].dislikes).toBe(0); // unvoted country gets 0 dislikes
  });

  it("readTopDislikedCountries supports sorting lowest-first via options", async () => {
    const totalsMap = new Map([
      ["JP", { countryCode: "JP", likes: 500, dislikes: 100 }],
      ["CA", { countryCode: "CA", likes: 800, dislikes: 200 }],
    ]);

    const result = await Effect.runPromise(
      readTopDislikedCountries({
        readTotals: () => Effect.succeed(totalsMap),
        fixtures: mockCountries,
        order: "lowest-first",
      })
    );

    expect(result[0].dislikes).toBe(0);
    expect(result[result.length - 1].code).toBe("CA");
    expect(result[result.length - 1].dislikes).toBe(200);
  });

  it("readTopDislikedCountries gracefully falls back to 0 totals on Redis read error", async () => {
    const errorLogger = { error: () => {} };
    const result = await Effect.runPromise(
      readTopDislikedCountries({
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
    // When all dislikes are 0, sorted alphabetically by name
    expect(result.map((c) => c.name)).toEqual(["Brazil", "Canada", "Iceland", "Japan"]);
  });

  it("loadTopDislikedRouteData executes Effect and wraps result in countries object", async () => {
    const data = await loadTopDislikedRouteData({
      fixtures: mockCountries,
      readTotals: () => Effect.succeed(new Map()),
    });

    expect(data).toHaveProperty("countries");
    expect(Array.isArray(data.countries)).toBe(true);
    expect(data.countries.length).toBe(mockCountries.length);
  });

  it("loader parses order search param from request url", async () => {
    const lowestRequest = new Request("https://countryrank.example.com/top-disliked?order=lowest-first");
    const lowestData = await loader({ request: lowestRequest });
    expect(Array.isArray(lowestData.countries)).toBe(true);

    const highestRequest = new Request("https://countryrank.example.com/top-disliked?order=highest-first");
    const highestData = await loader({ request: highestRequest });
    expect(Array.isArray(highestData.countries)).toBe(true);

    const emptyArgsData = await loader();
    expect(Array.isArray(emptyArgsData.countries)).toBe(true);
  });
});

describe("TopDisliked component rendering", () => {
  it("exports TopDisliked as both a named export and a default export component", () => {
    expect(typeof TopDisliked).toBe("function");
    expect(typeof TopDislikedDefault).toBe("function");
    const router = createMemoryRouter(
      [{ id: "disliked", path: "/", Component: TopDislikedDefault }],
      {
        initialEntries: ["/"],
        hydrationData: { loaderData: { disliked: { countries: [] } } },
      },
    );
    const html = renderToString(React.createElement(RouterProvider, { router }));
    expect(html).toContain("No countries available.");
  });
  it("uses router loader data and the order query parameter", () => {
    const router = createMemoryRouter(
      [{ id: "disliked", path: "/", Component: TopDisliked }],
      {
        initialEntries: ["/?order=lowest-first"],
        hydrationData: { loaderData: { disliked: { countries: mockCountries } } },
      },
    );
    const html = renderToString(React.createElement(RouterProvider, { router }));
    expect(html).toContain("Iceland");
    expect(html.indexOf("Iceland")).toBeLessThan(html.indexOf("Japan"));
    expect(html).toContain('aria-label="Top Disliked Countries"');
  });

  it("accepts array loader data and gives the initial order prop precedence", () => {
    const router = createMemoryRouter(
      [{ id: "disliked", path: "/", element: React.createElement(TopDisliked, { initialOrder: HighestFirst }) }],
      {
        initialEntries: ["/?order=lowest-first"],
        hydrationData: { loaderData: { disliked: mockCountries } },
      },
    );
    const html = renderToString(React.createElement(RouterProvider, { router }));
    expect(html.indexOf("Japan")).toBeGreaterThan(-1);
    expect(html.indexOf("Japan")).toBeLessThan(html.indexOf("Iceland"));
  });

  it("renders when React supplies an empty props object", () => {
    const html = renderToString(React.createElement(MemoryRouter, null, React.createElement(TopDisliked, {})));
    expect(html).toContain("No countries available.");
  });

  it("renders page wrapped in AppShell with header and RankingOrderControls", () => {
    const html = renderToString(
      React.createElement(
        MemoryRouter,
        null,
        React.createElement(TopDisliked, { countries: mockCountries })
      )
    );

    expect(html).toContain("Top Disliked Countries");
    expect(html).toContain("Community picks ranked by total dislikes");
    expect(html).toContain("Highest First");
    expect(html).toContain("Lowest First");
    expect(html).toContain('aria-label="Ranking order"');
    expect(html).toContain('aria-label="Top Disliked Countries"');
    expect(html).toContain("Country Rank"); // From AppShell
  });

  it("renders countries in ranked order with dislike badges and progress", () => {
    const html = renderToString(
      React.createElement(
        MemoryRouter,
        null,
        React.createElement(TopDisliked, { countries: mockCountries })
      )
    );

    expect(html).toContain('aria-label="Rank 1"');
    expect(html).toContain('aria-label="Rank 2"');
    expect(html).toContain('aria-label="Rank 3"');
    expect(html).toContain('aria-label="Rank 4"');
    expect(html).toContain("Japan");
    expect(html).toContain("80 dislikes");
    expect(html).toContain("bg-vote-dislike");
  });

  it("renders lowest-first order correctly when initialOrder is LowestFirst", () => {
    const html = renderToString(
      React.createElement(
        MemoryRouter,
        null,
        React.createElement(TopDisliked, {
          countries: mockCountries,
          initialOrder: LowestFirst,
        })
      )
    );

    expect(html).toContain("Top Disliked Countries");
    expect(html).toContain('aria-label="Rank 4"');
    expect(html).toContain('aria-label="Rank 1"');
  });

  it("renders empty state message when countries array is empty", () => {
    const html = renderToString(
      React.createElement(
        MemoryRouter,
        null,
        React.createElement(TopDisliked, { countries: [] })
      )
    );

    expect(html).toContain("No countries available.");
  });
});
