/**
 * Cross-platform resources copy script
 */

import { existsSync, cpSync, copyFileSync, mkdirSync } from "fs";
import { join } from "path";

const ROOT_DIR = join(import.meta.dir, "..");
const ELECTRON_DIR = join(ROOT_DIR, "apps/electron");

const srcDir = join(ELECTRON_DIR, "resources");
const destDir = join(ELECTRON_DIR, "dist/resources");

if (existsSync(srcDir)) {
  cpSync(srcDir, destDir, { recursive: true, force: true });
  console.log("📦 Copied resources to dist");
} else {
  console.log("⚠️ No resources directory found");
}

for (const server of ["session-mcp-server", "pi-agent-server"]) {
  const source = join(ROOT_DIR, "packages", server, "dist", "index.js");
  const destination = join(destDir, server, "index.js");

  if (!existsSync(source)) {
    throw new Error(`Missing ${server} build output: ${source}`);
  }

  mkdirSync(join(destDir, server), { recursive: true });
  copyFileSync(source, destination);
  console.log(`📦 Copied ${server} to dist resources`);
}
