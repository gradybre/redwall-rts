#!/usr/bin/env python3
"""Adversarial exact-math and native-source format checks; all fixtures are synthetic."""
from fractions import Fraction
import hashlib
import io
import json
import math
import struct
import tempfile
import unittest
from pathlib import Path

import export_underground_envelopes as e


def palette_fixture(attachment=False, bad_frame=False, footer=True, weight=1.0, matrix_value=None,
                    compressed=False, bounds=True, omitted_attachment=False, format_override=None, grounding=None,
                    attachment_key="fruit", held_binding=None, reported_binding=None, clip="walk"):
    """Tiny synthetic finite representation; no native source state or policy is implied."""
    out = io.BytesIO()
    def u(value): out.write(struct.pack("<I", value))
    def text(value):
        data = json.dumps(value).encode(); u(len(data)); out.write(data)
    identity = [1., 0., 0., 0., 1., 0., 0., 0., 1., 0., 0., 0.]
    case = dict(id="synthetic", cast="fixture", species="mouse", life_stage="synthetic",
                clip=clip, scenario="plain", attachments=[attachment_key] if attachment else [])
    if held_binding is not None:
        case["held_tool_binding"] = held_binding
    out.write(b"UGPAL001"); u(2 if grounding is not None else 1); text({"cases": [case], "grounding_schema": 1}); u(1)
    u(0x43415345)
    actual = dict(case, parts=1+int(attachment and not omitted_attachment), body_parts=1,
                  frames=2, sample_hz=30, source_duration_s=1/30)
    if reported_binding is not None:
        actual["held_tool_binding"] = reported_binding
    text(actual)
    for index in range(1+int(attachment and not omitted_attachment)):
        format_value = (1 << 35) | 1 | ((3 << 10) if index == 0 else 0)
        if compressed and index > 0: format_value |= 1 << 29
        if format_override is not None: format_value = format_override
        part = dict(kind="body" if index == 0 else "attachment", name="Body" if index == 0 else attachment_key,
                    binds=1 if index == 0 else 0, surfaces=1, surface_formats=[format_value])
        if bounds: part["mesh_aabb"] = [-1., -1., -1., 2., 2., 2.]
        text(part); u(1); u(4 if index == 0 else 0)
        out.write(struct.pack("<3f", .1, -.2, .3))
        if index == 0:
            for w in [weight, 0., 0., 0.]:
                u(0); out.write(struct.pack("<f", w))
    for frame in range(2):
        u(0x4652414d); u(0 if bad_frame else frame)
        if grounding is not None: out.write(struct.pack("<f", grounding[frame]))
        for _ in range(1+int(attachment and not omitted_attachment)):
            matrix = list(identity); matrix[9] = float(frame * 2)
            if matrix_value is not None: matrix[0] = matrix_value
            out.write(struct.pack("<12f", *matrix))
    u(0x454e4443); u(2)
    if footer: u(0x444f4e45); u(1); u(2)
    return out.getvalue()


