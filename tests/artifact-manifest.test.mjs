import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { chmod, mkdir, mkdtemp, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, dirname, join } from "node:path";
import test from "node:test";

import { generateArtifactManifest } from "../scripts/generate_artifact_manifest.mjs";

const macFilename = "SeeYouAtTheHive-macOS.zip";
const windowsFilename = "SeeYouAtTheHive-Windows.exe";
const macPackEntry = "SeeYouAtTheHive.app/Contents/Resources/SeeYouAtTheHive.pck";

const fakeGodotSource = `#!/usr/bin/env node
import { createHash } from "node:crypto";
import { readFileSync, writeFileSync } from "node:fs";

if (process.argv.includes("--version")) {
  console.log("4.6.2.stable.test");
  process.exit(0);
}
const separator = process.argv.lastIndexOf("--");
const [packPath, reportFlag, reportPath] = process.argv.slice(separator + 1);
if (separator < 0 || reportFlag !== "--report" || !reportPath) {
  console.error("fake inspector received invalid arguments");
  process.exit(2);
}
let container;
try {
  container = JSON.parse(readFileSync(packPath, "utf8"));
} catch {
  console.error("fake pack is malformed");
  process.exit(1);
}
if (container.contains_internal_resources) {
  console.error("fake pack contains internal resources");
  process.exit(1);
}
if (!Object.hasOwn(container, "build_provenance_raw")) {
  console.error("fake pack is missing embedded build provenance");
  process.exit(1);
}
let buildProvenance;
try {
  buildProvenance = JSON.parse(container.build_provenance_raw);
} catch {
  console.error("fake pack has malformed embedded build provenance");
  process.exit(1);
}
const packBytes = readFileSync(packPath);
const report = {
  schema_version: 1,
  pack_sha256: createHash("sha256").update(packBytes).digest("hex"),
  build_provenance: buildProvenance,
};
writeFileSync(reportPath, JSON.stringify(report) + "\\n", { flag: "wx" });
console.log("EXPORT PACK CONTENTS VERIFIED: fake pack (no res://tests or res://tools)");
`;

