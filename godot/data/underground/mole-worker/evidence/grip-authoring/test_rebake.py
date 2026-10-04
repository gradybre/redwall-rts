"""Adversarial source-closure and create-only bundle checks; no engine or production fixture."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("mole_grip_rebake_tested", Path(__file__).with_name("rebake.py"))
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class RebakeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.here = self.root / "godot/data/underground/mole-worker/evidence/grip-authoring"
        self.here.mkdir(parents=True)
        self.patch_root = patch.object(MODULE, "ROOT", self.root)
        self.patch_here = patch.object(MODULE, "HERE", self.here)
        self.patch_root.start()
        self.patch_here.start()
        self.addCleanup(self.patch_root.stop)
        self.addCleanup(self.patch_here.stop)
        self.addCleanup(self.temporary.cleanup)

    def setup_sources(self):
        names = [f"mole_digger.fixture-{index}" for index in range(7)]
        plan = {"clips": names, "groups": [{"states": {"travel": names[:3], "work": names[3:]}}], "revision": 1}
        (self.here.parents[1] / "source-plan.json").write_text(json.dumps(plan))
        files = {
            MODULE.GRIP_SOURCE: 'extends RefCounted\nconst C=preload("res://demo/cast/underground_actor_content.gd")\n',
            "res://demo/cast/underground_actor_content.gd": 'extends RefCounted\nconst A=preload("res://demo/cast/underground_actor.gd")\n',
            "res://demo/cast/underground_actor.gd": "extends RefCounted\n",
        }
        for name, text in files.items():
            path = self.actual(name)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        for name in ("bake_mole_grip_content.gd", "bake_underground_matrices.gd"):
            path = self.root / "tools" / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("extends SceneTree\n")
        helper = self.here / "accepted_palette.py"
        helper.write_text("# source closure fixture\n")
        cases = [{"id": name, "cast": "mole_digger", "attachments": ["mole_pick"]} for name in names]
        base = SimpleNamespace(build=lambda: {"sources": [], "cases": [dict(row) for row in cases]},
                               actual_path=self.actual, pin=self.pin)
        palette = SimpleNamespace(with_held_pick_states=lambda rows: rows, __file__=str(helper))
        return base, palette, helper

    def actual(self, name):
        return self.root / "godot" / name[6:] if name.startswith("res://") else Path(name)

    def pin(self, name):
        return {"path": name, "sha256": hashlib.sha256(self.actual(name).read_bytes()).hexdigest()}

    def test_transitive_helpers_and_indirect_python_producer_are_pinned(self):
        base, palette, helper = self.setup_sources()
        spec, plan = MODULE.build(base, palette)
        pins = {row["path"]: row["sha256"] for row in spec["sources"]}
        self.assertIn(str(helper.resolve()), pins)
        self.assertIn("res://demo/cast/underground_actor.gd", pins)
        self.assertTrue(all(row["derived_mesh_sha256"] == MODULE.DERIVED for row in spec["cases"]))
        self.assertTrue(all(name.endswith(".firm_grip_v1") for name in plan["clips"]))
        helper.write_text("# changed indirect producer\n")
        after, _ = MODULE.build(base, palette)
        after_pins = {row["path"]: row["sha256"] for row in after["sources"]}
        self.assertNotEqual(pins[str(helper.resolve())], after_pins[str(helper.resolve())])

    def test_missing_dependency_fails_instead_of_reusing_neighbor_source(self):
        base, palette, _ = self.setup_sources()
        self.actual("res://demo/cast/underground_actor.gd").unlink()
        with self.assertRaises(FileNotFoundError):
            MODULE.build(base, palette)

    def test_wrong_species_or_tool_case_cannot_enter_the_seven_state_batch(self):
        base, palette, _ = self.setup_sources()
        original = base.build
        def wrong():
            result = original()
            result["cases"][2]["cast"] = "badger_quarryman"
            return result
        base.build = wrong
        with self.assertRaisesRegex(ValueError, "EXACT_STATE_SET"):
            MODULE.build(base, palette)

    def test_existing_bundle_and_raw_remain_byte_identical_on_refusal(self):
        bundle = self.root / "old"
        bundle.mkdir()
        old = bundle / "report.json"
        old.write_bytes(b"preserved report")
        with patch.object(MODULE, "load") as loading:
            with self.assertRaisesRegex(ValueError, "OUTPUT_EXISTS"):
                MODULE.run(bundle, "new.ugpal")
            loading.assert_not_called()
        self.assertEqual(old.read_bytes(), b"preserved report")
        raw = self.root / "godot/demo/assets/underground-matrices/existing.ugpal"
        raw.parent.mkdir(parents=True)
        raw.write_bytes(b"preserved raw source")
        with self.assertRaisesRegex(ValueError, "OUTPUT_EXISTS"):
            MODULE.run(self.root / "absent", raw.name)
        self.assertEqual(raw.read_bytes(), b"preserved raw source")
        self.assertFalse((self.root / "absent").exists())

    def test_dangling_bundle_and_traversal_raw_names_refuse_before_writes(self):
        bundle = self.root / "link"
        bundle.symlink_to(self.root / "absent-target")
        with self.assertRaisesRegex(ValueError, "OUTPUT_EXISTS"):
            MODULE.run(bundle, "next.ugpal")
        with self.assertRaisesRegex(ValueError, "RAW_NAME"):
            MODULE.run(self.root / "new", "../outside.ugpal")
        self.assertFalse((self.root / "new").exists())
        self.assertFalse((self.root / "absent-target").exists())


if __name__ == "__main__":
    unittest.main()
