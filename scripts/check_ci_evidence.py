"""Validate document JSON and the recorded preview screenshots in the compared Git tree."""
import hashlib
import json
import os
import subprocess
import sys


PREVIEW = "docs/art/nectar-oblique-preview/"
MANIFEST = PREVIEW + "manifest.json"
IMAGE_TYPES = (".png", ".jpg", ".jpeg", ".webp", ".svg")


def invalid_constant(value):
    raise ValueError(f"{value} is not a JSON number")


def read_blob(tree, path):
    mode, _, oid = tree[path]
    if mode not in (b"100644", b"100755"):
        raise ValueError(f"{path!r} must be a regular file")
    return subprocess.check_output(["git", "cat-file", "blob", oid])


def check_preview(tree):
    images = {p for p in tree if p.startswith(PREVIEW) and p.lower().endswith(IMAGE_TYPES)}
    if MANIFEST not in tree:
        if images:
            raise ValueError(f"{MANIFEST} is missing")
        return  # The complete archive can be removed.
    manifest = json.loads(read_blob(tree, MANIFEST), parse_constant=invalid_constant)
    if not isinstance(manifest, dict) or not isinstance(manifest.get("screenshots"), list):
        raise ValueError(f"{MANIFEST} must list its screenshots")
    declared = set()
    for row in manifest["screenshots"]:
        name = row.get("file") if isinstance(row, dict) else None
        if not isinstance(name, str) or "/" in name or "\\" in name or PREVIEW + name not in images:
            raise ValueError(f"{MANIFEST} names an invalid or missing screenshot: {name!r}")
        path = PREVIEW + name
        if path in declared:
            raise ValueError(f"duplicate screenshot: {path!r}")
        if hashlib.sha256(read_blob(tree, path)).hexdigest() != row.get("sha256"):
            raise ValueError(f"SHA-256 mismatch for {path!r}")
        declared.add(path)
    if images != declared:
        raise ValueError(f"{MANIFEST} omits screenshots: {sorted(images - declared)!r}")


def main():
    check_all = sys.argv[2:] == ["--all"]
    changed = set() if check_all else {
        os.fsdecode(p) for p in sys.stdin.buffer.read().split(b"\0") if p.startswith(b"docs/")
    }
    check_archive = check_all or any(p.startswith(PREVIEW) for p in changed)
    records = {p for p in changed if p.endswith((".json", ".jsonl"))}
    if not (check_archive or records):
        return
    entries = subprocess.check_output(["git", "ls-tree", "-rz", sys.argv[1], "--", "docs"])
    tree = {}
    for entry in entries.split(b"\0"):
        if entry:
            metadata, path = entry.split(b"\t", 1)
            tree[os.fsdecode(path)] = metadata.split()
    if check_all:
        records = {p for p in tree if p.endswith((".json", ".jsonl"))}
    for path in sorted(records.intersection(tree) - {MANIFEST}):
        try:
            data = read_blob(tree, path)
            if path.endswith(".json"):
                json.loads(data, parse_constant=invalid_constant)
            else:
                for number, line in enumerate(data.splitlines(), 1):
                    try:
                        json.loads(line, parse_constant=invalid_constant)
                    except ValueError as exc:
                        raise ValueError(f"line {number}: {exc}") from exc
        except ValueError as exc:
            sys.exit(f"Invalid document {path!r}: {exc}")
    if check_archive:
        try:
            check_preview(tree)
        except ValueError as exc:
            sys.exit(f"Invalid preview archive {MANIFEST!r}: {exc}")


if __name__ == "__main__":
    main()
