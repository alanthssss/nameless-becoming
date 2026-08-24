import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { fileURLToPath } from "node:url";

const script = fileURLToPath(new URL("../scripts/generate_build_provenance.mjs", import.meta.url));
const fixtureCommit = "0123456789abcdef0123456789abcdef01234567";

test("build provenance contains the product version and commit without a branch name", async () => {
  const directory = await mkdtemp(join(tmpdir(), "nameless-provenance-"));
  const output = join(directory, "build_provenance.json");
  try {
    const result = spawnSync(process.execPath, [script], {
      encoding: "utf8",
      env: {
        ...process.env,
        NAMELESS_BUILD_COMMIT: fixtureCommit,
        NAMELESS_BUILD_DIRTY: "false",
        NAMELESS_BUILD_INFO_PATH: output,
      },
    });
    assert.equal(result.status, 0, result.stderr);
    const provenance = JSON.parse(await readFile(output, "utf8"));
    assert.deepEqual(provenance, {
      schema_version: 1,
      product_version: "0.9.5-rc.2",
      commit: fixtureCommit,
      dirty: false,
    });
    assert.equal(Object.hasOwn(provenance, "branch"), false);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("build provenance marks a build made from uncommitted work", async () => {
  const directory = await mkdtemp(join(tmpdir(), "nameless-provenance-dirty-"));
  const output = join(directory, "build_provenance.json");
  try {
    const result = spawnSync(process.execPath, [script], {
      encoding: "utf8",
      env: {
        ...process.env,
        NAMELESS_BUILD_COMMIT: fixtureCommit,
        NAMELESS_BUILD_DIRTY: "true",
        NAMELESS_BUILD_INFO_PATH: output,
      },
    });
    assert.equal(result.status, 0, result.stderr);
    const provenance = JSON.parse(await readFile(output, "utf8"));
    assert.equal(provenance.dirty, true);
    assert.match(result.stdout, /01234567\+dirty/);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("build provenance rejects a non-commit source identifier", () => {
  const result = spawnSync(process.execPath, [script], {
    encoding: "utf8",
    env: {
      ...process.env,
      NAMELESS_BUILD_COMMIT: "codex/player-feedback-v2",
    },
  });
  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /hexadecimal Git object ID/);
});
