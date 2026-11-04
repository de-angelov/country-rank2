import type { JSX } from "react";
import type { Country } from "../../countries/country.js";

export type RankTone = "like" | "dislike";
export type RankNumberOrder = "highest-first" | "lowest-first" | { _tag: string };

export interface RankedCountriesListProps {
  ariaLabel: string;
  countries: readonly Country[];
  rankNumberOrder?: RankNumberOrder;
  rankTone: RankTone;
}

export declare function getDisplayedRankNumber(params: {
  index: number;
  order: RankNumberOrder;
  total: number;
}): number;

export declare function RankedCountriesList(props: RankedCountriesListProps): JSX.Element;
export default RankedCountriesList;
