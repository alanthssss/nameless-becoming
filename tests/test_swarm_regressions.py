"""Test that regression evidence cannot be forged by crashes or partial runs."""
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import check_swarm_regressions as gate


def output(errors=(), checks=184):
    return "\n".join([*(f"ERROR: {error}" for error in errors),
                      f"SEASON ELEMENT CHECKS: {checks}, failures {len(errors)}"])


class RegressionGateTests(unittest.TestCase):
    def test_baseline_and_expected_behavior_failures(self):
        self.assertEqual(gate.inspect_result(0, output()), gate.Report(184, ()))
        movement = tuple(f"Authored airflow 13/{region} continuously affects {mode} (0.0 px)"
                         for region in range(1, 7) for mode in ("release", "charge"))
        gate.validate_canary("wind_requires_steering", gate.inspect_result(1, output(movement), 184))
        gate.validate_canary("preview_claims_contact", gate.inspect_result(1, output((gate.CUE_FAILURE,) * 6), 184))

    def test_crash_timeout_and_parse_error_are_not_caught_regressions(self):
        for code, log in ((1, "Parse Error: bad script"), (1, output() + "\nSCRIPT ERROR: fail"),
                          (-11, output((gate.CUE_FAILURE,) * 6)), (1, "ERROR: unexpected crash")):
            with self.subTest(code=code, log=log), self.assertRaises(gate.GateError):
                gate.inspect_result(code, log, 184)
        with patch.object(gate.subprocess, "run", side_effect=subprocess.TimeoutExpired("godot", 1)):
            with self.assertRaisesRegex(gate.GateError, "timed out"):
                gate.run_verify("godot", Path("/temporary"), 1)

    def test_partial_or_inconsistent_run_is_rejected(self):
        for code, log in ((0, output(checks=183)), (0, output(checks=1)),
                          (1, output()), (0, output() + "\nERROR: unrelated"),
                          (0, output() + "\n" + output())):
            with self.subTest(code=code, log=log), self.assertRaises(gate.GateError):
                gate.inspect_result(code, log, 184)

    def test_surviving_or_wrong_failure_mutant_is_rejected(self):
        for name in ("wind_requires_steering", "preview_claims_contact"):
            for failures in ((), ("unrelated assertion",), (gate.CUE_FAILURE,) * 5):
                with self.subTest(name=name, failures=failures), self.assertRaises(gate.GateError):
                    gate.validate_canary(name, gate.Report(184, failures))

    def test_duplicate_region_does_not_replace_coverage(self):
        failures = tuple(f"Authored airflow 13/1 continuously affects {mode} (0.0 px)"
                         for _ in range(6) for mode in ("release", "charge"))
        with self.assertRaises(gate.GateError):
            gate.validate_canary("wind_requires_steering", gate.Report(184, failures))

    def test_changed_or_ambiguous_anchor_requires_review(self):
        for source in ("missing", "anchor anchor"):
            with self.assertRaises(gate.GateError):
                gate.replace_once(source, "anchor", "mutant")

    def test_isolation_and_mutations_leave_real_project_untouched(self):
        source = Path(__file__).resolve().parents[1] / "prototypes" / "swarm-flight"
        original = {name: (source / name).read_bytes() for name in gate.SCRIPTS}
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            gate.prepare_project(source, target)
            self.assertNotIn("user://", (target / "save_data.gd").read_text())
            self.assertNotIn("OS.get_cache_dir()", (target / "verify.gd").read_text())
            self.assertIn(str(target), (target / "save_data.gd").read_text())
            for name in ("wind_requires_steering", "preview_claims_contact"):
                self.assertNotEqual(gate.mutate((target / "game_model.gd").read_text(), name),
                                    original["game_model.gd"].decode())
        self.assertEqual(original, {name: (source / name).read_bytes() for name in gate.SCRIPTS})

    def test_minimal_project_includes_inherited_and_preloaded_scripts(self):
        source = Path(__file__).resolve().parents[1] / "prototypes" / "swarm-flight"
        for name in gate.SCRIPTS:
            references = re.findall(r'res://([^"\s]+\.gd)', (source / name).read_text())
            for reference in references:
                with self.subTest(script=name, dependency=reference):
                    self.assertIn(reference, gate.SCRIPTS)


if __name__ == "__main__":
    unittest.main()
