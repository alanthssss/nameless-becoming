import { execFileSync } from "node:child_process";
import { cp, lstat, mkdir, mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, dirname, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { commercialArtFilenames } from "./create_commercial_godot_stage.mjs";
import { generateArtifactManifest, PLATFORM_ARTIFACTS } from "./generate_artifact_manifest.mjs";
import {
  documents, escapeHtml, gitIdentity, materialPaths, pngDimensions, readMaterial,
  redactLocalPaths, sha256, validateArtifact,
} from "./package_art_review.mjs";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const platform = "macos-universal";
const gameArchiveName = PLATFORM_ARTIFACTS[platform];
const appName = "一会儿巢里见.app";
const currentArtPaths = commercialArtFilenames.map((name) => `godot/assets/art/commercial/${name}`);
const referenceImagePaths = materialPaths.filter((path) => /\.(?:png|svg)$/u.test(path) && !currentArtPaths.includes(path));

async function assertRealDirectory(path) {
  const stats = await lstat(path);
  if (!stats.isDirectory() || stats.isSymbolicLink()) throw new Error(`Expected a real directory: ${path}`);
}

async function collectRegularFiles(directory, base = directory, files = []) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name);
    if (entry.isSymbolicLink()) throw new Error(`Mac expert package refuses symbolic links: ${path}`);
    if (entry.isDirectory()) await collectRegularFiles(path, base, files);
    else if (entry.isFile()) files.push({ path, relativePath: relative(base, path).split(sep).join("/") });
    else throw new Error(`Mac expert package refuses special files: ${path}`);
  }
  return files;
}

export function macFirstRead(identity) {
  return `《一会儿巢里见》Mac 美术专家评审包\n\n版本：${identity.product_version}\n完整提交：${identity.commit}\n生成时间（UTC）：${identity.generated_at}\n平台：macOS universal（Apple Silicon + Intel）\n\n怎么开始\n\n1. 请先把整个 ZIP 解压；不要在压缩包预览窗口里运行游戏。\n2. 按住 Control 点击「一会儿巢里见.app」，选择“打开”，再确认“打开”。首次启动可能需要等待几秒。\n3. 如果仍被 macOS 阻止：打开“系统设置 → 隐私与安全性”，在安全提示旁选择“仍要打开”，然后再确认。\n4. 不要关闭 Mac 的全局安全保护，也不需要输入终端命令。若系统仍提示“已损坏”或没有“仍要打开”，请把提示截图和 macOS 版本发回，不要继续尝试。\n5. 双击「美术资料/图册.html」查看当前原图、历史截图和未批准品牌参考；把意见写入「美术反馈.md」。\n\n试玩建议\n\n先体验标题 → 主巢 → 立春出巢 → 一次实际交互 → 回巢接货，再查看图册。无需为看美术而通关全年。方向键／WASD 移动，空格主动作，Q 次动作／返巢，Esc 暂停。游戏使用本地单存档；已有项目存档的 Mac 不要未经备份选择“新旅程”。\n\n重要边界\n\n- 这是内部美术评审候选，不是可售成品或公开营销素材；产品名仍在重评。\n- 美术仍为 AUTH-PENDING / ALAN-PENDING / PLAYER-PENDING / MKT-NO。\n- 六张 Journey 截图是历史开发者采集，不是本包 Campaign 同版本截图；概念图不是玩法画面。\n- macOS 应用经过 ad-hoc 签名但没有 Apple 公证，因此系统会要求上述人工确认。只有 Apple Developer ID 签名＋公证才能消除这类首次打开警告。\n- 自动检查不代表真人全流程、设备手感、声音、授权或商业发行验收。\n\n校验整个分享 ZIP：在终端运行 shasum -a 256 <ZIP文件>，结果应与旁边的 .sha256 文件相同。\n`;
}

function feedback(identity) {
  return `# Mac 美术专家反馈\n\n版本：${identity.product_version}\n提交：${identity.commit}\n\n评审人／日期：\nMac 型号（Apple Silicon／Intel）：\nmacOS 版本／分辨率／缩放：\n能否成功打开游戏；若不能，请附完整提示截图：\n实际试玩范围与时间：\n意见类别：[专家启发式]（如仅看图请明确写未试玩）\n\n## 最值得保留的三点\n\n1.\n2.\n3.\n\n## 优先修改的问题（复制本节逐项填写）\n\n- 文件名或场景／状态：\n- 截图编号／时间点：\n- 实际观察：\n- 对可读性／风格／动作的影响：\n- 严重度：阻断理解／明显影响／润色\n- 修改建议及验收方式：\n- 估计工作量范围、依赖与不确定性：\n\n## 下一步三个样板与所需源文件\n\n## 未覆盖范围／需要 Alan 决定的问题\n\n本反馈不构成授权审计、商业终稿批准或独立玩家验收。\n`;
}

