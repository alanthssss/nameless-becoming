import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { constants } from "node:fs";
import { access, readFile, realpath, rm, stat } from "node:fs/promises";
import { basename, dirname, isAbsolute, join, resolve } from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import { fileURLToPath } from "node:url";

const ticketFilename = "playtest-ticket.json";
const ticketArgumentPrefix = "--playtest-ticket=";
export const readyReceiptFilename = "playtest-ready-receipt.json";

export function parseLaunchArguments(arguments_) {
  const options = {};
  const valueFlags = new Map([
    ["--executable", "executablePath"],
    ["--ticket", "ticketPath"],
  ]);
  for (let index = 0; index < arguments_.length; index += 1) {
    const flag = arguments_[index];
    if (flag === "--help" || flag === "--dry-run") {
      const key = flag === "--help" ? "help" : "dryRun";
      if (options[key]) throw new Error(`Argument may only be provided once: ${flag}.`);
      options[key] = true;
      continue;
    }
    const key = valueFlags.get(flag);
    if (!key) throw new Error(`Unknown argument: ${flag}.`);
    if (Object.hasOwn(options, key)) throw new Error(`Argument may only be provided once: ${flag}.`);
    const value = arguments_[index + 1];
    if (!value || value.startsWith("--")) throw new Error(`${flag} requires a value.`);
    options[key] = value;
    index += 1;
  }
  if (options.help) return options;
  if (!options.executablePath) throw new Error("--executable is required.");
  if (!options.ticketPath) throw new Error("--ticket is required.");
  return options;
}

async function canonicalPath(path, label) {
  if (!isAbsolute(path)) throw new Error(`${label} must be an absolute filesystem path.`);
  try {
    return await realpath(path);
  } catch (error) {
    throw new Error(`${label} could not be resolved: ${error.message}`, { cause: error });
  }
}

export async function buildLaunchSpec({ executablePath, ticketPath, platform = process.platform }) {
  const executable = await canonicalPath(executablePath, "--executable");
  const ticket = await canonicalPath(ticketPath, "--ticket");
  if (basename(ticket) !== ticketFilename) throw new Error(`--ticket must name ${ticketFilename}.`);
  if (!(await stat(ticket)).isFile()) throw new Error("--ticket must resolve to a regular file.");

  const ticketBytes = await readFile(ticket);
  let ticketPayload;
  try {
    ticketPayload = JSON.parse(ticketBytes.toString("utf8"));
  } catch (error) {
    throw new Error(`--ticket is not valid JSON: ${error.message}`, { cause: error });
  }
  if (!ticketPayload || typeof ticketPayload !== "object"
      || typeof ticketPayload.session_id !== "string"
      || typeof ticketPayload.task?.slice_code !== "string"
      || typeof ticketPayload.product?.commit !== "string") {
    throw new Error("--ticket does not contain the identity fields needed to verify launch readiness.");
  }
  const ticketSha256 = createHash("sha256").update(ticketBytes).digest("hex");
  const receiptPath = join(dirname(ticket), readyReceiptFilename);
  const expectedReceipt = {
    schema_version: 1,
    status: "ready",
    session_id: ticketPayload.session_id,
    slice_code: ticketPayload.task.slice_code,
    product_commit: ticketPayload.product.commit,
    ticket_sha256: ticketSha256,
  };

  const executableStatus = await stat(executable);
  const ticketArgument = `${ticketArgumentPrefix}${ticket}`;
  if (platform === "darwin" && executableStatus.isDirectory() && executable.toLowerCase().endsWith(".app")) {
    return {
      mode: "macos-app",
      command: "/usr/bin/open",
      arguments: ["-n", executable, "--args", "--", ticketArgument],
      executable,
      ticket,
      receiptPath,
      expectedReceipt,
    };
  }
  if (!executableStatus.isFile()) throw new Error("--executable must resolve to an executable file or, on macOS, an .app bundle.");
  if (platform !== "win32") {
    try {
      await access(executable, constants.X_OK);
    } catch (error) {
      throw new Error("--executable is not executable by the current user.", { cause: error });
    }
  }
  return {
    mode: "direct",
    command: executable,
    arguments: ["--", ticketArgument],
    executable,
    ticket,
    receiptPath,
    expectedReceipt,
  };
}

export function launchPlaytest(spec, spawnImplementation = spawn) {
  return new Promise((resolveLaunch, rejectLaunch) => {
    const direct = spec.mode === "direct";
    const child = spawnImplementation(spec.command, spec.arguments, {
      detached: direct,
      stdio: "ignore",
      windowsHide: true,
    });
    let settled = false;
    const reject = (error) => {
      if (settled) return;
      settled = true;
      rejectLaunch(error);
    };
    child.once("error", reject);
    if (direct) {
      child.once("spawn", () => {
        if (settled) return;
        settled = true;
        child.unref();
        resolveLaunch({ pid: child.pid, mode: spec.mode });
      });
      return;
    }
    child.once("close", (code) => {
      if (settled) return;
      settled = true;
      if (code !== 0) {
        rejectLaunch(new Error(`/usr/bin/open exited with status ${code}.`));
        return;
      }
      resolveLaunch({ pid: child.pid, mode: spec.mode });
    });
  });
}

function receiptMatches(actual, expected) {
  if (!actual || typeof actual !== "object" || Array.isArray(actual)) return false;
  const actualKeys = Object.keys(actual).sort();
  const expectedKeys = Object.keys(expected).sort();
  return actualKeys.length === expectedKeys.length
    && actualKeys.every((key, index) => key === expectedKeys[index])
    && expectedKeys.every((key) => actual[key] === expected[key]);
}

export async function waitForReadyReceipt(spec, { timeoutMs = 30_000, pollIntervalMs = 100 } = {}) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() <= deadline) {
    try {
      const text = await readFile(spec.receiptPath, "utf8");
      let receipt;
      try {
        receipt = JSON.parse(text);
      } catch {
        receipt = null;
      }
      if (receipt !== null) {
        if (!receiptMatches(receipt, spec.expectedReceipt)) {
          throw new Error(`Playtest ready receipt identity mismatch: ${spec.receiptPath}`);
        }
        return receipt;
      }
    } catch (error) {
      if (error?.code !== "ENOENT") throw error;
    }
    await delay(pollIntervalMs);
  }
  throw new Error(`Timed out waiting for the typed playtest scene ready receipt: ${spec.receiptPath}`);
}

export async function launchVerifiedPlaytest(spec, options = {}) {
  await rm(spec.receiptPath, { force: true });
  await launchPlaytest(spec, options.spawnImplementation || spawn);
  return waitForReadyReceipt(spec, options);
}

function usage() {
  return `Usage:
  npm run playtest:launch -- --executable <absolute .app/.exe/binary path> --ticket <absolute playtest-ticket.json path>

The launcher always inserts Godot's required user-argument separator before the ticket.
Use --dry-run to print the exact argv without starting the game.`;
}

async function main() {
  try {
    const options = parseLaunchArguments(process.argv.slice(2));
    if (options.help) {
      console.log(usage());
      return;
    }
    const spec = await buildLaunchSpec(options);
    if (options.dryRun) {
      console.log(JSON.stringify({ command: spec.command, arguments: spec.arguments, receipt: spec.receiptPath }, null, 2));
      return;
    }
    await launchVerifiedPlaytest(spec);
    console.log(`Playtest ready receipt verified: ${spec.receiptPath}`);
  } catch (error) {
    console.error(`Playtest launch failed: ${error.message}`);
    process.exitCode = 1;
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
