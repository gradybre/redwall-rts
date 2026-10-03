#!/usr/bin/env python3
"""Create-only wrapper regressions with synthetic files and a mocked native process."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest import mock


SPEC = importlib.util.spec_from_file_location("matrix_reproduction_under_test", Path(__file__).with_name("reproduce.py"))
WRAPPER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(WRAPPER)


class Reproduction(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bundle = self.root / "evidence"
        self.raw = self.root / "godot/demo/assets/underground-matrices/test.ugpal"
        self.pin = self.root / "actual-fixture"
        self.pin.write_bytes(b"synthetic source, no native qualification")
        self.calls = 0
        self.drift = False
        for relative in ("tools/bake_underground_matrices.gd", "godot/demo/cast/underground_actor.gd"):
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("synthetic wrapper fixture\n")
        runtime = self.root / "docs/design/underground-planning/evidence/modular-build/profiles/runtime/reproduce.py"
        runtime.parent.mkdir(parents=True)
        runtime.write_text("""from pathlib import Path
import hashlib
def pin(path):
    return {"path": str(path), "sha256": hashlib.sha256(Path(path).read_bytes()).hexdigest()}
def build():
    source = Path(__file__).parents[7] / "actual-fixture"
    return {"manifest": pin(source), "sources": [pin(source)],
            "cases": [{"id": "fixture", "scenario": "plain"}, {"id": "turn", "scenario": "turn"}]}
def validate_report(spec, report, log):
    if len(spec["cases"]) != len(report["cases"]):
        raise ValueError("SYNTHETIC_CASE_CENSUS")
