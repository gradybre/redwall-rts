#!/usr/bin/env python3
"""Synthetic adversarial tests; fixture dimensions and state hooks are not production profiles."""
from __future__ import annotations

import copy
from fractions import Fraction as F
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import measure_underground_profiles as b
import measure_underground_variants as v
from repair_meshy_rig import append_accessor, write_glb
from test_measure_underground_profiles import fixture


def named_fixture() -> tuple[dict,bytes]:
    doc,binary = fixture(False)
    for node,name in zip(doc["nodes"],["Root","RightHand","Body"]):
        node["name"] = name
    doc["nodes"][0]["children"].append(3)
    doc["nodes"].append({"name":"LeftHand"})
    return doc,binary


def parsed(doc: dict, binary: bytes) -> b.Source:
    data = write_glb(doc,binary)
    return b.Source(data,b.hash_bytes(data))


def curve(doc: dict, binary: bytes, node: int, path: str, values: list) -> bytes:
    animation = doc["animations"][0]
    binary,index = append_accessor(doc,binary,values,5126,"VEC4" if path == "rotation" else "VEC3")
    animation["samplers"].append({"input":animation["samplers"][0]["input"],"output":index})
    animation["channels"].append({"sampler":len(animation["samplers"])-1,"target":{"node":node,"path":path}})
    return binary


def combined() -> v.Combined:
    body = parsed(*named_fixture())
    return v.Combined(body,{"idle":body})


def static_fixture() -> tuple[dict,bytes]:
    doc = {"asset":{"version":"2.0"},"buffers":[{"byteLength":0}],"bufferViews":[],"accessors":[],
           "nodes":[{"mesh":0}],"scenes":[{"nodes":[0]}],"scene":0,"meshes":[{"primitives":[{"attributes":{}}]}]}
    binary,index = append_accessor(doc,b"",[(0.,0.,0.),(2.,0.,0.),(0.,1.,0.)],5126,"VEC3")
    doc["meshes"][0]["primitives"][0]["attributes"]["POSITION"] = index
    return doc,binary


def static(doc: dict, binary: bytes) -> dict:
    data = write_glb(doc,binary)
    return v.static_geometry(data,b.hash_bytes(data))


