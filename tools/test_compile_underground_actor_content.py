#!/usr/bin/env python3
"""Adversarial compact-content tests; source fixtures are explicitly synthetic."""
import copy
import hashlib
import io
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import numpy as np

import compile_underground_actor_content as c
import export_underground_envelopes as e
from test_export_underground_envelopes import palette_fixture


def fixture():
    raw = palette_fixture(attachment=True, attachment_key="mole_pick", grounding=[0., .25],
                          held_binding="set_work_tool", clip="idle")
    case = next(e.PaletteSource(io.BytesIO(raw), hashlib.sha256(raw).hexdigest()).cases())
    case.update(source_loop_mode=1)
    work = copy.deepcopy(case)
    work.update(id="work", clip="heavy_hammer_swing", held_tool_binding="demo_clip_specific")
    walk = copy.deepcopy(case)
    walk.update(id="walk", clip="walk")
    cases = {"synthetic": case, "work": work, "walk": walk}
    plan = {"schema": 1, "revision": 1, "cast": "fixture", "species": "mouse", "life_stage": "synthetic",
            "active_tool": "mole_pick", "clips": list(cases), "world_root_bounds_u": [0, -32, 0, 128, 64, 128],
            "groups": [{"id": "work", "mode": "work", "states": {"idle": ["synthetic"], "work": ["work"],
                       "entry": ["synthetic", "work"], "recovery": ["synthetic", "work"]}}]}
    rows = []
    for name, actual in cases.items():
        rows.append({"id": name, "frames": 2, "world_model_representation_enclosed": True,
            "parts": [{"kind": p["kind"], "name": p["name"],
                       "world_all_headings_bounds_u": [-2, -1 if p["binds"] else -100, -3, 8, 9, 10]}
                      for p in actual["geometry"]]})
    proof = {"profiles": rows, "world_root_bounds_u": plan["world_root_bounds_u"],
             "world_basis": {"sha256": "a" * 64}}
    return cases, plan, proof


