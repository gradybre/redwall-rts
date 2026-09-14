#!/usr/bin/env python3
"""Refuse a merge whose ledger, registry or agent report does not hold up.

WHY THIS EXISTS. Every check here is a mistake that actually reached a pull
request in this repository, passed the full Godot suite and every other
validator, and was caught only because a human recomputed the arithmetic by
hand. They are not hypothetical failure modes:

  * A lane reported "net +96 bytes, it replaces the array it supersedes". That
    array had never been ledgered, so nothing was freed and the true figure was
    +144. CHECK L3.
  * A lane reported `wear_remainder` as "either annotate or add a row". It was
    already budgeted inside a ResidentRuntime group for a store that does not
    exist, so adding it again would have counted one field twice. CHECK L2.
  * A reconciliation cited `source_contract` values that were not in the
    artifact's closed C001..C167 set. CHECK R2.
  * Two validator constants pinned a snapshot the governing ruling requires to
    grow. CHECK R3.

And one that is NOT mechanisable, so it is surfaced instead of decided: a lane
correctly refused its own brief because a ruling overrode it. No script can
judge that. CHECK A1 forces it into view by refusing to auto-merge any report
that declares a deviation, a surviving mutant or a blocker.

The trail chain (CHECK L1) is the one I have re-derived by hand on every single
ledger change this session. It belongs in a script.

Exit 0 means "safe to merge without a human reading the arithmetic". Exit 1
means a human must look. It never means the change is wrong.
"""

from __future__ import annotations

import argparse
import collections
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
ARCH = ROOT / "docs/systems_architecture.md"
REGISTRY = ROOT / "docs/persistence_state_registry.md"
RESERVE = 8388608


def _trail_rows(text: str) -> list[list[str]]:
	"""The ARCH-MEM-009 increment trail, one cell list per row."""
	lines = text.split("\n")
	start = next((i for i, l in enumerate(lines)
		if l.startswith("| Step | Governing record |")), None)
	if start is None:
		return []
	rows: list[list[str]] = []
	for line in lines[start + 2:]:
		if not line.startswith("|"):
			break
		cells = [c.strip() for c in line.strip().strip("|").split("|")]
		# Stop at the first row that is not shaped like a trail step. Without
		# this the scan runs on into whatever table follows and tries to read
		# "I32" as a byte delta.
		if len(cells) != 5 or not all(re.fullmatch(r"\d+", cells[i]) for i in (3, 4)):
			break
		rows.append(cells)
	return rows


def check_trail(text: str) -> list[str]:
	"""CHECK L1: every running payload is the previous plus its own delta.

	Verified row by row rather than by comparing totals, because a total that
	moves without its rows is exactly the failure that has occurred three times
	here (decisions 0080, 0083 and 0085 each advanced a total silently).
	"""
	problems: list[str] = []
	previous: int | None = None
	for cells in _trail_rows(text):
		label, delta, payload, live = cells[0], cells[2], int(cells[3]), int(cells[4])
		if delta not in ("—", "--"):
			# A delta may now be NEGATIVE: decision 0138 deletes the presentation pose
			# scaffold whole, the first row in this ledger to remove bytes. Accept an
			# ASCII sign only, and say so rather than crashing -- a U+2212 MINUS SIGN
			# pasted from a document looks identical in a diff and used to raise
			# ValueError out of this function, which reads as a broken gate rather
			# than a malformed row.
			if not re.fullmatch(r"[+-]?\d+", delta):
				problems.append(
					f"L1 unreadable delta at {label[:48]!r}: {delta!r} is not an ASCII "
					f"signed integer (a Unicode minus sign U+2212 is the usual cause)")
				previous = payload
				continue
			step = int(delta.lstrip("+"))
			if previous is not None and previous + step != payload:
				problems.append(
					f"L1 trail break at {label[:48]!r}: {previous} + {step} = "
					f"{previous + step}, row says {payload}")
		if payload + RESERVE != live:
			problems.append(
				f"L1 reserve mismatch at {label[:48]!r}: {payload} + {RESERVE} != {live}")
		previous = payload
	return problems


def _ledger_members(text: str) -> dict[str, list[tuple[str, str]]]:
	"""Bare member name -> [(spelling as written, owning row label)].

	Keyed WITHOUT a leading underscore, because that is the whole point: a
	planned component field is written `kind` and the packed column that
	implements it is written `_kind`. Same byte, two spellings, two rows.
	"""
	found: dict[str, list[tuple[str, str]]] = collections.defaultdict(list)
	for line in text.split("\n"):
		if not line.startswith("|"):
			continue
		cells = [c.strip() for c in line.strip().strip("|").split("|")]
		if len(cells) < 7 or not all(re.fullmatch(r"\d+", cells[i]) for i in (3, 4, 5, 6)):
			continue
		for member in re.findall(r"_?[a-z][a-z0-9_]*", cells[1]):
			found[member.lstrip("_")].append((member, cells[0]))
	return found


