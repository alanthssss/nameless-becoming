"""Check the JSON format of changed, archived evidence in the compared Git tree."""
import json
import os
import subprocess
import sys


def invalid_constant(value):
    raise ValueError(f"{value} is not a JSON number")


def main():
    revision = sys.argv[1]
    for raw_path in sys.stdin.buffer.read().split(b"\0"):
        if not raw_path.endswith((b".json", b".jsonl")):
            continue
        path = os.fsdecode(raw_path)
        data = subprocess.check_output(["git", "cat-file", "blob", f"{revision}:{path}"])
        try:
            if path.endswith(".jsonl"):
                for number, line in enumerate(data.splitlines(), 1):
                    try:
                        json.loads(line, parse_constant=invalid_constant)
                    except ValueError as exc:
                        raise ValueError(f"line {number}: {exc}") from exc
            else:
                json.loads(data, parse_constant=invalid_constant)
        except ValueError as exc:
            sys.exit(f"Invalid evidence in {path!r}: {exc}")


if __name__ == "__main__":
    main()
