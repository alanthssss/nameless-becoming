import { execFile } from "node:child_process";
import { randomBytes } from "node:crypto";
import { lstat, mkdir, readFile, realpath, rename, rm, writeFile } from "node:fs/promises";
import { basename, dirname, isAbsolute, parse, relative, resolve } from "node:path";
import { promisify } from "node:util";
import { fileURLToPath } from "node:url";

const execFileAsync = promisify(execFile);
const repositoryRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const defaultOutputRoot = resolve(repositoryRoot, "outputs/playtest-evidence");
const outputSentinelName = ".nameless-playtest-evidence";
const outputSentinel = "nameless-playtest-evidence:v2\n";
const schemaVersion = 2;

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
    },
    timeline: {
      origin: "T0 = 首次取得控制权",
      session_duration: normalizeTimelineEvent({ status: durationStatus, elapsed_seconds: Number.isFinite(duration) && duration >= 0 ? duration : null }),
      events: Object.fromEntries(timelineEvents.map(({ id }) => [id, normalizeTimelineEvent(events[id])])),
    },
    contacts: Object.fromEntries(observedMoments.map(({ id }) => [id, String(answers[`contact_${id}`] || "")])),
    objective_observations: Object.fromEntries(observedMoments.map(({ id }) => [id, String(answers[`observation_${id}`] || "")])),
    help_request_quote: String(answers.help_request_quote || ""),
    exported_at: exportedAt,
  };
}

export async function readProductIdentity(root = repositoryRoot) {
  const packageJson = JSON.parse(await readFile(resolve(root, "package.json"), "utf8"));
  const [{ stdout: commitOutput }, { stdout: statusOutput }] = await Promise.all([
    execFileAsync("git", ["rev-parse", "HEAD"], { cwd: root }),
    execFileAsync("git", ["status", "--porcelain=v1", "--untracked-files=normal"], { cwd: root }),
  ]);
  const fullCommit = commitOutput.trim();
  if (!/^[0-9a-f]{40}$/u.test(fullCommit)) throw new Error(`Unexpected git commit: ${fullCommit}`);
  return { name: "无名：成蜂", version: String(packageJson.version), commit: fullCommit.slice(0, 8), full_commit: fullCommit, dirty: statusOutput.trim().length > 0 };
}

