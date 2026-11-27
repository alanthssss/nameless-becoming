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
            with self.assertRaises(discussion.WhitespaceError):
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
