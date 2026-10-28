"""Synthetic contract tests. Passing fixtures are NOT actual game review evidence."""

import base64
import copy
import hashlib
from pathlib import Path
import tempfile
import unittest

from tools.spring_review_gate import validate_review

REVISION = "a" * 40
# One-pixel test image only: not a screenshot of the game or a review artifact.
SYNTHETIC_PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jX1kAAAAASUVORK5CYII="
)


class ReviewGateTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="synthetic-spring-gate-", dir="/tmp")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / "raw").mkdir()
        for chapter in ("03", "04", "05"):
            (self.root / "raw" / f"{chapter}.png").write_bytes(SYNTHETIC_PNG)
        self.record = {
            "revision": REVISION,
            "status": "ready",
            "author": "synthetic author",
            "reviewer": "synthetic independent reviewer",
            "human_acceptance_claim": False,
            "blockers": [],
            "chapters": [self.chapter(chapter) for chapter in ("03", "04", "05")],
        }

    def chapter(self, number):
        result = {
            "chapter": number,
            "method": "exploratory_continuous",
            "known_solution_used": False,
            "before": {
                "goal": "Synthetic goal predicted before acting",
                "options": [
                    {"approach": "under", "action": "Stay under cover",
                     "expected_consequence": "Remain sheltered",
                     "visual_basis": "Visible roof and a later opening"},
                    {"approach": "over", "action": "Use shield above cover",
                     "expected_consequence": "Cross exposed space while shield lasts",
                     "visual_basis": "Visible shield, rain and destination"},
                ],
            },
            "after": [{"approach": "under", "consequence": "Stayed sheltered until the next opening"}],
            "verdict": "pass",
            "conclusion": "Synthetic complete declaration, not a game judgment",
            "evidence": [{"path": f"raw/{number}.png", "raw": True,
                          "sha256": hashlib.sha256(SYNTHETIC_PNG).hexdigest()}],
        }
        if number == "04":
            result["after"].append({"approach": "over", "consequence": "Used shield duration to reach the higher opening"})
            result["choice_comparison"] = {
                "dimensions": ["exposure", "resource_use"],
                "description": "One approach uses cover; the other spends protection during exposure",
                "route_or_state_only": False,
            }
        return result

    def errors(self, record=None, root=None):
        return validate_review(self.record if record is None else record, REVISION,
                               self.root if root is None else root)

    def rejects(self, expected):
        errors = self.errors()
        self.assertTrue(errors, "negative fixture unexpectedly passed")
        self.assertTrue(any(expected in error for error in errors), errors)

    def test_synthetic_complete_record_only_checks_contract(self):
        self.assertEqual([], self.errors())

    def test_known_answer_route_is_rejected(self):
        self.record["chapters"][0]["method"] = "known_answer_route"
        self.rejects("method")

    def test_known_solution_flag_cannot_be_hidden_by_correct_method(self):
        for value in (True, "false", 0, None):
            with self.subTest(value=value):
                self.record["chapters"][0]["known_solution_used"] = value
                self.rejects("known_solution_used")

    def test_author_cannot_self_sign_even_case_and_space_differ(self):
        self.record["reviewer"] = "  SYNTHETIC AUTHOR  "
        self.rejects("cannot sign")

    def test_empty_identities_are_rejected(self):
        for key in ("author", "reviewer"):
            with self.subTest(key=key):
                record = copy.deepcopy(self.record)
                record[key] = "  "
                self.assertTrue(any(key in error for error in self.errors(record)))

    def test_each_missing_chapter_is_rejected(self):
        for missing in ("03", "04", "05"):
            with self.subTest(chapter=missing):
                record = copy.deepcopy(self.record)
                record["chapters"] = [c for c in record["chapters"] if c["chapter"] != missing]
                self.assertTrue(any("exactly one" in error for error in self.errors(record)))

    def test_duplicate_chapter_cannot_replace_missing_chapter(self):
        self.record["chapters"][2] = copy.deepcopy(self.record["chapters"][0])
        self.rejects("exactly one")

    def test_stale_review_revision_is_rejected(self):
        self.record["revision"] = "b" * 40
        self.rejects("frozen revision")

    def test_caller_must_supply_full_frozen_revision(self):
        self.assertTrue(validate_review(self.record, "a" * 7, self.root))

    def test_old_hash_is_rejected_after_evidence_changes(self):
        (self.root / "raw/03.png").write_bytes(SYNTHETIC_PNG + b"changed")
        self.rejects("does not match")

    def test_malformed_hash_is_rejected(self):
        self.record["chapters"][0]["evidence"][0]["sha256"] = "oldhash"
        self.rejects("64 lowercase")

    def test_parent_and_absolute_paths_are_rejected(self):
        for path in ("../outside.png", str(self.root / "raw/03.png"), "raw/../../outside.png", "..\\outside.png"):
            with self.subTest(path=path):
                self.record["chapters"][0]["evidence"][0]["path"] = path
                self.rejects("path")

    def test_symlink_escape_is_rejected_even_with_correct_hash(self):
        # The other temporary root is unrelated to permitted evidence_root.
        with tempfile.TemporaryDirectory(prefix="synthetic-outside-", dir="/tmp") as directory:
            outside = Path(directory) / "outside.png"
            outside.write_bytes(SYNTHETIC_PNG)
            (self.root / "raw/escape.png").symlink_to(outside)
            self.record["chapters"][0]["evidence"][0]["path"] = "raw/escape.png"
            self.rejects("inside evidence_root")

    def test_empty_missing_and_nonmedia_files_are_rejected(self):
        for case in ("empty", "missing", "nonmedia"):
            with self.subTest(case=case):
                record = copy.deepcopy(self.record)
                evidence = record["chapters"][0]["evidence"][0]
                if case == "empty":
                    (self.root / "raw/empty.png").write_bytes(b"")
                    evidence.update(path="raw/empty.png", sha256=hashlib.sha256(b"").hexdigest())
                elif case == "missing":
                    evidence["path"] = "raw/missing.png"
                else:
                    (self.root / "raw/note.txt").write_text("Not media")
                    evidence["path"] = "raw/note.txt"
                self.assertTrue(self.errors(record))

    def test_nonraw_evidence_is_rejected(self):
        self.record["chapters"][0]["evidence"][0]["raw"] = False
        self.rejects(".raw")

    def test_unresolved_blockers_are_rejected(self):
        self.record["blockers"] = ["04 still requires route instructions"]
        self.rejects("blockers")

    def test_human_acceptance_claim_is_rejected(self):
        self.record["human_acceptance_claim"] = True
        self.rejects("human_acceptance_claim")

    def test_missing_explicit_declared_fields_are_rejected(self):
        for key in ("status", "human_acceptance_claim", "blockers"):
            with self.subTest(key=key):
                record = copy.deepcopy(self.record)
                del record[key]
                self.assertTrue(any(key in error for error in self.errors(record)))

    def test_chapter04_needs_two_observed_approaches(self):
        self.record["chapters"][1]["after"] = self.record["chapters"][1]["after"][:1]
        self.rejects("two distinct")

    def test_chapter04_cannot_duplicate_outcome_or_approach(self):
        for field in ("approach", "consequence"):
            with self.subTest(field=field):
                record = copy.deepcopy(self.record)
                after = record["chapters"][1]["after"]
                after[1][field] = after[0][field]
                self.assertTrue(any("two distinct" in error for error in self.errors(record)))

    def test_chapter04_route_or_state_change_alone_is_rejected(self):
        self.record["chapters"][1]["choice_comparison"]["route_or_state_only"] = True
        self.rejects("route/state change alone")

    def test_chapter04_turn_count_is_not_qualifying_dimension(self):
        self.record["chapters"][1]["choice_comparison"]["dimensions"] = ["turn_count"]
        self.rejects("dimensions")

    def test_missing_prediction_visual_basis_conclusion_or_evidence_is_rejected(self):
        for field in ("goal", "visual_basis", "conclusion", "evidence"):
            with self.subTest(field=field):
                record = copy.deepcopy(self.record)
                chapter = record["chapters"][0]
                if field == "goal":
                    chapter["before"]["goal"] = ""
                elif field == "visual_basis":
                    chapter["before"]["options"][0]["visual_basis"] = ""
                else:
                    del chapter[field]
                self.assertTrue(any(field in error for error in self.errors(record)))

    def test_rework_verdict_is_rejected_despite_ready_status(self):
        self.record["chapters"][0]["verdict"] = "needs_rework"
        self.rejects("verdict")

    def test_malformed_record_returns_errors_not_exception(self):
        for value in (None, [], "ready", 1):
            with self.subTest(value=value):
                self.assertTrue(validate_review(value, REVISION, self.root))
        malformed = copy.deepcopy(self.record)
        malformed["chapters"] = [{"chapter": []}, None, "04"]
        self.assertTrue(self.errors(malformed))


if __name__ == "__main__":
    unittest.main()
