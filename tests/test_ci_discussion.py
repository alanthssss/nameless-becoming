import base64
from hashlib import sha1
import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("ci_discussion", ROOT / "scripts/ci_discussion.py")
discussion = importlib.util.module_from_spec(spec)
spec.loader.exec_module(discussion)

BASE, HEAD, MERGE = "a" * 40, "b" * 40, "c" * 40


class DiscussionTests(unittest.TestCase):
    def setUp(self):
        self.data = {}
        self.compare = {"merge_base_commit": {"sha": BASE}, "files": []}
        self.data[f"compare/{BASE}...{HEAD}?per_page=1"] = self.compare
        self.note("design/notes.md", b"before\n", b"after\n")

    def snapshot(self, tree, files):
        nodes = []
        for path, content in files.items():
            if isinstance(content, dict):
                child = tree + "/" + path
                self.snapshot(child, content)
                nodes.append(dict(path=path, type="tree", mode="040000", sha=child))
            else:
                oid = sha1(content).hexdigest()
                self.data["git/blobs/" + oid] = dict(size=len(content), encoding="base64",
                                                    content=base64.b64encode(content).decode())
                nodes.append(dict(path=path, type="blob", mode="100644", sha=oid, size=len(content)))
        self.data["git/trees/" + tree] = {"tree": nodes, "truncated": False}

    def note(self, name, old, new, *, attributes=False):
        directory, filename = name.split("/")
        for tree, content in ((BASE, old), (HEAD, new), (MERGE, new)):
            docs = {directory: {} if content is None else {filename: content}}
            if attributes:
                docs[".gitattributes"] = b"*.md -whitespace\n"
            self.snapshot(tree, {"docs": docs, "scripts": {
                "classify_ci_changes.sh": (ROOT / "scripts/classify_ci_changes.sh").read_bytes()}})
        status = "added" if old is None else "removed" if new is None else "modified"
        self.compare["files"] = [dict(filename="docs/" + name, status=status)]

    def verify(self, push=False):
        return discussion.check(BASE, HEAD, MERGE, push=push, get=self.data.__getitem__)

    def test_complete_files_added_modified_or_deleted(self):
        for old, new in ((None, b"first\n"), (b"old  \n", b"old  \nnew\n"), (b"before\n", None)):
            with self.subTest(old=old, new=new):
                self.note("release/notes.md", old, new)
                self.assertTrue(self.verify())

    def test_whitespace_hidden_by_short_or_missing_api_patch_is_rejected(self):
        for contents in (b"after  \n", b"after\n\n", b"<<<<<<< HEAD\n"):
            self.note("design/notes.md", b"before\n", contents)
            self.compare["files"][0]["patch"] = ""
            with self.assertRaises(discussion.RejectedChange):
                self.verify()

    def test_runtime_inputs_mixed_renamed_preview_and_large_comparisons_use_checkout(self):
        for name in ("design/year-play-matrix.md", "design/commercial-product-requirements.md"):
            self.note(name, b"old\n", b"new\n")
            self.assertFalse(self.verify())
        item = {"filename": "docs/design/notes.md", "status": "modified"}
        for changes in ([], [item] * 300,
                        [item, dict(filename="game.gd", status="added")],
                        [dict(item, status="renamed", previous_filename="game.gd")],
                        [dict(item, filename="docs/art/nectar-oblique-preview/guide.md")]):
            self.compare["files"] = changes
            self.assertFalse(self.verify())

    def test_attributes_truncation_and_force_push_cannot_take_the_shortcut(self):
        self.assertTrue(self.verify(push=True))
        self.note("release/notes.md", b"a", b"b", attributes=True)
        with self.assertRaisesRegex(ValueError, "attributes"):
            self.verify()
        self.data["git/trees/" + MERGE]["truncated"] = True
        with self.assertRaisesRegex(ValueError, "incomplete"):
            self.verify()
        self.compare["merge_base_commit"]["sha"] = "d" * 40
        self.assertFalse(self.verify(push=True))


class TextEditTests(unittest.TestCase):
    def setUp(self):
        self.pr = dict(number=31, head=dict(sha=HEAD, ref="topic", repo={"full_name": "a/game"}),
                       base=dict(sha=BASE, ref="main"))
        self.event = dict(action="edited", changes={"body": {}}, pull_request=self.pr)
        self.prior = dict(status="completed", conclusion="success", head_sha=HEAD, head_branch="topic",
                          head_repository={"full_name": "a/game"}, id=10, run_attempt=2)
        self.gate = dict(name="CI required checks", status="completed", conclusion="success", run_id=10,
                         run_attempt=2, head_sha=HEAD, steps=[dict(
                             name=f"Gate outcome v1 PR 31 base main {BASE} merge {MERGE}", conclusion="success")])
        self.jobs = {"jobs": [self.gate], "total_count": 1}
        self.runs = [{"id": 11}, self.prior]
        self.data = {f"actions/workflows/quality.yml/runs?event=pull_request&head_sha={HEAD}&per_page=2":
                     {"workflow_runs": self.runs}, "actions/runs/10/attempts/2/jobs?per_page=100": self.jobs}

    def lookup(self):
        return discussion.prior_text_result(self.event, MERGE, 11, self.data.__getitem__)

    def test_exact_outcome_is_carried_forward_including_failure(self):
        self.assertEqual(self.lookup(), "success")
        self.prior["conclusion"] = self.gate["conclusion"] = "failure"
        self.assertEqual(self.lookup(), "failure")
        self.prior["conclusion"] = "cancelled"
        self.assertIsNone(self.lookup())

    def test_retarget_and_unknown_edits_reclassify(self):
        for changes in ({}, {"base": {}, "title": {}}, {"other": {}}):
            self.event["changes"] = changes
            self.assertIsNone(self.lookup())

    def test_incomplete_or_different_evidence_reclassifies(self):
        self.assertIsNone(discussion.prior_text_result(self.event, HEAD, 11, self.data.__getitem__))
        self.assertIsNone(discussion.prior_text_result(self.event, MERGE, 12, self.data.__getitem__))
        for data, key, value in ((self.prior, "status", "in_progress"), (self.prior, "head_branch", "other"),
                                 (self.gate, "run_attempt", 1), (self.gate, "head_sha", MERGE),
                                 (self.gate, "steps", []), (self.jobs, "total_count", 2)):
            with self.subTest(key=key):
                old = data[key]
                data[key] = value
                self.assertIsNone(self.lookup())
                data[key] = old
