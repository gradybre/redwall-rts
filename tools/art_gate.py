#!/usr/bin/env python3
"""The one gate that never clears itself.

Everything else in this pipeline is designed to run without a human. This is
not. Two things pass through here:

  * PAID GENERATION. Meshy credits are real money spent from Brendan's account.
    A tool call that spends them cannot be undone by reverting a commit.
  * VISUAL ACCEPTANCE. Whether the badger reads as a badger, whether the HUD
    looks right, whether the proportions are believable. No test asserts taste,
    and an agent that decides its own art is acceptable is grading its own work.

Decision 0002 additionally forbids bulk creature generation before proportion
approval, which is a sequencing rule no amount of green CI satisfies.

USAGE, before any call that spends or any claim that art is accepted:

    python3 tools/art_gate.py --check ART-CREATURES

Exit 0 means a human wrote `approved` against that id in
docs/planning/art_approvals.json. Exit 1 means stop and ask. There is
deliberately no --force, no environment variable and no way for an agent to
write this file: an approval is Brendan editing it, or it is not an approval.

    python3 tools/art_gate.py --request ART-TREES --what "..." --credits 120

prints the approval block to paste in, with the cost stated, so the ask is
always accompanied by the number.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
APPROVALS = ROOT / "docs/planning/art_approvals.json"


def _entry(approval_id: str) -> dict | None:
	"""The approval record for an id, or None."""
	data = json.loads(APPROVALS.read_text(encoding="utf-8"))
	for entry in data.get("approvals", ()):
		if entry.get("id") == approval_id:
			return entry
	return None


def check(approval_id: str) -> int:
	"""Refuse unless a human approved this exact id."""
	entry = _entry(approval_id)
	if entry is None:
		print(f"art_gate: REFUSE -- {approval_id!r} has no entry in {APPROVALS.name}.")
		print("art_gate: run --request to generate one, then ask Brendan.")
		return 1
	status = entry.get("status")
	if status != "approved":
		print(f"art_gate: REFUSE -- {approval_id!r} is {status!r}, not approved.")
		print(f"art_gate: what it would do: {entry.get('what')}")
		if entry.get("spends_credits"):
			credits = entry.get("estimated_credits")
			print(f"art_gate: THIS SPENDS CREDITS. Estimate: "
				f"{credits if credits is not None else 'not yet costed'}.")
		print(f"art_gate: why gated: {entry.get('why_gated')}")
		return 1
	if not entry.get("decided_by"):
		print(f"art_gate: REFUSE -- {approval_id!r} is approved by nobody. "
			"An approval needs a name against it.")
		return 1
	print(f"art_gate: PASS -- {approval_id!r} approved by {entry['decided_by']} "
		f"on {entry.get('decided')}.")
	return 0


def request(approval_id: str, what: str, credits: int | None) -> int:
	"""Print the block to add, cost first."""
	block = {
		"id": approval_id,
		"what": what,
		"spends_credits": credits is not None and credits > 0,
		"estimated_credits": credits,
		"why_gated": "paid generation" if credits else "visual acceptance",
		"status": "pending",
		"requested": None,
		"decided": None,
		"decided_by": None,
	}
	if credits:
		print(f"art_gate: THIS WOULD SPEND {credits} CREDITS. Present this figure "
			"to Brendan before asking.")
	print(json.dumps(block, indent=2))
	print(f"\nart_gate: add the block above to {APPROVALS.relative_to(ROOT)} with a "
		"`requested` date, then ask.")
	return 0


def main() -> int:
	"""Check an approval, or draft a request for one."""
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--check", metavar="ID", help="refuse unless ID is approved")
	parser.add_argument("--request", metavar="ID", help="draft an approval block for ID")
	parser.add_argument("--what", default="", help="what the work would do")
	parser.add_argument("--credits", type=int, default=None, help="estimated credit cost")
	parser.add_argument("--list", action="store_true", help="show every approval and its status")
	args = parser.parse_args()

	if args.list:
		data = json.loads(APPROVALS.read_text(encoding="utf-8"))
		for entry in data.get("approvals", ()):
			credits = entry.get("estimated_credits")
			cost = ""
			if entry.get("spends_credits"):
				cost = f" [{credits} credits]" if credits else " [COST NOT YET KNOWN]"
			print(f"  {entry['status']:<9} {entry['id']:<18}{cost} {entry['what'][:60]}")
		return 0
	if args.check:
		return check(args.check)
	if args.request:
		return request(args.request, args.what, args.credits)
	parser.print_help()
	return 1


if __name__ == "__main__":
	sys.exit(main())
