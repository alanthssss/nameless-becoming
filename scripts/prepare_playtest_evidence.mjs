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
const outputSentinel = "nameless-playtest-evidence:v1\n";
const schemaVersion = 1;

const contactStatuses = Object.freeze([
  Object.freeze(["not_reached", "本次未到达"]),
  Object.freeze(["reached_not_noticed", "到达了，但没注意到／没尝试"]),
  Object.freeze(["attempted_incomplete", "尝试了，但没有完成"]),
  Object.freeze(["completed_game_prompt", "主要照着游戏内提示才完成"]),
  Object.freeze(["completed_external_help", "经测试者／旁观者口头帮助完成"]),
  Object.freeze(["completed_independent", "没有游戏外帮助，也不是主要照提示，自己完成"]),
]);

const timelineEventIds = Object.freeze([
  "event_1",
  "event_2",
  "event_3",
  "event_4",
]);

function arrayValue(value) {
  if (Array.isArray(value)) return value;
  if (value === undefined || value === null || value === "") return [];
  return [value];
}

function normalizeTimelineEvent(value) {
  const allowedStatuses = new Set(["occurred_timed", "occurred_time_unavailable", "did_not_occur", "not_recorded"]);
  const status = allowedStatuses.has(value?.status) ? value.status : "not_recorded";
  const elapsed = Number(value?.elapsed_seconds);
  return {
    status,
    elapsed_seconds: status === "occurred_timed" && Number.isFinite(elapsed) && elapsed >= 0
      ? Math.round(elapsed)
      : null,
  };
}

