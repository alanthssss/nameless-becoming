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

test("server-renders the Nameless: Becoming launch shell", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<html lang="zh-CN">/i);
  assert.match(html, /<title>无名：成蜂｜Godot 四季搜打撤<\/title>/i);
  assert.match(html, /再采一朵，还是现在归巢？/);
  assert.match(html, /启动 Web 版/);
  assert.match(html, /v0\.9\.4/);
  assert.doesNotMatch(html, /codex-preview|Your site is taking shape|Building your site/i);
});

test("keeps starter artifacts out of the production shell", async () => {
  const [page, layout, packageJson] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../package.json", import.meta.url), "utf8"),
  ]);

  assert.match(page, /iframe src="\/game\/index\.html"/);
  assert.match(page, /title="无名：成蜂 Godot Web 游戏"/);
  assert.match(layout, /title:\s*"无名：成蜂｜Godot 四季搜打撤"/);
  assert.match(layout, /<html lang="zh-CN">/);
  assert.doesNotMatch(page, /SkeletonPreview|codex-preview/);
  assert.doesNotMatch(layout, /Starter Project|codex-preview|_sites-preview/);
  assert.doesNotMatch(packageJson, /react-loading-skeleton/);

  await Promise.all([
    assert.rejects(access(new URL("app/_sites-preview", projectRoot))),
    assert.rejects(access(new URL("public/_sites-preview", projectRoot))),
  ]);
});
