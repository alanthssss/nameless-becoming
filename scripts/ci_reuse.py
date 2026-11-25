"""Reuse certified prototype results only across a clean synchronization with main."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys


SHA = r"[0-9a-f]{40}"
PROTOTYPES = ("swarm", "flower", "garden")
# These control how evidence is produced/verified or supply shared test tooling.
CONTROL_PATHS = (
    ".github/actions", ".github/workflows/quality.yml", "scripts/ci_scope.sh", "scripts/ci_reuse.py",
    "scripts/classify_ci_changes.sh", "scripts/check_ci_results.py", "scripts/check_ci_evidence.py",
    "scripts/lint_workflows.sh", "tests/ci-scope.test.sh", ":(glob)tests/test_ci_*.py",
    ".gitattributes", ".gitmodules", "package.json", "package-lock.json",
)
MARKER = re.compile(
    rf"Prototype evidence v1 PR (?P<number>[1-9][0-9]*) base (?P<base>{SHA}) tree (?P<tree>{SHA}) "
    r"swarm (?P<swarm>none|region|full) flower (?P<flower>true|false) garden (?P<garden>true|false)"
)


def git(*args):
    return subprocess.check_output(["git", *args], stderr=subprocess.PIPE)


def ancestor(first, second):
    return subprocess.run(["git", "merge-base", "--is-ancestor", first, second],
                          stderr=subprocess.DEVNULL).returncode == 0


def merge_tree(first, second):
    # A conflict exits nonzero even when Git produces a provisional tree.
    return git("merge-tree", "--write-tree", first, second).decode().strip()


def controls_changed(first, second):
    return bool(git("diff", "--name-only", "-z", first, second, "--", *CONTROL_PATHS))


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
    jobs = api(f"{endpoint}/runs/{run_id}/attempts/{attempt}/jobs?per_page=100")["jobs"]
    gates = [job for job in jobs if job["name"] == "CI required checks"]
    if len(gates) != 1:
        return None
    gate = gates[0]
    if (gate["status"] != "completed" or gate["conclusion"] != "success"
            or gate["run_id"] != run_id or gate["run_attempt"] != attempt or gate["head_sha"] != before):
        return None
    markers = [MARKER.fullmatch(step["name"]) for step in gate["steps"]
               if step["status"] == "completed" and step["conclusion"] == "success"]
    matches = [marker for marker in markers if marker and marker["number"] == str(number)]
    return (run_id, matches[0]) if len(matches) == 1 else None


def decide(event, repo, selected, api):
    fresh = (set(), None)
    if event.get("action") != "synchronize" or not any(selected[p] == "true" for p in PROTOTYPES):
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
    if controls_changed(base, head):
        return fresh
    try:
        if merge_tree(before, base) != current_tree:
            return fresh
    except subprocess.CalledProcessError:
        return fresh  # Includes missing history and conflict resolutions.
    evidence = previous_evidence(api, repo, pr["head"]["ref"], before, pr["number"])
    if not evidence:
        return fresh
    run_id, prior = evidence
    if not ancestor(prior["base"], base) or controls_changed(prior["base"], before):
        return fresh
    # Reconstruct what Actions checked out, which may differ from the old PR head.
    if merge_tree(prior["base"], before) != prior["tree"] or controls_changed(prior["tree"], current_tree):
        return fresh
    paths = git("diff", "--name-only", "--no-renames", "-z", prior["tree"], current_tree, "--")
    impact = {}
    if paths:
        flags = subprocess.check_output(["bash", "scripts/classify_ci_changes.sh"], input=paths)
        impact = dict(line.split("=", 1) for line in flags.decode().splitlines())
    reusable = set()
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
            print("No prototype results reused. Selected checks run on this revision.", file=summary)


if __name__ == "__main__":
    main()