export function buildEvidencePayload({ product, task, sessionId, answers = {}, events = {}, sessionDurationSeconds = null, sessionDurationStatus = "not_recorded", exportedAt }) {
  const contacts = Object.fromEntries(
    Object.entries(answers)
      .filter(([key]) => key.startsWith("contact_"))
      .map(([key, value]) => [key.slice("contact_".length), String(value)]),
  );
  const reservedFields = new Set([
    "participant_code",
    "tester_relation",
    "evidence_channel",
    "platform",
    "windows_environment",
    "input_methods",
  ]);
  const categoricalFields = new Set([
    "prior_external_explanation",
    "end_reason",
    "replay_intent",
  ]);
  const categoricalResponses = Object.fromEntries(
    Object.entries(answers)
      .filter(([key]) => categoricalFields.has(key))
      .map(([key, value]) => [key, String(value)]),
  );
  const responses = Object.fromEntries(
    Object.entries(answers).filter(
      ([key]) => !reservedFields.has(key) && !categoricalFields.has(key) && !key.startsWith("contact_"),
    ),
  );
  const duration = Number(sessionDurationSeconds);
  const normalizedDurationStatus = sessionDurationStatus === "recorded"
    ? "occurred_timed"
    : sessionDurationStatus === "unavailable" ? "occurred_time_unavailable" : "not_recorded";

  return {
    schema_version: schemaVersion,
    session_id: sessionId,
    product: {
      name: product.name,
      version: product.version,
      commit: product.commit,
      full_commit: product.full_commit,
      dirty: Boolean(product.dirty),
      artifact_sha256: product.artifact_sha256,
    },
    task: {
      code: task.code,
      assignment: task.assignment,
      maximum_minutes: task.maximum_minutes,
    },
    evidence: {
      participant_code: sessionId,
      tester_relation: String(answers.tester_relation || ""),
      evidence_channel: String(answers.evidence_channel || ""),
      platform: String(answers.platform || ""),
      windows_environment: String(answers.windows_environment || ""),
      input_methods: arrayValue(answers.input_methods).map(String),
    },
    timeline: {
      origin: "T0 = 首次取得控制权",
      session_duration: normalizeTimelineEvent({
        status: normalizedDurationStatus,
        elapsed_seconds: Number.isFinite(duration) && duration >= 0 ? duration : null,
      }),
      events: Object.fromEntries(timelineEventIds.map((id) => [id, normalizeTimelineEvent(events[id])])),
    },
    contacts,
    categorical_responses: categoricalResponses,
    verbatim_responses: responses,
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
  return {
    name: "无名：成蜂",
    version: String(packageJson.version),
    commit: fullCommit.slice(0, 8),
    full_commit: fullCommit,
    dirty: statusOutput.trim().length > 0,
  };
}

export async function readCandidateIdentity(commit, root = repositoryRoot) {
  const normalizedCommit = String(commit).trim().toLowerCase();
  if (!/^[0-9a-f]{7,40}$/u.test(normalizedCommit)) {
    throw new Error("--candidate-commit must be a 7-40 character hexadecimal git commit.");
  }
  const { stdout: commitOutput } = await execFileAsync("git", ["rev-parse", `${normalizedCommit}^{commit}`], { cwd: root });
  const fullCommit = commitOutput.trim();
  if (!/^[0-9a-f]{40}$/u.test(fullCommit)) throw new Error(`Unexpected candidate commit: ${fullCommit}`);
  const { stdout: packageOutput } = await execFileAsync("git", ["show", `${fullCommit}:package.json`], { cwd: root });
  const packageJson = JSON.parse(packageOutput);
  return {
    name: "无名：成蜂",
    version: String(packageJson.version),
    commit: fullCommit.slice(0, 8),
    full_commit: fullCommit,
  };
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function contactSelect(id, title) {
  return `
    <label class="field contact-select">${escapeHtml(title)}
      <select name="contact_${id}" data-contact="${id}" required>
        <option value="">请选择最接近的情况</option>
        ${contactStatuses.map(([value, label]) => `<option value="${value}">${label}</option>`).join("")}
      </select>
    </label>`;
}

function detailSection(id, title, questions) {
  return `
    <section class="detail-card" data-contact-details="${id}" hidden aria-labelledby="${id}-title">
      <h3 id="${id}-title">${escapeHtml(title)}</h3>
      ${questions.map(({ name, label, placeholder = "没注意到或不记得，也可以直接这样写。" }) => `
        <label class="field">${escapeHtml(label)}
          <textarea name="${name}" placeholder="${escapeHtml(placeholder)}" required disabled></textarea>
        </label>`).join("")}
    </section>`;
}

function timelineCard(id, title) {
  return `
    <article class="event-card" data-event-card="${id}">
      <h3>${escapeHtml(title)}</h3>
      <p class="event-value" data-event-value="${id}">尚未记录</p>
      <div class="event-actions">
        <button type="button" data-event-action="timed" data-event-id="${id}">记录当前 T+</button>
        <button type="button" data-event-action="unavailable" data-event-id="${id}">发生了，时间不可得</button>
        <button type="button" data-event-action="absent" data-event-id="${id}">本轮未发生</button>
        <button type="button" class="quiet" data-event-action="clear" data-event-id="${id}">清除</button>
      </div>
    </article>`;
}

function participantHtml({ product, task, sessionId }) {
  const versionLabel = `${product.version} · ${product.commit}${product.dirty ? " +dirty" : ""}`;
  const isTaskA = task.code === "A";
  const coreContent = isTaskA ? `
    <section class="panel" aria-labelledby="contact-title">
      <div class="section-heading">
        <p class="eyebrow">接触状态</p>
        <h2 id="contact-title">先说有没有遇到，再说你怎么理解</h2>
        <p>“未到达”不会被当成失败；选择后只会展开你实际遇到过的部分。</p>
      </div>
      <div class="contact-grid">
        ${contactSelect("moment_1", "回到左侧建筑的那一刻")}
        ${contactSelect("moment_2", "这一段何时结束")}
        ${contactSelect("moment_3", "花和蜜蜂身上出现变化的一段")}
        ${contactSelect("moment_4", "敌害快速冲过来的一段")}
        ${contactSelect("moment_5", "体力发生变化的一段")}
        ${contactSelect("moment_6", "一次结束后重新开始")}
      </div>
      <div class="detail-grid">
        ${detailSection("moment_1", "回到左侧建筑的那一刻", [
          { name: "moment_1_recall_quote", label: "你当时为什么回去？回去以后觉得发生了什么？" },
        ])}
        ${detailSection("moment_2", "这一段何时结束", [
          { name: "moment_2_recall_quote", label: "你当时觉得这段什么时候会结束？你从画面哪里看出来的？" },
        ])}
        ${detailSection("moment_3", "花和蜜蜂身上的变化", [
          { name: "moment_3_recall_quote", label: "关于花、蜜蜂身上的东西和花后来的变化，你记得发生了什么？" },
        ])}
        ${detailSection("moment_4", "敌害快速冲过来的一段", [
          { name: "moment_4_recall_quote", label: "刚才敌害冲过来时，你觉得发生了什么？如果再遇到一次，你会怎么做？" },
          { name: "moment_4_repeat_opportunity", label: "过了一段时间以后，你有没有自然遇到类似情况？", placeholder: "有／没有／不确定；只记本轮真实发生的情况。" },
        ])}
        ${detailSection("moment_5", "体力发生变化的一段", [
          { name: "moment_5_recall_quote", label: "你注意到体力变化时做了什么，或者本来想做什么？" },
        ])}
        ${detailSection("moment_6", "一次结束后重新开始", [
          { name: "moment_6_recall_quote", label: "如果有结束或重新开始，当时为什么继续，或者为什么停下？" },
        ])}
      </div>
    </section>` : `
    <section class="panel" aria-labelledby="slice-title">
      <div class="section-heading">
        <p class="eyebrow">单切片任务</p>
        <h2 id="slice-title">只记录分配给你的这一段</h2>
        <p>没有到达不会被算作失败；不要为了填写而继续跑其他季节或其他 Boss。</p>
      </div>
      ${contactSelect("assigned_slice", task.assignment)}
      ${detailSection("assigned_slice", task.assignment, [
        { name: "assigned_slice_recall_quote", label: "你在这段里觉得主要发生了什么？" },
        { name: "assigned_slice_signal_quote", label: "你从哪些画面或声音判断下一步？" },
        { name: "assigned_slice_decision_quote", label: "你有没有因此改路线、顺序、撤离或资源选择？" },
        { name: "assigned_slice_pacing_quote", label: "哪里开始重复、无聊或太快？当时大约是 T+多少？" },
      ])}
    </section>`;

  return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="Content-Security-Policy" content="default-src 'self' blob:; img-src 'self' data:; style-src 'self'; script-src 'self'; connect-src 'none'; media-src 'none'">
  <title>《无名：成蜂》试玩记录 ${escapeHtml(sessionId)}</title>
  <link rel="stylesheet" href="styles.css">
</head>
<body data-session-id="${escapeHtml(sessionId)}" data-product-name="${escapeHtml(product.name)}" data-product-version="${escapeHtml(product.version)}" data-product-commit="${escapeHtml(product.commit)}" data-product-full-commit="${escapeHtml(product.full_commit)}" data-product-dirty="${product.dirty ? "true" : "false"}" data-artifact-sha256="${escapeHtml(product.artifact_sha256)}" data-task-code="${task.code}" data-task-assignment="${escapeHtml(task.assignment)}" data-task-maximum-minutes="${task.maximum_minutes}">
  <main class="shell">
    <header class="hero">
      <p class="eyebrow">LOCAL PLAYTEST · ${escapeHtml(sessionId)}</p>
      <h1>只记你实际遇到的。</h1>
      <p class="lede">没有标准答案，也不要求你通关。请先把本页放在一边自由玩，结束后再回来填写；没注意到、不记得、失败或提前停下都是真实有效的记录。现场观察者可以另行记录相对时间。</p>
      <dl class="build-card">
        <div><dt>任务</dt><dd>${escapeHtml(task.code)} · ${escapeHtml(task.assignment)}</dd></div>
        <div><dt>最长</dt><dd>${task.maximum_minutes} 分钟</dd></div>
        <div><dt>版本</dt><dd>${escapeHtml(versionLabel)}</dd></div>
        <div><dt>安装包 SHA-256</dt><dd><code>${escapeHtml(product.artifact_sha256)}</code></dd></div>
      </dl>
      ${product.dirty ? '<p class="warning">此记录由 dirty 工作区生成。它可以用于排查，但不能当作可重复的固定候选证据。</p>' : ""}
    </header>

    <form id="evidence-form">
      <section class="panel" aria-labelledby="setup-title">
        <div class="section-heading">
          <p class="eyebrow">开始前</p>
          <h2 id="setup-title">匿名环境信息</h2>
          <p>不要填写姓名、邮箱、手机号、账号、年龄、性别、精确位置、健康或残障信息。</p>
        </div>
        <div class="form-grid">
          <label class="field">证据身份
            <select name="tester_relation" required>
              <option value="">请选择</option>
              <option value="alan_self_test">Alan 本人自测</option>
              <option value="external_player">未参与策划／开发的外部玩家</option>
            </select>
          </label>
          <label class="field">记录来源
            <select name="evidence_channel" required>
              <option value="">请选择</option>
              <option value="onsite_observation">现场观察</option>
              <option value="remote_self_report">远程自报</option>
              <option value="consented_screen_recording">自愿匿名屏幕记录</option>
            </select>
          </label>
          <label class="field">运行平台
            <select name="platform" id="platform" required>
              <option value="">请选择</option>
              <option value="macos">macOS</option>
              <option value="windows">Windows</option>
              <option value="web">Web</option>
            </select>
          </label>
          <label class="field" id="windows-environment-field" hidden>Windows 运行环境
            <select name="windows_environment" disabled>
              <option value="">请选择</option>
              <option value="native_physical_hardware">真实 Windows 设备</option>
              <option value="virtual_machine">虚拟机</option>
              <option value="compatibility_layer">兼容层</option>
              <option value="unknown">不确定</option>
            </select>
          </label>
          <fieldset class="field full">
            <legend>实际使用的输入方式（可多选）</legend>
            <div class="choices">
              <label><input type="checkbox" name="input_methods" value="keyboard_mouse"> 键盘＋鼠标</label>
              <label><input type="checkbox" name="input_methods" value="trackpad"> 触控板</label>
              <label><input type="checkbox" name="input_methods" value="touchscreen"> 真实触屏</label>
              <label><input type="checkbox" name="input_methods" value="other"> 其他</label>
            </div>
          </fieldset>
        </div>
      </section>

      <section class="panel" aria-labelledby="recall-title">
        <div class="section-heading">
          <p class="eyebrow">先自由回忆</p>
          <h2 id="recall-title">不要回头重做来迎合问题</h2>
        </div>
        <div class="form-grid">
          <label class="field full">开始后一分钟，你记得自己先做了什么、卡在哪里？
            <textarea name="first_minute_quote" required placeholder="请用自己的话；不记得也可以直接写。"></textarea>
          </label>
          <label class="field">开始前是否有人解释操作、目标或正确做法？
            <select name="prior_external_explanation" required>
              <option value="">请选择</option>
              <option value="none">没有</option>
              <option value="after_explicit_request">我主动求助后才解释</option>
              <option value="before_play">开始前就解释过</option>
              <option value="unknown">不确定</option>
            </select>
          </label>
          <label class="field">最远到达哪里？
            <input name="furthest_reached_quote" required placeholder="用你看到的画面描述，不必知道关卡名">
          </label>
          <label class="field full">如果向游戏外的人求助，你当时原话问了什么？
            <textarea name="help_request_quote" required placeholder="没有求助就写“没有”。不要替自己润色。"></textarea>
          </label>
        </div>
      </section>

      <section class="panel" aria-labelledby="timer-title">
        <div class="section-heading">
          <p class="eyebrow">自由回忆之后再补</p>
          <h2 id="timer-title">相对时间（T0 = 首次取得控制权）</h2>
          <p>玩家不需要边玩边操作本页。现场观察者可在另一设备记录；远程玩家请把发生过但记不清秒数的事件选为“时间不可得”，不要补造精确时间。</p>
        </div>
        <div class="timer-row">
          <strong id="timer-display" aria-live="polite">尚未开始</strong>
          <button type="button" id="start-timer" class="primary">现场观察者：开始计时</button>
          <button type="button" id="finish-timer">现场观察者：结束计时</button>
          <button type="button" id="unavailable-timer">总时长不可得</button>
        </div>
        <div class="event-grid">
          ${timelineCard("event_1", "回到左侧建筑的一刻")}
          ${timelineCard("event_2", "第一次向游戏外的人提问")}
          ${timelineCard("event_3", "这一轮第一次结束")}
          ${timelineCard("event_4", "结束后第一次重新开始")}
        </div>
      </section>

      ${coreContent}

      <section class="panel" aria-labelledby="finish-title">
        <div class="section-heading">
          <p class="eyebrow">结束</p>
          <h2 id="finish-title">到这里就够了</h2>
        </div>
        <div class="form-grid">
          <label class="field">结束原因
            <select name="end_reason" required>
              <option value="">请选择</option>
              <option value="time_limit">到达本任务时间上限</option>
              <option value="finished_assignment">觉得已完成分配内容</option>
              <option value="stuck">卡住，不知道怎么继续</option>
              <option value="lost_interest">不想继续</option>
              <option value="technical_issue">技术问题</option>
              <option value="other">其他</option>
            </select>
          </label>
          <label class="field">这次还想马上再玩吗？
            <select name="replay_intent" required>
              <option value="">请选择</option>
              <option value="yes">想</option>
              <option value="after_changes">改一些问题后想</option>
              <option value="no">不想</option>
              <option value="unsure">不确定</option>
            </select>
          </label>
          <label class="field full">请用一句自己的话描述这次游戏
            <textarea name="player_summary_quote" required placeholder="原话即可，不用替游戏宣传。"></textarea>
          </label>
          <label class="field full">最后还有什么想说的？
            <textarea name="final_comment_quote" placeholder="没注意到、不喜欢、说不清楚都可以。"></textarea>
          </label>
        </div>
      </section>
    </form>
  </main>

  <div class="sticky-actions" aria-label="记录操作">
    <button id="save-button" type="button">保存到本机</button>
    <button id="export-button" class="primary" type="button">导出匿名 JSON</button>
    <button id="reset-button" class="danger" type="button">清空</button>
    <span id="save-status" aria-live="polite">尚未保存</span>
  </div>
  <script src="review.js"></script>
</body>
</html>
`;
}

const participantCss = `
:root { color-scheme: dark; font-family: Inter, "PingFang SC", "Microsoft YaHei", system-ui, sans-serif; background: #101713; color: #f3ecd7; font-synthesis: none; }
* { box-sizing: border-box; }
body { margin: 0; min-width: 320px; background: radial-gradient(circle at 15% 0, rgba(219, 174, 62, 0.15), transparent 30rem), linear-gradient(160deg, #15241e, #0d1411 68%); }
button, input, select, textarea { font: inherit; }
button, input, select, textarea { border: 1px solid #52675a; border-radius: 0.65rem; background: #18251f; color: #f3ecd7; }
button { padding: 0.7rem 0.9rem; cursor: pointer; }
button:hover, button:focus-visible, input:focus-visible, select:focus-visible, textarea:focus-visible { border-color: #e3b746; outline: 2px solid rgba(227, 183, 70, 0.25); }
input, select, textarea { width: 100%; padding: 0.68rem 0.75rem; }
textarea { min-height: 6rem; resize: vertical; line-height: 1.55; }
input[type="checkbox"] { width: auto; accent-color: #e3b746; }
fieldset { margin: 0; padding: 0; border: 0; }
.shell { width: min(1120px, calc(100% - 2rem)); margin: 0 auto; padding: 2.5rem 0 7rem; }
.hero { padding: 1rem 0 2rem; }
.eyebrow { margin: 0 0 0.5rem; color: #e3b746; font-size: 0.76rem; font-weight: 800; letter-spacing: 0.16em; }
h1, h2, h3, p { margin-top: 0; }
h1 { max-width: 16ch; margin-bottom: 0.6rem; font-size: clamp(2.3rem, 7vw, 4.8rem); line-height: 1; }
.lede, .section-heading p { max-width: 68ch; color: #bcc9c0; line-height: 1.75; }
.build-card { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0.75rem; margin: 1.5rem 0 0; }
.build-card div { min-width: 0; padding: 0.9rem; border: 1px solid #405348; border-radius: 0.8rem; background: rgba(24, 37, 31, 0.8); }
.build-card dt { color: #91a89a; font-size: 0.75rem; }
.build-card dd { margin: 0.25rem 0 0; overflow-wrap: anywhere; }
.warning { margin-top: 1rem; padding: 0.8rem; border: 1px solid #a86951; border-radius: 0.7rem; color: #ffc8af; }
.panel { margin-bottom: 1rem; padding: clamp(1rem, 3vw, 1.7rem); border: 1px solid #405348; border-radius: 1rem; background: rgba(20, 33, 27, 0.94); box-shadow: 0 16px 44px rgba(0, 0, 0, 0.2); }
.section-heading { margin-bottom: 1.2rem; }
.section-heading h2 { margin-bottom: 0.35rem; font-size: clamp(1.4rem, 4vw, 2rem); }
.section-heading p { margin-bottom: 0; }
.form-grid, .contact-grid, .detail-grid, .event-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0.9rem; }
.field { display: grid; align-content: start; gap: 0.4rem; color: #e4e2d7; }
.full { grid-column: 1 / -1; }
.choices { display: flex; flex-wrap: wrap; gap: 0.7rem 1rem; }
.choices label { display: inline-flex; align-items: center; gap: 0.4rem; color: #cad3cc; }
.contact-grid { margin-bottom: 1rem; }
.detail-card, .event-card { padding: 1rem; border: 1px solid #35483d; border-radius: 0.8rem; background: #111d18; }
.detail-card h3, .event-card h3 { margin-bottom: 0.7rem; color: #e3b746; }
.detail-card[hidden] { display: none; }
.timer-row { display: flex; flex-wrap: wrap; align-items: center; gap: 0.65rem; margin-bottom: 1rem; }
#timer-display { min-width: 9rem; font-variant-numeric: tabular-nums; }
.event-value { min-height: 1.5rem; color: #aabbb0; }
.event-actions { display: flex; flex-wrap: wrap; gap: 0.45rem; }
.event-actions button { padding: 0.55rem 0.65rem; font-size: 0.82rem; }
.quiet { color: #9fb1a5; }
.primary { border-color: #e3b746; background: #d8aa35; color: #172017; font-weight: 800; }
.danger { color: #efb6a2; }
.sticky-actions { position: fixed; z-index: 10; right: 1rem; bottom: 1rem; left: 1rem; display: flex; align-items: center; justify-content: center; gap: 0.6rem; width: fit-content; max-width: calc(100% - 2rem); margin: auto; padding: 0.7rem; border: 1px solid #52675a; border-radius: 1rem; background: rgba(10, 17, 14, 0.95); backdrop-filter: blur(12px); }
#save-status { min-width: 7rem; color: #9fb1a5; font-size: 0.78rem; text-align: center; }
@media (max-width: 720px) { .shell { width: min(100% - 1rem, 42rem); padding-top: 1rem; } .build-card, .form-grid, .contact-grid, .detail-grid, .event-grid { grid-template-columns: 1fr; } .full { grid-column: auto; } .sticky-actions { overflow-x: auto; justify-content: flex-start; } .sticky-actions button { flex: 0 0 auto; } }
`;

function participantJavaScript() {
  return `
const schemaVersion = ${schemaVersion};
const timelineEventIds = ${JSON.stringify(timelineEventIds)};
${arrayValue.toString()}
${normalizeTimelineEvent.toString()}
${buildEvidencePayload.toString()}

const form = document.querySelector("#evidence-form");
const saveStatus = document.querySelector("#save-status");
const timerDisplay = document.querySelector("#timer-display");
const body = document.body;
const storageKey = "nameless-playtest-evidence-v1-" + body.dataset.sessionId;
const eventIds = timelineEventIds;
let events = Object.fromEntries(eventIds.map((id) => [id, { status: "not_recorded", elapsed_seconds: null }]));
let timer = { started_at_epoch_ms: null, ended_elapsed_seconds: null, status: "not_recorded" };
let timerInterval = null;

const product = {
  name: body.dataset.productName,
  version: body.dataset.productVersion,
  commit: body.dataset.productCommit,
  full_commit: body.dataset.productFullCommit,
  dirty: body.dataset.productDirty === "true",
  artifact_sha256: body.dataset.artifactSha256,
};
const task = {
  code: body.dataset.taskCode,
  assignment: body.dataset.taskAssignment,
  maximum_minutes: Number(body.dataset.taskMaximumMinutes),
};

function formAnswers() {
  const answers = {};
  for (const [key, value] of new FormData(form).entries()) {
    if (Object.hasOwn(answers, key)) {
      answers[key] = Array.isArray(answers[key]) ? [...answers[key], value] : [answers[key], value];
    } else {
      answers[key] = value;
    }
  }
  return answers;
}

function elapsedSeconds() {
  if (timer.status === "unavailable" || timer.status === "not_recorded") return null;
  if (timer.ended_elapsed_seconds !== null) return timer.ended_elapsed_seconds;
  if (timer.started_at_epoch_ms === null) return null;
  return Math.max(0, Math.round((Date.now() - timer.started_at_epoch_ms) / 1000));
}

function formatElapsed(seconds) {
  if (seconds === null || !Number.isFinite(seconds)) return "时间不可得";
  const minutes = Math.floor(seconds / 60);
  const rest = Math.floor(seconds % 60);
  return "T+" + String(minutes).padStart(2, "0") + ":" + String(rest).padStart(2, "0");
}

function refreshTimer() {
  if (timer.status === "unavailable") {
    timerDisplay.textContent = "总时长不可得";
    return;
  }
  const elapsed = elapsedSeconds();
  timerDisplay.textContent = elapsed === null ? "尚未开始" : formatElapsed(elapsed) + (timer.ended_elapsed_seconds !== null ? " · 已结束" : "");
}

function eventLabel(value) {
  if (value.status === "occurred_timed") return "已记录 " + formatElapsed(value.elapsed_seconds);
  if (value.status === "occurred_time_unavailable") return "已发生 · 时间不可得";
  if (value.status === "did_not_occur") return "本轮未发生";
  return "尚未记录";
}

function refreshEvents() {
  for (const id of eventIds) document.querySelector('[data-event-value="' + id + '"]').textContent = eventLabel(events[id]);
}

function refreshContactSections() {
  for (const select of document.querySelectorAll("[data-contact]")) {
    const detail = document.querySelector('[data-contact-details="' + select.dataset.contact + '"]');
    if (!detail) continue;
    const show = select.value !== "" && select.value !== "not_reached";
    detail.hidden = !show;
    for (const control of detail.querySelectorAll("input, select, textarea")) control.disabled = !show;
  }
}

function refreshWindowsField() {
  const field = document.querySelector("#windows-environment-field");
  const select = field.querySelector("select");
  const show = document.querySelector("#platform").value === "windows";
  field.hidden = !show;
  select.disabled = !show;
  select.required = show;
  if (!show) select.value = "";
}

function setStatus(message) { saveStatus.textContent = message; }

function localState() {
  return { schema_version: 1, answers: formAnswers(), events, timer };
}

function save() {
  try {
    localStorage.setItem(storageKey, JSON.stringify(localState()));
    setStatus("已保存在本机");
  } catch {
    setStatus("请直接导出 JSON");
  }
}

function restore() {
  let saved;
  try { saved = JSON.parse(localStorage.getItem(storageKey) || "null"); } catch { return; }
  if (!saved || saved.schema_version !== 1) return;
  for (const control of form.elements) {
    if (!control.name) continue;
    const value = saved.answers?.[control.name];
    if (control.type === "checkbox" || control.type === "radio") {
      const values = Array.isArray(value) ? value : [value];
      control.checked = values.includes(control.value);
    } else if (typeof value === "string") {
      control.value = value;
    }
  }
  events = Object.fromEntries(eventIds.map((id) => [id, normalizeTimelineEvent(saved.events?.[id])]));
  if (saved.timer && (saved.timer.started_at_epoch_ms === null || Number.isFinite(saved.timer.started_at_epoch_ms))) {
    timer = {
      started_at_epoch_ms: saved.timer.started_at_epoch_ms,
      ended_elapsed_seconds: saved.timer.ended_elapsed_seconds ?? null,
      status: ["not_recorded", "running", "recorded", "unavailable"].includes(saved.timer.status) ? saved.timer.status : "not_recorded",
    };
  }
  setStatus("已恢复本机记录");
}

function buildCurrentPayload(exportedAt) {
  return buildEvidencePayload({
    product,
    task,
    sessionId: body.dataset.sessionId,
    answers: formAnswers(),
    events,
    sessionDurationSeconds: elapsedSeconds(),
    sessionDurationStatus: timer.status === "unavailable" ? "unavailable" : timer.status === "not_recorded" ? "not_recorded" : "recorded",
    exportedAt,
  });
}

function exportResults() {
  refreshWindowsField();
  refreshContactSections();
  if (!form.reportValidity()) {
    setStatus("请先补全必填项");
    return;
  }
  if (![...form.querySelectorAll('[name="input_methods"]')].some((control) => control.checked)) {
    setStatus("请至少选择一种输入方式");
    return;
  }
  const missingEvent = eventIds.find((id) => events[id].status === "not_recorded");
  if (missingEvent) {
    setStatus("请明确记录四个首次事件是否发生");
    document.querySelector('[data-event-card="' + missingEvent + '"]').scrollIntoView({ behavior: "smooth", block: "center" });
    return;
  }
  if (timer.status === "not_recorded") {
    setStatus("请记录总时长或标记不可得");
    return;
  }
  if (timer.status === "running") {
    timer.ended_elapsed_seconds = elapsedSeconds();
    timer.status = "recorded";
    window.clearInterval(timerInterval);
    refreshTimer();
  }
  save();
  const payload = buildCurrentPayload(new Date().toISOString());
  const blob = new Blob([JSON.stringify(payload, null, 2) + "\\n"], { type: "application/json" });
  const link = document.createElement("a");
  link.href = URL.createObjectURL(blob);
  const safeCode = (payload.evidence.participant_code || "anonymous").replace(/[^a-zA-Z0-9_-]+/g, "-").slice(0, 24);
  link.download = "playtest-" + body.dataset.sessionId + "-" + safeCode + ".json";
  link.click();
  URL.revokeObjectURL(link.href);
  setStatus("匿名结果已导出");
}

document.querySelector("#start-timer").addEventListener("click", () => {
  if (timer.started_at_epoch_ms === null) timer.started_at_epoch_ms = Date.now();
  timer.ended_elapsed_seconds = null;
  timer.status = "running";
  window.clearInterval(timerInterval);
  timerInterval = window.setInterval(refreshTimer, 1000);
  refreshTimer();
  save();
});

document.querySelector("#finish-timer").addEventListener("click", () => {
  if (timer.started_at_epoch_ms !== null && timer.ended_elapsed_seconds === null) {
    timer.ended_elapsed_seconds = elapsedSeconds();
    timer.status = "recorded";
  }
  window.clearInterval(timerInterval);
  refreshTimer();
  save();
});

document.querySelector("#unavailable-timer").addEventListener("click", () => {
  timer = { started_at_epoch_ms: null, ended_elapsed_seconds: null, status: "unavailable" };
  window.clearInterval(timerInterval);
  refreshTimer();
  save();
});

for (const button of document.querySelectorAll("[data-event-action]")) {
  button.addEventListener("click", () => {
    const id = button.dataset.eventId;
    if (button.dataset.eventAction === "timed") {
      const elapsed = elapsedSeconds();
      if (elapsed === null) {
        setStatus("先在取得控制权时开始计时");
        return;
      }
      events[id] = { status: "occurred_timed", elapsed_seconds: elapsed };
    } else if (button.dataset.eventAction === "unavailable") {
      events[id] = { status: "occurred_time_unavailable", elapsed_seconds: null };
    } else if (button.dataset.eventAction === "absent") {
      events[id] = { status: "did_not_occur", elapsed_seconds: null };
    } else {
      events[id] = { status: "not_recorded", elapsed_seconds: null };
    }
    refreshEvents();
    save();
  });
}

form.addEventListener("input", () => {
  refreshContactSections();
  refreshWindowsField();
  setStatus("有未导出的修改");
  window.clearTimeout(form.saveTimer);
  form.saveTimer = window.setTimeout(save, 350);
});
form.addEventListener("submit", (event) => event.preventDefault());
document.querySelector("#save-button").addEventListener("click", save);
document.querySelector("#export-button").addEventListener("click", exportResults);
document.querySelector("#reset-button").addEventListener("click", () => {
  if (!window.confirm("清空本页填写内容和本机记录？已导出的 JSON 不受影响。")) return;
  form.reset();
  events = Object.fromEntries(eventIds.map((id) => [id, { status: "not_recorded", elapsed_seconds: null }]));
  timer = { started_at_epoch_ms: null, ended_elapsed_seconds: null, status: "not_recorded" };
  window.clearInterval(timerInterval);
  try { localStorage.removeItem(storageKey); } catch { /* Export remains available. */ }
  refreshWindowsField();
  refreshContactSections();
  refreshEvents();
  refreshTimer();
  setStatus("已清空");
});

restore();
refreshWindowsField();
refreshContactSections();
refreshEvents();
refreshTimer();
if (timer.status === "running") timerInterval = window.setInterval(refreshTimer, 1000);
`;
}

function coordinatorReadme({ product, sourceIdentity, task, sessionId }) {
  return `# 试玩协调说明（不要发给参与者）

本次会话：\`${sessionId}\`  
参与者任务：\`${task.code} · ${task.assignment}\`，最多 ${task.maximum_minutes} 分钟  
候选：\`${product.version} · ${product.commit}${product.dirty ? " +dirty" : ""}\`  
安装包 SHA-256：\`${product.artifact_sha256}\`

## 只交付什么

只把同级的 \`participant/\` 文件夹交给参与者，并让其打开 \`index.html\`。不要把本 \`coordinator/\` 目录一起发出。参与者页面不含正确操作、开发者解释或后续优先级。

## 怎么做

1. 核对参与者实际启动的候选版本、8 位提交号与上方一致；安装包哈希不一致时停止记录。
2. A 包只测陌生玩家的首节点，T0 从首次取得控制权开始，最多 15 分钟；不要要求跑完 24 节点。
3. B 包当前阻塞：正式游戏只能从首节点开始，还没有绑定同一 artifact／哈希的固定单切片入口。入口实现并固定以前，不得让玩家先跑前置节点来冒充单切片测试。
4. C 包是独立音乐任务，使用 \`npm run audio:review\`，不要与 A/B 的长流程混做。
5. 开始前不解释操作、目标或设计意图。参与者明确求助后，可以给最少必要帮助，但必须记录 T+时间与其求助原话。
6. 当前正常首轮路线没有稳定的“三分钟后再次急转”机会。只记录参与者是否自然遇到复测机会；没有机会不能判定迁移失败。
7. 远程无观察、无录像或参与者记不清时，把精确时间记为“不可得”，不能补造。
8. 收到 JSON 后，将客观观察、玩家逐字原话、开发者解释和后续动作分别写入 \`analysis-template.json\` 的四个数组；不要润色玩家原话。

A 包内部映射只留在这里：时间线 \`event_1\` 第一次交蜜、\`event_2\` 第一次游戏外求助、\`event_3\` 第一次失败、\`event_4\` 第一次重开；接触状态 \`moment_1\` 第一次交蜜、\`moment_2\` 完成条件、\`moment_3\` 传粉、\`moment_4\` 急转、\`moment_5\` 饮蜜、\`moment_6\` 重开。参与者端故意只显示中性场景描述；分析时也应先保存其原话，再做机制归类。

## 证据分类

- \`tester_relation = alan_self_test\` 只算 Alan 自测，不能计入外部玩家样本。
- \`tester_relation = external_player\` 且参与者未参与策划／开发，才算外部玩家记录。
- Windows 发布证据由 \`platform = windows\` 与 \`windows_environment = native_physical_hardware\` 单独判定；它不会自动变成外部玩家证据。
- 同一份记录可以同时来自外部玩家和真实 Windows 设备，但两种结论仍要分别汇总。

## 隐私

不收姓名、联系方式、账号、IP、年龄、性别、精确位置、健康／残障信息、脸或声音。若参与者自愿匿名录屏，先说明用途，允许关闭麦克风并裁掉通知；录屏文件引用只保存在内部分析，不进入参与者表单。

生成工具来源：\`${sourceIdentity.full_commit}\`${sourceIdentity.dirty ? "（生成时工作区有改动）" : "（生成时工作区干净）"}。
`;
}

function analysisTemplate({ product, task, sessionId }) {
  return {
    schema_version: schemaVersion,
    session_id: sessionId,
    candidate: product,
    task,
    participant_export_file: "",
    field_schema: {
      objective_observations: {
        required: ["event_id", "source", "elapsed", "text"],
        rule: "Only directly observable events or state. Use T+mm:ss when observed; otherwise set elapsed to unavailable.",
      },
      verbatim_player_quotes: {
        required: ["event_id", "source", "elapsed", "text"],
        rule: "Copy exact player wording without polishing, interpretation, or inserted game terminology.",
      },
      developer_interpretations: {
        required: ["evidence_refs", "text", "confidence"],
        rule: "Keep hypotheses separate and cite observation or quote event_ids; confidence is low, medium, or high.",
      },
      follow_up_actions: {
        required: ["evidence_refs", "action", "status"],
        rule: "Record a concrete action or explicit no-action decision; status is proposed, accepted, or no_action.",
      },
      analyst_confidence: "low, medium, or high; keep uncertainty visible.",
    },
    objective_observations: [],
    verbatim_player_quotes: [],
    developer_interpretations: [],
    follow_up_actions: [],
    analyst_confidence: "",
    evidence_classification: {
      counts_as_external_player: null,
      counts_as_windows_native_hardware: null,
    },
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
  if (code === "B") {
    throw new Error("Task B is blocked until the game has a fixed single-slice entry bound to the same artifact and hash. This generator currently prepares Task A only.");
  }
  if (code !== "A") throw new Error("--task must be A. Music task C uses npm run audio:review.");
  return {
    code,
    assignment: "首次体验：首节点",
    internal_assignment: "",
    maximum_minutes: 15,
  };
}

function isWithin(parent, candidate) {
  const path = relative(parent, candidate);
  return path === "" || (!path.startsWith("..") && !isAbsolute(path));
}

function validateResolvedOutput(output) {
  if (output === parse(output).root) throw new Error("Refusing to replace a filesystem root.");
  if (isWithin(output, repositoryRoot)) throw new Error("Refusing the repository or one of its ancestors as output.");
  if (isWithin(repositoryRoot, output) && !isWithin(resolve(repositoryRoot, "outputs"), output)) {
    throw new Error("Output inside the repository must stay under outputs/.");
  }
}

async function validateOutputTarget(outputDirectory) {
  const output = resolve(outputDirectory);
  validateResolvedOutput(output);

  let existingAncestor = output;
  const missingSegments = [];
  while (true) {
    try {
      await lstat(existingAncestor);
      break;
    } catch (error) {
      if (error?.code !== "ENOENT") throw error;
      const parent = dirname(existingAncestor);
      if (parent === existingAncestor) throw new Error(`Unable to resolve output target: ${output}.`);
      missingSegments.unshift(basename(existingAncestor));
      existingAncestor = parent;
    }
  }
  const physicalOutput = resolve(await realpath(existingAncestor), ...missingSegments);
  validateResolvedOutput(physicalOutput);
  return output;
}

async function assertReplaceableOutput(output) {
  let status;
  try {
    status = await lstat(output);
  } catch (error) {
    if (error?.code === "ENOENT") return false;
    throw error;
  }
  if (!status.isDirectory()) throw new Error(`Refusing to replace non-directory output: ${output}.`);
  let sentinel;
  try {
    sentinel = await readFile(resolve(output, outputSentinelName), "utf8");
  } catch (error) {
    if (error?.code === "ENOENT") throw new Error(`Refusing to replace existing directory without ${outputSentinelName}: ${output}.`);
    throw error;
  }
  if (sentinel !== outputSentinel) throw new Error(`Refusing to replace existing directory with an invalid ${outputSentinelName}: ${output}.`);
  return true;
}

export async function generatePlaytestEvidence(outputDirectory, options = {}) {
  const sourceIdentity = await readProductIdentity();
  const task = validateTask(options.taskCode);
  const artifactSha256 = validateSha256(options.artifactSha256);
  if (options.candidateCommit && typeof options.candidateDirty !== "boolean") {
    throw new Error("A fixed --candidate-commit also requires exactly one of --candidate-clean or --candidate-dirty.");
  }
  const candidateIdentity = options.candidateCommit
    ? await readCandidateIdentity(options.candidateCommit)
    : sourceIdentity;
  const product = {
    name: candidateIdentity.name,
    version: candidateIdentity.version,
    commit: candidateIdentity.commit,
    full_commit: candidateIdentity.full_commit,
    dirty: options.candidateCommit ? options.candidateDirty : sourceIdentity.dirty,
    artifact_sha256: artifactSha256,
  };
  const sessionId = options.sessionId || `NB-${new Date().toISOString().slice(0, 10).replaceAll("-", "")}-${randomBytes(4).toString("hex").toUpperCase()}`;
  if (!/^[A-Z0-9-]{8,40}$/u.test(sessionId)) throw new Error("Invalid session ID.");
  const output = await validateOutputTarget(outputDirectory || resolve(defaultOutputRoot, sessionId));

  const stage = `${output}.stage-${process.pid}-${Date.now()}`;
  const participantDirectory = resolve(stage, "participant");
  const coordinatorDirectory = resolve(stage, "coordinator");
  const replaceExisting = await assertReplaceableOutput(output);
  await mkdir(dirname(output), { recursive: true });
  await mkdir(participantDirectory, { recursive: true });
  await mkdir(coordinatorDirectory, { recursive: true });

  try {
    const manifest = {
      schema_version: schemaVersion,
      session_id: sessionId,
      candidate: product,
      task,
      participant_entry: "../participant/index.html",
      generator_source: sourceIdentity,
      generated_at: new Date().toISOString(),
    };
    await Promise.all([
      writeFile(resolve(participantDirectory, "index.html"), participantHtml({ product, task, sessionId }), "utf8"),
      writeFile(resolve(participantDirectory, "styles.css"), participantCss, "utf8"),
      writeFile(resolve(participantDirectory, "review.js"), participantJavaScript(), "utf8"),
      writeFile(resolve(coordinatorDirectory, "README.md"), coordinatorReadme({ product, sourceIdentity, task, sessionId }), "utf8"),
      writeFile(resolve(coordinatorDirectory, "analysis-template.json"), `${JSON.stringify(analysisTemplate({ product, task, sessionId }), null, 2)}\n`, "utf8"),
      writeFile(resolve(coordinatorDirectory, "manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`, "utf8"),
      writeFile(resolve(stage, outputSentinelName), outputSentinel, "utf8"),
    ]);

    if (replaceExisting) {
      await assertReplaceableOutput(output);
      await rm(output, { recursive: true, force: true });
    }
    await rename(stage, output);
  } catch (error) {
    await rm(stage, { recursive: true, force: true });
    throw error;
  }

  return {
    output,
    participant: resolve(output, "participant/index.html"),
    coordinator: resolve(output, "coordinator/README.md"),
    sessionId,
    product,
    task,
  };
}

function flagValue(name) {
  const index = process.argv.indexOf(name);
  if (index < 0) return undefined;
  const value = process.argv[index + 1];
  if (!value || value.startsWith("--")) throw new Error(`${name} requires a value.`);
  return value;
}

async function main() {
  const requestedOutput = flagValue("--output") || process.env.NAMELESS_PLAYTEST_OUTPUT;
  const artifactSha256 = flagValue("--artifact-sha256") || process.env.NAMELESS_PLAYTEST_ARTIFACT_SHA256;
  const taskCode = flagValue("--task") || "A";
  const candidateCommit = flagValue("--candidate-commit");
  const candidateClean = process.argv.includes("--candidate-clean");
  const candidateDirty = process.argv.includes("--candidate-dirty");
  if (candidateClean && candidateDirty) throw new Error("Use only one of --candidate-clean or --candidate-dirty.");
  if (!candidateCommit && (candidateClean || candidateDirty)) throw new Error("--candidate-clean/--candidate-dirty requires --candidate-commit.");
  const result = await generatePlaytestEvidence(requestedOutput, {
    artifactSha256,
    taskCode,
    candidateCommit,
    candidateDirty: candidateClean ? false : candidateDirty ? true : undefined,
  });
  const outputLabel = relative(repositoryRoot, result.output) || result.output;
  console.log(`Prepared playtest evidence package ${result.sessionId} at ${outputLabel}.`);
  console.log(`Give only this folder to the participant: ${dirname(result.participant)}`);
  console.log(`Coordinator instructions (keep separate): ${result.coordinator}`);
}

const invokedPath = process.argv[1] ? resolve(process.argv[1]) : "";
if (invokedPath === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  });
}
