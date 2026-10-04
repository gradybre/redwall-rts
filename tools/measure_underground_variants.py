#!/usr/bin/env python3
"""Measure combined source bodies, blend sets and held geometry without enabling gameplay.

Decision1067. Imports the frozen B1 parser; never stages, rewrites or imports an
asset. Exact source-model bounds and presentation-state candidates remain distinct
from live profile, equipment, cargo, support and movement-policy qualification.
"""
from __future__ import annotations

import argparse
from fractions import Fraction
import json
import math
from pathlib import Path
import re
import struct
from types import SimpleNamespace

import measure_underground_profiles as base

require = base.require
F = Fraction
MAX_CLIPS = 8
MAX_STATIC_BYTES = 128 * 1024 * 1024
MAX_STATIC_VERTICES = 2000000
MAX_ATTACHMENTS = 16
MAX_RATIONAL_BITS = 4096
PROOF = "combined_exact_source_tree_sphere_v1"
IDENTITY = [F(v) for v in base.IDENTITY]
# These are the reviewed source algorithms, not a claim that the final staged
# meshes or live equipment use this mathematical construction. A changed fit
# must be reviewed rather than merely receiving a fresh provenance hash.
FIT_FUNCTION_SHA256 = {
    "godot/demo/cast/demo_actor.gd::_build_load": "fc6098329ae973db6e42266af75ada0660ef3e3fa9723661bccfb36de26cbca6",
    "godot/demo/cast/demo_actor.gd::_place_load": "2ac9eb4480eaf5458e8d5539816cbfc6c54da05c0661b84babdd8df7be3c0178",
    "godot/demo/props/demo_props.gd::scale_for": "fed6a9c6645a62e467b88729e7138ee932c09902863dd7d1843ce15aca109d76",
    "godot/demo/props/demo_props.gd::base_fit": "646ed7ac647e28be4224fa2b8b9785fd380b4846e8fff24db2c027b14421eedc",
    "godot/demo/props/demo_props.gd::drawn_bound": "fb91557d6f04d5b3a0851b6c6302388fb46ade2f87cf6c0580ea3769e2c08ff1",
    "godot/demo/farm/farm_goods.gd::hand_fit": "739394756a1872e5293603f1aa76059b00d13002acc198b4c38ac8c1d112fc85",
    "godot/demo/tunnel/tunnel_ext.gd::pick_fit": "af2413dee2da617e58d9954092584f7a7cd921a3cdb17f4830e3a6adf12b7745",
}
# Full reviewed source files also close indirect-helper drift (drawn_size_m,
# rule_of, _in_right_hand, set_tool and _relative_transform, among others).
# Even unrelated edits require a new review before this importer runs again.
PRESENTATION_SOURCE_SHA256 = {
    "godot/demo/cast/demo_actor.gd": "3cf6e155d65c2085ebf4d637765f4534bc90c5a8fd9f518417848ee788fbfcd8",
    "godot/demo/props/demo_props.gd": "28eebe56851286d2718a89c8c5085ed3ee6e8a817bd5cf821a5dd9e76c2568da",
    "godot/demo/farm/farm_catalog.gd": "f6521f04dd187d09c365b7ec6450302cb0736322ede08c40f002dce9bfac56fc",
    "godot/demo/tunnel/tunnel_ext.gd": "286d386c02ed4e4193965bc0fc196f5054369dd8842656e78b0f27b4594b9492",
    "godot/demo/farm/farm_goods.gd": "e6e231d27a6fd58cc53739b54848230615665e275faca329552c9bd92e230432",
    "tools/stage_demo_assets.py": "10c489d39fd650183affaf003236897828478c831032ace1bb7d2a0735d5db2e",
    "godot/demo/cast/resident_brain.gd": "ce85423ce7aed09b3985630e09a9cbc181c7a4b48ecc3f6b2e67821c05b8075a",
}


def bounded_fraction(value: F) -> F:
    """Keep exact affine composition bounded before hostile denominators grow indefinitely."""
    require(abs(value) <= 1000000000000 and value.numerator.bit_length() <= MAX_RATIONAL_BITS
            and value.denominator.bit_length() <= MAX_RATIONAL_BITS, "RATIONAL_CAPACITY")
    return value


def exact_matrix(node: dict) -> list[F]:
    """Read an affine matrix or construct exact raw-quaternion TRS, without float arithmetic."""
    if "matrix" in node:
        require(not any(k in node for k in ("translation", "rotation", "scale")), "MATRIX_AND_TRS")
        matrix = node["matrix"]
        require(isinstance(matrix, list) and len(matrix) == 16, "MATRIX_SHAPE")
        result = [base.rational(v) for v in matrix]
        require(result[3::4] == [0, 0, 0, 1], "MATRIX_NOT_AFFINE")
        return result
    vectors = []
    for name, default in (("translation", [0, 0, 0]), ("rotation", [0, 0, 0, 1]), ("scale", [1, 1, 1])):
        value = node.get(name, default)
        require(isinstance(value, list) and len(value) == len(default), "TRS_SHAPE")
        vectors.append([base.rational(v) for v in value])
    t, (x, y, z, w), (sx, sy, sz) = vectors
    require(x*x + y*y + z*z + w*w > 0, "ZERO_ROTATION")
    return [(1-2*(y*y+z*z))*sx, 2*(x*y+w*z)*sx, 2*(x*z-w*y)*sx, F(0),
            2*(x*y-w*z)*sy, (1-2*(x*x+z*z))*sy, 2*(y*z+w*x)*sy, F(0),
            2*(x*z+w*y)*sz, 2*(y*z-w*x)*sz, (1-2*(x*x+y*y))*sz, F(0), *t, F(1)]


