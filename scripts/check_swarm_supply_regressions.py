#!/usr/bin/env python3
"""Reject shipped supply/flight split layouts in both content catalogues."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from check_swarm_regressions import GateError, prepare_project, replace_once

SOURCE = Path(__file__).resolve().parents[1] / "prototypes/swarm-flight"
SUMMARY = re.compile(r"^SUPPLY CHECKS: (\d+), failures (\d+)$", re.M)


def run(project):
    result = subprocess.run(
        [os.environ.get("GODOT_BIN", "godot"), "--headless", "--path", str(project),
         "--script", "res://verify.gd", "--", "--supply-only", "--swarm-qa"],
        capture_output=True, text=True, timeout=30,
    )
    output = result.stdout + result.stderr
    summary = SUMMARY.findall(output)
    errors = re.findall(r"^ERROR:\s*(.+)$", output, re.M)
    if re.search(r"SCRIPT ERROR|Parse Error|Compile Error", output) or len(summary) != 1:
        raise GateError("Supply test did not finish normally: " + output[-3000:])
    checks, failures = map(int, summary[0])
    if checks < 80 or failures != len(errors) or result.returncode != bool(failures):
        raise GateError("Incomplete supply test or inconsistent error/exit counts")
    return errors


def check_long_layouts(project):
    for name in ("long_journey_model.gd", "long_journey_content.gd",
                 "long_journey_verify.gd", "long_supply_contract.gd"):
        shutil.copy2(SOURCE / name, project / name)
    def run_long():
        result = subprocess.run(
            [os.environ.get("GODOT_BIN", "godot"), "--headless", "--path", str(project),
             "--script", "res://long_journey_verify.gd", "--", "--long-supply-only"],
            capture_output=True, text=True, timeout=30)
        output = result.stdout + result.stderr
        summary = re.findall(r"^LONG SUPPLY CHECKS: (\d+), failures (\d+)$", output, re.M)
        errors = re.findall(r"^FAIL: (.+)$", output, re.M)
        if re.search(r"SCRIPT ERROR|Parse Error|Compile Error|^ERROR:", output, re.M) or len(summary) != 1:
            raise GateError("Long supply checks did not finish normally: " + output[-3000:])
        checks, failures = map(int, summary[0])
        if checks < 100 or failures != len(errors) or result.returncode != bool(failures):
            raise GateError("Incomplete long supply checks")
        return errors
    content = project / "long_journey_content.gd"
    original = content.read_text()
    if run_long():
        raise GateError("Long supply baseline failed")
    mutants = {
        "long_upper_relay_lower_dew": (
            'dew(1900,420,"借风或绕篱后，在共同出口补给")',
            'dew(980,600,"篱下路线自己的补给","branch")'),
        "long_lower_relay_upper_dew": (
            'dew(1900,420,"借下方风或从上沿绕行后共同补给")',
            'dew(1080,190,"上沿路线自己的补给","branch")'),
    }
    for name, (old, new) in mutants.items():
        content.write_text(replace_once(original, old, new))
        errors = run_long()
        if not any(e.startswith("Long shared supply restores real stamina after chosen action:") for e in errors):
            raise GateError(name + " was not rejected by actual input pickup ordering")
        allowed = ("Long journey supply never rewards abandoning flight",
                   "Both long-journey routes pass their supply",
                   "Long shared supply restores real stamina after chosen action:",
                   "Shared supply restores its full amount when needed:")
        if not all(e.startswith(allowed) for e in errors):
            raise GateError(name + " failed unrelated assertions: " + str(errors))
        print(f"LONG SUPPLY REGRESSION CAUGHT: {name}, {len(errors)} assertions", flush=True)
    content.write_text(original)


def main():
    with tempfile.TemporaryDirectory(prefix="swarm-supply-canary-") as temp:
        project = Path(temp)
        prepare_project(SOURCE, project)
        content = project / "campaign_content.gd"
        original = content.read_text()
        if run(project):
            raise GateError("Unmutated supply baseline failed")
        print("SUPPLY REGRESSION BASELINE: passed", flush=True)
        mutants = {
            "05_lower_dew": ('chain([Vector2(420,230),Vector2(720,230)],[],Vector2(1000,230))',
                'chain([Vector2(420,230),Vector2(720,230)],[],Vector2(1000,230)),dew(650,580,"old lower supply","branch")'),
            "10_lower_dew": ('dew(1360,420,"穿帘或绕箱完成后在共同出口补给，接着斜向借风")',
                'dew(930,650,"old lower supply","branch")'),
            "13_lower_dew": ('dew(1340,460,"越过台面后在共同出口补给，接着穿过下一段侧风")',
                'dew(940,580,"old lower supply","branch")'),
        }
        for name, (old, new) in mutants.items():
            content.write_text(replace_once(original, old, new))
            errors = run(project)
            expected_count = {"05_lower_dew":3,"10_lower_dew":12,"13_lower_dew":12}[name]
            prefixes = (
                "Stamina supply never rewards abandoning the encounter's flight action",
                "Both authored branches retain access to their stamina supply",
                "Full-stamina summer opening does not bait a branch with redundant supply",
                "Supply is collected at the shared exit before the next action:",
                "Shared supply has a real stamina deficit to fill:",
                "Supply preserves the chosen flight or bypass action: 10 upper low-fixture",
                "Supply and following flight need no backtracking, collision or recovery: 13 upper low-fixture",
            )
            if len(errors) != expected_count or not all(error.startswith(prefixes) for error in errors):
                raise GateError(f"{name} failed unexpected assertions: {errors}")
            if "Stamina supply never rewards abandoning the encounter's flight action" not in errors:
                raise GateError(f"{name} did not fail the player-rule assertion")
            if name != "05_lower_dew" and not any(
                error.startswith("Supply is collected at the shared exit before the next action:")
                for error in errors
            ):
                raise GateError(f"{name} did not fail actual input pickup ordering")
            print(f"SUPPLY REGRESSION CAUGHT: {name}, {len(errors)} assertions", flush=True)
        content.write_text(original)
        check_long_layouts(project)
    print("SWARM SUPPLY REGRESSIONS VERIFIED: 5/5 layouts rejected")


if __name__ == "__main__":
    try:
        main()
    except (GateError, OSError, subprocess.TimeoutExpired) as exc:
        raise SystemExit(f"SUPPLY GATE FAILED: {exc}")
