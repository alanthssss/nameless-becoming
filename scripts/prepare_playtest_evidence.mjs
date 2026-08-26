import { execFile } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import { createReadStream } from "node:fs";
import { lstat, mkdir, readFile, readdir, realpath, rename, rm, writeFile } from "node:fs/promises";
import { basename, dirname, isAbsolute, parse, relative, resolve } from "node:path";
import { promisify, TextDecoder } from "node:util";
import { fileURLToPath } from "node:url";

const execFileAsync = promisify(execFile);
const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const defaultOutputRoot = resolve(repositoryRoot, "outputs/playtest-evidence");
const outputSentinelName = ".nameless-playtest-evidence";
const outputSentinel = "nameless-playtest-evidence:v2\n";
const schemaVersion = 2;
const artifactManifestSchemaVersion = 1;
const playtestSliceSchemaVersion = 1;
const playtestTicketSchemaVersion = 1;
const playtestSliceCatalogPath = "godot/data/playtest_slices.json";
const utf8Decoder = new TextDecoder("utf-8", { fatal: true });
const platformArtifacts = Object.freeze({
  "macos-universal": "NamelessBecoming-macOS.zip",
  "windows-x86_64": "NamelessBecoming-Windows.exe",
});

const contactStatuses = Object.freeze([
  ["not_observed", "没有可用观察，不能判定"],
  ["not_reached", "本次未到达"],
  ["reached_not_noticed", "到达了，但没注意到／没尝试"],
  ["attempted_incomplete", "尝试了，但没有完成"],
  ["completed_game_prompt", "主要照着游戏内提示才完成"],
  ["completed_external_help", "经游戏外口头帮助完成"],
  ["completed_independent", "没有游戏外帮助，也不是主要照提示，独立完成"],
]);
const timelineEvents = Object.freeze([
  { id: "event_1", title: "第一次交蜜" },
  { id: "event_2", title: "第一次向游戏外的人求助" },
  { id: "event_3", title: "第一次失败" },
  { id: "event_4", title: "第一次重开" },
]);
const observedMoments = Object.freeze([
  { id: "moment_1", title: "第一次交蜜" },
  { id: "moment_2", title: "完成条件" },
  { id: "moment_3", title: "传粉" },
  { id: "moment_4", title: "急转" },
  { id: "moment_5", title: "饮蜜" },
  { id: "moment_6", title: "失败后的重开" },
]);
const participantQuoteFields = Object.freeze([
  "first_minute_quote",
  "furthest_reached_quote",
  "stuck_or_surprised_quote",
  "player_summary_quote",
]);

function arrayValue(value) {
  if (Array.isArray(value)) return value;
  if (value === undefined || value === null || value === "") return [];
  return [value];
}

function productPayload(product) {
  return {
    name: product.name,
    version: product.version,
    commit: product.commit,
    full_commit: product.full_commit,
    dirty: Boolean(product.dirty),
    artifact_sha256: product.artifact_sha256,
  };
}

function taskPayload(task) {
  return { code: task.code, assignment: task.assignment, maximum_minutes: task.maximum_minutes };
}

function normalizeTimelineEvent(value) {
  const allowed = new Set(["occurred_timed", "occurred_time_unavailable", "did_not_occur", "not_observed", "not_recorded"]);
  const status = allowed.has(value?.status) ? value.status : "not_recorded";
  const elapsed = Number(value?.elapsed_seconds);
  return {
    status,
    elapsed_seconds: status === "occurred_timed" && Number.isFinite(elapsed) && elapsed >= 0 ? Math.round(elapsed) : null,
  };
}

export function buildEvidencePayload({ product, task, sessionId, participant, answers = {}, exportedAt }) {
  return {
    schema_version: schemaVersion,
    export_kind: "participant_short_form",
    session_id: sessionId,
    product: productPayload(product),
    task: taskPayload(task),
    evidence: {
      participant_code: participant.participant_code,
      tester_relation: participant.tester_relation,
      relation_asserted_by: "coordinator_at_generation",
    },
    categorical_responses: {
      end_reason: String(answers.end_reason || ""),
      replay_intent: String(answers.replay_intent || ""),
    },
    verbatim_responses: Object.fromEntries(participantQuoteFields.map((field) => [field, String(answers[field] || "")])),
    exported_at: exportedAt,
  };
}

export function buildObserverPayload({ product, task, sessionId, participant, answers = {}, events = {}, sessionDurationSeconds = null, sessionDurationStatus = "not_recorded", exportedAt }) {
  const duration = Number(sessionDurationSeconds);
  const durationStatus = sessionDurationStatus === "recorded" ? "occurred_timed"
    : sessionDurationStatus === "unavailable" ? "occurred_time_unavailable" : "not_recorded";
  return {
    schema_version: schemaVersion,
    export_kind: "coordinator_observation",
    session_id: sessionId,
    product: productPayload(product),
    task: taskPayload(task),
    evidence: {
      participant_code: participant.participant_code,
      tester_relation: participant.tester_relation,
      relation_asserted_by: "coordinator_at_generation",
      evidence_channel: String(answers.evidence_channel || ""),
      platform: String(answers.platform || ""),
      windows_environment: String(answers.windows_environment || ""),
      input_methods: arrayValue(answers.input_methods).map(String),
      prior_external_explanation: String(answers.prior_external_explanation || ""),
    },
    timeline: {
      origin: "T0 = 首次取得控制权",
      session_duration: normalizeTimelineEvent({ status: durationStatus, elapsed_seconds: Number.isFinite(duration) && duration >= 0 ? duration : null }),
      events: Object.fromEntries(timelineEvents.map(({ id }) => [id, normalizeTimelineEvent(events[id])])),
    },
    contacts: Object.fromEntries(observedMoments.map(({ id }) => [id, String(answers[`contact_${id}`] || "")])),
    objective_observations: Object.fromEntries(observedMoments.map(({ id }) => [id, String(answers[`observation_${id}`] || "")])),
    learning_transfer: {
      evade_delayed_retest: {
        opportunity: String(answers.evade_retest_opportunity || ""),
        result: String(answers.evade_retest_result || ""),
        objective_observation: String(answers.evade_retest_observation || ""),
      },
    },
    help_request_quote: String(answers.help_request_quote || ""),
    exported_at: exportedAt,
  };
}

export function validateEvadeRetestAnswers(answers = {}) {
  const opportunity = String(answers.evade_retest_opportunity || "");
  const result = String(answers.evade_retest_result || "");
  if (opportunity === "provided_stable" && result === "not_evaluable") return "已有稳定复测机会，请记录实际结果";
  if (opportunity && opportunity !== "provided_stable" && result && result !== "not_evaluable") return "没有稳定复测机会时，结果必须选不可判定";
  return "";
}

export async function readProductIdentity(root = repositoryRoot) {
  const packageJson = JSON.parse(await readFile(resolve(root, "package.json"), "utf8"));
  const [{ stdout: commitOutput }, { stdout: statusOutput }] = await Promise.all([
    execFileAsync("git", ["rev-parse", "HEAD"], { cwd: root }),
    execFileAsync("git", ["status", "--porcelain=v1", "--untracked-files=normal"], { cwd: root }),
  ]);
  const fullCommit = commitOutput.trim();
  if (!/^[0-9a-f]{40}$/u.test(fullCommit)) throw new Error(`Unexpected git commit: ${fullCommit}`);
  return { name: "一会儿巢里见", version: String(packageJson.version), commit: fullCommit.slice(0, 8), full_commit: fullCommit, dirty: statusOutput.trim().length > 0 };
}

export async function readCandidateIdentity(commit, root = repositoryRoot) {
  const normalized = String(commit).trim().toLowerCase();
  if (!/^[0-9a-f]{7,40}$/u.test(normalized)) throw new Error("--candidate-commit must be a 7-40 character hexadecimal git commit.");
  const { stdout } = await execFileAsync("git", ["rev-parse", `${normalized}^{commit}`], { cwd: root });
  const fullCommit = stdout.trim();
  if (!/^[0-9a-f]{40}$/u.test(fullCommit)) throw new Error(`Unexpected candidate commit: ${fullCommit}`);
  const packageJson = JSON.parse((await execFileAsync("git", ["show", `${fullCommit}:package.json`], { cwd: root })).stdout);
  return { name: "一会儿巢里见", version: String(packageJson.version), commit: fullCommit.slice(0, 8), full_commit: fullCommit };
}

