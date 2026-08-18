import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));

export default defineConfig({
  plugins: [react()],
  root: resolve(root, "web"),
  server: {
    port: 5173,
    strictPort: true,
  },
  build: {
    outDir: resolve(root, "web/dist"),
    emptyOutDir: true,
  },
});
