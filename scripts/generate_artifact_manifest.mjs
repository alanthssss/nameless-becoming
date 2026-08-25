import { execFileSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { lstat, readFile, realpath, rename, rm, writeFile } from "node:fs/promises";
import { basename, dirname, join, resolve } from "node:path";
import { TextDecoder } from "node:util";
import { fileURLToPath } from "node:url";

export const ARTIFACT_MANIFEST_SCHEMA_VERSION = 1;

export const PLATFORM_ARTIFACTS = Object.freeze({
  "macos-universal": "NamelessBecoming-macOS.zip",
  "windows-x86_64": "NamelessBecoming-Windows.exe",
});

const scriptPath = fileURLToPath(import.meta.url);
const defaultRepositoryRoot = resolve(dirname(scriptPath), "..");
const utf8Decoder = new TextDecoder("utf-8", { fatal: true });

function git(repositoryRoot, args) {
  return execFileSync("git", args, {
    cwd: repositoryRoot,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

async function readRegularFile(path, label) {
  let stats;
  try {
    stats = await lstat(path);
  } catch (error) {
    if (error?.code === "ENOENT") throw new Error(`${label} does not exist: ${path}`);
    throw error;
  }
  if (!stats.isFile() || stats.isSymbolicLink()) {
    throw new Error(`${label} must be a regular file, not a directory or symbolic link: ${path}`);
  }
  return readFile(path);
}

function parseJson(bytes, label) {
  let text;
  try {
    text = utf8Decoder.decode(bytes);
  } catch {
    throw new Error(`${label} must be valid UTF-8 JSON.`);
  }
  try {
    return JSON.parse(text);
  } catch {
    throw new Error(`${label} must be valid JSON.`);
  }
}

function requireProductVersion(packageJson, projectText) {
  const packageVersion = packageJson?.version;
  if (typeof packageVersion !== "string" || packageVersion.length === 0 || /[\r\n]/u.test(packageVersion)) {
    throw new Error("package.json must contain a non-empty string version.");
  }
  const projectVersion = projectText.match(/^config\/version="([^"]+)"$/mu)?.[1];
  if (projectVersion !== packageVersion) {
    throw new Error(`Godot product version ${projectVersion || "<missing>"} does not match package version ${packageVersion}.`);
  }
  return packageVersion;
}

function validateProvenance(provenance, packageVersion, headCommit) {
  if (!provenance || typeof provenance !== "object" || Array.isArray(provenance)) {
    throw new Error("Build provenance must be a JSON object.");
  }
  const expectedKeys = ["commit", "dirty", "product_version", "schema_version"];
  const actualKeys = Object.keys(provenance).sort();
  if (actualKeys.length !== expectedKeys.length || actualKeys.some((key, index) => key !== expectedKeys[index])) {
    throw new Error(`Build provenance must contain exactly: ${expectedKeys.join(", ")}.`);
  }
  if (provenance.schema_version !== 1) {
    throw new Error("Build provenance schema_version must be 1.");
  }
  if (provenance.product_version !== packageVersion) {
    throw new Error(`Build provenance version ${String(provenance.product_version)} does not match package version ${packageVersion}.`);
  }
  if (typeof provenance.commit !== "string" || !/^[0-9a-f]{40}$/u.test(provenance.commit)) {
    throw new Error("Build provenance commit must be exactly 40 lowercase hexadecimal characters.");
  }
  if (provenance.commit !== headCommit) {
    throw new Error(`Build provenance commit ${provenance.commit} does not match current HEAD ${headCommit}.`);
  }
  if (provenance.dirty !== false) {
    throw new Error("Build provenance dirty must be false for a fixed artifact manifest.");
  }
}

function parseSidecar(sidecarBytes, artifactFilename) {
  let text;
  try {
    text = utf8Decoder.decode(sidecarBytes);
  } catch {
    throw new Error("SHA-256 sidecar must be valid UTF-8 text.");
  }
  const match = text.match(/^([0-9a-fA-F]{64})[ \t]+\*?([^\r\n]+)(?:\r?\n)?$/u);
  if (!match) {
    throw new Error("SHA-256 sidecar must contain exactly one standard checksum line.");
  }
  if (match[2] !== artifactFilename) {
    throw new Error(`SHA-256 sidecar names ${match[2]}; expected ${artifactFilename}.`);
  }
  return match[1].toLowerCase();
}

function validateSourceMetadata(repositoryRoot, headCommit, sourceRef, githubRunId) {
  const hasRef = sourceRef !== undefined;
  const hasRun = githubRunId !== undefined;
  if (hasRef !== hasRun) {
    throw new Error("--source-ref and --github-run-id must be provided together.");
  }
  if (!hasRef) return {};
  if (typeof sourceRef !== "string" || sourceRef.length === 0) {
    throw new Error("Source ref must be a non-empty full Git ref.");
  }
  try {
    git(repositoryRoot, ["check-ref-format", sourceRef]);
  } catch {
    throw new Error(`Source ref is not a valid full Git ref: ${sourceRef}`);
  }
  let refCommit;
  try {
    refCommit = git(repositoryRoot, ["rev-parse", "--verify", `${sourceRef}^{commit}`]).toLowerCase();
  } catch {
    throw new Error(`Source ref cannot be resolved to a commit in this checkout: ${sourceRef}`);
  }
  if (refCommit !== headCommit) {
    throw new Error(`Source ref ${sourceRef} resolves to ${refCommit}, not current HEAD ${headCommit}.`);
  }
  const normalizedRunId = String(githubRunId);
  if (!/^[1-9][0-9]*$/u.test(normalizedRunId)) {
    throw new Error("GitHub run ID must be a positive decimal integer.");
  }
  return { source_ref: sourceRef, github_run_id: normalizedRunId };
}

async function requireExpectedArtifactPath(repositoryRoot, artifactPath, artifactFilename) {
  const expectedPath = resolve(repositoryRoot, "builds", artifactFilename);
  const resolvedArtifactPath = resolve(artifactPath);
  if (resolvedArtifactPath !== expectedPath) {
    throw new Error(`Artifact path must be ${expectedPath} for the selected platform; received ${resolvedArtifactPath}.`);
  }

  const buildsPath = resolve(repositoryRoot, "builds");
  let buildsStats;
  try {
    buildsStats = await lstat(buildsPath);
  } catch (error) {
    if (error?.code === "ENOENT") throw new Error(`Artifact directory does not exist: ${buildsPath}`);
    throw error;
  }
  if (!buildsStats.isDirectory() || buildsStats.isSymbolicLink()) {
    throw new Error(`Artifact directory must be a real directory, not a symbolic link: ${buildsPath}`);
  }

  const [realRoot, realBuilds] = await Promise.all([realpath(repositoryRoot), realpath(buildsPath)]);
  if (realBuilds !== join(realRoot, "builds")) {
    throw new Error(`Artifact directory escapes the repository root: ${buildsPath}`);
  }
  return resolvedArtifactPath;
}

export async function generateArtifactManifest({
  artifactPath,
  platform,
  sourceRef,
  githubRunId,
  repositoryRoot = defaultRepositoryRoot,
}) {
  if (typeof artifactPath !== "string" || artifactPath.length === 0) {
    throw new Error("An artifact path is required.");
  }
  const artifactFilename = PLATFORM_ARTIFACTS[platform];
  if (!artifactFilename) {
    throw new Error(`Unsupported platform ${String(platform)}; expected one of: ${Object.keys(PLATFORM_ARTIFACTS).join(", ")}.`);
  }

  const resolvedRepositoryRoot = resolve(repositoryRoot);
  const resolvedArtifactPath = await requireExpectedArtifactPath(resolvedRepositoryRoot, artifactPath, artifactFilename);
  const packagePath = resolve(resolvedRepositoryRoot, "package.json");
  const projectPath = resolve(resolvedRepositoryRoot, "godot/project.godot");
  const provenancePath = resolve(resolvedRepositoryRoot, "godot/data/build_provenance.json");
  const sidecarPath = `${resolvedArtifactPath}.sha256`;
  const outputPath = `${resolvedArtifactPath}.manifest.json`;

  const [packageBytes, projectBytes, provenanceBytes, artifactBytes, sidecarBytes] = await Promise.all([
    readRegularFile(packagePath, "package.json"),
    readRegularFile(projectPath, "Godot project file"),
    readRegularFile(provenancePath, "Build provenance"),
    readRegularFile(resolvedArtifactPath, "Artifact"),
    readRegularFile(sidecarPath, "SHA-256 sidecar"),
  ]);
  if (artifactBytes.byteLength === 0) throw new Error("Artifact must not be empty.");

  const packageJson = parseJson(packageBytes, "package.json");
  const projectText = utf8Decoder.decode(projectBytes);
  const packageVersion = requireProductVersion(packageJson, projectText);
  const provenance = parseJson(provenanceBytes, "Build provenance");

  let headCommit;
  try {
    headCommit = git(resolvedRepositoryRoot, ["rev-parse", "--verify", "HEAD^{commit}"]).toLowerCase();
  } catch {
    throw new Error(`Repository root does not contain a readable Git HEAD: ${resolvedRepositoryRoot}`);
  }
  if (!/^[0-9a-f]{40}$/u.test(headCommit)) {
    throw new Error(`Current HEAD is not a full 40-character commit: ${headCommit}`);
  }
  validateProvenance(provenance, packageVersion, headCommit);

  const dirtyPaths = git(resolvedRepositoryRoot, ["status", "--porcelain=v1", "--untracked-files=all"]);
  if (dirtyPaths.length > 0) {
    throw new Error("Current Git worktree is dirty; fixed artifact manifests require a clean checkout.");
  }

  const actualSha256 = createHash("sha256").update(artifactBytes).digest("hex");
  const sidecarSha256 = parseSidecar(sidecarBytes, artifactFilename);
  if (sidecarSha256 !== actualSha256) {
    throw new Error(`Sidecar SHA-256 ${sidecarSha256} does not match actual artifact SHA-256 ${actualSha256}.`);
  }

  const sourceMetadata = validateSourceMetadata(resolvedRepositoryRoot, headCommit, sourceRef, githubRunId);
  const manifest = {
    schema_version: ARTIFACT_MANIFEST_SCHEMA_VERSION,
    product_version: packageVersion,
    commit: headCommit,
    dirty: false,
    platform,
    filename: basename(resolvedArtifactPath),
    size: artifactBytes.byteLength,
    sha256: actualSha256,
    ...sourceMetadata,
  };

  const temporaryOutput = `${outputPath}.${process.pid}.${randomUUID()}.tmp`;
  try {
    await writeFile(temporaryOutput, `${JSON.stringify(manifest, null, 2)}\n`, { encoding: "utf8", flag: "wx" });
    await rename(temporaryOutput, outputPath);
  } finally {
    await rm(temporaryOutput, { force: true });
  }
  return { manifest, outputPath };
}

function parseArguments(arguments_) {
  const options = {};
  const supported = new Map([
    ["--artifact", "artifactPath"],
    ["--platform", "platform"],
    ["--source-ref", "sourceRef"],
    ["--github-run-id", "githubRunId"],
  ]);
  for (let index = 0; index < arguments_.length; index += 1) {
    const flag = arguments_[index];
    if (flag === "--help") return { help: true };
    const key = supported.get(flag);
    if (!key) throw new Error(`Unknown argument: ${flag}`);
    if (Object.hasOwn(options, key)) throw new Error(`Argument may only be provided once: ${flag}`);
    const value = arguments_[index + 1];
    if (value === undefined || value.startsWith("--")) throw new Error(`Argument requires a value: ${flag}`);
    options[key] = value;
    index += 1;
  }
  return options;
}

function usage() {
  return [
    "Usage:",
    "  node scripts/generate_artifact_manifest.mjs --artifact <path> --platform <platform>",
    "    [--source-ref <full-ref> --github-run-id <id>]",
    "",
    `Platforms: ${Object.keys(PLATFORM_ARTIFACTS).join(", ")}`,
  ].join("\n");
}

async function main() {
  try {
    const options = parseArguments(process.argv.slice(2));
    if (options.help) {
      console.log(usage());
      return;
    }
    const result = await generateArtifactManifest(options);
    console.log(`Prepared ${result.manifest.platform} artifact manifest at ${result.outputPath}.`);
  } catch (error) {
    console.error(`Artifact manifest generation failed: ${error.message}`);
    process.exitCode = 1;
  }
}

if (resolve(process.argv[1] || "") === scriptPath) await main();
