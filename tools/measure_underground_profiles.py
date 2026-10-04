#!/usr/bin/env python3
"""Read-only, source-bound underground actor measurements; never publishes a movement profile.

The exact-rational hierarchy sphere encloses every embedded primitive under all
local rotations and the source's LINEAR/STEP translation/scale ranges. Its loose
bounds cover continuous source interpolation; tighter sampled bounds are only
diagnostics. Neither proves complete legal states, external gear/cargo, runtime
tail constraints, support, contact, traversal policy or renderer error margins.
See decision1063 and MOVE-C2/C3. No asset is normalized, staged or rewritten.
"""
from __future__ import annotations

import argparse
import bisect
import hashlib
import json
import math
from pathlib import Path
import re
import struct
from fractions import Fraction
from typing import Any

from repair_meshy_rig import COMPONENTS, WIDTHS, RepairRefused, read_accessor, read_glb
from rig_meshy_tail import mat_mul, transform_point, trs_matrix
from validate_movement_envelopes import EnvelopeRefusal, quantize_axis_units

MAX_FILE_BYTES = 64 * 1024 * 1024
MAX_NODES = 512
MAX_PRIMITIVES = 256
MAX_ACCESSOR_VALUES = 2000000
MAX_VERTICES = 100000
MAX_CHANNELS = 2048
MAX_KEYS = 8192
MAX_SAMPLE_POSES = 33
MICROMETRES = 1000000
STATES = ("ENTRY", "TRAVEL", "HOLD", "TURN", "REVERSAL", "RETREAT", "EXIT")
CAST = ("mouse_keeper", "mole_digger", "squirrel_gatherer", "otter_boatwright", "badger_quarryman")
CLIPS = ("anim_walk", "anim_idle", "anim_cautious_crouch_walk_forward",
         "anim_carry_heavy_object_walk", "anim_heavy_hammer_swing")
IDENTITY = [1., 0., 0., 0., 0., 1., 0., 0., 0., 0., 1., 0., 0., 0., 0., 1.]


class MeasurementRefused(ValueError):
    """Malformed or unsupported input cannot yield a plausible measured envelope."""


def require(condition: bool, code: str) -> None:
    """Use named refusals instead of silently dropping unsupported geometry."""
    if not condition:
        raise MeasurementRefused(code)


def integer(value: Any, low: int, high: int) -> bool:
    """Reject booleans and counts outside explicit cold-tool limits."""
    return type(value) is int and low <= value <= high


def rational(value: Any) -> Fraction:
    """Capture the exact decoded binary value, not a rounded decimal approximation."""
    require(type(value) in (float, int) and abs(value) <= 1000000 and math.isfinite(value),
            "NONFINITE_OR_EXTREME_GEOMETRY")
    return Fraction(value)


