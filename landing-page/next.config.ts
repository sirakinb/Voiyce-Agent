import type { NextConfig } from "next";
import path from "path";
import { fileURLToPath } from "url";

/** Directory containing this config (app root); avoids Turbopack cwd/root mismatches. */
const projectRoot = path.dirname(fileURLToPath(import.meta.url));

const nextConfig: NextConfig = {
  reactCompiler: true,
  turbopack: {
    root: projectRoot,
  },
};

export default nextConfig;