function escapeHtml(value) {
  return String(value).replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&#39;");
}

function bodyData({ product, task, sessionId, participant }) {
  return `data-session-id="${escapeHtml(sessionId)}" data-participant-code="${escapeHtml(participant.participant_code)}" data-tester-relation="${escapeHtml(participant.tester_relation)}" data-product-name="${escapeHtml(product.name)}" data-product-version="${escapeHtml(product.version)}" data-product-commit="${escapeHtml(product.commit)}" data-product-full-commit="${escapeHtml(product.full_commit)}" data-product-dirty="${product.dirty ? "true" : "false"}" data-artifact-sha256="${escapeHtml(product.artifact_sha256)}" data-task-code="${task.code}" data-task-assignment="${escapeHtml(task.assignment)}" data-task-maximum-minutes="${task.maximum_minutes}"`;
}

function participantHtml(context) {
  const { product, task, sessionId } = context;
  const versionLabel = `${product.version} · ${product.commit}${product.dirty ? " +dirty" : ""}`;
  const introduction = task.code === "B"
    ? "请先把本页放在一边自由玩，结束后再回来；不记得、失败或提前停下都可以照实写。"
    : "请先把本页放在一边自由玩，结束后再回来。没有标准答案；不记得、失败或提前停下都可以照实写。";
  const taskCard = task.code === "B" ? `<div><dt>任务</dt><dd>${escapeHtml(task.assignment)}</dd></div>` : "";
  return `<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'self' blob:; img-src 'self' data:; style-src 'self'; script-src 'self'; connect-src 'none'; media-src 'none'">
<title>《一会儿巢里见》试玩回忆 ${escapeHtml(sessionId)}</title><link rel="stylesheet" href="styles.css"></head>
<body ${bodyData(context)}><main class="shell compact-shell">
<header class="hero"><p class="eyebrow">LOCAL PLAYTEST · ${escapeHtml(sessionId)}</p><h1>六项，写完就结束。</h1>
<p class="lede">${introduction}</p>
<dl class="build-card">${taskCard}<div><dt>最长</dt><dd>${task.maximum_minutes} 分钟</dd></div><div><dt>版本</dt><dd>${escapeHtml(versionLabel)}</dd></div></dl>
${product.dirty ? '<p class="warning">这是 dirty 候选，只能用于排查，不能作为固定候选通过证据。</p>' : ""}</header>
<form id="evidence-form"><section class="panel" aria-labelledby="recall-title"><div class="section-heading"><p class="eyebrow">结束后填写 · 约两分钟</p>
<h2 id="recall-title">只写你自己的记忆</h2><p>不要填写姓名、联系方式、账号、精确位置、健康或残障信息。</p></div>
<div class="form-grid single-column">
<label class="field">开始后一分钟，你先做了什么？有没有不知道下一步做什么、操作没有成功或停下来想的地方？<textarea name="first_minute_quote" required maxlength="800" placeholder="不记得也可以直接写“不记得”。"></textarea></label>
<label class="field">你最远到达了什么画面？<textarea name="furthest_reached_quote" required maxlength="500" placeholder="按画面描述，不必知道关卡名。"></textarea></label>
<label class="field">哪一处最难懂、最难操作、最意外，或者最想让我们知道？<textarea name="stuck_or_surprised_quote" required maxlength="800" placeholder="没有也可以写“没有”。"></textarea></label>
<label class="field">用一句自己的话描述这次游戏<textarea name="player_summary_quote" required maxlength="500" placeholder="原话即可，不用替游戏宣传。"></textarea></label>
<label class="field">为什么在这里结束？<select name="end_reason" required><option value="">请选择</option><option value="time_limit">到达时间上限</option><option value="felt_finished">觉得这一轮结束了</option><option value="stuck">卡住，不知道怎么继续</option><option value="lost_interest">不想继续</option><option value="technical_issue">技术问题</option><option value="other">其他</option></select></label>
<label class="field">现在还想再来一次吗？<select name="replay_intent" required><option value="">请选择</option><option value="yes">想</option><option value="after_changes">改一些问题后想</option><option value="no">不想</option><option value="unsure">不确定</option></select></label>
</div></section></form></main>
<div class="sticky-actions" aria-label="记录操作"><button id="save-button" type="button">保存到本机</button><button id="export-button" class="primary" type="button">导出匿名 JSON</button><button id="reset-button" class="danger" type="button">清空</button><span id="save-status" aria-live="polite">尚未保存</span></div>
<script src="review.js"></script></body></html>`;
}

function contactSelect(id, title) {
  return `<label class="field">${escapeHtml(title)}<select name="contact_${id}" required><option value="">请选择最接近的情况</option>${contactStatuses.map(([value, label]) => `<option value="${value}">${label}</option>`).join("")}</select></label>`;
}

function timelineCard({ id, title }) {
  return `<article class="event-card" data-event-card="${id}"><h3>${escapeHtml(title)}</h3><p class="event-value" data-event-value="${id}">尚未记录</p><div class="event-actions"><button type="button" data-event-action="timed" data-event-id="${id}">记录当前 T+</button><button type="button" data-event-action="unavailable" data-event-id="${id}">发生了，时间不可得</button><button type="button" data-event-action="absent" data-event-id="${id}">确认本轮未发生</button><button type="button" data-event-action="not-observed" data-event-id="${id}">未观察，不能判断</button><button type="button" class="quiet" data-event-action="clear" data-event-id="${id}">清除</button></div></article>`;
}

