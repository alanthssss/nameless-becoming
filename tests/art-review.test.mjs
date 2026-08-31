import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtemp, mkdir, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import test from "node:test";
import {
  documents, escapeHtml, gitIdentity, materialPaths, pngDimensions, readMaterial,
  redactLocalPaths, sha256, validateArtifact,
} from "../scripts/package_art_review.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const bytes = Buffer.from("candidate game bytes");
const identity = { commit: "a".repeat(40), product_version: "0.9.5-rc.2" };
const manifest = {
  schema_version: 1, ...identity, dirty: false, platform: "windows-x86_64",
  filename: "SeeYouAtTheHive-Windows.exe", size: bytes.length, sha256: sha256(bytes),
};

test("artifact identity includes bytes, version, full commit, platform and clean state", () => {
  assert.doesNotThrow(() => validateArtifact(manifest, bytes, identity, "windows-x86_64"));
  for (const change of [
    { schema_version: 2 }, { commit: "b".repeat(40) }, { dirty: true },
    { product_version: "0.1.0" }, { platform: "macos-universal" },
    { filename: "other.exe" }, { size: 1 }, { sha256: "0".repeat(64) },
  ]) assert.throws(() => validateArtifact({ ...manifest, ...change }, bytes, identity, "windows-x86_64"), /mismatch/u);
  assert.throws(() => validateArtifact(manifest, Buffer.from("tampered"), identity, "windows-x86_64"), /mismatch/u);
});

test("allowlist has exactly 21 runtime originals, 6 historical screenshots and no obsolete direction or secrets", async () => {
  assert.equal(new Set(materialPaths).size, materialPaths.length);
  assert.equal(materialPaths.filter((path) => path.startsWith("godot/assets/art/commercial/")).length, 21);
  assert.equal(materialPaths.filter((path) => /screenshots\/.+\.png$/u.test(path)).length, 6);
  assert.ok(documents.includes("docs/design/commercial-product-requirements.md"));
  assert.ok(!materialPaths.some((path) => /(?:\.env|\.git\/|saves\/|tests\/|visual-audio-direction|ART_IMPLEMENTATION_STANDARD|concepts\/)/u.test(path)));
  for (const path of materialPaths) {
    const data = await readFile(join(root, path));
    assert.ok(data.length > 0, path);
    if (path.endsWith(".png")) {
      const dimensions = pngDimensions(data);
      assert.ok(dimensions.width > 0 && dimensions.height > 0, path);
    }
  }
});

test("HTML escapes arbitrary document strings and local path redaction leaves asset IDs intact", () => {
  assert.equal(escapeHtml('<script a="x">&\'</script>'), "&lt;script a=&quot;x&quot;&gt;&amp;&#39;&lt;/script&gt;");
  const text = redactLocalPaths("源 `/Users/person/.codex/generated_images/a.png` 与 /home/person/private.png\n文件 player_bee.png");
  assert.ok(!text.includes("person"));
  assert.ok(text.includes("player_bee.png"));
  assert.throws(() => pngDimensions(Buffer.from("not png")), /PNG/u);
});

test("Git gate rejects dirty, staged and untracked files", async () => {
  const fixture = await mkdtemp(join(tmpdir(), "art-review-git-test-"));
  const git = (...args) => execFileSync("git", args, { cwd: fixture, stdio: "pipe" });
  try {
    git("init");
    git("config", "user.email", "test@example.invalid");
    git("config", "user.name", "Review Test");
    await writeFile(join(fixture, "tracked"), "one");
    git("add", "tracked");
    git("commit", "-m", "fixture");
    assert.equal(gitIdentity(fixture).dirty, false);
    await writeFile(join(fixture, "tracked"), "two");
    assert.throws(() => gitIdentity(fixture), /clean/u);
    git("add", "tracked");
    assert.throws(() => gitIdentity(fixture), /clean/u);
    git("commit", "-m", "second");
    await writeFile(join(fixture, "untracked"), "new");
    assert.throws(() => gitIdentity(fixture), /clean/u);
  } finally { await rm(fixture, { recursive: true, force: true }); }
});

test("material reads reject unlisted paths, untracked files and symlinks", async () => {
  const fixture = await mkdtemp(join(tmpdir(), "art-review-material-test-"));
  try {
    execFileSync("git", ["init"], { cwd: fixture, stdio: "pipe" });
    const path = "docs/ART_REVIEW_HANDOFF.md";
    await mkdir(join(fixture, "docs"));
    await writeFile(join(fixture, path), "review");
    await assert.rejects(readMaterial(fixture, "../secret"), /allowlisted/u);
    await assert.rejects(readMaterial(fixture, path));
    execFileSync("git", ["add", path], { cwd: fixture });
    assert.equal((await readMaterial(fixture, path)).toString(), "review");
    await rm(join(fixture, path));
    await symlink(join(root, "docs/ART_REVIEW_HANDOFF.md"), join(fixture, path));
    await assert.rejects(readMaterial(fixture, path), /non-symlink/u);
  } finally { await rm(fixture, { recursive: true, force: true }); }
});

test("workflow packages only after both platform builds, on immutable source, with restricted artifact output", async () => {
  const workflow = await readFile(join(root, ".github/workflows/desktop-build.yml"), "utf8");
  const job = workflow.split("  art-review:")[1].split("  prerelease:")[0];
  assert.match(job, /needs: \[macos, windows\]/u);
  assert.ok(job.includes("ref: ${{ github.sha }}"));
  assert.match(job, /retention-days: 30/u);
  assert.ok(job.includes("outputs/art-review/*/*.zip"));
  assert.match(job, /npm run art:package/u);
  assert.doesNotMatch(job, /contents: write|gh release|curl.*POST/u);
});
