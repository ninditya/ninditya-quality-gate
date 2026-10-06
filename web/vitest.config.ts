import { defineConfig, mergeConfig } from "vitest/config";
import path from "path";
import viteConfig from "./vite.config";

export default mergeConfig(
  viteConfig,
  defineConfig({
    resolve: {
      alias: {
        // The API <-> web contract fixtures live outside both services.
        "@contracts": path.resolve(__dirname, "../contracts"),
      },
    },
    test: {
      environment: "jsdom",
      globals: true,
      setupFiles: ["./src/test/setup.ts"],
      css: false,
      // A focused test silently disables every other check in its file.
      allowOnly: !process.env.CI,
    },
  })
);
