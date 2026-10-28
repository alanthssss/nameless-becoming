"""Check the internal 03→05 review record before packaging for user review.

Public API: validate_review(record, revision, evidence_root) -> list[str].
An empty list means declarations and referenced evidence are complete, NOT that
reviewer judgments are true, play is enjoyable, art is good, or a human accepted
this build. This deliberately does not interpret prose or decode/authenticate
media. A synthetic passing test fixture is never actual acceptance evidence.

Minimal JSON record (all keys shown are required):
{
  "revision": "<same full 40-character frozen Git revision>",
  "status": "ready", "author": "author identity", "reviewer": "other identity",
  "human_acceptance_claim": false, "blockers": [],
  "chapters": [
    {
      "chapter": "03", "method": "exploratory_continuous",
      "known_solution_used": false,
      "before": {
        "goal": "Goal predicted before operating",
        "options": [
          {"approach": "upper", "action": "What I could do",
           "expected_consequence": "What I expect",
           "visual_basis": "Visible clue before acting"},
          {"approach": "lower", "action": "Another possible action",
           "expected_consequence": "Expected result", "visual_basis": "Clue"}
        ]
      },
      "after": [{"approach": "upper", "consequence": "What actually happened"}],
      "verdict": "pass", "conclusion": "Specific review conclusion",
      "evidence": [{"path": "raw/03.png", "sha256": "<64 hex digits>",
                    "raw": true}]
    },
    "<equivalent records for 04 and 05>"
  ]
}

Exactly one record for each chapter is required. Each records at least two
possible approaches before acting and at least one observed outcome afterward.
04 must observe at least two distinct declared approaches, with different outcome
text, and additionally contain:
  "choice_comparison": {
    "dimensions": ["exposure"],
    "description": "Explain consequential difference between the approaches",
    "route_or_state_only": false
  }
Allowed dimensions: exposure, timing, resource_use, next_action, information.
Turn count, different coordinates, or a state transition alone do not qualify.
This is a required reviewer declaration, not a semantic proof of that claim.

Evidence paths must be relative to evidence_root, resolve to nonempty regular
files inside it, and have a screenshot/video extension. Every supplied hash is
verified. References with parent traversal or a symlink escaping root are refused.
Keep original media and the frozen review record together. This checker does not
run the game, generate evidence, or contact anyone.

CLI: python3 spring_review_gate.py RECORD.json --revision FULL_GIT_SHA \\
       --evidence-root PATH
Returns 0 for structurally ready, 1 for rejected, and 2 for an unreadable record.
Wire this command/API into the real packaging precondition; a standalone passing
run must never be described as product acceptance.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

_CHAPTERS = {"03", "04", "05"}
_DIMENSIONS = {"exposure", "timing", "resource_use", "next_action", "information"}
_MEDIA = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".mp4", ".mov", ".webm", ".m4v"}


def _text(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_review(record: object, revision: str, evidence_root: str | Path) -> list[str]:
    """Return human-readable errors; [] checks completeness, not review truth."""
    errors: list[str] = []
    if not isinstance(record, dict):
        return ["record: expected an object"]
    if not isinstance(revision, str) or not re.fullmatch(r"[0-9a-f]{40}", revision):
        errors.append("revision: expected a full lowercase frozen Git revision")
    if record.get("revision") != revision:
        errors.append("record.revision: does not match the frozen revision")
    if record.get("status") != "ready":
        errors.append("status: must be ready")
    for field in ("author", "reviewer"):
        if not _text(record.get(field)):
            errors.append(f"{field}: must be a nonempty identity")
    if all(_text(record.get(key)) for key in ("author", "reviewer")):
        if record["author"].strip().casefold() == record["reviewer"].strip().casefold():
            errors.append("reviewer: author cannot sign their own review")
    if record.get("human_acceptance_claim") is not False:
        errors.append("human_acceptance_claim: must explicitly be false")
    if not isinstance(record.get("blockers"), list) or record["blockers"]:
        errors.append("blockers: must be an explicitly empty list")
    try:
        root = Path(evidence_root).resolve(strict=True)
        if not root.is_dir():
            raise ValueError("not a directory")
    except (OSError, ValueError, TypeError, RuntimeError):
        root = None
        errors.append("evidence_root: must resolve to an existing directory")

    chapters = record.get("chapters")
    if not isinstance(chapters, list):
        return errors + ["chapters: expected exactly one record for 03, 04, and 05"]
    found: list[str] = []
    for index, chapter in enumerate(chapters):
        label = f"chapters[{index}]"
        if not isinstance(chapter, dict):
            errors.append(f"{label}: expected an object")
            continue
        chapter_id = chapter.get("chapter")
        if not isinstance(chapter_id, str) or chapter_id not in _CHAPTERS:
            errors.append(f"{label}.chapter: must be 03, 04, or 05")
        else:
            found.append(chapter_id)
            label = f"chapter {chapter_id}"
        if chapter.get("method") != "exploratory_continuous":
            errors.append(f"{label}.method: must be exploratory_continuous; known_answer_route is not a review")
        if chapter.get("known_solution_used") is not False:
            errors.append(f"{label}.known_solution_used: must explicitly be false")
        if chapter.get("verdict") != "pass":
            errors.append(f"{label}.verdict: must be pass before delivery")
        if not _text(chapter.get("conclusion")):
            errors.append(f"{label}.conclusion: must record a specific conclusion")

        before = chapter.get("before")
        approaches: list[str] = []
        if not isinstance(before, dict):
            errors.append(f"{label}.before: expected goal and options recorded before acting")
        else:
            if not _text(before.get("goal")):
                errors.append(f"{label}.before.goal: must be nonempty")
            options = before.get("options")
            if not isinstance(options, list) or len(options) < 2:
                errors.append(f"{label}.before.options: at least two possible approaches required")
            else:
                for number, option in enumerate(options):
                    at = f"{label}.before.options[{number}]"
                    if not isinstance(option, dict):
                        errors.append(f"{at}: expected an object")
                        continue
                    for field in ("approach", "action", "expected_consequence", "visual_basis"):
                        if not _text(option.get(field)):
                            errors.append(f"{at}.{field}: must be nonempty")
                    if _text(option.get("approach")):
                        approaches.append(option["approach"].strip())
                if len(set(approaches)) != len(approaches):
                    errors.append(f"{label}.before.options: approach identities must be distinct")

        after = chapter.get("after")
        observed: list[str] = []
        consequences: list[str] = []
        if not isinstance(after, list) or not after:
            errors.append(f"{label}.after: actual consequences are required")
        else:
            for number, result in enumerate(after):
                at = f"{label}.after[{number}]"
                if not isinstance(result, dict):
                    errors.append(f"{at}: expected an object")
                    continue
                approach = result.get("approach")
                if not _text(approach) or approach.strip() not in approaches:
                    errors.append(f"{at}.approach: must identify a declared option")
                else:
                    observed.append(approach.strip())
                if not _text(result.get("consequence")):
                    errors.append(f"{at}.consequence: must state an actual consequence")
                else:
                    consequences.append(result["consequence"].strip())
            if len(set(observed)) != len(observed):
                errors.append(f"{label}.after: duplicate approach outcomes are not separate choices")
        if chapter_id == "04":
            if len(set(observed)) < 2 or len(set(consequences)) < 2:
                errors.append("chapter 04.after: two distinct approaches and different actual consequences required")
            comparison = chapter.get("choice_comparison")
            if not isinstance(comparison, dict):
                errors.append("chapter 04.choice_comparison: consequential choice comparison required")
            else:
                dimensions = comparison.get("dimensions")
                if (not isinstance(dimensions, list) or not dimensions
                        or any(not isinstance(d, str) or d not in _DIMENSIONS for d in dimensions)):
                    errors.append("chapter 04.choice_comparison.dimensions: exposure/timing/resource_use/next_action/information required")
                if not _text(comparison.get("description")):
                    errors.append("chapter 04.choice_comparison.description: explain the observed difference")
                if comparison.get("route_or_state_only") is not False:
                    errors.append("chapter 04.choice_comparison: route/state change alone is insufficient")

        evidence = chapter.get("evidence")
        if not isinstance(evidence, list) or not evidence:
            errors.append(f"{label}.evidence: raw screenshot/video reference required")
            continue
        for number, item in enumerate(evidence):
            at = f"{label}.evidence[{number}]"
            if not isinstance(item, dict):
                errors.append(f"{at}: expected an object")
                continue
            if item.get("raw") is not True:
                errors.append(f"{at}.raw: must explicitly identify raw evidence")
            digest = item.get("sha256")
            if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
                errors.append(f"{at}.sha256: expected 64 lowercase hex digits")
            relative = item.get("path")
            if not _text(relative):
                errors.append(f"{at}.path: nonempty relative path required")
                continue
            path = Path(relative)
            if path.is_absolute() or ".." in path.parts or "\\" in relative:
                errors.append(f"{at}.path: absolute paths and traversal are forbidden")
                continue
            if path.suffix.lower() not in _MEDIA:
                errors.append(f"{at}.path: screenshot/video extension required")
                continue
            if root is None:
                continue
            try:
                actual = (root / path).resolve(strict=True)
                actual.relative_to(root)
                if not actual.is_file() or actual.stat().st_size == 0:
                    raise ValueError("expected a nonempty regular file")
                checksum = hashlib.sha256()
                with actual.open("rb") as stream:
                    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                        checksum.update(chunk)
                if checksum.hexdigest() != digest:
                    errors.append(f"{at}.sha256: does not match the raw evidence file")
            except (OSError, ValueError, RuntimeError):
                errors.append(f"{at}.path: must resolve to a nonempty file inside evidence_root")
    if sorted(found) != sorted(_CHAPTERS) or len(chapters) != 3:
        errors.append("chapters: expected exactly one record each for 03, 04, and 05")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--evidence-root", required=True, type=Path)
    args = parser.parse_args()
    try:
        record = json.loads(args.record.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print(f"Cannot read review record: {exc}", file=sys.stderr)
        return 2
    errors = validate_review(record, args.revision, args.evidence_root)
    if errors:
        print("Internal review record rejected:\n- " + "\n- ".join(errors), file=sys.stderr)
        return 1
    print("Internal review declarations and evidence are complete; this is not product or human acceptance.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
