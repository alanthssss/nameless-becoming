"""Exercise CI routing with real Git history and fail-closed job results."""
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
FLAGS = ("web", "godot", "export_game", "swarm", "flower", "garden", "content")
OUTPUT_KEYS = set(FLAGS) | {"godot_suite", "swarm_suite", "reason"}
ZERO_SHA = "0" * 40


class BuildInputTests(unittest.TestCase):
    def test_tailwind_scans_only_the_site_directory(self):
        # Web and the candidate can reuse previous builds after edits outside
        # app/. Tailwind's default source discovery would scan the entire repo.
        css = (ROOT / "app/globals.css").read_text()
        css = re.sub(r"/\*.*?\*/", "", css, flags=re.DOTALL)
        sources = re.findall(r"""@import\s+["']tailwindcss["']\s*([^;]*);""", css)
        self.assertEqual(sources, ['source(".")'])
        self.assertNotRegex(css, r"@source\b", "Audit CI build inputs before adding Tailwind scan roots")


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
        for name in ("classify_ci_changes.sh", "ci_scope.sh", "check_ci_evidence.py"):
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

    def assert_scope_error(self, message, event="pull_request", **values):
        result = subprocess.run(["bash", "scripts/ci_scope.sh"], cwd=self.repo,
                                env=dict(self.env, EVENT_NAME=event, **values),
                                text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(message, result.stderr)
        self.assertNotIn("web=", result.stdout)

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

    def test_evidence_is_validated_at_head_only_for_changed_surviving_records(self):
        receipt = "docs/production/evidence/receipt.json"
        events = "docs/production/evidence/with spaces/events.jsonl"
        self.write(receipt, '{"version":1}\n')
        self.write(events, '{}\n{"event":"finish"}\n')
        good = self.commit("valid evidence")
        self.write(receipt, "not JSON\n")
        bad = self.commit("broken receipt")
        self.assert_flags(self.pr(self.base, good))  # checkout now contains the broken receipt
        self.write(receipt, '{}\n')
        self.write(events, '{}\nbroken\n')
        bad_line = self.commit("broken event")
        self.write(events, '{"cost":NaN}\n')
        bad_number = self.commit("nonstandard JSON constant")
        for head, message in ((bad, receipt), (bad_line, "line 2"), (bad_number, "not a JSON number")):
            self.assert_scope_error(message, PR_BASE_SHA=self.base, PR_HEAD_SHA=head)
        self.assert_scope_error("not a JSON number", "workflow_dispatch")
        (self.repo / events).unlink()
        deleted = self.commit("remove archived events")
        self.assert_flags(self.pr(bad_line, deleted))

    def test_document_records_outside_evidence_are_checked_when_moved_or_on_full_runs(self):
        old = "docs/design/old.txt"
        new = "docs/design/research.jsonl"
        self.write(old, '{}\nnot JSON\n')
        start = self.commit("draft text")
        self.git("mv", old, new)
        bad = self.commit("publish malformed records")
        self.assert_scope_error("line 2", PR_BASE_SHA=start, PR_HEAD_SHA=bad)
        self.assert_scope_error("line 2", "push", PUSH_BEFORE_SHA=ZERO_SHA, CURRENT_SHA=bad)
        self.git("mv", new, old)
        moved = self.commit("move out of JSON records")
        self.pr(bad, moved)

    def test_preview_manifest_and_images_are_checked_together_in_compared_tree(self):
        folder = "docs/art/nectar-oblique-preview/"
        photo, manifest = folder + "pond.png", folder + "manifest.json"
        digest = hashlib.sha256(b"captured bytes\n").hexdigest()
        self.write(photo, "captured bytes\n")
        self.write(manifest, json.dumps({"screenshots": [{"file": "pond.png", "sha256": digest}]}))
        good = self.commit("preview and its manifest")
        self.write(photo, "changed bytes\n")
        altered = self.commit("alter just the screenshot")
        self.pr(self.base, good)  # Working checkout contains the later altered bytes.
        self.assert_scope_error("SHA-256", PR_BASE_SHA=good, PR_HEAD_SHA=altered)
        self.assert_scope_error("SHA-256", "workflow_dispatch")
        self.write("docs/another-note.md", "unrelated")
        unrelated = self.commit("an unrelated change")
        self.pr(altered, unrelated)
        (self.repo / photo).unlink()
        deleted = self.commit("delete one declared image")
        self.assert_scope_error("missing screenshot", PR_BASE_SHA=unrelated, PR_HEAD_SHA=deleted)
        (self.repo / manifest).unlink()
        self.pr(good, self.commit("remove entire archive"))

    def test_preview_manifest_cannot_name_external_files_or_omit_images(self):
        folder = "docs/art/nectar-oblique-preview/"
        manifest = folder + "manifest.json"
        self.write(folder + "pond.png", "image")
        self.write("docs/art/outside.png", "image")
        for filename in ("../outside.png", "/tmp/outside.png"):
            self.write(manifest, json.dumps({"screenshots": [{"file": filename, "sha256": "x"}]}))
            head = self.commit("invalid filename")
            self.assert_scope_error("invalid or missing screenshot", PR_BASE_SHA=self.base, PR_HEAD_SHA=head)
        self.write(manifest, '{"screenshots":[]}')
        self.assert_scope_error("omits screenshots", PR_BASE_SHA=self.base,
                                PR_HEAD_SHA=self.commit("unlisted screenshot"))
        (self.repo / manifest).unlink()
        self.assert_scope_error("manifest.json is missing", PR_BASE_SHA=self.base,
                                PR_HEAD_SHA=self.commit("only the screenshot remains"))

    def test_registered_regional_art_sources_select_swarm(self):
        sources = set()

        def collect_source(record):
            if "source_in_repository" in record:
                sources.add(record["source_in_repository"])
            return record

        provenance = ROOT / "prototypes/swarm-flight/region_game/art-provenance.json"
        json.loads(provenance.read_bytes(), object_hook=collect_source)
        self.assertTrue(sources, "No registered regional source images found")
        for source in sorted(sources):
            with self.subTest(source=source):
                flags = subprocess.check_output(["bash", ROOT / "scripts/classify_ci_changes.sh"],
                                                input=os.fsencode(source) + b"\0")
                self.assertIn(b"swarm=true", flags.splitlines())

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

    def test_move_regional_script_to_archived_log_still_checks_runtime(self):
        old = "prototypes/swarm-flight/region_game/controls.gd"
        new = "docs/production/evidence/controls/retired.log"
        self.write(old)
        before = self.commit("regional script")
        (self.repo / new).parent.mkdir(parents=True)
        self.git("mv", old, new)
        head = self.commit("archive regional script")
        for output in (self.pr(before, head), self.scope("push", PUSH_BEFORE_SHA=before, CURRENT_SHA=head)):
            self.assert_flags(output, "swarm")
            self.assertEqual(output["swarm_suite"], "region")

    def test_moving_review_image_into_and_out_of_game_checks_the_runtime_path(self):
        review = "docs/art/pond-study.jpg"
        runtime = "prototypes/swarm-flight/art/basin-fish.webp"
        self.write(review, "image bytes")
        initial = self.commit("add review image")
        (self.repo / runtime).parent.mkdir(parents=True)
        self.git("mv", review, runtime)
        in_game = self.commit("move image into the game")
        self.git("mv", runtime, review)
        archived = self.commit("move image out of the game")
        self.assert_flags(self.pr(self.base, initial))
        for old, new in ((initial, in_game), (in_game, archived)):
            for result in (self.pr(old, new), self.scope("push", PUSH_BEFORE_SHA=old, CURRENT_SHA=new)):
                self.assert_flags(result, "swarm")
                self.assertEqual(result["swarm_suite"], "region")

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
        for name in ("classify_ci_changes.sh", "ci_scope.sh", "check_ci_evidence.py"):
            shutil.copyfile(ROOT / "scripts" / name, self.repo / "scripts" / name)
        self.assert_full(self.pr(self.base, unrelated))


def job_results(*selected):
    outputs = {flag: "true" if flag in selected else "false" for flag in FLAGS}
    outputs["godot_suite"] = "full" if "godot" in selected else "routes"
    outputs["swarm_suite"] = "full" if "swarm" in selected else "none"
    outputs.update(reused="[]", source_run="none")
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
        for flag in (*FLAGS, "godot_suite", "swarm_suite"):
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

    def test_regional_selection_requires_a_successful_swarm_job(self):
        needs = job_results("swarm")
        needs["scope"]["outputs"]["swarm_suite"] = "region"
        self.assertEqual(self.gate.validate(needs), [])
        needs["swarm"]["result"] = "skipped"
        self.assertTrue(self.gate.validate(needs))
        for selected, suite in (((), "region"), (("swarm",), "none"), (("swarm",), "typo")):
            needs = job_results(*selected)
            needs["scope"]["outputs"]["swarm_suite"] = suite
            self.assertTrue(self.gate.validate(needs))

    def test_only_certified_selected_jobs_can_skip(self):
        needs = job_results("swarm", "web")
        outputs = needs["scope"]["outputs"]
        outputs.update(reused='["swarm"]', source_run="123")
        needs["swarm"]["result"] = "skipped"
        self.assertEqual(self.gate.validate(needs), [])
        self.assertEqual(self.gate.validate(needs, only="swarm"), [])
        for result in ("failure", "cancelled", "success", None):
            needs["swarm"]["result"] = result
            self.assertTrue(self.gate.validate(needs))
        needs["swarm"]["result"] = "skipped"
        for listed, source in (("[]", ""), ('["flower"]', "123"), ('["content"]', "123"),
                               ('["swarm"]', ""), ('["swarm"]', "0"), ('["swarm"]', "-1"),
                               ('["swarm", "swarm"]', "123"), ("{}", ""), ("", "")):
            outputs.update(reused=listed, source_run=source)
            self.assertTrue(self.gate.validate(needs))
        for key in ("reused", "source_run"):
            fresh = job_results()
            del fresh["scope"]["outputs"][key]
            self.assertTrue(self.gate.validate(fresh))

    def test_web_godot_and_candidate_can_be_run_or_reused_independently(self):
        jobs = ("web", "godot", "web-candidate")
        for reused in (jobs, ("web", "godot"), ("godot", "web-candidate"), ("web", "web-candidate"),
                       ("web",), ("godot",), ("web-candidate",)):
            with self.subTest(reused=reused):
                needs = job_results("web", "godot", "export_game", "content")
                needs["scope"]["outputs"].update(reused=json.dumps(reused), source_run="123")
                for job in reused:
                    needs[job]["result"] = "skipped"
                self.assertEqual(needs["content"]["result"], "skipped")  # Covered by Web in either case.
                self.assertEqual(self.gate.validate(needs), [])
                for job in jobs:
                    for wrong in ("failure", "cancelled", None, "success" if job in reused else "skipped"):
                        invalid = copy.deepcopy(needs)
                        if wrong is None:
                            del invalid[job]
                        else:
                            invalid[job]["result"] = wrong
                        self.assertTrue(self.gate.validate(invalid), (job, wrong))

    def test_web_godot_and_candidate_must_be_selected_to_reuse(self):
        for job, selected in (("web", ("godot",)), ("godot", ("web",)),
                              ("web-candidate", ("web", "godot"))):
            with self.subTest(job=job):
                needs = job_results(*selected)
                needs["scope"]["outputs"].update(reused=json.dumps([job]), source_run="123")
                self.assertTrue(self.gate.validate(needs))

    def test_partial_swarm_reuse_requires_running_the_regional_job(self):
        needs = job_results("swarm")
        outputs = needs["scope"]["outputs"]
        outputs.update(reused='["swarm-except-region"]', source_run="123")
        self.assertEqual(self.gate.validate(needs), [])
        for result in ("skipped", "failure", "cancelled"):
            needs["swarm"]["result"] = result
            self.assertTrue(self.gate.validate(needs))
            self.assertTrue(self.gate.validate(needs, only="swarm"))
        needs["swarm"]["result"] = "success"
        outputs["swarm_suite"] = "region"
        self.assertTrue(self.gate.validate(needs))
        outputs.update(swarm_suite="full", reused='["swarm", "swarm-except-region"]')
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
