import { describe, expect, it } from "vitest";
import { Country, countryFixtures, fixtures, Like, Dislike } from "../app/countries/index.fun";

describe("domain schema and fixtures", () => {
  it("exports Country schema and VoteKind", () => {
    expect(Country).toBeDefined();
    expect(Like).toBeDefined();
    expect(Dislike).toBeDefined();
  });

  it("exports a non-empty fixtures array", () => {
    expect(Array.isArray(fixtures)).toBe(true);
    expect(fixtures.length).toBeGreaterThan(0);
    expect(fixtures).toBe(countryFixtures);
    expect(fixtures.length).toBe(249);
  });

  it("verifies every country has all required fields with valid types", () => {
    for (const country of fixtures) {
      expect(typeof country.code).toBe("string");
      expect(country.code.length).toBe(2);

      expect(typeof country.name).toBe("string");
      expect(country.name.trim().length).toBeGreaterThan(0);

      expect(typeof country.capital).toBe("string");
      expect(country.capital.trim().length).toBeGreaterThan(0);

      expect(typeof country.flagImageUrl).toBe("string");
      expect(country.flagImageUrl).toMatch(/^https:\/\//);

      expect(typeof country.factSnippet).toBe("string");
      expect(country.factSnippet.trim().length).toBeGreaterThan(0);

      expect(typeof country.likes).toBe("number");
      expect(country.likes).toBeGreaterThanOrEqual(0);

      expect(typeof country.dislikes).toBe("number");
      expect(country.dislikes).toBeGreaterThanOrEqual(0);
    }
  });

  it("ensures country codes are unique", () => {
    const codes = fixtures.map((c) => c.code);
    const uniqueCodes = new Set(codes);
    expect(uniqueCodes.size).toBe(codes.length);
  });
});
