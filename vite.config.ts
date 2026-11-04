import { reactRouter } from "@react-router/dev/vite";
import tailwindcss from "@tailwindcss/vite";
import tsconfigPaths from "vite-tsconfig-paths";
import { defineConfig } from "vite";
import { funscript } from "funscript/plugins/vite";

export default defineConfig({
  esbuild: {
    include: /\.[jt]sx?$|\.funx$/,
    loader: "tsx",
  },
  plugins: [funscript(), tailwindcss(), reactRouter(), tsconfigPaths()],
});
