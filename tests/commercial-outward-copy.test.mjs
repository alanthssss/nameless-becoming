import assert from "node:assert/strict";
import { readdir, readFile } from "node:fs/promises";
import { extname, join, relative, resolve } from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const repositoryRoot = resolve(fileURLToPath(new URL("..", import.meta.url)));
const allowedExtensions = new Set([".gd", ".godot", ".json", ".md", ".svg", ".tscn", ".tsx", ".txt"]);
const explicitFiles = [
  "app/layout.tsx",
  "app/page.tsx",
  "docs/STEAM_NEXT_FEST_2026_PLAN.md",
  "godot/commercial_title.tscn",
  "godot/journey.tscn",
  "godot/data/credits_and_licenses.json",
  "godot/data/journey_levels.json",
  "godot/data/journey_solar_term_chronicles.json",
  "godot/scripts/player/bee_player.gd",
  "godot/scripts/sound_feedback.gd",
  "marketing/README.md",
  "package.json",
];
const recursiveDirectories = [
  "godot/scripts/system",
  "godot/scripts/world",
  "godot/world/journey",
  "marketing/brand",
  "marketing/screenshots",
  "marketing/store-candidates",
];
const commercialUiDirectory = "godot/scripts/ui";

async function collectFiles(directory) {
  const output = [];
  for (const entry of await readdir(resolve(repositoryRoot, directory), { withFileTypes: true })) {
    const repositoryPath = join(directory, entry.name);
    if (entry.isDirectory()) output.push(...await collectFiles(repositoryPath));
    else if (allowedExtensions.has(extname(entry.name))) output.push(repositoryPath);
  }
  return output;
}

async function commercialSources() {
  const uiFiles = (await readdir(resolve(repositoryRoot, commercialUiDirectory)))
    .filter((name) => name.startsWith("commercial_") && name.endsWith(".gd"))
    .map((name) => join(commercialUiDirectory, name));
  const recursiveFiles = (await Promise.all(recursiveDirectories.map(collectFiles))).flat();
  return [...new Set([...explicitFiles, ...uiFiles, ...recursiveFiles])].sort();
}

test("commercial player path excludes rejected names and abstract conflict framing", async () => {
  const sources = await commercialSources();
  assert.ok(sources.length >= 20, "commercial copy audit unexpectedly found too few source files");
  const forbidden = [
    /再采一朵/u,
    /无名[：:]?成蜂/u,
    /蚊地主/u,
    /失律者/u,
    /调律/u,
    /归律/u,
    /净化/u,
    /预言/u,
    /\bboss\b/iu,
    /三弦/u,
    /回声板/u,
    /校(?:回)?声/u,
    /trichord/iu,
  ];
  for (const repositoryPath of sources) {
    const copy = await readFile(resolve(repositoryRoot, repositoryPath), "utf8");
    for (const pattern of forbidden) {
      assert.doesNotMatch(copy, pattern, `${repositoryPath} contains rejected commercial framing ${pattern}`);
    }
  }
});

test("commercial copy names several kinds of work beyond nectar collection", async () => {
  const sources = await commercialSources();
  const combined = (await Promise.all(sources.map(async (repositoryPath) =>
    readFile(resolve(repositoryRoot, repositoryPath), "utf8")))).join("\n");
  for (const expectedWork of ["授粉", "观察", "修补", "留种", "听声", "转正种壳", "续暖", "搬木", "交接"]) {
    assert.match(combined, new RegExp(expectedWork, "u"), `commercial path does not mention ${expectedWork}`);
  }
});

test("commercial copy stays in the neighborhood instead of rebutting design requirements", async () => {
  const sources = await commercialSources();
  const forbiddenRebuttals = [
    /总开关/u,
    /不是火堆/u,
    /一键/u,
    /不是首领/u,
    /墙不发光/u,
    /按下归巢键/u,
    /自动完成/u,
    /不会自己回/u,
    /没有标准比例/u,
    /哪一种结果更高尚/u,
    /不是身体乐器/u,
    /不是追逐战/u,
  ];
  for (const repositoryPath of sources) {
    const copy = await readFile(resolve(repositoryRoot, repositoryPath), "utf8");
    for (const pattern of forbiddenRebuttals) {
      assert.doesNotMatch(copy, pattern, `${repositoryPath} answers a design objection inside player-facing copy: ${pattern}`);
    }
  }
});

test("commercial copy audit is limited to shipping product sources", async () => {
  const sources = await commercialSources();
  for (const repositoryPath of sources) {
    assert.equal(repositoryPath.includes("/tests/"), false);
    assert.equal(repositoryPath.includes("/playtest/"), false);
    assert.equal(relative(repositoryRoot, resolve(repositoryRoot, repositoryPath)).startsWith(".."), false);
  }
});

test("commercial art directory retains only current runtime candidates", async () => {
  const names = await readdir(resolve(repositoryRoot, "godot/assets/art/commercial"));
  const sourcePngs = names.filter((name) => name.endsWith(".png")).sort();
  assert.equal(sourcePngs.length, 17, "commercial art source count must match the reviewed runtime set");
  for (const rejectedName of ["oil_cricket_states_v1.png", "thrush_tuner_states_v1.png"]) {
    assert.equal(names.includes(rejectedName), false, `${rejectedName} must not be retained in the repository`);
    assert.equal(names.includes(`${rejectedName}.import`), false, `${rejectedName}.import must not be retained in the repository`);
  }
});

test("README current-product section stays clean while preserving marked history below it", async () => {
  const readme = await readFile(resolve(repositoryRoot, "README.md"), "utf8");
  const currentProduct = readme.split("## 历史私有部署（非当前产品试玩）", 1)[0];
  assert.ok(currentProduct.includes("一会儿巢里见"));
  // Production documentation may call the four requested season finales Boss
  // levels. Shipping data and player-facing copy remain covered by the stricter
  // audit above and use concrete incident names plus the internal `climax` kind.
  for (const pattern of [/再采一朵/u, /无名[：:]?成蜂/u, /失律/u, /调律/u, /三弦/u, /回声板/u, /校(?:回)?声/u, /trichord/iu]) {
    assert.doesNotMatch(currentProduct, pattern, `README current-product section contains rejected framing ${pattern}`);
  }
});