function observerHtml(context) {
  const { product, task, sessionId, participant } = context;
  const momentFields = observedMoments.map(({ id, title }) => `<article class="detail-card">${contactSelect(id, title)}<label class="field">客观观察备注（可空）<textarea name="observation_${id}" maxlength="1200" placeholder="只写可观察事实，不替玩家解释。"></textarea></label></article>`).join("");
  return `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'self' blob:; img-src 'self' data:; style-src 'self'; script-src 'self'; connect-src 'none'; media-src 'none'">
<title>协调者观察记录 ${escapeHtml(sessionId)}</title><link rel="stylesheet" href="styles.css"></head><body ${bodyData(context)}><main class="shell">
<header class="hero"><p class="eyebrow">COORDINATOR ONLY · ${escapeHtml(sessionId)}</p><h1>观察和玩家回忆分开记。</h1><p class="lede">本页包含内部机制名，绝不能交给参与者。关系类型已固定为 <code>${escapeHtml(participant.tester_relation)}</code>，参与者无法修改。</p><dl class="build-card"><div><dt>任务</dt><dd>${escapeHtml(task.assignment)}</dd></div><div><dt>候选</dt><dd>${escapeHtml(product.version)} · ${escapeHtml(product.commit)}${product.dirty ? " +dirty" : ""}</dd></div></dl></header>
<form id="observer-form"><section class="panel"><div class="section-heading"><h2>环境与证据来源</h2><p>只记匿名代号；不要写姓名、联系方式、账号、精确位置、健康或残障信息。</p></div><div class="form-grid">
<label class="field">记录来源<select name="evidence_channel" required><option value="">请选择</option><option value="onsite_observation">现场观察</option><option value="remote_self_report">远程自报，无观察</option><option value="consented_screen_recording">自愿匿名屏幕记录</option></select></label>
<label class="field">运行平台<select name="platform" id="platform" required><option value="">请选择</option><option value="macos">macOS</option><option value="windows">Windows</option><option value="web">Web</option></select></label>
<label class="field" id="windows-environment-field" hidden>Windows 运行环境<select name="windows_environment" disabled><option value="">请选择</option><option value="native_physical_hardware">真实 Windows 设备</option><option value="virtual_machine">虚拟机</option><option value="compatibility_layer">兼容层</option><option value="unknown">不确定</option></select></label>
<label class="field">游戏外是否在试玩前解释过操作、目标或正确做法？<select name="prior_external_explanation" required><option value="">请选择</option><option value="none">没有</option><option value="after_explicit_request">只在玩家主动求助后解释</option><option value="before_play">开始前就解释过</option><option value="unknown">不确定</option></select></label>
<fieldset class="field full"><legend>实际输入方式（可多选）</legend><div class="choices"><label><input type="checkbox" name="input_methods" value="keyboard_mouse"> 键盘＋鼠标</label><label><input type="checkbox" name="input_methods" value="trackpad"> 触控板</label><label><input type="checkbox" name="input_methods" value="touchscreen"> 真实触屏</label><label><input type="checkbox" name="input_methods" value="other"> 其他</label><label><input type="checkbox" name="input_methods" value="unknown"> 不确定</label></div></fieldset></div></section>
<section class="panel"><div class="section-heading"><h2>观察时间线</h2><p>T0 = 首次取得控制权。无观察时标记“未观察”，不得补造秒数。</p></div><div class="timer-row"><strong id="timer-display">尚未开始</strong><button type="button" id="start-timer" class="primary">开始计时</button><button type="button" id="finish-timer">结束计时</button><button type="button" id="unavailable-timer">总时长不可得</button></div><div class="event-grid">${timelineEvents.map(timelineCard).join("")}</div></section>
<section class="panel"><div class="section-heading"><h2>机制接触判定</h2><p>这是观察者分类，不要求参与者逐项回答。没有观察时统一选“没有可用观察”。</p></div><div class="detail-grid">${momentFields}</div><label class="field full">玩家第一次求助的原话（可空）<textarea name="help_request_quote" maxlength="1200" placeholder="只抄原话；没有或不可得就留空。"></textarea></label></section>
<section class="panel" id="evade-retest-panel"><div class="section-heading"><h2>急转延迟复测</h2><p>机会与结果必须分开。只有首次急转之后、间隔约 3 分钟、同一危险语法且没有再次教学，才算稳定复测机会；没有机会不能判成迁移失败。</p></div><div class="form-grid">
<label class="field">是否提供稳定延迟复测机会？<select name="evade_retest_opportunity" required><option value="">请选择</option><option value="not_observed">没有可用观察，不能判定</option><option value="first_evade_not_completed">首次急转未完成，不能进入迁移判断</option><option value="not_provided">没有提供稳定延迟复测机会</option><option value="provided_with_reteaching">再次遇到，但有重新教学，不算稳定复测</option><option value="provided_stable">提供了稳定、无重新教学的复测机会</option></select></label>
<label class="field">该次稳定复测的结果<select name="evade_retest_result" required><option value="">请选择</option><option value="not_evaluable">不可判定／没有稳定机会</option><option value="not_attempted">有稳定机会，但玩家没有尝试</option><option value="attempted_incomplete">尝试了，但没有完成</option><option value="completed_external_help">经游戏外帮助完成</option><option value="completed_independent">无额外提示或帮助，独立完成</option></select></label>
<label class="field full">延迟复测客观观察（可空）<textarea name="evade_retest_observation" maxlength="1200" placeholder="例如首次急转后的间隔、是否出现同语法危险、是否重新弹出教学、玩家实际动作。"></textarea></label></div></section></form></main>
<div class="sticky-actions"><button id="save-button" type="button">保存到本机</button><button id="export-button" class="primary" type="button">导出观察 JSON</button><button id="reset-button" class="danger" type="button">清空</button><span id="save-status">尚未保存</span></div><script src="observer.js"></script></body></html>`;
}

const sharedCss = `
:root{color-scheme:dark;font-family:Inter,"PingFang SC","Microsoft YaHei",system-ui,sans-serif;background:#101713;color:#f3ecd7}*{box-sizing:border-box}body{margin:0;min-width:320px;background:linear-gradient(160deg,#15241e,#0d1411 68%)}button,input,select,textarea{font:inherit;border:1px solid #52675a;border-radius:.65rem;background:#18251f;color:#f3ecd7}button{padding:.7rem .9rem;cursor:pointer}button:focus-visible,input:focus-visible,select:focus-visible,textarea:focus-visible{border-color:#e3b746;outline:2px solid rgba(227,183,70,.25)}input,select,textarea{width:100%;padding:.68rem .75rem}textarea{min-height:5.5rem;resize:vertical;line-height:1.55}input[type=checkbox]{width:auto;accent-color:#e3b746}fieldset{margin:0;padding:0;border:0}.shell{width:min(1120px,calc(100% - 2rem));margin:0 auto;padding:2.5rem 0 7rem}.compact-shell{width:min(720px,calc(100% - 2rem))}.hero{padding:1rem 0 2rem}.eyebrow{margin:0 0 .5rem;color:#e3b746;font-size:.76rem;font-weight:800;letter-spacing:.16em}h1,h2,h3,p{margin-top:0}h1{max-width:18ch;margin-bottom:.6rem;font-size:clamp(2.3rem,7vw,4.8rem);line-height:1}.lede,.section-heading p{max-width:68ch;color:#bcc9c0;line-height:1.75}.build-card{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:.75rem;margin:1.5rem 0 0}.build-card div,.detail-card,.event-card{padding:.9rem;border:1px solid #405348;border-radius:.8rem;background:#111d18}.build-card dd{margin:.25rem 0 0;overflow-wrap:anywhere}.warning{padding:.8rem;border:1px solid #a86951;border-radius:.7rem;color:#ffc8af}.panel{margin-bottom:1rem;padding:clamp(1rem,3vw,1.7rem);border:1px solid #405348;border-radius:1rem;background:rgba(20,33,27,.94)}.section-heading{margin-bottom:1.2rem}.form-grid,.detail-grid,.event-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:.9rem}.single-column{grid-template-columns:1fr}.field{display:grid;align-content:start;gap:.4rem}.full{grid-column:1/-1}.choices,.timer-row,.event-actions{display:flex;flex-wrap:wrap;gap:.65rem}.choices label{display:inline-flex;align-items:center;gap:.4rem}.detail-card,.event-card{display:grid;gap:.8rem}.event-value{color:#aabbb0}.event-actions button{padding:.55rem .65rem;font-size:.82rem}.primary{border-color:#e3b746;background:#d8aa35;color:#172017;font-weight:800}.danger{color:#efb6a2}.sticky-actions{position:fixed;z-index:10;right:1rem;bottom:1rem;left:1rem;display:flex;align-items:center;justify-content:center;gap:.6rem;width:fit-content;max-width:calc(100% - 2rem);margin:auto;padding:.7rem;border:1px solid #52675a;border-radius:1rem;background:rgba(10,17,14,.95)}#save-status{min-width:7rem;color:#9fb1a5;font-size:.78rem}@media(max-width:720px){.shell{width:min(100% - 1rem,42rem);padding-top:1rem}.build-card,.form-grid,.detail-grid,.event-grid{grid-template-columns:1fr}.full{grid-column:auto}.sticky-actions{overflow-x:auto;justify-content:flex-start}.sticky-actions button{flex:0 0 auto}}
`;

function browserContextJavaScript() {
  return `const schemaVersion=${schemaVersion};const body=document.body;const product={name:body.dataset.productName,version:body.dataset.productVersion,commit:body.dataset.productCommit,full_commit:body.dataset.productFullCommit,dirty:body.dataset.productDirty==="true",artifact_sha256:body.dataset.artifactSha256};const task={code:body.dataset.taskCode,assignment:body.dataset.taskAssignment,maximum_minutes:Number(body.dataset.taskMaximumMinutes)};const participant={participant_code:body.dataset.participantCode,tester_relation:body.dataset.testerRelation};function formAnswers(form){const answers={};for(const[key,value]of new FormData(form).entries()){if(Object.hasOwn(answers,key))answers[key]=Array.isArray(answers[key])?[...answers[key],value]:[answers[key],value];else answers[key]=value}return answers}function downloadJson(payload,filename){const blob=new Blob([JSON.stringify(payload,null,2)+"\\n"],{type:"application/json"});const link=document.createElement("a");link.href=URL.createObjectURL(blob);link.download=filename;link.click();window.setTimeout(()=>URL.revokeObjectURL(link.href),0)}`;
}

