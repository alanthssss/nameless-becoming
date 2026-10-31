"""Exercise CI routing with real Git history and fail-closed job results."""
import copy
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
FLAGS = ("web", "godot", "export_game", "swarm", "flower", "garden", "content")
OUTPUT_KEYS = set(FLAGS) | {"godot_suite", "reason"}
ZERO_SHA = "0" * 40


class GitScopeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="ci-routing-test-")
        self.addCleanup(self.temporary.cleanup)
        self.repo = Path(self.temporary.name)
        self.env = os.environ.copy()
        self.env.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
        for name in ("EVENT_NAME", "PR_BASE_SHA", "PR_HEAD_SHA", "PUSH_BEFORE_SHA", "CURRENT_SHA"):
            self.env.pop(name, None)
        self.git("init", "-q", "--initial-branch=main")
        self.git("config", "user.name", "CI routing fixture")
        self.git("config", "user.email", "ci-routing@example.invalid")
        self.git("config", "core.hooksPath", os.devnull)
        (self.repo / "scripts").mkdir()
        for name in ("classify_ci_changes.sh", "ci_scope.sh"):
            shutil.copyfile(ROOT / "scripts" / name, self.repo / "scripts" / name)
        self.base = self.commit("base")

    def git(self, *args):
        result = subprocess.run(
            ["git", "-c", "commit.gpgsign=false", *args],
            cwd=self.repo, env=self.env, text=True, capture_output=True, check=True,
        )
        return result.stdout.strip()

    def write(self, path, content="fixture\n"):
        target = self.repo / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)

    def commit(self, message):
        self.git("add", "--all")
        self.git("commit", "-qm", message)
        return self.git("rev-parse", "HEAD")

    def scope(self, event="pull_request", **values):
        env = dict(self.env, EVENT_NAME=event, **values)
        result = subprocess.run(
            ["bash", "scripts/ci_scope.sh"], cwd=self.repo, env=env,
            text=True, capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        output = {}
        for line in result.stdout.splitlines():
            self.assertIn("=", line, result.stdout)
            key, value = line.split("=", 1)
            self.assertNotIn(key, output, "Duplicate output: " + result.stdout)
            output[key] = value
        self.assertEqual(set(output), OUTPUT_KEYS)
        self.assertTrue(output["reason"])
        return output

    def pr(self, base, head):
        return self.scope(PR_BASE_SHA=base, PR_HEAD_SHA=head, CURRENT_SHA=head)

    def assert_flags(self, output, *selected):
        for flag in FLAGS:
            self.assertEqual(output[flag], "true" if flag in selected else "false", flag)

    def assert_full(self, output):
        self.assert_flags(output, *FLAGS)
        self.assertEqual(output["godot_suite"], "full")

    def test_documentation_is_light_but_readme_selects_content(self):
        self.write("docs/ci-routing-note.md")
        docs = self.commit("documentation only")
        self.assert_flags(self.pr(self.base, docs))
        self.write("README.md")
        readme = self.commit("readme content contract")
        self.assert_flags(self.pr(docs, readme), "content")

    def test_runtime_selects_its_prototype(self):
        self.write("prototypes/swarm-flight/game_model.gd")
        head = self.commit("swarm runtime")
        self.assert_flags(self.pr(self.base, head), "swarm")

    def test_deleted_runtime_is_still_selected(self):
        self.write("prototypes/flower-step/removed.gd")
        before = self.commit("add runtime")
        (self.repo / "prototypes/flower-step/removed.gd").unlink()
        head = self.commit("delete runtime")
        self.assert_flags(self.pr(before, head), "flower")

    def test_cross_project_rename_checks_both_sides(self):
        old = "prototypes/flower-step/moved.gd"
        new = "prototypes/garden-puzzles/moved.gd"
        self.write(old)
        before = self.commit("add source")
        (self.repo / new).parent.mkdir(parents=True)
        self.git("mv", old, new)
        head = self.commit("move between prototypes")
        self.assert_flags(self.pr(before, head), "flower", "garden")

    def test_large_changeset_keeps_runtime_after_documentation(self):
        for index in range(350):
            self.write(f"docs/entry-{index:04d}.md")
        self.write("prototypes/swarm-flight/runtime.gd")
        head = self.commit("many documents and one runtime")
        self.assert_flags(self.pr(self.base, head), "swarm")

    def test_spaces_and_newlines_do_not_invent_changed_paths(self):
        # A line-based path reader would invent a Swarm change on line two.
        self.write("docs/white space.md\nprototypes/swarm-flight/not-runtime.md")
        head = self.commit("one oddly named document")
        self.assert_flags(self.pr(self.base, head))
        self.write("prototypes/swarm-flight/white space\nactual-runtime.gd")
        runtime = self.commit("oddly named actual runtime")
        self.assert_flags(self.pr(head, runtime), "swarm")

    def test_push_checks_entire_multi_commit_range(self):
        self.write("prototypes/swarm-flight/runtime.gd")
        self.commit("first push commit")
        self.write("prototypes/garden-puzzles/runtime.gd")
        head = self.commit("second push commit")
        output = self.scope("push", PUSH_BEFORE_SHA=self.base, CURRENT_SHA=head)
        self.assert_flags(output, "swarm", "garden")

    def test_pull_request_uses_merge_base_not_base_tip(self):
        self.git("checkout", "-qb", "feature", self.base)
        self.write("prototypes/swarm-flight/runtime.gd")
        head = self.commit("feature change")
        self.git("checkout", "-q", "main")
        self.write("prototypes/flower-step/base-only.gd")
        advanced_base = self.commit("base changes after branching")
        self.assert_flags(self.pr(advanced_base, head), "swarm")

    def test_empty_diff_is_conservative(self):
        self.assert_full(self.pr(self.base, self.base))
        self.assert_full(self.scope("push", PUSH_BEFORE_SHA=self.base, CURRENT_SHA=self.base))

    def test_manual_and_unknown_events_are_conservative(self):
        for event in ("workflow_dispatch", "merge_group", "unexpected-event"):
            with self.subTest(event=event):
                self.assert_full(self.scope(event, CURRENT_SHA=self.base))

    def test_missing_zero_and_invalid_revisions_are_conservative(self):
        for base in ("", ZERO_SHA, "f" * 40, "not-a-ref"):
            with self.subTest(event="pull_request", base=base):
                self.assert_full(self.pr(base, self.base))
            with self.subTest(event="push", base=base):
                self.assert_full(self.scope("push", PUSH_BEFORE_SHA=base, CURRENT_SHA=self.base))
        self.assert_full(self.scope("pull_request", PR_BASE_SHA=self.base))
        self.assert_full(self.scope("push", PUSH_BEFORE_SHA=self.base))

    def test_whitespace_failure_cannot_emit_successful_selection(self):
        self.write("prototypes/swarm-flight/runtime.gd", "broken whitespace   \n")
        head = self.commit("whitespace defect")
        result = subprocess.run(
            ["bash", "scripts/ci_scope.sh"], cwd=self.repo,
            env=dict(self.env, EVENT_NAME="pull_request", PR_BASE_SHA=self.base, PR_HEAD_SHA=head),
            text=True, capture_output=True,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("web=", result.stdout)

    def test_unrelated_histories_are_conservative(self):
        self.git("checkout", "--orphan", "unrelated")
        self.git("rm", "-rf", "--", ".")
        self.write("docs/unrelated.md")
        unrelated = self.commit("unrelated root")
        # Restore the helper scripts without adding them to either history.
        (self.repo / "scripts").mkdir()
        for name in ("classify_ci_changes.sh", "ci_scope.sh"):
            shutil.copyfile(ROOT / "scripts" / name, self.repo / "scripts" / name)
        self.assert_full(self.pr(self.base, unrelated))


def job_results(*selected):
    outputs = {flag: "true" if flag in selected else "false" for flag in FLAGS}
    outputs["godot_suite"] = "full" if "godot" in selected else "routes"
    needs = {"scope": {"result": "success", "outputs": outputs}}
    for job, flag in (
        ("web", "web"), ("godot", "godot"), ("web-candidate", "export_game"),
        ("swarm", "swarm"), ("flower", "flower"), ("garden", "garden"),
        ("content", "content"),
    ):
        active = flag in selected and not (job == "content" and "web" in selected)
        needs[job] = {"result": "success" if active else "skipped"}
    return needs


class JobResultsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("ci_results_under_test", ROOT / "scripts/check_ci_results.py")
        cls.gate = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.gate)

    def test_selected_success_and_unselected_skipped_pass(self):
        for selected in ((), ("swarm",), ("content",), ("web", "content"), FLAGS):
            with self.subTest(selected=selected):
                self.assertEqual(self.gate.validate(job_results(*selected)), [])

    def test_selected_failure_cancellation_skip_or_absence_is_rejected(self):
        cases = (
            ("web", ("web",)), ("godot", ("godot",)),
            ("web-candidate", ("web", "godot", "export_game")),
            ("swarm", ("swarm",)), ("flower", ("flower",)),
            ("garden", ("garden",)), ("content", ("content",)),
        )
        for job, selected in cases:
            for result in ("failure", "cancelled", "skipped", "", None):
                with self.subTest(job=job, result=result):
                    needs = job_results(*selected)
                    if result is None:
                        del needs[job]
                    else:
                        needs[job]["result"] = result
                    self.assertTrue(self.gate.validate(needs))

    def test_unselected_jobs_must_be_present_and_skipped(self):
        for job in ("web", "godot", "web-candidate", "swarm", "flower", "garden", "content"):
            for result in ("success", "failure", "cancelled", None):
                with self.subTest(job=job, result=result):
                    needs = job_results()
                    if result is None:
                        del needs[job]
                    else:
                        needs[job]["result"] = result
                    self.assertTrue(self.gate.validate(needs))

    def test_scope_must_succeed_and_exist(self):
        for result in ("failure", "cancelled", "skipped", "", None):
            with self.subTest(result=result):
                needs = job_results()
                if result is None:
                    del needs["scope"]
                else:
                    needs["scope"]["result"] = result
                self.assertTrue(self.gate.validate(needs))

    def test_scope_requires_every_output_and_strict_booleans(self):
        for flag in (*FLAGS, "godot_suite"):
            with self.subTest(missing=flag):
                needs = job_results()
                del needs["scope"]["outputs"][flag]
                self.assertTrue(self.gate.validate(needs))
        for flag in FLAGS:
            for value in ("", "True", "FALSE", "1", "yes", True, None):
                with self.subTest(flag=flag, value=value):
                    needs = job_results()
                    needs["scope"]["outputs"][flag] = value
                    self.assertTrue(self.gate.validate(needs))
        needs = job_results()
        needs["scope"]["outputs"]["godot_suite"] = "unknown"
        self.assertTrue(self.gate.validate(needs))

    def test_malformed_dependency_payloads_are_rejected(self):
        for payload in (None, [], "success", {}):
            with self.subTest(payload=payload):
                self.assertTrue(self.gate.validate(payload))
        for payload in (None, [], "success"):
            with self.subTest(scope_outputs=payload):
                needs = job_results()
                needs["scope"]["outputs"] = payload
                self.assertTrue(self.gate.validate(needs))
            with self.subTest(job=payload):
                needs = job_results("swarm")
                needs["swarm"] = payload
                self.assertTrue(self.gate.validate(needs))

    def test_export_cannot_skip_either_prerequisite(self):
        for selected in (("export_game",), ("export_game", "web"), ("export_game", "godot")):
            with self.subTest(selected=selected):
                self.assertTrue(self.gate.validate(job_results(*selected)))

    def test_unknown_compatibility_selector_is_rejected(self):
        self.assertTrue(self.gate.validate(job_results(), only="swram"))

    def test_web_covers_content_without_a_duplicate_content_job(self):
        needs = job_results("web", "content")
        self.assertEqual(needs["content"]["result"], "skipped")
        self.assertEqual(self.gate.validate(needs), [])
        failed = copy.deepcopy(needs)
        failed["web"]["result"] = "failure"
        self.assertTrue(self.gate.validate(failed))

    def test_swarm_compatibility_gate_checks_only_swarm_and_scope(self):
        complete = job_results("swarm", "web")
        needs = {key: complete[key] for key in ("scope", "swarm")}
        self.assertEqual(self.gate.validate(needs, only="swarm"), [])
        needs["swarm"]["result"] = "failure"
        self.assertTrue(self.gate.validate(needs, only="swarm"))
        needs = job_results()
        self.assertEqual(self.gate.validate(needs, only="swarm"), [])
        needs["scope"]["result"] = "failure"
        self.assertTrue(self.gate.validate(needs, only="swarm"))


if __name__ == "__main__":
    unittest.main()
