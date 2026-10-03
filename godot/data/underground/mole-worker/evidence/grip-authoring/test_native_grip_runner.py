"""Run the accepted diagnostic/overwrite regressions against the new authored-grip wrapper."""
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent


def load(name, path):
    specification = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


BASE = load("accepted_native_runner_tests", HERE.parent / "test_native_runner.py")
BASE.runner = load("native_grip_runner_tested", HERE / "run_native_grip.py")


class GripRunner(BASE.Runner):
    def fixture(self, root):
        super().fixture(root)
        shutil.copytree(root / "godot/data/underground/mole-worker/v2",
                        root / "godot/data/underground/mole-worker/firm-v1")
        for name in ("godot/data/underground/mole-worker/evidence/grip-authoring/native_grip_sequence.gd",
                     "godot/data/underground/mole-worker/mole_grip_source.gd", "godot/demo/tunnel/tunnel_ext.gd",
                     "fixture-runner.py"):
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"synthetic fixture")

    def assert_drift_refused(self, changed_step, delete=False):
        """These mock commands verify source timing; they never count as a native rendering run."""
        runner = BASE.runner
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            out = root / "output"
            target = root / "godot/data/underground/mole-worker/mole_grip_source.gd"
            key = str(target.relative_to(root))
            original = runner.digest(target)
            calls = []

            def fake_run(command, **kwargs):
                step = len(calls)
                calls.append(command)
                self.assertEqual(json.loads((out / "sources.json").read_text())[key], original)
                kwargs["stdout"].write("clean\n")
                if step == changed_step:
                    if delete:
                        target.unlink()
                    else:
                        target.write_bytes(b"changed during execution")
                if step == 1:
                    (out / "report.json").write_text(json.dumps({"failures": [], "poses": 731,
                        "assertions": 1578, "production_qualified": False}))
                return type("Result", (), {"returncode": 0})()

            with patch.object(runner, "ROOT", root), patch.object(runner, "__file__", str(root / "fixture-runner.py")), \
                    patch.object(runner.subprocess, "run", side_effect=fake_run), \
                    patch.object(runner.sys, "argv", ["runner", str(out)]):
                with self.assertRaisesRegex(ValueError, "SOURCE_DRIFT"):
                    runner.main()
            record = json.loads((out / "invocation.json").read_text())
            self.assertFalse(record["source_unchanged"])
            self.assertEqual(record["returncodes"], [0, 0, 0])
            self.assertEqual(json.loads((out / "sources.json").read_text())[key], original)
            self.assertEqual(json.loads((out / "sources-after.json").read_text())[key],
                             None if delete else runner.digest(target))

    def test_mutation_in_any_native_stage_preserves_prior_pins_and_refuses(self):
        for step in range(3):
            with self.subTest(step=step):
                self.assert_drift_refused(step)

    def test_deleted_source_is_recorded_and_refused(self):
        self.assert_drift_refused(2, delete=True)

    def test_dangling_output_symlink_refuses_before_resolution(self):
        runner = BASE.runner
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            missing = root / "missing-target"
            out = root / "output-link"
            out.symlink_to(missing, target_is_directory=True)
            with patch.object(runner.sys, "argv", ["runner", str(out)]), \
                    patch.object(runner.subprocess, "run") as native:
                with self.assertRaisesRegex(ValueError, "OUTPUT_EXISTS"):
                    runner.main()
                native.assert_not_called()
            self.assertTrue(out.is_symlink())
            self.assertFalse(missing.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