function participantJavaScript() {
  return `${browserContextJavaScript()}\nconst participantQuoteFields=${JSON.stringify(participantQuoteFields)};\n${productPayload.toString()}\n${taskPayload.toString()}\n${buildEvidencePayload.toString()}
const form=document.querySelector("#evidence-form"),saveStatus=document.querySelector("#save-status"),storageKey="nameless-playtest-participant-v2-"+body.dataset.sessionId;
function setStatus(message){saveStatus.textContent=message}function snapshot(){return{schema_version:schemaVersion,answers:formAnswers(form)}}
function save(){try{localStorage.setItem(storageKey,JSON.stringify(snapshot()));setStatus("已保存在本机")}catch{setStatus("请直接导出 JSON")}}
function restore(){let saved;try{saved=JSON.parse(localStorage.getItem(storageKey)||"null")}catch{return}if(!saved||saved.schema_version!==schemaVersion)return;for(const control of form.elements){if(!control.name)continue;const value=saved.answers?.[control.name];if(typeof value==="string")control.value=value}setStatus("已恢复本机记录")}
function exportResults(){if(!form.reportValidity()){setStatus("请补完六项；不记得可以直接这样写");return}save();const payload=buildEvidencePayload({product,task,sessionId:body.dataset.sessionId,participant,answers:formAnswers(form),exportedAt:new Date().toISOString()});downloadJson(payload,"playtest-"+body.dataset.sessionId+".json");setStatus("匿名结果已导出")}
form.addEventListener("input",()=>{setStatus("有未导出的修改");window.clearTimeout(form.saveTimer);form.saveTimer=window.setTimeout(save,350)});form.addEventListener("submit",event=>event.preventDefault());document.querySelector("#save-button").addEventListener("click",save);document.querySelector("#export-button").addEventListener("click",exportResults);document.querySelector("#reset-button").addEventListener("click",()=>{if(!window.confirm("清空本页填写内容和本机记录？已导出的 JSON 不受影响。"))return;form.reset();try{localStorage.removeItem(storageKey)}catch{}setStatus("已清空")});restore();`;
}

function observerJavaScript() {
  return `${browserContextJavaScript()}\n${arrayValue.toString()}\n${productPayload.toString()}\n${taskPayload.toString()}\n${normalizeTimelineEvent.toString()}\n${buildObserverPayload.toString()}\n${validateEvadeRetestAnswers.toString()}
const timelineEvents=${JSON.stringify(timelineEvents)},observedMoments=${JSON.stringify(observedMoments)},form=document.querySelector("#observer-form"),saveStatus=document.querySelector("#save-status"),timerDisplay=document.querySelector("#timer-display"),storageKey="nameless-playtest-observer-v2-"+body.dataset.sessionId;let events=Object.fromEntries(timelineEvents.map(({id})=>[id,{status:"not_recorded",elapsed_seconds:null}])),timer={started_at_epoch_ms:null,ended_elapsed_seconds:null,status:"not_recorded"},timerInterval=null;
function setStatus(message){saveStatus.textContent=message}function elapsedSeconds(){if(timer.status==="unavailable"||timer.status==="not_recorded")return null;if(timer.ended_elapsed_seconds!==null)return timer.ended_elapsed_seconds;if(timer.started_at_epoch_ms===null)return null;return Math.max(0,Math.round((Date.now()-timer.started_at_epoch_ms)/1000))}function formatElapsed(seconds){if(seconds===null||!Number.isFinite(seconds))return"时间不可得";return"T+"+String(Math.floor(seconds/60)).padStart(2,"0")+":"+String(Math.floor(seconds%60)).padStart(2,"0")}function refreshTimer(){if(timer.status==="unavailable"){timerDisplay.textContent="总时长不可得";return}const elapsed=elapsedSeconds();timerDisplay.textContent=elapsed===null?"尚未开始":formatElapsed(elapsed)+(timer.ended_elapsed_seconds!==null?" · 已结束":"")}
function refreshEvents(){for(const{id}of timelineEvents){const value=events[id],label=value.status==="occurred_timed"?"已记录 "+formatElapsed(value.elapsed_seconds):value.status==="occurred_time_unavailable"?"已发生 · 时间不可得":value.status==="did_not_occur"?"确认未发生":value.status==="not_observed"?"未观察 · 不能判断":"尚未记录";document.querySelector('[data-event-value="'+id+'"]').textContent=label}}function refreshWindowsField(){const field=document.querySelector("#windows-environment-field"),select=field.querySelector("select"),show=document.querySelector("#platform").value==="windows";field.hidden=!show;select.disabled=!show;select.required=show;if(!show)select.value=""}function validateEvadeRetest(){const message=validateEvadeRetestAnswers(formAnswers(form));if(!message)return true;setStatus(message);document.querySelector("#evade-retest-panel").scrollIntoView({behavior:"smooth",block:"center"});return false}function localState(){return{schema_version:schemaVersion,answers:formAnswers(form),events,timer}}function save(){try{localStorage.setItem(storageKey,JSON.stringify(localState()));setStatus("已保存在本机")}catch{setStatus("请直接导出 JSON")}}
function restore(){let saved;try{saved=JSON.parse(localStorage.getItem(storageKey)||"null")}catch{return}if(!saved||saved.schema_version!==schemaVersion)return;for(const control of form.elements){if(!control.name)continue;const value=saved.answers?.[control.name];if(control.type==="checkbox")control.checked=arrayValue(value).includes(control.value);else if(typeof value==="string")control.value=value}events=Object.fromEntries(timelineEvents.map(({id})=>[id,normalizeTimelineEvent(saved.events?.[id])]));if(saved.timer&&["not_recorded","running","recorded","unavailable"].includes(saved.timer.status))timer=saved.timer;setStatus("已恢复本机记录")}
function exportResults(){refreshWindowsField();if(!form.reportValidity()){setStatus("请先补全必填观察项");return}if(![...form.querySelectorAll('[name="input_methods"]')].some(control=>control.checked)){setStatus("请至少选择一种输入方式");return}if(!validateEvadeRetest())return;const missing=timelineEvents.find(({id})=>events[id].status==="not_recorded");if(missing){setStatus("请明确记录四个事件，或标记未观察");document.querySelector('[data-event-card="'+missing.id+'"]').scrollIntoView({behavior:"smooth",block:"center"});return}if(timer.status==="not_recorded"){setStatus("请记录总时长或标记不可得");return}if(timer.status==="running"){timer.ended_elapsed_seconds=elapsedSeconds();timer.status="recorded";window.clearInterval(timerInterval);refreshTimer()}save();const payload=buildObserverPayload({product,task,sessionId:body.dataset.sessionId,participant,answers:formAnswers(form),events,sessionDurationSeconds:elapsedSeconds(),sessionDurationStatus:timer.status==="unavailable"?"unavailable":"recorded",exportedAt:new Date().toISOString()});downloadJson(payload,"playtest-observer-"+body.dataset.sessionId+".json");setStatus("观察结果已导出")}
document.querySelector("#start-timer").addEventListener("click",()=>{if(timer.started_at_epoch_ms===null)timer.started_at_epoch_ms=Date.now();timer.ended_elapsed_seconds=null;timer.status="running";window.clearInterval(timerInterval);timerInterval=window.setInterval(refreshTimer,1000);refreshTimer();save()});document.querySelector("#finish-timer").addEventListener("click",()=>{if(timer.started_at_epoch_ms!==null&&timer.ended_elapsed_seconds===null){timer.ended_elapsed_seconds=elapsedSeconds();timer.status="recorded"}window.clearInterval(timerInterval);refreshTimer();save()});document.querySelector("#unavailable-timer").addEventListener("click",()=>{timer={started_at_epoch_ms:null,ended_elapsed_seconds:null,status:"unavailable"};window.clearInterval(timerInterval);refreshTimer();save()});
for(const button of document.querySelectorAll("[data-event-action]"))button.addEventListener("click",()=>{const id=button.dataset.eventId;if(button.dataset.eventAction==="timed"){const elapsed=elapsedSeconds();if(elapsed===null){setStatus("先在取得控制权时开始计时");return}events[id]={status:"occurred_timed",elapsed_seconds:elapsed}}else if(button.dataset.eventAction==="unavailable")events[id]={status:"occurred_time_unavailable",elapsed_seconds:null};else if(button.dataset.eventAction==="absent")events[id]={status:"did_not_occur",elapsed_seconds:null};else if(button.dataset.eventAction==="not-observed")events[id]={status:"not_observed",elapsed_seconds:null};else events[id]={status:"not_recorded",elapsed_seconds:null};refreshEvents();save()});
form.addEventListener("input",()=>{refreshWindowsField();setStatus("有未导出的修改");window.clearTimeout(form.saveTimer);form.saveTimer=window.setTimeout(save,350)});form.addEventListener("submit",event=>event.preventDefault());document.querySelector("#save-button").addEventListener("click",save);document.querySelector("#export-button").addEventListener("click",exportResults);document.querySelector("#reset-button").addEventListener("click",()=>{if(!window.confirm("清空观察记录？已导出的 JSON 不受影响。"))return;form.reset();events=Object.fromEntries(timelineEvents.map(({id})=>[id,{status:"not_recorded",elapsed_seconds:null}]));timer={started_at_epoch_ms:null,ended_elapsed_seconds:null,status:"not_recorded"};window.clearInterval(timerInterval);try{localStorage.removeItem(storageKey)}catch{}refreshWindowsField();refreshEvents();refreshTimer();setStatus("已清空")});restore();refreshWindowsField();refreshEvents();refreshTimer();if(timer.status==="running")timerInterval=window.setInterval(refreshTimer,1000);`;
}

