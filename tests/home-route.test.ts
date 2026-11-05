import { describe, expect, it } from "vitest";
import React from "react";
import { renderToString } from "react-dom/server";
import { MemoryRouter } from "react-router";
import { Effect } from "effect";

import type { Country } from "../app/countries/country.js";
import {
  readHomeCountries,
  loadHomeRouteData,
  loader,
} from "../app/routes/home/home.server.tsx";
import {
  Home,
  filterCountriesByName,
  sortCountriesByDisplayName,
  SEARCH_DEBOUNCE_MS,
} from "../app/routes/home/home.funx";

const mockCountries: readonly Country[] = [
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
    code: "BR",
    name: "Brazil",
    capital: "Brasília",
    factSnippet: "Rainforests, carnival, and football.",
    flagImageUrl: "https://flagcdn.com/br.svg",
    likes: 450,
    dislikes: 20,
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

describe("home route helper functions", () => {
  it("sortCountriesByDisplayName sorts countries alphabetically by name", () => {
    const sorted = sortCountriesByDisplayName(mockCountries);
    expect(sorted.map((c) => c.name)).toEqual(["Brazil", "Canada", "Iceland", "Japan"]);
  });

  it("sortCountriesByDisplayName breaks name ties by country code", () => {
    const ties: Country[] = [
      {
        code: "US2",
        name: "Same Name",
        capital: "C1",
        factSnippet: "S1",
        flagImageUrl: "url1",
        likes: 0,
        dislikes: 0,
      },
      {
        code: "US1",
        name: "Same Name",
        capital: "C2",
        factSnippet: "S2",
        flagImageUrl: "url2",
        likes: 0,
        dislikes: 0,
      },
    ];
    const sorted = sortCountriesByDisplayName(ties);
    expect(sorted.map((c) => c.code)).toEqual(["US1", "US2"]);
  });

  it("filterCountriesByName returns all countries when search query is empty or whitespace", () => {
    expect(filterCountriesByName(mockCountries, "")).toHaveLength(mockCountries.length);
    expect(filterCountriesByName(mockCountries, "   ")).toHaveLength(mockCountries.length);
  });

  it("filterCountriesByName filters countries case-insensitively and trims input", () => {
    const matches = filterCountriesByName(mockCountries, "  can  ");
    expect(matches).toHaveLength(1);
    expect(matches[0].name).toBe("Canada");
  });

  it("filterCountriesByName returns empty array when no country matches", () => {
    const matches = filterCountriesByName(mockCountries, "NonexistentCountry");
    expect(matches).toEqual([]);
  });

  it("exports SEARCH_DEBOUNCE_MS configured to 200ms", () => {
    expect(SEARCH_DEBOUNCE_MS).toBe(200);
  });
});

describe("home server loader", () => {
  it("readHomeCountries returns countries with totals when Redis succeeds", async () => {
    const result = await Effect.runPromise(
      readHomeCountries({
        readTotals: () =>
          Effect.succeed(
            new Map([
              ["JP", { likes: 999, dislikes: 11 }],
              ["CA", { likes: 555, dislikes: 22 }],
            ])
          ),
        fixtures: mockCountries,
      })
    );

    expect(result).toHaveLength(mockCountries.length);
    const jp = result.find((c) => c.code === "JP");
    expect(jp?.likes).toBe(999);
    expect(jp?.dislikes).toBe(11);
  });

  it("readHomeCountries gracefully falls back to 0 totals on Redis read error", async () => {
    const errorLogger = { error: () => {} };
    const result = await Effect.runPromise(
      readHomeCountries({
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

    expect(result).toHaveLength(mockCountries.length);
    expect(result.every((c) => c.likes === 0 && c.dislikes === 0)).toBe(true);
  });

  it("loadHomeRouteData executes Effect and wraps result in countries object", async () => {
    const data = await loadHomeRouteData({
      fixtures: mockCountries,
      readTotals: () => Effect.succeed(new Map()),
    });

    expect(data).toHaveProperty("countries");
    expect(Array.isArray(data.countries)).toBe(true);
    expect(data.countries).toHaveLength(mockCountries.length);
  });

  it("loadHomeRouteData accepts omitted options and uses the default catalog", async () => {
    const data = await loadHomeRouteData();

    expect(data).toHaveProperty("countries");
    expect(data.countries.length).toBeGreaterThan(0);
  });

  it("loadHomeRouteData gracefully falls back to zero totals on failure", async () => {
    const data = await loadHomeRouteData({
      fixtures: mockCountries,
      readTotals: () =>
        Effect.fail({
          code: "redis_connection_failed",
          message: "Failed",
          cause: new Error("Fail"),
        }),
      logger: { error: () => {} },
    });

    expect(data.countries).toHaveLength(mockCountries.length);
    expect(data.countries.every((c) => c.likes === 0 && c.dislikes === 0)).toBe(true);
  });

  it("loader executes and returns countries object", async () => {
    const data = await loader();
    expect(data).toHaveProperty("countries");
    expect(Array.isArray(data.countries)).toBe(true);
  });
});

describe("Home component rendering", () => {
  it("renders page wrapped in AppShell with header and search input", () => {
    const html = renderToString(
      React.createElement(
        MemoryRouter,
        null,
        React.createElement(Home, { countries: mockCountries })
      )
    );

    expect(html).toContain("Country Rank"); // AppShell header link
    expect(html).toContain("Countries");
    expect(html).toContain("Browse and search country rankings");
    expect(html).toContain('id="country-search"');
    expect(html).toContain('placeholder="Search countries..."');
    expect(html).toContain('aria-label="Search countries"');
  });

  it("renders countries in display-name order with RankedCountriesList", () => {
    const html = renderToString(
      React.createElement(
        MemoryRouter,
        null,
        React.createElement(Home, { countries: mockCountries })
      )
    );

    expect(html).toContain('aria-label="Countries"');
    expect(html).toContain("Brazil");
    expect(html).toContain("Canada");
    expect(html).toContain("Iceland");
    expect(html).toContain("Japan");

    const brazilIndex = html.indexOf("Brazil");
    const canadaIndex = html.indexOf("Canada");
    const icelandIndex = html.indexOf("Iceland");
    const japanIndex = html.indexOf("Japan");

    expect(brazilIndex).toBeLessThan(canadaIndex);
    expect(canadaIndex).toBeLessThan(icelandIndex);
    expect(icelandIndex).toBeLessThan(japanIndex);
  });

  it("filters countries based on initialSearch prop", () => {
    const html = renderToString(
      React.createElement(
        MemoryRouter,
        null,
        React.createElement(Home, { countries: mockCountries, initialSearch: "Canada" })
      )
    );

    expect(html).toContain("Canada");
    expect(html).toContain('value="Canada"');
    expect(html).not.toContain("Brazil");
    expect(html).not.toContain("Iceland");
    expect(html).not.toContain("Japan");
  });

  it("filters countries based on ?q= URL search param", () => {
    const html = renderToString(
      React.createElement(
        MemoryRouter,
        { initialEntries: ["/?q=brazil"] },
        React.createElement(Home, { countries: mockCountries })
      )
    );

    expect(html).toContain("Brazil");
    expect(html).toContain('value="brazil"');
    expect(html).not.toContain("Canada");
    expect(html).not.toContain("Iceland");
    expect(html).not.toContain("Japan");
  });

  it("renders empty state 'No countries matched' when countries array is empty", () => {
    const html = renderToString(
      React.createElement(
        MemoryRouter,
        null,
        React.createElement(Home, { countries: [] })
      )
    );

    expect(html).toContain("No countries matched");
  });

  it("renders empty state 'No countries matched' when search has no matches", () => {
    const html = renderToString(
      React.createElement(
        MemoryRouter,
        null,
        React.createElement(Home, { countries: mockCountries, initialSearch: "Atlantis" })
      )
    );

    expect(html).toContain("No countries matched");
    expect(html).not.toContain("Brazil");
    expect(html).not.toContain("Canada");
    expect(html).not.toContain("Japan");
  });
});
