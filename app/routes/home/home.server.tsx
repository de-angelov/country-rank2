import { Effect } from "effect";
import {
  loadHomeRouteData as loadHomeRouteEffect,
  readHomeCountries as readHomeCountriesEffect,
} from "./home.server.fun";

export const readHomeCountries = readHomeCountriesEffect;
export const getHomeCountries = readHomeCountries;
export const loadHomeCountries = readHomeCountries;

export const loadHomeRouteData = (options?: unknown) =>
  Effect.runPromise(loadHomeRouteEffect(options));

export const loader = (_args?: unknown) => loadHomeRouteData();