function coordinatorReadme({ product, sourceIdentity, task, sessionId, participant }) {
  const participantSummary = task.code === "B"
    ? `只把同级的 \`participant/\` 文件夹交给参与者。公开任务只写“${task.assignment}”和 ${task.maximum_minutes} 分钟时限。`
    : "只把同级的 `participant/` 文件夹交给参与者。A 表只有 4 个原话题和 2 个结束选择。";
  const protocolStart = task.code === "B"
    ? `B01 必须使用 participant 同目录的 \`playtest-ticket.json\` 启动，T0 为首次取得控制权，最多 ${task.maximum_minutes} 分钟；开始前不解释操作、目标或设计意图。`
    : "A 包从标题开始，T0 为首次取得控制权，最多 15 分钟；开始前不解释操作、目标或设计意图。";
  const verifiedLaunch = task.code === "B"
    ? `\n## 可靠启动\n\n从仓库根目录运行，不要手写 Godot 参数分隔符：\n\n\`npm run playtest:launch -- --executable "/游戏绝对路径/一会儿巢里见.app" --ticket "/本会话绝对路径/participant/playtest-ticket.json"\`\n\n只有命令打印 \`Playtest ready receipt verified\` 才能记录为 B01 typed scene 已启动；它会在 participant 目录生成与本 session、slice、commit 和 ticket SHA-256 绑定的 \`playtest-ready-receipt.json\`。缺少 receipt、身份不符或游戏显示 \`PT-ARG-SEPARATOR\` 时均停止，不得把普通 Main 误记为 B01。\n`
    : "";
  return `# 试玩协调说明（不要发给参与者）

本次会话：\`${sessionId}\`  
关系类型：\`${participant.tester_relation}\`（生成时由协调者声明，参与者不可修改）
候选：\`${product.version} · ${product.commit}${product.dirty ? " +dirty" : ""}\`  
安装包 SHA-256：\`${product.artifact_sha256}\`

## 两个入口

- ${participantSummary}
- 协调者自己打开 \`observer.html\`，记录环境、试玩前游戏外解释、时间线、机制接触，以及急转延迟复测的机会和结果。它含内部机制名，绝不能交给参与者。
${verifiedLaunch}

参与者不再选择自己是不是外部玩家，也不再逐项判定是否掌握机制。分析时仍需核对 \`external_player\` 确实未参与策划／开发。

1. 核对实际启动候选的版本、提交号和安装包哈希；不一致就停止。
2. ${protocolStart}
3. 现场／录屏可用时填写 observer；远程无观察时把事件标成“未观察”，机制状态标成“没有可用观察”，不得让玩家补做长表。
4. 玩家结束后才打开 participant 表；两份 JSON 分别引用到 \`analysis-template.json\`。

participant JSON 只保存短回忆与结束选择，不能单独证明机制掌握。observer JSON 保存观察事实和分类；无观察就保持不可判定。

**急转复测警告**：只有 observer 同时记录 \`opportunity = provided_stable\`（首次急转后约 3 分钟、同一危险语法、没有重新教学）和对应结果，才能评价延迟迁移。\`not_observed\`、\`first_evade_not_completed\`、\`not_provided\` 或 \`provided_with_reteaching\` 一律记为不可判定，不能改写成玩家失败。

不收姓名、联系方式、账号、IP、年龄、性别、精确位置、健康／残障信息、脸或声音。匿名录屏须先说明用途并允许关麦、裁通知。

生成工具来源：\`${sourceIdentity.full_commit}\`${sourceIdentity.dirty ? "（生成时工作区有改动）" : "（生成时工作区干净）"}。
`;
}

function analysisTemplate({ product, task, sessionId, participant }) {
  return {
    schema_version: schemaVersion,
    session_id: sessionId,
    candidate: product,
    task,
    participant_identity: participant,
    participant_export_file: "",
    observer_export_file: "",
    relation_asserted_at_generation: true,
    relation_verified_by_coordinator: null,
    protocol_verification: { prior_external_explanation: null },
    objective_observations: [],
    verbatim_player_quotes: [],
    developer_interpretations: [],
    follow_up_actions: [],
    evade_delayed_retest_assessment: {
      opportunity: null,
      result: null,
      evaluable: null,
      evidence_refs: [],
      analyst_note: "只有 provided_stable 加观察到的结果可以评价；其他机会状态一律不可判定，不能记为迁移失败。",
    },
    analyst_confidence: "",
    evidence_classification: { counts_as_external_player: null, counts_as_windows_native_hardware: null, mechanism_mastery_evaluable: null },
  };
}

function requireExactKeys(value, expectedKeys, label) {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(`${label} must be a JSON object.`);
  const expected = [...expectedKeys].sort();
  const actual = Object.keys(value).sort();
  if (actual.length !== expected.length || actual.some((key, index) => key !== expected[index])) {
    throw new Error(`${label} must contain exactly: ${expected.join(", ")}.`);
  }
}

function parseJsonBytes(bytes, label) {
  let text;
  try { text = utf8Decoder.decode(bytes); } catch { throw new Error(`${label} must be valid UTF-8 JSON.`); }
  try { return JSON.parse(text); } catch { throw new Error(`${label} must be valid JSON.`); }
}

async function readRegularFileBytes(path, label) {
  let stats;
  try { stats = await lstat(path); } catch (error) {
    if (error?.code === "ENOENT") throw new Error(`${label} does not exist: ${path}.`);
    throw error;
  }
  if (!stats.isFile() || stats.isSymbolicLink()) throw new Error(`${label} must be a regular file, not a directory or symbolic link: ${path}.`);
  return { bytes: await readFile(path), stats };
}

async function hashRegularFile(path, label) {
  let stats;
  try { stats = await lstat(path); } catch (error) {
    if (error?.code === "ENOENT") throw new Error(`${label} does not exist: ${path}.`);
    throw error;
  }
  if (!stats.isFile() || stats.isSymbolicLink()) throw new Error(`${label} must be a regular file, not a directory or symbolic link: ${path}.`);
  const hash = createHash("sha256");
  let size = 0;
  for await (const chunk of createReadStream(path)) { hash.update(chunk); size += chunk.byteLength; }
  if (size !== stats.size) throw new Error(`${label} changed while it was being verified.`);
  return { size, sha256: hash.digest("hex") };
}

async function gitShowBytes(commit, path, root, label) {
  try {
    const { stdout } = await execFileAsync("git", ["show", `${commit}:${path}`], { cwd: root, encoding: null, maxBuffer: 8 * 1024 * 1024 });
    return Buffer.isBuffer(stdout) ? stdout : Buffer.from(stdout);
  } catch {
    throw new Error(`${label} is not available at exact artifact commit ${commit}: ${path}.`);
  }
}

