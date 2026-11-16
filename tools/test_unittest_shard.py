#!/usr/bin/env python3
"""Self-tests for tools/unittest_shard.py (decision 1244), against throwaway modules and the real workflow."""
from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest

REPO = Path(__file__).resolve().parent.parent
TOOL = REPO / "tools/unittest_shard.py"
WORKFLOW = REPO / ".github/workflows/tests.yml"

MODULE = textwrap.dedent('''
    import unittest
    from fixture_helper import Imported

    class Beta(unittest.TestCase):
        setups = 0
        @classmethod
        def setUpClass(cls):
            cls.setups += 1
            print("SETUP Beta", cls.setups)
    {beta}

    class Alpha(unittest.TestCase):
    {alpha}
''')
HELPER = textwrap.dedent('''
    import unittest
    class Imported(unittest.TestCase):
        def test_from_another_module(self):
            pass
''')


def methods(names: list[str], body: str = "pass") -> str:
    """Return indented test methods with the given names and body."""
    return "\n".join(f"    def {name}(self):\n        {body}" for name in names)


class UnittestShardTests(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory()
        self.root = Path(self.directory.name)
        (self.root / "fixture_helper.py").write_text(HELPER)

    def tearDown(self) -> None:
        self.directory.cleanup()

    def module(self, beta: str, alpha: str) -> Path:
        path = self.root / "test_fixture.py"
        path.write_text(MODULE.format(beta=beta, alpha=alpha))
        return path

    def run_tool(self, *args: str) -> subprocess.CompletedProcess:
        return subprocess.run([sys.executable, str(TOOL), *args], capture_output=True, text=True, cwd=self.root)

    def listed(self, path: Path, shard: str) -> list[str]:
        result = self.run_tool(str(path), "--shard", shard, "--list")
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.splitlines()[1:]

    def test_shards_are_disjoint_and_exhaustive(self) -> None:
        path = self.module(methods([f"test_b{i}" for i in range(7)]), methods([f"test_a{i}" for i in range(5)]))
        everything = set(self.listed(path, "0/1"))
        self.assertEqual(len(everything), 13)
        self.assertIn("Imported.test_from_another_module", everything)
        for count in (2, 3, 4):
            shards = [self.listed(path, f"{index}/{count}") for index in range(count)]
            combined = [test_id for shard in shards for test_id in shard]
            self.assertEqual(len(combined), len(set(combined)), f"overlap at count {count}")
            self.assertEqual(set(combined), everything, f"gap at count {count}")

    def test_membership_is_by_sorted_id_position(self) -> None:
        path = self.module(methods(["test_b0", "test_b1"]), methods(["test_a0", "test_a1"]))
        ordered = sorted(self.listed(path, "0/1"))
        self.assertEqual(sorted(self.listed(path, "0/2")), ordered[0::2])
        self.assertEqual(sorted(self.listed(path, "1/2")), ordered[1::2])

    def test_class_setup_runs_once_per_class_in_a_shard(self) -> None:
        path = self.module(methods([f"test_b{i}" for i in range(6)]), methods(["test_a0"]))
        result = self.run_tool(str(path), "--shard", "0/2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count("SETUP Beta"), 1, result.stdout)
        self.assertIn("shard 0/2: 4 of 8 test(s)", result.stdout)

    def test_a_failing_selected_test_fails_the_shard(self) -> None:
        path = self.module(methods(["test_b0"], "self.fail('boom')"), methods(["test_a0"]))
        owner = next(index for index in range(2) if "Beta.test_b0" in self.listed(path, f"{index}/2"))
        self.assertEqual(self.run_tool(str(path), "--shard", f"{owner}/2").returncode, 1)
        self.assertEqual(self.run_tool(str(path), "--shard", f"{1 - owner}/2").returncode, 0)

    def test_an_error_in_class_setup_fails_the_shard(self) -> None:
        path = self.module(methods(["test_b0"]), methods(["test_a0"]))
        path.write_text(path.read_text().replace("cls.setups += 1", "raise RuntimeError('setup')"))
        self.assertEqual(self.run_tool(str(path), "--shard", "0/1").returncode, 1)

    def test_an_empty_shard_fails(self) -> None:
        path = self.module(methods(["test_b0"]), methods(["test_a0"]))
        result = self.run_tool(str(path), "--shard", "4/5")
        self.assertEqual(result.returncode, 1)
        self.assertIn("empty shard", result.stderr)

    def test_malformed_shards_are_refused(self) -> None:
        path = self.module(methods(["test_b0"]), methods(["test_a0"]))
        for shard in ("2/2", "-1/2", "0/0", "1", "a/b"):
            self.assertEqual(self.run_tool(str(path), "--shard", shard).returncode, 2, shard)

    def test_the_workflow_runs_the_memory_budget_tests_only_through_matrix_sized_shards(self) -> None:
        workflow = WORKFLOW.read_text()
        self.assertEqual(workflow.count("tools/test_underground_memory_budget.py"), 1)
        self.assertIn("python3 tools/unittest_shard.py tools/test_underground_memory_budget.py\n"
                      "          --shard ${{ strategy.job-index }}/${{ strategy.job-total }}", workflow)
        self.assertIn("needs: [godot-shards, godot-gates, contracts, underground-memory]", workflow)
        self.assertIn('"$UNDERGROUND_MEMORY_RESULT"; do', workflow)


if __name__ == "__main__":
    unittest.main(verbosity=2)