class CompactContent(unittest.TestCase):
    def test_plan_requires_every_source_state_without_neighbor_fallback(self):
        _, plan, _ = fixture()
        self.assertEqual(c.validate_plan(plan), ["synthetic", "work", "walk"])
        for change in (lambda p: p["groups"][0]["states"].pop("recovery"),
                       lambda p: p["groups"][0]["states"].update(work=["missing"]),
                       lambda p: p["groups"][0].update(mode="climb"),
                       lambda p: p["clips"].append("work"),
                       lambda p: p["groups"][0].update(id=[]),
                       lambda p: p["groups"][0]["states"].update(work=[{}]),
                       lambda p: p.update(world_root_bounds_u=[0, 0, 0, 1 << 25, 10, 10])):
            candidate = copy.deepcopy(plan)
            change(candidate)
            with self.assertRaises(e.Refused):
                c.validate_plan(candidate)

    def test_source_labels_cannot_rename_idle_as_productive_work(self):
        cases, plan, proof = fixture()
        plan["groups"][0]["states"]["work"] = ["synthetic"]
        with self.assertRaisesRegex(e.Refused, "STATE_LABEL"):
            c.state_unions(plan, proof, cases)

    def test_tool_stroke_and_recovery_keep_genuine_below_floor_geometry(self):
        cases, plan, proof = fixture()
        result = c.state_unions(plan, proof, cases)[0]
        self.assertEqual(result["body_non_target_u"][1], -1)
        self.assertEqual(result["active_tool_stroke_u"][1], -100)
        self.assertEqual(result["recovery_all_parts_u"][1], -100)
        self.assertFalse(result["production_qualified"])
        self.assertNotIn("stance", result)
        plan["groups"][0] = {"id": "walk", "mode": "walk", "states": {
            "idle": ["synthetic"], "walk": ["walk"], "entry": ["walk"], "reversal": ["walk"], "recovery": ["synthetic"]}}
        self.assertEqual(c.state_unions(plan, proof, cases)[0]["body_non_target_u"][1], -100)

    def test_missing_reordered_or_incomplete_proof_parts_refuse(self):
        cases, plan, proof = fixture()
        for change in (lambda p: p["profiles"][0]["parts"].pop(),
                       lambda p: p["profiles"][0]["parts"].reverse(),
                       lambda p: p["profiles"][0].update(frames=1),
                       lambda p: p["profiles"][0].update(world_model_representation_enclosed=False),
                       lambda p: p["profiles"].append(p["profiles"][0])):
            candidate = copy.deepcopy(proof)
            change(candidate)
            with self.assertRaises(e.Refused):
                c.state_unions(plan, candidate, cases)

    def test_mesh_fingerprint_includes_every_influence_and_original_format(self):
        cases, _, _ = fixture()
        part = cases["synthetic"]["geometry"][0]
        original = c.geometry_fingerprint(part)
        self.assertEqual(len(original), 32)
        for field, index in (("weights", (0, 3)), ("ids", (0, 3)), ("points", (0, 2))):
            changed = copy.deepcopy(part)
            changed["geometry"][0][field][index] += 1
            self.assertNotEqual(c.geometry_fingerprint(changed), original)
        changed = copy.deepcopy(part)
        changed["surface_formats"][0] ^= 1 << 27
        self.assertNotEqual(c.geometry_fingerprint(changed), original)
        changed = copy.deepcopy(part)
        changed["mesh_aabb"][0] += .25
        self.assertNotEqual(c.geometry_fingerprint(changed), original)
        changed = copy.deepcopy(part)
        changed["surface_formats"] = []
        with self.assertRaisesRegex(e.Refused, "SURFACE_CENSUS"):
            c.geometry_fingerprint(changed)

    def test_wire_has_one_complete_frame_stream_and_exact_source_digests(self):
        cases, plan, proof = fixture()
        image, budget = c.encode(list(cases.values()), plan, proof, "1" * 64, "2" * 64, "3" * 64)
        self.assertEqual(image[:8], b"UGACNT01")
        self.assertEqual(struct.unpack_from("<6I", image, 8), (1, 1, 2, 3, 6, 24))
        self.assertEqual(image[56:88], bytes.fromhex("a" * 64))
        self.assertEqual(image[88:120], bytes.fromhex("1" * 64))
        self.assertEqual(image[-8:], b"UGAEND01")
        self.assertEqual(len(image), 184 + 72 * 2 + 48 * 3 + 4 * 6 * 25 + 8)
        matrices = np.frombuffer(image, dtype="<f4", count=6 * 24, offset=184 + 144 + 144)
        self.assertEqual(matrices.tolist(), np.concatenate([x["matrices"].ravel() for x in cases.values()]).tolist())
        self.assertEqual(budget["retained_palette_bytes"], 600)
        self.assertEqual(budget["admitted_peak_bytes"], 600 + 600 + 80 * 2 + 48 * 3 + 152 + c.CONTROL_RESERVE)
        self.assertFalse(budget["native_peak_measured"])

    def test_clip_timing_has_exact_complete_source_span(self):
        cases, plan, proof = fixture()
        one = [cases["synthetic"]]
        one[0]["source_duration_s"] = 1 / 60
        image, _ = c.encode(one, plan, proof, "1" * 64, "2" * 64, "3" * 64)
        self.assertEqual(struct.unpack_from("<4I", image, 184 + 144), (0, 2, 1, 32768))
        for duration in (0, 1, -1):
            one[0]["source_duration_s"] = duration
            with self.assertRaisesRegex(e.Refused, "CLIP_DURATION"):
                c.encode(one, plan, proof, "1" * 64, "2" * 64, "3" * 64)

    def test_extract_consumes_complete_hash_and_exact_identity_after_labeled_synthetic_backend(self):
        raw = palette_fixture(attachment=True, attachment_key="mole_pick", grounding=[0., .25],
                              held_binding="set_work_tool", clip="idle")
        digest = hashlib.sha256(raw).hexdigest()
        cases, plan, proof = fixture()
        plan["clips"] = ["synthetic"]
        plan["groups"] = [{"id": "stand", "mode": "stand", "states": {
            "idle": ["synthetic"], "recovery": ["synthetic"]}}]
        proof["source_sha256"] = digest
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "synthetic.ugpal"
            source.write_bytes(raw)
            with patch.object(e, "palette_backend_certificate"), patch.object(e, "verify_palette_sources", return_value=0):
                selected, _, count = c.extract(source, digest, proof, plan, None)
                self.assertEqual([row["id"] for row in selected], ["synthetic"])
                self.assertEqual(count, 0)  # Backend/source-file fixture never claims actual verification.
                wrong = copy.deepcopy(plan)
                wrong["life_stage"] = "neighboring_stage"
                with self.assertRaisesRegex(e.Refused, "CAST_IDENTITY"):
                    c.extract(source, digest, proof, wrong, None)
                wrong = copy.deepcopy(plan)
                wrong["clips"] = ["synthetic", "missing"]
                with self.assertRaisesRegex(e.Refused, "SOURCE_STATE_MISSING"):
                    c.extract(source, digest, proof, wrong, None)
                proof["source_sha256"] = "0" * 64
                with self.assertRaisesRegex(e.Refused, "HASH"):
                    c.extract(source, "0" * 64, proof, plan, None)

    def test_full_scalar_and_mesh_capacities_refuse_before_output(self):
        cases, plan, proof = fixture()
        cases["work"]["frames"] = c.MAX_FRAMES
        with self.assertRaisesRegex(e.Refused, "SCALAR_CAPACITY"):
            c.encode(list(cases.values()), plan, proof, "1" * 64, "2" * 64, "3" * 64)
        part = cases["synthetic"]["geometry"][0]
        part["geometry"][0]["points"] = np.zeros((c.MAX_VERTICES + 1, 3), dtype="<f4")
        with self.assertRaisesRegex(e.Refused, "VERTEX_CAPACITY"):
            c.geometry_fingerprint(part)

    def test_json_hash_and_file_capacity_never_accept_a_refreshed_claim(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "plan.json"
            path.write_text('{"schema":1}')
            digest = c.file_hash(path)
            self.assertEqual(c.read_json(path, digest), {"schema": 1})
            with self.assertRaisesRegex(e.Refused, "DIGEST"):
                c.read_json(path, "0" * 64)
            with self.assertRaisesRegex(e.Refused, "CAPACITY"):
                c.read_json(path, digest, 1)

    def test_existing_bundle_is_untouched_before_any_source_read(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "saved"
            path.mkdir()
            marker = path / "preserved"
            marker.write_bytes(b"prior output")
            args = ["compile", "--source", "absent", "--proof", "absent", "--plan", "absent",
                    "--source-sha256", "0" * 64, "--proof-sha256", "0" * 64,
                    "--plan-sha256", "0" * 64, "--out", str(path)]
            with patch("sys.argv", args), self.assertRaisesRegex(e.Refused, "OUTPUT_EXISTS"):
                c.main()
            self.assertEqual(marker.read_bytes(), b"prior output")
            self.assertEqual(list(path.iterdir()), [marker])


if __name__ == "__main__":
    unittest.main(verbosity=2)