function validateArtifactManifest(manifest, artifactFilename) {
  if (!manifest || typeof manifest !== "object" || Array.isArray(manifest)) throw new Error("Artifact manifest must be a JSON object.");
  const coreKeys = ["commit", "dirty", "filename", "platform", "product_version", "schema_version", "sha256", "size"];
  const sourceKeys = [...coreKeys, "github_run_id", "source_ref"];
  const actualKeys = Object.keys(manifest || {}).sort();
  const hasCoreKeys = actualKeys.length === coreKeys.length && actualKeys.every((key, index) => key === [...coreKeys].sort()[index]);
  const hasSourceKeys = actualKeys.length === sourceKeys.length && actualKeys.every((key, index) => key === [...sourceKeys].sort()[index]);
  if (!hasCoreKeys && !hasSourceKeys) {
    throw new Error(`Artifact manifest must contain exactly the schema v1 core keys, optionally plus source_ref and github_run_id together.`);
  }
  if (manifest.schema_version !== artifactManifestSchemaVersion) throw new Error("Artifact manifest schema_version must be 1.");
  if (typeof manifest.product_version !== "string" || manifest.product_version.length === 0 || /[\r\n]/u.test(manifest.product_version)) {
    throw new Error("Artifact manifest product_version must be a non-empty single-line string.");
  }
  if (typeof manifest.commit !== "string" || !/^[0-9a-f]{40}$/u.test(manifest.commit)) {
    throw new Error("Artifact manifest commit must be exactly 40 lowercase hexadecimal characters.");
  }
  if (manifest.dirty !== false) throw new Error("Artifact manifest dirty must be false.");
  const expectedFilename = platformArtifacts[manifest.platform];
  if (!expectedFilename) throw new Error(`Artifact manifest platform must be one of: ${Object.keys(platformArtifacts).join(", ")}.`);
  if (manifest.filename !== expectedFilename) throw new Error(`Artifact manifest filename ${String(manifest.filename)} does not match platform ${manifest.platform}.`);
  if (artifactFilename !== manifest.filename) throw new Error(`Artifact filename ${artifactFilename} does not match manifest filename ${manifest.filename}.`);
  if (!Number.isSafeInteger(manifest.size) || manifest.size <= 0) throw new Error("Artifact manifest size must be a positive safe integer.");
  if (typeof manifest.sha256 !== "string" || !/^[0-9a-f]{64}$/u.test(manifest.sha256)) {
    throw new Error("Artifact manifest sha256 must be 64 lowercase hexadecimal characters.");
  }
  if (hasSourceKeys) {
    if (typeof manifest.source_ref !== "string" || !/^refs\/[A-Za-z0-9._/-]+$/u.test(manifest.source_ref)) {
      throw new Error("Artifact manifest source_ref must be a non-empty full Git ref.");
    }
    if (typeof manifest.github_run_id !== "string" || !/^[1-9][0-9]*$/u.test(manifest.github_run_id)) {
      throw new Error("Artifact manifest github_run_id must be a positive decimal string.");
    }
  }
}

async function verifyManifestCommitVersion(manifest, root) {
  const packageBytes = await gitShowBytes(manifest.commit, "package.json", root, "package identity");
  const packageJson = parseJsonBytes(packageBytes, "package.json at artifact commit");
  if (packageJson?.version !== manifest.product_version) {
    throw new Error(`Artifact manifest version ${manifest.product_version} does not match package.json version ${String(packageJson?.version)} at commit ${manifest.commit}.`);
  }
}

export async function readArtifactIdentity({ artifactPath, artifactManifestPath, repositoryRoot: root = repositoryRoot } = {}) {
  if (typeof artifactPath !== "string" || artifactPath.length === 0) throw new Error("--artifact is required.");
  if (typeof artifactManifestPath !== "string" || artifactManifestPath.length === 0) throw new Error("--artifact-manifest is required.");
  if (!isAbsolute(artifactPath)) throw new Error("--artifact must be an absolute path.");
  if (!isAbsolute(artifactManifestPath)) throw new Error("--artifact-manifest must be an absolute path.");
  const resolvedArtifact = resolve(artifactPath);
  const resolvedManifest = resolve(artifactManifestPath);
  const [{ bytes: manifestBytes }, artifactDigest] = await Promise.all([
    readRegularFileBytes(resolvedManifest, "Artifact manifest"),
    hashRegularFile(resolvedArtifact, "Artifact"),
  ]);
  const manifest = parseJsonBytes(manifestBytes, "Artifact manifest");
  validateArtifactManifest(manifest, basename(resolvedArtifact));
  if (artifactDigest.size !== manifest.size) {
    throw new Error(`Artifact size ${artifactDigest.size} does not match manifest size ${manifest.size}.`);
  }
  if (artifactDigest.sha256 !== manifest.sha256) {
    throw new Error(`Artifact SHA-256 ${artifactDigest.sha256} does not match manifest SHA-256 ${manifest.sha256}.`);
  }
  await verifyManifestCommitVersion(manifest, resolve(root));
  const manifestSha256 = createHash("sha256").update(manifestBytes).digest("hex");
  return {
    product: {
      name: "一会儿巢里见",
      version: manifest.product_version,
      commit: manifest.commit.slice(0, 8),
      full_commit: manifest.commit,
      dirty: false,
      artifact_sha256: manifest.sha256,
    },
    artifact: {
      platform: manifest.platform,
      filename: manifest.filename,
      size: manifest.size,
      sha256: manifest.sha256,
      manifest_sha256: manifestSha256,
    },
    manifest,
    manifestBytes,
  };
}

export async function readPlaytestSliceCatalog(commit, root = repositoryRoot) {
  if (typeof commit !== "string" || !/^[0-9a-f]{40}$/u.test(commit)) throw new Error("Slice catalog commit must be exactly 40 lowercase hexadecimal characters.");
  const rawBytes = await gitShowBytes(commit, playtestSliceCatalogPath, resolve(root), "Playtest slice catalog");
  const catalog = parseJsonBytes(rawBytes, "Playtest slice catalog");
  requireExactKeys(catalog, ["schema_version", "slices"], "Playtest slice catalog");
  if (catalog.schema_version !== playtestSliceSchemaVersion) throw new Error("Playtest slice catalog schema_version must be 1.");
  if (!Array.isArray(catalog.slices) || catalog.slices.length === 0) throw new Error("Playtest slice catalog slices must be a non-empty array.");
  const seen = new Set();
  for (const [index, slice] of catalog.slices.entries()) {
    const label = `Playtest slice catalog slices[${index}]`;
    requireExactKeys(slice, ["assignment", "code", "maximum_minutes", "status"], label);
    if (typeof slice.code !== "string" || !/^B[0-9]{2}$/u.test(slice.code)) throw new Error(`${label} code must match B followed by two digits.`);
    if (seen.has(slice.code)) throw new Error(`Playtest slice catalog contains duplicate code ${slice.code}.`);
    seen.add(slice.code);
    if (slice.assignment !== `固定切片 ${slice.code}`) throw new Error(`${label} assignment must remain neutral and code-based.`);
    if (!Number.isSafeInteger(slice.maximum_minutes) || slice.maximum_minutes <= 0 || slice.maximum_minutes > 60) throw new Error(`${label} maximum_minutes must be an integer from 1 to 60.`);
    if (!["blocked", "ready"].includes(slice.status)) throw new Error(`${label} status must be blocked or ready.`);
  }
  return { catalog, rawBytes, sha256: createHash("sha256").update(rawBytes).digest("hex") };
}

function validateSha256(value) {
  const normalized = String(value || "").trim().toLowerCase();
  if (!/^[0-9a-f]{64}$/u.test(normalized)) throw new Error("A 64-character --artifact-sha256 is required before preparing a participant package.");
  return normalized;
}

function normalizeTaskCode(taskCode) {
  const code = String(taskCode || "A").trim().toUpperCase();
  if (code === "C") throw new Error("Task C is the separate music package. Run npm run audio:review instead.");
  if (!["A", "B"].includes(code)) throw new Error("--task must be A or B. Music task C uses npm run audio:review.");
  return code;
}

