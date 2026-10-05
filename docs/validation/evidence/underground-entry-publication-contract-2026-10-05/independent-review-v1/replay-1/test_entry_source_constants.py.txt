"""Constant serialization and linked-source refusal; no physical qualification."""
import hashlib
import importlib.util
from pathlib import Path
import re
import struct
import unittest

HERE = Path(__file__).resolve().parent
loader = importlib.util.spec_from_file_location("entry_constants", HERE / "entry_source_constants.py")
C = importlib.util.module_from_spec(loader)
loader.loader.exec_module(C)
ROOT = HERE.parents[3]
BUNDLE = ROOT / "docs/validation/evidence/underground-entry-source-phases-2026-10-05/handling-diagnostic-1"


def fixture():
    """Use real archived headers; the two-row Workpieces image is only a serialization fixture."""
    packet = {name: (BUNDLE / name).read_bytes() for name in C.FILES.values() if name != "workpieces.ugwipc"}
    packet["mole-worker.ugprof"] = (BUNDLE / "mole-worker.ugprof").read_bytes()
    raw = b"UGWIPC01" + struct.pack("<I9q", 1, 1, 1, 1, 1, 1, 4, 2, 0, 1)
    raw += b"".join(hashlib.sha256(packet[name]).digest() for name in
                    ("structure.ugconn", "assemblies.ugasmb", "recipes.ugrecp"))
    raw += packet["mole-worker.ugprof"][64:96]
    raw += struct.pack("<6iq", 1, 3, 1024, 192, -768, 29, 1)
    raw += struct.pack("<6iq", 8, 3, 2304, 320, -2816, 29, 1) + b"UGWEND01"
    packet["workpieces.ugwipc"] = raw
    return packet


class ConstantsTests(unittest.TestCase):
    def test_scalar_only_fixed_paths_and_all_revisions(self):
        packet = fixture()
        text = C.generate(packet).decode()
        self.assertEqual(text.splitlines()[:2], ["extends RefCounted", "## Generated fixed first-entry source metadata; ADR1190."])
        for name, filename in C.FILES.items():
            self.assertIn('const ' + name + '_PATH: String = "' + C.DESTINATION + filename + '"', text)
            self.assertIn('const ' + name + '_SHA: String = "' + hashlib.sha256(packet[filename]).hexdigest() + '"', text)
        for name in tuple(C.FILES)[:5]:
            self.assertIn('const ' + name + '_REVISION: int = 1\n', text)
        self.assertIn('const CONTENT_REVISION: int = 4\n', text)
        self.assertNotRegex(text, r"\b(var|func|Array|load|preload)\b")

    def test_signed_words_reconstruct_exact_digest(self):
        packet = fixture()
        text = C.generate(packet).decode()
        for name in ("CATALOG", "GROUND"):
            values = [int(re.search(r"const " + name + "_DIGEST_" + str(i) + r": int = (-?\d+)\n", text)[1]) for i in range(4)]
            self.assertEqual(struct.pack("<4q", *values), hashlib.sha256(packet[C.FILES[name]]).digest())
        self.assertTrue(any(int(v) < 0 for v in re.findall(r"_DIGEST_\d: int = (-?\d+)", text)))

    def test_capacities_come_from_complete_bounded_wire(self):
        text = C.generate(fixture()).decode()
        for name, count in zip(C.TABLES, (2, 8, 2, 10, 10, 6)):
            self.assertIn('const ' + name + '_COUNT: int = ' + str(count) + '\n', text)

    def test_inputs_are_not_modified(self):
        packet = fixture()
        before = packet.copy()
        self.assertEqual(C.generate(packet), C.generate(packet))
        self.assertEqual(packet, before)

    def test_missing_or_extra_file_refuses(self):
        for name in fixture():
            packet = fixture()
            del packet[name]
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, "FILES"):
                C.generate(packet)
        packet = fixture()
        packet['../unapproved'] = b'12345678'
        with self.assertRaisesRegex(ValueError, "FILES"):
            C.generate(packet)

    def test_truncation_footer_and_mutable_input_refuse(self):
        for name in fixture():
            for value in (b'12345678', fixture()[name][:-1], fixture()[name][:-8] + b'UGBAD001', bytearray(fixture()[name])):
                packet = fixture()
                packet[name] = value
                with self.subTest(name=name), self.assertRaises(ValueError):
                    C.generate(packet)

    def test_linked_digest_corruption_refuses(self):
        for name, offsets in {"assemblies.ugasmb": [56], "recipes.ugrecp": [52, 84],
                              "frontier.ugfront": [92, 124, 156, 188],
                              "workpieces.ugwipc": [84, 116, 148, 180],
                              "ground-pace.ugconn": [72, 104]}.items():
            for offset in offsets:
                packet = fixture()
                raw = bytearray(packet[name]); raw[offset] ^= 1; packet[name] = bytes(raw)
                with self.subTest(name=name, offset=offset), self.assertRaises(ValueError):
                    C.generate(packet)

    def test_revision_mismatches_refuse(self):
        for name, offsets in {"assemblies.ugasmb": [12, 20, 28, 40], "recipes.ugrecp": [12, 20, 28, 40],
                              "frontier.ugfront": [20, 28, 36, 44, 52],
                              "workpieces.ugwipc": [20, 28, 36, 44, 52],
                              "structure.ugconn": [12, 48], "ground-pace.ugconn": [12, 48]}.items():
            for offset in offsets:
                packet = fixture(); raw = bytearray(packet[name]); struct.pack_into('<q', raw, offset, 99); packet[name] = bytes(raw)
                with self.subTest(name=name, offset=offset), self.assertRaises(ValueError):
                    C.generate(packet)

    def test_frontier_capacity_and_full_length_refuse_before_emission(self):
        for index in range(6):
            for count in (0, 2049, 0xffffffff):
                packet = fixture(); raw = bytearray(packet['frontier.ugfront']); struct.pack_into('<I', raw, 68 + index * 4, count)
                packet['frontier.ugfront'] = bytes(raw)
                with self.subTest(index=index, count=count), self.assertRaisesRegex(ValueError, 'FRONTIER_CAPACITY'):
                    C.generate(packet)
        packet = fixture(); raw = bytearray(packet['frontier.ugfront']); struct.pack_into('<I', raw, 72, 9)
        packet['frontier.ugfront'] = bytes(raw)
        with self.assertRaisesRegex(ValueError, 'FRONTIER_LENGTH'):
            C.generate(packet)

    def test_coherent_install_source_substitution_cannot_supply_handling(self):
        packet = fixture()
        raw = bytearray(packet['workpieces.ugwipc'])
        struct.pack_into('<q', raw, 76, 0)
        raw[180:212] = packet['mole-worker.ugprof'][32:64]
        packet['workpieces.ugwipc'] = bytes(raw)
        with self.assertRaisesRegex(ValueError, 'WORKPIECES_NOT_DISTINCT'):
            C.generate(packet)


if __name__ == "__main__":
    unittest.main()
