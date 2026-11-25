"""Reuse certified check results only across a clean synchronization with main."""
from collections import Counter
import json
import os
from pathlib import Path
import re
import subprocess
import sys


SHA = r"[0-9a-f]{40}"
PROTOTYPES = ("swarm", "flower", "garden")
BUILD_JOBS = {
    "web": ("web", "Web build, tests and lint"),
    "godot": ("godot", "Godot 4.6.2 tests"),
    "web-candidate": ("export_game", "Clean Web game and site candidate"),
}
# Topic edits to any control invalidate reuse. Only the following routing and
# document checks can change on main without changing how a prototype executes.
ROUTING_FILES = (
    "scripts/classify_ci_changes.sh", "scripts/ci_scope.sh", "scripts/check_ci_evidence.py",
    "tests/ci-scope.test.sh", "tests/test_ci_routing.py",
)
CONTROL_PATHS = (
    *ROUTING_FILES, ".github/actions", ".github/workflows/quality.yml", "scripts/ci_reuse.py",
    "scripts/check_ci_results.py", "scripts/lint_workflows.sh", ":(glob)tests/test_ci_*.py",
    ".gitattributes", ".gitmodules", "package.json", "package-lock.json",
)
SWARM_NONREGIONAL = {"core", "regressions", "samples", "samples-save", "migrations"}
MARKER = re.compile(
    rf"Prototype evidence v1 PR (?P<number>[1-9][0-9]*) base (?P<base>{SHA}) tree (?P<tree>{SHA}) "
    r"swarm (?P<swarm>none|region|full) flower (?P<flower>true|false) garden (?P<garden>true|false)"
)
BUILD_MARKER = re.compile(
    rf"Build evidence v1 PR (?P<number>[1-9][0-9]*) base (?P<base>{SHA}) tree (?P<tree>{SHA}) "
    r"web (?P<web>true|false) godot (?P<godot>none|routes|full) export (?P<export_game>true|false)"
)


def git(*args):
    return subprocess.check_output(["git", *args], stderr=subprocess.PIPE)


def ancestor(first, second):
    return subprocess.run(["git", "merge-base", "--is-ancestor", first, second],
                          stderr=subprocess.DEVNULL).returncode == 0


def merge_tree(first, second):
    # A conflict exits nonzero even when Git produces a provisional tree.
    return git("merge-tree", "--write-tree", first, second).decode().strip()


def changed_paths(first, second, *pathspecs):
    # Disabling rename detection keeps both sides of moves, including moves
    # between a routing file and a runtime input. Preserve arbitrary filenames.
    paths = git("diff", "--name-only", "--no-renames", "-z", first, second, "--", *pathspecs)
    return {os.fsdecode(path) for path in paths.split(b"\0") if path}


def directly_passed(group, swarm_suite, passed_jobs):
    if group in BUILD_JOBS:
        return BUILD_JOBS[group][1] in passed_jobs
    if group in ("flower", "garden"):
        title = "Flower Step" if group == "flower" else "Garden Puzzles"
        return f"{title} / {title} rules and complete routes" in passed_jobs
    suites = SWARM_NONREGIONAL if group == "swarm-except-region" else {"region-greybox"}
    if group == "swarm" and swarm_suite == "full":
        suites = suites | SWARM_NONREGIONAL
    return all(f"Swarm Flight / Swarm Flight checks ({suite})" in passed_jobs for suite in suites)


