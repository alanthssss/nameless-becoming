import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { lstat, mkdir, mkdtemp, readFile, realpath, writeFile } from "node:fs/promises";
import { basename, dirname, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { commercialArtFilenames } from "./create_commercial_godot_stage.mjs";
import { generateArtifactManifest, PLATFORM_ARTIFACTS } from "./generate_artifact_manifest.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
export const documents = Object.freeze([
  "docs/ART_REVIEW_HANDOFF.md",
  "docs/design/commercial-product-requirements.md",
  "docs/design/solar-term-campaign-production-spec.md",
  "docs/design/narrative-framework.md",
  "docs/design/art-source-register.md",
  "godot/data/credits_and_licenses.json",
  "godot/fonts/OFL-NotoSansCJK.txt",
  "marketing/README.md",
]);
const historicalShots = ["01-hive", "02-spring", "03-summer", "04-autumn", "05-winter", "06-finale"];
const storeImages = [
  "library-logo-light-1600x520.png", "library-logo-dark-1600x520.png",
  "library-hero-3840x1240.png", "library-capsule-600x900.png",
  "store-header-920x430.png", "store-main-1232x706.png",
  "store-small-462x174.png", "store-vertical-748x896.png",
];
export const materialPaths = Object.freeze([
  ...documents,
  ...commercialArtFilenames.map((name) => `godot/assets/art/commercial/${name}`),
  ...historicalShots.map((name) => `marketing/screenshots/${name}-developer-capture.png`),
  "marketing/screenshots/developer-capture-manifest.json",
  "marketing/key-art/see-you-at-the-hive-key-art-base-v1.png",
  "marketing/brand/see-you-at-the-hive-wordmark.svg",
  "marketing/store-candidates/candidate-manifest.json",
  ...storeImages.map((name) => `marketing/store-candidates/${name}`),
]);

export const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");
export const escapeHtml = (text) => String(text).replace(/[&<>"']/gu, (c) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
})[c]);
export const redactLocalPaths = (text) => text.replace(/\/(?:Users|home)\/[^\s`"'<>）。，；]+/gu, "[本机路径已省略]");

export function gitIdentity(repositoryRoot = root) {
  const git = (args) => execFileSync("git", args, { cwd: repositoryRoot, encoding: "utf8" }).trim();
  if (git(["status", "--porcelain=v1", "--untracked-files=all"])) {
    throw new Error("Art review requires a clean committed worktree; preserve unrelated changes in a separate worktree.");
  }
  const commit = git(["rev-parse", "HEAD"]);
  if (!/^[a-f0-9]{40}$/u.test(commit)) throw new Error("Expected full Git SHA.");
  return { commit, dirty: false };
}

export async function readMaterial(repositoryRoot, path) {
  if (!materialPaths.includes(path)) throw new Error(`Material is not allowlisted: ${path}`);
  const fullPath = resolve(repositoryRoot, path);
  const realRoot = await realpath(repositoryRoot);
  if (await realpath(fullPath) !== join(realRoot, path) || !(await lstat(fullPath)).isFile()) {
    throw new Error(`Material must be a regular, non-symlink file: ${path}`);
  }
  execFileSync("git", ["ls-files", "--error-unmatch", "--", path], { cwd: repositoryRoot, stdio: "pipe" });
  return readFile(fullPath);
}

export function validateArtifact(manifest, bytes, identity, platform) {
  if (manifest.schema_version !== 1 || manifest.commit !== identity.commit || manifest.dirty !== false
    || manifest.product_version !== identity.product_version || manifest.platform !== platform
    || manifest.filename !== PLATFORM_ARTIFACTS[platform] || manifest.size !== bytes.length
    || bytes.length === 0 || manifest.sha256 !== sha256(bytes)) {
    throw new Error(`Artifact identity or checksum mismatch: ${platform}`);
  }
}

export function pngDimensions(bytes) {
  if (bytes.length < 24 || bytes.subarray(0, 8).toString("hex") !== "89504e470d0a1a0a"
    || bytes.subarray(12, 16).toString() !== "IHDR") throw new Error("Invalid PNG header.");
  return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20) };
}

function run(command, args) {
  execFileSync(command, args, { cwd: root, stdio: "inherit" });
}

async function buildGames() {
  if (process.platform !== "darwin") throw new Error("art:build requires macOS for signing; use Desktop client builds on CI.");
  gitIdentity();
  const godot = process.env.GODOT_BIN || "godot";
  if (!execFileSync(godot, ["--version"], { encoding: "utf8" }).startsWith("4.6.2.")) {
    throw new Error("Godot 4.6.2 is required.");
  }
  run("npm", ["run", "test:godot"]);
  // Clear identity overrides: metadata must describe this actual checkout.
  const identity = gitIdentity();
  const pkg = JSON.parse(await readFile(join(root, "package.json"), "utf8"));
  await writeFile(join(root, "godot/data/build_provenance.json"), JSON.stringify({
    schema_version: 1, product_version: pkg.version, ...identity,
  }, null, 2) + "\n");
  await mkdir(join(root, "builds"), { recursive: true });
  for (const [preset, filename] of [["macOS", PLATFORM_ARTIFACTS["macos-universal"]], ["Windows Desktop", PLATFORM_ARTIFACTS["windows-x86_64"]]]) {
    run("bash", ["scripts/with_commercial_godot_cache.sh", godot, "--path", "godot", "--headless", "--export-release", preset, join(root, "builds", filename)]);
  }
  run("sh", ["scripts/package_macos.sh"]);
  for (const filename of Object.values(PLATFORM_ARTIFACTS)) {
    const bytes = await readFile(join(root, "builds", filename));
    await writeFile(join(root, "builds", `${filename}.sha256`), `${sha256(bytes)}  ${filename}\n`);
  }
}

const boundaries = [
  "内部美术专家评审候选；不是可售成品或公开营销许可。产品名仍在重评。",
  "运行候选：AUTH-PENDING / ALAN-PENDING / PLAYER-PENDING / MKT-NO。",
  "六张 Journey 截图是历史开发者采集，不是本包 Campaign 同提交截图；概念图不是玩法画面。",
  "自动验证只证明来源／包完整性；不代表真人全流程、设备手感、声音或授权验收。",
  "无完整分层源和动画；资料里的计划不等于已实现。专家意见记为专家启发式，不冒充外部玩家证据。",
];

function firstRead(identity) {
  return `一会儿巢里见 · 美术专家评审包\n\n版本：${identity.product_version}\n完整提交：${identity.commit}\n生成时间（UTC）：${identity.generated_at}\n工作树：clean\n\n先完整解压，再双击 START_HERE.html：离线图册无需联网、无需安装引擎。\n游戏文件位于 game/：Windows 运行 EXE；macOS 再解压 ZIP 后打开「一会儿巢里见.app」。\nWindows 未做发行签名；macOS 为 ad-hoc 签名／未公证；只运行可信发送者的包，不关闭系统全局安全防护。\n游戏使用本地单存档；首次试玩可新建旅程，已有存档的设备不要未经备份点新旅程覆盖进度。\n操作以游戏内提示为准：方向键／WASD 移动，空格情境动作，Q 次要动作／返巢，Esc 暂停。\n建议先体验标题→主巢→立春出巢→交互→回巢接货，再用图册直接查看四季资产，无需通关全年。\n\n${boundaries.join("\n")}\n\n请填写 FEEDBACK.md 并附问题截图；不要直接改写原图。\nSHA-256：MANIFEST.json 列出包内文件；外部 .sha256 验证整个 ZIP。\nWindows: Get-FileHash -Algorithm SHA256 <zip文件>\nmacOS: shasum -a 256 <zip文件>\n`;
}

function feedback(identity) {
  return `# 美术专家反馈\n\n版本：${identity.product_version}\n提交：${identity.commit}\n\n评审人／日期：\n系统／分辨率／缩放：\n实际试玩范围与时间：\n意见类别：[专家启发式]（如仅看图请明确写未试玩）\n\n## 最值得保留的三点\n\n1.\n2.\n3.\n\n## 优先修改的问题（复制本节逐项填写）\n\n- 文件名或场景／状态：\n- 截图编号／时间点：\n- 实际观察（不混入推测）：\n- 对可读性／风格／动作的影响：\n- 严重度：阻断理解／明显影响／润色\n- 修改建议及验收方式：\n- 估计工作量范围、依赖与不确定性：\n\n## 下一步三个样板与所需源文件\n\n## 未覆盖范围\n\n## 需要 Alan 决定的问题\n\n本反馈不构成授权审计、商业终稿批准或独立玩家验收。\n`;
}

export async function packageArtReview({ output = join(root, "outputs/art-review") } = {}) {
  const identity = { ...gitIdentity(), product_version: JSON.parse(await readFile(join(root, "package.json"), "utf8")).version };
  if (!/^[0-9A-Za-z][0-9A-Za-z.+-]*$/u.test(identity.product_version)) throw new Error("Unsafe version string.");
  const gameFiles = [];
  for (const [platform, filename] of Object.entries(PLATFORM_ARTIFACTS)) {
    // Re-inspect the immutable PCK inside the real game, not a caller-supplied JSON assertion.
    const { manifest } = await generateArtifactManifest({ artifactPath: join(root, "builds", filename), platform });
    const bytes = await readFile(join(root, "builds", filename));
    validateArtifact(manifest, bytes, identity, platform);
    gameFiles.push({ platform, filename, bytes, manifest });
  }
  const materials = [];
  for (const path of materialPaths) materials.push({ path, bytes: await readMaterial(root, path) });
  const artRegister = materials.find((item) => item.path === "docs/design/art-source-register.md").bytes.toString("utf8");
  for (const name of commercialArtFilenames) {
    const item = materials.find((item) => item.path === `godot/assets/art/commercial/${name}`);
    const row = artRegister.split("\n").find((line) => line.startsWith(`| \`${name}\``));
    if (!row?.includes(sha256(item.bytes))) throw new Error(`Art source register checksum mismatch: ${name}`);
  }
  const shotManifest = JSON.parse(materials.find((item) => item.path === "marketing/screenshots/developer-capture-manifest.json").bytes);
  for (const shot of shotManifest.captures) {
    const item = materials.find((item) => item.path === `marketing/screenshots/${shot.file}`);
    if (!item || sha256(item.bytes) !== shot.sha256) throw new Error(`Historical screenshot checksum mismatch: ${shot.file}`);
  }
  const checkedIdentity = gitIdentity();
  if (checkedIdentity.commit !== identity.commit) throw new Error("HEAD changed during packaging.");
  identity.generated_at = new Date().toISOString();
  identity.schema_version = 1;
  identity.platforms = gameFiles.map((file) => file.platform);
  identity.boundaries = boundaries;
  const outputPath = resolve(output);
  await mkdir(outputPath, { recursive: true });
  const delivery = await mkdtemp(join(outputPath, `ArtReview-v${identity.product_version}-${identity.generated_at.slice(0, 10)}-${identity.commit.slice(0, 8)}-`));
  const folderName = basename(delivery);
  const bundle = join(delivery, folderName);
  await mkdir(bundle);
  const entries = [];
  async function put(path, content, extra = {}) {
    const bytes = Buffer.isBuffer(content) ? content : Buffer.from(content);
    const target = join(bundle, path);
    await mkdir(dirname(target), { recursive: true });
    await writeFile(target, bytes, { flag: "wx" });
    entries.push({ path, size: bytes.length, sha256: sha256(bytes), ...extra });
  }
  await put("VERSION.json", JSON.stringify(identity, null, 2) + "\n");
  await put("START_HERE.txt", firstRead(identity));
  await put("FEEDBACK.md", feedback(identity));
  for (const file of gameFiles) {
    await put(`game/${file.filename}`, file.bytes, { evidence: "same_commit_runtime_candidate" });
    await put(`game/${file.filename}.manifest.json`, JSON.stringify(file.manifest, null, 2) + "\n");
    await put(`game/${file.filename}.sha256`, `${file.manifest.sha256}  ${file.filename}\n`);
  }
  for (const item of materials) {
    const redact = /\.(md|json)$/u.test(item.path);
    await put(`materials/${item.path}`, redact ? redactLocalPaths(item.bytes.toString("utf8")) : item.bytes, {
      source_path: item.path, source_sha256: sha256(item.bytes), local_paths_redacted: redact,
      evidence: item.path.startsWith("godot/assets/art/") ? "runtime_art_candidate"
        : item.path.startsWith("marketing/screenshots/") ? "historical_developer_capture_not_current_build"
          : item.path.startsWith("marketing/") ? "unapproved_marketing_reference" : "requirements_or_source_register",
    });
  }
  const figures = (paths) => paths.map((path) => {
    const item = materials.find((entry) => entry.path === path);
    const dimensions = path.endsWith(".png") ? pngDimensions(item.bytes) : null;
    const href = `materials/${path}`;
    return `<figure><a href="${escapeHtml(href)}"><img loading="lazy" src="${escapeHtml(href)}" alt="${escapeHtml(basename(path))}"></a><figcaption>${escapeHtml(basename(path))}${dimensions ? ` · ${dimensions.width} × ${dimensions.height}` : ""}<small>SHA-256 ${sha256(item.bytes)}</small></figcaption></figure>`;
  }).join("\n");
  const html = `<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src 'self' data:; style-src 'unsafe-inline'"><title>美术专家评审 ${escapeHtml(identity.product_version)}</title><style>body{font:16px/1.7 system-ui,sans-serif;margin:32px auto;padding:0 24px;max-width:1200px;color:#203328;background:#faf8f1}h1,h2{line-height:1.3}a{color:#245e43}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:inherit}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:20px}figure{margin:0;background:#ecebdc;padding:14px;border-radius:8px}img{max-width:100%;max-height:380px;object-fit:contain}small{display:block;overflow-wrap:anywhere}details{border-top:1px solid #ccc;padding:14px 0}.warning{border-left:5px solid #b57c24;padding:14px;background:#fff2d5}</style><h1>美术专家评审包</h1><p>v${escapeHtml(identity.product_version)} · <code>${identity.commit}</code></p><nav><a href="#game">试玩与版本</a> · <a href="#art">21 张运行原图</a> · <a href="#docs">现行要求</a> · <a href="#history">历史截图</a> · <a href="#marketing">未批准品牌参考</a> · <a href="FEEDBACK.md">反馈模板</a></nav><div class="warning">${boundaries.map((line) => `<p>${escapeHtml(line)}</p>`).join("")}</div><h2 id="game">1. 试玩与版本</h2><pre>${escapeHtml(firstRead(identity))}</pre>${gameFiles.map((file) => `<p><a href="game/${file.filename}">${file.platform} 游戏</a> · SHA-256 <small>${file.manifest.sha256}</small></p>`).join("")}<h2 id="art">2. 当前运行候选原图（点击查看原尺寸）</h2><p>未经缩放或重绘；不是批准终稿。逐文件用途、切片和授权状态见下方美术来源登记。</p><div class="grid">${figures(commercialArtFilenames.map((name) => `godot/assets/art/commercial/${name}`))}</div><h2 id="docs">3. 现行要求与来源（展开阅读离线全文）</h2><p>原始文档的相对链接可能指向未附材料；本页已内嵌所选全文。历史生成提示不覆盖现行美术要求。</p>${documents.map((path) => `<details><summary>${escapeHtml(path)}</summary><pre>${escapeHtml(redactLocalPaths(materials.find((item) => item.path === path).bytes.toString("utf8")))}</pre></details>`).join("")}<h2 id="history">4. 历史 Journey 截图，不是本包 Campaign 画面</h2><p>开发者注入状态的实际渲染；不能当本版本玩法、UI 或玩家验收证据。</p><div class="grid">${figures(historicalShots.map((name) => `marketing/screenshots/${name}-developer-capture.png`))}</div><h2 id="marketing">5. 未批准的概念／品牌参考，不是玩法截图</h2><p>产品名重新评估中；只讨论美术与构图，不得外发营销。</p><div class="grid">${figures(["marketing/key-art/see-you-at-the-hive-key-art-base-v1.png", "marketing/brand/see-you-at-the-hive-wordmark.svg", ...storeImages.map((name) => `marketing/store-candidates/${name}`)])}</div></html>`;
  await put("START_HERE.html", html);
  await writeFile(join(bundle, "MANIFEST.json"), JSON.stringify({ schema_version: 1, ...identity, files: entries }, null, 2) + "\n", { flag: "wx" });
  // Verify the actual copied files before producing the outer archive.
  for (const entry of entries) {
    if (sha256(await readFile(join(bundle, entry.path))) !== entry.sha256) throw new Error(`Copy checksum mismatch: ${entry.path}`);
  }
  const archive = join(delivery, `${folderName}.zip`);
  execFileSync("zip", ["-q", "-r", archive, folderName], { cwd: delivery, stdio: "inherit" });
  execFileSync("unzip", ["-tq", archive], { stdio: "inherit" });
  await writeFile(`${archive}.sha256`, `${sha256(await readFile(archive))}  ${basename(archive)}\n`, { flag: "wx" });
  console.log(`Art review ready: ${archive}`);
  return { archive, bundle, identity, fileCount: entries.length + 1 };
}

async function main() {
  let output;
  let build = false;
  const args = process.argv.slice(2);
  for (let index = 0; index < args.length; index += 1) {
    if (args[index] === "--build" && !build) build = true;
    else if (args[index] === "--output" && output === undefined && args[index + 1] && !args[index + 1].startsWith("--")) output = resolve(args[++index]);
    else throw new Error(`Unknown or incomplete argument: ${args[index]}`);
  }
  // Generated outputs in the checkout must remain ignored, so they cannot turn a clean snapshot dirty.
  if (output && !relative(root, output).startsWith(`..${sep}`)) {
    if (output === root || !relative(root, output).startsWith(`outputs${sep}`)) throw new Error("In-repository output must be under outputs/.");
  }
  if (build) await buildGames();
  await packageArtReview({ output });
}

if (resolve(process.argv[1] || "") === fileURLToPath(import.meta.url)) {
  main().catch((error) => { console.error(error.message); process.exitCode = 1; });
}
