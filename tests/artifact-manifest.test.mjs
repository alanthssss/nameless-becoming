import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdir, mkdtemp, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";
import test from "node:test";

import { generateArtifactManifest } from "../scripts/generate_artifact_manifest.mjs";

const macFilename = "NamelessBecoming-macOS.zip";
const windowsFilename = "NamelessBecoming-Windows.exe";

function git(root, args) {
  return execFileSync("git", args, {
    cwd: root,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

async function createFixture({ platform = "macos-universal", packageVersion = "0.9.5-rc.2", projectVersion = packageVersion } = {}) {
  const root = await mkdtemp(join(tmpdir(), "nameless-artifact-manifest-"));
  const filename = platform === "windows-x86_64" ? windowsFilename : macFilename;
  await mkdir(join(root, "godot/data"), { recursive: true });
  await mkdir(join(root, "builds"), { recursive: true });
  await Promise.all([
    writeFile(join(root, ".gitignore"), "/builds/\n/godot/data/build_provenance.json\n", "utf8"),
    writeFile(join(root, "package.json"), `${JSON.stringify({ version: packageVersion }, null, 2)}\n`, "utf8"),
    writeFile(join(root, "godot/project.godot"), `[application]\nconfig/version="${projectVersion}"\n`, "utf8"),
  ]);
  git(root, ["init", "--initial-branch=main"]);
  git(root, ["config", "user.name", "Artifact Manifest Test"]);
  git(root, ["config", "user.email", "artifact-manifest@example.invalid"]);
  git(root, ["add", ".gitignore", "package.json", "godot/project.godot"]);
  git(root, ["-c", "commit.gpgsign=false", "commit", "-m", "fixture"]);
  const commit = git(root, ["rev-parse", "HEAD"]);
  const provenancePath = join(root, "godot/data/build_provenance.json");
  const provenance = { schema_version: 1, product_version: packageVersion, commit, dirty: false };
  await writeFile(provenancePath, `${JSON.stringify(provenance, null, 2)}\n`, "utf8");

  const artifactPath = join(root, "builds", filename);
  const artifactBytes = Buffer.from(`verified-${platform}-artifact-bytes`);
  const sha256 = createHash("sha256").update(artifactBytes).digest("hex");
  await writeFile(artifactPath, artifactBytes);
  await writeFile(`${artifactPath}.sha256`, `${sha256}  ${filename}\n`, "utf8");
  return { root, commit, provenance, provenancePath, artifactPath, artifactBytes, sha256, platform };
}

async function useFixture(callback, options) {
  const fixture = await createFixture(options);
  try {
    await callback(fixture);
  } finally {
    await rm(fixture.root, { recursive: true, force: true });
  }
}

test("generates a schema v1 manifest from the verified artifact bytes", async () => {
  await useFixture(async (fixture) => {
    const result = await generateArtifactManifest({
      artifactPath: fixture.artifactPath,
      platform: fixture.platform,
      sourceRef: "refs/heads/main",
      githubRunId: "32844593593",
      repositoryRoot: fixture.root,
    });
    assert.equal(result.outputPath, `${fixture.artifactPath}.manifest.json`);
    assert.deepEqual(result.manifest, {
      schema_version: 1,
      product_version: "0.9.5-rc.2",
      commit: fixture.commit,
      dirty: false,
      platform: "macos-universal",
      filename: macFilename,
      size: fixture.artifactBytes.byteLength,
      sha256: fixture.sha256,
      source_ref: "refs/heads/main",
      github_run_id: "32844593593",
    });
    assert.deepEqual(JSON.parse(await readFile(result.outputPath, "utf8")), result.manifest);
  });
});

test("generates the same core schema for the fixed Windows executable path", async () => {
  await useFixture(async (fixture) => {
    const result = await generateArtifactManifest({
      artifactPath: fixture.artifactPath,
      platform: fixture.platform,
      repositoryRoot: fixture.root,
    });
    assert.equal(result.manifest.platform, "windows-x86_64");
    assert.equal(result.manifest.filename, windowsFilename);
    assert.equal(result.manifest.size, fixture.artifactBytes.byteLength);
    assert.equal(result.manifest.sha256, fixture.sha256);
    assert.equal(Object.hasOwn(result.manifest, "source_ref"), false);
    assert.equal(Object.hasOwn(result.manifest, "github_run_id"), false);
  }, { platform: "windows-x86_64" });
});

test("rejects artifact bytes changed after the sidecar was created", async () => {
  await useFixture(async (fixture) => {
    await writeFile(fixture.artifactPath, Buffer.concat([fixture.artifactBytes, Buffer.from("tampered")]));
    await assert.rejects(
      generateArtifactManifest({ artifactPath: fixture.artifactPath, platform: fixture.platform, repositoryRoot: fixture.root }),
      /Sidecar SHA-256 .* does not match actual artifact SHA-256/u,
    );
  });
});

test("rejects a tampered SHA-256 sidecar", async () => {
  await useFixture(async (fixture) => {
    await writeFile(`${fixture.artifactPath}.sha256`, `${"0".repeat(64)}  ${basename(fixture.artifactPath)}\n`, "utf8");
    await assert.rejects(
      generateArtifactManifest({ artifactPath: fixture.artifactPath, platform: fixture.platform, repositoryRoot: fixture.root }),
      /Sidecar SHA-256 0{64} does not match actual artifact SHA-256/u,
    );
  });
});

test("rejects package, Godot and provenance version disagreement", async () => {
  await useFixture(async (fixture) => {
    const mismatched = { ...fixture.provenance, product_version: "0.9.5-rc.1" };
    await writeFile(fixture.provenancePath, `${JSON.stringify(mismatched)}\n`, "utf8");
    await assert.rejects(
      generateArtifactManifest({ artifactPath: fixture.artifactPath, platform: fixture.platform, repositoryRoot: fixture.root }),
      /does not match package version 0\.9\.5-rc\.2/u,
    );
  });
  await useFixture(async (fixture) => {
    await assert.rejects(
      generateArtifactManifest({ artifactPath: fixture.artifactPath, platform: fixture.platform, repositoryRoot: fixture.root }),
      /Godot product version 0\.9\.5-rc\.1 does not match package version 0\.9\.5-rc\.2/u,
    );
  }, { projectVersion: "0.9.5-rc.1" });
});

test("rejects a short or wrong provenance commit", async () => {
  await useFixture(async (fixture) => {
    const shortCommit = { ...fixture.provenance, commit: fixture.commit.slice(0, 8) };
    await writeFile(fixture.provenancePath, `${JSON.stringify(shortCommit)}\n`, "utf8");
    await assert.rejects(
      generateArtifactManifest({ artifactPath: fixture.artifactPath, platform: fixture.platform, repositoryRoot: fixture.root }),
      /exactly 40 lowercase hexadecimal characters/u,
    );
  });
  await useFixture(async (fixture) => {
    const wrongCommit = { ...fixture.provenance, commit: fixture.commit === "f".repeat(40) ? "e".repeat(40) : "f".repeat(40) };
    await writeFile(fixture.provenancePath, `${JSON.stringify(wrongCommit)}\n`, "utf8");
    await assert.rejects(
      generateArtifactManifest({ artifactPath: fixture.artifactPath, platform: fixture.platform, repositoryRoot: fixture.root }),
      /does not match current HEAD/u,
    );
  });
});

test("rejects dirty provenance and a dirty current checkout", async () => {
  await useFixture(async (fixture) => {
    const dirty = { ...fixture.provenance, dirty: true };
    await writeFile(fixture.provenancePath, `${JSON.stringify(dirty)}\n`, "utf8");
    await assert.rejects(
      generateArtifactManifest({ artifactPath: fixture.artifactPath, platform: fixture.platform, repositoryRoot: fixture.root }),
      /dirty must be false/u,
    );
  });
  await useFixture(async (fixture) => {
    await writeFile(join(fixture.root, "unexpected.txt"), "dirty\n", "utf8");
    await assert.rejects(
      generateArtifactManifest({ artifactPath: fixture.artifactPath, platform: fixture.platform, repositoryRoot: fixture.root }),
      /Git worktree is dirty/u,
    );
  });
});

test("rejects unsupported or filename-incompatible platforms", async () => {
  await useFixture(async (fixture) => {
    await assert.rejects(
      generateArtifactManifest({ artifactPath: fixture.artifactPath, platform: "linux-x86_64", repositoryRoot: fixture.root }),
      /Unsupported platform/u,
    );
    await assert.rejects(
      generateArtifactManifest({ artifactPath: fixture.artifactPath, platform: "windows-x86_64", repositoryRoot: fixture.root }),
      /Artifact path must be .*NamelessBecoming-Windows\.exe/u,
    );
  });
});

test("rejects artifacts outside the fixed builds path and symbolic-link artifacts", async () => {
  await useFixture(async (fixture) => {
    const outsidePath = join(fixture.root, macFilename);
    await writeFile(outsidePath, fixture.artifactBytes);
    await assert.rejects(
      generateArtifactManifest({ artifactPath: outsidePath, platform: fixture.platform, repositoryRoot: fixture.root }),
      /Artifact path must be/u,
    );

    await rm(fixture.artifactPath);
    await symlink(outsidePath, fixture.artifactPath);
    await assert.rejects(
      generateArtifactManifest({ artifactPath: fixture.artifactPath, platform: fixture.platform, repositoryRoot: fixture.root }),
      /Artifact must be a regular file/u,
    );
  });
});
