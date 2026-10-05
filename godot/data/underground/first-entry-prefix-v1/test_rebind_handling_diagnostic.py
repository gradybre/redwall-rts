"""Exact rebind and fail-closed regressions; never execute or approve a runtime source."""
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
loader = importlib.util.spec_from_file_location("diagnostic_rebind", HERE / "rebind_handling_diagnostic.py")
D = importlib.util.module_from_spec(loader)
loader.loader.exec_module(D)
BUNDLE = D.S.ROOT / "docs/validation/evidence/underground-entry-source-phases-2026-10-05/handling-diagnostic-1"


class RebindTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profile = (BUNDLE / "mole-worker.ugprof").read_bytes()
        cls.expected = json.loads((BUNDLE / "manifest.json").read_text())

    def test_exact_bundle_rebuild(self):
        actual = D.build(self.profile)
        for name, raw in actual.items():
            self.assertEqual(raw, (BUNDLE / name).read_bytes(), name)

    def test_payload_and_bills_remain_exact(self):
        actual = D.build(self.profile)
        original = D.S.build()
        self.assertEqual(actual["structure.ugconn"][:48], original["structure.ugconn"][:48])
        self.assertEqual(actual["structure.ugconn"][56:], original["structure.ugconn"][56:])
        self.assertEqual(actual["recipes.ugrecp"][116:], original["recipes.ugrecp"][116:])
        self.assertEqual(actual["assemblies.ugasmb"][88:], original["assemblies.ugasmb"][88:])
        self.assertEqual(actual["frontier.ugfront"][220:], D.F.build()["frontier.ugfront"][220:])

    def test_derived_hashes_bind_new_exact_sources(self):
        actual = D.build(self.profile)
        h = lambda name: hashlib.sha256(actual[name]).digest()
        self.assertEqual(actual["assemblies.ugasmb"][56:88], h("structure.ugconn"))
        self.assertEqual(actual["recipes.ugrecp"][52:116], h("structure.ugconn") + h("assemblies.ugasmb"))
        self.assertEqual(actual["frontier.ugfront"][92:188], h("structure.ugconn") + h("assemblies.ugasmb") + h("recipes.ugrecp"))
        self.assertEqual(struct.unpack_from("<q", actual["structure.ugconn"], 48)[0], 4)
        self.assertEqual(struct.unpack_from("<q", actual["frontier.ugfront"], 52)[0], 4)

    def test_old_row_and_handling_changes_are_not_admitted(self):
        for offset in [32, 64, 96, 96+29*98, 96+30*98, len(self.profile)-12]:
            raw = bytearray(self.profile)
            raw[offset] ^= 1
            with self.subTest(offset=offset), self.assertRaisesRegex(ValueError, "PROFILE_SHA"):
                D.build(bytes(raw))

    def test_modified_frontier_predecessor_refuses_before_output(self):
        predecessor = D.F.build()
        predecessor["frontier.ugfront"] = predecessor["frontier.ugfront"][:-1] + b"2"
        with patch.object(D.F, "build", return_value=predecessor):
            with self.assertRaisesRegex(ValueError, "ACCEPTED_FRONTIER_DRIFT"):
                D.build(self.profile)

    def test_source_rebind_makes_no_runtime_qualification(self):
        for name in ("production_qualified", "world_activation_qualified", "paid_execution_qualified"):
            self.assertIs(self.expected[name], False)
        self.assertTrue(self.expected["frontier_payload_unchanged"])
        self.assertEqual(self.expected["profile_count"], 30)
        self.assertEqual(self.expected["source_count"], 2)


if __name__ == "__main__":
    unittest.main()
