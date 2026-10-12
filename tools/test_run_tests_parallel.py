#!/usr/bin/env python3
"""Fault-test tools/run_tests_parallel.sh (decision 1895) against a fake shard runner and a fake verify.

The tool is copied into a scratch repository whose tools/run_tests.sh and tools/ci_test_shards.py are fakes that
record how they were called and fail on request, so every case runs in about a second without Godot:

    python3 tools/test_run_tests_parallel.py
"""
from __future__ import annotations

import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parent.parent
TOOL = REPO / "tools/run_tests_parallel.sh"

# The fake shard runner: records its arguments and its start and end times, prints the three summary lines, and
# writes its report unless FAKE_FAIL lists its index (exit 1, no report), FAKE_NO_REPORT does (exit 0, no
# report) or FAKE_EXIT_WITH_REPORT does (exit 1 after writing the report).
FAKE_RUN_TESTS = r'''#!/usr/bin/env python3
import os, sys, time
args = sys.argv[1:]
assert len(args) == 4 and args[0] == "--shard" and args[2] == "--output-dir", args
index, count = args[1].split("/")
out = args[3]
def listed(name):
    return index in os.environ.get(name, "").split(",")
with open(os.path.join(out, "calls-" + index), "a") as calls:
    calls.write(" ".join(args) + " start=%f\n" % time.time())
time.sleep(float(os.environ.get("FAKE_SLEEP", "0")))
with open(os.path.join(out, "calls-" + index), "a") as calls:
    calls.write("end=%f\n" % time.time())
print("1 test(s), 2 assertion(s), 0 failure(s)")
print("diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; "
      "leaked at exit: 0 object(s), 0 resource(s)")
if listed("FAKE_FAIL"):
    print("error: 1 failing test(s).")
    sys.exit(1)
print("log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).")
print("ok: 1 tests, 2 assertions, 0 failures.")
if not listed("FAKE_NO_REPORT"):
    open(os.path.join(out, "shard-%s.json" % index), "w").write("{}\n")
sys.exit(1 if listed("FAKE_EXIT_WITH_REPORT") else 0)
'''

# The fake verify: passes exactly when shard-0..COUNT-1.json are all present and nothing else is.
FAKE_SHARDS = r'''#!/usr/bin/env python3
import glob, os, sys
args = sys.argv[1:]
assert args[0] == "verify", args
reports = args[args.index("--reports") + 1]
count = int(args[args.index("--count") + 1])
open(os.path.join(reports, "verify-args"), "w").write(" ".join(args) + "\n")
found = sorted(os.path.basename(p) for p in glob.glob(os.path.join(reports, "shard-*.json")))
if found != sorted("shard-%d.json" % i for i in range(count)):
    print("error: missing or extra shard reports", file=sys.stderr)
    sys.exit(1)
print("ok: %d suite files executed exactly once across %d shards" % (count, count))
'''

WORKFLOW = """jobs:
  godot:
    steps:
      - run: python3 tools/ci_test_shards.py verify --reports artifacts/test-shards --count 3
"""