def previous_evidence(api, repo, branch, before, number):
    endpoint = f"repos/{repo}/actions"
    runs = api(f"{endpoint}/workflows/quality.yml/runs?event=pull_request&head_sha={before}&per_page=1")
    # Do not look past a newer failed, running or cancelled attempt to find a green one.
    if not runs["workflow_runs"]:
        return None
    run = runs["workflow_runs"][0]
    if (run["path"] != ".github/workflows/quality.yml" or run["event"] != "pull_request"
            or run["head_sha"] != before or run["head_branch"] != branch
            or run["repository"]["full_name"] != repo or run["head_repository"]["full_name"] != repo
            or run["status"] != "completed" or run["conclusion"] != "success"):
        return None
    run_id, attempt = run["id"], run["run_attempt"]
    if not all(type(n) is int and n > 0 for n in (run_id, attempt)):
        return None
    response = api(f"{endpoint}/runs/{run_id}/attempts/{attempt}/jobs?per_page=100")
    jobs = response["jobs"]
    if response["total_count"] != len(jobs):
        return None  # Incomplete list cannot prove unique execution or a unique gate.
    gates = [job for job in jobs if job["name"] == "CI required checks"]
    if len(gates) != 1:
        return None
    gate = gates[0]
    if (gate["status"] != "completed" or gate["conclusion"] != "success"
            or gate["run_id"] != run_id or gate["run_attempt"] != attempt or gate["head_sha"] != before):
        return None
    steps = [step["name"] for step in gate["steps"]
             if step["status"] == "completed" and step["conclusion"] == "success"]
    markers = [MARKER.fullmatch(name) for name in steps]
    matches = [marker for marker in markers if marker and marker["number"] == str(number)]
    if len(matches) != 1:
        return None
    counts = Counter(job["name"] for job in jobs)
    passed_jobs = {
        job["name"] for job in jobs
        if counts[job["name"]] == 1 and job["status"] == "completed" and job["conclusion"] == "success"
        and job["run_id"] == run_id and job["run_attempt"] == attempt and job["head_sha"] == before
    }
    prior = matches[0]
    builds = [BUILD_MARKER.fullmatch(name) for name in steps if name.startswith("Build evidence ")]
    build = builds[0] if len(builds) == 1 else None
    if build and any(build[field] != prior[field] for field in ("number", "base", "tree")):
        build = None
    return run_id, prior, passed_jobs, build


def affected_builds(paths, impact):
    """Add cross-job inputs to the ordinary first-run path classification."""
    if not paths:
        return set()
    site = any(path.startswith(("app/", "src/", "public/", "build/", "worker/", "db/", "drizzle/", ".openai/"))
               or ".config." in path.rsplit("/", 1)[-1]
               or path.startswith("wrangler.") or path in ("tsconfig.json", "tests/rendered-html.test.mjs")
               for path in paths)
    engine = any(path.startswith("godot/") for path in paths)
    # npm test builds the site and reads the material contracts and main engine.
    # ESLint traverses JS/TS even when it lives in a prototype or a docs folder.
    lint = any(path.lower().endswith((".js", ".jsx", ".cjs", ".mjs", ".ts", ".tsx", ".cts", ".mts"))
               for path in paths)
    affected = set()
    if site or engine or lint or impact["web"] == "true" or impact["content"] == "true":
        affected.add("web")
    if engine or impact["godot"] == "true":
        affected.add("godot")
    if site or engine or impact["export_game"] == "true":
        affected.add("web-candidate")
    return affected


