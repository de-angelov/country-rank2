import { describe, expect, it } from "vitest";
import { loader as homeLoader } from "../app/routes/home/home.funx";
import { loader as topLikedLoader } from "../app/routes/top-liked/top-liked.funx";
import { loader as topDislikedLoader } from "../app/routes/top-disliked/top-disliked.funx";
import { action } from "../app/routes/votes.fun";

describe("FunScript route entry points", () => {
  it("returns resolved route data to React Router", async () => {
    const home = await homeLoader();
    const liked = await topLikedLoader({ request: new Request("http://localhost/top-liked") });
    const disliked = await topDislikedLoader({ request: new Request("http://localhost/top-disliked") });
    expect(home.countries.length).toBeGreaterThan(0);
    expect(liked.countries.length).toBe(home.countries.length);
    expect(disliked.countries.length).toBe(home.countries.length);
  });

  it("routes vote submissions to the server action", async () => {
    const response = await action({ request: new Request("http://localhost/votes", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{}",
    }) });
    expect(response.status).toBe(400);
    expect(await response.json()).toMatchObject({ ok: false, error: { code: "invalid_vote_request" } });
  });
});
