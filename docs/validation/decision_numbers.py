#!/usr/bin/env python3
"""Refuse duplicate and malformed decision-record numbers.

Astra and the executor allocate ADR numbers independently, from different
sessions, with no shared counter. That has produced seven collisions
(0053, 0063, 0064, 0068, 0069, 0080 and 0089), each found by hand long after
the fact and each costing a renumber plus a link sweep. Nothing mechanical
was watching, so this watches.

It checks three things and nothing else:

  1. Every ``docs/decisions/NNNN-*.md`` has a unique NNNN.
  2. The leading ``# NNNN`` heading matches the filename's number, because a
     renumber that moves the file and forgets the heading leaves a record that
     greps as one number and reads as another.
  3. Filenames are well formed: four digits, a hyphen, a lowercase-kebab slug.

It deliberately does NOT require the sequence to be gapless. 0086 is an
unused number, and reserving the right to skip is what lets two authors
allocate without a lock.

Exit status is 0 on pass, 1 on any violation; the report goes to stdout as
one line per problem so a CI log shows every one rather than only the first.
"""

from __future__ import annotations

import pathlib
import re
import sys
from collections import defaultdict

DECISIONS = pathlib.Path(__file__).resolve().parents[1] / "decisions"
FILENAME = re.compile(r"^(\d{4})-[a-z0-9]+(?:-[a-z0-9]+)*\.md$")
HEADING = re.compile(r"^#\s*(\d{4})\b")


def check() -> list[str]:
	"""Return one message per violation, empty when the directory is clean."""
	problems: list[str] = []
	by_number: dict[str, list[str]] = defaultdict(list)

	for path in sorted(DECISIONS.glob("*.md")):
		if path.name == "README.md":
			continue
		match = FILENAME.match(path.name)
		if match is None:
			problems.append(f"{path.name}: not NNNN-lower-kebab-slug.md")
			continue
		number = match.group(1)
		by_number[number].append(path.name)

		heading = HEADING.match(path.read_text(encoding="utf-8").lstrip())
		if heading is None:
			problems.append(f"{path.name}: first heading does not open with its number")
		elif heading.group(1) != number:
			problems.append(
				f"{path.name}: filename says {number}, heading says {heading.group(1)}"
			)

	for number, names in sorted(by_number.items()):
		if len(names) > 1:
			problems.append(f"{number} is claimed by {len(names)} records: {', '.join(names)}")

	return problems


def main() -> int:
	"""Print the report and return the process exit status."""
	if not DECISIONS.is_dir():
		print(f"decision_numbers: FAIL -- no such directory {DECISIONS}")
		return 1
	problems = check()
	for problem in problems:
		print(f"decision_numbers: {problem}")
	total = len(list(DECISIONS.glob("[0-9][0-9][0-9][0-9]-*.md")))
	status = "FAIL" if problems else "PASS"
	print(f"decision_numbers: {status} -- {total} records, {len(problems)} problem(s)")
	return 1 if problems else 0


if __name__ == "__main__":
	sys.exit(main())
