#!/usr/bin/env python3
"""Independent wire, conservation and refusal checks for the finite structural packet."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
LOADER = importlib.util.spec_from_file_location("entry_structure", HERE / "compile_entry_prefix.py")
M = importlib.util.module_from_spec(LOADER)
LOADER.loader.exec_module(M)


class StructuralPublication(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.spec = json.loads((M.ROOT / M.SPEC).read_text())
        cls.packet = M.build()

    def test_full_rebuild_is_byte_identical(self):
        self.assertEqual(self.packet, M.build())
        self.assertEqual(set(self.packet), {"structure.ugconn", "assemblies.ugasmb", "recipes.ugrecp", "manifest.json"})

    def test_every_rectangular_solid_and_bearing_survives(self):
        wire = self.packet["structure.ugconn"]
        counts = struct.unpack_from("<7I", wire, 20)
        self.assertEqual(counts, (1, 2, 26, 14, 56, 1, 12))
        region_at = 136 + counts[0] * 112 + counts[1] * 16
        regions = [struct.unpack_from("<8i", wire, region_at + r * 32) for r in range(counts[2])]
        self.assertEqual([r[:6] for r in regions if r[6] == 18],
                         [tuple(b["bounds_u"]) for b in self.spec["natural_bearings"]])
        self.assertEqual([r[:6] for r in regions if r[6] == 20],
                         [tuple(b["bounds_u"]) for b in self.spec["parts"]])
        part_at = region_at + counts[2] * 32
        vertex_at = part_at + counts[3] * 36
        for row, original in enumerate(self.spec["parts"]):
            part = struct.unpack_from("<9i", wire, part_at + row * 36)
            vertices = [struct.unpack_from("<3i", wire, vertex_at + (part[7] + i) * 12) for i in range(part[8])]
            reconstructed = [min(v[0] for v in vertices), min(v[1] for v in vertices) - part[1],
                             min(v[2] for v in vertices), max(v[0] for v in vertices),
                             max(v[1] for v in vertices), max(v[2] for v in vertices)]
            self.assertEqual(reconstructed, original["bounds_u"])
        floors = [r for r in regions if r[6] == 17]
        self.assertEqual(len(floors), 2)
        self.assertEqual(min(r[2] for r in floors), -2560, "residual pocket is not a floor")

    def test_paces_are_exact_ground_records_with_no_stair_rate(self):
        ground = (M.ROOT / M.GROUND).read_bytes()
        cat = self.packet["structure.ugconn"]
        self.assertEqual(cat[-8 - 12 * 36:-8], ground[136:-8])
        for row in range(12):
            fields = struct.unpack_from("<7iq", cat, len(cat) - 8 - 12 * 36 + row * 36)
            self.assertEqual((fields[1], fields[5], fields[6]), (-1, 0, 0))

    def test_two_whole_wood_bills_bind_exact_partition(self):
        group, recipes = self.packet["assemblies.ugasmb"], self.packet["recipes.ugrecp"]
        self.assertEqual(group[56:88], hashlib.sha256(self.packet["structure.ugconn"]).digest())
        self.assertEqual(recipes[52:84], group[56:88])
        self.assertEqual(recipes[84:116], hashlib.sha256(group).digest())
        ownership, wood, work = [], 0, 0
        for row in range(2):
            kind, start, count, anchor = struct.unpack_from("<4i", group, 88 + row * 16)
            ownership.extend(range(start, start + count))
            self.assertEqual((kind, start, count, anchor), (row, row * 7, 7, row * 7))
            billed, lines, amount, key, quantity = struct.unpack_from("<iiq8sq", recipes, 116 + row * 80)
            self.assertEqual((billed, lines, key), (anchor, 1, b"wood\0\0\0\0"))
            self.assertEqual(recipes[116 + row * 80 + 32:116 + row * 80 + 80], bytes(48))
            work += amount
            wood += quantity
        self.assertEqual(ownership, list(range(14)))
        self.assertEqual((wood, work), (5000, 44000))

    def test_manifest_is_explicit_about_unbuilt_gates(self):
        record = json.loads(self.packet["manifest.json"])
        for key in ("entry_workflow_qualified", "world_activation_qualified", "traversal_qualified",
                    "frontier_emitted", "workpieces_emitted"):
            self.assertIs(record[key], False)
        for path, expected in record["inputs"].items():
            # Historical publication: scripts are pinned at PUBLISHED_AT, data inputs are still live.
            raw = (M.published(M.ROOT, path, M.PUBLISHED_AT) if path in (M.PRODUCER, *M.OWNERS)
                   else (M.ROOT / path).read_bytes())
            self.assertEqual(hashlib.sha256(raw).hexdigest(), expected)

    def test_committed_publication_is_the_exact_rebuild(self):
        out = M.ROOT / M.OUTPUT
        self.assertEqual({p.name for p in out.iterdir()}, set(self.packet))
        for name, raw in self.packet.items():
            self.assertEqual((out / name).read_bytes(), raw, name)

    def test_historical_scripts_come_from_the_publishing_commit(self):
        with self.assertRaisesRegex(ValueError, "HISTORICAL_SOURCE"):
            M.published(M.ROOT, M.OWNERS[0], "0" * 40)

    def test_invalid_partition_bill_and_cut_bearing_are_refused(self):
        changes = [lambda s: s["assemblies"][1]["included_parts"].append(0),
                   lambda s: s["assemblies"][0].update(wood_milli=0),
                   lambda s: s["assemblies"][1].update(build_milli_wu=1),
                   lambda s: s["parts"][2].update(assembly=1),
                   lambda s: s["natural_bearings"][0]["bounds_u"].__setitem__(4, 0),
                   lambda s: s["cut_groups"][0]["bounds_u"].__setitem__(0, -1023),
                   lambda s: s.update(production_qualified=True)]
        for mutate in changes:
            changed = copy.deepcopy(self.spec)
            mutate(changed)
            with self.assertRaises(ValueError):
                M.structure(changed)

    def test_changed_input_cannot_be_accepted_by_a_filename(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            p = root / "wire"
            p.write_bytes(b"not the accepted input")
            with self.assertRaisesRegex(ValueError, "INPUT_SHA"):
                M.read(root, "wire", M.PROFILE_SHA, 131072)
            p.unlink()
            p.symlink_to(M.ROOT / M.PROFILE)
            with self.assertRaisesRegex(ValueError, "INPUT_PATH"):
                M.read(root, "wire", M.PROFILE_SHA, 131072)


if __name__ == "__main__":
    unittest.main()
