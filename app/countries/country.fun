export schema Country = {
  code: String
  name: String
  capital: String
  factSnippet: String
  flagImageUrl: String
  likes: Number
  dislikes: Number
}

export schema VoteKind =
  | Like
  | Dislike
