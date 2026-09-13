#!/usr/bin/env python3
"""Emit the largest conflict-free set of tasks that can be dispatched right now.

The orchestrator's whole job reduces to one question asked over and over: given
what is already running, what else can start without two agents editing the same
file? Answering it by memory is how two lanes were dispatched against branches
that did not contain the files they were told to edit, and how three lanes were
briefed against an artifact that was untracked in the working tree.

CONFLICT RULE. Two tasks conflict when their `owns` entries intersect. An entry
ending in "/" is a directory prefix and covers everything beneath it. A task is
dispatchable when:

  1. every dependency is `done`,
  2. its gate is cleared, and
  3. nothing it owns is owned by a task that is `in_flight` or `review`, or by
     a task already selected in this same plan.

Rule 3 includes `review`: a task whose PR is open but unmerged still owns its
files, because a second lane editing them produces exactly the merge conflict
this whole system exists to avoid.

GATES. `none` clears itself. `astra_ruling` clears when the named request is
answered. `brendan_art` clears ONLY from docs/planning/art_approvals.json, and
only when a human wrote `approved` there. No flag, no environment variable and
no argument to this script can clear an art gate -- if it could, the gate would
be decoration. Meshy credits are real money and decision 0002 forbids bulk
creature generation before proportion approval.

Exit 0 always in `plan` mode; this reports, it does not judge. `--validate`
exits 1 on a malformed graph and is what CI runs.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
QUEUE = ROOT / "docs/planning/work_queue.json"
APPROVALS = ROOT / "docs/planning/art_approvals.json"

HOLDS_FILES = ("in_flight", "review")
TERMINAL = ("done",)


def _owns(task: dict) -> list[str]:
	"""The file paths a task claims. A trailing slash is a directory prefix."""
	return list(task.get("owns", ()))


def _conflicts(left: list[str], right: list[str]) -> list[str]:
	"""Paths claimed by both sides, honouring directory prefixes."""
	hits: list[str] = []
	for a in left:
		for b in right:
			if a == b or (a.endswith("/") and b.startswith(a)) or (
					b.endswith("/") and a.startswith(b)):
				hits.append(a if a == b else f"{a} ~ {b}")
	return hits


def _approved(approvals: dict, approval_id: str | None) -> bool:
	"""True only when a human wrote `approved` against this id."""
	if approval_id is None:
		return False
	for entry in approvals.get("approvals", ()):
		if entry.get("id") == approval_id:
			return entry.get("status") == "approved"
	return False


def _gate_state(task: dict, approvals: dict) -> tuple[bool, str]:
	"""Is the gate clear, and why not if it is not."""
	gate = task.get("gate", "none")
	if gate == "none":
		return True, ""
	if gate == "brendan_art":
		if _approved(approvals, task.get("approval_id")):
			return True, ""
		return False, f"art approval {task.get('approval_id')!r} is not approved"
	if gate == "astra_ruling":
		if task.get("astra_answered") is True:
			return True, ""
		return False, f"awaiting Astra: {task.get('astra_request', 'unnamed request')}"
	return False, f"unknown gate {gate!r}"


def plan(queue: dict, approvals: dict) -> dict:
	"""Choose a conflict-free dispatch set and explain every exclusion."""
	tasks = {t["id"]: t for t in queue["tasks"]}
	done = {i for i, t in tasks.items() if t["status"] in TERMINAL}

	held: list[str] = []
	for task in tasks.values():
		if task["status"] in HOLDS_FILES:
			held += _owns(task)

	dispatch: list[dict] = []
	claimed: list[str] = list(held)
	withheld: list[dict] = []

	# Deterministic order: a plan that reshuffles between runs is unreviewable.
	for task in sorted(queue["tasks"], key=lambda t: t["id"]):
		if task["status"] != "blocked" and task["status"] != "ready":
			continue
		missing = [d for d in task.get("depends_on", ()) if d not in done]
		if missing:
			withheld.append({"id": task["id"], "reason": f"depends on {', '.join(missing)}"})
			continue
		clear, why = _gate_state(task, approvals)
		if not clear:
			withheld.append({"id": task["id"], "reason": why})
			continue
		collision = _conflicts(_owns(task), claimed)
		if collision:
			withheld.append({"id": task["id"], "reason": f"file conflict: {collision[0]}"})
			continue
		dispatch.append({"id": task["id"], "title": task["title"],
			"agent": task.get("agent", "game-coder"), "owns": _owns(task)})
		claimed += _owns(task)

	return {
		"dispatch": dispatch,
		"withheld": withheld,
		"in_flight": sorted(i for i, t in tasks.items() if t["status"] == "in_flight"),
		"awaiting_merge": sorted(i for i, t in tasks.items() if t["status"] == "review"),
		"done": sorted(done),
	}


def validate(queue: dict, approvals: dict) -> list[str]:
	"""Structural checks. A malformed graph dispatches nothing and says nothing."""
	problems: list[str] = []
	ids = [t["id"] for t in queue["tasks"]]
	for duplicate in {i for i in ids if ids.count(i) > 1}:
		problems.append(f"duplicate task id {duplicate!r}")
	known = set(ids)
	for task in queue["tasks"]:
		for dependency in task.get("depends_on", ()):
			if dependency not in known:
				problems.append(f"{task['id']} depends on unknown {dependency!r}")
		if task.get("status") not in ("blocked", "ready", "in_flight", "review", "done"):
			problems.append(f"{task['id']} has status {task.get('status')!r}")
		if task.get("gate") == "brendan_art" and task.get("approval_id") is None:
			problems.append(f"{task['id']} is art-gated with no approval_id")
		if not _owns(task):
			problems.append(f"{task['id']} owns no files, so nothing serialises it")

	# Cycle detection. A cycle silently withholds every task in it forever.
	colour: dict[str, int] = {}

	def visit(node: str, trail: list[str]) -> None:
		if colour.get(node) == 1:
			problems.append("dependency cycle: " + " -> ".join(trail + [node]))
			return
		if colour.get(node) == 2:
			return
		colour[node] = 1
		for nxt in {t["id"]: t for t in queue["tasks"]}.get(node, {}).get("depends_on", ()):
			if nxt in known:
				visit(nxt, trail + [node])
		colour[node] = 2

	for task_id in ids:
		visit(task_id, [])

	for entry in approvals.get("approvals", ()):
		if entry.get("status") not in ("pending", "approved", "denied"):
			problems.append(f"approval {entry.get('id')!r} has status {entry.get('status')!r}")
		if entry.get("status") == "approved" and not entry.get("decided_by"):
			problems.append(f"approval {entry.get('id')!r} is approved by nobody")
	return problems


def main() -> int:
	"""Print a dispatch plan, or validate the graph for CI."""
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--validate", action="store_true", help="check the graph and exit")
	parser.add_argument("--json", action="store_true", help="machine-readable plan")
	args = parser.parse_args()

	queue = json.loads(QUEUE.read_text(encoding="utf-8"))
	approvals = json.loads(APPROVALS.read_text(encoding="utf-8"))

	if args.validate:
		problems = validate(queue, approvals)
		for problem in problems:
			print(f"dispatch_plan: {problem}")
		print(f"dispatch_plan: {'REFUSE' if problems else 'PASS'} -- "
			f"{len(queue['tasks'])} tasks, {len(problems)} problem(s)")
		return 1 if problems else 0

	result = plan(queue, approvals)
	if args.json:
		print(json.dumps(result, indent=2))
		return 0

	print(f"DISPATCH NOW ({len(result['dispatch'])}):")
	for task in result["dispatch"]:
		print(f"  {task['id']:<20} [{task['agent']}] {task['title']}")
		for path in task["owns"]:
			print(f"      owns {path}")
	print(f"\nRUNNING ({len(result['in_flight'])}): {', '.join(result['in_flight']) or '--'}")
	print(f"AWAITING MERGE ({len(result['awaiting_merge'])}): "
		f"{', '.join(result['awaiting_merge']) or '--'}")
	print(f"\nWITHHELD ({len(result['withheld'])}):")
	for task in result["withheld"]:
		print(f"  {task['id']:<20} {task['reason']}")
	return 0


if __name__ == "__main__":
	sys.exit(main())