def exact_product(a: list[F], b: list[F]) -> list[F]:
    """Column-major affine multiplication with explicit rational limits."""
    return [bounded_fraction(sum(a[k*4+r] * b[c*4+k] for k in range(4))) for c in range(4) for r in range(4)]


def affine_box(low: list[F], high: list[F], matrix: list[F]) -> tuple[list[F], list[F]]:
    """Exact interval image, including reflection, shear and translation."""
    result_low, result_high = [], []
    for axis in range(3):
        lo = hi = matrix[12+axis]
        for j in range(3):
            a, b = matrix[j*4+axis] * low[j], matrix[j*4+axis] * high[j]
            lo, hi = lo + min(a, b), hi + max(a, b)
        result_low.append(bounded_fraction(lo))
        result_high.append(bounded_fraction(hi))
    return result_low, result_high


def position_layout(doc: dict, binary: bytes, index: int, remaining: int) -> tuple[int,int,int]:
    """Validate one bounded stream before scanning any actual float32 position."""
    require(base.integer(index, 0, len(doc.get("accessors", []))-1), "STATIC_ACCESSOR_INDEX")
    a = doc["accessors"][index]
    require(a.get("componentType") == 5126 and a.get("type") == "VEC3"
            and not a.get("normalized") and not a.get("sparse"), "STATIC_POSITION_FORMAT")
    count = a.get("count")
    require(base.integer(count, 1, remaining), "STATIC_VERTEX_CAPACITY")
    require(base.integer(a.get("bufferView"), 0, len(doc.get("bufferViews", []))-1), "STATIC_VIEW_INDEX")
    view = doc["bufferViews"][a["bufferView"]]
    start, length = view.get("byteOffset", 0), view.get("byteLength")
    stride, offset = view.get("byteStride", 12), a.get("byteOffset", 0)
    require(view.get("buffer") == 0 and base.integer(start, 0, len(binary))
            and base.integer(length, 1, len(binary)-start), "STATIC_VIEW_BOUNDS")
    require(base.integer(stride, 12, 4096) and base.integer(offset, 0, length)
            and offset + (count-1)*stride + 12 <= length, "STATIC_ACCESSOR_BOUNDS")
    return start+offset,stride,count


def local_extrema(binary: bytes, start: int, stride: int, count: int) -> tuple[list[F],list[F]]:
    """Exact source float32 extrema need comparisons only, without rounding any coordinate."""
    low, high = [math.inf]*3, [-math.inf]*3
    for vertex in range(count):
        values = struct.unpack_from("<fff", binary, start + vertex*stride)
        for axis, value in enumerate(values):
            require(math.isfinite(value) and abs(value) <= 1000000, "STATIC_NONFINITE_OR_EXTREME")
            low[axis], high[axis] = min(low[axis], value), max(high[axis], value)
    return [F(v) for v in low], [F(v) for v in high]


def transformed_extrema(binary: bytes, start: int, stride: int, count: int,
                        matrix: list[F]) -> tuple[list[F],list[F]]:
    """A fit denominator needs actual transformed-vertex extrema, never an interval-box overestimate."""
    low,high = None,None
    for vertex in range(count):
        values = struct.unpack_from("<fff", binary, start + vertex*stride)
        require(all(math.isfinite(v) and abs(v) <= 1000000 for v in values), "STATIC_NONFINITE_OR_EXTREME")
        p = [F(v) for v in values]
        actual = [bounded_fraction(sum(matrix[j*4+axis]*p[j] for j in range(3)) + matrix[12+axis])
                  for axis in range(3)]
        low = actual if low is None else [min(a,b) for a,b in zip(low,actual)]
        high = actual if high is None else [max(a,b) for a,b in zip(high,actual)]
    return low,high


def primitive_bounds(doc: dict, binary: bytes, index: int, remaining: int,
                     matrix: list[F]) -> tuple[list[F], list[F], int]:
    """Measure exact transformed extrema while retaining the cheap exact axis-aligned case."""
    start,stride,count = position_layout(doc,binary,index,remaining)
    if all(sum(matrix[j*4+axis] != 0 for j in range(3)) <= 1 for axis in range(3)):
        # Each output coordinate depends on at most one input coordinate, so
        # transforming its actual local extrema is exact even under reflection.
        low,high = local_extrema(binary,start,stride,count)
        low,high = affine_box(low,high,matrix)
    else:
        low,high = transformed_extrema(binary,start,stride,count,matrix)
    return low,high,count