def decide(event, repo, selected, api):
    fresh = (set(), None)
    if event.get("action") != "synchronize" or not any(
            selected.get(p) == "true" for p in (*PROTOTYPES, "web", "godot", "export_game")):
        return fresh
    pr = event["pull_request"]
    base, head, before = pr["base"]["sha"], pr["head"]["sha"], event.get("before", "")
    if (pr["base"]["ref"] != "main" or pr["base"]["repo"]["full_name"] != repo
            or pr["head"]["repo"]["full_name"] != repo
            or not all(re.fullmatch(SHA, sha) and sha != "0" * 40 for sha in (base, head, before))):
        return fresh
    if not ancestor(base, head):
        return fresh
    # Rebasing may remove the old tip from advertised refs. Only fetch the immutable
    # SHA from this same-repository synchronize event; otherwise run fresh.
    if subprocess.run(["git", "cat-file", "-e", f"{before}^{{commit}}"],
                      stderr=subprocess.DEVNULL).returncode:
        subprocess.run(["git", "fetch", "--no-tags", "--no-write-fetch-head", "--no-recurse-submodules",
                        "origin", before], check=True, timeout=15, stdout=subprocess.DEVNULL,
                       stderr=subprocess.PIPE)
    if ancestor(base, before):
        return fresh  # An ordinary new PR commit is validated normally.
    current_tree = git("rev-parse", "HEAD^{tree}").decode().strip()
    if current_tree != git("rev-parse", f"{head}^{{tree}}").decode().strip():
        return fresh
    if changed_paths(base, head, *CONTROL_PATHS):
        return fresh
    try:
        if merge_tree(before, base) != current_tree:
            return fresh
    except subprocess.CalledProcessError:
        return fresh  # Includes missing history and conflict resolutions.
    evidence = previous_evidence(api, repo, pr["head"]["ref"], before, pr["number"])
    if not evidence:
        return fresh
    run_id, prior, passed_jobs, build = evidence
    if not ancestor(prior["base"], base) or changed_paths(prior["base"], before, *CONTROL_PATHS):
        return fresh
    # Reconstruct what Actions checked out, which may differ from the old PR head.
    if merge_tree(prior["base"], before) != prior["tree"]:
        return fresh
    controls = changed_paths(prior["tree"], current_tree, *CONTROL_PATHS)
    if controls.difference(ROUTING_FILES):
        return fresh
    paths = changed_paths(prior["tree"], current_tree) - controls
    impact = {}
    if paths:
        payload = b"".join(os.fsencode(path) + b"\0" for path in sorted(paths))
        flags = subprocess.check_output(["bash", "scripts/classify_ci_changes.sh"], input=payload)
        impact = dict(line.split("=", 1) for line in flags.decode().splitlines())
    reusable = set()
    if build:
        affected = affected_builds(paths, impact)
        for group, (flag, _) in BUILD_JOBS.items():
            if selected.get(flag) != "true" or group in affected:
                continue
            if group == "godot":
                if build[flag] == "full" or build[flag] == selected["godot_suite"] == "routes":
                    reusable.add(group)
            elif build[flag] == "true":
                reusable.add(group)
    for name in PROTOTYPES:
        if selected[name] != "true" or (paths and impact[name] != "false"):
            continue
        if name == "swarm":
            if prior[name] == "full" or prior[name] == selected["swarm_suite"] == "region":
                reusable.add(name)
        elif prior[name] == "true":
            reusable.add(name)
    if (selected["swarm"] == "true" and prior["swarm"] == selected["swarm_suite"] == "full"
            and impact.get("swarm_suite") == "region"):
        reusable.add("swarm-except-region")
    if controls:
        # A new router can select work the old router never actually ran.
        # A carried-forward group certificate alone does not establish this.
        reusable = {name for name in reusable if directly_passed(name, selected["swarm_suite"], passed_jobs)}
    return (reusable, run_id) if reusable else fresh


def actions_api(path):
    return json.loads(subprocess.check_output(["gh", "api", path], timeout=15, stderr=subprocess.PIPE))


def main():
    groups, source = set(), None
    repo = os.environ["GITHUB_REPOSITORY"]
    if os.environ["GITHUB_EVENT_NAME"] == "pull_request":
        try:
            event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_bytes())
            groups, source = decide(event, repo, json.loads(os.environ["CI_SELECTION"]), actions_api)
        except (OSError, subprocess.SubprocessError, ValueError, TypeError, KeyError, IndexError):
            print("Previous check evidence unavailable. Running selected checks.", file=sys.stderr)
    names = sorted(groups)
    tree = git("rev-parse", "HEAD^{tree}").decode().strip()
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
        print(f"reused={json.dumps(names)}", f"source_run={source or 'none'}", f"tested_tree={tree}",
              sep="\n", file=output)
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as summary:
        if source:
            print(f"Reused after comparing integrated trees: {', '.join(names)}. "
                  f"[Previous successful run](https://github.com/{repo}/actions/runs/{source}).", file=summary)
            if "swarm-except-region" in groups:
                print("Five Swarm Flight suites are covered by that result; region-greybox runs here.", file=summary)
        else:
            print("No results reused. Selected checks run on this revision.", file=summary)


if __name__ == "__main__":
    main()
