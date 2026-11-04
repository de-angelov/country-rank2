import type { JSX } from "react";

export type RankingOrder =
  | { _tag: "HighestFirst" }
  | { _tag: "LowestFirst" };

export declare const HighestFirst: RankingOrder;
export declare const LowestFirst: RankingOrder;

export declare const getRankingOrderLabel: (order: RankingOrder) => string;

export interface RankingOrderControlsProps {
  currentOrder?: RankingOrder;
  order?: RankingOrder;
  onOrderChange?: (order: RankingOrder) => void;
  onChange?: (order: RankingOrder) => void;
}

export declare const RankingOrderControls: (props: RankingOrderControlsProps) => JSX.Element;
export default RankingOrderControls;