class VariantTests(unittest.TestCase):
    def test_cross_clip_blend_can_exceed_max_of_separate_clip_bounds(self) -> None:
        doc,binary = named_fixture()
        body = parsed(copy.deepcopy(doc),binary)
        a,c = copy.deepcopy(doc),copy.deepcopy(doc)
        ba = curve(a,binary,0,"scale",[(10.,10.,10.)]*2)
        bc = curve(c,binary,1,"translation",[(10.,0.,0.)]*2)
        first,second = parsed(a,ba),parsed(c,bc)
        separate = max(b.continuous_radius(first)[0],b.continuous_radius(second)[0])
        # At a 50% convex blend: root scale=5.5 and child translation=5.
        actual_blend_origin_um = 27500000
        self.assertLess(separate,actual_blend_origin_um)
        joined = v.Combined(body,{"a":first,"b":second})
        self.assertGreaterEqual(joined.body_radius()[0],actual_blend_origin_um)

    def test_node_indices_may_change_when_complete_named_topology_is_identical(self) -> None:
        doc,binary = named_fixture()
        body = parsed(copy.deepcopy(doc),binary)
        order = [3,2,1,0]
        remap = {old:new for new,old in enumerate(order)}
        doc["nodes"] = [doc["nodes"][old] for old in order]
        for node in doc["nodes"]:
            if "children" in node:
                node["children"] = [remap[n] for n in node["children"]]
        doc["scenes"][0]["nodes"] = [remap[0]]
        doc["skins"][0]["joints"] = [remap[n] for n in doc["skins"][0]["joints"]]
        for channel in doc["animations"][0]["channels"]:
            channel["target"]["node"] = remap[channel["target"]["node"]]
        rearranged = v.Combined(body,{"clip":parsed(doc,binary)})
        self.assertEqual(rearranged.body_radius(),v.Combined(body,{"clip":body}).body_radius())

    def test_changed_rest_hierarchy_and_missing_name_refuse(self) -> None:
        body = parsed(*named_fixture())
        for kind in ("rest","parent","name"):
            doc,binary = named_fixture()
            if kind == "rest":
                doc["nodes"][1]["translation"] = [1.,0.,0.]
            elif kind == "parent":
                doc["nodes"][0]["children"].remove(3)
                doc["nodes"][1]["children"] = [3]
            else:
                del doc["nodes"][3]["name"]
            with self.assertRaises(b.MeasurementRefused):
                v.Combined(body,{"clip":parsed(doc,binary)})

    def test_changed_body_geometry_and_inverse_bind_refuse(self) -> None:
        body = parsed(*named_fixture())
        for change in ("geometry","bind"):
            doc,binary = named_fixture()
            if change == "geometry":
                binary,index = append_accessor(doc,binary,[(0.,0.,0.),(20.,0.,0.),(0.,1.,0.)],5126,"VEC3")
                doc["meshes"][0]["primitives"][0]["attributes"]["POSITION"] = index
            else:
                matrix = list(b.IDENTITY)
                matrix[12] = 1.
                binary,index = append_accessor(doc,binary,[matrix],5126,"MAT4")
                doc["skins"][0]["inverseBindMatrices"] = index
            with self.assertRaisesRegex(b.MeasurementRefused,"BODY_"):
                v.Combined(body,{"clip":parsed(doc,binary)})

    def test_influence_filter_keeps_all_used_vertices_but_avoids_unrelated_joint_box(self) -> None:
        doc,binary = named_fixture()
        doc["nodes"][3]["translation"] = [100.,0.,0.]
        doc["skins"][0]["joints"].append(3)
        matrix = list(b.IDENTITY)
        matrix[12] = -100.
        binary,index = append_accessor(doc,binary,[b.IDENTITY,matrix],5126,"MAT4")
        doc["skins"][0]["inverseBindMatrices"] = index
        attrs = doc["meshes"][0]["primitives"][0]["attributes"]
        for name,values,component,kind in [
            ("POSITION",[(0.,0.,0.),(100.,0.,0.)],5126,"VEC3"),
            ("JOINTS_0",[(0,0,0,0),(1,0,0,0)],5121,"VEC4"),
            ("WEIGHTS_0",[(1.,0.,0.,0.)]*2,5126,"VEC4")]:
            binary,attrs[name] = append_accessor(doc,binary,values,component,kind)
        source = parsed(doc,binary)
        radius,parts = v.Combined(source,{"idle":source}).body_radius()
        self.assertEqual(radius,100000000)
        self.assertEqual(parts[0]["influenced_vertex_pairs"],2)
        self.assertGreaterEqual(b.continuous_radius(source)[0],200000000)

    def test_second_influence_set_and_raw_weight_sum_are_preserved(self) -> None:
        doc,binary = named_fixture()
        doc["nodes"][3]["translation"] = [8.,0.,0.]
        doc["skins"][0]["joints"].append(3)
        attrs = doc["meshes"][0]["primitives"][0]["attributes"]
        binary,attrs["JOINTS_1"] = append_accessor(doc,binary,[(1,0,0,0)]*3,5121,"VEC4")
        binary,attrs["WEIGHTS_1"] = append_accessor(doc,binary,[(.5,0.,0.,0.)]*3,5126,"VEC4")
        source = parsed(doc,binary)
        self.assertGreaterEqual(v.Combined(source,{"clip":source}).body_radius()[0],12000000)

    def test_tool_tip_extends_body_and_missing_bone_refuses(self) -> None:
        source = combined()
        gear = {"id":"pick","kind":"right_hand","bone":"RightHand","local_radius_um":5000000}
        result = v.variant(source,[gear],v.state_manifest(["idle"]),["pick"])
        self.assertGreaterEqual(result["continuous_bounds_micrometres"]["x"][1],5000000)
        self.assertFalse(result["admission_qualified"])
        gear["bone"] = "MissingHand"
        with self.assertRaisesRegex(b.MeasurementRefused,"ATTACHMENT_BONE_MISSING"):
            v.attachment_radius(source,gear)

    def test_omitted_or_undeclared_gear_and_cargo_refuse(self) -> None:
        source = combined()
        states = v.state_manifest(["idle"])
        with self.assertRaisesRegex(b.MeasurementRefused,"ATTACHMENT_OMITTED"):
            v.variant(source,[],states,["pick"])
        cargo = {"id":"cargo","kind":"midpoint","local_radius_um":1,"ahead_um":0}
        with self.assertRaisesRegex(b.MeasurementRefused,"ATTACHMENT_OMITTED"):
            v.variant(source,[cargo],states,[])

    def test_changed_cargo_dimensions_change_the_measured_variant(self) -> None:
        source = combined()
        cargo = {"id":"cargo","kind":"midpoint","local_radius_um":100000,"ahead_um":0}
        small = v.variant(source,[cargo],v.state_manifest(["idle"]),["cargo"])
        cargo["local_radius_um"] = 10000000
        large = v.variant(source,[cargo],v.state_manifest(["idle"]),["cargo"])
        self.assertGreater(large["attachments"][0]["continuous_radius_micrometres"],
                           small["attachments"][0]["continuous_radius_micrometres"])
        self.assertEqual(small["attachments"][0]["local_radius_um"],100000)

    def test_inter_hand_log_covers_both_hands_and_variable_full_span(self) -> None:
        doc,binary = named_fixture()
        doc["nodes"][1]["translation"] = [3.,0.,0.]
        doc["nodes"][3]["translation"] = [-2.,0.,0.]
        source = parsed(doc,binary)
        a = {"kind":"inter_hand_log","radius_um":100000,"overhang_um":500000}
        self.assertEqual(v.attachment_radius(v.Combined(source,{"clip":source}),a),5350000)
        a["overhang_um"] = -1
        with self.assertRaisesRegex(b.MeasurementRefused,"LOG_SHAPE"):
            v.attachment_radius(combined(),a)

    def test_seven_state_manifest_cannot_omit_retreat_or_claim_runtime_binding(self) -> None:
        source,states = combined(),v.state_manifest(["idle"])
        with self.assertRaisesRegex(b.MeasurementRefused,"STATE_SET_INCOMPLETE"):
            v.variant(source,[],states[:-1],[])
        states[0]["runtime_binding"] = "pretend-qualified"
        with self.assertRaisesRegex(b.MeasurementRefused,"STATE_BINDING_UNPROVED"):
            v.variant(source,[],states,[])

    def test_static_affine_matrix_transforms_every_primitive(self) -> None:
        doc,binary = static_fixture()
        doc["nodes"][0]["matrix"] = [0.,1.,0.,0.,-1.,0.,0.,0.,0.,0.,1.,0.,2.,-1.,3.,1.]
        result = static(doc,binary)
        self.assertEqual(result["low"],[1,-1,3])
        self.assertEqual(result["high"],[2,1,3])
        self.assertEqual(result["vertices"],3)

    def test_static_second_mesh_instance_cannot_disappear(self) -> None:
        doc,binary = static_fixture()
        doc["nodes"].append({"mesh":0,"translation":[10.,0.,0.]})
        doc["scenes"][0]["nodes"].append(1)
        result = static(doc,binary)
        self.assertEqual(result["high"][0],12)
        self.assertEqual(result["vertices"],6)

    def test_fit_uses_exact_transformed_vertices_not_inflated_affine_interval_box(self) -> None:
        doc,binary = static_fixture()
        binary,index = append_accessor(doc,binary,[(0.,0.,0.),(1.,0.,0.),(-10.,1.,0.),(-9.,1.,0.)],5126,"VEC3")
        doc["meshes"][0]["primitives"][0]["attributes"]["POSITION"] = index
        # x' = x + 10*y creates a unit square. Transforming the local AABB
        # instead would yield width21 and incorrectly shrink a LONGEST fit.
        doc["nodes"][0]["matrix"] = [1.,0.,0.,0.,10.,1.,0.,0.,0.,0.,1.,0.,0.,0.,0.,1.]
        measured = static(doc,binary)
        self.assertEqual(measured["low"],[0,0,0])
        self.assertEqual(measured["high"],[1,1,0])
        self.assertEqual(v.fitted_prop(measured,F(1),"LONGEST","midpoint"),707107)

    def test_static_hash_tamper_and_normalized_position_refuse(self) -> None:
        doc,binary = static_fixture()
        data = write_glb(doc,binary)
        with self.assertRaisesRegex(b.MeasurementRefused,"STATIC_SOURCE_HASH_MISMATCH"):
            v.static_geometry(data,"0"*64)
        doc["accessors"][0]["normalized"] = True
        with self.assertRaisesRegex(b.MeasurementRefused,"STATIC_POSITION_FORMAT"):
            static(doc,binary)

    def test_static_overlapping_transform_forms_and_perspective_refuse(self) -> None:
        for kind in ("both","perspective"):
            doc,binary = static_fixture()
            doc["nodes"][0]["matrix"] = list(b.IDENTITY)
            if kind == "both":
                doc["nodes"][0]["translation"] = [0,0,0]
            else:
                doc["nodes"][0]["matrix"][3] = 1.
            with self.assertRaisesRegex(b.MeasurementRefused,"MATRIX_"):
                static(doc,binary)

    def test_static_source_capacities_and_invalid_accessor_refuse_before_scan(self) -> None:
        doc,binary = static_fixture()
        data = write_glb(doc,binary)
        with patch.object(v,"MAX_STATIC_BYTES",32):
            with self.assertRaisesRegex(b.MeasurementRefused,"STATIC_BYTE_CAPACITY"):
                v.static_geometry(data,b.hash_bytes(data))
        doc["accessors"][0]["count"] = v.MAX_STATIC_VERTICES+1
        with self.assertRaisesRegex(b.MeasurementRefused,"STATIC_VERTEX_CAPACITY"):
            static(doc,binary)

    def test_exact_prop_fit_uses_actual_extent_not_a_height_ratio(self) -> None:
        geometry = static(*static_fixture())
        self.assertEqual(v.fitted_prop(geometry,F(2),"LONGEST","midpoint"),1118034)
        self.assertGreater(v.fitted_prop(geometry,F(2),"LONGEST","right_hand",F(0)),
                           v.fitted_prop(geometry,F(2),"LONGEST","midpoint"))

    def test_duplicate_attachment_clip_and_manifest_identities_refuse(self) -> None:
        source = combined()
        cargo = {"id":"same","kind":"midpoint","local_radius_um":1,"ahead_um":0}
        with self.assertRaisesRegex(b.MeasurementRefused,"ATTACHMENT_SET"):
            v.variant(source,[cargo,cargo],v.state_manifest(["idle"]),["same"])
        with self.assertRaisesRegex(b.MeasurementRefused,"CLIP_SET_CAPACITY"):
            v.Combined(source.body,{str(i):source.body for i in range(v.MAX_CLIPS+1)})
        with self.assertRaisesRegex(b.MeasurementRefused,"MANIFEST_DUPLICATE_IDENTITY"):
            v.record_index([{"id":"same"},{"id":"same"}],("id",))

    def test_cli_cannot_overwrite_input_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory)
            target = repo/"docs/art-reference/manifest.json"
            target.parent.mkdir(parents=True)
            target.write_text("keep original")
            result = subprocess.run([sys.executable,str(Path(v.__file__)),"--asset-root",str(repo/"assets"),
                                     "--repo",str(repo),"--output",str(target)],capture_output=True,text=True,timeout=10)
            self.assertEqual(result.returncode,1)
            self.assertIn("OUTPUT_OVERWRITES_INPUT_AREA",result.stdout)
            self.assertEqual(target.read_text(),"keep original")

    def test_declaration_parser_rejects_changed_expression_and_array_code(self) -> None:
        with self.assertRaisesRegex(b.MeasurementRefused,"DEMO_SCALAR_BINDING_CHANGED"):
            v.scalar("const SIZE: float = source_height * 0.5","SIZE")
        with self.assertRaisesRegex(b.MeasurementRefused,"DEMO_ARRAY_FORMAT"):
            v.string_array('const A: Array[StringName] = [\n &"first", compute_other()\n]',"A")

    def test_changed_fit_algorithm_refuses_even_with_unchanged_constants(self) -> None:
        original = 'func fit() -> int:\n\treturn 2\n\n'
        digest = b.hash_bytes(original[:-1].encode())
        v.reviewed_fit(original,"fit",digest)
        with self.assertRaisesRegex(b.MeasurementRefused,"FIT_FUNCTION_REVIEW_REQUIRED"):
            v.reviewed_fit(original.replace("return 2","return 3"),"fit",digest)
        with self.assertRaisesRegex(b.MeasurementRefused,"FIT_FUNCTION_REVIEW_REQUIRED"):
            v.reviewed_fit(original+original,"fit",digest)

    def test_composed_rotations_cover_continuous_non_endpoint_tool_reach(self) -> None:
        doc,binary = named_fixture()
        binary = curve(doc,binary,0,"rotation",[(0.,0.,0.,1.),(0.,0.,1.,0.)])
        source = parsed(doc,binary)
        joined = v.Combined(source,{"clip":source})
        gear = {"kind":"right_hand","bone":"RightHand","local_radius_um":2000000}
        # Rotating the tip from +X to -X passes through +Y; an endpoint AABB
        # would have no Y extent, but the source proof includes every rotation.
        self.assertGreaterEqual(v.attachment_radius(joined,gear),2000000)

    def test_carried_variants_retain_all_available_crossfade_source_clips(self) -> None:
        body = parsed(*named_fixture())
        clips = {key:body for key in b.CLIPS}
        bindings = {"heights":{"mouse":F(1)},"load_radius":F(1,10),
                    "load_overhang":F(1,5),"hold_ahead":F(1,10),"farm":[]}
        records,gaps = v.cast_variants("mouse_keeper",body,clips,bindings,{})
        self.assertEqual(len(records),2)
        self.assertEqual(gaps,[{"cast_key":"mouse_keeper","reason":"PICK_GEOMETRY_UNAVAILABLE"}])
        for result in records:
            self.assertEqual(set(result["clip_sha256"]),set(clips))
            for state in result["states"]:
                self.assertEqual(set(state["source_candidates"]),set(clips))

    def test_indirect_fit_and_hand_helpers_cannot_drift_with_all_direct_function_pins_unchanged(self) -> None:
        repo,read = Path(v.__file__).resolve().parents[1],v.text_input
        for file,before,after in [
            ("demo_props.gd","return float((SIZES[key] as Array)[1])","return 2.0 * float((SIZES[key] as Array)[1])"),
            ("demo_actor.gd","return _skeleton_to_actor * _skeleton.get_bone_global_pose(_hand_bone) * fit",
             "return _skeleton_to_actor * _skeleton.get_bone_global_pose(_hand_bone) * fit.scaled(Vector3.ONE * 2.0)")]:
            def drift(path: Path) -> tuple[str,str]:
                text,digest = read(path)
                if path.name == file:
                    self.assertIn(before,text)
                    text = text.replace(before,after)
                    # None of the seven direct fitting functions changed.
                    for identity,expected in v.FIT_FUNCTION_SHA256.items():
                        relative,name = identity.split("::")
                        if Path(relative).name == file:
                            v.reviewed_fit(text,name,expected)
                    return text,b.hash_bytes(text.encode())
                return text,digest
            with patch.object(v,"text_input",side_effect=drift):
                with self.assertRaisesRegex(b.MeasurementRefused,"PRESENTATION_SOURCE_REVIEW_REQUIRED"):
                    v.demo_bindings(repo)


if __name__ == "__main__":
    unittest.main(verbosity=2)
