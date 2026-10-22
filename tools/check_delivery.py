#!/usr/bin/env python3
"""Check a declared delivery against project criteria; does not judge fun or art."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re

CLAIMS = {"maintenance", "candidate", "accepted"}
KINDS = {"technical", "content_review", "in_engine_visual", "production_record", "user_feedback"}


def validate(contract, receipt, evidence_root, revision, expected_claim):
    errors = []
    def require(ok, message):
        if not ok: errors.append(message)
    require(isinstance(contract, dict) and isinstance(receipt, dict), "contract/receipt must be objects")
    if errors: return errors
    require(contract.get("schema") == 1 and receipt.get("schema") == 1, "unsupported schema")
    require(isinstance(contract.get("goal"), str) and bool(contract.get("goal")), "missing project goal")
    require(receipt.get("goal") == contract.get("goal"), "delivery has drifted from the active goal")
    require(expected_claim in CLAIMS and receipt.get("claim") == expected_claim, "claim does not match the requested delivery gate")
    require(bool(re.fullmatch(r"(?:[0-9a-f]{40}|[0-9a-f]{64})", revision)), "expected revision must be an immutable full hash")
    require(receipt.get("revision") == revision, "evidence belongs to another revision")
    criteria = contract.get("criteria")
    require(isinstance(criteria, list) and bool(criteria), "project has no completion criteria")
    if not isinstance(criteria, list): return errors
    ids = []
    for row in criteria:
        require(isinstance(row, dict), "invalid criterion")
        if not isinstance(row, dict): continue
        ids.append(row.get("id"))
        require(isinstance(row.get("id"), str) and bool(row.get("id")), "criterion has no id")
        require(row.get("kind") in KINDS-{"user_feedback"}, "criterion has unsupported evidence kind")
        require(bool(row.get("requirement")), "criterion has no player/product requirement")
    require(all(isinstance(x, str) for x in ids) and len(set(str(x) for x in ids)) == len(ids), "duplicate/invalid criterion ids")
    evidence = receipt.get("evidence", [])
    require(isinstance(evidence, list), "evidence must be a list")
    if not isinstance(evidence, list): return errors
    seen = set()
    for item in evidence:
        require(isinstance(item, dict), "invalid evidence")
        if not isinstance(item, dict): continue
        key = item.get("criterion")
        require(key in ids or key in {"maintenance", "user_acceptance"}, "unknown evidence criterion")
        require(isinstance(key, str) and key not in seen, "duplicate evidence criterion")
        if isinstance(key, str): seen.add(key)
        require(item.get("status") == "passed", "missing/failed checks cannot be counted as completed")
        require(item.get("kind") in KINDS, "unknown evidence kind")
        require(item.get("revision") == revision, "stale evidence revision")
        path = item.get("path")
        digest = item.get("sha256")
        require(isinstance(path, str) and bool(path) and isinstance(digest, str), "missing artifact path/hash")
        if not isinstance(path, str) or not path: continue
        try:
            target = (evidence_root / path).resolve()
            require(target.is_relative_to(evidence_root.resolve()), "evidence escapes its declared root")
            if not target.is_relative_to(evidence_root.resolve()): continue
            require(target.is_file() and target.stat().st_size > 0, "missing/empty evidence artifact: " + path)
            if target.is_file(): require(hashlib.sha256(target.read_bytes()).hexdigest() == digest, "evidence hash mismatch: " + path)
        except OSError as exc:
            errors.append("cannot read evidence: " + str(exc))
    claim = receipt.get("claim")
    if claim == "maintenance":
        require(seen == {"maintenance"}, "maintenance cannot count as product milestone progress")
    elif claim in {"candidate", "accepted"}:
        for criterion in criteria:
            if not isinstance(criterion, dict): continue
            matches = [e for e in evidence if isinstance(e, dict) and e.get("criterion") == criterion.get("id")]
            require(len(matches) == 1, "missing milestone criterion: " + str(criterion.get("id")))
            if matches: require(matches[0].get("kind") == criterion.get("kind"), "test totals cannot substitute for " + str(criterion.get("id")))
        require("maintenance" not in seen, "repair evidence cannot replace milestone evidence")
        if claim == "accepted":
            acceptance = [e for e in evidence if isinstance(e, dict) and e.get("criterion") == "user_acceptance"]
            require(len(acceptance) == 1, "product acceptance requires actual user feedback")
            if acceptance:
                require(acceptance[0].get("kind") == "user_feedback" and acceptance[0].get("actor") == "user", "AI review is not user acceptance")
        else:
            require("user_acceptance" not in seen, "candidate must not imply user acceptance")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--evidence-root", type=Path, required=True)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--expect", choices=sorted(CLAIMS), required=True)
    args = parser.parse_args()
    try:
        errors = validate(json.loads(args.contract.read_text()), json.loads(args.receipt.read_text()), args.evidence_root, args.revision, args.expect)
    except (OSError, ValueError, TypeError) as exc:
        errors = [str(exc)]
    print(json.dumps({"gate": "passed" if not errors else "blocked", "claim": args.expect, "errors": errors, "limit": "Checks declared coverage and artifact integrity; cannot authenticate a review or establish enjoyment/art quality."}, ensure_ascii=False, indent=2))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
