import { readFile, writeFile, rename } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";

const gameDir = new URL("../public/game/", import.meta.url);
const wasmUrl = new URL("index.wasm", gameDir);
const engineUrl = new URL("index.js", gameDir);
const wasm = new Uint8Array(await readFile(wasmUrl));
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
const replacement = `loadPromise = Promise.all(${JSON.stringify(partNames)}.map((part) => fetch(new URL(part, new URL(\`${"${loadPath}"}.wasm\`, location.href))))).then(async (responses) => {\n\t\t\t\tconst chunks = await Promise.all(responses.map((response) => { if (!response.ok) throw new Error(\`HTTP \${response.status}: \${response.url}\`); return response.arrayBuffer(); }));\n\t\t\t\tconst total = chunks.reduce((sum, chunk) => sum + chunk.byteLength, 0);\n\t\t\t\tconst merged = new Uint8Array(total); let offset = 0;\n\t\t\t\tfor (const chunk of chunks) { merged.set(new Uint8Array(chunk), offset); offset += chunk.byteLength; }\n\t\t\t\treturn new Response(merged, { headers: { \"content-type\": \"application/wasm\" } });\n\t\t\t});`;

if (!engine.includes(original)) throw new Error("Godot Web loader signature changed; split-loader patch not applied.");
engine = engine.replace(original, replacement);
await writeFile(engineUrl, engine);
console.log(`Prepared ${partNames.length} WebAssembly chunks (${wasm.length} bytes total).`);