async function validateTask(taskCode, sliceCode, artifactCommit, root) {
  const code = normalizeTaskCode(taskCode);
  if (code === "A") {
    if (sliceCode !== undefined) throw new Error("--slice is only valid with --task B.");
    return { task: { code, assignment: "首次体验：首节点", internal_assignment: "", maximum_minutes: 15 }, sliceCatalog: null };
  }
  const normalizedSlice = String(sliceCode || "").trim().toUpperCase();
  if (!normalizedSlice) throw new Error("--slice is required with --task B.");
  const sliceCatalog = await readPlaytestSliceCatalog(artifactCommit, root);
  const slice = sliceCatalog.catalog.slices.find(({ code: candidate }) => candidate === normalizedSlice);
  if (!slice) throw new Error(`Slice ${normalizedSlice} is not defined at artifact commit ${artifactCommit}.`);
  if (slice.code !== "B01" || slice.assignment !== "固定切片 B01" || slice.maximum_minutes !== 10) {
    throw new Error("Task B currently permits only the neutral fixed B01 assignment with a 10-minute limit.");
  }
  if (slice.status !== "ready") throw new Error(`Task B slice ${slice.code} is blocked at artifact commit ${artifactCommit}; no evidence package was written.`);
  return {
    task: { code, slice_code: slice.code, assignment: slice.assignment, internal_assignment: "", maximum_minutes: slice.maximum_minutes },
    sliceCatalog,
  };
}
function validateTesterRelation(value) {
  const relation = String(value || "").trim();
  if (!["external_player", "alan_self_test"].includes(relation)) throw new Error("--tester-relation must be external_player or alan_self_test and must be set by the coordinator.");
  return relation;
}
function isWithin(parent, candidate) {
  const path = relative(parent, candidate);
  return path === "" || (!path.startsWith("..") && !isAbsolute(path));
}
function validateResolvedOutput(output, root = repositoryRoot) {
  if (output === parse(output).root) throw new Error("Refusing to replace a filesystem root.");
  if (isWithin(output, root)) throw new Error("Refusing the repository or one of its ancestors as output.");
  if (isWithin(root, output) && !isWithin(resolve(root, "outputs"), output)) throw new Error("Output inside the repository must stay under outputs/.");
}
async function validateOutputTarget(outputDirectory, root = repositoryRoot) {
  const output = resolve(outputDirectory); validateResolvedOutput(output, root);
  let existingAncestor = output; const missingSegments = [];
  while (true) {
    try { await lstat(existingAncestor); break; } catch (error) {
      if (error?.code !== "ENOENT") throw error;
      const parent = dirname(existingAncestor);
      if (parent === existingAncestor) throw new Error(`Unable to resolve output target: ${output}.`);
      missingSegments.unshift(basename(existingAncestor)); existingAncestor = parent;
    }
  }
  validateResolvedOutput(resolve(await realpath(existingAncestor), ...missingSegments), root); return output;
}
async function assertReplaceableOutput(output) {
  let status;
  try { status = await lstat(output); } catch (error) { if (error?.code === "ENOENT") return false; throw error; }
  if (!status.isDirectory()) throw new Error(`Refusing to replace non-directory output: ${output}.`);
  let sentinel;
  try { sentinel = await readFile(resolve(output, outputSentinelName), "utf8"); } catch (error) {
    if (error?.code === "ENOENT") throw new Error(`Refusing to replace existing directory without ${outputSentinelName}: ${output}.`); throw error;
  }
  if (sentinel !== outputSentinel) throw new Error(`Refusing to replace existing directory with an invalid ${outputSentinelName}: ${output}.`);
  return true;
}

function buildPlaytestTicket({ sessionId, product, artifact, task, catalogSha256 }) {
  return {
    schema_version: playtestTicketSchemaVersion,
    session_id: sessionId,
    task: { code: "B", slice_code: task.slice_code },
    product: {
      id: "nameless-becoming",
      display_name: product.name,
      version: product.version,
      commit: product.full_commit,
      dirty: false,
    },
    artifact: {
      platform: artifact.platform,
      filename: artifact.filename,
      size: artifact.size,
      sha256: artifact.sha256,
      manifest_sha256: artifact.manifest_sha256,
    },
    catalog_sha256: catalogSha256,
  };
}

function participantRuntimeReadme({ task }) {
  return `# ${task.assignment}

本次最长 ${task.maximum_minutes} 分钟。请不要打开同包之外的说明文件。

用游戏可执行文件的绝对路径启动，并保留参数前的 \`--\` 分隔符：

\`"<游戏可执行文件的绝对路径>" -- "--playtest-ticket=<playtest-ticket.json 的绝对路径>"\`

如果游戏显示错误码 \`PT-ARG-SEPARATOR\`，说明启动命令漏掉了分隔符；请停止并让协调者重新启动，不能继续玩随后出现的普通游戏。

结束后回到 \`index.html\`，按自己的记忆填写六项短表。
`;
}

const participantForbiddenPatterns = Object.freeze([
  /完成条件|传粉|授粉|急转|饮蜜|交蜜|采蜜|正确答案|答案说明/iu,
]);

// Participant files are generated by this tool, so aggressively compact every
// English identifier before scanning it. This closes CamelCase, digit suffix,
// nested path and repeated/mixed-separator variants without trusting word edges.
const participantForbiddenCompactTerms = Object.freeze([
  "pollination", "evade", "nectar", "deposit", "handler", "profile", "observer",
  "contact", "event1", "event2", "event3", "event4", "observation",
  "evidencechannel", "windowsenvironment", "inputmethods", "priorexternalexplanation",
  "timeline", "contacts", "objectiveobservations", "learningtransfer", "helprequestquote",
  "internalassignment", "answerkey", "answerexplanation", "expectedanswer", "expectedresult",
  "successcondition", "successcriteria", "maintscn", "scriptsmaingd", "mentortutorial",
  "savemanager", "stageindex", "spawnstage", "tutorialstep", "tutorialcomplete",
]);

async function assertParticipantPackageBlind(participantDirectory) {
  const pending = [participantDirectory];
  while (pending.length > 0) {
    const directory = pending.pop();
    for (const entry of await readdir(directory, { withFileTypes: true })) {
      const path = resolve(directory, entry.name);
      if (entry.isDirectory()) { pending.push(path); continue; }
      if (!entry.isFile() || entry.isSymbolicLink()) throw new Error(`Participant package contains an unsupported entry: ${path}.`);
      const bytes = await readFile(path);
      let text;
      try { text = utf8Decoder.decode(bytes); } catch { throw new Error(`Participant package contains a non-text file: ${path}.`); }
      const relativePath = relative(participantDirectory, path);
      const combinedText = `${relativePath}\n${text}`;
      for (const pattern of participantForbiddenPatterns) {
        if (pattern.test(combinedText)) throw new Error(`Participant package leaks coordinator-only vocabulary in ${relativePath}.`);
      }
      const compactText = combinedText.normalize("NFKC").toLowerCase().replace(/[^\p{L}\p{N}]+/gu, "");
      for (const term of participantForbiddenCompactTerms) {
        if (compactText.includes(term)) throw new Error(`Participant package leaks coordinator-only vocabulary in ${relativePath}.`);
      }
    }
  }
}