""")

    def run_wrapper(self, extra=(), callback=None):
        arguments = ["reproduce.py", str(self.bundle), "--raw-name", "test.ugpal", *extra]
        with mock.patch.object(WRAPPER, "ROOT", self.root), mock.patch.object(sys, "argv", arguments), \
                mock.patch.object(WRAPPER.subprocess, "run", side_effect=callback or self.fake_native), \
                mock.patch("builtins.print"):
            WRAPPER.main()

    def fake_native(self, command, *, cwd, stdout, stderr, timeout):
        self.calls += 1
        self.assertEqual(cwd, self.root)
        self.assertGreater(timeout, 0)
        stdout.write("Synthetic process fixture only\n")
        if "--" in command:
            spec, report, content = map(Path, command[-3:])
            manifest = json.loads(spec.read_text())
            content.write_bytes(b"synthetic finite content")
            rows = [{"samples": 2, "skin_engine_matrix_checks": 3} for _ in manifest["cases"]]
            report.write_text(json.dumps({"cases": rows, "finite_presentation_content": {"sha256": WRAPPER.digest(content)}}))
            if self.drift:
                self.pin.write_bytes(b"changed after capture")
        return types.SimpleNamespace(returncode=0)

    def test_existing_complete_bundle_is_unchanged_before_any_process(self):
        self.bundle.mkdir()
        files = {name: b"retained " + name.encode() for name in ("bake-spec.json", "bake-report.json", "native-bake.log", "verification.json")}
        for name, data in files.items():
            (self.bundle / name).write_bytes(data)
        with self.assertRaisesRegex(ValueError, "OUTPUT_BUNDLE_EXISTS"):
            self.run_wrapper()
        self.assertEqual(self.calls, 0)
        self.assertEqual({p.name: p.read_bytes() for p in self.bundle.iterdir()}, files)
        self.assertFalse(self.raw.exists())

    def test_existing_raw_and_symlink_destinations_are_never_replaced(self):
        self.raw.parent.mkdir(parents=True)
        self.raw.write_bytes(b"retained source")
        with self.assertRaisesRegex(ValueError, "RAW_EXISTS"):
            self.run_wrapper()
        self.assertEqual(self.raw.read_bytes(), b"retained source")
        self.assertFalse(self.bundle.exists())
        self.raw.unlink()
        self.raw.symlink_to(self.pin)
        with self.assertRaisesRegex(ValueError, "RAW_EXISTS"):
            self.run_wrapper()
        self.assertEqual(self.pin.read_bytes(), b"synthetic source, no native qualification")
        self.raw.unlink()
        self.bundle.symlink_to(self.root / "absent-target")
        with self.assertRaisesRegex(ValueError, "OUTPUT_BUNDLE_EXISTS"):
            self.run_wrapper()
        self.assertEqual(self.calls, 0)

    def test_raw_names_cannot_escape_the_own_generated_directory(self):
        for name in ("../escape.ugpal", "/absolute.ugpal", "wrong.extension"):
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, "RAW_NAME"):
                self.run_wrapper(("--raw-name", name))
        self.assertEqual(self.calls, 0)
        self.assertFalse(self.bundle.exists())

    def test_existing_import_archive_refuses_before_any_engine_or_evidence_write(self):
        archive = self.raw.with_suffix(".inputs")
        archive.mkdir(parents=True)
        with self.assertRaisesRegex(ValueError, "IMPORT_ARCHIVE_EXISTS"):
            self.run_wrapper()
        self.assertEqual(self.calls, 0)
        self.assertFalse(self.bundle.exists())

    def test_archive_is_exact_copy_not_a_current_asset_substitution(self):
        cache = self.root / "godot/.godot/imported/native.scn"
        cache.parent.mkdir(parents=True)
        cache.write_bytes(b"actual synthetic imported bytes")
        digest = WRAPPER.digest(cache)
        spec = {"sources": [{"path": "res://.godot/imported/native.scn", "sha256": digest}]}
        archive = self.root / "archive"
        with mock.patch.object(WRAPPER, "ROOT", self.root):
            record = WRAPPER.archive_imports(spec, archive)
        self.assertEqual(record["files"], 1)
        self.assertEqual((archive / (digest + ".input")).read_bytes(), cache.read_bytes())
        cache.write_bytes(b"reimported identity")
        with mock.patch.object(WRAPPER, "ROOT", self.root), self.assertRaisesRegex(ValueError, "ARCHIVE_SOURCE"):
            WRAPPER.archive_imports(spec, self.root / "new-archive")

    def test_generated_import_metadata_is_archived_but_raw_assets_are_not(self):
        imported = self.root / "godot/demo/assets/body.glb.import"
        imported.parent.mkdir(parents=True)
        imported.write_bytes(b"frozen generated import parameters and resource identity")
        raw = imported.with_suffix("")
        raw.write_bytes(b"actual immutable GLB source")
        pins = [{"path": "res://demo/assets/" + path.name, "sha256": WRAPPER.digest(path)}
                for path in (imported, raw)]
        with mock.patch.object(WRAPPER, "ROOT", self.root):
            record = WRAPPER.archive_imports({"sources": pins}, self.root / "metadata-archive")
        self.assertEqual(record["files"], 1)
        self.assertEqual((self.root / "metadata-archive" / (pins[0]["sha256"] + ".input")).read_bytes(),
                         imported.read_bytes())
        self.assertFalse((self.root / "metadata-archive" / (pins[1]["sha256"] + ".input")).exists())

    def test_success_records_finite_source_without_a_qualification_claim(self):
        self.run_wrapper()
        report = json.loads((self.bundle / "verification.json").read_text())
        self.assertEqual((report["cases"], report["frames"], report["native_matrix_checks"]), (1, 2, 3))
        self.assertEqual(report["qualified_profiles"], 0)
        self.assertEqual(report["content_sha256"], hashlib.sha256(self.raw.read_bytes()).hexdigest())
        spec = json.loads((self.bundle / "bake-spec.json").read_text())
        self.assertEqual([row["id"] for row in spec["cases"]], ["fixture"])
        self.assertTrue(any(p["path"].endswith("underground_actor.gd") for p in spec["sources"]))

    def test_changed_real_source_after_capture_refuses_verification(self):
        self.drift = True
        with self.assertRaisesRegex(ValueError, "SOURCE_DRIFT"):
            self.run_wrapper()
        self.assertTrue((self.bundle / "bake-report.json").is_file())
        self.assertFalse((self.bundle / "verification.json").exists())

    def test_nonzero_exit_or_diagnostic_cannot_become_success(self):
        def rejected(command, **kwargs):
            kwargs["stdout"].write("ERROR: synthetic rejection\n")
            return types.SimpleNamespace(returncode=0)
        with self.assertRaisesRegex(ValueError, "DIAGNOSTIC"):
            self.run_wrapper(callback=rejected)
        self.assertFalse((self.bundle / "verification.json").exists())

    def test_unknown_case_does_not_write_a_relabelled_source_manifest(self):
        with self.assertRaisesRegex(ValueError, "CASE_NOT_IN_ACTUAL_MANIFEST"):
            self.run_wrapper(("--case", "invented"))
        self.assertFalse((self.bundle / "bake-spec.json").exists())
        self.assertFalse(self.raw.exists())


if __name__ == "__main__":
    unittest.main()
