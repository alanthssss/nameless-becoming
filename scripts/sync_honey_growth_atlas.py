#!/usr/bin/env python3
"""Refresh the interactive Honey atlas from its canonical rank catalog."""
import argparse
import json
import re
import sys
from pathlib import Path

DATA_TAG = re.compile(
    r'(<script type="application/json" id="treeData">)(.*?)(</script>)',
    re.DOTALL,
)
ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATA = ROOT / "docs/design/honey-growth-tree-v2.json"
DEFAULT_ATLAS = ROOT / "docs/design/honey-growth-atlas-v2.html"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Report stale embedded data without touching the file")
    parser.add_argument("--data", type=Path, default=DEFAULT_DATA)
    parser.add_argument("--atlas", type=Path, default=DEFAULT_ATLAS)
    args = parser.parse_args()

    try:
        data = json.loads(args.data.read_text(encoding="utf-8"))
        source = args.atlas.read_text(encoding="utf-8")
    except (OSError, ValueError) as error:
        parser.exit(1, f"{error}\n")
    payload = json.dumps(data, ensure_ascii=False, separators=(",", ":")).replace("<", r"\u003c")
    updated, count = DATA_TAG.subn(lambda match: match[1] + payload + match[3], source)
    if count != 1:
        parser.exit(1, f"Expected one treeData script in {args.atlas}, found {count}\n")
    if updated == source:
        print(f"Atlas data verified: {len(data['cells'])} cells, {len(data['ranks'])} ranks")
        return 0
    if args.check:
        print(f"Stale atlas data: {args.atlas}", file=sys.stderr)
        return 1
    args.atlas.write_text(updated, encoding="utf-8")
    print(f"Refreshed {args.atlas}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