class ParallelRunner(unittest.TestCase):
    def setUp(self) -> None:
        scratch = tempfile.TemporaryDirectory(prefix="redwall-parallel-test-")
        self.addCleanup(scratch.cleanup)
        self.root = Path(scratch.name)
        (self.root / "tools").mkdir()
        (self.root / "godot/.godot").mkdir(parents=True)
        (self.root / ".github/workflows").mkdir(parents=True)
        (self.root / ".github/workflows/tests.yml").write_text(WORKFLOW)
        shutil.copy(TOOL, self.root / "tools/run_tests_parallel.sh")
        self._executable("tools/run_tests.sh", FAKE_RUN_TESTS)
        self._executable("tools/ci_test_shards.py", FAKE_SHARDS)
        self.reports = self.root / "reports"

    def _executable(self, relative: str, text: str) -> None:
        path = self.root / relative
        path.write_text(text)
        path.chmod(path.stat().st_mode | stat.S_IXUSR)

    def run_tool(self, *args: str, **env: str) -> subprocess.CompletedProcess:
        environment = dict(os.environ, **env)
        command = ["bash", str(self.root / "tools/run_tests_parallel.sh"), *args]
        return subprocess.run(command, cwd=self.root, env=environment, capture_output=True, text=True, timeout=60)

    def calls(self) -> list[str]:
        return sorted(line.split(" start=")[0] for path in self.reports.glob("calls-*")
                      for line in path.read_text().splitlines() if " start=" in line)

    def test_defaults_to_ci_count_and_runs_every_shard_once_then_verify(self) -> None:
        result = self.run_tool("--output-dir", str(self.reports))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.calls(), [f"--shard {i}/3 --output-dir {self.reports}" for i in range(3)])
        self.assertIn("--count 3", (self.reports / "verify-args").read_text())
        self.assertIn("ok: every shard passed and verify passed", result.stdout)
        self.assertIn("3 shards, 4 at a time", result.stdout, "the documented default of 4 jobs")

    def test_shard_count_option_is_passed_to_every_shard_and_to_verify(self) -> None:
        result = self.run_tool("--shards", "5", "--jobs", "2", "--output-dir", str(self.reports))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.calls(), [f"--shard {i}/5 --output-dir {self.reports}" for i in range(5)])
        self.assertIn("--count 5", (self.reports / "verify-args").read_text())

    def test_prints_each_shards_summary_lines_and_the_merged_verify(self) -> None:
        result = self.run_tool("--output-dir", str(self.reports))
        for index in range(3):
            self.assertIn(f"--- shard {index}/3: exit 0", result.stdout)
        self.assertEqual(result.stdout.count("1 test(s), 2 assertion(s), 0 failure(s)"), 3)
        self.assertEqual(result.stdout.count("ok: 1 tests, 2 assertions, 0 failures."), 3)
        self.assertIn("ok: 3 suite files executed exactly once across 3 shards", result.stdout)

    def test_a_failing_shard_fails_the_run(self) -> None:
        result = self.run_tool("--output-dir", str(self.reports), FAKE_FAIL="1")
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("--- shard 1/3: exit 1", result.stdout)
        self.assertIn("error: 1 failing test(s).", result.stdout)

    def test_a_shard_that_fails_after_writing_its_report_still_fails_the_run(self) -> None:
        result = self.run_tool("--output-dir", str(self.reports), FAKE_EXIT_WITH_REPORT="2")
        self.assertIn("ok: 3 suite files", result.stdout, "verify itself passes here")
        self.assertEqual(result.returncode, 1, result.stdout)

    def test_a_missing_report_fails_the_run_through_verify(self) -> None:
        result = self.run_tool("--output-dir", str(self.reports), FAKE_NO_REPORT="0")
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("missing or extra shard reports", result.stderr)

    def test_jobs_bounds_how_many_shards_run_at_once(self) -> None:
        # A loaded runner may start the fakes unevenly, so with 3 jobs at least 2 must overlap and never more than 3.
        for jobs, lowest, highest in (("1", 1, 1), ("3", 2, 3)):
            with self.subTest(jobs=jobs):
                reports = self.root / f"reports-{jobs}"
                result = self.run_tool("--jobs", jobs, "--output-dir", str(reports), FAKE_SLEEP="1.5")
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                spans = []
                for path in reports.glob("calls-*"):
                    lines = path.read_text().splitlines()
                    spans.append((float(lines[0].split("start=")[1]), float(lines[1].split("end=")[1])))
                peak = max(sum(1 for start, end in spans if start <= moment < end) for moment, _ in spans)
                self.assertTrue(lowest <= peak <= highest, f"{peak} shards at once with --jobs {jobs}")

    def test_a_non_empty_output_directory_is_refused_before_any_shard_runs(self) -> None:
        self.reports.mkdir()
        (self.reports / "shard-0.json").write_text("{}\n")
        result = self.run_tool("--output-dir", str(self.reports))
        self.assertEqual(result.returncode, 2)
        self.assertIn("not empty", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_a_default_output_directory_is_created_and_reported(self) -> None:
        result = self.run_tool(TMPDIR=str(self.root))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        made = list(self.root.glob("redwall-shards.*"))
        self.assertEqual(len(made), 1)
        self.assertIn(f"/{made[0].name}\n", result.stdout.split("load before")[0], "the directory is named")

    def test_bad_arguments_are_refused(self) -> None:
        for args in (["--shards", "0"], ["--jobs", "x"], ["--jobs"], ["--bogus", "1"], ["--shards", "-1"]):
            with self.subTest(args=args):
                result = self.run_tool(*args, "--output-dir", str(self.root / "unused"))
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        trailing = self.run_tool("--output-dir", str(self.root / "unused"), "--jobs")
        self.assertEqual(trailing.returncode, 2, "an option missing its value is a usage error")
        self.assertIn("usage:", trailing.stderr)
        self.assertFalse((self.root / "unused").exists() and any((self.root / "unused").iterdir()))

    def test_an_unimported_project_is_refused(self) -> None:
        (self.root / "godot/.godot").rmdir()
        result = self.run_tool("--output-dir", str(self.reports))
        self.assertEqual(result.returncode, 2)
        self.assertIn("not imported", result.stderr)

    def test_without_a_ci_count_the_shard_count_must_be_given(self) -> None:
        (self.root / ".github/workflows/tests.yml").write_text("jobs: {}\n")
        result = self.run_tool("--output-dir", str(self.reports))
        self.assertEqual(result.returncode, 2)
        self.assertIn("could not read CI's shard count", result.stderr)
        self.assertEqual(self.run_tool("--shards", "2", "--output-dir", str(self.reports)).returncode, 0)

    def test_the_default_shard_count_is_the_real_workflows(self) -> None:
        workflow = (REPO / ".github/workflows/tests.yml").read_text()
        self.assertIn("ci_test_shards.py verify --reports artifacts/test-shards --count", workflow)
        shutil.copy(REPO / ".github/workflows/tests.yml", self.root / ".github/workflows/tests.yml")
        count = workflow.split("ci_test_shards.py verify --reports artifacts/test-shards --count ")[1].split()[0]
        result = self.run_tool("--output-dir", str(self.reports))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(self.calls()), int(count))
        self.assertIn(f"run_tests.sh --shard ${{{{ matrix.shard }}}}/{count}", workflow)


if __name__ == "__main__":
    unittest.main()