class FinitePalette(unittest.TestCase):
    def read(self, data, digest=None):
        return list(e.PaletteSource(io.BytesIO(data), digest or hashlib.sha256(data).hexdigest()).cases())

    def test_complete_finite_content_is_not_a_live_animation_certificate(self):
        case = self.read(palette_fixture(attachment=True))[0]
        self.assertEqual(case["matrices"].shape, (2, 2, 12))
        self.assertEqual([p["name"] for p in case["geometry"]], ["Body", "fruit"])
        self.assertNotIn("production_qualified", case)

    def test_consumed_source_hash_and_complete_frame_census_are_mandatory(self):
        data = palette_fixture()
        with self.assertRaisesRegex(e.Refused, "SOURCE_HASH_MISMATCH"):
            self.read(data, "0"*64)
        with self.assertRaisesRegex(e.Refused, "PALETTE_FRAME_ORDER"):
            self.read(palette_fixture(bad_frame=True))
        with self.assertRaises(e.Refused): self.read(palette_fixture(footer=False))
        with self.assertRaisesRegex(e.Refused, "PALETTE_TRAILING_BYTES"):
            self.read(data+b"\0")

    def test_omitted_attachment_is_not_a_successful_body_only_certificate(self):
        with self.assertRaisesRegex(e.Refused, "PALETTE_ATTACHMENT_CENSUS"):
            self.read(palette_fixture(attachment=True, omitted_attachment=True))

    def test_persistent_tool_has_exact_explicit_clip_and_attachment_source_binding(self):
        for clip in ("idle", "walk", "cautious_crouch_walk_forward"):
            case = self.read(palette_fixture(attachment=True, attachment_key="mole_pick",
                held_binding="set_work_tool", clip=clip))[0]
            self.assertEqual(case["held_tool_binding"], "set_work_tool")
            self.assertEqual(case["geometry"][1]["name"], "mole_pick")
        for override in ({"attachment_key": "fruit"}, {"clip": "carry_heavy_object_walk"},
                         {"clip": "heavy_hammer_swing"}, {"held_binding": "different"},
                         {"reported_binding": "demo_clip_specific"}):
            kwargs = dict(attachment=True, attachment_key="mole_pick", held_binding="set_work_tool")
            kwargs.update(override)
            with self.assertRaisesRegex(e.Refused, "HELD_TOOL_BINDING"):
                self.read(palette_fixture(**kwargs))
        with self.assertRaisesRegex(e.Refused, "HELD_TOOL_BINDING"):
            self.read(palette_fixture(reported_binding="set_work_tool"))

    def test_nonfinite_and_zero_weight_cannot_enter_the_convex_proof(self):
        for weight in (-.1, 0., math.inf, math.nan):
            with self.assertRaisesRegex(e.Refused, "PALETTE_INFLUENCE"):
                self.read(palette_fixture(weight=weight))
        for value in (math.inf, math.nan, 1025.):
            with self.assertRaisesRegex(e.Refused, "PALETTE_MATRIX"):
                self.read(palette_fixture(matrix_value=value))

    def test_every_positive_temporal_and_transition_blend_fits_the_endpoint_hull(self):
        import numpy as np
        case = self.read(palette_fixture())[0]
        part = case["geometry"][0]
        bounds, residual = e.palette_part_envelope(part, case["matrices"])
        self.assertGreater(residual, 0)
        point = part["geometry"][0]["points"][0].astype(np.float64)
        # Four contributors, with actual fixed-weight CPU blending and final float32 conversion.
        for t in (0, 1, 32767, 32768, 65535, 65536):
            for u in (0, 16384, 49152, 65536):
                for transition in (0, 1, 32768, 65535, 65536):
                    a, b = case["matrices"][:, 0].astype(np.float64)
                    now = a*(1-t/65536)+b*(t/65536)
                    old = b*(1-u/65536)+a*(u/65536)
                    matrix = (old*(1-transition/65536)+now*(transition/65536)).astype(np.float32)
                    actual = matrix[:9].reshape(3,3).T.astype(np.float64) @ point + matrix[9:]
                    for axis in range(3):
                        self.assertLessEqual(Fraction(bounds[axis].low, e.FIXED), Fraction(float(actual[axis])))
                        self.assertGreaterEqual(Fraction(bounds[axis].high, e.FIXED), Fraction(float(actual[axis])))

    def test_compressed_gpu_decode_needs_its_actual_source_bound(self):
        case = self.read(palette_fixture(attachment=True, compressed=True, bounds=False))[0]
        with self.assertRaisesRegex(e.Refused, "PALETTE_COMPRESSED_BOUND_MISSING"):
            e.palette_part_envelope(case["geometry"][1], case["matrices"][:, 1:2])
        known = self.read(palette_fixture(attachment=True, compressed=True))[0]
        plain = self.read(palette_fixture(attachment=True))[0]
        compressed_error = e.palette_residual(known["geometry"][1], known["matrices"][:, 1:2])
        plain_error = e.palette_residual(plain["geometry"][1], plain["matrices"][:, 1:2])
        self.assertGreater(compressed_error, plain_error)
        self.assertGreater(plain_error, Fraction(1, 1 << 24))

    def test_static_attachment_and_below_root_vertices_keep_their_own_matrices(self):
        case = self.read(palette_fixture(attachment=True))[0]
        bounds, residual = e.palette_part_envelope(case["geometry"][1], case["matrices"][:, 1:2])
        self.assertLess(e.units(bounds)[1], 0)
        self.assertGreater(e.units(bounds)[3], 2*1024)
        self.assertGreater(residual, 0)

    def test_no_arbitrary_report_margin_can_replace_derived_arithmetic_residual(self):
        case = self.read(palette_fixture())[0]
        part = case["geometry"][0]
        baseline = e.palette_residual(part, case["matrices"])
        part["claimed_residual_m"] = 0
        self.assertEqual(e.palette_residual(part, case["matrices"]), baseline)
        larger = case["matrices"].copy(); larger[:, :, 0] = 8
        self.assertGreater(e.palette_residual(part, larger), baseline)
        with self.assertRaises(e.Refused): e.gamma32(1025)

    def test_glsl_directed_rounding_and_actual_backend_are_explicit(self):
        self.assertEqual(e.gamma32(1), Fraction(1, (1 << 23)-1))
        backend = {"engine": {"major": 4, "minor": 7, "patch": 2, "hash": e.GODOT_SOURCE_HASH,
                              "build": "official", "status": "stable"}, "rendering_driver": "opengl3",
                   "rendering_method": "gl_compatibility", "display_server": "macOS", "api_version": "4.1 Metal"}
        self.assertEqual(e.palette_backend_certificate(backend)["driver"], "opengl3")
        for key, value in (("rendering_driver", "vulkan"), ("display_server", "headless"),
                           ("api_version", "OpenGL ES 3.2"), ("api_version", "3.3"), ("engine", {})):
            with self.assertRaises(e.Refused): e.palette_backend_certificate(dict(backend, **{key: value}))
        for key, value in (("hash", "different-build"), ("status", "dev"), ("build", "custom")):
            with self.assertRaisesRegex(e.Refused, "ENGINE_SOURCE_UNREVIEWED"):
                e.palette_backend_certificate(dict(backend, engine=dict(backend["engine"], **{key: value})))

    def test_actual_skin_flags_must_match_the_proved_equation(self):
        known = (1 << 35) | 1 | (3 << 10)
        for flag in (1 << 25, 1 << 28, 1 << 29):
            with self.assertRaises(e.Refused): self.read(palette_fixture(format_override=known | flag))
        with self.assertRaisesRegex(e.Refused, "SKIN_FORMAT"):
            self.read(palette_fixture(format_override=known | (1 << 27)))
        with self.assertRaisesRegex(e.Refused, "SKIN_FORMAT"):
            self.read(palette_fixture(format_override=1))

    def test_common_post_skin_grounding_is_not_multiplied_by_nonunit_skin_weights(self):
        case = self.read(palette_fixture(weight=.5, attachment=True, grounding=(.2, .4)))[0]
        body, _ = e.palette_part_envelope(case["geometry"][0], case["matrices"][:, :1], case["grounding"])
        item, _ = e.palette_part_envelope(case["geometry"][1], case["matrices"][:, 1:], case["grounding"])
        self.assertLessEqual(e.units(body)[1], 102)
        self.assertGreaterEqual(e.units(body)[4], 308)
        self.assertGreater(e.units(body)[1], 100)  # Wrong bone-wise shift would reach zero.
        self.assertLessEqual(e.units(item)[1], 0)
        self.assertGreaterEqual(e.units(item)[4], 205)

    def test_grounded_transition_hull_covers_all_four_coupled_matrix_and_root_weights(self):
        import numpy as np
        case = self.read(palette_fixture(weight=.5, grounding=(.25, -.5)))[0]
        part = case["geometry"][0]
        bounds, residual = e.palette_part_envelope(part, case["matrices"], case["grounding"])
        self.assertGreater(residual, e.palette_residual(part, case["matrices"]))
        points = part["geometry"][0]["points"][0].astype(np.float64)
        for t in (0, 1, 16384, 32768, 65535, 65536):
            for u in (0, 32768, 65536):
                for b in (0, 16384, 65536):
                    weights = np.array([(1-u/65536)*(1-b/65536)+t/65536*b/65536,
                                        u/65536*(1-b/65536)+(1-t/65536)*b/65536])
                    matrix = np.sum(case["matrices"][:, 0].astype(np.float64)*weights[:, None], axis=0).astype(np.float32)
                    root = np.float32(np.sum(case["grounding"].astype(np.float64)*weights))
                    actual = (matrix[:9].reshape(3, 3).T @ points+matrix[9:])*.5
                    actual[1] += root
                    for axis in range(3):
                        self.assertLessEqual(Fraction(bounds[axis].low, e.FIXED), Fraction(float(actual[axis])))
                        self.assertGreaterEqual(Fraction(bounds[axis].high, e.FIXED), Fraction(float(actual[axis])))

    def test_grounding_source_rejects_missing_nonfinite_or_excessive_values(self):
        for value in (math.nan, math.inf, -math.inf, 1025.):
            with self.assertRaisesRegex(e.Refused, "PALETTE_GROUNDING"):
                self.read(palette_fixture(grounding=(0, value)))
        case = self.read(palette_fixture())[0]
        with self.assertRaisesRegex(e.Refused, "PALETTE_GROUNDING"):
            e.palette_part_envelope(case["geometry"][0], case["matrices"], [0])

    def test_missing_changed_or_conflicting_sources_refuse_reproduction(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)/"fixture-only-source"
            path.write_bytes(b"synthetic native input")
            pin = {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
            metadata = {"manifest": pin, "sources": [pin]}
            self.assertEqual(e.verify_palette_sources(metadata), 1)
            resource = dict(pin, path="res://fixture-only-source")
            self.assertEqual(e.verify_palette_sources({"manifest": resource, "sources": [pin]}, Path(directory)), 1)
            with self.assertRaisesRegex(e.Refused, "RESOURCE_PATH"):
                e.verify_palette_sources({"manifest": dict(pin, path="res://../escaped"), "sources": [pin]}, Path(directory))
            conflict = dict(pin, sha256="0"*64)
            with self.assertRaisesRegex(e.Refused, "CONFLICTING_PIN"):
                e.verify_palette_sources(dict(metadata, sources=[conflict]))
            path.write_bytes(b"changed input")
            with self.assertRaisesRegex(e.Refused, "SOURCE_DRIFT"): e.verify_palette_sources(metadata)
            path.unlink()
            with self.assertRaisesRegex(e.Refused, "SOURCE_MISSING"): e.verify_palette_sources(metadata)

    def test_preserved_import_bytes_do_not_waive_asset_or_script_source_drift(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            asset = root / "actual-asset"; asset.write_bytes(b"actual frozen asset")
            cache = root / ".godot/imported/native.scn"; cache.parent.mkdir(parents=True)
            cache.write_bytes(b"frozen imported bytes")
            def pin(path): return {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
            source_pin = pin(asset)
            cache_pin = dict(pin(cache), path="res://.godot/imported/native.scn")
            metadata = {"manifest": source_pin, "sources": [source_pin, cache_pin]}
            archive = root / "archive"; archive.mkdir()
            saved = archive / (cache_pin["sha256"] + ".input"); saved.write_bytes(cache.read_bytes())
            cache.write_bytes(b"regenerated imported identity")
            with self.assertRaisesRegex(e.Refused, "SOURCE_DRIFT"): e.verify_palette_sources(metadata, root)
            self.assertEqual(e.verify_palette_sources(metadata, root, archive), 2)
            asset.write_bytes(b"different geometry")
            with self.assertRaisesRegex(e.Refused, "SOURCE_DRIFT"): e.verify_palette_sources(metadata, root, archive)
            asset.write_bytes(b"actual frozen asset")
            saved.write_bytes(b"not the same image")
            with self.assertRaisesRegex(e.Refused, "SOURCE_DRIFT"): e.verify_palette_sources(metadata, root, archive)
            saved.unlink()
            with self.assertRaisesRegex(e.Refused, "ARCHIVE_MISSING"): e.verify_palette_sources(metadata, root, archive)

    def test_import_metadata_archive_is_exact_and_cannot_substitute_the_glb(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            raw = root / "demo/assets/body.glb"; raw.parent.mkdir(parents=True)
            raw.write_bytes(b"actual pinned raw mesh")
            imported = raw.with_suffix(".glb.import"); imported.write_bytes(b"frozen imported resource identity")
            def pin(path):
                return {"path": "res://" + str(path.relative_to(root)),
                        "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
            raw_pin, import_pin = pin(raw), pin(imported)
            metadata = {"manifest": raw_pin, "sources": [raw_pin, import_pin]}
            archive = root / "archive"; archive.mkdir()
            (archive / (import_pin["sha256"] + ".input")).write_bytes(imported.read_bytes())
            imported.write_bytes(b"new generated metadata after clean import")
            self.assertEqual(e.verify_palette_sources(metadata, root, archive), 2)
            with self.assertRaisesRegex(e.Refused, "SOURCE_DRIFT"): e.verify_palette_sources(metadata, root)
            (archive / (raw_pin["sha256"] + ".input")).write_bytes(raw.read_bytes())
            raw.write_bytes(b"different actual mesh")
            with self.assertRaisesRegex(e.Refused, "SOURCE_DRIFT"): e.verify_palette_sources(metadata, root, archive)


def world_basis_fixture(override=None, footer=True, producer="a"*64, backend="opengl3"):
    """Complete synthetic finite coefficient source; source-math tests do not claim native provenance."""
    metadata = {"engine": {"major": 4, "minor": 7, "patch": 2, "hash": e.GODOT_SOURCE_HASH,
        "build": "official", "status": "stable"}, "rendering_driver": backend,
        "rendering_method": "gl_compatibility", "display_server": "macOS", "api_version": "4.1 fixture",
        "source": {"sha256": producer}, "claimed_max_norm_squared": 1}
    raw = json.dumps(metadata).encode()
    out = io.BytesIO()
    out.write(b"UGYAW001" + struct.pack("<III", 1, 65536, len(raw)) + raw)
    for yaw in range(65536):
        values = (math.cos(yaw*math.tau/65536), math.sin(yaw*math.tau/65536))
        if override is not None and yaw == 32769:
            values = override
        out.write(struct.pack("<ff", *values))
    if footer:
        out.write(b"UGYEND01")
    return out.getvalue()


class FiniteWorldModel(unittest.TestCase):
    ROOTS = [0, -32256, 0, 262144, 16896, 262144]

    @staticmethod
    def source(data=None, digest=None):
        data = data if data is not None else world_basis_fixture()
        return e.WorldBasisSource(io.BytesIO(data), digest or hashlib.sha256(data).hexdigest(), "a"*64)

    def test_entire_native_table_not_the_reported_norm_controls_the_radial_bound(self):
        # The source's deliberately false diagnostic norm=1 cannot overwrite the exact row proof.
        basis = self.source(world_basis_fixture(override=(1, 0.5)))
        self.assertEqual(basis.norm_squared, Fraction(5, 4))
        self.assertEqual(basis.max_norm_yaw, 32769)
        self.assertEqual(basis.certificate()["heading_count"], 65536)
        bound = e.native_all_yaw(e.vector([3., -.01, 4.]), basis.norm_squared)
        self.assertGreater(bound[0].high, 5*e.FIXED)
        self.assertEqual(bound[1], e.Interval.exact(-.01))
        self.assertGreaterEqual(Fraction(bound[0].high, e.FIXED)**2, Fraction(125, 4))

    def test_complete_hash_footer_rows_backend_and_producer_are_mandatory(self):
        data = world_basis_fixture()
        with self.assertRaisesRegex(e.Refused, "WORLD_BASIS_DIGEST"):
            self.source(data, "0"*64)
        for raw in (data[:-1], data+b"hidden", world_basis_fixture(footer=False)):
            with self.assertRaises(e.Refused):
                self.source(raw)
        for pair in ((math.nan, 0), (math.inf, 0), (1.001, 0), (0, -1.001)):
            with self.assertRaisesRegex(e.Refused, "COEFFICIENT"):
                self.source(world_basis_fixture(override=pair))
        with self.assertRaisesRegex(e.Refused, "PRODUCER"):
            self.source(world_basis_fixture(producer="b"*64))
        with self.assertRaisesRegex(e.Refused, "BACKEND"):
            self.source(world_basis_fixture(backend="vulkan"))

    def test_only_finite_exact_root_domain_and_explicit_grounding_can_receive_a_certificate(self):
        self.assertEqual(e.world_root_bounds(self.ROOTS), (Fraction(256), Fraction(63, 2), Fraction(256)))
        for values in (None, [0]*6, [False, 0, 0, 1, 1, 1], [0, 0, 0, (1 << 24)+1, 1, 1]):
            with self.assertRaises(e.Refused):
                e.world_root_bounds(values)
        raw = palette_fixture()
        case = list(e.PaletteSource(io.BytesIO(raw), hashlib.sha256(raw).hexdigest()).cases())[0]
        local, _ = e.palette_part_envelope(case["geometry"][0], case["matrices"])
        with self.assertRaisesRegex(e.Refused, "GROUNDING_REQUIRED"):
            e.world_residual(case["geometry"][0], case["matrices"], None, local, self.ROOTS)

    @staticmethod
    def draw(matrix, point):
        """Independent scalar float32 affine emulation; no exporter interval operations are reused."""
        import numpy as np
        result = []
        for axis in range(3):
            value = np.float32(matrix[axis]*point[0])
            value = np.float32(value + np.float32(matrix[axis+3]*point[1]))
            value = np.float32(value + np.float32(matrix[axis+6]*point[2]))
            result.append(np.float32(value+matrix[axis+9]))
        return np.array(result, dtype=np.float32)

    @staticmethod
    def compose(matrix, g, root, c, s):
        """The reviewed Actor uses these double scalar operations followed by a native Vector3 store."""
        import numpy as np
        out = matrix.astype(np.float64).copy()
        for column in range(4):
            x, y, z = out[3*column:3*column+3].copy()
            out[3*column:3*column+3] = [c*x+s*z, y, -s*x+c*z]
        out[9:] += root.astype(np.float64)/1024
        out[10] += float(g)
        return out.astype(np.float32)

    def test_actual_scalar_world_paths_fit_for_all_root_corners_blends_body_and_attachment(self):
        import itertools
        import numpy as np
        basis = self.source()
        raw = palette_fixture(attachment=True, grounding=(.25, -.5), weight=.5)
        case = list(e.PaletteSource(io.BytesIO(raw), hashlib.sha256(raw).hexdigest()).cases())[0]
        roots = list(itertools.product((0, 262143), (-32256, 16895), (0, 262143)))
        for index, part in enumerate(case["geometry"]):
            matrices = case["matrices"][:, index:index+1]
            bounds, errors = e.world_part_envelope(part, matrices, case["grounding"], basis, self.ROOTS)
            self.assertTrue(all(value["numerator"] > 0 for value in errors))
            point = part["geometry"][0]["points"][0]
            for weight, yaw, origin in itertools.product((0, 1, 16384, 32768, 65535, 65536),
                                                         (0, 1, 16384, 32769, 65535), roots):
                t = weight/65536
                matrix = (matrices[0, 0].astype(np.float64)*(1-t)+matrices[1, 0].astype(np.float64)*t).astype(np.float32)
                grounding = np.float32(float(case["grounding"][0])*(1-t)+float(case["grounding"][1])*t)
                c, s = (float(v) for v in np.array([math.cos(yaw*math.tau/65536), math.sin(yaw*math.tau/65536)], dtype=np.float32))
                root = np.array(origin, dtype=np.int32)
                if part["binds"]:
                    local = self.draw((matrix*np.float32(.5)).astype(np.float32), point)
                    identity = np.array([1,0,0,0,1,0,0,0,1,0,0,0], dtype=np.float32)
                    actual = self.draw(self.compose(identity, grounding, root, c, s), local)
                else:
                    actual = self.draw(self.compose(matrix, grounding, root, c, s), point)
                for axis in range(3):
                    relative = Fraction(float(actual[axis])) - Fraction(int(root[axis]), 1024)
                    self.assertLessEqual(Fraction(bounds[axis].low, e.FIXED), relative)
                    self.assertGreaterEqual(Fraction(bounds[axis].high, e.FIXED), relative)

    def test_world_residual_is_source_and_root_derived_never_a_claimed_margin(self):
        raw = palette_fixture(attachment=True, compressed=True, grounding=(.25, .5))
        case = list(e.PaletteSource(io.BytesIO(raw), hashlib.sha256(raw).hexdigest()).cases())[0]
        part, matrices = case["geometry"][1], case["matrices"][:, 1:]
        local, _ = e.palette_part_envelope(part, matrices, case["grounding"])
        first = e.world_residual(part, matrices, case["grounding"], local, [-1, -1, -1, 1, 1, 1])
        second = e.world_residual(part, matrices, case["grounding"], local, self.ROOTS)
        self.assertTrue(all(b > a for a, b in zip(first, second)))
        part["claimed_world_error_m"] = 0
        self.assertEqual(second, e.world_residual(part, matrices, case["grounding"], local, self.ROOTS))
        del part["mesh_aabb"]
        with self.assertRaises(e.Refused):
            e.world_residual(part, matrices, case["grounding"], local, self.ROOTS)


def fixture(attachments=(), native_items=(), tracks=1, weight=None, footer=True, schema=1,
            motion_scale=1.,player_script='',skeleton_script='',has_reset=0):
    out = io.BytesIO()
    def u(value): out.write(struct.pack("<I", value & 0xffffffff))
    def numbers(values): out.write(struct.pack("<" + "d" * len(values), *values))
    def text(value):
        data = value.encode(); u(len(data)); out.write(data)
    identity = [1., 0., 0., 0., 1., 0., 0., 0., 1., 0., 0., 0.]
    out.write(b"UGNSRC01"); u(schema)
    text(json.dumps({"cases": [{"id": "synthetic", "cast": "fixture", "species": "mouse", "attachments": list(attachments)}]})); u(1)
    text("synthetic"); text("fixture"); text("mouse"); numbers([1]); numbers(identity); numbers(identity)
    u(1); text("Hips"); u(-1); numbers(identity); numbers([0, 0, 0]); numbers([0, 0, 0, 1]); numbers([1, 1, 1])
    u(1); text("cast/walk"); numbers([1]); u(1); u(tracks)
    for _ in range(tracks):
        text("Skeleton:Hips"); u(0); u(1); u(1); u(1); u(2)
        numbers([0, 1, 0, 0, 0]); numbers([1, 1, 1, 0, 0])
    u(1); text("Body"); numbers(identity); u(0 if weight is None else 1)
    if weight is not None: u(0); numbers(identity)
    u(1); u(1); u(0 if weight is None else 4); numbers([0, 0, 0])
    if weight is not None:
        for value in [weight, 0, 0, 0]: u(0); numbers([value])
    u(len(native_items))
    for item in native_items:
        text(item); numbers(identity); u(0); u(0); u(1); u(1); numbers([0, 0, 0])
    u(0); u(0); numbers([0, 1, 0]); numbers([1, 0, 0]); text("TAIL_NO_CHAIN"); text("{}")
    numbers([.25, .4, .07, 1.3, .07, .12])
    if schema>=2:text('{}')
    if schema>=3:
        numbers([motion_scale]);text(player_script);text(skeleton_script);u(has_reset)
        u(0);numbers([0.,0.,0.]);numbers([0.])
    if footer: out.write(b"UGNEND01"); u(1); text("")
    return out.getvalue()


class ExactIntervals(unittest.TestCase):
    def contains(self, interval, value):
        self.assertLessEqual(Fraction(interval.low, e.FIXED), value)
        self.assertGreaterEqual(Fraction(interval.high, e.FIXED), value)

    def test_binary_fraction_and_nonbinary_rational_are_outward(self):
        for value in [Fraction(1, 255), Fraction(-1, 65535), .1, -.1, 123.5]:
            self.contains(e.Interval.exact(value), Fraction(value))

    def test_products_and_signed_quantization_do_not_round_inward(self):
        a, b = e.Interval.exact(Fraction(-1, 3)), e.Interval.exact(Fraction(7, 11))
        self.contains(a*b, Fraction(-7, 33))
        lo, hi = (a*b).units()
        self.assertLessEqual(Fraction(lo, 1024), Fraction(-7, 33))
        self.assertGreaterEqual(Fraction(hi, 1024), Fraction(-7, 33))

    def test_zero_crossing_square_and_exact_sqrt(self):
        a = e.Interval(-3*e.FIXED, 2*e.FIXED).square()
        self.assertEqual(a.low, 0)
        self.assertEqual(a.high, 9*e.FIXED)
        self.assertEqual(a.sqrt().high, 3*e.FIXED)
        b = e.Interval.exact(2).sqrt()
        self.assertLessEqual(b.low*b.low, 2*e.FIXED*e.FIXED)
        self.assertGreaterEqual(b.high*b.high, 2*e.FIXED*e.FIXED)

    def test_zero_rotation_and_bad_shape_refuse(self):
        for q in ([0., 0., 0., 0.], [0., 0., 1.]):
            with self.assertRaises(e.Refused): e.unit_quaternion(q)

    def test_cone_encloses_continuous_rotation_and_positive_blends(self):
        values = [[0., math.sin(a/2), 0., math.cos(a/2)] for a in (-.7, .2, .8)]
        box = e.quaternion_hull(values)
        for index in range(201):
            t = index/200
            for first, second in [(values[0], values[1]), (values[0], values[2]), (values[1], values[2])]:
                q = [(1-t)*a+t*b for a,b in zip(first,second)]
                n = math.sqrt(sum(a*a for a in q));q = [a/n for a in q]
                actual = e.rotation_matrix(e.vector(q))
                for r in range(3):
                    for c in range(3):
                        self.assertLessEqual(box[r][c].low, actual[r][c].high)
                        self.assertGreaterEqual(box[r][c].high, actual[r][c].low)

    def test_pi_separation_expands_without_guessing_a_sign(self):
        box = e.quaternion_hull([[0.,0.,0.,1.], [1.,0.,0.,0.]])
        self.assertTrue(all(value == e.ROTATION_COMPONENT for row in box for value in row))

    def test_unbounded_or_nonfinite_inputs_refuse(self):
        for value in (float("nan"), float("inf"), 1e8):
            with self.assertRaises(e.Refused): e.Interval.exact(value)
        with self.assertRaises(e.Refused): e.Interval(-(1 << 200), 0)

    def test_all_yaw_keeps_below_root_body(self):
        bounds = [e.Interval.exact(3), e.Interval(-2*e.FIXED, e.FIXED), e.Interval.exact(4)]
        self.assertEqual(e.units(e.all_yaw(bounds)), [-5120,-2048,-5120,5120,1024,5120])


class NativeRecords(unittest.TestCase):
    def read(self, data, digest=None):
        return list(e.NativeSource(io.BytesIO(data), digest or hashlib.sha256(data).hexdigest()).cases())

    def test_exact_minimal_record_is_source_only(self):
        rows = self.read(fixture())
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["body"][0]["surfaces"][0][0][0], [0.,0.,0.])
        self.assertNotIn("qualified", rows[0])

    def test_hash_covers_decoded_bytes(self):
        data = fixture()
        with self.assertRaisesRegex(e.Refused, "SOURCE_HASH_MISMATCH"): self.read(data, "0"*64)

    def test_truncated_completion_cannot_be_accepted(self):
        with self.assertRaises(e.Refused): self.read(fixture(footer=False))

    def test_trailing_data_is_not_an_ignored_second_image(self):
        with self.assertRaisesRegex(e.Refused, "SOURCE_TRAILING_BYTES"): self.read(fixture()+b"hidden")

    def test_omitted_or_extra_attachment_refuses(self):
        for data in (fixture(attachments=("pick",)), fixture(native_items=("pick",))):
            with self.assertRaisesRegex(e.Refused, "SOURCE_ATTACHMENT_CENSUS"): self.read(data)

    def test_explicit_attachment_binding_is_preserved(self):
        row = self.read(fixture(attachments=("pick",), native_items=("pick",)))[0]
        self.assertEqual(row["items"][0]["key"], "pick")

    def test_negative_zero_and_nonfinite_weights_refuse(self):
        for weight in (-1.,0.,float("nan")):
            with self.assertRaises(e.Refused): self.read(fixture(weight=weight))

    def test_nonunit_positive_weights_are_not_silently_normalized(self):
        row = self.read(fixture(weight=2.))[0]
        self.assertEqual(row["body"][0]["surfaces"][0][0][1][0][1], 2.)

    def test_omitted_required_clip_and_empty_state_refuse(self):
        row = self.read(fixture())[0]
        with self.assertRaisesRegex(e.Refused, "REQUIRED_STATE_MISSING"): e.bone_domains(row,["idle"],"upright")
        row = self.read(fixture(tracks=0))[0]
        with self.assertRaisesRegex(e.Refused, "REQUIRED_STATE_EMPTY"): e.bone_domains(row,["walk"],"upright")

    def test_unknown_modifier_cannot_borrow_a_body_certificate(self):
        row = self.read(fixture())[0]
        row["modifiers"].append(("SkeletonModifier3D","res://unreviewed.gd",1,1.))
        with self.assertRaisesRegex(e.Refused,"MODIFIER_BINDING_UNSUPPORTED"): e.bone_domains(row,["walk"],"upright")

    def test_duplicate_tracks_and_bone_names_refuse(self):
        with self.assertRaisesRegex(e.Refused,"SOURCE_DUPLICATE_TRACK"): self.read(fixture(tracks=2))
        with self.assertRaisesRegex(e.Refused,"SOURCE_BONE_NAMES"):
            e.validate_hierarchy([{"name":"x","parent":-1},{"name":"x","parent":0}])


class ContinuousWindows(unittest.TestCase):
    def row(self):
        return list(e.NativeSource(io.BytesIO(fixture()), hashlib.sha256(fixture()).hexdigest()).cases())[0]

    def test_complete_segments_and_loop_wrap_not_sampled_endpoints(self):
        track = {"wrap":1,"keys":[[0.,1.,0.],[.4,1.,2.],[.8,1.,-3.]]}
        clip = {"length":1.,"loop":1}
        self.assertEqual(e.window_keys(track,(.41,.42),clip),track["keys"][1:])
        self.assertEqual(e.window_keys(track,(.99,1.),clip),[track["keys"][0],track["keys"][-1]])
        with self.assertRaisesRegex(e.Refused,"WINDOW_RANGE"):
            e.window_keys(track,(-.01,.4),clip)

    def test_present_track_does_not_union_unplayed_reset_pose(self):
        row=self.row();row["bones"][0]["position"]=[100.,0.,0.]
        track=row["clips"][0]["tracks"][0]
        track["type"]=1;track["keys"]=[[0.,1.,1.,2.,3.],[1.,1.,1.,2.,3.]]
        domain=e.bone_domains(row,["walk"],"upright",{"cast/walk":(0.,1.)})
        self.assertEqual(e.units(domain[0]["origin"]),[1024,2048,3072,1024,2048,3072])

    def test_missing_channel_uses_actual_reset_not_another_species(self):
        row=self.row();row["bones"][0]["position"]=[.125,0.,0.]
        row["clips"][0]["tracks"][0].update(type=2,keys=[[0.,1.,0.,0.,0.,1.],[1.,1.,0.,0.,0.,1.]])
        domain=e.bone_domains(row,["walk"],"upright",{"cast/walk":(0.,1.)})
        self.assertEqual(domain[0]["origin"][0],e.Interval.exact(.125))

    def test_vectorized_skin_encloses_scalar_exact_skin_with_nonunit_weights(self):
        raw=fixture(weight=1.);row=list(e.NativeSource(io.BytesIO(raw),hashlib.sha256(raw).hexdigest()).cases())[0]
        row["body"][0]["surfaces"][0][0]=([.7,-.0125,.3],[(0,.25),(0,.5),(0,.75),(0,.125)])
        domain=e.global_domains(row,["walk"],"upright")
        # Deliberately non-point uncertainty exercises sign changes and interval multiplication.
        domain[0]["origin"][0]=e.Interval(-e.FIXED//3,e.FIXED//5)
        scalar=e.body_bounds(row,domain);fast=e.FastSkin(row).bounds(domain)
        for a,b in zip(fast,scalar):
            self.assertLessEqual(a.low,b.low);self.assertGreaterEqual(a.high,b.high)

    def test_vectorized_integer_overflow_refuses_before_multiplication(self):
        fast=e.FastSkin(self.row());np=fast.np
        with self.assertRaisesRegex(e.Refused,"FAST_PRODUCT_CAPACITY"):
            fast.multiply((np.array([1<<40]),np.array([1<<40])),(np.array([1<<30]),np.array([1<<30])))

    def test_physical_modifier_without_actual_empty_simulator_proof_refuses(self):
        row=self.row();row["modifiers"].append(("PhysicalBoneSimulator3D","",1,1.))
        with self.assertRaisesRegex(e.Refused,"MODIFIER_BINDING_UNSUPPORTED"):
            e.bone_domains(row,["walk"],"upright")
        row["presentation"]={"physical_bones":0,"physical_simulating":False}
        self.assertEqual(len(e.bone_domains(row,["walk"],"upright")),1)
        row["presentation"]["physical_bones"]=1
        with self.assertRaisesRegex(e.Refused,"MODIFIER_BINDING_UNSUPPORTED"):
            e.bone_domains(row,["walk"],"upright")

    def test_exact_motion_scale_applies_only_to_native_position_track_values(self):
        raw=fixture(schema=3,motion_scale=2.)
        row=list(e.NativeSource(io.BytesIO(raw),hashlib.sha256(raw).hexdigest()).cases())[0]
        domain=e.bone_domains(row,['walk'],'upright')
        self.assertEqual(domain[0]['origin'][0].high,2*e.FIXED)
        row['clips'][0]['tracks'][0].update(type=2,keys=[[0.,1.,0.,0.,0.,1.]])
        row['bones'][0]['position']=[.125,0.,0.]
        self.assertEqual(e.bone_domains(row,['walk'],'upright')[0]['origin'][0],e.Interval.exact(.125))

    def test_custom_postprocessing_or_reset_cannot_borrow_native_rest_math(self):
        for kwargs in ({'player_script':'res://custom.gd'},{'skeleton_script':'res://custom.gd'},
                       {'has_reset':1},{'motion_scale':0.}):
            raw=fixture(schema=3,**kwargs)
            with self.assertRaisesRegex(e.Refused,'NATIVE_POSTPROCESS_UNSUPPORTED'):
                list(e.NativeSource(io.BytesIO(raw),hashlib.sha256(raw).hexdigest()).cases())


class NativeMixerMath(unittest.TestCase):
    """Independent diagnostic evaluation of the actual rest-relative native formula.

    These tests check the source-math certificate, not float32 engine error bounds.
    """

    @staticmethod
    def product(a, b):
        x,y,z,w = a; i,j,k,r = b
        return [w*i+x*r+y*k-z*j, w*j+y*r+z*i-x*k,
                w*k+z*r+x*j-y*i, w*r-x*i-y*j-z*k]

    @staticmethod
    def normalized(q):
        n = math.sqrt(sum(x*x for x in q))
        return [x/n for x in q]

    @classmethod
    def slerp(cls, a, b, t):
        a,b=cls.normalized(a),cls.normalized(b)
        c=sum(x*y for x,y in zip(a,b))
        if c < 0: b=[-x for x in b];c=-c
        if c > .999999:
            return cls.normalized([(1-t)*x+t*y for x,y in zip(a,b)])
        theta=math.acos(min(1,c));s=math.sin(theta)
        return [math.sin((1-t)*theta)/s*x+math.sin(t*theta)/s*y for x,y in zip(a,b)]

    @staticmethod
    def axis(axis, angle):
        return [math.sin(angle/2) if i == axis else 0 for i in range(3)]+[math.cos(angle/2)]

    def assert_enclosed(self, bounds, q):
        matrix=e.rotation_matrix(e.vector(self.normalized(q)))
        for row in range(3):
            for col in range(3):
                self.assertLessEqual(bounds[row][col].low, matrix[row][col].high)
                self.assertGreaterEqual(bounds[row][col].high, matrix[row][col].low)

    def test_machin_pi_contains_independent_decimal_bracket(self):
        # The two rational decimal bounds are known outward bounds, not one exact pi.
        lo=Fraction('3.14159265358979323846264338327950288419716939937510')
        hi=Fraction('3.14159265358979323846264338327950288419716939937511')
        self.assertLessEqual(Fraction(e.PI.low,e.FIXED),lo)
        self.assertGreaterEqual(Fraction(e.PI.high,e.FIXED),hi)
        self.assertEqual(e.PI.high-e.PI.low,1)

    def test_outward_trig_contains_long_exact_rational_series(self):
        for numerator in (-300,-175,-1,0,1,127,300):
            x=Fraction(numerator,100)
            dyadic=int(x*e.FIXED);x=Fraction(dyadic,e.FIXED)
            for kind in ('sin','cos','sinc'):
                offset=0 if kind=='cos' else 1
                power=(0 if kind=='sinc' else offset)
                value=sum(((-1)**n*x**(2*n+power)/math.factorial(2*n+offset) for n in range(50)),Fraction(0))
                bound=e.trig_point(kind,dyadic)
                self.assertLessEqual(Fraction(bound.low,e.FIXED),value)
                self.assertGreaterEqual(Fraction(bound.high,e.FIXED),value)

    def test_acos_seed_is_only_a_proposal_until_cosine_proves_endpoints(self):
        from unittest.mock import patch
        for x in (1,e.FIXED//3,e.FIXED//2,e.FIXED-1):
            with patch.object(e.math,'acos',return_value=.4):
                e.acos_point.cache_clear()
                result=e.acos_point(x)
            self.assertTrue(result.low==0 or e.trig_point('cos',result.low).low>=x)
            self.assertTrue(result.high>=e.PI.high//2 or e.trig_point('cos',result.high).high<=x)

    def test_noncommuting_many_clip_products_with_any_nonnegative_weights(self):
        rest=self.axis(1,.41)
        deltas=[self.axis(0,.6),self.axis(1,-.45),self.axis(2,.5),self.axis(0,-.2)]
        values=[self.product(rest,d) for d in deltas]
        bounds=e.mixer_rotation(rest,values,[])
        for weights in ([1,0,0,0],[0,.2,.3,.5],[.1,.2,.3,.4],[.25]*4,[.001,.009,.09,.9]):
            q=rest
            for delta,weight in zip(deltas,weights):
                q=self.normalized(self.product(q,self.slerp([0,0,0,1],delta,weight)))
            self.assert_enclosed(bounds,q)

    def test_continuous_key_arcs_and_negative_equivalent_quaternions(self):
        rest=self.axis(2,.3)
        first=self.product(rest,self.axis(0,-.4));second=self.product(rest,self.axis(1,.7))
        third=self.product(rest,self.axis(2,-.6))
        bounds=e.mixer_rotation(rest,[first,[-v for v in second],third],[(first,second)])
        inverse=[-v for v in rest[:3]]+[rest[3]]
        for step in range(51):
            phase=step/50
            to=self.slerp(first,second,phase)
            delta=self.product(inverse,to)
            other=self.product(inverse,third)
            q=self.product(rest,self.slerp([0,0,0,1],delta,.63))
            q=self.product(q,self.slerp([0,0,0,1],other,.37))
            self.assert_enclosed(bounds,q)

    def test_hemisphere_ambiguity_falls_back_to_all_rotations_and_empty_refuses(self):
        first,second=self.axis(0,2.8),self.axis(0,-2.8)
        bounds=e.mixer_rotation([0,0,0,1],[first,second],[(first,second)])
        self.assertTrue(all(v==e.ROTATION_COMPONENT for row in bounds for v in row))
        with self.assertRaisesRegex(e.Refused,'ROTATION_STATE_MISSING'):
            e.mixer_rotation([0,0,0,1],[],[])


class TailGroundMath(unittest.TestCase):
    def test_tightening_preserves_radial_geometry_and_outside_segment_extent(self):
        start=e.Interval.exact(.2);end=e.Interval.exact(.1);offset=e.vector([1.,0.,0.])
        for p in ([.4,.03,.07],[-.2,.1,.05],[1.4,-.1,.06],[0.,0.,0.]):
            lower=e.tail_influence_lower(e.vector(p),start,end,offset)/e.FIXED
            for step in range(201):
                angle=-math.pi+2*math.pi*step/200
                # A rigid segment is admissible only while both proved endpoint heights hold.
                if .2+math.sin(angle)<.1:continue
                actual=.2+math.sin(angle)*p[0]+math.cos(angle)*p[1]
                self.assertLessEqual(lower,actual+1e-14)
        # A 10cm-thick tail may extend below a 1cm joint clearance. Never crop it at floor zero.
        low=e.tail_influence_lower(e.vector([.5,-.1,0.]),e.Interval.exact(.01),e.Interval.exact(.01),offset)
        self.assertLess(low,0)

    def test_failed_ground_premises_cannot_silently_tighten_a_tail(self):
        case={'tail_clearances':[0.]*9,'tail_floor':0.,'skeleton_to_actor':[1.,0.,0.,0.,1.,0.,0.,0.,1.,0.,0.,0.],
              'modifiers':[('SkeletonModifier3D','res://scripts/presentation/tail_ground_constraint.gd',1,1.)],
              'bones':[{'name':'tail_%02d'%i,'parent':i-1,'position':[0.,0.,.1]} for i in range(8)],
              'tail_tip':[0.,0.,.1],'clips':[]}
        globals_=[{'scale_bound':e.FIXED,'origin':e.vector([0.,.2,0.])} for _ in range(8)]
        proof=e.tail_constraint_domains(case,globals_)
        self.assertEqual(len(proof),8)
        case['modifiers'].append(('SkeletonModifier3D','res://later_unproved_modifier.gd',1,1.))
        with self.assertRaisesRegex(e.Refused,'TAIL_CONSTRAINT_ORDER'):
            e.tail_constraint_domains(case,globals_)
        case['modifiers'].pop();globals_[0]['scale_bound']+=1
        with self.assertRaisesRegex(e.Refused,'TAIL_CONSTRAINT_SCALE'):
            e.tail_constraint_domains(case,globals_)

    def test_base_too_low_keeps_the_actual_segment_length_limit(self):
        case={'tail_clearances':[0.]+[.2]*8,'tail_floor':0.,'skeleton_to_actor':[1.,0.,0.,0.,1.,0.,0.,0.,1.,0.,0.,0.],
              'modifiers':[('SkeletonModifier3D','res://scripts/presentation/tail_ground_constraint.gd',1,1.)],
              'bones':[{'name':'tail_%02d'%i,'parent':i-1,'position':[0.,0.,.01]} for i in range(8)],
              'tail_tip':[0.,0.,.01],'clips':[]}
        globals_=[{'scale_bound':e.FIXED,'origin':e.vector([0.,-.2,0.])} for _ in range(8)]
        proof=e.tail_constraint_domains(case,globals_)
        self.assertLess(proof[0][1].high,0)
        self.assertLessEqual(proof[7][1].high,e.Interval.exact(-.12).high)


if __name__ == "__main__":
    unittest.main(verbosity=2)