function gallery(identity, materials) {
  const figures = (paths) => paths.map((path) => {
    const item = materials.get(path);
    const target = currentArtPaths.includes(path)
      ? `当前游戏美术原图/${basename(path)}`
      : `参考资料/${path}`;
    const dimensions = path.endsWith(".png") ? pngDimensions(item) : null;
    return `<figure><a href="${escapeHtml(target)}"><img loading="lazy" src="${escapeHtml(target)}" alt="${escapeHtml(basename(path))}"></a><figcaption>${escapeHtml(basename(path))}${dimensions ? ` · ${dimensions.width} × ${dimensions.height}` : ""}<small>SHA-256 ${sha256(item)}</small></figcaption></figure>`;
  }).join("\n");
  return `<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src 'self'; style-src 'unsafe-inline'"><title>Mac 美术专家图册 ${escapeHtml(identity.product_version)}</title><style>body{font:16px/1.65 system-ui,sans-serif;max-width:1200px;margin:30px auto;padding:0 20px;color:#203328;background:#faf8f1}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:18px}figure{margin:0;padding:12px;background:#ecebdc;border-radius:8px}img{display:block;max-width:100%;height:300px;margin:auto;object-fit:contain}small{display:block;overflow-wrap:anywhere}.warning{border-left:5px solid #b57c24;padding:12px;background:#fff2d5}</style><h1>Mac 美术专家图册</h1><p>v${escapeHtml(identity.product_version)} · <code>${identity.commit}</code></p><div class="warning"><p>当前图仍未获授权、Alan、玩家或营销终稿批准。</p><p>历史 Journey 截图不是本包 Campaign 同版本截图；概念图和商店图不是玩法画面。</p></div><h2>21 张当前运行候选原图</h2><div class="grid">${figures(currentArtPaths)}</div><h2>历史截图与未批准品牌参考</h2><div class="grid">${figures(referenceImagePaths)}</div><h2>现行要求与来源</h2><ul>${documents.map((path) => `<li><a href="现行要求与来源/${escapeHtml(path)}">${escapeHtml(path)}</a></li>`).join("")}</ul></html>`;
}

