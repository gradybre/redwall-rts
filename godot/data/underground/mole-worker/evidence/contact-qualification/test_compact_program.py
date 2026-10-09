"""Adversarial version2 source/proof binding; synthetic poses establish no production permission."""
import copy
from fractions import Fraction
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("compact_compiler", HERE / "compile_compact_program.py")
Q = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(Q)
SPEC = importlib.util.spec_from_file_location("program_fixture", HERE / "test_state_program.py")
T = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(T)


def program():
    clips = T.program() + [T.clip(3, True), T.clip(3, False), T.clip(3, False)]
    clips[9]["matrices"][1, 17, 9] = .25
    clips[10]["matrices"] = clips[9]["matrices"][::-1].copy()
    return clips


def interval(case):
    edges = [list(edge) for edge in Q.P.rendered_intervals(case)]
    loop, duration = Q.P.rendered_timing(case)
    return {"clear": True, "unresolved": [], "exact_yaw": 0, "rendered_edges": edges,
            "intervals": len(edges), "loop_mode": loop, "duration_q16": duration, "checks": 1}


class CompactProgram(unittest.TestCase):
    def test_all_three_entry_and_recovery_pairs_share_exactly_one_ready_source(self):
        clips = program()
        Q.D.check_program(clips)
        for entry in (3, 6, 9):
            bad = copy.deepcopy(clips)
            bad[entry]["matrices"][0, 17, 9] += 1
            with self.assertRaisesRegex(Q.P.envelope.Refused, "ENDPOINT"):
                Q.D.check_program(bad)
        for recovery in (4, 7, 10):
            bad = copy.deepcopy(clips)
            bad[recovery]["matrices"][1, 17, 9] += 1
            with self.assertRaisesRegex(Q.P.envelope.Refused, "RECOVERY"):
                Q.D.check_program(bad)

    def test_missing_front_clip_or_an_unproved_loop_rule_cannot_inherit_the_old_program(self):
        clips = program()
        with self.assertRaisesRegex(Q.P.envelope.Refused, "CLIP_CENSUS"):
            Q.D.check_program(clips[:8])
        for index in (8, 9, 10):
            bad = copy.deepcopy(clips)
            bad[index]["source_loop_mode"] = 1 - bad[index]["source_loop_mode"]
            with self.assertRaisesRegex(Q.P.envelope.Refused, "TIMING"):
                Q.D.check_program(bad)

    def test_actual_rendered_loop_closure_and_positive_exact_census_are_required(self):
        case = program()[8]
        row = interval(case)
        Q.interval_refusal(row, case)
        self.assertEqual(row["rendered_edges"][-1], [1, 0])
        changes = ({"rendered_edges": [[0, 1], [1, 2]]}, {"intervals": 1}, {"checks": 0},
                   {"duration_q16": row["duration_q16"] - 1}, {"unresolved": [1]},
                   {"exact_yaw": 1}, {"clear": 1}, {"checks": True})
        for change in changes:
            with self.assertRaisesRegex(Q.P.envelope.Refused, "INTERVAL_PROOF"):
                Q.interval_refusal(dict(row, **change), case)

    def test_short_final_timing_grounding_and_native_signed_zero_prevent_wrong_proof_reuse(self):
        first = program()[8]
        self.assertTrue(Q.same_source(first, copy.deepcopy(first)))
        changed = copy.deepcopy(first)
        changed["source_duration_s"] = Fraction(3, 60)
        self.assertFalse(Q.same_source(first, changed))
        changed = copy.deepcopy(first)
        changed["grounding"][0] = .01
        self.assertFalse(Q.same_source(first, changed))
        changed = copy.deepcopy(first)
        changed["matrices"][0, 0, 1] = -0.0
        self.assertFalse(Q.same_source(first, changed))

    def test_contact_patch_needs_the_actual_source_plane_and_both_positive_spans(self):
        tip = {"anchor_u": [6, 707, -768], "patch_u": [4, 705, -768, 7, 710, -768]}
        Q.contact_refusal(tip, 2, -768)
        for patch in ([4, 705, -769, 7, 710, -767], [4, 705, -768, 4, 710, -768],
                      [4, 705, -768, 7, 706, -768], [False, 705, -768, 7, 710, -768]):
            with self.assertRaisesRegex(Q.P.envelope.Refused, "CONTACT_PATCH"):
                Q.contact_refusal(dict(tip, patch_u=patch), 2, -768)

    def test_changed_metadata_cannot_borrow_an_unchanged_complete_source_image(self):
        source = HERE / "compact-program-source-v1"
        digest = json.loads((source / "compilation.json").read_text())["content_sha256"]
        candidate, _ = Q.read_program_metadata(source, digest)
        self.assertEqual(candidate["profile_roles"]["front"], 4)
        with tempfile.TemporaryDirectory() as name:
            directory = Path(name)
            for filename in ("mole-worker.ugactor", "candidate.json", "plan.json"):
                (directory / filename).write_bytes((source / filename).read_bytes())
            for filename in ("candidate.json", "plan.json"):
                original = (directory / filename).read_bytes()
                (directory / filename).write_bytes(original + b" ")
                with self.assertRaisesRegex(Q.P.envelope.Refused, "JSON_DIGEST"):
                    Q.read_program_metadata(directory, digest)
                (directory / filename).write_bytes(original)

    def test_missing_or_drifted_producer_pins_refuse_without_inferring_source_authority(self):
        with self.assertRaisesRegex(Q.P.envelope.Refused, "PIN_CENSUS"):
            Q.producer_refusal({"producer_sources": {}})
        with self.assertRaisesRegex(Q.P.envelope.Refused, "SOURCE_DRIFT"):
            Q.producer_refusal({"producer_sources": {str(Path(__file__).resolve()): "0" * 64}})


if __name__ == "__main__":
    unittest.main()
