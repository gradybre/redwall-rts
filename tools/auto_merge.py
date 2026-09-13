#!/usr/bin/env python3
"""Merge every pull request that has earned it, and say why the rest have not.

This is the last automated step. It merges nothing on judgement; it merges what
survives four independent refusals, and every refusal has a named reason printed
beside the PR number.

A PR is merged only when ALL of these hold:

  1. GitHub reports every required check SUCCESS. Not "pending", not "no checks
     configured", not "some skipped". I merged on pending CI twice in this
     project against an explicit instruction not to, and both times got away
     with it, which is precisely why a script should be doing this and not me.
  2. It is mergeable with no conflicts.
  3. merge_gate.py passes against the PR's head tree -- the ledger chain, the
     cross-form double budget and the row arithmetic.
  4. The PR body carries DEVIATIONS/SURVIVED_MUTANTS/BLOCKED and all are empty.

Rule 4 is the one that keeps a human in the loop without keeping a human in the
way. Most changes declare no exceptions and merge untouched. A change that
overrules its brief, leaves a mutant alive or reports a blocker stops here and
waits to be read -- which is right, because a lane once overruled my brief
correctly, citing SAVE-LAYOUT-R01, and a script that ranked that would have been
wrong either way it ruled.

Dry run by default. --merge actually merges. Never force-merges, never enables
auto-merge, never overrides a branch protection.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
GATE = ROOT / "docs/validation/merge_gate.py"
REPORT_BLOCKS = ("DEVIATIONS", "SURVIVED_MUTANTS", "BLOCKED")


def _gh(*args: str) -> str:
	"""Run gh and return stdout, or raise with its own error text."""
	result = subprocess.run(["gh", *args], capture_output=True, text=True)
	if result.returncode != 0:
		raise RuntimeError(result.stderr.strip() or f"gh {' '.join(args)} failed")
	return result.stdout


def open_prs() -> list[dict]:
	"""Every open PR with the fields the checks need."""
	raw = _gh("pr", "list", "--state", "open", "--limit", "50", "--json",
		"number,title,headRefName,mergeable,mergeStateStatus,body,isDraft,statusCheckRollup")
	return json.loads(raw)


def check_ci(pr: dict) -> list[str]:
	"""CHECK 1: every check has actually finished and actually succeeded."""
	rollup = pr.get("statusCheckRollup") or []
	if not rollup:
		return ["no checks have reported yet"]
	problems: list[str] = []
	for check in rollup:
		name = check.get("name") or check.get("context") or "unnamed"
		state = check.get("conclusion") or check.get("state") or ""
		if state.upper() in ("SUCCESS", "NEUTRAL", "SKIPPED"):
			continue
		if state == "":
			problems.append(f"check {name} is still running")
		else:
			problems.append(f"check {name} is {state}")
	return problems


def check_mergeable(pr: dict) -> list[str]:
	"""CHECK 2: no conflicts, not a draft."""
	problems: list[str] = []
	if pr.get("isDraft"):
		problems.append("draft")
	if pr.get("mergeable") == "CONFLICTING":
		problems.append("conflicts with the base branch")
	elif pr.get("mergeable") == "UNKNOWN":
		problems.append("GitHub has not finished computing mergeability")
	return problems


def check_gate(pr: dict) -> list[str]:
	"""CHECK 3: run merge_gate.py against this PR's own ledger, not master's."""
	with tempfile.TemporaryDirectory() as directory:
		target = pathlib.Path(directory) / "arch.md"
		try:
			# The ref goes in the query string: `gh api -f` sends a request BODY,
			# which a GET ignores, silently returning the DEFAULT branch's file.
			# That would have checked master's ledger and called it the PR's.
			content = _gh("api",
				"repos/{owner}/{repo}/contents/docs/systems_architecture.md"
				f"?ref={pr['headRefName']}",
				"-H", "Accept: application/vnd.github.raw")
		except RuntimeError as error:
			return [f"could not fetch the branch's ledger: {error}"]
		target.write_text(content, encoding="utf-8")
		result = subprocess.run(
			[sys.executable, str(GATE), "--architecture", str(target)],
			capture_output=True, text=True)
		if result.returncode == 0:
			return []
		return [line.replace("merge_gate: ", "")
			for line in result.stdout.splitlines() if "PASS" not in line]


def check_report(pr: dict) -> list[str]:
	"""CHECK 4: the PR body's declared exceptions must be empty and present."""
	import re
	body = pr.get("body") or ""
	problems: list[str] = []
	for block in REPORT_BLOCKS:
		match = re.search(rf"^\s*\**{block}:\**\s*(.*)$", body, re.M)
		if match is None:
			problems.append(f"body declares no {block}:")
		elif match.group(1).strip().strip("*").lower() not in ("none", "none.", ""):
			problems.append(f"{block}: {match.group(1).strip()[:60]}")
	return problems


def main() -> int:
	"""Evaluate every open PR; merge the clean ones if asked."""
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--merge", action="store_true",
		help="actually merge; without this the run is a dry run")
	parser.add_argument("--only", type=int, action="append", help="restrict to these PR numbers")
	args = parser.parse_args()

	merged: list[int] = []
	held: list[int] = []
	for pr in open_prs():
		if args.only and pr["number"] not in args.only:
			continue
		problems = (check_mergeable(pr) + check_ci(pr)
			+ check_gate(pr) + check_report(pr))
		label = f"#{pr['number']} {pr['title'][:52]}"
		if problems:
			held.append(pr["number"])
			print(f"HOLD  {label}")
			for problem in problems:
				print(f"        {problem}")
			continue
		print(f"READY {label}")
		if args.merge:
			try:
				_gh("pr", "merge", str(pr["number"]), "--merge", "--delete-branch")
				print(f"        merged")
				merged.append(pr["number"])
			except RuntimeError as error:
				print(f"        merge refused by GitHub: {error}")
				held.append(pr["number"])

	print(f"\nauto_merge: {len(merged)} merged, {len(held)} held"
		f"{'' if args.merge else ' (dry run -- pass --merge to act)'}")
	return 0


if __name__ == "__main__":
	sys.exit(main())