def static_geometry(data: bytes, expected_sha256: str) -> dict:
    """Measure all scene instances in an actual static prop, preserving exact affine transforms."""
    require(28 <= len(data) <= MAX_STATIC_BYTES, "STATIC_BYTE_CAPACITY")
    require(isinstance(expected_sha256, str) and re.fullmatch(r"[0-9a-f]{64}", expected_sha256)
            and base.hash_bytes(data) == expected_sha256, "STATIC_SOURCE_HASH_MISMATCH")
    try:
        json_size = struct.unpack_from("<I", data, 12)[0]
        offset = 20 + json_size
        require(json_size % 4 == 0 and offset + 8 <= len(data), "STATIC_CHUNKS")
        bin_size = struct.unpack_from("<I", data, offset)[0]
        require(bin_size % 4 == 0 and offset + 8 + bin_size == len(data), "STATIC_CHUNKS")
        doc, binary = base.read_glb(data)
        require(doc.get("asset", {}).get("version") == "2.0", "STATIC_VERSION")
        require(not doc.get("extensionsUsed") and not doc.get("extensionsRequired")
                and not doc.get("animations") and not doc.get("skins"), "STATIC_UNSUPPORTED")
        require(len(doc.get("buffers", [])) == 1 and "uri" not in doc["buffers"][0]
                and doc["buffers"][0].get("byteLength") == len(binary), "STATIC_BUFFER")
        require(0 < len(doc.get("nodes", [])) <= base.MAX_NODES, "STATIC_NODE_CAPACITY")
        parents, order = base.Source._hierarchy(SimpleNamespace(doc=doc))
        worlds, low, high, count, parts = {}, None, None, 0, []
        for index in order:
            node = doc["nodes"][index]
            require(not node.get("extensions") and "skin" not in node and "weights" not in node,
                    "STATIC_NODE_UNSUPPORTED")
            worlds[index] = exact_product(worlds.get(parents.get(index), IDENTITY), exact_matrix(node))
            if "mesh" not in node:
                continue
            require(base.integer(node["mesh"], 0, len(doc.get("meshes", []))-1), "STATIC_MESH_INDEX")
            mesh = doc["meshes"][node["mesh"]]
            require(not mesh.get("weights") and not mesh.get("extensions"), "STATIC_MESH_UNSUPPORTED")
            for number, primitive in enumerate(mesh.get("primitives", [])):
                require(len(parts) < base.MAX_PRIMITIVES and not primitive.get("targets")
                        and not primitive.get("extensions"), "STATIC_PRIMITIVE_UNSUPPORTED")
                attrs = primitive["attributes"]
                require(not any(k.startswith(("JOINTS_", "WEIGHTS_")) for k in attrs), "STATIC_SKIN_UNBOUND")
                lo, hi, n = primitive_bounds(doc, binary, attrs["POSITION"], MAX_STATIC_VERTICES-count, worlds[index])
                low = lo if low is None else [min(a,b) for a,b in zip(low,lo)]
                high = hi if high is None else [max(a,b) for a,b in zip(high,hi)]
                count += n
                parts.append({"node": index, "primitive": number, "vertices": n})
        require(bool(parts), "STATIC_NO_GEOMETRY")
        return {"sha256": expected_sha256, "bytes": len(data), "low": low, "high": high,
                "parts": parts, "vertices": count}
    except (base.RepairRefused, KeyError, IndexError, TypeError, AttributeError, struct.error) as error:
        raise base.MeasurementRefused("STATIC_STRUCTURE") from error


def node_names(source: base.Source) -> dict[str, int]:
    """Bone/mesh names are explicit remapping keys, never coincident GLB indices."""
    result = {}
    for i, node in enumerate(source.doc["nodes"]):
        name = node.get("name")
        require(isinstance(name, str) and 0 < len(name) <= 256 and name not in result, "RIG_NODE_NAME")
        result[name] = i
    return result


