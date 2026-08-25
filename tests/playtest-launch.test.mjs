import assert from "node:assert/strict";
import { EventEmitter } from "node:events";
import { existsSync } from "node:fs";
import { chmod, mkdir, mkdtemp, realpath, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import test from "node:test";

import {
  buildLaunchSpec,
  launchPlaytest,
  launchVerifiedPlaytest,
  parseLaunchArguments,
  waitForReadyReceipt,
} from "../scripts/launch_playtest.mjs";

test("strictly parses the playtest launch contract", () => {
  assert.deepEqual(parseLaunchArguments([
    "--executable", "/tmp/game",
    "--ticket", "/tmp/playtest-ticket.json",
    "--dry-run",
  ]), {
    executablePath: "/tmp/game",
    ticketPath: "/tmp/playtest-ticket.json",
    dryRun: true,
  });
  assert.throws(() => parseLaunchArguments([]), /--executable is required/u);
  assert.throws(() => parseLaunchArguments(["--executable", "/tmp/game"]), /--ticket is required/u);
  assert.throws(() => parseLaunchArguments(["--mystery", "x"]), /Unknown argument/u);
  assert.throws(() => parseLaunchArguments(["--executable", "/one", "--executable", "/two"]), /only be provided once/u);
});

test("builds direct and macOS bundle argv with an explicit Godot separator", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-playtest-launch-"));
  try {
    const executable = join(temporaryRoot, "game");
    const ticket = join(temporaryRoot, "playtest-ticket.json");
    const app = join(temporaryRoot, "无名：成蜂.app");
    await writeFile(executable, "#!/bin/sh\nexit 0\n", "utf8");
    await chmod(executable, 0o755);
    await writeFile(ticket, `${JSON.stringify({
      session_id: "NB-20260826-NEW0001",
      task: { slice_code: "B01" },
      product: { commit: "a".repeat(40) },
    }, null, 2)}\n`, "utf8");
    await mkdir(app);
    const canonicalExecutable = await realpath(executable);
    const canonicalTicket = await realpath(ticket);
    const canonicalApp = await realpath(app);

    const direct = await buildLaunchSpec({ executablePath: executable, ticketPath: ticket, platform: "linux" });
    assert.equal(direct.command, canonicalExecutable);
    assert.deepEqual(direct.arguments, ["--", `--playtest-ticket=${canonicalTicket}`]);
    assert.equal(direct.expectedReceipt.session_id, "NB-20260826-NEW0001");
    assert.equal(direct.receiptPath, join(dirname(canonicalTicket), "playtest-ready-receipt.json"));

    const macos = await buildLaunchSpec({ executablePath: app, ticketPath: ticket, platform: "darwin" });
    assert.equal(macos.command, "/usr/bin/open");
    assert.deepEqual(macos.arguments, ["-n", canonicalApp, "--args", "--", `--playtest-ticket=${canonicalTicket}`]);

    const wrongTicket = join(temporaryRoot, "ticket.json");
    await writeFile(wrongTicket, "{}\n", "utf8");
    await assert.rejects(buildLaunchSpec({ executablePath: executable, ticketPath: wrongTicket, platform: "linux" }), /must name playtest-ticket\.json/u);
    await assert.rejects(buildLaunchSpec({ executablePath: "relative/game", ticketPath: ticket, platform: "linux" }), /absolute filesystem path/u);
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

test("passes the launch spec to spawn without shell re-parsing", async () => {
  let invocation;
  let unrefCalled = false;
  const fakeSpawn = (command, arguments_, options) => {
    invocation = { command, arguments: arguments_, options };
    const child = new EventEmitter();
    child.pid = 4312;
    child.unref = () => { unrefCalled = true; };
    process.nextTick(() => child.emit("spawn"));
    return child;
  };
  const spec = {
    mode: "direct",
    command: "/tmp/game with spaces",
    arguments: ["--", "--playtest-ticket=/tmp/package with spaces/playtest-ticket.json"],
  };
  assert.deepEqual(await launchPlaytest(spec, fakeSpawn), { pid: 4312, mode: "direct" });
  assert.deepEqual(invocation, {
    command: spec.command,
    arguments: spec.arguments,
    options: { detached: true, stdio: "ignore", windowsHide: true },
  });
  assert.equal(unrefCalled, true);
});

test("removes stale evidence and only succeeds after the matching typed-scene receipt", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-playtest-receipt-"));
  try {
    const receiptPath = join(temporaryRoot, "playtest-ready-receipt.json");
    const expectedReceipt = {
      schema_version: 1,
      status: "ready",
      session_id: "NB-20260826-NEW0002",
      slice_code: "B01",
      product_commit: "b".repeat(40),
      ticket_sha256: "c".repeat(64),
    };
    await writeFile(receiptPath, '{"status":"stale"}\n', "utf8");
    const spec = {
      mode: "direct",
      command: "/tmp/fake-game",
      arguments: ["--", "--playtest-ticket=/tmp/playtest-ticket.json"],
      receiptPath,
      expectedReceipt,
    };
    const fakeSpawn = () => {
      assert.equal(existsSync(receiptPath), false, "stale receipt must be removed before spawning the game");
      const child = new EventEmitter();
      child.pid = 8142;
      child.unref = () => {};
      process.nextTick(() => {
        child.emit("spawn");
        void writeFile(receiptPath, `${JSON.stringify(expectedReceipt, null, 2)}\n`, "utf8");
      });
      return child;
    };
    assert.deepEqual(await launchVerifiedPlaytest(spec, {
      spawnImplementation: fakeSpawn,
      timeoutMs: 1_000,
      pollIntervalMs: 5,
    }), expectedReceipt);
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});

test("rejects a ready receipt whose session identity does not match the ticket", async () => {
  const temporaryRoot = await mkdtemp(join(tmpdir(), "nameless-playtest-receipt-mismatch-"));
  try {
    const receiptPath = join(temporaryRoot, "playtest-ready-receipt.json");
    const expectedReceipt = {
      schema_version: 1,
      status: "ready",
      session_id: "NB-20260826-EXPECTED",
      slice_code: "B01",
      product_commit: "d".repeat(40),
      ticket_sha256: "e".repeat(64),
    };
    await writeFile(receiptPath, `${JSON.stringify({
      ...expectedReceipt,
      session_id: "NB-20260826-WRONG",
    })}\n`, "utf8");
    await assert.rejects(waitForReadyReceipt({ receiptPath, expectedReceipt }, {
      timeoutMs: 25,
      pollIntervalMs: 5,
    }), /identity mismatch/u);
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
});
