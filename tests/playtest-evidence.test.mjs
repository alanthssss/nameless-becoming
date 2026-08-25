import assert from "node:assert/strict";
import { execFile, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { access, mkdir, mkdtemp, readFile, readdir, realpath, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";

import {
  buildEvidencePayload,
  buildObserverPayload,
  generatePlaytestEvidence,
  parseArguments,
  readArtifactIdentity,
  readCandidateIdentity,
  readPlaytestSliceCatalog,
  readProductIdentity,
  validateEvadeRetestAnswers,
} from "../scripts/prepare_playtest_evidence.mjs";

const execFileAsync = promisify(execFile);
const repositoryRoot = new URL("../", import.meta.url);
const repositoryPath = fileURLToPath(repositoryRoot);
const scriptPath = fileURLToPath(new URL("../scripts/prepare_playtest_evidence.mjs", import.meta.url));
const fixedSessionId = "NB-20260825-TEST0001";
const artifactFilename = "NamelessBecoming-Windows.exe";
const legacyArtifactSha256 = "a".repeat(64);

function sha256(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}

async function pathDoesNotExist(path) {
  try { await access(path); return false; } catch (error) {
    if (error?.code === "ENOENT") return true;
    throw error;
  }
}

async function writeArtifactFixture(directory, { commit, version, artifactBytes = Buffer.from("fixed distribution bytes\n"), manifestOverrides = {}, sourceMetadata = false } = {}) {
  await mkdir(directory, { recursive: true });
  const artifactPath = join(directory, artifactFilename);
  await writeFile(artifactPath, artifactBytes);
  const manifest = {
    schema_version: 1,
    product_version: version,
    commit,
    dirty: false,
    platform: "windows-x86_64",
    filename: artifactFilename,
    size: artifactBytes.byteLength,
    sha256: sha256(artifactBytes),
    ...(sourceMetadata ? { source_ref: "refs/heads/main", github_run_id: "32844593593" } : {}),
    ...manifestOverrides,
  };
  const manifestBytes = Buffer.from(`${JSON.stringify(manifest, null, 2)}\n`);
  const artifactManifestPath = `${artifactPath}.manifest.json`;
  await writeFile(artifactManifestPath, manifestBytes);
  return { artifactPath, artifactManifestPath, artifactBytes, manifest, manifestBytes };
}

function git(root, args) {
  return spawnSync("git", args, { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
}

async function createSliceRepositoryFixture(temporaryRoot, catalog, { copyCli = false, sourceMetadata = false } = {}) {
  const root = join(temporaryRoot, "repository");
  await mkdir(join(root, "godot/data"), { recursive: true });
  await writeFile(join(root, "package.json"), '{"version":"0.9.5-rc.2"}\n', "utf8");
  const catalogBytes = Buffer.from(`${JSON.stringify(catalog, null, 2)}\n`);
  await writeFile(join(root, "godot/data/playtest_slices.json"), catalogBytes);
  if (copyCli) {
    await mkdir(join(root, "scripts"), { recursive: true });
    await writeFile(join(root, "scripts/prepare_playtest_evidence.mjs"), await readFile(scriptPath));
  }
  assert.equal(git(root, ["init", "--initial-branch=main"]).status, 0);
  assert.equal(git(root, ["config", "user.name", "Playtest Evidence Test"]).status, 0);
  assert.equal(git(root, ["config", "user.email", "playtest@example.invalid"]).status, 0);
  assert.equal(git(root, ["add", "."]).status, 0);
  assert.equal(git(root, ["-c", "commit.gpgsign=false", "commit", "-m", "fixture"]).status, 0);
  const commitResult = git(root, ["rev-parse", "HEAD"]);
  assert.equal(commitResult.status, 0);
  const commit = commitResult.stdout.trim();
  const distribution = await writeArtifactFixture(join(temporaryRoot, "distribution"), {
    commit,
    version: "0.9.5-rc.2",
    sourceMetadata,
  });
  return { root, commit, catalogBytes, ...distribution };
}

async function readParticipantTree(directory) {
  const files = [];
  const pending = [directory];
  while (pending.length > 0) {
    const current = pending.pop();
    for (const entry of await readdir(current, { withFileTypes: true })) {
      const path = join(current, entry.name);
      if (entry.isDirectory()) pending.push(path);
      else files.push({ path, text: await readFile(path, "utf8") });
    }
  }
  return files;
}

test("takes generator version and source identity from the current checkout", async () => {
  const identity = await readProductIdentity();
  const packageJson = JSON.parse(await readFile(new URL("package.json", repositoryRoot), "utf8"));
  const { stdout } = await execFileAsync("git", ["rev-parse", "HEAD"], { cwd: repositoryPath });
  const { stdout: statusOutput } = await execFileAsync("git", ["status", "--porcelain=v1", "--untracked-files=normal"], { cwd: repositoryPath });
  assert.equal(identity.name, "无名：成蜂");
  assert.equal(identity.version, packageJson.version);
  assert.equal(identity.full_commit, stdout.trim());
  assert.equal(identity.commit, stdout.trim().slice(0, 8));
  assert.equal(identity.dirty, statusOutput.trim().length > 0);
});

test("keeps the legacy identity reader available without using it for package identity", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-candidate-identity-"));
  try {
    assert.equal(git(temporaryRoot, ["init", "--initial-branch=main"]).status, 0);
    assert.equal(git(temporaryRoot, ["config", "user.email", "test@example.invalid"]).status, 0);
    assert.equal(git(temporaryRoot, ["config", "user.name", "Test"]).status, 0);
    await writeFile(join(temporaryRoot, "package.json"), '{"version":"0.9.5-rc.1"}\n');
    assert.equal(git(temporaryRoot, ["add", "package.json"]).status, 0);
    assert.equal(git(temporaryRoot, ["-c", "commit.gpgsign=false", "commit", "-m", "old"]).status, 0);
    const oldCommit = git(temporaryRoot, ["rev-parse", "HEAD"]).stdout.trim();
    await writeFile(join(temporaryRoot, "package.json"), '{"version":"0.9.5-rc.2"}\n');
    assert.equal(git(temporaryRoot, ["add", "package.json"]).status, 0);
    assert.equal(git(temporaryRoot, ["-c", "commit.gpgsign=false", "commit", "-m", "new"]).status, 0);
    const identity = await readCandidateIdentity(oldCommit.slice(0, 8), temporaryRoot);
    assert.equal(identity.version, "0.9.5-rc.1");
    assert.equal(identity.full_commit, oldCommit);
    await assert.rejects(readCandidateIdentity("deadbeef", temporaryRoot));
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

test("separates the six-item participant export from coordinator observation", () => {
  const artifactSha256 = "a".repeat(64);
  const product = { name: "无名：成蜂", version: "0.9.5-rc.2", commit: "f57ea02c", full_commit: "f".repeat(40), dirty: false, artifact_sha256: artifactSha256 };
  const task = { code: "A", assignment: "首次体验：首节点", maximum_minutes: 15 };
  const participant = { participant_code: fixedSessionId, tester_relation: "external_player" };
  const participantPayload = buildEvidencePayload({
    product, task, sessionId: fixedSessionId, participant,
    answers: {
      first_minute_quote: "我先飞向最近的花。",
      furthest_reached_quote: "到了一个大虫子前。",
      stuck_or_surprised_quote: "不知道什么时候结束。",
      player_summary_quote: "飞来飞去收集东西。",
      end_reason: "stuck",
      replay_intent: "after_changes",
      contact_moment_3: "completed_game_prompt",
    },
    exportedAt: "2026-08-25T00:00:00.000Z",
  });
  assert.equal(participantPayload.schema_version, 2);
  assert.equal(participantPayload.export_kind, "participant_short_form");
  assert.equal(participantPayload.evidence.tester_relation, "external_player");
  assert.equal(participantPayload.evidence.relation_asserted_by, "coordinator_at_generation");
  assert.deepEqual(Object.keys(participantPayload.verbatim_responses), ["first_minute_quote", "furthest_reached_quote", "stuck_or_surprised_quote", "player_summary_quote"]);
  assert.equal(Object.hasOwn(participantPayload, "timeline"), false);
  assert.equal(Object.hasOwn(participantPayload, "contacts"), false);

  const observerPayload = buildObserverPayload({
    product, task, sessionId: fixedSessionId, participant,
    answers: {
      evidence_channel: "onsite_observation",
      platform: "windows",
      windows_environment: "native_physical_hardware",
      input_methods: ["keyboard_mouse"],
      prior_external_explanation: "none",
      contact_moment_3: "attempted_incomplete",
      observation_moment_3: "蜂身有变化，未碰到另一朵花。",
      evade_retest_opportunity: "provided_stable",
      evade_retest_result: "attempted_incomplete",
      evade_retest_observation: "首次急转后三分钟出现同语法危险，玩家尝试一次但仍在线内。",
    },
    events: { event_1: { status: "occurred_timed", elapsed_seconds: 83.4 }, event_2: { status: "not_observed" } },
    sessionDurationSeconds: 614.6, sessionDurationStatus: "recorded", exportedAt: "2026-08-25T00:00:00.000Z",
  });
  assert.equal(observerPayload.export_kind, "coordinator_observation");
  assert.equal(observerPayload.timeline.events.event_1.elapsed_seconds, 83);
  assert.equal(observerPayload.timeline.events.event_2.status, "not_observed");
  assert.equal(observerPayload.contacts.moment_3, "attempted_incomplete");
  assert.equal(observerPayload.objective_observations.moment_3, "蜂身有变化，未碰到另一朵花。");
  assert.equal(observerPayload.evidence.prior_external_explanation, "none");
  assert.deepEqual(observerPayload.learning_transfer.evade_delayed_retest, {
    opportunity: "provided_stable",
    result: "attempted_incomplete",
    objective_observation: "首次急转后三分钟出现同语法危险，玩家尝试一次但仍在线内。",
  });
});

test("only evaluates delayed evade transfer when a stable opportunity has a result", () => {
  assert.equal(validateEvadeRetestAnswers({ evade_retest_opportunity: "provided_stable", evade_retest_result: "completed_independent" }), "");
  assert.match(validateEvadeRetestAnswers({ evade_retest_opportunity: "provided_stable", evade_retest_result: "not_evaluable" }), /记录实际结果/);
  assert.equal(validateEvadeRetestAnswers({ evade_retest_opportunity: "not_provided", evade_retest_result: "not_evaluable" }), "");
  assert.match(validateEvadeRetestAnswers({ evade_retest_opportunity: "not_provided", evade_retest_result: "attempted_incomplete" }), /必须选不可判定/);
});

test("strictly parses both A and B CLI contracts and rejects unknown or duplicate flags", () => {
  assert.deepEqual(parseArguments([
    "--task", "B", "--slice", "B01", "--tester-relation", "external_player",
    "--artifact", "/tmp/game.exe", "--artifact-manifest", "/tmp/game.exe.manifest.json", "--output", "/tmp/out",
  ]), {
    taskCode: "B",
    sliceCode: "B01",
    testerRelation: "external_player",
    artifactPath: "/tmp/game.exe",
    artifactManifestPath: "/tmp/game.exe.manifest.json",
    outputDirectory: "/tmp/out",
  });
  assert.deepEqual(parseArguments([
    "--task", "A", "--tester-relation", "external_player", "--artifact-sha256", legacyArtifactSha256,
    "--candidate-commit", "f".repeat(40), "--candidate-clean",
  ]), {
    taskCode: "A",
    testerRelation: "external_player",
    artifactSha256: legacyArtifactSha256,
    candidateCommit: "f".repeat(40),
    candidateClean: true,
  });
  assert.throws(() => parseArguments(["--mystery", "x"]), /Unknown argument/u);
  assert.throws(() => parseArguments(["--slice", "B01", "--slice", "B01"]), /only be provided once/u);
  assert.throws(() => parseArguments(["--candidate-clean", "--candidate-clean"]), /only be provided once/u);
  assert.throws(() => parseArguments(["--artifact"]), /requires a value/u);
  assert.throws(() => parseArguments(["--task", "B", "--artifact-sha256", legacyArtifactSha256]), /rejects legacy argument --artifact-sha256/u);
  assert.throws(() => parseArguments(["--candidate-dirty", "--task", "B"]), /rejects legacy argument --candidate-dirty/u);
});

test("keeps the A CLI artifact SHA environment fallback", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-playtest-a-cli-"));
  try {
    const output = join(temporaryRoot, "package");
    const result = spawnSync(process.execPath, [
      await realpath(scriptPath),
      "--task", "A",
      "--tester-relation", "external_player",
      "--output", output,
    ], { encoding: "utf8", env: { ...process.env, NAMELESS_PLAYTEST_ARTIFACT_SHA256: legacyArtifactSha256 } });
    assert.equal(result.status, 0, result.stderr);
    const manifest = JSON.parse(await readFile(join(output, "coordinator/manifest.json"), "utf8"));
    assert.equal(manifest.candidate.artifact_sha256, legacyArtifactSha256);
    assert.equal(Object.hasOwn(manifest, "artifact"), false);
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

test("derives candidate identity only from a strict schema v1 manifest and actual distribution bytes", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-playtest-artifact-"));
  try {
    const generator = await readProductIdentity();
    const fixture = await writeArtifactFixture(temporaryRoot, {
      commit: generator.full_commit,
      version: generator.version,
      sourceMetadata: true,
    });
    const identity = await readArtifactIdentity({
      artifactPath: fixture.artifactPath,
      artifactManifestPath: fixture.artifactManifestPath,
    });
    await assert.rejects(readArtifactIdentity({ artifactPath: artifactFilename, artifactManifestPath: fixture.artifactManifestPath }), /--artifact must be an absolute path/u);
    await assert.rejects(readArtifactIdentity({ artifactPath: fixture.artifactPath, artifactManifestPath: `${artifactFilename}.manifest.json` }), /--artifact-manifest must be an absolute path/u);
    assert.deepEqual(identity.product, {
      name: "无名：成蜂",
      version: generator.version,
      commit: generator.full_commit.slice(0, 8),
      full_commit: generator.full_commit,
      dirty: false,
      artifact_sha256: sha256(fixture.artifactBytes),
    });
    assert.deepEqual(identity.artifact, {
      platform: "windows-x86_64",
      filename: artifactFilename,
      size: fixture.artifactBytes.byteLength,
      sha256: sha256(fixture.artifactBytes),
      manifest_sha256: sha256(fixture.manifestBytes),
    });

    await writeFile(fixture.artifactPath, Buffer.from("tampered distribution!\n"));
    await assert.rejects(readArtifactIdentity({ artifactPath: fixture.artifactPath, artifactManifestPath: fixture.artifactManifestPath }), /Artifact (?:size|SHA-256)/u);

    const extra = await writeArtifactFixture(join(temporaryRoot, "extra"), {
      commit: generator.full_commit,
      version: generator.version,
      manifestOverrides: { unexpected: true },
    });
    await assert.rejects(readArtifactIdentity({ artifactPath: extra.artifactPath, artifactManifestPath: extra.artifactManifestPath }), /exactly the schema v1 core keys/u);

    const dirty = await writeArtifactFixture(join(temporaryRoot, "dirty"), {
      commit: generator.full_commit,
      version: generator.version,
      manifestOverrides: { dirty: true },
    });
    await assert.rejects(readArtifactIdentity({ artifactPath: dirty.artifactPath, artifactManifestPath: dirty.artifactManifestPath }), /dirty must be false/u);

    const wrongVersion = await writeArtifactFixture(join(temporaryRoot, "wrong-version"), {
      commit: generator.full_commit,
      version: "999.0.0",
    });
    await assert.rejects(readArtifactIdentity({ artifactPath: wrongVersion.artifactPath, artifactManifestPath: wrongVersion.artifactManifestPath }), /does not match package\.json version/u);
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

test("keeps the A participant form, observer split, and overwrite protections", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-playtest-a-"));
  const output = join(temporaryRoot, "package");
  try {
    const generator = await readProductIdentity();
    const options = {
      artifactSha256: legacyArtifactSha256,
      taskCode: "A",
      testerRelation: "external_player",
      candidateCommit: generator.full_commit,
      candidateDirty: false,
      sessionId: fixedSessionId,
    };
    await generatePlaytestEvidence(output, options);
    assert.equal(await readFile(join(output, ".nameless-playtest-evidence"), "utf8"), "nameless-playtest-evidence:v2\n");
    const participantAssets = await Promise.all([
      readFile(join(output, "participant", "index.html"), "utf8"),
      readFile(join(output, "participant", "styles.css"), "utf8"),
      readFile(join(output, "participant", "review.js"), "utf8"),
    ]);
    const participantText = participantAssets.join("\n");
    const participantHtml = participantAssets[0];
    const observerHtml = await readFile(join(output, "coordinator", "observer.html"), "utf8");
    const coordinatorText = await readFile(join(output, "coordinator", "README.md"), "utf8");
    const analysis = JSON.parse(await readFile(join(output, "coordinator", "analysis-template.json"), "utf8"));
    const manifest = JSON.parse(await readFile(join(output, "coordinator", "manifest.json"), "utf8"));
    await execFileAsync(process.execPath, ["--check", join(output, "participant", "review.js")]);
    await execFileAsync(process.execPath, ["--check", join(output, "coordinator", "observer.js")]);

    assert.equal((participantHtml.match(/<(?:input|select|textarea)[^>]*\sname="/gu) || []).length, 6);
    assert.doesNotMatch(participantText, /contact_|event_[1-4]|observation_|完成条件|传粉|急转|饮蜜|第一次交蜜|游戏内提示/iu);
    assert.doesNotMatch(participantHtml, /<select name="tester_relation"|evidence_channel|windows_environment|input_methods/u);
    assert.doesNotMatch(participantText, /https?:\/\//iu);
    assert.doesNotMatch(participantText, /\b(?:fetch|XMLHttpRequest|sendBeacon|WebSocket)\b/u);
    assert.match(participantHtml, /六项，写完就结束/);
    assert.match(participantHtml, /没有标准答案/);
    assert.match(observerHtml, /机制接触判定/);
    assert.match(observerHtml, /完成条件|传粉|急转|饮蜜/u);
    assert.match(observerHtml, /name="prior_external_explanation"/u);
    assert.match(observerHtml, /name="evade_retest_opportunity"/u);
    assert.match(observerHtml, /name="evade_retest_result"/u);
    assert.match(observerHtml, /机会与结果必须分开/u);
    assert.match(coordinatorText, /4 个原话题和 2 个结束选择/);
    assert.match(coordinatorText, /provided_stable/u);
    assert.equal((coordinatorText.match(/不收姓名/gu) || []).length, 1);
    assert.equal(analysis.participant_identity.tester_relation, "external_player");
    assert.equal(analysis.relation_asserted_at_generation, true);
    assert.equal(analysis.relation_verified_by_coordinator, null);
    assert.equal(analysis.protocol_verification.prior_external_explanation, null);
    assert.equal(analysis.evade_delayed_retest_assessment.opportunity, null);
    assert.match(analysis.evade_delayed_retest_assessment.analyst_note, /不能记为迁移失败/u);
    assert.equal(manifest.observer_entry, "observer.html");
    assert.equal(manifest.participant_identity.tester_relation, "external_player");
    assert.equal(manifest.candidate.full_commit, generator.full_commit);
    assert.equal(manifest.candidate.dirty, false);
    assert.equal(Object.hasOwn(manifest, "artifact"), false);
    assert.deepEqual((await readdir(join(output, "participant"))).sort(), ["index.html", "review.js", "styles.css"]);
    assert.equal(await pathDoesNotExist(join(output, "coordinator", "artifact-manifest.json")), true);
    assert.equal(await pathDoesNotExist(join(output, "participant", "playtest-ticket.json")), true);

    await generatePlaytestEvidence(output, options);
    assert.equal(JSON.parse(await readFile(join(output, "coordinator", "manifest.json"), "utf8")).session_id, fixedSessionId);
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

test("preserves A provenance semantics and protects unrelated output targets", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-playtest-safety-"));
  const unrelated = join(temporaryRoot, "existing-project");
  const repositoryLink = join(temporaryRoot, "repository-link");
  const legacyOutput = join(temporaryRoot, "legacy-v1-package");
  await mkdir(unrelated);
  await writeFile(join(unrelated, "keep.txt"), "keep\n");
  await mkdir(legacyOutput);
  await writeFile(join(legacyOutput, ".nameless-playtest-evidence"), "nameless-playtest-evidence:v1\n");
  await writeFile(join(legacyOutput, "keep.txt"), "legacy\n");
  await symlink(repositoryPath, repositoryLink);
  try {
    const generator = await readProductIdentity();
    const fixedOptions = {
      artifactSha256: legacyArtifactSha256,
      taskCode: "A",
      testerRelation: "external_player",
      candidateCommit: generator.full_commit,
      candidateDirty: false,
      sessionId: fixedSessionId,
    };
    await assert.rejects(generatePlaytestEvidence(join(temporaryRoot, "missing-hash"), { testerRelation: "external_player" }), /64-character --artifact-sha256/u);
    await assert.rejects(generatePlaytestEvidence(join(temporaryRoot, "missing-relation"), { artifactSha256: legacyArtifactSha256 }), /--tester-relation/u);
    await assert.rejects(generatePlaytestEvidence(join(temporaryRoot, "bad-relation"), { artifactSha256: legacyArtifactSha256, testerRelation: "external_player_self_selected" }), /--tester-relation/u);
    await assert.rejects(generatePlaytestEvidence(join(temporaryRoot, "task-c"), { artifactSha256: legacyArtifactSha256, testerRelation: "external_player", taskCode: "C" }), /npm run audio:review/u);
    await assert.rejects(generatePlaytestEvidence(join(temporaryRoot, "slice-on-a"), { ...fixedOptions, sliceCode: "B01" }), /only valid with --task B/u);
    await assert.rejects(generatePlaytestEvidence(join(temporaryRoot, "implicit-clean"), { artifactSha256: legacyArtifactSha256, testerRelation: "external_player", candidateCommit: generator.full_commit }), /requires exactly one of --candidate-clean or --candidate-dirty/u);
    await assert.rejects(generatePlaytestEvidence(join(temporaryRoot, "missing-commit"), { artifactSha256: legacyArtifactSha256, testerRelation: "external_player", candidateCommit: "deadbeef", candidateDirty: false }));
    await assert.rejects(generatePlaytestEvidence(repositoryPath, fixedOptions), /repository or one of its ancestors/u);
    await assert.rejects(generatePlaytestEvidence(dirname(repositoryPath), fixedOptions), /repository or one of its ancestors/u);
    await assert.rejects(generatePlaytestEvidence(join(repositoryPath, "docs/generated"), fixedOptions), /must stay under outputs/u);
    await assert.rejects(generatePlaytestEvidence(join(repositoryLink, "docs/generated"), fixedOptions), /must stay under outputs/u);
    await assert.rejects(generatePlaytestEvidence(unrelated, fixedOptions), /without \.nameless-playtest-evidence/u);
    await assert.rejects(generatePlaytestEvidence(legacyOutput, fixedOptions), /invalid \.nameless-playtest-evidence/u);
    assert.equal(await readFile(join(unrelated, "keep.txt"), "utf8"), "keep\n");
    assert.equal(await readFile(join(legacyOutput, "keep.txt"), "utf8"), "legacy\n");

    const dirtyOutput = join(temporaryRoot, "dirty-candidate");
    const dirtyResult = await generatePlaytestEvidence(dirtyOutput, { ...fixedOptions, candidateDirty: true });
    assert.equal(dirtyResult.product.dirty, true);
    assert.match(await readFile(join(dirtyOutput, "participant", "index.html"), "utf8"), new RegExp(`${generator.commit} \\+dirty`));
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

test("reads the exact committed slice catalog, rejects schema drift, and blocks B01 before output", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-playtest-blocked-b-"));
  const blockedCatalog = {
    schema_version: 1,
    slices: [{ code: "B01", assignment: "固定切片 B01", maximum_minutes: 10, status: "blocked" }],
  };
  try {
    const fixture = await createSliceRepositoryFixture(temporaryRoot, blockedCatalog);
    const catalog = await readPlaytestSliceCatalog(fixture.commit, fixture.root);
    assert.deepEqual(catalog.rawBytes, fixture.catalogBytes);
    assert.equal(catalog.sha256, sha256(fixture.catalogBytes));

    const output = join(temporaryRoot, "must-not-exist");
    const bOptions = {
      repositoryRoot: fixture.root,
      artifactPath: fixture.artifactPath,
      artifactManifestPath: fixture.artifactManifestPath,
      taskCode: "B",
      sliceCode: "B01",
      testerRelation: "external_player",
      sessionId: fixedSessionId,
    };
    for (const legacy of [
      { artifactSha256: legacyArtifactSha256 },
      { candidateCommit: fixture.commit },
      { candidateClean: true },
      { candidateDirty: false },
    ]) {
      await assert.rejects(generatePlaytestEvidence(output, { ...bOptions, ...legacy }), /Task B rejects legacy identity option/u);
    }
    await assert.rejects(generatePlaytestEvidence(output, bOptions), /B01 is blocked.*no evidence package was written/u);
    assert.equal(await pathDoesNotExist(output), true);

    const invalidRoot = await mkdtemp(join(tmpdir(), "nameless-playtest-invalid-catalog-"));
    try {
      const invalid = await createSliceRepositoryFixture(invalidRoot, { ...blockedCatalog, unexpected: true });
      await assert.rejects(readPlaytestSliceCatalog(invalid.commit, invalid.root), /must contain exactly/u);
    } finally {
      await rm(invalidRoot, { recursive: true, force: true });
    }

    const duplicateRoot = await mkdtemp(join(tmpdir(), "nameless-playtest-duplicate-catalog-"));
    try {
      const duplicate = await createSliceRepositoryFixture(duplicateRoot, {
        schema_version: 1,
        slices: [blockedCatalog.slices[0], blockedCatalog.slices[0]],
      });
      await assert.rejects(readPlaytestSliceCatalog(duplicate.commit, duplicate.root), /duplicate code B01/u);
    } finally {
      await rm(duplicateRoot, { recursive: true, force: true });
    }
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

test("the blocked B01 CLI exits nonzero and writes no output", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-playtest-blocked-cli-"));
  try {
    const fixture = await createSliceRepositoryFixture(temporaryRoot, {
      schema_version: 1,
      slices: [{ code: "B01", assignment: "固定切片 B01", maximum_minutes: 10, status: "blocked" }],
    }, { copyCli: true });
    const output = join(temporaryRoot, "cli-output");
    const result = spawnSync(process.execPath, [
      await realpath(join(fixture.root, "scripts/prepare_playtest_evidence.mjs")),
      "--task", "B",
      "--slice", "B01",
      "--tester-relation", "external_player",
      "--artifact", fixture.artifactPath,
      "--artifact-manifest", fixture.artifactManifestPath,
      "--output", output,
    ], { encoding: "utf8" });
    assert.equal(result.status, 1, result.stderr);
    assert.match(result.stderr, /B01 is blocked.*no evidence package was written/u);
    assert.equal(await pathDoesNotExist(output), true);

    const environmentResult = spawnSync(process.execPath, [
      await realpath(join(fixture.root, "scripts/prepare_playtest_evidence.mjs")),
      "--task", "B",
      "--slice", "B01",
      "--tester-relation", "external_player",
      "--artifact", fixture.artifactPath,
      "--artifact-manifest", fixture.artifactManifestPath,
      "--output", join(temporaryRoot, "env-output"),
    ], { encoding: "utf8", env: { ...process.env, NAMELESS_PLAYTEST_ARTIFACT_SHA256: legacyArtifactSha256 } });
    assert.equal(environmentResult.status, 1, environmentResult.stderr);
    assert.match(environmentResult.stderr, /Task B rejects legacy identity option artifactSha256FromEnvironment/u);
    assert.equal(await pathDoesNotExist(join(temporaryRoot, "env-output")), true);
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

test("a ready B01 emits an exact ticket, raw manifest, and recursively blind participant package", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-playtest-ready-b-"));
  try {
    const fixture = await createSliceRepositoryFixture(temporaryRoot, {
      schema_version: 1,
      slices: [{ code: "B01", assignment: "固定切片 B01", maximum_minutes: 10, status: "ready" }],
    }, { sourceMetadata: true });
    const output = join(temporaryRoot, "package");
    const result = await generatePlaytestEvidence(output, {
      repositoryRoot: fixture.root,
      artifactPath: fixture.artifactPath,
      artifactManifestPath: fixture.artifactManifestPath,
      taskCode: "B",
      sliceCode: "B01",
      testerRelation: "external_player",
      sessionId: fixedSessionId,
    });
    assert.deepEqual(result.task, {
      code: "B",
      slice_code: "B01",
      assignment: "固定切片 B01",
      internal_assignment: "",
      maximum_minutes: 10,
    });
    assert.deepEqual(await readFile(join(output, "participant/artifact-manifest.json")), fixture.manifestBytes);
    const ticket = JSON.parse(await readFile(join(output, "participant/playtest-ticket.json"), "utf8"));
    assert.deepEqual(ticket, {
      schema_version: 1,
      session_id: fixedSessionId,
      task: { code: "B", slice_code: "B01" },
      product: {
        id: "nameless-becoming",
        display_name: "无名：成蜂",
        version: "0.9.5-rc.2",
        commit: fixture.commit,
        dirty: false,
      },
      artifact: {
        platform: "windows-x86_64",
        filename: artifactFilename,
        size: fixture.artifactBytes.byteLength,
        sha256: sha256(fixture.artifactBytes),
        manifest_sha256: sha256(fixture.manifestBytes),
      },
      catalog_sha256: sha256(fixture.catalogBytes),
    });
    assert.deepEqual(Object.keys(ticket).sort(), ["artifact", "catalog_sha256", "product", "schema_version", "session_id", "task"]);
    assert.deepEqual(Object.keys(ticket.task).sort(), ["code", "slice_code"]);
    assert.deepEqual(Object.keys(ticket.product).sort(), ["commit", "dirty", "display_name", "id", "version"]);
    assert.deepEqual(Object.keys(ticket.artifact).sort(), ["filename", "manifest_sha256", "platform", "sha256", "size"]);

    const participantFiles = await readParticipantTree(join(output, "participant"));
    const participantText = participantFiles.map(({ path, text }) => `${path}\n${text}`).join("\n");
    assert.match(participantText, /固定切片 B01/u);
    assert.match(participantText, /10 分钟/u);
    assert.match(participantText, /"<游戏可执行文件的绝对路径>" -- "--playtest-ticket=<playtest-ticket\.json 的绝对路径>"/u);
    assert.doesNotMatch(participantText, /完成条件|传粉|授粉|急转|饮蜜|交蜜|采蜜/iu);
    assert.doesNotMatch(participantText, /\b(?:pollination|evade|nectar|deposit|handler|profile|observer)\b/iu);
    assert.doesNotMatch(participantText, /contact_|event_[1-4]|observation_|evidence_channel|windows_environment|input_methods|prior_external_explanation|timeline|contacts|objective_observations|learning_transfer|help_request_quote|evade_retest|internal_assignment/iu);
    assert.doesNotMatch(participantText, /answer_key|answer_explanation|expected_answer|expected_result|success_condition|success_criteria|正确答案|答案说明/iu);
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});
