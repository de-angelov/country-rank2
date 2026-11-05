import { reactRouter } from "@react-router/dev/vite";
import tailwindcss from "@tailwindcss/vite";
import tsconfigPaths from "vite-tsconfig-paths";
import { defineConfig } from "vite";
import { funscript } from "funscript/plugins/vite";

export default defineConfig({
  esbuild: {
    include: /\.[jt]sx?$|\.funx?$/,
    loader: "tsx",
  },
  plugins: [
    funscript(),
    {
      name: "resolve-funscript-js",
      enforce: "pre",
      async resolveId(source, importer) {
        if (source.endsWith(".js") && importer) {
          const funCandidate = source.replace(/\.js$/, ".fun");
          const funxCandidate = source.replace(/\.js$/, ".funx");
          const resolved = await this.resolve(funCandidate, importer, { skipSelf: true });
          if (resolved) return resolved;
          const resolvedX = await this.resolve(funxCandidate, importer, { skipSelf: true });
          if (resolvedX) return resolvedX;
        }
      },
    },
    {
      name: "reject-server-modules-in-client",
      apply: "build",
      generateBundle(_options, bundle) {
        if (this.environment.name !== "client") return;
        for (const output of Object.values(bundle)) {
          if (output.type !== "chunk") continue;
          const serverModules = Object.keys(output.modules).filter((id) =>
            /\.server\.(?:[cm]?[jt]sx?|funx?)(?:\?|$)/.test(id),
          );
          if (serverModules.length) {
            this.error(`Server modules in client chunk ${output.fileName}: ${serverModules.join(", ")}`);
          }
        }
      },
    },
    tailwindcss(),
    reactRouter(),
    tsconfigPaths(),
  ],
});