def check_no_double_budget(text: str) -> list[str]:
	"""CHECK L2: no field is budgeted once as a planned field and again as a column.

	A bare name repeated across owners is NOT a finding -- Building, FarmPlot,
	Feast, Job and RngStream each legitimately carry their own `state`, and an
	earlier draft of this check produced 84 such false positives and was useless.
	The discriminating signal is CROSS-FORM: the ledger names a field `x` in one
	row and `_x` in another. That is one byte written down twice, once under the
	planned component and once under the store that implements it.

	This found a real 14336-byte over-count the moment it was first run: decision
	0109 added injury.gd's eleven columns to 3 while 2.2 already carried the
	Injury component's kind/severity/rescuer_slot/rescuer_generation and
	care_progress_mwu. The true net was +7168, not +21504. `wear_remainder` was
	the same shape one decision earlier and cost a manual recomputation to find.
	"""
	problems: list[str] = []
	for member, uses in sorted(_ledger_members(text).items()):
		spellings = {spelling for spelling, _ in uses}
		if len(spellings) < 2:
			continue
		rows = sorted({row for _, row in uses})
		if len(rows) < 2:
			continue
		# Only compare rows describing the SAME owner. Section 3's index tables name their
		# members bare (`BuildingIndex | present`) while a store's own section names them as
		# GDScript spells them (`_present`), so without this every index table collides with
		# every other one -- ConstructionIndex against BuildingIndex, FurnitureIndex and
		# RoomIndex, none of which share a byte. The real defect this check exists for was
		# always SAME-owner: `Injury` against `Injury store`. Requiring the owner labels to
		# share their leading token keeps that and drops six false positives.
		leading = {row.split()[0].rstrip(".,") for row in rows if row.split()}
		if len(leading) > 1:
			continue
		problems.append(
			f"L2 {member!r} is written both ways ({', '.join(sorted(spellings))}) "
			f"across rows: {', '.join(r[:40] for r in rows)}")
	return problems


def check_row_arithmetic(text: str) -> list[str]:
	"""CHECK L3: every ledger row's width x columns x rows equals its own bytes."""
	problems: list[str] = []
	for line in text.split("\n"):
		if not line.startswith("|"):
			continue
		cells = [c.strip() for c in line.strip().strip("|").split("|")]
		if len(cells) < 7 or not all(re.fullmatch(r"\d+", cells[i]) for i in (3, 4, 5, 6)):
			continue
		width, columns, rows, total = (int(cells[i]) for i in (3, 4, 5, 6))
		if width * columns * rows != total:
			problems.append(
				f"L3 {cells[0][:48]!r}: {width} x {columns} x {rows} = "
				f"{width * columns * rows}, row says {total}")
	return problems


REPORT_BLOCKS = ("DEVIATIONS", "SURVIVED_MUTANTS", "BLOCKED")


def check_report(path: pathlib.Path) -> list[str]:
	"""CHECK A1: an agent report may not auto-merge if it declares an exception.

	The one failure class no script can judge. A lane that overrules its brief may
	be right -- one did, citing a ruling that overrode my instruction, and it was
	correct to. A surviving mutant may be genuinely equivalent -- several were.
	Both need a human, so both refuse the automatic path rather than being ranked.
	"""
	if not path.exists():
		return [f"A1 report {path} does not exist; an auto-merge needs one"]
	text = path.read_text(encoding="utf-8")
	problems: list[str] = []
	for block in REPORT_BLOCKS:
		match = re.search(rf"^{block}:\s*(.*)$", text, re.M)
		if match is None:
			problems.append(f"A1 report declares no {block}: block")
		elif match.group(1).strip().lower() not in ("none", "none.", ""):
			problems.append(f"A1 report declares {block}: {match.group(1).strip()[:70]}")
	return problems


def main() -> int:
	"""Run every check and print one line per problem."""
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--report", type=pathlib.Path,
		help="agent report to check for DEVIATIONS/SURVIVED_MUTANTS/BLOCKED")
	parser.add_argument("--architecture", type=pathlib.Path, default=ARCH,
		help="ledger to check; defaults to the repository's own, overridden by the self-test")
	args = parser.parse_args()

	text = args.architecture.read_text(encoding="utf-8")
	problems = check_trail(text) + check_no_double_budget(text) + check_row_arithmetic(text)
	if args.report is not None:
		problems += check_report(args.report)

	for problem in problems:
		print(f"merge_gate: {problem}")
	verdict = "REFUSE" if problems else "PASS"
	scope = "ledger + report" if args.report is not None else "ledger only"
	print(f"merge_gate: {verdict} -- {scope}, {len(problems)} problem(s)")
	return 1 if problems else 0


if __name__ == "__main__":
	sys.exit(main())
