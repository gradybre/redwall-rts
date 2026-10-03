#!/usr/bin/env python3
"""Runner control-flow regressions; all native invocations are mocked, never clearance evidence."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("mole_native_runner", Path(__file__).with_name("run_native.py"))
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class Runner(unittest.TestCase):
    def fixture(self, root):
        paths = ["godot/data/underground/mole-worker/v2/mole-worker.ugactor",
                 "godot/data/underground/mole-worker/evidence/native_sequence.gd",
                 "godot/demo/cast/underground_actor_content.gd", "godot/demo/cast/underground_actor.gd",
                 "godot/demo/cast/demo_actor.gd", "godot/demo/props/demo_props.gd",
                 "godot/demo/assets/underground-matrices/world-yaw-v1.ugyaw", "godot/demo/assets/manifest.json"]
        for name in paths:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"synthetic fixture")
        path = root / "godot/data/underground/mole-worker/v2/compilation.json"
        path.write_text(json.dumps({"content_sha256": "a" * 64,
            "presentation_budget": {"admitted_peak_bytes": 1}}))

    def exercise(self, bad_step=None):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            out = root / "output"
            calls = []

            def fake_run(command, **kwargs):
                step = len(calls)
                calls.append(command)
                kwargs["stdout"].write("WARNING: unexpected final diagnostic\n" if step == bad_step else "clean\n")
                if step == 1:
                    (out / "report.json").write_text(json.dumps({"failures": [], "poses": 731,
                        "assertions": 1575, "production_qualified": False}))
                return type("Result", (), {"returncode": 0})()

            with patch.object(runner, "ROOT", root), patch.object(runner, "digest", return_value="b" * 64), \
                    patch.object(runner.Path, "relative_to", return_value=Path("fixture")), \
                    patch.object(runner.subprocess, "run", side_effect=fake_run), \
                    patch.object(runner.sys, "argv", ["runner", str(out)]):
                if bad_step is None:
                    runner.main()
                else:
                    with self.assertRaisesRegex(ValueError, "NATIVE_REFUSED"):
                        runner.main()
            record = json.loads((out / "invocation.json").read_text())
            self.assertEqual(record["unexpected_diagnostic"], bad_step is not None)
            self.assertEqual(len(calls), 3 if bad_step is None else bad_step + 1)

    def test_final_zero_exit_with_unexpected_diagnostics_refuses(self):
        self.exercise(2)

    def test_first_bad_diagnostic_stops_before_native_execution(self):
        self.exercise(0)

    def test_clean_complete_mocked_sequence_passes(self):
        self.exercise()

    def test_existing_bundle_refuses_without_modifying_it(self):
        with tempfile.TemporaryDirectory() as directory:
            out = Path(directory)
            marker = out / "kept"
            marker.write_bytes(b"unchanged")
            with patch.object(runner.sys, "argv", ["runner", str(out)]), \
                    patch.object(runner.subprocess, "run") as native:
                with self.assertRaisesRegex(ValueError, "OUTPUT_EXISTS"):
                    runner.main()
                native.assert_not_called()
            self.assertEqual(marker.read_bytes(), b"unchanged")


if __name__ == "__main__":
    unittest.main(verbosity=2)