export async function generatePlaytestEvidence(outputDirectory, options = {}) {
  const taskCode = normalizeTaskCode(options.taskCode);
  const resolvedRepositoryRoot = resolve(options.repositoryRoot || repositoryRoot);
  let artifactIdentity = null;
  let sliceCatalog = null;
  let sourceIdentity;
  let product;
  let task;
  let testerRelation;

  if (taskCode === "A") {
    if ([options.sliceCode, options.artifactPath, options.artifactManifestPath].some((value) => value !== undefined)) {
      throw new Error("--slice, --artifact, and --artifact-manifest are only valid with --task B.");
    }
    sourceIdentity = await readProductIdentity(resolvedRepositoryRoot);
    ({ task } = await validateTask(taskCode, undefined, "", resolvedRepositoryRoot));
    const artifactSha256 = validateSha256(options.artifactSha256);
    testerRelation = validateTesterRelation(options.testerRelation);
    if (options.candidateCommit && typeof options.candidateDirty !== "boolean") throw new Error("A fixed --candidate-commit also requires exactly one of --candidate-clean or --candidate-dirty.");
    const candidateIdentity = options.candidateCommit ? await readCandidateIdentity(options.candidateCommit, resolvedRepositoryRoot) : sourceIdentity;
    product = {
      name: candidateIdentity.name,
      version: candidateIdentity.version,
      commit: candidateIdentity.commit,
      full_commit: candidateIdentity.full_commit,
      dirty: options.candidateCommit ? options.candidateDirty : sourceIdentity.dirty,
      artifact_sha256: artifactSha256,
    };
  } else {
    for (const legacyOption of ["artifactSha256", "candidateCommit", "candidateClean", "candidateDirty", "artifactSha256FromEnvironment"]) {
      if (Object.hasOwn(options, legacyOption)) throw new Error(`Task B rejects legacy identity option ${legacyOption}; use --artifact and --artifact-manifest.`);
    }
    if (!String(options.sliceCode || "").trim()) throw new Error("--slice is required with --task B.");
    artifactIdentity = await readArtifactIdentity({
      artifactPath: options.artifactPath,
      artifactManifestPath: options.artifactManifestPath,
      repositoryRoot: resolvedRepositoryRoot,
    });
    ({ task, sliceCatalog } = await validateTask(taskCode, options.sliceCode, artifactIdentity.product.full_commit, resolvedRepositoryRoot));
    product = artifactIdentity.product;
    testerRelation = validateTesterRelation(options.testerRelation);
    sourceIdentity = await readProductIdentity(resolvedRepositoryRoot);
  }
  const sessionId = options.sessionId || `NB-${new Date().toISOString().slice(0, 10).replaceAll("-", "")}-${randomBytes(4).toString("hex").toUpperCase()}`;
  if (!/^[A-Z0-9-]{8,40}$/u.test(sessionId)) throw new Error("Invalid session ID.");
  const participant = { participant_code: sessionId, tester_relation: testerRelation };
  const output = await validateOutputTarget(outputDirectory || resolve(defaultOutputRoot, sessionId), resolvedRepositoryRoot);
  const stage = `${output}.stage-${process.pid}-${Date.now()}`, participantDirectory = resolve(stage, "participant"), coordinatorDirectory = resolve(stage, "coordinator");
  const replaceExisting = await assertReplaceableOutput(output);
  const context = { product, task, sessionId, participant };
  try {
    await mkdir(dirname(output), { recursive: true }); await mkdir(participantDirectory, { recursive: true }); await mkdir(coordinatorDirectory, { recursive: true });
    const manifest = { schema_version: schemaVersion, session_id: sessionId, candidate: product, ...(artifactIdentity ? { artifact: artifactIdentity.artifact } : {}), task, participant_identity: participant, participant_entry: "../participant/index.html", observer_entry: "observer.html", generator_source: sourceIdentity, generated_at: new Date().toISOString() };
    const writes = [
      writeFile(resolve(participantDirectory, "index.html"), participantHtml(context), "utf8"), writeFile(resolve(participantDirectory, "styles.css"), sharedCss, "utf8"), writeFile(resolve(participantDirectory, "review.js"), participantJavaScript(), "utf8"),
      writeFile(resolve(coordinatorDirectory, "observer.html"), observerHtml(context), "utf8"), writeFile(resolve(coordinatorDirectory, "styles.css"), sharedCss, "utf8"), writeFile(resolve(coordinatorDirectory, "observer.js"), observerJavaScript(), "utf8"),
      writeFile(resolve(coordinatorDirectory, "README.md"), coordinatorReadme({ product, sourceIdentity, task, sessionId, participant }), "utf8"), writeFile(resolve(coordinatorDirectory, "analysis-template.json"), `${JSON.stringify(analysisTemplate(context), null, 2)}\n`, "utf8"), writeFile(resolve(coordinatorDirectory, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`, "utf8"), writeFile(resolve(stage, outputSentinelName), outputSentinel, "utf8"),
    ];
    if (task.code === "B") {
      const ticket = buildPlaytestTicket({ sessionId, product, artifact: artifactIdentity.artifact, task, catalogSha256: sliceCatalog.sha256 });
      writes.push(
        writeFile(resolve(coordinatorDirectory, "artifact-manifest.json"), artifactIdentity.manifestBytes),
        writeFile(resolve(participantDirectory, "artifact-manifest.json"), artifactIdentity.manifestBytes),
        writeFile(resolve(participantDirectory, "playtest-ticket.json"), `${JSON.stringify(ticket, null, 2)}\n`, "utf8"),
        writeFile(resolve(participantDirectory, "README.md"), participantRuntimeReadme({ task }), "utf8"),
      );
    }
    await Promise.all(writes);
    if (task.code === "B") await assertParticipantPackageBlind(participantDirectory);
    if (replaceExisting) { await assertReplaceableOutput(output); await rm(output, { recursive: true, force: true }); }
    await rename(stage, output);
  } catch (error) { await rm(stage, { recursive: true, force: true }); throw error; }
  return { output, participant: resolve(output, "participant/index.html"), observer: resolve(output, "coordinator/observer.html"), coordinator: resolve(output, "coordinator/README.md"), sessionId, participantIdentity: participant, product, ...(artifactIdentity ? { artifact: artifactIdentity.artifact } : {}), task };
}

export function parseArguments(arguments_) {
  const options = {};
  const supported = new Map([
    ["--output", "outputDirectory"],
    ["--task", "taskCode"],
    ["--slice", "sliceCode"],
    ["--tester-relation", "testerRelation"],
    ["--artifact", "artifactPath"],
    ["--artifact-manifest", "artifactManifestPath"],
    ["--artifact-sha256", "artifactSha256"],
    ["--candidate-commit", "candidateCommit"],
  ]);
  const switches = new Map([
    ["--candidate-clean", "candidateClean"],
    ["--candidate-dirty", "candidateDirty"],
  ]);
  for (let index = 0; index < arguments_.length; index += 1) {
    const flag = arguments_[index];
    if (flag === "--help") {
      if (options.help) throw new Error("Argument may only be provided once: --help.");
      options.help = true;
      continue;
    }
    const switchKey = switches.get(flag);
    if (switchKey) {
      if (Object.hasOwn(options, switchKey)) throw new Error(`Argument may only be provided once: ${flag}.`);
      options[switchKey] = true;
      continue;
    }
    const key = supported.get(flag);
    if (!key) throw new Error(`Unknown argument: ${flag}.`);
    if (Object.hasOwn(options, key)) throw new Error(`Argument may only be provided once: ${flag}.`);
    const value = arguments_[index + 1];
    if (value === undefined || value.startsWith("--")) throw new Error(`Argument requires a value: ${flag}.`);
    options[key] = value;
    index += 1;
  }
  if (String(options.taskCode || "A").trim().toUpperCase() === "B") {
    for (const legacyKey of ["artifactSha256", "candidateCommit", "candidateClean", "candidateDirty"]) {
      if (Object.hasOwn(options, legacyKey)) {
        const flag = { artifactSha256: "--artifact-sha256", candidateCommit: "--candidate-commit", candidateClean: "--candidate-clean", candidateDirty: "--candidate-dirty" }[legacyKey];
        throw new Error(`Task B rejects legacy argument ${flag}; use --artifact and --artifact-manifest.`);
      }
    }
  }
  return options;
}

function usage() {
  return [
    "Usage:",
    "  node scripts/prepare_playtest_evidence.mjs --task A --tester-relation <relation>",
    "    --artifact-sha256 <sha256> [--candidate-commit <commit> (--candidate-clean | --candidate-dirty)]",
    "    [--output <directory>]",
    "  node scripts/prepare_playtest_evidence.mjs --task B --slice B01 --tester-relation <relation>",
    "    --artifact <distribution> --artifact-manifest <manifest> [--output <directory>]",
  ].join("\n");
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  if (options.help) { console.log(usage()); return; }
  const requestedOutput = options.outputDirectory || process.env.NAMELESS_PLAYTEST_OUTPUT;
  const taskCode = normalizeTaskCode(options.taskCode);
  let generationOptions;
  if (taskCode === "A") {
    if (options.candidateClean && options.candidateDirty) throw new Error("Use only one of --candidate-clean or --candidate-dirty.");
    if (!options.candidateCommit && (options.candidateClean || options.candidateDirty)) throw new Error("--candidate-clean/--candidate-dirty requires --candidate-commit.");
    generationOptions = {
      ...options,
      artifactSha256: options.artifactSha256 || process.env.NAMELESS_PLAYTEST_ARTIFACT_SHA256,
      candidateDirty: options.candidateClean ? false : options.candidateDirty ? true : undefined,
    };
  } else {
    generationOptions = { ...options };
    if (Object.hasOwn(process.env, "NAMELESS_PLAYTEST_ARTIFACT_SHA256")) {
      generationOptions.artifactSha256FromEnvironment = process.env.NAMELESS_PLAYTEST_ARTIFACT_SHA256;
    }
  }
  const result = await generatePlaytestEvidence(requestedOutput, generationOptions);
  console.log(`Prepared playtest evidence package ${result.sessionId} at ${relative(repositoryRoot, result.output) || result.output}.`);
  console.log(`Give only this folder to the participant: ${dirname(result.participant)}`);
  console.log(`Coordinator observer (keep separate): ${result.observer}`);
}
const invokedPath = process.argv[1] ? resolve(process.argv[1]) : "";
if (invokedPath === fileURLToPath(import.meta.url)) main().catch((error) => { console.error(error instanceof Error ? error.message : error); process.exitCode = 1; });
