export type Country = {
  code: string;
  name: string;
  capital: string;
  factSnippet: string;
  flagImageUrl: string;
  likes: number;
  dislikes: number;
};

export type VoteKind = "Like" | "Dislike";
