"""Adversarial finite INSTALL composition; synthetic inputs grant no runtime motion permission."""
import copy
from fractions import Fraction
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("install_program", HERE / "author_install_program.py")
Q = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(Q)
T = Q.module("compact_install_fixture", "test_compact_program.py")


def source():
    compact = T.program()
    install = [T.T.clip(3, False), T.T.clip(3, False), T.T.clip(3, False)]
    install[0]["matrices"][1, 17, 9] = .1
    install[1]["matrices"][1, 17, 9] = .25
    install[2]["matrices"] = install[1]["matrices"][::-1].copy()
    return compact, install


def record():
    return json.loads((HERE / "install-source-proof-v4/proof.json").read_text())


def proof_cases(value):
    cases = []
    for index in range(3):
        timing = value["self"][str(index)]
        count = timing["intervals"] + 1
        case = T.T.clip(count, False)
        case["source_duration_s"] = Fraction(timing["duration_q16"], 30 * 65536)
        case["duration_q16"] = timing["duration_q16"]
        cases.append(case)
    return cases


class InstallProgram(unittest.TestCase):
    def test_exact_loop_edge_reuses_the_accepted_finite_tap_without_changing_old_clips(self):
        compact, install = source()
        cases, edges = Q.assemble(compact, install, list(Q.NAMES))
        self.assertEqual(edges[-1], {"proved": [1, 2], "rendered": [1, 0]})
        self.assertTrue(all(Q.Q.same_source(a, b) for a, b in zip(compact, cases[:11])))
        self.assertEqual(install[0]["source_loop_mode"], 0)
        self.assertEqual(len(cases), 14)

    def test_nonidentical_loop_endpoint_grounding_and_signed_zero_are_refused(self):
        for field, value in (("matrices", .1), ("matrices", -0.0), ("grounding", .1)):
            compact, install = source()
            if field == "matrices":
                install[0][field][-1, 0, 1] = value
            else:
                install[0][field][-1] = value
            with self.assertRaisesRegex(Q.P.envelope.Refused, "EDGE_SOURCE"):
                Q.assemble(compact, install, list(Q.NAMES))

    def test_changed_short_interval_duration_cannot_borrow_another_edge_certificate(self):
        _, install = source()
        altered = copy.deepcopy(install[0])
        altered["source_duration_s"] = Fraction(3, 60)
        altered["duration_q16"] = 98304
        with self.assertRaisesRegex(Q.P.envelope.Refused, "EDGE_TIMING"):
            Q.equivalent_rendered_edges(install[0], altered)

    def test_missing_install_clip_and_nonmatching_shared_hub_or_recovery_refuse(self):
        compact, install = source()
        with self.assertRaisesRegex(Q.P.envelope.Refused, "CLIP_CENSUS"):
            Q.assemble(compact, install[:2], list(Q.NAMES))
        for clip, frame, error in ((1, 0, "ENDPOINT"), (2, 1, "RECOVERY")):
            changed = copy.deepcopy(install)
            changed[clip]["matrices"][frame, 17, 9] += .25
            with self.assertRaisesRegex(Q.P.envelope.Refused, error):
                Q.assemble(compact, changed, list(Q.NAMES))

    def test_full_primitive_and_stance_census_is_required_even_with_a_true_flag(self):
        proof = record()
        cases = proof_cases(proof)
        topology = [[np.zeros((10209, 3), dtype=np.int64)], [np.zeros((1150, 3), dtype=np.int64)]]
        Q.source_proof_refusal(proof, cases, topology, proof["native_domain_roots_u"])
        for mutate in (lambda r: r["self"]["0"].update(tool_triangles=1149),
                       lambda r: r["world"]["1"][0]["supports"].pop(),
                       lambda r: r["world"]["0"][0].update(target_is_worker_support=True),
                       lambda r: r["world"]["0"][0]["supports"][0].update(source_above=False),
                       lambda r: r["self"]["0"].update(exact_yaw=1),
                       lambda r: r["local"]["0"].pop()):
            altered = copy.deepcopy(proof)
            mutate(altered)
            with self.assertRaises(Q.P.envelope.Refused):
                Q.source_proof_refusal(altered, cases, topology, proof["native_domain_roots_u"])

    def test_all_consumer_roles_are_required_and_contact_remains_the_actual_planar_patch(self):
        roles = {name: [[-2, 0, -2, 2, 4, 2]] for name in Q.ROLE_NAMES}
        floor = [-1, -1, -1, 1, 0, 1]
        roles["BODY_HELD_LOAD"].append(floor)
        roles["CONTACT_POINT"] = [[0, 128, 0, 0, 128, 0]]
        roles["CONTACT_PATCH"] = [[-1, 128, -1, 1, 128, 1]]
        Q.role_refusal(roles, floor)
        for name in Q.ROLE_NAMES:
            missing = copy.deepcopy(roles)
            del missing[name]
            with self.assertRaisesRegex(Q.P.envelope.Refused, "ROLE_CENSUS"):
                Q.role_refusal(missing, floor)
        missing = copy.deepcopy(roles)
        missing["BODY_HELD_LOAD"].pop()
        with self.assertRaisesRegex(Q.P.envelope.Refused, "COMMON_FLOOR_MISSING"):
            Q.role_refusal(missing, floor)
        roles["CONTACT_PATCH"][0][4] = 129
        with self.assertRaisesRegex(Q.P.envelope.Refused, "CONTACT_PATCH"):
            Q.role_refusal(roles, floor)

    def test_absent_or_changed_producer_refuses_without_reusing_a_matching_filename(self):
        with self.assertRaisesRegex(Q.P.envelope.Refused, "PIN_CENSUS"):
            Q.checked_pins({})
        name = str(Path(__file__).relative_to(Q.P.ROOT))
        with self.assertRaisesRegex(Q.P.envelope.Refused, "SOURCE_DRIFT"):
            Q.checked_pins({name: "0" * 64})

    def test_embedded_metadata_is_not_replaced_after_an_unchanged_image_is_selected(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp)
            for name in ("mole-worker.ugactor", "candidate.json", "plan.json"):
                (target / name).write_bytes((Q.INSTALL / name).read_bytes())
            Q.image_metadata(target, Q.INSTALL_SHA, None, "candidate.json")
            (target / "candidate.json").write_bytes((target / "candidate.json").read_bytes() + b" ")
            with self.assertRaisesRegex(Q.P.envelope.Refused, "JSON_DIGEST"):
                Q.image_metadata(target, Q.INSTALL_SHA, None, "candidate.json")


if __name__ == "__main__":
    unittest.main()