class Combined:
    """One body and compatible clip set, with per-node convex blend envelopes."""

    def __init__(self, body: base.Source, clips: dict[str, base.Source]) -> None:
        require(0 < len(clips) <= MAX_CLIPS and all(isinstance(k,str) and 0 < len(k) <= 128 for k in clips),
                "CLIP_SET_CAPACITY")
        self.body, self.clips, self.names = body, clips, node_names(body)
        self.merged = {}
        for clip in clips.values():
            mapping = self._compatible(clip)
            for name, index in self.names.items():
                for path, curve in clip.channels.get(mapping[name], {}).items():
                    self.merged.setdefault(index, {}).setdefault(path, ([], [], "LINEAR"))[1].extend(curve[1])
        self.hierarchy = base.hierarchy_bounds(SimpleNamespace(doc=body.doc, order=body.order,
                                                              parents=body.parents, channels=self.merged))

    def _compatible(self, clip: base.Source) -> dict[str, int]:
        """Require the real shared skeleton/rest and mesh binding before combining animation tracks."""
        other = node_names(clip)
        require(set(other) == set(self.names), "RIG_NODE_SET_MISMATCH")
        for name, index in self.names.items():
            target = other[name]
            a, b = self.body.doc["nodes"][index], clip.doc["nodes"][target]
            parent_a, parent_b = self.body.parents.get(index), clip.parents.get(target)
            require((None if parent_a is None else self.body.doc["nodes"][parent_a]["name"])
                    == (None if parent_b is None else clip.doc["nodes"][parent_b]["name"]), "RIG_PARENT_MISMATCH")
            for path, default in (("translation", [0,0,0]), ("rotation", [0,0,0,1]), ("scale", [1,1,1])):
                require(a.get(path,default) == b.get(path,default), "RIG_REST_MISMATCH")
        require(len(self.body.parts) == len(clip.parts), "BODY_PART_SET_MISMATCH")
        keyed = {(clip.doc["nodes"][p["node"]]["name"], p["id"].split("/")[-1]):p for p in clip.parts}
        for part in self.body.parts:
            key = (self.body.doc["nodes"][part["node"]]["name"], part["id"].split("/")[-1])
            require(key in keyed, "BODY_PART_SET_MISMATCH")
            other_part = keyed[key]
            require(part["positions"] == other_part["positions"] and part["influences"] == other_part["influences"],
                    "BODY_GEOMETRY_MISMATCH")
            if part["skin"] is None:
                require(other_part["skin"] is None, "BODY_SKIN_MISMATCH")
            else:
                require(other_part["skin"] is not None, "BODY_SKIN_MISMATCH")
                joints, binds = part["skin"]
                other_joints, other_binds = other_part["skin"]
                require([self.body.doc["nodes"][j]["name"] for j in joints]
                        == [clip.doc["nodes"][j]["name"] for j in other_joints]
                        and binds == other_binds, "BODY_SKIN_MISMATCH")
        return other

    def body_radius(self) -> tuple[int, list[dict]]:
        """Bound each joint only over vertices it actually influences, preserving every positive weight."""
        result, records = 0, []
        for part in self.body.parts:
            if part["skin"] is None:
                a,b = self.hierarchy[part["node"]]
                radius = base.ceil_fraction(a * base.inverse_bound_radius(part["positions"], base.IDENTITY) + b)
                influenced = 0
            else:
                points, max_weight = {}, F(1)
                for vertex, position in enumerate(part["positions"]):
                    total, used = F(0), set()
                    for joints, weights in part["influences"]:
                        for joint, weight in zip(joints[vertex], weights[vertex]):
                            total += base.rational(weight)
                            if weight > 0:
                                used.add(joint)
                    require(total > 0, "SKIN_ZERO_WEIGHT")
                    max_weight = max(max_weight, total)
                    for joint in used:
                        points.setdefault(joint, []).append(position)
                joints, binds = part["skin"]
                radii = [self.hierarchy[joints[j]][0] * base.inverse_bound_radius(p, binds[j])
                         + self.hierarchy[joints[j]][1] for j,p in points.items()]
                radius = base.ceil_fraction(max(radii) * max_weight)
                influenced = sum(len(p) for p in points.values())
            result = max(result, radius)
            records.append({"primitive": part["id"], "vertices": len(part["positions"]),
                            "influenced_vertex_pairs": influenced, "continuous_radius_micrometres": radius})
        return result, records

    def bone(self, name: str) -> tuple[F,F]:
        """Return the full source-bound A/B pair, refusing a missing attachment bone."""
        require(name in self.names, "ATTACHMENT_BONE_MISSING")
        return self.hierarchy[self.names[name]]


def fitted_prop(geometry: dict, target: F, rule: str, attachment: str, grip: F = F(0)) -> int:
    """Bound the real prop under its existing uniform demo fit and hand-local origin."""
    require(rule in ("HEIGHT","LONGEST") and 0 < target <= 1000 and 0 <= grip <= 1,
            "PROP_FIT_INVALID")
    lo, hi = geometry["low"], geometry["high"]
    extent = [b-a for a,b in zip(lo,hi)]
    size = extent[1] if rule == "HEIGHT" else max(extent)
    require(size > 0, "PROP_FLAT")
    scale = target / size
    if attachment == "midpoint":
        reach = [e*scale/2 for e in extent]
    else:
        require(attachment == "right_hand", "ATTACHMENT_KIND")
        # base_fit recentres X/Z and grounds Y; pick_fit removes the actual
        # grip again. Its quarter-turns preserve this radial bound exactly.
        reach = [max(grip,1-grip)*extent[0]*scale, extent[1]*scale/2, extent[2]*scale/2]
    return base.norm_upper_um(reach)


