import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "skills/godot-production-workflow/scripts/check_delivery.py"
if not SCRIPT.exists(): SCRIPT = ROOT / "tools/check_delivery.py"
spec = importlib.util.spec_from_file_location("delivery_gate", SCRIPT)
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)
REV = "a" * 40


class DeliveryGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.contract = {"schema":1,"goal":"whole-game","criteria":[{"id":x,"kind":x,"requirement":"Example criterion, not player evidence"} for x in ["technical","content_review","in_engine_visual","production_record"]]}
        self.receipt = {"schema":1,"goal":"whole-game","claim":"candidate","revision":REV,"evidence":[]}
        for row in self.contract["criteria"]: self.add(row["id"],row["kind"])

    def add(self, criterion, kind, **extra):
        path = self.root / (criterion + ".txt")
        path.write_text("Synthetic test fixture: " + criterion)
        self.receipt["evidence"].append({"criterion":criterion,"kind":kind,"status":"passed","revision":REV,"path":path.name,"sha256":hashlib.sha256(path.read_bytes()).hexdigest(),**extra})

    def errors(self, expected="candidate"):
        return gate.validate(self.contract,self.receipt,self.root,REV,expected)

    def test_complete_candidate_is_not_acceptance(self):
        self.assertEqual(self.errors(),[])
        self.receipt["claim"]="accepted"
        self.assertTrue(self.errors("accepted"))

    def test_repair_cannot_complete_milestone(self):
        self.receipt["claim"]="maintenance"
        self.receipt["evidence"]=[]
        self.add("maintenance","technical")
        self.assertEqual(self.errors("maintenance"),[])
        self.assertTrue(self.errors("candidate"))
        self.receipt["claim"]="candidate"
        self.assertTrue(self.errors())

    def test_many_tests_cannot_replace_visual_or_content(self):
        for item in self.receipt["evidence"]: item["kind"]="technical"
        self.assertTrue(self.errors())

    def test_missing_failed_or_duplicate_evidence_blocks(self):
        for change in ["missing","failed","duplicate"]:
            with self.subTest(change=change):
                original=copy.deepcopy(self.receipt)
                if change=="missing": self.receipt["evidence"].pop()
                if change=="failed": self.receipt["evidence"][0]["status"]="not_run"
                if change=="duplicate": self.receipt["evidence"].append(copy.deepcopy(self.receipt["evidence"][0]))
                self.assertTrue(self.errors())
                self.receipt=original

    def test_wrong_goal_or_revision_blocks(self):
        for field in ["goal","revision"]:
            original=self.receipt[field]
            self.receipt[field]="wrong"
            self.assertTrue(self.errors())
            self.receipt[field]=original
        self.receipt["evidence"][0]["revision"]="b"*40
        self.assertTrue(self.errors())

    def test_tampered_or_missing_file_blocks(self):
        path=self.root/self.receipt["evidence"][0]["path"]
        path.write_text("changed after review")
        self.assertTrue(self.errors())
        path.unlink()
        self.assertTrue(self.errors())

    def test_empty_contract_cannot_pass(self):
        self.contract["criteria"]=[]
        self.assertTrue(self.errors())

    def test_user_acceptance_not_agent_review(self):
        self.receipt["claim"]="accepted"
        self.add("user_acceptance","user_feedback",actor="agent")
        self.assertTrue(self.errors("accepted"))
        self.receipt["evidence"][-1]["actor"]="user"
        self.assertEqual(self.errors("accepted"),[])  # Synthetic metadata, not authentication.

    def test_revision_must_be_exact_full_hash(self):
        for size in [39,40,41,63,64,65]:
            with self.subTest(size=size):
                revision="a"*size
                self.receipt["revision"]=revision
                for item in self.receipt["evidence"]: item["revision"]=revision
                errors=gate.validate(self.contract,self.receipt,self.root,revision,"candidate")
                self.assertEqual(bool(errors),size not in [40,64])

    def test_empty_and_outside_artifacts_block(self):
        item=self.receipt["evidence"][0]
        path=self.root/item["path"]
        path.write_bytes(b"")
        item["sha256"]=hashlib.sha256(b"").hexdigest()
        self.assertTrue(self.errors())
        outside=self.root.parent/(self.root.name+"-outside.txt")
        outside.write_text("Synthetic outside evidence")
        self.addCleanup(lambda: outside.unlink(missing_ok=True))
        path.unlink();path.symlink_to(outside)
        item["sha256"]=hashlib.sha256(outside.read_bytes()).hexdigest()
        self.assertTrue(self.errors())

    def test_cli_fails_closed_on_bad_json(self):
        bad=self.root/"bad.json";bad.write_text("not json")
        result=subprocess.run([sys.executable,str(SCRIPT),"--contract",str(bad),"--receipt",str(bad),"--evidence-root",str(self.root),"--revision",REV,"--expect","candidate"],capture_output=True,text=True)
        self.assertEqual(result.returncode,1)
        self.assertEqual(json.loads(result.stdout)["gate"],"blocked")


if __name__=="__main__": unittest.main()
