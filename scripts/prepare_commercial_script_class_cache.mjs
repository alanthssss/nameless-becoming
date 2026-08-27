#!/usr/bin/env node

import { mkdir, readFile, rename, unlink, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const defaultGodotRoot = resolve(repositoryRoot, "godot");

const forbiddenClassFragments = ["nameless", "boss", "b01", "playtest", "productionhud"];
const forbiddenClassNames = new Set(["main"]);
const forbiddenPathFragments = [
  "/main.gd",
  "/bootstrap.gd",
  "/playtest/",
  "production_hud",
];

function fail(message) {
  throw new Error(`Commercial script-class cache refused: ${message}`);
}

function hasExactKeys(value, expected) {
  return (
    value !== null &&
    typeof value === "object" &&
    !Array.isArray(value) &&
    JSON.stringify(Object.keys(value).sort()) === JSON.stringify([...expected].sort())
  );
}

function globToRegExp(pattern) {
  let result = "^";
  for (let index = 0; index < pattern.length; index += 1) {
    const character = pattern[index];
    if (character === "*" && pattern[index + 1] === "*") {
      result += ".*";
      index += 1;
    } else if (character === "*") {
      result += "[^/]*";
    } else if (character === "?") {
      result += "[^/]";
    } else {
      result += character.replace(/[\\^$.*+?()[\]{}|]/g, "\\$&");
    }
  }
  return new RegExp(`${result}$`);
}

function parsePresetFilters(presetsText) {
  const sections = presetsText.split(/(?=^\[preset\.\d+\]\s*$)/m);
  const expectedNames = new Set(["macOS", "Windows Desktop", "Web"]);
  const filters = [];
  for (const section of sections) {
    const name = section.match(/^name="([^"]+)"$/m)?.[1];
    if (!expectedNames.has(name)) continue;
    const includeValue = section.match(/^include_filter="([^"]*)"$/m)?.[1];
    const excludeValue = section.match(/^exclude_filter="([^"]*)"$/m)?.[1];
    if (includeValue === undefined || excludeValue === undefined) {
      fail(`export preset ${name} has no literal include/exclude boundary`);
    }
    filters.push({
      name,
      include: includeValue.split(",").filter(Boolean).map(globToRegExp),
      exclude: excludeValue.split(",").filter(Boolean).map(globToRegExp),
    });
    expectedNames.delete(name);
  }
  if (expectedNames.size > 0) {
    fail(`missing commercial export presets: ${[...expectedNames].join(", ")}`);
  }
  return filters;
}

function validateAllowlistDocument(document) {
  if (!hasExactKeys(document, ["schema_version", "entries"]) || document.schema_version !== 1) {
    fail("allowlist must use the exact schema-v1 shape");
  }
  if (!Array.isArray(document.entries) || document.entries.length === 0) {
    fail("allowlist entries must be a non-empty array");
  }

  const seenClasses = new Set();
  const seenPaths = new Set();
  for (const [index, entry] of document.entries.entries()) {
    if (!hasExactKeys(entry, ["base", "class", "path"])) {
      fail(`allowlist entry ${index} does not have the exact base/class/path shape`);
    }
    if (!/^[A-Za-z_][A-Za-z0-9_]*$/.test(entry.base) || !/^[A-Za-z_][A-Za-z0-9_]*$/.test(entry.class)) {
      fail(`allowlist entry ${index} has a non-identifier base or class`);
    }
    if (!entry.path.startsWith("res://scripts/") || !entry.path.endsWith(".gd")) {
      fail(`allowlist entry ${index} is outside res://scripts/*.gd: ${entry.path}`);
    }
    const lowerClass = entry.class.toLowerCase();
    const lowerPath = entry.path.toLowerCase();
    if (
      forbiddenClassNames.has(lowerClass) ||
      forbiddenClassFragments.some((fragment) => lowerClass.includes(fragment)) ||
      forbiddenPathFragments.some((fragment) => lowerPath.includes(fragment))
    ) {
      fail(`allowlist entry ${index} contains a forbidden legacy class or path: ${entry.class} ${entry.path}`);
    }
    if (seenClasses.has(entry.class) || seenPaths.has(entry.path)) {
      fail(`allowlist contains a duplicate class or path: ${entry.class} ${entry.path}`);
    }
    seenClasses.add(entry.class);
    seenPaths.add(entry.path);
  }
}