def attachment_radius(combined: Combined, attachment: dict) -> int:
    """Enclose actual bone-local props, fixed midpoint cargo or the variable inter-hand log."""
    kind = attachment.get("kind")
    if kind == "right_hand":
        a,b = combined.bone(attachment.get("bone", ""))
        require(base.integer(attachment.get("local_radius_um"), 0, 1000000000), "ATTACHMENT_RADIUS")
        return base.ceil_fraction(a*attachment["local_radius_um"] + b)
    require(kind in ("midpoint", "inter_hand_log"), "ATTACHMENT_KIND")
    left, right = combined.bone("LeftHand")[1], combined.bone("RightHand")[1]
    midpoint = (left+right)/2
    if kind == "midpoint":
        require(base.integer(attachment.get("local_radius_um"), 0, 1000000000)
                and base.integer(attachment.get("ahead_um"), 0, 1000000000), "ATTACHMENT_RADIUS")
        return base.ceil_fraction(midpoint + attachment["ahead_um"] + attachment["local_radius_um"])
    require(base.integer(attachment.get("radius_um"), 0, 1000000000)
            and base.integer(attachment.get("overhang_um"), 0, 1000000000), "LOG_SHAPE")
    # |right-left| <= |right|+|left|. The radial cross-section plus half its
    # full variable height encloses the cylinder for every orientation.
    return base.ceil_fraction(midpoint + (left+right+attachment["overhang_um"])/2 + attachment["radius_um"])


def state_manifest(clips: list[str]) -> list[dict]:
    """Map observed demo behavior to source candidates; no entry becomes a legal-state permission."""
    hooks = {"ENTRY":"resident_brain._enter_tunnel_leg", "TRAVEL":"demo_actor.choose_clip",
             "HOLD":"resident_brain._enter_hold", "TURN":"resident_brain._enter_turn",
             "REVERSAL":"resident_brain.turn_back", "RETREAT":"resident_brain._walk_out",
             "EXIT":"resident_brain._walk_out_from"}
    return [{"state": state, "source_candidates": sorted(clips), "presentation_hook": hooks[state],
             "status":"PRESENTATION_CANDIDATES_ONLY", "runtime_binding": None}
            for state in base.STATES]


def variant(combined: Combined, attachments: list[dict], states: list[dict], required_ids: list[str]) -> dict:
    """Build a closed source measurement with all required attachments and explicit state gaps."""
    require(len(attachments) <= MAX_ATTACHMENTS and all(isinstance(a.get("id"),str) and 0 < len(a["id"]) <= 128
                for a in attachments) and len({a["id"] for a in attachments}) == len(attachments),
            "ATTACHMENT_SET")
    require(len(required_ids) <= MAX_ATTACHMENTS and len(set(required_ids)) == len(required_ids)
            and {a["id"] for a in attachments} == set(required_ids), "ATTACHMENT_OMITTED_OR_UNDECLARED")
    require(len(states) == len(base.STATES) and {s.get("state") for s in states} == set(base.STATES),
            "STATE_SET_INCOMPLETE")
    require(all(s.get("runtime_binding") is None and s.get("status") == "PRESENTATION_CANDIDATES_ONLY"
                and set(s.get("source_candidates", [])) == set(combined.clips) for s in states), "STATE_BINDING_UNPROVED")
    body_radius, body_parts = combined.body_radius()
    records = [{**a, "continuous_radius_micrometres": attachment_radius(combined,a)} for a in attachments]
    radius = max([body_radius] + [a["continuous_radius_micrometres"] for a in records])
    units = list(base.quantize_axis_units(-radius, radius, 0))
    require(all(-2147483648 <= v <= 2147483647 for v in units), "BOUND_INT32_CAPACITY")
    return {"status":"PARTIAL_COMBINED_SOURCE_VARIANT", "admission_qualified":False,
            "body_sha256":combined.body.sha256, "clip_sha256":{k:v.sha256 for k,v in combined.clips.items()},
            "body_parts":body_parts, "attachments":records, "states":states,
            "continuous_bounds_micrometres":{axis:[-radius,radius] for axis in "xyz"},
            "outward_diagnostic_bounds_u_no_safety_margin":{axis:units for axis in "xyz"},
            "certificate":{"method":PROOF,"source_interpolation_residual_units":0,
                           "scope":"combined mathematical source hierarchy, convex TRS blends and declared attachments; runtime numeric/deformation errors unqualified"},
            "missing_bindings":["FINAL_STAGED_ASSET_SET", "RUNTIME_DEFORMATION_AND_NUMERIC_MARGIN",
                                "ACTUAL_LEGAL_STATE_AND_COST_OWNER", "LIVE_GEAR_AND_CARGO_VARIANT_OWNER",
                                "ACCEPTED_PROFILE_REVISION", "ACTUAL_SUPPORT_CONTACT_AND_ROOT_ANCHOR"]}


def text_input(path: Path) -> tuple[str,str]:
    """Bound and fingerprint a source declaration without importing or executing it."""
    data = base.bounded_bytes(path, 4*1024*1024, "DECLARATION_CAPACITY")
    return data.decode("utf-8"), base.hash_bytes(data)


def scalar(text: str, name: str) -> F:
    """Read one explicit existing GDScript float literal; changed expressions require review."""
    matches = re.findall(r"^const " + re.escape(name) + r": float = ([0-9]+(?:\.[0-9]+)?)\s*$", text, re.M)
    require(len(matches) == 1, "DEMO_SCALAR_BINDING_CHANGED:"+name)
    return base.rational(float(matches[0]))