export async function packageMacosArtReview({ output = join(root, "outputs/mac-art-review") } = {}) {
  if (process.platform !== "darwin") throw new Error("The direct Mac expert package must be built on macOS to preserve and re-verify the app bundle.");
  const sourceIdentity = gitIdentity();
  const packageJson = JSON.parse(await readFile(join(root, "package.json"), "utf8"));
  const identity = { schema_version: 1, ...sourceIdentity, product_version: packageJson.version, generated_at: new Date().toISOString(), platform: platform };
  const gamePath = join(root, "builds", gameArchiveName);
  const { manifest: gameManifest } = await generateArtifactManifest({ artifactPath: gamePath, platform });
  validateArtifact(gameManifest, await readFile(gamePath), identity, platform);

  const materials = new Map();
  for (const path of materialPaths) materials.set(path, await readMaterial(root, path));
  const sourceRegister = materials.get("docs/design/art-source-register.md").toString("utf8");
  for (const path of currentArtPaths) {
    if (!sourceRegister.split("\n").find((line) => line.startsWith(`| \`${basename(path)}\``))?.includes(sha256(materials.get(path)))) {
      throw new Error(`Art source register checksum mismatch: ${path}`);
    }
  }
  const screenshotManifest = JSON.parse(materials.get("marketing/screenshots/developer-capture-manifest.json"));
  for (const shot of screenshotManifest.captures) {
    if (sha256(materials.get(`marketing/screenshots/${shot.file}`)) !== shot.sha256) throw new Error(`Screenshot checksum mismatch: ${shot.file}`);
  }
  if (gitIdentity().commit !== identity.commit) throw new Error("HEAD changed during Mac expert packaging.");

  const outputPath = resolve(output);
  await mkdir(outputPath, { recursive: true });
  const delivery = await mkdtemp(join(outputPath, `MacArtReview-v${identity.product_version}-${identity.generated_at.slice(0, 10)}-${identity.commit.slice(0, 8)}-`));
  const folderName = basename(delivery);
  const bundle = join(delivery, folderName);
  const extraction = await mkdtemp(join(tmpdir(), "mac-art-review-source-"));
  try {
    await mkdir(bundle);
    execFileSync("ditto", ["-x", "-k", gamePath, extraction], { stdio: "inherit" });
    const sourceApp = join(extraction, appName);
    await assertRealDirectory(sourceApp);
    execFileSync("codesign", ["--verify", "--deep", "--strict", sourceApp], { stdio: "inherit" });
    execFileSync("lipo", [join(sourceApp, "Contents/MacOS/一会儿巢里见"), "-verify_arch", "arm64", "x86_64"], { stdio: "inherit" });
    await cp(sourceApp, join(bundle, appName), { recursive: true, errorOnExist: true, force: false, preserveTimestamps: true });
    await writeFile(join(bundle, "请先看这里.txt"), macFirstRead(identity), { flag: "wx" });
    await writeFile(join(bundle, "美术反馈.md"), feedback(identity), { flag: "wx" });
    await writeFile(join(bundle, "VERSION.json"), JSON.stringify({ ...identity, game_artifact: gameManifest }, null, 2) + "\n", { flag: "wx" });
    for (const path of currentArtPaths) {
      const target = join(bundle, "美术资料/当前游戏美术原图", basename(path));
      await mkdir(dirname(target), { recursive: true });
      await writeFile(target, materials.get(path), { flag: "wx" });
    }
    for (const path of documents) {
      const target = join(bundle, "美术资料/现行要求与来源", path);
      await mkdir(dirname(target), { recursive: true });
      const bytes = materials.get(path);
      await writeFile(target, /\.(?:md|json)$/u.test(path) ? redactLocalPaths(bytes.toString("utf8")) : bytes, { flag: "wx" });
    }
    for (const path of [...referenceImagePaths, "marketing/screenshots/developer-capture-manifest.json", "marketing/store-candidates/candidate-manifest.json"]) {
      const target = join(bundle, "美术资料/参考资料", path);
      await mkdir(dirname(target), { recursive: true });
      const bytes = materials.get(path);
      await writeFile(target, path.endsWith(".json") ? redactLocalPaths(bytes.toString("utf8")) : bytes, { flag: "wx" });
    }
    await writeFile(join(bundle, "美术资料/图册.html"), gallery(identity, materials), { flag: "wx" });

    const files = [];
    for (const file of await collectRegularFiles(bundle)) {
      const bytes = await readFile(file.path);
      files.push({ path: file.relativePath, size: bytes.length, sha256: sha256(bytes) });
    }
    await writeFile(join(bundle, "MANIFEST.json"), JSON.stringify({ ...identity, files }, null, 2) + "\n", { flag: "wx" });
    const archive = join(delivery, `${folderName}.zip`);
    // Use a standard ZIP without AppleDouble/Finder metadata. Those attributes
    // are not required by this Godot app and can invalidate strict signature
    // verification when macOS restores them after download. Info-ZIP preserves
    // the executable mode required by the app bundle.
    execFileSync("zip", ["-q", "-r", archive, folderName], { cwd: delivery, stdio: "inherit" });
    execFileSync("unzip", ["-tq", archive], { stdio: "inherit" });
    const archiveHash = sha256(await readFile(archive));
    await writeFile(`${archive}.sha256`, `${archiveHash}  ${basename(archive)}\n`, { flag: "wx" });

    const verification = await mkdtemp(join(tmpdir(), "mac-art-review-verify-"));
    try {
      execFileSync("ditto", ["-x", "-k", archive, verification], { stdio: "inherit" });
      const extracted = join(verification, folderName);
      const extractedApp = join(extracted, appName);
      execFileSync("codesign", ["--verify", "--deep", "--strict", extractedApp], { stdio: "inherit" });
      execFileSync("lipo", [join(extractedApp, "Contents/MacOS/一会儿巢里见"), "-verify_arch", "arm64", "x86_64"], { stdio: "inherit" });
      const actualNames = (await readdir(extracted)).sort();
      const expectedNames = ["MANIFEST.json", "VERSION.json", appName, "美术反馈.md", "美术资料", "请先看这里.txt"].sort();
      if (JSON.stringify(actualNames) !== JSON.stringify(expectedNames)) throw new Error(`Unexpected Mac package root: ${actualNames.join(", ")}`);
    } finally {
      await rm(verification, { recursive: true, force: true });
    }
    console.log(`Mac art expert review ready: ${archive}`);
    return { archive, bundle, identity, sha256: archiveHash };
  } finally {
    await rm(extraction, { recursive: true, force: true });
  }
}

async function main() {
  let output;
  const args = process.argv.slice(2);
  for (let index = 0; index < args.length; index += 1) {
    if (args[index] === "--output" && output === undefined && args[index + 1] && !args[index + 1].startsWith("--")) output = resolve(args[++index]);
    else throw new Error(`Unknown or incomplete argument: ${args[index]}`);
  }
  if (output && !relative(root, output).startsWith(`..${sep}`) && (output === root || !relative(root, output).startsWith(`outputs${sep}`))) {
    throw new Error("In-repository output must be under outputs/.");
  }
  await packageMacosArtReview({ output });
}

if (resolve(process.argv[1] || "") === fileURLToPath(import.meta.url)) {
  main().catch((error) => { console.error(error.message); process.exitCode = 1; });
}