export async function readCandidateIdentity(commit, root = repositoryRoot) {
  const normalized = String(commit).trim().toLowerCase();
  if (!/^[0-9a-f]{7,40}$/u.test(normalized)) throw new Error("--candidate-commit must be a 7-40 character hexadecimal git commit.");
  const { stdout } = await execFileAsync("git", ["rev-parse", `${normalized}^{commit}`], { cwd: root });
  const fullCommit = stdout.trim();
  if (!/^[0-9a-f]{40}$/u.test(fullCommit)) throw new Error(`Unexpected candidate commit: ${fullCommit}`);
  const packageJson = JSON.parse((await execFileAsync("git", ["show", `${fullCommit}:package.json`], { cwd: root })).stdout);
  return { name: "无名：成蜂", version: String(packageJson.version), commit: fullCommit.slice(0, 8), full_commit: fullCommit };
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
  return `<!doctype html>
<html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="Content-Security-Policy" content="default-src 'self' blob:; img-src 'self' data:; style-src 'self'; script-src 'self'; connect-src 'none'; media-src 'none'">
<title>《无名：成蜂》试玩回忆 ${escapeHtml(sessionId)}</title><link rel="stylesheet" href="styles.css"></head>
<body ${bodyData(context)}><main class="shell compact-shell">
<header class="hero"><p class="eyebrow">LOCAL PLAYTEST · ${escapeHtml(sessionId)}</p><h1>六项，写完就结束。</h1>
<p class="lede">请先把本页放在一边自由玩，结束后再回来。没有标准答案；不记得、失败或提前停下都可以照实写。</p>
<dl class="build-card"><div><dt>最长</dt><dd>${task.maximum_minutes} 分钟</dd></div><div><dt>版本</dt><dd>${escapeHtml(versionLabel)}</dd></div></dl>
${product.dirty ? '<p class="warning">这是 dirty 候选，只能用于排查，不能作为固定候选通过证据。</p>' : ""}</header>
<form id="evidence-form"><section class="panel" aria-labelledby="recall-title"><div class="section-heading"><p class="eyebrow">结束后填写 · 约两分钟</p>
<h2 id="recall-title">只写你自己的记忆</h2><p>不要填写姓名、联系方式、账号、精确位置、健康或残障信息。</p></div>
<div class="form-grid single-column">
<label class="field">开始后一分钟，你记得自己先做了什么、卡在哪里？<textarea name="first_minute_quote" required maxlength="800" placeholder="不记得也可以直接写“不记得”。"></textarea></label>
<label class="field">你最远到达了什么画面？<textarea name="furthest_reached_quote" required maxlength="500" placeholder="按画面描述，不必知道关卡名。"></textarea></label>
<label class="field">哪里最卡、最意外，或者最想让我们知道？<textarea name="stuck_or_surprised_quote" required maxlength="800" placeholder="没有也可以写“没有”。"></textarea></label>
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
<fieldset class="field full"><legend>实际输入方式（可多选）</legend><div class="choices"><label><input type="checkbox" name="input_methods" value="keyboard_mouse"> 键盘＋鼠标</label><label><input type="checkbox" name="input_methods" value="trackpad"> 触控板</label><label><input type="checkbox" name="input_methods" value="touchscreen"> 真实触屏</label><label><input type="checkbox" name="input_methods" value="other"> 其他</label><label><input type="checkbox" name="input_methods" value="unknown"> 不确定</label></div></fieldset></div></section>
<section class="panel"><div class="section-heading"><h2>观察时间线</h2><p>T0 = 首次取得控制权。无观察时标记“未观察”，不得补造秒数。</p></div><div class="timer-row"><strong id="timer-display">尚未开始</strong><button type="button" id="start-timer" class="primary">开始计时</button><button type="button" id="finish-timer">结束计时</button><button type="button" id="unavailable-timer">总时长不可得</button></div><div class="event-grid">${timelineEvents.map(timelineCard).join("")}</div></section>
<section class="panel"><div class="section-heading"><h2>机制接触判定</h2><p>这是观察者分类，不要求参与者逐项回答。没有观察时统一选“没有可用观察”。</p></div><div class="detail-grid">${momentFields}</div><label class="field full">玩家第一次求助的原话（可空）<textarea name="help_request_quote" maxlength="1200" placeholder="只抄原话；没有或不可得就留空。"></textarea></label></section></form></main>
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
  return `${browserContextJavaScript()}\n${arrayValue.toString()}\n${productPayload.toString()}\n${taskPayload.toString()}\n${normalizeTimelineEvent.toString()}\n${buildObserverPayload.toString()}
const timelineEvents=${JSON.stringify(timelineEvents)},observedMoments=${JSON.stringify(observedMoments)},form=document.querySelector("#observer-form"),saveStatus=document.querySelector("#save-status"),timerDisplay=document.querySelector("#timer-display"),storageKey="nameless-playtest-observer-v2-"+body.dataset.sessionId;let events=Object.fromEntries(timelineEvents.map(({id})=>[id,{status:"not_recorded",elapsed_seconds:null}])),timer={started_at_epoch_ms:null,ended_elapsed_seconds:null,status:"not_recorded"},timerInterval=null;
function setStatus(message){saveStatus.textContent=message}function elapsedSeconds(){if(timer.status==="unavailable"||timer.status==="not_recorded")return null;if(timer.ended_elapsed_seconds!==null)return timer.ended_elapsed_seconds;if(timer.started_at_epoch_ms===null)return null;return Math.max(0,Math.round((Date.now()-timer.started_at_epoch_ms)/1000))}function formatElapsed(seconds){if(seconds===null||!Number.isFinite(seconds))return"时间不可得";return"T+"+String(Math.floor(seconds/60)).padStart(2,"0")+":"+String(Math.floor(seconds%60)).padStart(2,"0")}function refreshTimer(){if(timer.status==="unavailable"){timerDisplay.textContent="总时长不可得";return}const elapsed=elapsedSeconds();timerDisplay.textContent=elapsed===null?"尚未开始":formatElapsed(elapsed)+(timer.ended_elapsed_seconds!==null?" · 已结束":"")}
function refreshEvents(){for(const{id}of timelineEvents){const value=events[id],label=value.status==="occurred_timed"?"已记录 "+formatElapsed(value.elapsed_seconds):value.status==="occurred_time_unavailable"?"已发生 · 时间不可得":value.status==="did_not_occur"?"确认未发生":value.status==="not_observed"?"未观察 · 不能判断":"尚未记录";document.querySelector('[data-event-value="'+id+'"]').textContent=label}}function refreshWindowsField(){const field=document.querySelector("#windows-environment-field"),select=field.querySelector("select"),show=document.querySelector("#platform").value==="windows";field.hidden=!show;select.disabled=!show;select.required=show;if(!show)select.value=""}function localState(){return{schema_version:schemaVersion,answers:formAnswers(form),events,timer}}function save(){try{localStorage.setItem(storageKey,JSON.stringify(localState()));setStatus("已保存在本机")}catch{setStatus("请直接导出 JSON")}}
function restore(){let saved;try{saved=JSON.parse(localStorage.getItem(storageKey)||"null")}catch{return}if(!saved||saved.schema_version!==schemaVersion)return;for(const control of form.elements){if(!control.name)continue;const value=saved.answers?.[control.name];if(control.type==="checkbox")control.checked=arrayValue(value).includes(control.value);else if(typeof value==="string")control.value=value}events=Object.fromEntries(timelineEvents.map(({id})=>[id,normalizeTimelineEvent(saved.events?.[id])]));if(saved.timer&&["not_recorded","running","recorded","unavailable"].includes(saved.timer.status))timer=saved.timer;setStatus("已恢复本机记录")}
function exportResults(){refreshWindowsField();if(!form.reportValidity()){setStatus("请先补全必填观察项");return}if(![...form.querySelectorAll('[name="input_methods"]')].some(control=>control.checked)){setStatus("请至少选择一种输入方式");return}const missing=timelineEvents.find(({id})=>events[id].status==="not_recorded");if(missing){setStatus("请明确记录四个事件，或标记未观察");document.querySelector('[data-event-card="'+missing.id+'"]').scrollIntoView({behavior:"smooth",block:"center"});return}if(timer.status==="not_recorded"){setStatus("请记录总时长或标记不可得");return}if(timer.status==="running"){timer.ended_elapsed_seconds=elapsedSeconds();timer.status="recorded";window.clearInterval(timerInterval);refreshTimer()}save();const payload=buildObserverPayload({product,task,sessionId:body.dataset.sessionId,participant,answers:formAnswers(form),events,sessionDurationSeconds:elapsedSeconds(),sessionDurationStatus:timer.status==="unavailable"?"unavailable":"recorded",exportedAt:new Date().toISOString()});downloadJson(payload,"playtest-observer-"+body.dataset.sessionId+".json");setStatus("观察结果已导出")}
document.querySelector("#start-timer").addEventListener("click",()=>{if(timer.started_at_epoch_ms===null)timer.started_at_epoch_ms=Date.now();timer.ended_elapsed_seconds=null;timer.status="running";window.clearInterval(timerInterval);timerInterval=window.setInterval(refreshTimer,1000);refreshTimer();save()});document.querySelector("#finish-timer").addEventListener("click",()=>{if(timer.started_at_epoch_ms!==null&&timer.ended_elapsed_seconds===null){timer.ended_elapsed_seconds=elapsedSeconds();timer.status="recorded"}window.clearInterval(timerInterval);refreshTimer();save()});document.querySelector("#unavailable-timer").addEventListener("click",()=>{timer={started_at_epoch_ms:null,ended_elapsed_seconds:null,status:"unavailable"};window.clearInterval(timerInterval);refreshTimer();save()});
for(const button of document.querySelectorAll("[data-event-action]"))button.addEventListener("click",()=>{const id=button.dataset.eventId;if(button.dataset.eventAction==="timed"){const elapsed=elapsedSeconds();if(elapsed===null){setStatus("先在取得控制权时开始计时");return}events[id]={status:"occurred_timed",elapsed_seconds:elapsed}}else if(button.dataset.eventAction==="unavailable")events[id]={status:"occurred_time_unavailable",elapsed_seconds:null};else if(button.dataset.eventAction==="absent")events[id]={status:"did_not_occur",elapsed_seconds:null};else if(button.dataset.eventAction==="not-observed")events[id]={status:"not_observed",elapsed_seconds:null};else events[id]={status:"not_recorded",elapsed_seconds:null};refreshEvents();save()});
form.addEventListener("input",()=>{refreshWindowsField();setStatus("有未导出的修改");window.clearTimeout(form.saveTimer);form.saveTimer=window.setTimeout(save,350)});form.addEventListener("submit",event=>event.preventDefault());document.querySelector("#save-button").addEventListener("click",save);document.querySelector("#export-button").addEventListener("click",exportResults);document.querySelector("#reset-button").addEventListener("click",()=>{if(!window.confirm("清空观察记录？已导出的 JSON 不受影响。"))return;form.reset();events=Object.fromEntries(timelineEvents.map(({id})=>[id,{status:"not_recorded",elapsed_seconds:null}]));timer={started_at_epoch_ms:null,ended_elapsed_seconds:null,status:"not_recorded"};window.clearInterval(timerInterval);try{localStorage.removeItem(storageKey)}catch{}refreshWindowsField();refreshEvents();refreshTimer();setStatus("已清空")});restore();refreshWindowsField();refreshEvents();refreshTimer();if(timer.status==="running")timerInterval=window.setInterval(refreshTimer,1000);`;
}

function coordinatorReadme({ product, sourceIdentity, sessionId, participant }) {
  return `# 试玩协调说明（不要发给参与者）

本次会话：\`${sessionId}\`  
关系类型：\`${participant.tester_relation}\`（生成时由协调者声明，参与者不可修改）
候选：\`${product.version} · ${product.commit}${product.dirty ? " +dirty" : ""}\`  
安装包 SHA-256：\`${product.artifact_sha256}\`

## 两个入口

- 只把同级的 \`participant/\` 文件夹交给参与者。A 表只有 4 个原话题和 2 个结束选择。
- 协调者自己打开 \`observer.html\`，记录环境、时间线和机制接触状态。它含内部机制名，绝不能交给参与者。

参与者不再选择自己是不是外部玩家，也不再逐项判定是否掌握机制。分析时仍需核对 \`external_player\` 确实未参与策划／开发。

1. 核对实际启动候选的版本、提交号和安装包哈希；不一致就停止。
2. A 包从标题开始，T0 为首次取得控制权，最多 15 分钟；开始前不解释操作、目标或设计意图。
3. 现场／录屏可用时填写 observer；远程无观察时把事件标成“未观察”，机制状态标成“没有可用观察”，不得让玩家补做长表。
4. 玩家结束后才打开 participant 表；两份 JSON 分别引用到 \`analysis-template.json\`。

participant JSON 只保存短回忆与结束选择，不能单独证明机制掌握。observer JSON 保存观察事实和分类；无观察就保持不可判定。

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
    objective_observations: [],
    verbatim_player_quotes: [],
    developer_interpretations: [],
    follow_up_actions: [],
    analyst_confidence: "",
    evidence_classification: { counts_as_external_player: null, counts_as_windows_native_hardware: null, mechanism_mastery_evaluable: null },
  };
}

function validateSha256(value) {
  const normalized = String(value || "").trim().toLowerCase();
  if (!/^[0-9a-f]{64}$/u.test(normalized)) throw new Error("A 64-character --artifact-sha256 is required before preparing a participant package.");
  return normalized;
}
function validateTask(taskCode) {
  const code = String(taskCode || "A").trim().toUpperCase();
  if (code === "C") throw new Error("Task C is the separate music package. Run npm run audio:review instead.");
  if (code === "B") throw new Error("Task B is blocked until the game has a fixed single-slice entry bound to the same artifact and hash. This generator currently prepares Task A only.");
  if (code !== "A") throw new Error("--task must be A. Music task C uses npm run audio:review.");
  return { code, assignment: "首次体验：首节点", internal_assignment: "", maximum_minutes: 15 };
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
function validateResolvedOutput(output) {
  if (output === parse(output).root) throw new Error("Refusing to replace a filesystem root.");
  if (isWithin(output, repositoryRoot)) throw new Error("Refusing the repository or one of its ancestors as output.");
  if (isWithin(repositoryRoot, output) && !isWithin(resolve(repositoryRoot, "outputs"), output)) throw new Error("Output inside the repository must stay under outputs/.");
}
async function validateOutputTarget(outputDirectory) {
  const output = resolve(outputDirectory); validateResolvedOutput(output);
  let existingAncestor = output; const missingSegments = [];
  while (true) {
    try { await lstat(existingAncestor); break; } catch (error) {
      if (error?.code !== "ENOENT") throw error;
      const parent = dirname(existingAncestor);
      if (parent === existingAncestor) throw new Error(`Unable to resolve output target: ${output}.`);
      missingSegments.unshift(basename(existingAncestor)); existingAncestor = parent;
    }
  }
  validateResolvedOutput(resolve(await realpath(existingAncestor), ...missingSegments)); return output;
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

export async function generatePlaytestEvidence(outputDirectory, options = {}) {
  const sourceIdentity = await readProductIdentity();
  const task = validateTask(options.taskCode);
  const artifactSha256 = validateSha256(options.artifactSha256);
  const testerRelation = validateTesterRelation(options.testerRelation);
  if (options.candidateCommit && typeof options.candidateDirty !== "boolean") throw new Error("A fixed --candidate-commit also requires exactly one of --candidate-clean or --candidate-dirty.");
  const candidateIdentity = options.candidateCommit ? await readCandidateIdentity(options.candidateCommit) : sourceIdentity;
  const product = { name: candidateIdentity.name, version: candidateIdentity.version, commit: candidateIdentity.commit, full_commit: candidateIdentity.full_commit, dirty: options.candidateCommit ? options.candidateDirty : sourceIdentity.dirty, artifact_sha256: artifactSha256 };
  const sessionId = options.sessionId || `NB-${new Date().toISOString().slice(0, 10).replaceAll("-", "")}-${randomBytes(4).toString("hex").toUpperCase()}`;
  if (!/^[A-Z0-9-]{8,40}$/u.test(sessionId)) throw new Error("Invalid session ID.");
  const participant = { participant_code: sessionId, tester_relation: testerRelation };
  const output = await validateOutputTarget(outputDirectory || resolve(defaultOutputRoot, sessionId));
  const stage = `${output}.stage-${process.pid}-${Date.now()}`, participantDirectory = resolve(stage, "participant"), coordinatorDirectory = resolve(stage, "coordinator");
  const replaceExisting = await assertReplaceableOutput(output);
  await mkdir(dirname(output), { recursive: true }); await mkdir(participantDirectory, { recursive: true }); await mkdir(coordinatorDirectory, { recursive: true });
  const context = { product, task, sessionId, participant };
  try {
    const manifest = { schema_version: schemaVersion, session_id: sessionId, candidate: product, task, participant_identity: participant, participant_entry: "../participant/index.html", observer_entry: "observer.html", generator_source: sourceIdentity, generated_at: new Date().toISOString() };
    await Promise.all([
      writeFile(resolve(participantDirectory, "index.html"), participantHtml(context), "utf8"), writeFile(resolve(participantDirectory, "styles.css"), sharedCss, "utf8"), writeFile(resolve(participantDirectory, "review.js"), participantJavaScript(), "utf8"),
      writeFile(resolve(coordinatorDirectory, "observer.html"), observerHtml(context), "utf8"), writeFile(resolve(coordinatorDirectory, "styles.css"), sharedCss, "utf8"), writeFile(resolve(coordinatorDirectory, "observer.js"), observerJavaScript(), "utf8"),
      writeFile(resolve(coordinatorDirectory, "README.md"), coordinatorReadme({ product, sourceIdentity, task, sessionId, participant }), "utf8"), writeFile(resolve(coordinatorDirectory, "analysis-template.json"), `${JSON.stringify(analysisTemplate(context), null, 2)}\n`, "utf8"), writeFile(resolve(coordinatorDirectory, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`, "utf8"), writeFile(resolve(stage, outputSentinelName), outputSentinel, "utf8"),
    ]);
    if (replaceExisting) { await assertReplaceableOutput(output); await rm(output, { recursive: true, force: true }); }
    await rename(stage, output);
  } catch (error) { await rm(stage, { recursive: true, force: true }); throw error; }
  return { output, participant: resolve(output, "participant/index.html"), observer: resolve(output, "coordinator/observer.html"), coordinator: resolve(output, "coordinator/README.md"), sessionId, participantIdentity: participant, product, task };
}