def string_array(text: str, name: str) -> list[str]:
    """Accept only the actual flat StringName array form, never guessed list ordering."""
    found = re.findall(r"^const " + re.escape(name) + r": Array\[StringName\] = \[([\s\S]*?)\n\]", text, re.M)
    require(len(found) == 1, "DEMO_ARRAY_BINDING_CHANGED:"+name)
    content = "\n".join(line.split("#")[0] for line in found[0].splitlines())
    names = re.findall(r'&"([a-z0-9_]*)"', content)
    require(len(names) <= 128 and not re.sub(r'&"[a-z0-9_]*"|[\s,]', "", content), "DEMO_ARRAY_FORMAT")
    return names


def reviewed_fit(text: str, name: str, expected_sha256: str) -> None:
    """Refuse algorithm drift even when every fitting constant remains unchanged."""
    matches = re.findall(r"^(?:static )?func " + re.escape(name)
                         + r"\([^\n]*(?:\n[\t ][^\n]*|\n(?=\n))*", text, re.M)
    require(len(matches) == 1 and base.hash_bytes(matches[0].encode()) == expected_sha256,
            "FIT_FUNCTION_REVIEW_REQUIRED:"+name)


def demo_bindings(repo: Path) -> dict:
    """Read actual presentation fitting declarations; they remain presentation provenance only."""
    paths = {"actor":"godot/demo/cast/demo_actor.gd", "props":"godot/demo/props/demo_props.gd",
             "farm":"godot/demo/farm/farm_catalog.gd", "pick":"godot/demo/tunnel/tunnel_ext.gd",
             "goods":"godot/demo/farm/farm_goods.gd", "stage":"tools/stage_demo_assets.py",
             "brain":"godot/demo/cast/resident_brain.gd"}
    contents, hashes = {}, {}
    for key,path in paths.items():
        contents[key], hashes[path] = text_input(repo/path)
        require(base.hash_bytes(contents[key].encode()) == PRESENTATION_SOURCE_SHA256[path]
                and hashes[path] == PRESENTATION_SOURCE_SHA256[path], "PRESENTATION_SOURCE_REVIEW_REQUIRED:"+path)
    by_path = {path:contents[key] for key,path in paths.items()}
    for identity,expected in FIT_FUNCTION_SHA256.items():
        path,name = identity.split("::")
        reviewed_fit(by_path[path],name,expected)
    sizes = re.findall(r'&"([a-z0-9_]+)": \[RULE_(HEIGHT|LONGEST), ([0-9]+(?:\.[0-9]+)?)\]', contents["props"])
    require(sizes and len(sizes) <= 256 and len({s[0] for s in sizes}) == len(sizes), "DEMO_PROP_SIZES")
    sizes = {key:(rule,base.rational(float(size))) for key,rule,size in sizes}
    keys, props = string_array(contents["farm"], "ITEM_KEYS"), string_array(contents["farm"], "ITEM_PROP")
    count = re.findall(r"^const ITEM_COUNT: int = ([0-9]+)\s*$", contents["farm"], re.M)
    require(len(count) == 1 and len(keys) == len(props) and 0 < int(count[0]) <= len(keys), "DEMO_FARM_BINDING")
    heights = re.findall(r'^SPECIES_HEIGHT_M = \{([^\n]+)\}', contents["stage"], re.M)
    require(len(heights) == 1, "DEMO_HEIGHT_BINDING")
    height_values = {k:base.rational(float(v)) for k,v in re.findall(r'"([a-z]+)": ([0-9]+(?:\.[0-9]+)?)', heights[0])}
    require(all(cast.split("_")[0] in height_values for cast in base.CAST), "DEMO_HEIGHT_BINDING")
    require(re.search(r"^const PICK_EULER_DEG: Vector3 = Vector3\(0\.0, 90\.0, 90\.0\)\s*$", contents["pick"], re.M),
            "PICK_ROTATION_BINDING_CHANGED")
    return {"source_sha256":hashes, "fit_sha256":FIT_FUNCTION_SHA256, "sizes":sizes, "heights":height_values,
            "farm":list(zip(keys[:int(count[0])],props[:int(count[0])])),
            "load_radius":scalar(contents["actor"],"LOAD_RADIUS_PER_HEIGHT"),
            "load_overhang":scalar(contents["actor"],"LOAD_OVERHANG_PER_HEIGHT"),
            "hold_ahead":scalar(contents["actor"],"HOLD_FORWARD_PER_HEIGHT"),
            "pick_grip":scalar(contents["pick"],"PICK_GRIP_SHARE")}


def manifest_inputs(repo: Path) -> tuple[dict,dict]:
    """Load existing provenance reports; duplicate identities refuse instead of last-write-wins."""
    reports, hashes = {}, {}
    for name in ("grounded.json","tailed.json","repaired.json","files.json"):
        path = Path("docs/art-reference/asset_library")/name
        contents, hashes[str(path)] = text_input(repo/path)
        reports[name] = json.loads(contents)
    return reports,hashes


