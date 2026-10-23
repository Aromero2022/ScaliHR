import { defineConfig } from "vitest/config";
import path from "path";

export default defineConfig({
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "src"),
      "@talentgo/shared": path.resolve(__dirname, "../../packages/shared/src"),
    },
  },
  plugins: [
    {
      name: "resolve-parenthesized-routes",
      resolveId(source) {
        if (source.startsWith("@/") && source.includes("(")) {
          const resolved = path.resolve(__dirname, "src", source.slice(2));
          return resolved + ".ts";
        }
      },
    },
  ],
  test: {
    globals: true,
    environment: "node",
    include: ["__tests__/**/*.test.ts"],
  },
});
