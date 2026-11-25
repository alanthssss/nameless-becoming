"""Exercise prototype check reuse against real Git merges and rebases."""
import copy
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("ci_reuse", ROOT / "scripts/ci_reuse.py")
ci_reuse = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ci_reuse)
REPO = "owner/game"
REGION = "prototypes/swarm-flight/region_game/menu.gd"
FLOWER = "prototypes/flower-step/route.gd"
SWARM_SUITES = ("core", "regressions", "samples", "samples-save", "migrations", "region-greybox")
FLOWER_JOB = "Flower Step / Flower Step rules and complete routes"
GARDEN_JOB = "Garden Puzzles / Garden Puzzles rules and complete routes"


def swarm_job(suite):
    return f"Swarm Flight / Swarm Flight checks ({suite})"


class PrototypeReuseTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.addCleanup(os.chdir, Path.cwd())
        os.chdir(temp.name)
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.name", "CI fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("config", "commit.gpgSign", "false")
        self.git("config", "core.hooksPath", os.devnull)
        Path("scripts").mkdir()
        shutil.copy2(ROOT / "scripts/classify_ci_changes.sh", "scripts")
        self.write(REGION, "initial menu")
        self.base = self.commit("base")
        self.git("checkout", "-qb", "topic")
        self.write(REGION, "new menu")
        self.write(FLOWER, "new route")
        self.before = self.commit("regional and flower changes")
        self.tree = self.git("rev-parse", "HEAD^{tree}")
        self.run = dict(id=101, run_number=30, run_attempt=2, status="completed",
                        conclusion="success", head_branch="topic", head_sha=self.before,
                        path=".github/workflows/quality.yml", event="pull_request",
                        repository={"full_name": REPO}, head_repository={"full_name": REPO})
        self.runs = [self.run]
        self.job = dict(name="CI required checks", id=301, run_id=101, run_attempt=2,
                        head_sha=self.before, status="completed", conclusion="success",
                        steps=[dict(number=2, name=self.marker(), status="completed", conclusion="success")])
        self.jobs = [self.job]
        self.selected = dict(swarm="true", swarm_suite="region", flower="true", garden="false")

    @staticmethod
    def git(*args, check=True):
        return subprocess.run(["git", *args], text=True, check=check,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout.strip()

    @staticmethod
    def write(path, text):
        target = Path(path)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text + "\n")

    def commit(self, message):
        self.git("add", "--all")
        self.git("commit", "-qm", message)
        return self.git("rev-parse", "HEAD")

    def marker(self, *, base=None, tree=None, number=12, swarm="region", flower="true", garden="false"):
        return (f"Prototype evidence v1 PR {number} base {base or self.base} tree {tree or self.tree} "
                f"swarm {swarm} flower {flower} garden {garden}")

    def full_swarm_and_garden_change(self, previous_scope="full"):
        self.write("prototypes/swarm-flight/main.gd", "a shared swarm change")
        self.write("prototypes/garden-puzzles/route.gd", "a garden change")
        self.before = self.commit("also change shared Swarm and Garden inputs")
        self.tree = self.git("rev-parse", "HEAD^{tree}")
        self.run["head_sha"] = self.job["head_sha"] = self.before
        self.job["steps"][0]["name"] = self.marker(swarm=previous_scope, garden="true")
        self.selected.update(swarm_suite="full", garden="true")

    def record_jobs(self, *names):
        for name in names:
            self.jobs.append(dict(name=name, run_id=self.run["id"], run_attempt=self.run["run_attempt"],
                                  head_sha=self.before, status="completed", conclusion="success"))

    def sync(self, path="docs/production/receipt.md", *, method="merge", additional_files=(), contents=None):
        self.git("checkout", "-q", "main")
        for changed in (path, *additional_files):
            self.write(changed, (contents or {}).get(changed, "upstream edit"))
        latest = self.commit("advance main")
        self.git("checkout", "-q", "topic")
        if method == "rebase":
            self.git("rebase", "-q", latest)
        elif method == "resolved":
            self.git("merge", "--no-ff", "--no-edit", latest, check=False)
            self.write(path, "manual resolution")
            self.commit("resolve competing edits")
        else:
            self.git("merge", "--no-ff", "--no-edit", latest)
        return self.checkout_integration(latest)

    def checkout_integration(self, base):
        head = self.git("rev-parse", "topic")
        self.git("checkout", "-q", "--detach", base)
        self.git("merge", "--no-ff", "--no-edit", head)
        identity = {"full_name": REPO}
        return dict(action="synchronize", before=self.before, after=head, number=12,
                    repository=identity,
                    pull_request=dict(number=12, base=dict(ref="main", sha=base, repo=identity),
                                      head=dict(ref="topic", sha=head, repo=identity)))

    def api(self, path):
        if "/workflows/quality.yml/runs?" in path:
            self.assertIn(self.before, path)
            return {"total_count": len(self.runs), "workflow_runs": self.runs}
        if "/runs/101/attempts/2/jobs" in path:
            return {"total_count": len(self.jobs), "jobs": self.jobs}
        self.fail(f"Unexpected API request: {path}")

    def decide(self, event, api=None):
        return ci_reuse.decide(event, REPO, self.selected, api or self.api)

    def test_clean_merge_or_equivalent_rebase_reuses_only_selected_domains(self):
        event = self.sync()
        self.assertEqual(self.decide(event), ({"swarm", "flower"}, 101))
        self.git("branch", "-f", "topic", self.before)
        self.git("checkout", "-q", "topic")
        latest = event["pull_request"]["base"]["sha"]
        self.git("rebase", "-q", latest)
        self.assertEqual(self.decide(self.checkout_integration(latest)), ({"swarm", "flower"}, 101))

    def test_main_change_in_same_domain_different_file_still_runs_affected_domain(self):
        event = self.sync("prototypes/swarm-flight/region_game/inventory.gd")
        self.assertEqual(self.decide(event), ({"flower"}, 101))

    def test_regional_and_flower_updates_keep_nonregional_swarm_suites_and_garden(self):
        self.full_swarm_and_garden_change()
        event = self.sync("prototypes/swarm-flight/region_game/inventory.gd",
                          additional_files=("prototypes/flower-step/other.gd",))
        self.assertEqual(self.decide(event), ({"swarm-except-region", "garden"}, 101))

    def test_previous_region_only_does_not_certify_nonregional_swarm_suites(self):
        self.full_swarm_and_garden_change(previous_scope="region")
        event = self.sync("prototypes/swarm-flight/region_game/inventory.gd")
        self.assertEqual(self.decide(event), ({"flower", "garden"}, 101))

    def test_shared_swarm_change_requires_all_swarm_suites_again(self):
        self.full_swarm_and_garden_change()
        event = self.sync("prototypes/swarm-flight/world_view.gd")
        self.assertEqual(self.decide(event), ({"flower", "garden"}, 101))

    def test_flower_only_workflow_change_preserves_other_prototype_results(self):
        self.full_swarm_and_garden_change()
        event = self.sync(".github/workflows/flower-step.yml")
        self.assertEqual(self.decide(event), ({"swarm", "garden"}, 101))

    def test_reuses_previously_integrated_upstream_changes_absent_from_old_topic(self):
        self.git("checkout", "-q", "main")
        self.write("prototypes/flower-step/upstream.gd", "already present in previous CI checkout")
        old_base = self.commit("previous PR target had advanced")
        self.git("checkout", "-q", "--detach", old_base)
        self.git("merge", "--no-ff", "--no-edit", self.before)
        integrated = self.git("rev-parse", "HEAD^{tree}")
        self.assertNotEqual(integrated, self.tree)
        self.job["steps"][0]["name"] = self.marker(base=old_base, tree=integrated)
        self.assertEqual(self.decide(self.sync()), ({"swarm", "flower"}, 101))

    def test_unknown_upstream_input_disables_every_domain(self):
        self.assertEqual(self.decide(self.sync("unknown-input.dat")), (set(), None))

    def test_shared_ci_change_blocks_all_reuse(self):
        event = self.sync(".github/workflows/quality.yml")
        self.assertEqual(self.decide(event), (set(), None))

    def test_438_sync_of_routing_and_readme_reuses_six_executed_swarm_jobs(self):
        self.full_swarm_and_garden_change()
        self.selected.update(flower="false", garden="false")
        self.record_jobs(*(swarm_job(s) for s in SWARM_SUITES))
        classifier = "scripts/classify_ci_changes.sh"
        event = self.sync(classifier, contents={classifier: Path(classifier).read_text() + "\n# New routing"},
                          additional_files=("scripts/check_ci_evidence.py", "scripts/ci_scope.sh",
                                            "tests/ci-scope.test.sh", "tests/test_ci_routing.py",
                                            "README.md", "docs/CI_PERFORMANCE_2026-11-01.md"))
        self.assertEqual(self.decide(event), ({"swarm"}, 101))
        for job in tuple(self.jobs[1:]):
            with self.subTest(missing=job["name"]):
                self.jobs.remove(job)
                self.assertNotIn("swarm", self.decide(event)[0])
                self.jobs.append(job)

    def test_routing_sync_requires_unique_successful_jobs_from_the_certified_attempt(self):
        self.record_jobs(FLOWER_JOB)
        flower_only = list(self.jobs)
        self.record_jobs(swarm_job("region-greybox"))
        regional = self.jobs[-1]
        event = self.sync("scripts/ci_scope.sh")
        self.assertEqual(self.decide(event), ({"swarm", "flower"}, 101))

        def truncated_jobs(path):
            response = self.api(path)
            if "jobs" in response:
                response["total_count"] += 1
            return response

        self.assertEqual(self.decide(event, truncated_jobs), (set(), None))
        for overrides in ({"status": "in_progress"}, {"conclusion": "failure"}, {"conclusion": "skipped"},
                          {"run_id": 202}, {"run_attempt": 1}, {"head_sha": self.base},
                          {"name": "Swarm Flight rules and complete routes"}):
            with self.subTest(overrides=overrides):
                self.jobs = [*flower_only, dict(regional, **overrides)]
                self.assertEqual(self.decide(event), ({"flower"}, 101))
        self.jobs = [*flower_only, regional, regional.copy()]
        self.assertEqual(self.decide(event), ({"flower"}, 101))
        self.jobs = [self.job]  # A gate inherited through an earlier reuse is insufficient here.
        self.assertEqual(self.decide(event), (set(), None))

    def test_routing_and_regional_change_can_reuse_only_the_five_executed_unaffected_suites(self):
        self.full_swarm_and_garden_change()
        nonregional = [swarm_job(s) for s in SWARM_SUITES if s != "region-greybox"]
        self.record_jobs(*nonregional, FLOWER_JOB, GARDEN_JOB)
        event = self.sync("tests/test_ci_routing.py",
                          additional_files=("prototypes/swarm-flight/region_game/inventory.gd",))
        self.assertEqual(self.decide(event), ({"swarm-except-region", "flower", "garden"}, 101))
        self.jobs = [job for job in self.jobs if job["name"] not in (swarm_job("samples-save"), FLOWER_JOB)]
        self.assertEqual(self.decide(event), ({"garden"}, 101))

    def test_routing_and_shared_game_input_still_rerun_swarm(self):
        self.full_swarm_and_garden_change()
        self.record_jobs(*(swarm_job(s) for s in SWARM_SUITES), FLOWER_JOB, GARDEN_JOB)
        event = self.sync("scripts/ci_scope.sh", additional_files=("prototypes/swarm-flight/world_view.gd",))
        self.assertEqual(self.decide(event), ({"flower", "garden"}, 101))

    def test_changes_to_the_required_gate_still_block_reuse_alongside_routing_changes(self):
        self.record_jobs(swarm_job("region-greybox"), FLOWER_JOB)
        event = self.sync("scripts/check_ci_results.py", additional_files=("scripts/ci_scope.sh",))
        self.assertEqual(self.decide(event), (set(), None))

    def test_routing_changes_carried_by_the_pr_still_block_reuse(self):
        self.write("scripts/ci_scope.sh", "the topic changes the selector")
        self.before = self.commit("edit routing on the topic")
        self.tree = self.git("rev-parse", "HEAD^{tree}")
        self.run["head_sha"] = self.job["head_sha"] = self.before
        self.job["steps"][0]["name"] = self.marker()
        self.record_jobs(swarm_job("region-greybox"), FLOWER_JOB)
        self.assertEqual(self.decide(self.sync("tests/test_ci_routing.py")), (set(), None))

    def test_old_region_success_cannot_cover_full_swarm_or_an_unrun_domain(self):
        event = self.sync()
        self.selected.update(swarm_suite="full", garden="true")
        self.assertEqual(self.decide(event), ({"flower"}, 101))

    def test_extra_pr_edit_is_not_a_pure_sync_even_if_only_documentation(self):
        event = self.sync()
        self.git("checkout", "-q", "topic")
        self.write("docs/addition.md", "an edit made on the topic")
        self.commit("change scope after syncing")
        self.assertEqual(self.decide(self.checkout_integration(event["pull_request"]["base"]["sha"])),
                         (set(), None))

    def test_conflicting_sync_with_hand_resolution_is_not_reused(self):
        self.assertEqual(self.decide(self.sync(REGION, method="resolved")), (set(), None))

    def test_invalid_evidence_never_suppresses_checks(self):
        event = self.sync()
        for marker in (self.marker(number=33), self.marker(tree=self.git("rev-parse", "HEAD^{tree}")),
                       self.marker(base="0" * 40), "Prototype evidence missing or truncated"):
            with self.subTest(marker=marker):
                self.job["steps"][0]["name"] = marker
                self.assertEqual(self.decide(event), (set(), None))
        self.job["steps"] = []
        self.assertEqual(self.decide(event), (set(), None))

    def test_prior_run_and_job_must_be_the_right_source_and_successful_attempt(self):
        event = self.sync()
        for field, value in (("event", "workflow_dispatch"), ("path", ".github/workflows/other.yml"),
                             ("head_branch", "unrelated"), ("head_sha", self.base),
                             ("repository", {"full_name": "other/game"}),
                             ("head_repository", {"full_name": "fork/game"}),
                             ("conclusion", "failure"), ("status", "in_progress")):
            with self.subTest(field=field):
                self.runs = [dict(self.run, **{field: value})]
                self.assertEqual(self.decide(event), (set(), None))
        for conclusion in ("failure", "cancelled"):
            with self.subTest(latest=conclusion):
                newer = dict(self.run, id=103, run_number=31, conclusion=conclusion)
                self.runs = [newer, self.run]
                self.assertEqual(self.decide(event), (set(), None))
        self.runs = [self.run]
        for field, value in (("name", "unrelated"), ("conclusion", "cancelled"), ("run_attempt", 1)):
            with self.subTest(job=field):
                self.jobs = [dict(self.job, **{field: value})]
                self.assertEqual(self.decide(event), (set(), None))
        self.job["steps"][0]["conclusion"] = "skipped"
        self.jobs = [self.job]
        self.assertEqual(self.decide(event), (set(), None))

    def test_non_sync_fork_or_missing_history_runs_full_selected_checks(self):
        event = self.sync()
        for invalid in (dict(event, action="edited"), dict(event, before="0" * 40)):
            self.assertEqual(self.decide(invalid), (set(), None))
        fork = copy.deepcopy(event)
        fork["pull_request"]["head"]["repo"] = {"full_name": "fork/game"}
        self.assertEqual(self.decide(fork), (set(), None))
        self.runs = []
        self.assertEqual(self.decide(event), (set(), None))

    def test_mismatched_current_integrated_tree_is_not_reused(self):
        event = self.sync()
        self.write("docs/inconsistent-checkout.md", "not the expected integrated tree")
        self.commit("different checkout")
        self.assertEqual(self.decide(event), (set(), None))


if __name__ == "__main__":
    unittest.main()
