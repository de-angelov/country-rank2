import { type RouteConfig, index, route } from "@react-router/dev/routes";

export default [
  index("routes/home/home.funx"),
  route("top-liked", "routes/top-liked/top-liked.funx"),
  route("top-disliked", "routes/top-disliked/top-disliked.funx"),
] satisfies RouteConfig;
