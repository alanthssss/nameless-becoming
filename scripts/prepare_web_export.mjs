import { readFile, writeFile, rename } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";
import { gzipSync } from "node:zlib";

const gameDir = new URL("../public/game/", import.meta.url);
const wasmUrl = new URL("index.wasm", gameDir);
const engineUrl = new URL("index.js", gameDir);
const htmlUrl = new URL("index.html", gameDir);
const wasm = new Uint8Array(await readFile(wasmUrl));
const compressed = gzipSync(wasm, { level: 9 });
await writeFile(new URL("index.wasm.gz", gameDir), compressed);

// Sites limits individual files to 25 MB. Modern browsers use the much smaller
// gzip payload; split raw chunks remain as a compatibility fallback.
const chunkSize = 20 * 1024 * 1024;
const partNames = [];
for (let offset = 0, index = 0; offset < wasm.length; offset += chunkSize, index += 1) {
  const partName = `index.wasm.part${index}`;
  partNames.push(partName);
  await writeFile(new URL(partName, gameDir), wasm.subarray(offset, offset + chunkSize));
}

await rename(wasmUrl, join(tmpdir(), `${basename(process.cwd())}-${Date.now()}-index.wasm`));

let engine = await readFile(engineUrl, "utf8");
const original = "loadPromise = preloader.loadPromise(`${loadPath}.wasm`, size, true);";
const replacement = `loadPromise = ("DecompressionStream" in globalThis ? fetch(new URL(\`\${loadPath}.wasm.gz\`, location.href), { credentials: "same-origin" }).then((response) => {
				if (!response.ok || !response.body) throw new Error(\`HTTP \${response.status}: \${response.url}\`);
				// Fetch decodes Content-Encoding automatically while preserving the
				// response header. Only decompress hosts that serve the .gz bytes raw.
				const decodedByTransport = /\\bgzip\\b/i.test(response.headers.get("content-encoding") ?? "");
				const body = decodedByTransport ? response.body : response.body.pipeThrough(new DecompressionStream("gzip"));
				return new Response(body, { headers: { "content-type": "application/wasm" } });
			}) : Promise.all(${JSON.stringify(partNames)}.map((part) => fetch(new URL(part, new URL(\`\${loadPath}.wasm\`, location.href)), { credentials: "same-origin" }))).then(async (responses) => {
				const chunks = await Promise.all(responses.map((response) => { if (!response.ok) throw new Error(\`HTTP \${response.status}: \${response.url}\`); return response.arrayBuffer(); }));
				const total = chunks.reduce((sum, chunk) => sum + chunk.byteLength, 0);
				const merged = new Uint8Array(total); let offset = 0;
				for (const chunk of chunks) { merged.set(new Uint8Array(chunk), offset); offset += chunk.byteLength; }
				return new Response(merged, { headers: { "content-type": "application/wasm" } });
			}));`;
if (!engine.includes(original)) throw new Error("Godot Web loader signature changed; compressed-loader patch not applied.");
engine = engine.replace(original, replacement);
await writeFile(engineUrl, engine);

let html = await readFile(htmlUrl, "utf8");
if (!html.includes("\t\tconsole.error(err);") || !html.includes("\t\t\tsetStatusMode('hidden');")) {
  throw new Error("Godot Web shell signature changed; parent signal patch not applied.");
}
html = html
  .replace("\t\tconsole.error(err);", "\t\tconsole.error(err);\n\t\twindow.parent.postMessage({ type: 'nameless-game-error', message: err instanceof Error ? err.message : String(err) }, window.location.origin);")
  .replace("\t\t\tsetStatusMode('hidden');", "\t\t\tsetStatusMode('hidden');\n\t\t\twindow.parent.postMessage({ type: 'nameless-game-ready' }, window.location.origin);");
await writeFile(htmlUrl, html);

console.log(`Prepared ${compressed.length}-byte gzip WebAssembly plus ${partNames.length} fallback chunks (${wasm.length} bytes raw).`);
