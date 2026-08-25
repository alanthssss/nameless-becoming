import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { mkdtemp, mkdir, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";

import {
  buildEvidencePayload,
  generatePlaytestEvidence,
  readCandidateIdentity,
  readProductIdentity,
} from "../scripts/prepare_playtest_evidence.mjs";

const execFileAsync = promisify(execFile);
const repositoryRoot = new URL("../", import.meta.url);
const repositoryPath = fileURLToPath(repositoryRoot);
const artifactSha256 = "a".repeat(64);
const fixedSessionId = "NB-20260825-TEST0001";

test("takes product version and source identity from package.json and the current git checkout", async () => {
  const identity = await readProductIdentity();
  const packageJson = JSON.parse(await readFile(new URL("package.json", repositoryRoot), "utf8"));
  const { stdout: commitOutput } = await execFileAsync("git", ["rev-parse", "HEAD"], { cwd: repositoryPath });
  const { stdout: statusOutput } = await execFileAsync(
    "git",
    ["status", "--porcelain=v1", "--untracked-files=normal"],
    { cwd: repositoryPath },
  );

  assert.equal(identity.name, "无名：成蜂");
  assert.equal(identity.version, packageJson.version);
  assert.equal(identity.full_commit, commitOutput.trim());
  assert.equal(identity.commit, commitOutput.trim().slice(0, 8));
  assert.equal(identity.dirty, statusOutput.trim().length > 0);
});

test("resolves a candidate commit and reads the version from that exact snapshot", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-candidate-identity-"));
  try {
    await execFileAsync("git", ["init", "--quiet"], { cwd: temporaryRoot });
    await execFileAsync("git", ["config", "user.name", "Playtest Test"], { cwd: temporaryRoot });
    await execFileAsync("git", ["config", "user.email", "playtest-test@example.invalid"], { cwd: temporaryRoot });
    await writeFile(join(temporaryRoot, "package.json"), '{"version":"0.9.5-rc.1"}\n', "utf8");
    await execFileAsync("git", ["add", "package.json"], { cwd: temporaryRoot });
    await execFileAsync("git", ["-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "old candidate"], { cwd: temporaryRoot });
    const { stdout: oldCommitOutput } = await execFileAsync("git", ["rev-parse", "HEAD"], { cwd: temporaryRoot });
    const oldCommit = oldCommitOutput.trim();

    await writeFile(join(temporaryRoot, "package.json"), '{"version":"0.9.5-rc.2"}\n', "utf8");
    await execFileAsync("git", ["add", "package.json"], { cwd: temporaryRoot });
    await execFileAsync("git", ["-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "new candidate"], { cwd: temporaryRoot });

    const identity = await readCandidateIdentity(oldCommit.slice(0, 8), temporaryRoot);
    assert.equal(identity.version, "0.9.5-rc.1");
    assert.equal(identity.full_commit, oldCommit);
    assert.equal(identity.commit, oldCommit.slice(0, 8));
    await assert.rejects(readCandidateIdentity("deadbeef", temporaryRoot));
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

test("builds the documented anonymous export shape without mixing analysis into player evidence", () => {
  const payload = buildEvidencePayload({
    product: {
      name: "无名：成蜂",
      version: "0.9.5-rc.2",
      commit: "11111111",
      full_commit: "1".repeat(40),
      dirty: false,
      artifact_sha256: artifactSha256,
    },
    task: { code: "A", assignment: "首次体验：首节点", maximum_minutes: 15 },
    sessionId: fixedSessionId,
    answers: {
      participant_code: "P01",
      tester_relation: "external_player",
      evidence_channel: "remote_self_report",
      platform: "windows",
      windows_environment: "native_physical_hardware",
      input_methods: ["keyboard_mouse", "touchscreen"],
      prior_external_explanation: "none",
      end_reason: "time_limit",
      replay_intent: "unsure",
      contact_moment_3: "attempted_incomplete",
      contact_moment_4: "not_reached",
      first_minute_quote: "我先飞向最近的花。",
      moment_3_recall_quote: "花后来变了，但我没看懂。",
    },
    events: {
      event_1: { status: "occurred_timed", elapsed_seconds: 83.4 },
      event_2: { status: "did_not_occur", elapsed_seconds: 12 },
      event_3: { status: "occurred_time_unavailable" },
    },
    sessionDurationSeconds: 614.6,
    sessionDurationStatus: "recorded",
    exportedAt: "2026-08-25T00:00:00.000Z",
  });

  assert.equal(payload.schema_version, 1);
  assert.equal(payload.session_id, fixedSessionId);
  assert.equal(payload.evidence.participant_code, fixedSessionId);
  assert.equal(payload.product.commit, "11111111");
  assert.equal(payload.product.full_commit, "1".repeat(40));
  assert.equal(payload.product.artifact_sha256, artifactSha256);
  assert.deepEqual(payload.evidence.input_methods, ["keyboard_mouse", "touchscreen"]);
  assert.equal(payload.contacts.moment_3, "attempted_incomplete");
  assert.equal(payload.contacts.moment_4, "not_reached");
  assert.equal(payload.timeline.origin, "T0 = 首次取得控制权");
  assert.deepEqual(payload.timeline.session_duration, { status: "occurred_timed", elapsed_seconds: 615 });
  assert.deepEqual(payload.timeline.events.event_1, { status: "occurred_timed", elapsed_seconds: 83 });
  assert.deepEqual(payload.timeline.events.event_2, { status: "did_not_occur", elapsed_seconds: null });
  assert.deepEqual(payload.timeline.events.event_4, { status: "not_recorded", elapsed_seconds: null });
  assert.deepEqual(payload.categorical_responses, {
    prior_external_explanation: "none",
    end_reason: "time_limit",
    replay_intent: "unsure",
  });
  assert.equal(payload.verbatim_responses.first_minute_quote, "我先飞向最近的花。");
  assert.equal(payload.verbatim_responses.moment_3_recall_quote, "花后来变了，但我没看懂。");
  assert.equal(Object.hasOwn(payload.verbatim_responses, "participant_code"), false);
  assert.equal(Object.hasOwn(payload.verbatim_responses, "end_reason"), false);
  assert.equal(Object.hasOwn(payload, "developer_interpretations"), false);
  assert.equal(Object.hasOwn(payload, "follow_up_actions"), false);
});

test("generates an offline participant folder and keeps coordinator material separate", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-playtest-kit-"));
  const output = join(temporaryRoot, "package");
  const currentIdentity = await readProductIdentity();
  try {
    const result = await generatePlaytestEvidence(output, {
      artifactSha256,
      taskCode: "A",
      candidateCommit: currentIdentity.full_commit,
      candidateDirty: false,
      sessionId: fixedSessionId,
    });
    assert.equal(result.sessionId, fixedSessionId);
    assert.equal(await readFile(join(output, ".nameless-playtest-evidence"), "utf8"), "nameless-playtest-evidence:v1\n");

    const participantAssets = await Promise.all([
      readFile(join(output, "participant", "index.html"), "utf8"),
      readFile(join(output, "participant", "styles.css"), "utf8"),
      readFile(join(output, "participant", "review.js"), "utf8"),
    ]);
    const participantText = participantAssets.join("\n");
    const coordinatorText = await readFile(join(output, "coordinator", "README.md"), "utf8");
    const analysis = JSON.parse(await readFile(join(output, "coordinator", "analysis-template.json"), "utf8"));
    const manifest = JSON.parse(await readFile(join(output, "coordinator", "manifest.json"), "utf8"));

    await execFileAsync(process.execPath, ["--check", join(output, "participant", "review.js")]);

    assert.match(participantAssets[0], /connect-src 'none'/);
    assert.doesNotMatch(participantText, /https?:\/\//iu);
    assert.doesNotMatch(participantText, /\b(?:fetch|XMLHttpRequest|sendBeacon|WebSocket)\b/u);
    assert.doesNotMatch(participantText, /开放花药|同型开放柱头|蜂身散粉|锁定旧位置|同方向快速双击|侧移出通道|第一次交蜜|完成条件|传粉|急转|饮蜜|honey_delivery|pollination|acute_turn|drink|E\s*键/iu);
    assert.doesNotMatch(participantText, /coordinator|analysis-template|developer_interpretations|follow_up_actions/u);
    assert.doesNotMatch(participantText, /name="(?:name|email|phone|age|gender|location)"/u);
    assert.match(participantText, /本次未到达/);
    assert.match(participantText, /data-contact-details="moment_3"/);
    assert.match(participantText, /时间不可得/);
    assert.match(participantText, /导出匿名 JSON/);
    assert.match(coordinatorText, /只把同级的 `participant\/` 文件夹交给参与者/);
    assert.match(coordinatorText, /没有稳定的“三分钟后再次急转”机会/);
    assert.deepEqual(analysis.objective_observations, []);
    assert.deepEqual(analysis.verbatim_player_quotes, []);
    assert.deepEqual(analysis.developer_interpretations, []);
    assert.deepEqual(analysis.follow_up_actions, []);
    assert.deepEqual(
      analysis.field_schema.objective_observations.required,
      ["event_id", "source", "elapsed", "text"],
    );
    assert.match(analysis.field_schema.objective_observations.rule, /observable events/);
    assert.equal(manifest.candidate.artifact_sha256, artifactSha256);
    assert.equal(manifest.task.code, "A");

    await generatePlaytestEvidence(output, {
      artifactSha256,
      taskCode: "A",
      candidateCommit: currentIdentity.full_commit,
      candidateDirty: false,
      sessionId: fixedSessionId,
    });
    assert.equal(JSON.parse(await readFile(join(output, "coordinator", "manifest.json"), "utf8")).session_id, fixedSessionId);
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

test("blocks unavailable task B, sends music to the separate tool, and protects output paths", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-playtest-kit-safety-"));
  const currentIdentity = await readProductIdentity();
  const unrelatedDirectory = join(temporaryRoot, "existing-project");
  const guardFile = join(unrelatedDirectory, "keep.txt");
  const repositoryLink = join(temporaryRoot, "repository-link");
  await mkdir(unrelatedDirectory);
  await writeFile(guardFile, "do not delete\n", "utf8");
  await symlink(repositoryPath, repositoryLink);
  try {
    await assert.rejects(
      generatePlaytestEvidence(join(temporaryRoot, "missing-hash"), { taskCode: "A" }),
      /64-character --artifact-sha256/,
    );
    await assert.rejects(
      generatePlaytestEvidence(join(temporaryRoot, "blocked-slice"), { artifactSha256, taskCode: "B" }),
      /blocked until the game has a fixed single-slice entry/,
    );
    await assert.rejects(
      generatePlaytestEvidence(join(temporaryRoot, "music"), { artifactSha256, taskCode: "C" }),
      /npm run audio:review/,
    );
    await assert.rejects(
      generatePlaytestEvidence(join(temporaryRoot, "implicit-clean"), { artifactSha256, candidateCommit: currentIdentity.full_commit }),
      /requires exactly one of --candidate-clean or --candidate-dirty/,
    );
    await assert.rejects(
      generatePlaytestEvidence(join(temporaryRoot, "missing-commit"), { artifactSha256, candidateCommit: "deadbeef", candidateDirty: false }),
    );
    await assert.rejects(generatePlaytestEvidence(repositoryPath, { artifactSha256 }), /repository or one of its ancestors/);
    await assert.rejects(generatePlaytestEvidence(dirname(repositoryPath), { artifactSha256 }), /repository or one of its ancestors/);
    await assert.rejects(generatePlaytestEvidence(join(repositoryPath, "docs/generated"), { artifactSha256 }), /must stay under outputs/);
    await assert.rejects(generatePlaytestEvidence(join(repositoryLink, "docs/generated"), { artifactSha256 }), /must stay under outputs/);
    await assert.rejects(generatePlaytestEvidence(unrelatedDirectory, { artifactSha256 }), /without \.nameless-playtest-evidence/);
    assert.equal(await readFile(guardFile, "utf8"), "do not delete\n");

    const dirtyOutput = join(temporaryRoot, "dirty-candidate");
    const dirtyResult = await generatePlaytestEvidence(dirtyOutput, {
      artifactSha256,
      taskCode: "A",
      candidateCommit: currentIdentity.full_commit,
      candidateDirty: true,
      sessionId: fixedSessionId,
    });
    assert.equal(dirtyResult.product.dirty, true);
    assert.match(await readFile(join(dirtyOutput, "participant", "index.html"), "utf8"), new RegExp(`${currentIdentity.commit} \\+dirty`));
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});
