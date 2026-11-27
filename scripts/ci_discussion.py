"""Check a small documentation diff from immutable GitHub objects, without a checkout."""
import base64
from functools import cache
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


class RejectedChange(ValueError):
    pass


def api(endpoint):
    return json.loads(subprocess.check_output(
        ["gh", "api", f"repos/{os.environ['GITHUB_REPOSITORY']}/{endpoint}"], timeout=15,
    ))


def check(base, head, checkout, *, push=False, get=api):
    if not all(re.fullmatch(r"[0-9a-f]{40}", sha) for sha in (base, head, checkout)):
        return False
    comparison = get(f"compare/{base}...{head}?per_page=1")
    original = comparison["merge_base_commit"]["sha"]
    if push and original != base:
        return False  # The push check uses a two-dot diff, including force pushes.
    files = comparison["files"]
    # The first compare page contains at most 300 files. Stay well below that cap.
    if not 0 < len(files) <= 10:
        return False
    paths = []
    for change in files:
        path = change["filename"]
        if (change["status"] not in {"added", "modified", "removed"}
                or not re.fullmatch(r"docs/(?:[\w.-]+/)*[\w.-]+\.md", path)
                or ".." in path.split("/") or "." in path.split("/")
                or path.startswith("docs/art/nectar-oblique-preview/")):
            return False
        paths.append(path)

    @cache
    def tree(sha):
        result = get(f"git/trees/{sha}")
        if result["truncated"]:
            raise ValueError("incomplete Git tree")
        return {item["path"]: item for item in result["tree"]}

    def entry(sha, path, *, attributes=False):
        for part in path.split("/"):
            items = tree(sha)
            if attributes and ".gitattributes" in items:
                raise ValueError("use checkout for path-specific Git attributes")
            item = items.get(part)
            if item is None:
                return None
            sha = item["sha"]
        return item

    @cache
    def blob(sha):
        data = get(f"git/blobs/{sha}")
        if data["encoding"] != "base64":
            raise ValueError("unsupported blob encoding")
        content = base64.b64decode(data["content"])
        if len(content) != data["size"]:
            raise ValueError("incomplete Git blob")
        return content

    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        router = root / "classify.sh"
        router.write_bytes(blob(entry(checkout, "scripts/classify_ci_changes.sh")["sha"]))
        selection = subprocess.check_output(
            ["bash", str(router)], input=b"".join(os.fsencode(p) + b"\0" for p in paths),
        )
        flags = dict(line.split("=", 1) for line in selection.decode().splitlines())
        checks = ("web", "godot", "export_game", "swarm", "flower", "garden", "content")
        expected = dict.fromkeys(checks, "false")
        expected.update(godot_suite="routes", swarm_suite="none")
        if flags != expected:
            return False

        # Compare complete regular blobs with native Git, including blank lines at EOF.
        for side in ("old", "new"):
            (root / side).mkdir()
        for change, path in zip(files, paths):
            entry(checkout, path, attributes=True)
            for side, revision in (("old", original), ("new", head)):
                item = entry(revision, path)
                missing = (side == "old" and change["status"] == "added"
                           or side == "new" and change["status"] == "removed")
                if (item is None) != missing:
                    return False
                if missing:
                    continue
                if item["mode"] not in {"100644", "100755"} or item["size"] > 1024 * 1024:
                    return False
                target = root / side / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(blob(item["sha"]))
        result = subprocess.run(["git", "diff", "--no-index", "--check", "old", "new"], cwd=root)
        if result.returncode not in (0, 1):  # --no-index also sets --exit-code for clean differences.
            raise RejectedChange("Discussion document whitespace check failed")
    return True


def prior_text_result(event, checkout, current_run, get=api):
    """Return the last gate's result only when it checked this exact PR comparison."""
    if (event.get("action") != "edited"
            or not event.get("changes") or event["changes"].keys() - {"title", "body"}):
        return None
    pr = event["pull_request"]
    head, base = pr["head"], pr["base"]
    runs = get(f"actions/workflows/quality.yml/runs?event=pull_request&head_sha={head['sha']}&per_page=2")["workflow_runs"]
    if len(runs) != 2 or runs[0]["id"] != current_run:
        return None
    previous = runs[1]
    if (previous["status"] != "completed" or previous["conclusion"] not in ("success", "failure")
            or previous["head_sha"] != head["sha"] or previous["head_branch"] != head["ref"]
            or previous["head_repository"]["full_name"] != head["repo"]["full_name"]):
        return None
    run_id, attempt = previous["id"], previous["run_attempt"]
    result = get(f"actions/runs/{run_id}/attempts/{attempt}/jobs?per_page=100")
    gates = [job for job in result["jobs"] if job["name"] == "CI required checks"]
    if result["total_count"] != len(result["jobs"]) or len(gates) != 1:
        return None
    gate = gates[0]
    marker = f"Gate outcome v1 PR {pr['number']} base {base['ref']} {base['sha']} merge {checkout}"
    if (gate["run_id"] != run_id or gate["run_attempt"] != attempt or gate["head_sha"] != head["sha"]
            or gate["status"] != "completed" or gate["conclusion"] != previous["conclusion"]
            or not any(step["name"] == marker and step["conclusion"] == "success" for step in gate["steps"])):
        return None
    print(f"PR text edit carries forward the {gate['conclusion']} from run {run_id}.")
    return gate["conclusion"]


def main():
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_bytes())
    push = os.environ["GITHUB_EVENT_NAME"] == "push"
    success = True
    try:
        if push:
            base, head = event["before"], event["after"]
        else:
            pr = event["pull_request"]
            base, head = pr["base"]["sha"], pr["head"]["sha"]
        checkout = os.environ["GITHUB_SHA"]
        prior = None
        if not push and os.environ["GITHUB_RUN_ATTEMPT"] == "1":
            prior = prior_text_result(event, checkout, int(os.environ["GITHUB_RUN_ID"]))
        if prior == "failure":
            raise RejectedChange("The previous gate failed for this same comparison.")
        matched = prior == "success" or check(base, head, checkout, push=push)
    except RejectedChange as error:
        print(error, file=sys.stderr)
        matched, success = True, False
    except (OSError, subprocess.SubprocessError, ValueError, TypeError, KeyError) as error:
        print(f"Using checkout for this comparison: {error}", file=sys.stderr)
        matched = False
    with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as output:
        print(f"handled={str(matched).lower()}", file=output)
    if not success:
        sys.exit(1)
    if matched:
        print("Lightweight check completed without a repository checkout.")


if __name__ == "__main__":
    main()
