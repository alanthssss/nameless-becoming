import { execFileSync } from "node:child_process";
import { mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const defaultOutput = resolve(repositoryRoot, "godot/data/build_provenance.json");

function normalizeCommit(candidate) {
  const commit = candidate.trim().toLowerCase();
  if (!/^[0-9a-f]{7,40}$/.test(commit)) {
    throw new Error("Build commit must be a 7-40 character hexadecimal Git object ID.");
  }
  return commit;
}

function resolveCommit() {
  const injected = process.env.NAMELESS_BUILD_COMMIT || process.env.GITHUB_SHA;
  if (injected) return normalizeCommit(injected);
  const head = execFileSync("git", ["rev-parse", "--verify", "HEAD"], {
    cwd: repositoryRoot,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "inherit"],
  });
  return normalizeCommit(head);
}

function resolveDirty() {
  const injected = process.env.NAMELESS_BUILD_DIRTY;
  if (injected) {
    if (injected === "true") return true;
    if (injected === "false") return false;
    throw new Error("NAMELESS_BUILD_DIRTY must be true or false.");
  }
  const status = execFileSync("git", ["status", "--porcelain=v1", "--untracked-files=all"], {
    cwd: repositoryRoot,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "inherit"],
  });
  return status.trim().length > 0;
}

async function readProductVersion() {
  const packageJson = JSON.parse(await readFile(resolve(repositoryRoot, "package.json"), "utf8"));
  const project = await readFile(resolve(repositoryRoot, "godot/project.godot"), "utf8");
  const projectVersion = project.match(/^config\/version="([^"]+)"$/m)?.[1];
  if (!projectVersion || projectVersion !== packageJson.version) {
    throw new Error(`Godot product version ${projectVersion || "<missing>"} does not match package version ${packageJson.version}.`);
  }
  return projectVersion;
}

async function main() {
  const output = resolve(process.env.NAMELESS_BUILD_INFO_PATH || defaultOutput);
  const provenance = {
    schema_version: 1,
    product_version: await readProductVersion(),
    commit: resolveCommit(),
    dirty: resolveDirty(),
  };
  await mkdir(dirname(output), { recursive: true });
  const temporaryOutput = `${output}.${process.pid}.tmp`;
  await writeFile(temporaryOutput, `${JSON.stringify(provenance, null, 2)}\n`, "utf8");
  await rename(temporaryOutput, output);
  const dirtySuffix = provenance.dirty ? "+dirty" : "";
  console.log(`Prepared ${provenance.product_version} build provenance at ${provenance.commit.slice(0, 8)}${dirtySuffix}.`);
}

await main();
