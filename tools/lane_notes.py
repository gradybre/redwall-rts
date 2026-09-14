#!/usr/bin/env python3
"""Keep lane records in one file each, so two lanes can never conflict.

WHY THIS EXISTS. Every lane used to append a dated `## ` section to the end of
its task checklist. Two lanes finishing against the same checklist therefore
appended at the same place, and git called it a conflict every single time --
five for five on `09_persistence_replay_reliability.md` in one round, each one
resolved by hand as a mechanical keep-both. The resolution was never in doubt.
The conflict was structural: a shared append point guarantees it.

So a lane now writes exactly one NEW file under `docs/tasks/lanes/<task>/`,
named `<date>-<slug>.md`. Two new files with different names cannot conflict,
whatever order they land in. There is no shared index to append to either --
the directory listing IS the index, and this script renders it on demand.

A lane still ticks `[ ]` boxes in the checklist itself. That is real task state,
it is what a checklist is for, and distinct lines rarely collide.

    python3 tools/lane_notes.py            # print the index
    python3 tools/lane_notes.py --check    # CI: refuse the old pattern

CHECK is the part that matters. It refuses any task file that has grown a dated
`## ` section again, which is the habit coming back, and it refuses a lane file
that does not say which task and date it belongs to. Without that this is a
tidy-up that lasts until the next lane forgets.
"""

from __future__ import annotations

import argparse
import collections
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
TASKS = ROOT / "docs/tasks"
LANES = TASKS / "lanes"
DATE = re.compile(r"20\d{2}-\d{2}-\d{2}")
FILENAME = re.compile(r"^(20\d{2}-\d{2}-\d{2})-[a-z0-9-]+\.md$")


def lane_files() -> list[pathlib.Path]:
	"""Every lane record, sorted by task then date."""
	return sorted(LANES.glob("*/*.md"))


def check() -> list[str]:
	"""Refuse the shared-append pattern and malformed lane records."""
	problems: list[str] = []

	for path in sorted(TASKS.glob("*.md")):
		for number, line in enumerate(path.read_text(encoding="utf-8").split("\n"), 1):
			if line.startswith("## ") and DATE.search(line):
				problems.append(
					f"{path.relative_to(ROOT)}:{number} has a dated '## ' section. "
					f"Lane records go in docs/tasks/lanes/<task>/<date>-<slug>.md -- "
					f"appending here is what made five lanes conflict in one round")

	seen: dict[str, pathlib.Path] = {}
	for path in lane_files():
		relative = path.relative_to(ROOT)
		if not FILENAME.match(path.name):
			problems.append(f"{relative} is not named <date>-<slug>.md, lowercase")
		text = path.read_text(encoding="utf-8")
		if not text.startswith("# "):
			problems.append(f"{relative} does not open with an '# ' title")
		if not re.search(r"^Task: \S+", text, re.M):
			problems.append(f"{relative} has no 'Task:' line naming its checklist")
		if not re.search(r"^Date: 20\d{2}-\d{2}-\d{2}", text, re.M):
			problems.append(f"{relative} has no 'Date:' line")
		key = str(relative).lower()
		if key in seen:
			problems.append(f"{relative} collides with {seen[key].relative_to(ROOT)}")
		seen[key] = path

	for task_directory in sorted(p for p in LANES.glob("*") if p.is_dir()):
		matches = list(TASKS.glob(f"{task_directory.name}_*.md"))
		if not matches:
			problems.append(
				f"docs/tasks/lanes/{task_directory.name}/ names no task file")
	return problems


def index() -> str:
	"""Render the lane records grouped by task, newest first within each."""
	by_task: dict[str, list[tuple[str, str, pathlib.Path]]] = collections.defaultdict(list)
	for path in lane_files():
		text = path.read_text(encoding="utf-8")
		title = text.split("\n", 1)[0].lstrip("# ").strip()
		date_match = re.search(r"^Date: (20\d{2}-\d{2}-\d{2})", text, re.M)
		by_task[path.parent.name].append(
			(date_match.group(1) if date_match else "", title, path))

	out: list[str] = []
	for task in sorted(by_task):
		names = sorted(TASKS.glob(f"{task}_*.md"))
		out.append(f"\n{task} -- {names[0].name if names else 'unknown task'}")
		for date, title, path in sorted(by_task[task], reverse=True):
			out.append(f"  {date}  {title[:66]}")
			out.append(f"              {path.relative_to(ROOT)}")
	out.append(f"\n{len(lane_files())} lane record(s) across {len(by_task)} task(s)")
	return "\n".join(out)


def main() -> int:
	"""Print the index, or refuse a tree that has drifted back."""
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--check", action="store_true", help="CI: refuse the old pattern")
	args = parser.parse_args()

	if args.check:
		problems = check()
		for problem in problems:
			print(f"lane_notes: {problem}")
		print(f"lane_notes: {'REFUSE' if problems else 'PASS'} -- "
			f"{len(lane_files())} lane record(s), {len(problems)} problem(s)")
		return 1 if problems else 0

	print(index())
	return 0


if __name__ == "__main__":
	sys.exit(main())