function flagValue(name) {
  const index = process.argv.indexOf(name); if (index < 0) return undefined;
  const value = process.argv[index + 1]; if (!value || value.startsWith("--")) throw new Error(`${name} requires a value.`); return value;
}
async function main() {
  const requestedOutput = flagValue("--output") || process.env.NAMELESS_PLAYTEST_OUTPUT;
  const artifactSha256 = flagValue("--artifact-sha256") || process.env.NAMELESS_PLAYTEST_ARTIFACT_SHA256;
  const taskCode = flagValue("--task") || "A", testerRelation = flagValue("--tester-relation"), candidateCommit = flagValue("--candidate-commit");
  const candidateClean = process.argv.includes("--candidate-clean"), candidateDirty = process.argv.includes("--candidate-dirty");
  if (candidateClean && candidateDirty) throw new Error("Use only one of --candidate-clean or --candidate-dirty.");
  if (!candidateCommit && (candidateClean || candidateDirty)) throw new Error("--candidate-clean/--candidate-dirty requires --candidate-commit.");
  const result = await generatePlaytestEvidence(requestedOutput, { artifactSha256, taskCode, testerRelation, candidateCommit, candidateDirty: candidateClean ? false : candidateDirty ? true : undefined });
  console.log(`Prepared playtest evidence package ${result.sessionId} at ${relative(repositoryRoot, result.output) || result.output}.`);
  console.log(`Give only this folder to the participant: ${dirname(result.participant)}`);
  console.log(`Coordinator observer (keep separate): ${result.observer}`);
}
const invokedPath = process.argv[1] ? resolve(process.argv[1]) : "";
if (invokedPath === fileURLToPath(import.meta.url)) main().catch((error) => { console.error(error instanceof Error ? error.message : error); process.exitCode = 1; });
