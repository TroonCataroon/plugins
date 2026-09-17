#!/usr/bin/env node

import { existsSync, readFileSync } from "fs";
import { dirname, resolve } from "path";
import { fileURLToPath } from "url";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, "..");

function loadJSON(path) {
  return JSON.parse(readFileSync(path, "utf-8"));
}

const schema = loadJSON(resolve(root, "schemas/agent-plugin-1.0.0.schema.json"));
const ajv = new Ajv2020({ allErrors: true, strict: false });
addFormats(ajv);
const validatePlugin = ajv.compile(schema);

let errors = 0;
function fail(message) {
  console.error(`ERROR: ${message}`);
  errors++;
}

const marketplacePath = resolve(root, ".agents/plugins/marketplace.json");
if (!existsSync(marketplacePath)) {
  fail(".agents/plugins/marketplace.json not found");
} else {
  const marketplace = loadJSON(marketplacePath);
  if (!Array.isArray(marketplace.plugins) || marketplace.plugins.length === 0) {
    fail("OpenAI marketplace must contain at least one plugin entry");
  } else {
    for (const entry of marketplace.plugins) {
      const source = entry?.source;
      if (source?.source !== "local" || typeof source?.path !== "string") {
        fail(`Plugin "${entry?.name ?? "<unnamed>"}": expected a local source.path`);
        continue;
      }

      const pluginDir = resolve(root, source.path);
      const manifestPath = resolve(pluginDir, "plugin.json");
      if (!existsSync(manifestPath)) {
        fail(`Plugin "${entry.name}": missing ${source.path}/plugin.json`);
        continue;
      }

      const manifest = loadJSON(manifestPath);
      if (!validatePlugin(manifest)) {
        fail(`Plugin "${entry.name}": Agent Plugins manifest schema validation failed`);
        for (const err of validatePlugin.errors ?? []) {
          const detail = err.keyword === "additionalProperties"
            ? `${err.message}: "${err.params.additionalProperty}"`
            : err.message;
          console.error(`  ${err.instancePath || "/"}: ${detail}`);
        }
      }

      if (manifest.name !== entry.name) {
        fail(`Plugin "${entry.name}": marketplace name does not match manifest name "${manifest.name}"`);
      }

      const skillRoot = resolve(pluginDir, "skills");
      if (!existsSync(skillRoot)) {
        fail(`Plugin "${entry.name}": skills directory is missing`);
      }
    }
  }
}

if (errors > 0) {
  console.error(`\nOpenAI plugin validation failed with ${errors} error(s).`);
  process.exit(1);
}

console.log("All OpenAI plugin integrations validated successfully.");