def record_index(rows: list[dict], fields: tuple[str,...]) -> dict:
    """Bound and index an existing manifest's exact identity tuple."""
    require(isinstance(rows,list) and len(rows) <= 10000, "MANIFEST_RECORD_CAPACITY")
    result = {}
    for row in rows:
        key = tuple(row[field] for field in fields)
        require(key not in result, "MANIFEST_DUPLICATE_IDENTITY")
        result[key] = row
    return result


def source_file(root: Path, relative: str, expected: str) -> base.Source:
    """Reuse B1 validation and exact bytes; paths cannot escape the selected library."""
    path = root/relative
    require(path.resolve().is_relative_to(root.resolve()), "SOURCE_PATH_ESCAPE")
    return base.Source(base.bounded_bytes(path,base.MAX_FILE_BYTES,"SOURCE_BYTE_CAPACITY"),expected)


def static_report(geometry: dict) -> dict:
    """Export only outward integers, hashes and counts; the exact rationals stay local to measurement."""
    return {key:geometry[key] for key in ("sha256","bytes","parts","vertices")} | {
        "bounds_micrometres":{axis:[math.floor(geometry["low"][i]*base.MICROMETRES),
                                    math.ceil(geometry["high"][i]*base.MICROMETRES)] for i,axis in enumerate("xyz")}}


def prepare_props(root: Path, bindings: dict, files: dict) -> tuple[dict,list[dict]]:
    """Measure available original pick/farm geometry; missing or unsupported assets are explicit gaps."""
    props, gaps = {}, []
    keys = sorted({"mole_pick"} | {key for _,key in bindings["farm"] if key})
    for key in keys:
        relative = f"prop/{key}/highpoly.glb"
        path = root/relative
        require(path.resolve().is_relative_to(root.resolve()), "SOURCE_PATH_ESCAPE")
        manifest_key = ("assets/library/"+relative,)
        if manifest_key not in files or not path.is_file():
            gaps.append({"source":relative,"reason":"PROP_SOURCE_OR_MANIFEST_MISSING"})
            continue
        print("measuring attachment "+key,flush=True)
        try:
            geometry = static_geometry(base.bounded_bytes(path,MAX_STATIC_BYTES,"STATIC_BYTE_CAPACITY"),
                                       files[manifest_key]["sha256"])
        except base.MeasurementRefused as error:
            # A hash mismatch must abort: it is changed provenance, not a missing variant.
            if str(error) == "STATIC_SOURCE_HASH_MISMATCH":
                raise
            gaps.append({"source":relative,"reason":str(error)})
            continue
        geometry["source"] = relative
        props[key] = geometry
    return props,gaps


def named_variant(cast: str, key: str, combined: Combined, attachments: list[dict]) -> dict:
    """The batch declares expected attachments independently of validation and preserves variant identity."""
    expected = [] if key == "unloaded" else [key]
    result = variant(combined,attachments,state_manifest(list(combined.clips)),expected)
    result.update({"cast_key":cast,"variant_key":key,"gear_lot_ref":None,"cargo_lot_ref":None,
                   "core_item_variant":None,"cargo_quantity_milli":None})
    return result


def cast_variants(cast: str, body: base.Source, clips: dict, bindings: dict, props: dict) -> tuple[list[dict],list[dict]]:
    """Measure body, moving log/cargo and available work-tool sets; no source is invented for a missing clip."""
    require(all(key in clips for key in ("anim_idle","anim_walk","anim_cautious_crouch_walk_forward")),
            "REQUIRED_LOCOMOTION_SOURCE_MISSING")
    # Include every available clip in every source variant. Even a hidden-to-
    # visible attachment may follow a crossfade from a different action. Extra
    # impossible combinations widen evidence; they grant no action permission.
    joined = Combined(body,clips)
    records, gaps = [named_variant(cast,"unloaded",joined,[])], []
    if "anim_carry_heavy_object_walk" not in clips:
        return records,[{"cast_key":cast,"reason":"CARRY_SOURCE_MISSING"}]
    height = bindings["heights"][cast.split("_")[0]]
    log = {"id":"inter_hand_log","kind":"inter_hand_log",
           "radius_um":base.ceil_fraction(height*bindings["load_radius"]*base.MICROMETRES),
           "overhang_um":base.ceil_fraction(height*bindings["load_overhang"]*base.MICROMETRES),
           "geometry_source":"demo_actor._build_load/_place_load; existing procedural cylinder"}
    records.append(named_variant(cast,"inter_hand_log",joined,[log]))
    for item,prop in bindings["farm"]:
        if not prop:
            gaps.append({"cast_key":cast,"farm_item":item,"reason":"NO_EXISTING_ITEM_PROP_BINDING"})
            continue
        if prop not in props:
            gaps.append({"cast_key":cast,"farm_item":item,"reason":"PROP_GEOMETRY_UNAVAILABLE"})
            continue
        rule,target = bindings["sizes"][prop]
        record = {"id":item,"kind":"midpoint","source_sha256":props[prop]["sha256"],
                  "source":props[prop]["source"],"prop_key":prop,"farm_item":item,
                  "local_radius_um":fitted_prop(props[prop],target,rule,"midpoint"),
                  "ahead_um":base.ceil_fraction(height*bindings["hold_ahead"]*base.MICROMETRES),
                  "fit_source":"farm_goods.hand_fit + demo_actor._place_load; original highpoly, final staged fit unqualified"}
        records.append(named_variant(cast,item,joined,[record]))
    if "anim_heavy_hammer_swing" not in clips:
        gaps.append({"cast_key":cast,"reason":"HAMMER_WORK_SOURCE_MISSING"})
    elif "mole_pick" not in props:
        gaps.append({"cast_key":cast,"reason":"PICK_GEOMETRY_UNAVAILABLE"})
    else:
        rule,target = bindings["sizes"]["mole_pick"]
        pick = {"id":"mole_pick","kind":"right_hand","bone":"RightHand",
                "source_sha256":props["mole_pick"]["sha256"],"source":props["mole_pick"]["source"],
                "local_radius_um":fitted_prop(props["mole_pick"],target,rule,"right_hand",bindings["pick_grip"]),
                "fit_source":"tunnel_ext.pick_fit; original highpoly, final staged fit unqualified"}
        records.append(named_variant(cast,"mole_pick",joined,[pick]))
    return records,gaps


