import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { mkdtemp, mkdir, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";

import {
  buildEvidencePayload,
  buildObserverPayload,
  generatePlaytestEvidence,
  readCandidateIdentity,
  readProductIdentity,
} from "../scripts/prepare_playtest_evidence.mjs";

const execFileAsync = promisify(execFile);
const repositoryRoot = new URL("../", import.meta.url);
const repositoryPath = fileURLToPath(repositoryRoot);
const artifactSha256 = "a".repeat(64);
const fixedSessionId = "NB-20260825-TEST0001";

test("resolves candidate identity from the exact commit", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-candidate-identity-"));
  try {
    await execFileAsync("git", ["init", "--quiet"], { cwd: temporaryRoot });
    await execFileAsync("git", ["config", "user.email", "test@example.invalid"], { cwd: temporaryRoot });
    await execFileAsync("git", ["config", "user.name", "Test"], { cwd: temporaryRoot });
    await writeFile(join(temporaryRoot, "package.json"), '{"version":"0.9.5-rc.1"}\n');
    await execFileAsync("git", ["add", "package.json"], { cwd: temporaryRoot });
    await execFileAsync("git", ["-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "old"], { cwd: temporaryRoot });
    const oldCommit = (await execFileAsync("git", ["rev-parse", "HEAD"], { cwd: temporaryRoot })).stdout.trim();
    await writeFile(join(temporaryRoot, "package.json"), '{"version":"0.9.5-rc.2"}\n');
    await execFileAsync("git", ["add", "package.json"], { cwd: temporaryRoot });
    await execFileAsync("git", ["-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "new"], { cwd: temporaryRoot });
    const identity = await readCandidateIdentity(oldCommit.slice(0, 8), temporaryRoot);
    assert.equal(identity.version, "0.9.5-rc.1");
    assert.equal(identity.full_commit, oldCommit);
    await assert.rejects(readCandidateIdentity("deadbeef", temporaryRoot));
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

test("separates the six-item participant export from coordinator observation", () => {
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
    answers: { evidence_channel: "onsite_observation", platform: "windows", windows_environment: "native_physical_hardware", input_methods: ["keyboard_mouse"], contact_moment_3: "attempted_incomplete", observation_moment_3: "蜂身有变化，未碰到另一朵花。" },
    events: { event_1: { status: "occurred_timed", elapsed_seconds: 83.4 }, event_2: { status: "not_observed" } },
    sessionDurationSeconds: 614.6, sessionDurationStatus: "recorded", exportedAt: "2026-08-25T00:00:00.000Z",
  });
  assert.equal(observerPayload.export_kind, "coordinator_observation");
  assert.equal(observerPayload.timeline.events.event_1.elapsed_seconds, 83);
  assert.equal(observerPayload.timeline.events.event_2.status, "not_observed");
  assert.equal(observerPayload.contacts.moment_3, "attempted_incomplete");
  assert.equal(observerPayload.objective_observations.moment_3, "蜂身有变化，未碰到另一朵花。");
});

test("generates a short blind participant form and a separate observer workflow", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-playtest-kit-"));
  const output = join(temporaryRoot, "package");
  try {
    const identity = await readProductIdentity();
    await generatePlaytestEvidence(output, { artifactSha256, taskCode: "A", testerRelation: "external_player", candidateCommit: identity.full_commit, candidateDirty: false, sessionId: fixedSessionId });
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

    assert.equal((participantHtml.match(/<(?:input|select|textarea)[^>]*\sname="/gu) || []).length, 6, "participant burden must stay at six controls");
    assert.doesNotMatch(participantText, /contact_|event_[1-4]|observation_|完成条件|传粉|急转|饮蜜|第一次交蜜|游戏内提示/iu);
    assert.doesNotMatch(participantHtml, /<select name="tester_relation"|evidence_channel|windows_environment|input_methods/u);
    assert.doesNotMatch(participantText, /https?:\/\//iu);
    assert.doesNotMatch(participantText, /\b(?:fetch|XMLHttpRequest|sendBeacon|WebSocket)\b/u);
    assert.match(participantHtml, /六项，写完就结束/);
    assert.match(observerHtml, /机制接触判定/);
    assert.match(observerHtml, /完成条件|传粉|急转|饮蜜/u);
    assert.match(coordinatorText, /4 个原话题和 2 个结束选择/);
    assert.equal(analysis.participant_identity.tester_relation, "external_player");
    assert.equal(analysis.relation_asserted_at_generation, true);
    assert.equal(analysis.relation_verified_by_coordinator, null);
    assert.equal(manifest.observer_entry, "observer.html");
    assert.equal(manifest.participant_identity.tester_relation, "external_player");
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

test("requires coordinator relation, blocks unavailable tasks, and protects outputs", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-playtest-safety-"));
  const unrelated = join(temporaryRoot, "existing-project");
  const repositoryLink = join(temporaryRoot, "repository-link");
  await mkdir(unrelated);
  await writeFile(join(unrelated, "keep.txt"), "keep\n");
  await symlink(repositoryPath, repositoryLink);
  try {
    await assert.rejects(generatePlaytestEvidence(join(temporaryRoot, "missing-relation"), { artifactSha256 }), /--tester-relation/);
    await assert.rejects(generatePlaytestEvidence(join(temporaryRoot, "bad-relation"), { artifactSha256, testerRelation: "external_player_self_selected" }), /--tester-relation/);
    await assert.rejects(generatePlaytestEvidence(join(temporaryRoot, "task-b"), { artifactSha256, testerRelation: "external_player", taskCode: "B" }), /Task B is blocked/);
    await assert.rejects(generatePlaytestEvidence(repositoryPath, { artifactSha256, testerRelation: "external_player" }), /repository or one of its ancestors/);
    await assert.rejects(generatePlaytestEvidence(join(repositoryLink, "docs/generated"), { artifactSha256, testerRelation: "external_player" }), /must stay under outputs/);
    await assert.rejects(generatePlaytestEvidence(unrelated, { artifactSha256, testerRelation: "external_player" }), /without \.nameless-playtest-evidence/);
    assert.equal(await readFile(join(unrelated, "keep.txt"), "utf8"), "keep\n");
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});