async function validateSourcesAndPresets(entries, godotRoot) {
  const exportPresetsPath = resolve(godotRoot, "export_presets.cfg");
  const presets = parsePresetFilters(await readFile(exportPresetsPath, "utf8"));
  for (const entry of entries) {
    const relativePath = entry.path.slice("res://".length);
    for (const preset of presets) {
      if (!preset.include.some((pattern) => pattern.test(relativePath))) {
        fail(`${entry.path} is not explicitly included by ${preset.name}`);
      }
      if (preset.exclude.some((pattern) => pattern.test(relativePath))) {
        fail(`${entry.path} is excluded by ${preset.name}`);
      }
    }

    const sourcePath = resolve(godotRoot, relativePath);
    const source = await readFile(sourcePath, "utf8").catch(() => fail(`allowed source is missing: ${entry.path}`));
    const classNames = [...source.matchAll(/^class_name\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:#.*)?$/gm)].map((match) => match[1]);
    const bases = [...source.matchAll(/^extends\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:#.*)?$/gm)].map((match) => match[1]);
    if (classNames.length !== 1 || classNames[0] !== entry.class) {
      fail(`${entry.path} must declare exactly class_name ${entry.class}`);
    }
    if (bases.length !== 1 || bases[0] !== entry.base) {
      fail(`${entry.path} must declare exactly extends ${entry.base}`);
    }
    if (/^@(tool|icon|abstract)\b/m.test(source)) {
      fail(`${entry.path} uses unsupported class-cache annotations; extend the schema before exporting`);
    }
  }
}

function cacheRow(entry) {
  return [
    "{",
    `"base": &${JSON.stringify(entry.base)},`,
    `"class": &${JSON.stringify(entry.class)},`,
    '"icon": "",',
    '"is_abstract": false,',
    '"is_tool": false,',
    '"language": &"GDScript",',
    `"path": ${JSON.stringify(entry.path)}`,
    "}",
  ].join("\n");
}

export async function buildCanonicalCommercialClassCache({ godotRoot = defaultGodotRoot } = {}) {
  const allowlistPath = resolve(godotRoot, "data/commercial_script_class_allowlist.json");
  const allowlist = JSON.parse(await readFile(allowlistPath, "utf8"));
  validateAllowlistDocument(allowlist);
  const entries = [...allowlist.entries].sort((left, right) => left.class.localeCompare(right.class, "en"));
  await validateSourcesAndPresets(entries, godotRoot);
  return `list=[${entries.map(cacheRow).join(", ")}]\n`;
}

export async function writeCanonicalCommercialClassCache({
  godotRoot = defaultGodotRoot,
  cachePath = resolve(godotRoot, ".godot/global_script_class_cache.cfg"),
} = {}) {
  const canonical = await buildCanonicalCommercialClassCache({ godotRoot });
  const temporaryPath = `${cachePath}.commercial-${process.pid}.tmp`;
  try {
    await mkdir(dirname(cachePath), { recursive: true });
    await writeFile(temporaryPath, canonical, { flag: "wx" });
    await rename(temporaryPath, cachePath);
  } finally {
    await unlink(temporaryPath).catch(() => {});
  }
  return canonical;
}

function parseArguments(arguments_) {
  let godotRoot = defaultGodotRoot;
  let cachePath = "";
  let checkOnly = false;
  for (let index = 0; index < arguments_.length; index += 1) {
    const argument = arguments_[index];
    if (argument === "--cache") {
      const value = arguments_[index + 1];
      if (!value) fail("--cache requires a path");
      cachePath = resolve(value);
      index += 1;
    } else if (argument === "--godot-root") {
      const value = arguments_[index + 1];
      if (!value) fail("--godot-root requires a path");
      godotRoot = resolve(value);
      index += 1;
    } else if (argument === "--check") {
      checkOnly = true;
    } else {
      fail(`unknown argument: ${argument}`);
    }
  }
  return {
    godotRoot,
    cachePath: cachePath || resolve(godotRoot, ".godot/global_script_class_cache.cfg"),
    checkOnly,
  };
}

async function main() {
  const { godotRoot, cachePath, checkOnly } = parseArguments(process.argv.slice(2));
  const canonical = await buildCanonicalCommercialClassCache({ godotRoot });
  if (checkOnly) {
    const actual = await readFile(cachePath, "utf8").catch(() => fail(`cache does not exist: ${cachePath}`));
    if (actual !== canonical) {
      fail(`cache is not the exact commercial allowlist: ${cachePath}`);
    }
  } else {
    await writeCanonicalCommercialClassCache({ godotRoot, cachePath });
  }
  const digest = createHash("sha256").update(canonical).digest("hex");
  console.log(`Commercial script-class cache ${checkOnly ? "verified" : "prepared"}: ${digest}`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}
