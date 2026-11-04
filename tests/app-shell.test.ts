import { describe, expect, it, vi } from "vitest";
import React from "react";
import { renderToString } from "react-dom/server";
import { MemoryRouter } from "react-router";
import { AppShell } from "../app/components/app-shell/app-shell.funx";
import {
  RankingOrderControls,
  type RankingOrder,
  HighestFirst,
  LowestFirst,
  getRankingOrderLabel,
} from "../app/components/ranking-order-controls/ranking-order-controls.funx";

describe("AppShell component", () => {
  it("renders navigation shell with links to '/', '/top-liked', and '/top-disliked'", () => {
    const html = renderToString(
      React.createElement(
        MemoryRouter,
        null,
        React.createElement(
          AppShell,
          null,
          React.createElement("div", { id: "test-content" }, "Hello world content")
        )
      )
    );

    expect(html).toContain('href="/"');
    expect(html).toContain('href="/top-liked"');
    expect(html).toContain('href="/top-disliked"');
    expect(html).toContain("Country Rank");
    expect(html).toContain("Hello world content");
  });

  it("renders without children without throwing", () => {
    const html = renderToString(
      React.createElement(MemoryRouter, null, React.createElement(AppShell, null))
    );
    expect(html).toContain('href="/"');
    expect(html).toContain('href="/top-liked"');
    expect(html).toContain('href="/top-disliked"');
  });
});

describe("RankingOrderControls component", () => {
  it("exports HighestFirst and LowestFirst constructors with correct tags", () => {
    expect(HighestFirst).toBeDefined();
    expect(LowestFirst).toBeDefined();
    expect(HighestFirst._tag).toBe("HighestFirst");
    expect(LowestFirst._tag).toBe("LowestFirst");

    const order: RankingOrder = HighestFirst;
    expect(order._tag).toBe("HighestFirst");
  });

  it("matches ranking order in getRankingOrderLabel helper", () => {
    expect(getRankingOrderLabel(HighestFirst)).toBe("Highest First");
    expect(getRankingOrderLabel(LowestFirst)).toBe("Lowest First");
  });

  it("renders highest and lowest toggle buttons with default HighestFirst active", () => {
    const html = renderToString(
      React.createElement(RankingOrderControls, { currentOrder: HighestFirst })
    );

    expect(html).toContain("Highest First");
    expect(html).toContain("Lowest First");
    expect(html).toContain('aria-pressed="true"');
    expect(html).toContain('aria-pressed="false"');
  });

  it("renders with LowestFirst active when currentOrder is LowestFirst", () => {
    const html = renderToString(
      React.createElement(RankingOrderControls, { currentOrder: LowestFirst })
    );

    expect(html).toContain("Highest First");
    expect(html).toContain("Lowest First");
    expect(html).toContain('aria-pressed="false"');
    expect(html).toContain('aria-pressed="true"');
  });

  it("renders correctly when using order prop", () => {
    const html = renderToString(
      React.createElement(RankingOrderControls, { order: LowestFirst })
    );

    expect(html).toContain("Highest First");
    expect(html).toContain("Lowest First");
    expect(html).toContain('aria-pressed="true"');
  });

  it("triggers onOrderChange callback with corresponding variant on button click", () => {
    const onOrderChange = vi.fn();
    const element = RankingOrderControls({
      currentOrder: HighestFirst,
      onOrderChange,
    });

    const [highestBtn, lowestBtn] = element.props.children;
    lowestBtn.props.onClick();
    expect(onOrderChange).toHaveBeenCalledWith(LowestFirst);

    highestBtn.props.onClick();
    expect(onOrderChange).toHaveBeenCalledWith(HighestFirst);
  });
});
