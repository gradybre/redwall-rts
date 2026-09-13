#!/usr/bin/env python3
"""Self-test for merge_gate.py: prove each check refuses what it claims to.

A gate that only ever passes is indistinguishable from a gate that does
nothing. Every check below is driven by a synthetic ledger that contains the
exact defect the check exists for, and by a clean one that must not fire.

The L2 fixture is the real decision 0109 defect, reduced: injury.gd's packed
columns budgeted in section 3 while the Injury component's planned fields were
already budgeted in section 2.2. That cost 14336 bytes on master and was found
by running this check for the first time.
"""

import pathlib
import subprocess
import sys
import tempfile

GATE = pathlib.Path(__file__).resolve().parent / "merge_gate.py"

HEADER = "| Step | Governing record | Delta bytes | Running payload | Running payload + 8388608 reserve |\n|---|---|---:|---:|---:|\n"
GOOD_TRAIL = HEADER + (
	"| Baseline | — | — | 1000 | 8389608 |\n"
	"| First | decision 0001 | +24 | 1024 | 8389632 |\n"
	"| Second | decision 0002 | +16 | 1040 | 8389648 |\n")
BROKEN_CHAIN = HEADER + (
	"| Baseline | — | — | 1000 | 8389608 |\n"
	"| First | decision 0001 | +24 | 1024 | 8389632 |\n"
	"| Second | decision 0002 | +16 | 1048 | 8389656 |\n")
BROKEN_RESERVE = HEADER + (
	"| Baseline | — | — | 1000 | 8389608 |\n"
	"| First | decision 0001 | +24 | 1024 | 8389999 |\n")

CLEAN_ROWS = "| Injury | _kind, _severity | I32 | 4 | 2 | 512 | 4096 |\n"
CROSS_FORM = (
	"| Injury | kind, severity | I32 | 4 | 2 | 512 | 4096 |\n"
	"| Injury store | _kind, _severity | I32 | 4 | 2 | 512 | 4096 |\n")
SAME_BARE_NAME_TWICE = (
	"| Building | state | I32 | 4 | 1 | 512 | 2048 |\n"
	"| FarmPlot | state | I32 | 4 | 1 | 512 | 2048 |\n")
BAD_ARITHMETIC = "| Roster | _row_slot | I32 | 4 | 3 | 12 | 96 |\n"


def run(ledger: str, *args: str) -> tuple[int, str]:
	"""Run the gate against a synthetic architecture document."""
	with tempfile.TemporaryDirectory() as directory:
		path = pathlib.Path(directory) / "arch.md"
		path.write_text(ledger, encoding="utf-8")
		result = subprocess.run(
			[sys.executable, str(GATE), "--architecture", str(path), *args],
			capture_output=True, text=True)
		return result.returncode, result.stdout + result.stderr


def expect(name: str, code: int, output: str, refuse: bool, needle: str = "") -> None:
	"""Assert one case, printing the gate's own words when it disagrees."""
	if refuse and code == 0:
		raise AssertionError(f"{name}: gate PASSED a ledger it must refuse\n{output}")
	if not refuse and code != 0:
		raise AssertionError(f"{name}: gate REFUSED a clean ledger\n{output}")
	if needle and needle not in output:
		raise AssertionError(f"{name}: expected {needle!r} in\n{output}")
	print(f"  ok  {name}")


def main() -> int:
	"""Drive every check with a defect and with a clean input."""
	print("merge_gate self-test")
	expect("L1 clean chain", *run(GOOD_TRAIL), refuse=False)
	expect("L1 broken chain", *run(BROKEN_CHAIN), refuse=True, needle="L1 trail break")
	expect("L1 broken reserve", *run(BROKEN_RESERVE), refuse=True, needle="L1 reserve mismatch")
	expect("L2 one spelling only", *run(GOOD_TRAIL + CLEAN_ROWS), refuse=False)
	expect("L2 same bare name, different owners", *run(GOOD_TRAIL + SAME_BARE_NAME_TWICE),
		refuse=False)
	expect("L2 cross-form double budget", *run(GOOD_TRAIL + CROSS_FORM),
		refuse=True, needle="written both ways")
	expect("L3 row arithmetic", *run(GOOD_TRAIL + BAD_ARITHMETIC), refuse=True, needle="L3")

	with tempfile.TemporaryDirectory() as directory:
		report = pathlib.Path(directory) / "report.md"
		report.write_text("DEVIATIONS: none\nSURVIVED_MUTANTS: none\nBLOCKED: none\n")
		expect("A1 clean report", *run(GOOD_TRAIL, "--report", str(report)), refuse=False)
		report.write_text("DEVIATIONS: overrode the brief per SAVE-LAYOUT-R01\n"
			"SURVIVED_MUTANTS: none\nBLOCKED: none\n")
		expect("A1 declared deviation", *run(GOOD_TRAIL, "--report", str(report)),
			refuse=True, needle="declares DEVIATIONS")
		report.write_text("SURVIVED_MUTANTS: none\nBLOCKED: none\n")
		expect("A1 missing block", *run(GOOD_TRAIL, "--report", str(report)),
			refuse=True, needle="declares no DEVIATIONS")
		expect("A1 missing report", *run(GOOD_TRAIL, "--report", str(report) + ".absent"),
			refuse=True, needle="does not exist")

	print("merge_gate self-test: PASS")
	return 0


if __name__ == "__main__":
	sys.exit(main())
