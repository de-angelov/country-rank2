import { type RouteConfig, index, route } from "@react-router/dev/routes";

export default [
  index("routes/home/route.jsx"),
  route("top-liked", "routes/top-liked/route.jsx"),
  route("top-disliked", "routes/top-disliked/route.jsx"),
  route("votes", "routes/votes-route.jsx"),
] satisfies RouteConfig;