def measure_library(root: Path, repo: Path) -> dict:
    """Process one cast at a time; committed artifacts contain no source asset payloads."""
    bindings = demo_bindings(repo)
    reports,manifest_hashes = manifest_inputs(repo)
    grounded = record_index(reports["grounded.json"]["clips"],("key","clip"))
    tailed = record_index(reports["tailed.json"]["files"],("key","file"))
    repaired = record_index(reports["repaired.json"]["files"],("key","file"))
    files = record_index(reports["files.json"]["files"],("path",))
    props,gaps = prepare_props(root,bindings,files)
    records,bodies = [],[]
    for cast in base.CAST:
        print("measuring combined cast "+cast,flush=True)
        entry = tailed.get((cast,"rigged.glb"),repaired.get((cast,"rigged.glb")))
        require(entry is not None, "BODY_MANIFEST_MISSING")
        relative = f"creature/{cast}/grounded/rigged.glb"
        body = source_file(root,relative,entry["output_sha256"])
        bodies.append({"cast_key":cast,"source":relative,"sha256":body.sha256,
                       "provenance":"tailed/repaired rigged.glb copied unchanged by ground_meshy_clips"})
        clips = {}
        for key in base.CLIPS:
            relative = f"creature/{cast}/grounded/{key}.glb"
            if (cast,key) in grounded and (root/relative).is_file():
                clips[key] = source_file(root,relative,grounded[cast,key]["output_sha256"])
        results,missing = cast_variants(cast,body,clips,bindings,props)
        records.extend(results)
        gaps.extend(missing)
    tools = [Path(__file__),Path(base.__file__),*(Path(__file__).with_name(name) for name in
              ("repair_meshy_rig.py","rig_meshy_tail.py","validate_movement_envelopes.py"))]
    return {"schema":"redwall.underground.combined_source_variant/1","target_envelope_schema":2,
            "admission_qualified":False,"record_count":len(records),"bodies":bodies,
            "static_sources":{key:{**static_report(value),"source":value["source"]} for key,value in props.items()},
            "manifest_sha256":manifest_hashes,"presentation_binding_sha256":bindings["source_sha256"],
            "reviewed_fit_function_sha256":bindings["fit_sha256"],
            "tool_sha256":{p.name:base.hash_bytes(p.read_bytes()) for p in tools},
            "gaps":gaps,"records":records}


def main() -> int:
    """Success means combined source measurements exist, never qualified traversal or economic work."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asset-root",type=Path,required=True)
    parser.add_argument("--repo",type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output",type=Path,required=True)
    args = parser.parse_args()
    try:
        output = args.output.resolve()
        require(not output.is_relative_to(args.asset_root.resolve()),"OUTPUT_INSIDE_SOURCE_LIBRARY")
        # Restrict output to a report path, excluding executable/source/manifest inputs.
        require(output.suffix == ".json" and not output.is_relative_to((args.repo/"docs/art-reference").resolve())
                and not output.is_relative_to((args.repo/"tools").resolve())
                and not output.is_relative_to((args.repo/"godot").resolve()),"OUTPUT_OVERWRITES_INPUT_AREA")
        result = measure_library(args.asset_root,args.repo)
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
        print(f"variants: {result['record_count']} measured combined source(s), 0 production-qualified profile(s); "
              f"{len(result['static_sources'])} actual prop source(s), {len(result['gaps'])} explicit source/binding gap(s)")
        return 0
    except (base.MeasurementRefused,base.EnvelopeRefusal,OSError,ValueError,KeyError,IndexError,TypeError) as error:
        print(f"variant measurement refused: {error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
