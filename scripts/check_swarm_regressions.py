#!/usr/bin/env python3
"""Prove that the existing seasonal tests reject two previously shipped wind bugs.

Only a disposable script-only project is mutated. A crash, timeout, missing test
summary, or unrelated failure is an infrastructure failure, never a caught bug.
"""
import argparse
from dataclasses import dataclass
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


SCRIPTS = (
    "verify.gd", "game_model.gd", "save_data.gd", "chapter_data.gd",
    "campaign_content.gd", "event_data.gd", "route_driver.gd", "supply_contract.gd",
)
SUMMARY = re.compile(r"^SEASON ELEMENT CHECKS: (\d+), failures (\d+)$", re.M)
ERROR = re.compile(r"^ERROR:\s*(.+)$", re.M)
MOVEMENT_FAILURE = re.compile(
    r"Authored airflow (\d+/\d+) continuously affects (release|charge) "
    r"\(-?[\d.]+ px\)"
)
CUE_FAILURE = "Nearby wind never claims it is already pushing the player"


class GateError(RuntimeError):
    pass


@dataclass(frozen=True)
class Report:
    checks: int
    failures: tuple[str, ...]


def replace_once(source: str, old: str, new: str) -> str:
    if source.count(old) != 1:
        raise GateError("Mutation/isolation anchor changed; review the canary before proceeding")
    return source.replace(old, new, 1)


def mutate(source: str, name: str) -> str:
    if name == "wind_requires_steering":
        return replace_once(
            source, "\t\ttarget += effective_airflow()\n",
            "\t\tif not charging and direction.length() > 0.01:\n"
            "\t\t\ttarget += effective_airflow()\n",
        )
    if name == "preview_claims_contact":
        return replace_once(
            source, "func airflow_cue() -> Dictionary:\n\tvar flow := airflow_at(p)\n",
            "func airflow_cue() -> Dictionary:\n\tvar flow := Vector2.ZERO\n"
            "\tfor field in airflows:\n"
            "\t\tif field.rect.grow(80).has_point(p): flow += field.direction*field.strength\n",
        )
    raise GateError(f"Unknown canary: {name}")


def inspect_result(returncode: int, output: str, expected_checks: int | None = None) -> Report:
    if re.search(r"SCRIPT ERROR|Parse Error|Compile Error", output):
        raise GateError("Engine/script error is not a caught regression")
    summaries = SUMMARY.findall(output)
    if len(summaries) != 1:
        raise GateError("Missing or repeated seasonal test completion summary")
    checks, failures = map(int, summaries[0])
    errors = tuple(ERROR.findall(output))
    if checks < 100 or (expected_checks is not None and checks != expected_checks):
        raise GateError(f"Incomplete/changed assertion count: {checks}, expected {expected_checks}")
    if len(errors) != failures or returncode != (1 if failures else 0):
        raise GateError("Exit status/errors do not agree with completed assertion failures")
    return Report(checks, errors)


def validate_canary(name: str, report: Report) -> None:
    if name == "wind_requires_steering":
        matches = [MOVEMENT_FAILURE.fullmatch(error) for error in report.failures]
        if len(matches) != 12 or not all(matches):
            raise GateError("Steering mutant must fail only the six release and six charge assertions")
        for mode in ("release", "charge"):
            regions = {m[1] for m in matches if m and m[2] == mode}
            if len(regions) != 6:
                raise GateError(f"The {mode} regression was not detected in all six wind regions")
    elif name == "preview_claims_contact":
        if report.failures != (CUE_FAILURE,) * 6:
            raise GateError("Contact mutant must fail only the six outside-field feedback assertions")
    else:
        raise GateError(f"Unknown canary: {name}")


def prepare_project(source: Path, target: Path) -> None:
    for filename in SCRIPTS:
        shutil.copyfile(source / filename, target / filename)
    # No scene/assets or real project user directory are loaded. Explicitly
    # relocate BOTH possible save entry points in this disposable copy; the
    # original assertions and their journey_v2 suffix expectation stay intact.
    save = target / "save_data.gd"
    save.write_text(replace_once(
        save.read_text(), '"user://before_the_rain_journey_v2.json"',
        json.dumps(str(target / "before_the_rain_journey_v2.json")),
    ))
    verify = target / "verify.gd"
    verify.write_text(replace_once(
        verify.read_text(), 'OS.get_cache_dir().path_join("swarm-journey-verify.json")',
        json.dumps(str(target / "swarm-journey-verify.json")),
    ))
    (target / "project.godot").write_text(
        'config_version=5\n[application]\nconfig/name="Swarm Regression Isolation"\n'
        '[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
    )


def run_verify(godot: str, project: Path, timeout: float, expected_checks: int | None = None) -> Report:
    try:
        result = subprocess.run(
            [godot, "--headless", "--path", str(project), "--log-file",
             str(project / "engine.log"), "--script", "res://verify.gd", "--",
             "--season-elements-only", "--swarm-qa"],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            timeout=timeout, check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise GateError(f"Seasonal test timed out after {timeout}s; no regression evidence") from exc
    try:
        return inspect_result(result.returncode, result.stdout, expected_checks)
    except GateError:
        print(result.stdout[-12000:], file=sys.stderr)
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--timeout", type=float, default=15)
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[1] / "prototypes" / "swarm-flight"
    try:
        with tempfile.TemporaryDirectory(prefix="swarm-regression-") as directory:
            project = Path(directory)
            prepare_project(source, project)
            model = project / "game_model.gd"
            original = model.read_text()
            baseline = run_verify(args.godot, project, args.timeout)
            if baseline.failures:
                raise GateError("Baseline must pass before mutations can provide evidence")
            print(f"SWARM REGRESSION BASELINE: {baseline.checks} checks passed", flush=True)
            for name in ("wind_requires_steering", "preview_claims_contact"):
                model.write_text(mutate(original, name))
                report = run_verify(args.godot, project, args.timeout, baseline.checks)
                validate_canary(name, report)
                print(f"SWARM REGRESSION CAUGHT: {name}, {len(report.failures)} expected failures", flush=True)
        print("SWARM REGRESSIONS VERIFIED: 2/2 known bug classes rejected")
        return 0
    except (GateError, OSError) as exc:
        print(f"SWARM REGRESSION GATE FAILED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
