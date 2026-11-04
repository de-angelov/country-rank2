import { describe, expect, it } from "vitest";
import React from "react";
import { renderToString } from "react-dom/server";

import {
  CountryCard,
  getCountryCardFlagImageUrl,
} from "../app/components/country-card/country-card.funx";
import {
  RankedCountriesList,
  getDisplayedRankNumber,
} from "../app/components/ranked-countries-list/ranked-countries-list.funx";

const sampleCountry = {
  code: "JP",
  name: "Japan",
  capital: "Tokyo",
  factSnippet: "Vending machines, bullet trains, and stationery with main-character energy.",
  flagImageUrl: "https://commons.wikimedia.org/wiki/Special:FilePath/Flag%20of%20Japan.svg",
  likes: 1234,
  dislikes: 56,
};

const sampleCountry2 = {
  code: "FR",
  name: "France",
  capital: "Paris",
  factSnippet: "Bakeries, museums, and high-speed rail.",
  flagImageUrl: "https://commons.wikimedia.org/wiki/Special:FilePath/Flag%20of%20France.svg",
  likes: 800,
  dislikes: 120,
};

describe("CountryCard component", () => {
  it("renders country details, flag, and vote statistics", () => {
    const html = renderToString(
      React.createElement(CountryCard, { country: sampleCountry })
    );

    expect(html).toContain("Japan");
    expect(html).toContain("Capital: Tokyo");
    expect(html).toContain("Vending machines, bullet trains, and stationery with main-character energy.");
    expect(html).toContain('alt="Japan flag"');
    expect(html).toContain('src="https://commons.wikimedia.org/wiki/Special:FilePath/Flag%20of%20Japan.svg"');
    expect(html).toContain("1,234 likes");
    expect(html).toContain("56 dislikes");
    expect(html).toContain("Japan vote ratio: 1,234 likes (96%) and 56 dislikes (4%).");
    expect(html).toContain('role="progressbar"');
  });

  it("renders vote buttons posting to /votes server action", () => {
    const html = renderToString(
      React.createElement(CountryCard, { country: sampleCountry })
    );

    expect(html).toContain('action="/votes"');
    expect(html).toContain('method="post"');
    expect(html).toContain('name="countryCode" value="JP"');
    expect(html).toContain('name="code" value="JP"');
    expect(html).toContain('aria-label="Like Japan"');
    expect(html).toContain('aria-label="Dislike Japan"');
    expect(html).toContain(">Like</button>");
    expect(html).toContain(">Dislike</button>");
  });

  it("renders sprite when includeVoteIconSprite is true or default", () => {
    const html = renderToString(
      React.createElement(CountryCard, { country: sampleCountry })
    );
    expect(html).toContain('id="country-card-thumbs-up"');
    expect(html).toContain('id="country-card-thumbs-down"');
  });

  it("omits sprite when includeVoteIconSprite is false", () => {
    const html = renderToString(
      React.createElement(CountryCard, {
        country: sampleCountry,
        includeVoteIconSprite: false,
      })
    );
    expect(html).not.toContain('id="country-card-thumbs-up"');
    expect(html).not.toContain('id="country-card-thumbs-down"');
  });

  it("renders 50% ratio for country with 0 likes and 0 dislikes", () => {
    const html = renderToString(
      React.createElement(CountryCard, {
        country: { ...sampleCountry, likes: 0, dislikes: 0 },
      })
    );
    expect(html).toContain("0 likes");
    expect(html).toContain("0 dislikes");
    expect(html).toContain("Japan vote ratio: 0 likes (0%) and 0 dislikes (0%).");
    expect(html).toContain('aria-valuenow="50"');
    expect(html).toContain("transform:translateX(-50%)");
  });

  it("returns flagImageUrl from getCountryCardFlagImageUrl helper", () => {
    expect(getCountryCardFlagImageUrl(sampleCountry)).toBe(sampleCountry.flagImageUrl);
  });
});

describe("RankedCountriesList component", () => {
  const countries = [sampleCountry, sampleCountry2];

  it("renders an ordered list with aria-label and rank markers", () => {
    const html = renderToString(
      React.createElement(RankedCountriesList, {
        ariaLabel: "Top Liked Countries",
        countries,
        rankTone: "like",
      })
    );

    expect(html).toContain('<ol class="grid list-none gap-5 p-0" aria-label="Top Liked Countries">');
    expect(html).toContain('aria-label="Rank 1"');
    expect(html).toContain('aria-label="Rank 2"');
    expect(html).toContain("Japan");
    expect(html).toContain("France");
    expect(html).toContain("bg-vote-like");
  });

  it("applies dislike tone class when rankTone is dislike", () => {
    const html = renderToString(
      React.createElement(RankedCountriesList, {
        ariaLabel: "Top Disliked Countries",
        countries,
        rankTone: "dislike",
      })
    );

    expect(html).toContain("bg-vote-dislike");
  });

  it("calculates displayed rank numbers correctly with getDisplayedRankNumber", () => {
    expect(getDisplayedRankNumber({ index: 0, order: "highest-first", total: 10 })).toBe(1);
    expect(getDisplayedRankNumber({ index: 4, order: "highest-first", total: 10 })).toBe(5);
    expect(getDisplayedRankNumber({ index: 0, order: "lowest-first", total: 10 })).toBe(10);
    expect(getDisplayedRankNumber({ index: 9, order: "lowest-first", total: 10 })).toBe(1);
    expect(getDisplayedRankNumber({ index: 0, order: { _tag: "LowestFirst" }, total: 10 })).toBe(10);
  });

  it("inverts rank numbers when rankNumberOrder is lowest-first", () => {
    const html = renderToString(
      React.createElement(RankedCountriesList, {
        ariaLabel: "Countries Ranked",
        countries,
        rankNumberOrder: "lowest-first",
        rankTone: "like",
      })
    );

    expect(html).toContain('aria-label="Rank 2"');
    expect(html).toContain('aria-label="Rank 1"');
  });

  it("renders icon sprite once at the list root", () => {
    const html = renderToString(
      React.createElement(RankedCountriesList, {
        ariaLabel: "Countries",
        countries,
        rankTone: "like",
      })
    );

    // Sprite should appear only once (1 instance of the symbol definitions)
    const matchesUp = html.match(/id="country-card-thumbs-up"/g);
    expect(matchesUp?.length).toBe(1);
  });
});