function git(root, args) {
  return execFileSync("git", args, {
    cwd: root,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

async function writeEmbeddedArtifact(fixture, { provenance = fixture.provenance, raw, missing = false } = {}) {
  const container = {};
  if (!missing) container.build_provenance_raw = raw ?? JSON.stringify(provenance);
  const packBytes = Buffer.from(`${JSON.stringify(container)}\n`);

  if (fixture.platform === "windows-x86_64") {
    await writeFile(fixture.artifactPath, packBytes);
  } else {
    const stagingRoot = join(fixture.root, "builds/.mac-pack-staging");
    const stagedPack = join(stagingRoot, macPackEntry);
    await rm(stagingRoot, { recursive: true, force: true });
    await mkdir(dirname(stagedPack), { recursive: true });
    await writeFile(stagedPack, packBytes);
    await rm(fixture.artifactPath, { force: true });
    execFileSync("zip", ["-q", "-r", fixture.artifactPath, "SeeYouAtTheHive.app"], {
      cwd: stagingRoot,
      stdio: ["ignore", "pipe", "pipe"],
    });
  }

  fixture.artifactBytes = await readFile(fixture.artifactPath);
  fixture.sha256 = createHash("sha256").update(fixture.artifactBytes).digest("hex");
  await writeFile(`${fixture.artifactPath}.sha256`, `${fixture.sha256}  ${basename(fixture.artifactPath)}\n`, "utf8");
}

async function createFixture({ platform = "macos-universal", packageVersion = "0.9.5-rc.2", projectVersion = packageVersion } = {}) {
  const root = await mkdtemp(join(tmpdir(), "see-you-at-the-hive-artifact-manifest-"));
  const filename = platform === "windows-x86_64" ? windowsFilename : macFilename;
  const godotBin = join(root, "fake-godot.mjs");
  await mkdir(join(root, "godot/data"), { recursive: true });
  await mkdir(join(root, "builds"), { recursive: true });
  await Promise.all([
    writeFile(join(root, ".gitignore"), "/builds/\n/godot/data/build_provenance.json\n", "utf8"),
    writeFile(join(root, "package.json"), `${JSON.stringify({ version: packageVersion }, null, 2)}\n`, "utf8"),
    writeFile(join(root, "godot/project.godot"), `[application]\nconfig/version="${projectVersion}"\n`, "utf8"),
    writeFile(godotBin, fakeGodotSource, "utf8"),
  ]);
  await chmod(godotBin, 0o755);
  git(root, ["init", "--initial-branch=main"]);
  git(root, ["config", "user.name", "Artifact Manifest Test"]);
  git(root, ["config", "user.email", "artifact-manifest@example.invalid"]);
  git(root, ["add", ".gitignore", "package.json", "godot/project.godot", "fake-godot.mjs"]);
  git(root, ["-c", "commit.gpgsign=false", "commit", "-m", "fixture"]);
  git(root, ["-c", "commit.gpgsign=false", "commit", "--allow-empty", "-m", "candidate"]);
  git(root, ["branch", "stale", "HEAD^"]);

  const commit = git(root, ["rev-parse", "HEAD"]);
  const provenancePath = join(root, "godot/data/build_provenance.json");
  const provenance = { schema_version: 1, product_version: packageVersion, commit, dirty: false };
  await writeFile(provenancePath, `${JSON.stringify(provenance, null, 2)}\n`, "utf8");
  const fixture = {
    root,
    commit,
    provenance,
    provenancePath,
    artifactPath: join(root, "builds", filename),
    godotBin,
    platform,
  };
  await writeEmbeddedArtifact(fixture);
  return fixture;
}

function manifestOptions(fixture, overrides = {}) {
  return {
    artifactPath: fixture.artifactPath,
    platform: fixture.platform,
    repositoryRoot: fixture.root,
    godotBin: fixture.godotBin,
    ...overrides,
  };
}

async function useFixture(callback, options) {
  const fixture = await createFixture(options);
  try {
    await callback(fixture);
  } finally {
    await rm(fixture.root, { recursive: true, force: true });
  }
}

test("generates a schema v1 manifest from the final macOS ZIP and its embedded provenance", async () => {
  await useFixture(async (fixture) => {
    const result = await generateArtifactManifest(manifestOptions(fixture, {
      sourceRef: "refs/heads/main",
      githubRunId: "32844593593",
    }));
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

test("generates the same core schema from the final Windows EXE embedded pack", async () => {
  await useFixture(async (fixture) => {
    const result = await generateArtifactManifest(manifestOptions(fixture));
    assert.equal(result.manifest.platform, "windows-x86_64");
    assert.equal(result.manifest.filename, windowsFilename);
    assert.equal(result.manifest.size, fixture.artifactBytes.byteLength);
    assert.equal(result.manifest.sha256, fixture.sha256);
    assert.equal(Object.hasOwn(result.manifest, "source_ref"), false);
    assert.equal(Object.hasOwn(result.manifest, "github_run_id"), false);
  }, { platform: "windows-x86_64" });
});

test("rejects a stale Windows artifact even when its current sidecar is valid", async () => {
  await useFixture(async (fixture) => {
    const staleCommit = fixture.commit === "f".repeat(40) ? "e".repeat(40) : "f".repeat(40);
    await writeEmbeddedArtifact(fixture, { provenance: { ...fixture.provenance, commit: staleCommit } });
    await assert.rejects(
      generateArtifactManifest(manifestOptions(fixture)),
      /Embedded build provenance commit .* does not match current HEAD/u,
    );
  }, { platform: "windows-x86_64" });
});

test("rejects artifact bytes changed after the sidecar was created", async () => {
  await useFixture(async (fixture) => {
    await writeFile(fixture.artifactPath, Buffer.concat([fixture.artifactBytes, Buffer.from("tampered")]));
    await assert.rejects(
      generateArtifactManifest(manifestOptions(fixture)),
      /Sidecar SHA-256 .* does not match actual artifact SHA-256/u,
    );
  });
});

test("rejects a tampered SHA-256 sidecar", async () => {
  await useFixture(async (fixture) => {
    await writeFile(`${fixture.artifactPath}.sha256`, `${"0".repeat(64)}  ${basename(fixture.artifactPath)}\n`, "utf8");
    await assert.rejects(
      generateArtifactManifest(manifestOptions(fixture)),
      /Sidecar SHA-256 0{64} does not match actual artifact SHA-256/u,
    );
  });
});

test("rejects package, Godot and workspace provenance version disagreement", async () => {
  await useFixture(async (fixture) => {
    const mismatched = { ...fixture.provenance, product_version: "0.9.5-rc.1" };
    await writeFile(fixture.provenancePath, `${JSON.stringify(mismatched)}\n`, "utf8");
    await assert.rejects(
      generateArtifactManifest(manifestOptions(fixture)),
      /Workspace build provenance version .* does not match package version 0\.9\.5-rc\.2/u,
    );
  });
  await useFixture(async (fixture) => {
    await assert.rejects(
      generateArtifactManifest(manifestOptions(fixture)),
      /Godot product version 0\.9\.5-rc\.1 does not match package version 0\.9\.5-rc\.2/u,
    );
  }, { projectVersion: "0.9.5-rc.1" });
});

test("rejects a short or wrong workspace provenance commit", async () => {
  await useFixture(async (fixture) => {
    const shortCommit = { ...fixture.provenance, commit: fixture.commit.slice(0, 8) };
    await writeFile(fixture.provenancePath, `${JSON.stringify(shortCommit)}\n`, "utf8");
    await assert.rejects(
      generateArtifactManifest(manifestOptions(fixture)),
      /Workspace build provenance commit must be exactly 40/u,
    );
  });
  await useFixture(async (fixture) => {
    const wrongCommit = { ...fixture.provenance, commit: fixture.commit === "f".repeat(40) ? "e".repeat(40) : "f".repeat(40) };
    await writeFile(fixture.provenancePath, `${JSON.stringify(wrongCommit)}\n`, "utf8");
    await assert.rejects(
      generateArtifactManifest(manifestOptions(fixture)),
      /Workspace build provenance commit .* does not match current HEAD/u,
    );
  });
});

test("rejects dirty workspace provenance and a dirty current checkout", async () => {
  await useFixture(async (fixture) => {
    const dirty = { ...fixture.provenance, dirty: true };
    await writeFile(fixture.provenancePath, `${JSON.stringify(dirty)}\n`, "utf8");
    await assert.rejects(generateArtifactManifest(manifestOptions(fixture)), /Workspace build provenance dirty must be false/u);
  });
  await useFixture(async (fixture) => {
    await writeFile(join(fixture.root, "unexpected.txt"), "dirty\n", "utf8");
    await assert.rejects(generateArtifactManifest(manifestOptions(fixture)), /Git worktree is dirty/u);
  });
});

test("rejects embedded provenance version, dirty state and extra keys", async (context) => {
  const cases = [
    {
      name: "version mismatch",
      change: (provenance) => ({ ...provenance, product_version: "0.9.5-rc.1" }),
      error: /Embedded build provenance version .* does not match package version/u,
    },
    {
      name: "dirty build",
      change: (provenance) => ({ ...provenance, dirty: true }),
      error: /Embedded build provenance dirty must be false/u,
    },
    {
      name: "extra key",
      change: (provenance) => ({ ...provenance, branch: "main" }),
      error: /Embedded build provenance must contain exactly/u,
    },
  ];
  for (const fixtureCase of cases) {
    await context.test(fixtureCase.name, async () => {
      await useFixture(async (fixture) => {
        await writeEmbeddedArtifact(fixture, { provenance: fixtureCase.change(fixture.provenance) });
        await assert.rejects(generateArtifactManifest(manifestOptions(fixture)), fixtureCase.error);
      });
    });
  }
});

test("rejects malformed or missing provenance inside the final macOS pack", async (context) => {
  await context.test("malformed", async () => {
    await useFixture(async (fixture) => {
      await writeEmbeddedArtifact(fixture, { raw: "{not-json" });
      await assert.rejects(generateArtifactManifest(manifestOptions(fixture)), /malformed embedded build provenance/u);
    });
  });
  await context.test("missing", async () => {
    await useFixture(async (fixture) => {
      await writeEmbeddedArtifact(fixture, { missing: true });
      await assert.rejects(generateArtifactManifest(manifestOptions(fixture)), /missing embedded build provenance/u);
    });
  });
});

test("rejects incomplete, invalid or mismatched source run metadata", async () => {
  await useFixture(async (fixture) => {
    await assert.rejects(
      generateArtifactManifest(manifestOptions(fixture, { sourceRef: "refs/heads/main" })),
      /--source-ref and --github-run-id must be provided together/u,
    );
    await assert.rejects(
      generateArtifactManifest(manifestOptions(fixture, { githubRunId: "123" })),
      /--source-ref and --github-run-id must be provided together/u,
    );
    await assert.rejects(
      generateArtifactManifest(manifestOptions(fixture, { sourceRef: "main", githubRunId: "123" })),
      /Source ref is not a valid full Git ref/u,
    );
    await assert.rejects(
      generateArtifactManifest(manifestOptions(fixture, { sourceRef: "refs/heads/stale", githubRunId: "123" })),
      /resolves to .* not current HEAD/u,
    );
    await assert.rejects(
      generateArtifactManifest(manifestOptions(fixture, { sourceRef: "refs/heads/main", githubRunId: "0" })),
      /GitHub run ID must be a positive decimal integer/u,
    );
  }, { platform: "windows-x86_64" });
});

test("rejects unsupported or filename-incompatible platforms", async () => {
  await useFixture(async (fixture) => {
    await assert.rejects(
      generateArtifactManifest(manifestOptions(fixture, { platform: "linux-x86_64" })),
      /Unsupported platform/u,
    );
    await assert.rejects(
      generateArtifactManifest(manifestOptions(fixture, { platform: "windows-x86_64" })),
      /Artifact path must be .*SeeYouAtTheHive-Windows\.exe/u,
    );
  });
});

test("rejects artifacts outside the fixed builds path and symbolic-link artifacts", async () => {
  await useFixture(async (fixture) => {
    const outsidePath = join(fixture.root, macFilename);
    await writeFile(outsidePath, fixture.artifactBytes);
    await assert.rejects(
      generateArtifactManifest(manifestOptions(fixture, { artifactPath: outsidePath })),
      /Artifact path must be/u,
    );

    await rm(fixture.artifactPath);
    await symlink(outsidePath, fixture.artifactPath);
    await assert.rejects(generateArtifactManifest(manifestOptions(fixture)), /Artifact must be a regular file/u);
  });
});
