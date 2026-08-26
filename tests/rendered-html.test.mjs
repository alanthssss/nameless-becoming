import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import test from "node:test";

const projectRoot = new URL("../", import.meta.url);

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("http://localhost/", {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

test("server-renders the See You at the Hive launch shell", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<html lang="zh-CN">/i);
  assert.match(html, /<title>一会儿巢里见｜Godot 春季往返纵切<\/title>/i);
  assert.match(html, /花田有事，搭把翅膀。/);
  assert.match(html, /进入试玩/);
  assert.match(html, /可玩垂直切片/);
  assert.doesNotMatch(html, /codex-preview|Your site is taking shape|Building your site/i);
});

test("keeps starter artifacts out of the production shell", async () => {
  const [page, layout, packageJson] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../package.json", import.meta.url), "utf8"),
  ]);

  assert.match(page, /src="\/game\/index\.html"/);
  assert.match(page, /title="一会儿巢里见 Godot Web 游戏"/);
  assert.match(page, /正在唤醒蜂群/);
  assert.match(page, /重新载入/);
  assert.match(page, /role="status"/);
  assert.match(page, /role="alert"/);
  assert.match(page, /nameless-game-ready/);
  assert.match(page, /nameless-game-error/);
  assert.match(page, /60000/);
  assert.doesNotMatch(page, /onLoad=\{\(\) => setPhase\("ready"\)\}/);
  assert.match(layout, /title:\s*"一会儿巢里见｜Godot 春季往返纵切"/);
  assert.match(layout, /<html lang="zh-CN">/);
  assert.doesNotMatch(page, /SkeletonPreview|codex-preview/);
  assert.doesNotMatch(layout, /Starter Project|codex-preview|_sites-preview/);
  assert.doesNotMatch(layout, /next\/font/);
  assert.doesNotMatch(packageJson, /react-loading-skeleton/);

  await Promise.all([
    assert.rejects(access(new URL("app/_sites-preview", projectRoot))),
    assert.rejects(access(new URL("public/_sites-preview", projectRoot))),
  ]);
});

test("prepares a compressed Godot payload and signals real engine readiness", async () => {
  const script = await readFile(new URL("../scripts/prepare_web_export.mjs", import.meta.url), "utf8");
  assert.match(script, /gzipSync/);
  assert.match(script, /index\.wasm\.gz/);
  assert.match(script, /DecompressionStream/);
  assert.match(script, /content-encoding/);
  assert.match(script, /decodedByTransport \? response\.body/);
  assert.match(script, /credentials: "same-origin"/);
  assert.match(script, /nameless-game-ready/);
  assert.match(script, /nameless-game-error/);
  assert.match(script, /index\.wasm\.part/);
});