def ceil_fraction(value: Fraction) -> int:
    """Exact upward rounding, including signed rational values."""
    return -(-value.numerator // value.denominator)


def norm_upper_um(values: list[Fraction]) -> int:
    """Exact rational squared norm followed by outward integer square root in micrometres."""
    squared = sum(v * v for v in values) * MICROMETRES * MICROMETRES
    floor_root = math.isqrt(squared.numerator // squared.denominator)
    return floor_root if floor_root * floor_root * squared.denominator == squared.numerator else floor_root + 1


def hash_bytes(data: bytes) -> str:
    """Hash the exact bytes the parser will consume, closing a read/hash race."""
    return hashlib.sha256(data).hexdigest()


def bounded_bytes(path: Path, capacity: int, refusal: str) -> bytes:
    """Bound the actual read, including a source growing after its directory entry was checked."""
    with path.open("rb") as stream:
        data = stream.read(capacity + 1)
    require(len(data) <= capacity, refusal)
    return data


class Source:
    """One finite GLB image, checked accessors and complete scene hierarchy."""

    def __init__(self, data: bytes, expected_sha256: str) -> None:
        require(len(data) <= MAX_FILE_BYTES and len(data) >= 28, "SOURCE_BYTE_CAPACITY")
        require(isinstance(expected_sha256, str) and bool(re.fullmatch(r"[0-9a-f]{64}", expected_sha256)),
                "SOURCE_HASH_FORMAT")
        require(hash_bytes(data) == expected_sha256, "SOURCE_HASH_MISMATCH")
        try:
            json_size = struct.unpack_from("<I", data, 12)[0]
            bin_offset = 20 + json_size
            require(json_size % 4 == 0 and bin_offset + 8 <= len(data), "GLB_CHUNK_BOUNDS")
            bin_size = struct.unpack_from("<I", data, bin_offset)[0]
            require(bin_size % 4 == 0 and bin_offset + 8 + bin_size == len(data), "GLB_CHUNK_BOUNDS")
            self.doc, self.binary = read_glb(data)
        except (RepairRefused, ValueError, KeyError, IndexError, TypeError, struct.error) as error:
            raise MeasurementRefused("GLB_FORMAT") from error
        self.sha256 = expected_sha256
        self.cache: dict[int, list[tuple]] = {}
        self.decoded_values = 0
        try:
            self._header()
            self.parents, self.order = self._hierarchy()
            self.channels = self._channels()
            self.parts = self._primitives()
        except (KeyError, IndexError, TypeError, AttributeError, struct.error) as error:
            raise MeasurementRefused("GLTF_STRUCTURE") from error

    def _header(self) -> None:
        """Refuse external buffers, morphs, extensions and unsupported transform semantics."""
        d = self.doc
        require(isinstance(d, dict) and d.get("asset", {}).get("version") == "2.0", "GLTF_VERSION")
        require(not d.get("extensionsRequired") and not d.get("extensionsUsed"), "EXTENSION_UNSUPPORTED")
        require(len(d.get("buffers", [])) == 1 and "uri" not in d["buffers"][0], "EXTERNAL_BUFFER")
        require(d["buffers"][0].get("byteLength") == len(self.binary), "BUFFER_LENGTH")
        require(0 < len(d.get("nodes", [])) <= MAX_NODES, "NODE_CAPACITY")
        require(len(d.get("animations", [])) == 1, "ONE_CLIP_REQUIRED")
        for node in d["nodes"]:
            require("matrix" not in node and "weights" not in node and not node.get("extensions"), "NODE_UNSUPPORTED")
            for key, default in (("translation", [0, 0, 0]), ("scale", [1, 1, 1]), ("rotation", [0, 0, 0, 1])):
                values = node.get(key, default)
                require(isinstance(values, list) and len(values) == len(default), "NODE_TRS_FORMAT")
                for value in values:
                    rational(value)
            require(sum(v * v for v in node.get("rotation", [0, 0, 0, 1])) > 0, "ZERO_ROTATION")

    def accessor(self, index: int, kind: str | None = None) -> list[tuple]:
        """Check byte and allocation bounds before using the existing project accessor reader."""
        require(integer(index, 0, len(self.doc.get("accessors", [])) - 1), "ACCESSOR_INDEX")
        a = self.doc["accessors"][index]
        require(not a.get("sparse") and a.get("type") in WIDTHS and a.get("componentType") in COMPONENTS,
                "ACCESSOR_UNSUPPORTED")
        require(kind is None or a["type"] == kind, "ACCESSOR_KIND")
        if index in self.cache:
            return self.cache[index]
        self._accessor_bounds(a)
        rows = read_accessor(self.doc, self.binary, index)
        for row in rows:
            for value in row:
                rational(value)
        self.cache[index] = rows
        return rows

    def _accessor_bounds(self, a: dict) -> None:
        """An accessor must lie inside its own buffer view, not merely somewhere in the BIN."""
        count, width = a.get("count"), WIDTHS[a["type"]]
        require(integer(count, 1, MAX_ACCESSOR_VALUES), "ACCESSOR_COUNT")
        self.decoded_values += count * width
        require(self.decoded_values <= MAX_ACCESSOR_VALUES, "ACCESSOR_VALUE_CAPACITY")
        require(integer(a.get("bufferView"), 0, len(self.doc.get("bufferViews", [])) - 1), "BUFFER_VIEW_INDEX")
        view = self.doc["bufferViews"][a["bufferView"]]
        size = COMPONENTS[a["componentType"]][1] * width
        stride, offset = view.get("byteStride", size), a.get("byteOffset", 0)
        start, length = view.get("byteOffset", 0), view.get("byteLength")
        require(view.get("buffer") == 0 and integer(start, 0, len(self.binary))
                and integer(length, 1, len(self.binary) - start), "BUFFER_VIEW_BOUNDS")
        require(integer(stride, size, 4096) and integer(offset, 0, length)
                and offset + (count - 1) * stride + size <= length, "ACCESSOR_BYTE_BOUNDS")
        # The shared reader normalizes integers with float division. Until a
        # rational decoder exists, that lost fraction cannot carry a zero-residual proof.
        require(not a.get("normalized"), "NORMALIZATION_UNSUPPORTED")

    def _hierarchy(self) -> tuple[dict[int, int], list[int]]:
        """Visit every node exactly once; cycles, shared children and omitted roots refuse."""
        nodes, parents = self.doc["nodes"], {}
        for parent, node in enumerate(nodes):
            for child in node.get("children", []):
                require(integer(child, 0, len(nodes) - 1) and child not in parents, "HIERARCHY_PARENT")
                parents[child] = parent
        roots = [i for i in range(len(nodes)) if i not in parents]
        scene = self.doc.get("scene", 0)
        require(integer(scene, 0, len(self.doc.get("scenes", [])) - 1), "SCENE_INDEX")
        require(sorted(self.doc["scenes"][scene].get("nodes", [])) == roots, "SCENE_OMITS_NODES")
        order, queue = [], list(roots)
        while queue:
            node = queue.pop(0)
            require(node not in order, "HIERARCHY_CYCLE")
            order.append(node)
            queue.extend(nodes[node].get("children", []))
        require(len(order) == len(nodes), "HIERARCHY_CYCLE")
        return parents, order

    def _channels(self) -> dict[int, dict[str, tuple]]:
        """Only linear or held TRS curves have the stated endpoint convexity proof."""
        animation, channels = self.doc["animations"][0], {}
        require(0 < len(animation.get("channels", [])) <= MAX_CHANNELS, "CHANNEL_CAPACITY")
        for channel in animation["channels"]:
            node, path = channel["target"].get("node"), channel["target"].get("path")
            require(integer(node, 0, len(self.doc["nodes"]) - 1) and path in ("translation", "rotation", "scale"),
                    "ANIMATION_TARGET_UNSUPPORTED")
            require(path not in channels.get(node, {}), "DUPLICATE_CHANNEL")
            samplers = animation.get("samplers", [])
            require(integer(channel.get("sampler"), 0, len(samplers) - 1), "SAMPLER_INDEX")
            sampler = samplers[channel["sampler"]]
            mode = sampler.get("interpolation", "LINEAR")
            require(mode in ("LINEAR", "STEP"), "INTERPOLATION_UNSUPPORTED")
            keys = [row[0] for row in self.accessor(sampler["input"], "SCALAR")]
            values = self.accessor(sampler["output"], "VEC4" if path == "rotation" else "VEC3")
            require(len(keys) == len(values) and 0 < len(keys) <= MAX_KEYS
                    and keys[0] >= 0 and all(a < b for a, b in zip(keys, keys[1:])), "ANIMATION_KEYS")
            require(path != "rotation" or all(sum(v * v for v in row) > 0 for row in values), "ZERO_ROTATION")
            channels.setdefault(node, {})[path] = (keys, values, mode)
        return channels

    def _primitives(self) -> list[dict]:
        """Include every embedded mesh primitive and every authored influence set, never a body subset."""
        parts, total = [], 0
        for node_id, node in enumerate(self.doc["nodes"]):
            if "mesh" not in node:
                continue
            require(integer(node["mesh"], 0, len(self.doc.get("meshes", [])) - 1), "MESH_INDEX")
            mesh = self.doc["meshes"][node["mesh"]]
            require(not mesh.get("weights"), "MORPH_UNSUPPORTED")
            for primitive_id, primitive in enumerate(mesh.get("primitives", [])):
                require(len(parts) < MAX_PRIMITIVES and not primitive.get("targets")
                        and not primitive.get("extensions"), "PRIMITIVE_UNSUPPORTED")
                position = self.accessor(primitive["attributes"]["POSITION"], "VEC3")
                total += len(position)
                require(total <= MAX_VERTICES, "VERTEX_CAPACITY")
                part = {"id": f"node:{node_id}/mesh:{node['mesh']}/primitive:{primitive_id}",
                        "node": node_id, "positions": position, "influences": [], "skin": None}
                self._bind_skin(part, primitive, node)
                parts.append(part)
        require(bool(parts), "NO_EMBEDDED_GEOMETRY")
        return parts

    def _bind_skin(self, part: dict, primitive: dict, node: dict) -> None:
        """Validate all joint/weight sets and inverse binds; missing pairs cannot disappear."""
        attrs = primitive["attributes"]
        joint_sets = sorted(k for k in attrs if k.startswith("JOINTS_"))
        weight_sets = sorted(k for k in attrs if k.startswith("WEIGHTS_"))
        require([s.replace("JOINTS_", "WEIGHTS_") for s in joint_sets] == weight_sets, "SKIN_SET_PAIR")
        if "skin" not in node:
            require(not joint_sets, "SKIN_UNBOUND")
            return
        require(bool(joint_sets) and integer(node["skin"], 0, len(self.doc.get("skins", [])) - 1), "SKIN_UNBOUND")
        skin = self.doc["skins"][node["skin"]]
        joints = skin.get("joints", [])
        require(bool(joints) and len(joints) <= MAX_NODES and len(set(joints)) == len(joints)
                and all(integer(j, 0, len(self.doc["nodes"]) - 1) for j in joints), "SKIN_JOINTS")
        binds = self.accessor(skin["inverseBindMatrices"], "MAT4") if "inverseBindMatrices" in skin else [IDENTITY] * len(joints)
        require(len(binds) == len(joints) and all(tuple(m[3::4]) == (0, 0, 0, 1) for m in binds), "INVERSE_BIND_FORMAT")
        part["skin"] = (joints, binds)
        for name in joint_sets:
            j = self.accessor(attrs[name], "VEC4")
            w = self.accessor(attrs[name.replace("JOINTS_", "WEIGHTS_")], "VEC4")
            require(len(j) == len(w) == len(part["positions"]), "SKIN_VERTEX_COUNT")
            require(all(all(integer(v, 0, len(joints) - 1) for v in row) for row in j), "SKIN_JOINT_INDEX")
            require(all(all(v >= 0 for v in row) for row in w), "SKIN_NEGATIVE_WEIGHT")
            part["influences"].append((j, w))


def hierarchy_bounds(source: Source) -> dict[int, tuple[Fraction, Fraction]]:
    """For every node derive ||world(p)|| <= A*||p|| + B with B in exact micrometres.

    Unit rotation preserves length. Raw stored quaternions also get an exact
    operator-norm allowance, avoiding a unit-length assumption about float32 keys.
    Linear/held translation norm and scale magnitude attain an upper bound among
    their keys (plus rest). Composition is A'=A*S*Q, B'=B+A*T; no samples participate.
    """
    result = {}
    for index in source.order:
        node, curves = source.doc["nodes"][index], source.channels.get(index, {})
        translations = [node.get("translation", [0, 0, 0])] + list(curves.get("translation", ([], [], ""))[1])
        scales = [node.get("scale", [1, 1, 1])] + list(curves.get("scale", ([], [], ""))[1])
        rotations = [node.get("rotation", [0, 0, 0, 1])] + list(curves.get("rotation", ([], [], ""))[1])
        t = max(norm_upper_um([rational(v) for v in row]) for row in translations)
        s = max(abs(rational(v)) for row in scales for v in row)
        # R(q) = |q|² R(q/|q|) + (1-|q|²)I. This also bounds raw linear
        # quaternion interpolation because its norm is bounded by endpoint norms.
        q = max(Fraction(1), *(2 * sum(rational(v) ** 2 for v in row) - 1 for row in rotations))
        a, b = result.get(source.parents.get(index), (Fraction(1), Fraction(0)))
        result[index] = (a * s * q, b + a * t)
        require(result[index][0] <= 1000000 and result[index][1] <= 2000000000000,
                "HIERARCHY_MAGNITUDE_CAPACITY")
    return result


def inverse_bound_radius(positions: list[tuple], matrix: list | tuple) -> int:
    """Bound the full primitive's inverse-bind image using exact affine interval arithmetic."""
    low = [rational(min(p[axis] for p in positions)) for axis in range(3)]
    high = [rational(max(p[axis] for p in positions)) for axis in range(3)]
    extent = []
    for axis in range(3):
        lo = hi = rational(matrix[12 + axis])
        for j in range(3):
            coefficient = rational(matrix[j * 4 + axis])
            x, y = coefficient * low[j], coefficient * high[j]
            lo, hi = lo + min(x, y), hi + max(x, y)
        extent.append(max(abs(lo), abs(hi)))
    return norm_upper_um(extent)


def continuous_radius(source: Source) -> tuple[int, list[dict]]:
    """Conservatively bound weighted skinning and every rigid attachment in the source image."""
    hierarchy, radius, records = hierarchy_bounds(source), 0, []
    for part in source.parts:
        if part["skin"] is None:
            a, b = hierarchy[part["node"]]
            bound = ceil_fraction(a * inverse_bound_radius(part["positions"], IDENTITY) + b)
        else:
            used, max_weight = set(), Fraction(1)
            for vertex in range(len(part["positions"])):
                weights = Fraction(0)
                for joints, values in part["influences"]:
                    for joint, weight in zip(joints[vertex], values[vertex]):
                        weights += rational(weight)
                        if weight > 0:
                            used.add(joint)
                require(weights > 0, "SKIN_ZERO_WEIGHT")
                max_weight = max(max_weight, weights)
            joints, binds = part["skin"]
            bounds = [hierarchy[joints[j]][0] * inverse_bound_radius(part["positions"], binds[j])
                      + hierarchy[joints[j]][1] for j in sorted(used)]
            bound = ceil_fraction(max(bounds) * max_weight)
        radius = max(radius, bound)
        records.append({"id": part["id"], "vertices": len(part["positions"]),
                        "skinned": part["skin"] is not None, "continuous_radius_micrometres": bound})
    return radius, records


def sample_curve(curve: tuple, time: float, rotation: bool) -> list[float]:
    """Diagnostic interpolation: held values or linear vectors/shortest unit-quaternion slerp."""
    keys, values, mode = curve
    index = max(0, min(bisect.bisect_right(keys, time) - 1, len(keys) - 1))
    a = list(values[index])
    if rotation:
        norm = math.sqrt(sum(v * v for v in a))
        a = [v / norm for v in a]
    if index == len(keys) - 1 or time <= keys[0] or mode == "STEP":
        return a
    b, u = list(values[index + 1]), (time - keys[index]) / (keys[index + 1] - keys[index])
    if not rotation:
        return [x + (y - x) * u for x, y in zip(a, b)]
    norm = math.sqrt(sum(v * v for v in b))
    b = [v / norm for v in b]
    dot = sum(x * y for x, y in zip(a, b))
    if dot < 0:
        b, dot = [-v for v in b], -dot
    theta = math.acos(min(dot, 1.))
    if theta < 1e-8:
        return a
    return [(x * math.sin((1 - u) * theta) + y * math.sin(u * theta)) / math.sin(theta) for x, y in zip(a, b)]


def pose_worlds(source: Source, time: float) -> dict[int, list[float]]:
    """Sample all node transforms for diagnostics; the continuous proof does not depend on this."""
    worlds = {}
    for index in source.order:
        node = dict(source.doc["nodes"][index])
        for path, curve in source.channels.get(index, {}).items():
            node[path] = sample_curve(curve, time, path == "rotation")
        if "rotation" in node:
            norm = math.sqrt(sum(v * v for v in node["rotation"]))
            node["rotation"] = [v / norm for v in node["rotation"]]
        worlds[index] = mat_mul(worlds.get(source.parents.get(index), IDENTITY), trs_matrix(node))
    return worlds


def sample_bounds(source: Source, limit: int) -> dict:
    """Measure all vertices at a finite explicit pose list; never label this continuous coverage."""
    require(integer(limit, 1, MAX_SAMPLE_POSES), "SAMPLE_CAPACITY")
    timeline = sorted({t for paths in source.channels.values() for curve in paths.values() for t in curve[0]})
    count = min(limit, len(timeline))
    times = [timeline[i * (len(timeline) - 1) // max(1, count - 1)] for i in range(count)]
    low, high = [math.inf] * 3, [-math.inf] * 3
    for time in times:
        worlds = pose_worlds(source, time)
        for part in source.parts:
            matrices = None
            if part["skin"]:
                joints, binds = part["skin"]
                matrices = [mat_mul(worlds[j], bind) for j, bind in zip(joints, binds)]
            for vertex, position in enumerate(part["positions"]):
                point = sampled_vertex(part, vertex, position, worlds, matrices)
                low = [min(a, b) for a, b in zip(low, point)]
                high = [max(a, b) for a, b in zip(high, point)]
    return {"status": "SAMPLED_DIAGNOSTIC_NOT_CONTINUOUS", "sample_times_seconds": times,
            "bounds_micrometres": {axis: [math.floor(low[i] * MICROMETRES), math.ceil(high[i] * MICROMETRES)]
                                    for i, axis in enumerate("xyz")}}


def sampled_vertex(part: dict, vertex: int, position: tuple, worlds: dict, matrices: list | None) -> list[float]:
    """Apply every skinning influence, or the actual rigid node transform for attachments."""
    if matrices is None:
        return transform_point(worlds[part["node"]], position)
    point = [0., 0., 0.]
    for joints, weights in part["influences"]:
        for joint, weight in zip(joints[vertex], weights[vertex]):
            if weight > 0:
                posed = transform_point(matrices[joint], position)
                for axis in range(3):
                    point[axis] += weight * posed[axis]
    return point


def coverage_refusals(evidence: dict, requirements: dict) -> list[str]:
    """Report omitted states/parts/attachments and uncovered residual; never create a mode permission."""
    errors = []
    required_states = set(requirements.get("states", STATES))
    if not required_states.issubset(set(STATES)) or required_states != set(STATES):
        errors.append("REQUIRED_STATE_SET_INCOMPLETE")
    if set(evidence.get("qualified_states", [])) != set(STATES):
        errors.append("LEGAL_STATE_MAPPING_INCOMPLETE")
    if set(evidence.get("included_primitives", [])) != set(requirements.get("embedded_primitives", [])):
        errors.append("EMBEDDED_GEOMETRY_OMITTED")
    if not set(requirements.get("external_attachments", [])).issubset(evidence.get("included_external_attachments", [])):
        errors.append("EXTERNAL_ATTACHMENT_OMITTED")
    residual, margin = evidence.get("residual_error_units"), requirements.get("margin_units")
    if not integer(residual, 0, 2147483647) or not isinstance(margin, dict) or set(margin) != set("xyz"):
        errors.append("ERROR_OR_MARGIN_UNAUTHORED")
    elif any(not integer(v, residual, 2147483647) for v in margin.values()):
        errors.append("UNCOVERED_INTERPOLATION_ERROR")
    if not requirements.get("source_asset_approved"):
        errors.append("SOURCE_ASSET_ACCEPTANCE_MISSING")
    errors.append("RUNTIME_PROFILE_OWNER_BINDING_MISSING")
    return errors


def measure_bytes(data: bytes, expected_sha256: str, sample_limit: int = 9) -> dict:
    """Produce actual source measurements with explicit partial scope and immutable-source proof."""
    source = Source(data, expected_sha256)
    radius, parts = continuous_radius(source)
    bounds = {axis: [-radius, radius] for axis in "xyz"}
    quantized = {axis: list(quantize_axis_units(-radius, radius, 0)) for axis in "xyz"}
    require(all(-2147483648 <= value <= 2147483647 for pair in quantized.values() for value in pair),
            "QUANTIZED_BOUND_OUT_OF_INT32")
    sampled = sample_bounds(source, sample_limit)
    evidence = {"qualified_states": [], "included_primitives": [p["id"] for p in parts],
                "included_external_attachments": [], "residual_error_units": 0}
    requirements = {"states": list(STATES), "embedded_primitives": evidence["included_primitives"],
                    "external_attachments": ["actual_equipped_gear", "actual_carried_cargo", "runtime_support_attachments"],
                    "margin_units": None, "source_asset_approved": False}
    return {"data_class": "measurement", "status": "PARTIAL_SOURCE_GEOMETRY", "admission_qualified": False,
            "sha256": source.sha256, "bytes": len(data), "parts": parts,
            "target_envelope_schema": 2, "source_transform": "identity; no anatomical rescale or reorientation",
            "space": "source model root; intended +Y up/-Z forward, facing not qualified; excludes gameplay root trajectory",
            "continuous_bounds_micrometres": bounds, "outward_diagnostic_bounds_u_no_safety_margin": quantized,
            "certificate": {"method": "exact_rational_hierarchy_sphere_v1", "residual_error_units": 0,
                            "rotation_scope": "all unit rotations plus exact raw-key norm allowance; LINEAR/STEP translation and scale enclosure",
                            "arithmetic": "exact decoded values as rationals; outward integer square roots and ceilings",
                            "scope": "mathematical source TRS and skinning only; not runtime deformation or GPU numeric error"},
            "sampled": sampled, "coverage": evidence, "requirements": requirements,
            "not_ready_reasons": coverage_refusals(evidence, requirements)
                + ["FACING_AND_ROOT_BINDING_UNQUALIFIED", "RUNTIME_DEFORMATION_AND_NUMERIC_ERROR_UNQUALIFIED"]}


def measure_file(path: Path, expected_sha256: str, sample_limit: int = 9) -> dict:
    """Read one bounded immutable image; no importer, engine or source mutation is invoked."""
    require(path.is_file(), "SOURCE_MISSING_OR_OVERSIZE")
    return measure_bytes(bounded_bytes(path, MAX_FILE_BYTES, "SOURCE_BYTE_CAPACITY"), expected_sha256, sample_limit)


def measure_library(asset_root: Path, manifest: Path, sample_limit: int) -> dict:
    """Measure the five approved-height cast examples and explicitly list unavailable matching clips."""
    data = bounded_bytes(manifest, 4 * 1024 * 1024, "MANIFEST_CAPACITY")
    rows = json.loads(data)["clips"]
    require(isinstance(rows, list) and len(rows) <= 10000, "MANIFEST_RECORD_CAPACITY")
    index = {(r["key"], r["clip"]): r for r in rows}
    require(len(index) == len(rows), "MANIFEST_DUPLICATE")
    results, missing = [], []
    for cast in CAST:
        for clip in CLIPS:
            relative = Path("creature") / cast / "grounded" / (clip + ".glb")
            path = asset_root / relative
            require(path.resolve().is_relative_to(asset_root.resolve()), "SOURCE_PATH_ESCAPE")
            if (cast, clip) not in index or not path.is_file():
                require(clip != "anim_walk", "REQUIRED_WALK_SOURCE_MISSING")
                missing.append(str(relative))
                continue
            print(f"measuring {cast}/{clip}", flush=True)
            record = measure_file(path, index[cast, clip]["output_sha256"], sample_limit)
            record.update({"cast_key": cast, "clip": clip, "source": str(relative)})
            results.append(record)
    tooling = [Path(__file__), Path(__file__).with_name("repair_meshy_rig.py"),
               Path(__file__).with_name("rig_meshy_tail.py"), Path(__file__).with_name("validate_movement_envelopes.py")]
    return {"schema": "redwall.underground.source_measurement/1", "envelope_contract_version": 2,
            "admission_qualified": False, "manifest_sha256": hash_bytes(data),
            "tool_sha256": {p.name: hash_bytes(p.read_bytes()) for p in tooling},
            "record_count": len(results), "missing_optional_sources": missing, "records": results}


def main() -> int:
    """Exit success means measurements were produced, never that a production profile qualified."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--asset-root", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--sample-poses", type=int, default=9)
    args = parser.parse_args()
    try:
        require(not args.output.resolve().is_relative_to(args.asset_root.resolve()), "OUTPUT_INSIDE_SOURCE_LIBRARY")
        require(args.output.resolve() != args.manifest.resolve(), "OUTPUT_OVERWRITES_SOURCE_MANIFEST")
        report = measure_library(args.asset_root, args.manifest, args.sample_poses)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
        print(f"measurement: {report['record_count']} source(s), 0 production-qualified profile(s); "
              f"{len(report['missing_optional_sources'])} missing optional source(s)")
        return 0
    except (MeasurementRefused, EnvelopeRefusal, OSError, ValueError, KeyError, IndexError, TypeError) as error:
        print(f"measurement refused: {error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
