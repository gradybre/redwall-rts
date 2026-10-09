"""Safety checks for automatic lane release and full-scope tracking."""

import copy
import unittest

from underground_build_queue import overlaps, ready_lanes, validate


def fixture():
    return {"lanes": [
        {"id": "A", "status": "running", "owns": ["godot/a.gd"],
         "depends_on": [], "requirements": ["UG-SHAPE-001"],
         "acceptance": ["check"], "evidence": {}, "lease": {"state": "held"}},
        {"id": "B", "status": "queued", "owns": ["godot/b.gd"],
         "depends_on": ["A"], "requirements": ["UG-SHAPE-002"],
         "acceptance": ["check"], "evidence": {}, "lease": {"state": "free"}},
    ]}


class QueueTests(unittest.TestCase):
    requirements = {"UG-SHAPE-001", "UG-SHAPE-002"}

    def test_all_requirements_must_have_an_owner(self):
        queue = fixture()
        queue["lanes"].pop()
        self.assertIn("requirement has no owner: UG-SHAPE-002",
                      validate(queue, self.requirements))

    def test_implemented_is_not_verified(self):
        queue = fixture()
        queue["lanes"][0]["status"] = "implemented"
        self.assertEqual([], ready_lanes(queue))

    def test_final_qualification_cannot_hide_missing_implementation(self):
        queue = fixture()
        queue["lanes"][1]["kind"] = "qualification"
        self.assertIn("requirement has no owner: UG-SHAPE-002",
                      validate(queue, self.requirements))

    def test_ready_batch_does_not_grant_duplicate_file_ownership(self):
        queue = fixture()
        queue["lanes"][0]["status"] = "queued"
        queue["lanes"][0]["lease"] = {"state": "free"}
        queue["lanes"][0]["owns"] = ["godot/"]
        queue["lanes"][1]["depends_on"] = []
        self.assertEqual(["A"], [lane["id"] for lane in ready_lanes(queue)])

    def test_verified_needs_evidence(self):
        queue = fixture()
        queue["lanes"][0]["status"] = "verified"
        queue["lanes"][0]["lease"] = {"state": "released", "stop_evidence": "worker completed"}
        self.assertEqual(5, len(validate(queue, self.requirements)))
        queue["lanes"][0]["evidence"] = dict.fromkeys(
            ("commit", "tests", "diagnostics", "review", "integration"), "evidence")
        self.assertEqual([], validate(queue, self.requirements))
        self.assertEqual(["B"], [lane["id"] for lane in ready_lanes(queue)])

    def test_directory_claim_blocks_child_file(self):
        self.assertTrue(overlaps("godot/demo/", "godot/demo/burrow/a.gd"))
        self.assertTrue(overlaps("godot/demo/burrow/a.gd", "godot/demo/"))
        self.assertFalse(overlaps("godot/demo/", "godot/demolition.gd"))

    def test_queued_work_waits_for_active_file_owner(self):
        queue = fixture()
        queue["lanes"][0]["owns"] = ["godot/"]
        queue["lanes"][1]["depends_on"] = []
        self.assertEqual([], ready_lanes(queue))
        queue["lanes"][0]["status"] = "implemented"
        queue["lanes"][0]["lease"] = {"state": "released", "stop_evidence": "worker completed"}
        self.assertEqual(["B"], [lane["id"] for lane in ready_lanes(queue)])

    def test_blocked_worker_keeps_lease_until_stopped(self):
        queue = fixture()
        queue["lanes"][0]["status"] = "blocked"
        queue["lanes"][0]["owns"] = ["godot/"]
        queue["lanes"][1]["depends_on"] = []
        self.assertEqual([], ready_lanes(queue))
        queue["lanes"][0]["lease"] = {"state": "released"}
        self.assertTrue(any("worker-stop evidence" in error
                            for error in validate(queue, self.requirements)))
        queue["lanes"][0]["lease"]["stop_evidence"] = "worker completed"
        self.assertEqual([], validate(queue, self.requirements))
        self.assertEqual(["B"], [lane["id"] for lane in ready_lanes(queue)])

    def test_blocked_cannot_bypass_stop_evidence_with_free_lease(self):
        queue = fixture()
        queue["lanes"][0]["status"] = "blocked"
        queue["lanes"][0]["lease"] = {"state": "free"}
        self.assertTrue(any("never-started" in error
                            for error in validate(queue, self.requirements)))
        queue["lanes"][0]["status"] = "queued"
        queue["lanes"][0]["agent"] = "/root/previous_worker"
        self.assertTrue(any("never-started" in error
                            for error in validate(queue, self.requirements)))

    def test_verified_dependency_cannot_hide_unfinished_ancestor(self):
        queue = fixture()
        queue["lanes"][1]["status"] = "verified"
        queue["lanes"][1]["lease"] = {"state": "released", "stop_evidence": "worker completed"}
        queue["lanes"][1]["evidence"] = dict.fromkeys(
            ("commit", "tests", "diagnostics", "review", "integration"), "evidence")
        self.assertTrue(any("before dependency A verified" in error
                            for error in validate(queue, self.requirements)))

    def test_ownership_aliases_are_rejected(self):
        queue = fixture()
        for alias in ("./godot/a.gd", "godot//a.gd", "godot/./a.gd", "godot\\a.gd"):
            queue["lanes"][1]["owns"] = [alias]
            self.assertTrue(any("ownership must be" in error
                                for error in validate(queue, self.requirements)), alias)

    def test_active_file_conflict_is_rejected(self):
        queue = fixture()
        queue["lanes"][0]["owns"] = ["godot/"]
        queue["lanes"][1]["status"] = "running"
        queue["lanes"][1]["lease"] = {"state": "held"}
        self.assertTrue(any("active ownership conflict" in error
                            for error in validate(queue, self.requirements)))

    def test_cycles_and_missing_dependencies_are_rejected(self):
        queue = fixture()
        queue["lanes"][0]["depends_on"] = ["B"]
        self.assertTrue(any("dependency cycle" in error
                            for error in validate(queue, self.requirements)))
        queue["lanes"][0]["depends_on"] = ["missing"]
        self.assertTrue(any("unknown dependency" in error
                            for error in validate(queue, self.requirements)))

    def test_inspection_does_not_mutate_queue(self):
        queue = fixture()
        before = copy.deepcopy(queue)
        validate(queue, self.requirements)
        ready_lanes(queue)
        self.assertEqual(before, queue)

    def test_ownership_cannot_escape_repo(self):
        queue = fixture()
        queue["lanes"][0]["owns"] = ["../main/godot/", "/etc/", "godot/*"]
        self.assertEqual(3, len(validate(queue, self.requirements)))


if __name__ == "__main__":
    unittest.main()
