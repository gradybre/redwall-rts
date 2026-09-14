#!/usr/bin/env python3
"""Build the periodic packet Astra reviews, refusals first, from merged PR bodies.

Astra is the planner and head of the project. Its job is not to approve merges
-- the gate does that -- but to catch what a green suite cannot: work that
drifted from the vision, an instruction that was quietly dropped, a plan detail
that got skipped because it was inconvenient, art that passes every check and
still looks wrong.

ORDERING IS THE DESIGN. This packet leads with refusals, deviations and MISSING
evidence, because those are the only entries where the executor and the plan
actually disagreed -- or where nobody can tell whether they did -- and they are
exactly what a summary written in good faith buries. Merged work comes after.
"Everything is fine" is the least informative thing this file can say, so it is
written last if it is written at all.

WHY THIS READS PULL REQUESTS AND NOT COMMITS
--------------------------------------------
The previous generator read local HEAD commit bodies and `git log --merges`.
Both are the wrong evidence for a PR audit and it printed "None in this window"
anyway:

  * a commit message is not the final PR body -- the declaration blocks are
    edited on the PR, after review, and the commit never sees the edit;
  * `git log --merges` OMITS every squash-merged PR, because a squash result has
    one parent;
  * a local ref cannot see anything merged after it was last fetched.

Against merged:2026-09-10..2026-09-14 that generator listed 50 PRs from local
commits. A read-only GitHub query returned 103 merged PR records. Forty-nine
in-window PRs reachable from cached master were absent from the packet and three
more were not reachable from that ref at all. Nine of the 103 carry all three
declaration blocks; 94 lack all three. "None in this window" was not a finding,
it was an artefact of the source.

So: this reads final PR bodies, it paginates, it refuses rather than truncates,
and it prints in the artifact itself what it could not see.

THE DECLARATION GRAMMAR (v1)
----------------------------
Declared, not inferred, because the previous heuristic silently discarded
arbitrary prose after the word "none". See GRAMMAR below and ADR 0139.

    python3 tools/review_packet.py --since 2026-09-10
    python3 tools/review_packet.py --since 2026-09-10 --query

Writes docs/planning/review_packet.md. Regenerating it is cheap and it is meant
to be regenerated, not edited.
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
QUEUE = ROOT / "docs/planning/work_queue.json"
APPROVALS = ROOT / "docs/planning/art_approvals.json"
ITEMS = ROOT / "docs/rulings/requests/open_items.json"
OUT = ROOT / "docs/planning/review_packet.md"
SNAPSHOT_DIR = ROOT / "docs/planning/astra_cycles"
SNAPSHOT_GLOB = "*_merged_prs.json"

BLOCKS = ("DEVIATIONS", "SURVIVED_MUTANTS", "BLOCKED")

GRAMMAR = """\
    declaration ::= line_start , margin , emphasis , NAME , emphasis , ":" , value , EOL
    margin      ::= { " " | "\\t" | ">" | "-" | "+" | "*" }
    emphasis    ::= { "*" | "_" | "`" }
    NAME        ::= "DEVIATIONS" | "SURVIVED_MUTANTS" | "BLOCKED"   (uppercase, exact)
    value       ::= { character - EOL }

    normalise(value) = strip whitespace and the emphasis characters * _ ` from
                       both ends, repeatedly, then strip one trailing "."

    CLEAR      <- normalise(value) case-folds to exactly "none"
    MALFORMED  <- normalise(value) is empty        (block written, nothing declared)
    QUALIFIED  <- case-folded value begins "none" followed by a non-word
                  character, and anything else remains
    DECLARED   <- anything else
    MISSING    <- no declaration line for that NAME anywhere in the body

    Two or more lines for one NAME: every occurrence is printed, and the block
    takes the MOST SEVERE outcome (DECLARED > MALFORMED > QUALIFIED > CLEAR).\
"""

SEVERITY = {"CLEAR": 1, "QUALIFIED": 2, "MALFORMED": 3, "DECLARED": 4}

_DECLARATION = re.compile(
	r"^[ \t>\-+*]*[*_`]*(" + "|".join(BLOCKS) + r")[*_`]*[ \t]*:(.*)$", re.M)
_EDGE = " \t*_`"


def _git(*args: str) -> str:
	"""Run git in the repository root and return stdout, empty on failure."""
	return subprocess.run(["git", "-C", str(ROOT), *args],
		capture_output=True, text=True).stdout


def _gh(*args: str) -> str:
	"""Run gh and return stdout, raising with gh's own error text on failure."""
	result = subprocess.run(["gh", *args], capture_output=True, text=True)
	if result.returncode != 0:
		raise RuntimeError(result.stderr.strip() or f"gh {' '.join(args)} failed")
	return result.stdout


def normalise_value(value: str) -> str:
	"""Strip whitespace, markdown emphasis and one trailing period from a value.

	`_EDGE` contains the whitespace characters too, so one `strip` is already
	idempotent; the second exists only to clean up after the period.
	"""
	text = value.strip(_EDGE)
	if text.endswith("."):
		text = text[:-1].strip(_EDGE)
	return text


def classify_value(value: str) -> str:
	"""Classify one declaration value as CLEAR, MALFORMED, QUALIFIED or DECLARED.

	The grammar is in GRAMMAR and is justified in ADR 0139. The load-bearing
	choice: "none -- <prose>" is QUALIFIED, which is neither cleared nor counted
	as a live survivor. The machine refuses to decide and hands it to a human.
	"""
	text = normalise_value(value)
	if not text:
		return "MALFORMED"
	folded = text.casefold()
	if folded == "none":
		return "CLEAR"
	if folded.startswith("none") and not (folded[4].isalnum() or folded[4] == "_"):
		return "QUALIFIED"
	return "DECLARED"


def parse_declarations(body: str) -> dict[str, dict]:
	"""Outcome and every occurrence for each of the three blocks in one PR body.

	Returns {block: {"outcome": str, "occurrences": [raw value, ...]}}. A block
	with no matching line is MISSING with no occurrences -- distinct from CLEAR,
	because a lane that never wrote the section declared nothing, and absence is
	missing evidence rather than an approved exception.
	"""
	found: dict[str, dict] = {
		block: {"outcome": "MISSING", "occurrences": []} for block in BLOCKS}
	for match in _DECLARATION.finditer(body or ""):
		block, value = match.group(1), match.group(2)
		outcome = classify_value(value)
		entry = found[block]
		entry["occurrences"].append(value.strip())
		if entry["outcome"] == "MISSING" or SEVERITY[outcome] > SEVERITY[entry["outcome"]]:
			entry["outcome"] = outcome
	return found


def _iso(moment: datetime.datetime) -> str:
	"""GitHub search timestamp, second resolution, explicit UTC."""
	return moment.strftime("%Y-%m-%dT%H:%M:%SZ")


def _fetch_window(lo: datetime.datetime, hi: datetime.datetime, limit: int) -> list[dict]:
	"""One `gh pr list --search merged:<lo>..<hi>` page."""
	raw = _gh("pr", "list", "--search", f"merged:{_iso(lo)}..{_iso(hi)}",
		"--state", "merged", "--limit", str(limit),
		"--json", "number,title,body,mergedAt,mergeCommit")
	return json.loads(raw or "[]")


def fetch_merged_prs(lo: datetime.datetime, hi: datetime.datetime,
		limit: int) -> tuple[list[dict], list[str]]:
	"""Every merged PR in a window, bisecting any sub-window that saturates.

	`gh pr list --search` has no cursor, so pagination is by time: a sub-window
	that returns exactly `limit` rows may have been truncated, and is split into
	two overlapping halves and re-queried. Duplicates are removed by number.
	A one-second window that still saturates cannot be subdivided, so this
	raises rather than returning a silently short list.
	"""
	pending: list[tuple[datetime.datetime, datetime.datetime]] = [(lo, hi)]
	seen: dict[int, dict] = {}
	notes: list[str] = []
	while pending:
		low, high = pending.pop()
		rows = _fetch_window(low, high, limit)
		notes.append(f"`merged:{_iso(low)}..{_iso(high)}` limit {limit} -> {len(rows)}")
		if len(rows) >= limit:
			if (high - low) <= datetime.timedelta(seconds=1):
				raise RuntimeError(
					f"{limit} results in the one-second window {_iso(low)}; "
					"cannot subdivide further and will not truncate")
			mid = low + (high - low) / 2
			pending += [(low, mid), (mid, high)]
			continue
		for row in rows:
			seen[int(row["number"])] = row
	return [seen[n] for n in sorted(seen, reverse=True)], notes


def _newest_snapshot() -> pathlib.Path | None:
	"""The preserved PR snapshot with the latest mergedAt, or None if there is none."""
	best: tuple[str, pathlib.Path] | None = None
	for path in sorted(SNAPSHOT_DIR.glob(SNAPSHOT_GLOB)) if SNAPSHOT_DIR.is_dir() else []:
		try:
			records = _snapshot_records(json.loads(path.read_text(encoding="utf-8")))
		except (ValueError, KeyError):
			continue
		stamps = [str(r.get("mergedAt") or "") for r in records]
		key = max(stamps) if stamps else ""
		if best is None or key > best[0]:
			best = (key, path)
	return None if best is None else best[1]


def _snapshot_records(data: object) -> list[dict]:
	"""Records from either snapshot shape: a bare list, or {"records": [...]}."""
	if isinstance(data, list):
		return [r for r in data if isinstance(r, dict)]
	if isinstance(data, dict) and isinstance(data.get("records"), list):
		return [r for r in data["records"] if isinstance(r, dict)]
	raise ValueError("snapshot is neither a list of records nor {'records': [...]}")


def load_pr_records(args: argparse.Namespace, lo: datetime.datetime,
		hi: datetime.datetime) -> tuple[list[dict], dict]:
	"""Resolve the PR evidence and describe, exactly, where it came from."""
	if args.query:
		records, notes = fetch_merged_prs(lo, hi, args.limit)
		return records, {"kind": "live", "detail":
			f"live `gh pr list --search merged:{_iso(lo)}..{_iso(hi)}`, "
			f"{len(notes)} sub-quer(ies)", "queries": notes, "truncated": False}
	path = pathlib.Path(args.pr_source) if args.pr_source else _newest_snapshot()
	if path is None or not path.exists():
		return [], {"kind": "none", "detail":
			"NO PR EVIDENCE. No snapshot under docs/planning/astra_cycles/ and "
			"--query was not passed.", "queries": [], "truncated": None}
	blob = path.read_bytes()
	records = _snapshot_records(json.loads(blob.decode("utf-8")))
	digest = hashlib.sha256(blob).hexdigest()[:16]
	return records, {"kind": "snapshot", "queries": [], "truncated": None, "detail":
		f"preserved snapshot `{_relpath(path)}` (sha256 {digest}...), "
		f"{len(records)} record(s); the file carries no query metadata, so the "
		"window below is the observed mergedAt range, not a declared search window."}


def _relpath(path: pathlib.Path) -> str:
	"""Repository-relative path, or the absolute one if it lies outside."""
	try:
		return str(path.relative_to(ROOT))
	except ValueError:
		return str(path)


def in_window(records: list[dict], lo: datetime.datetime,
		hi: datetime.datetime) -> list[dict]:
	"""Records whose mergedAt falls inside the requested window."""
	kept: list[dict] = []
	for record in records:
		stamp = str(record.get("mergedAt") or "")
		try:
			moment = datetime.datetime.strptime(stamp, "%Y-%m-%dT%H:%M:%SZ")
		except ValueError:
			continue
		if lo <= moment <= hi:
			kept.append(record)
	return sorted(kept, key=lambda r: int(r["number"]), reverse=True)


def audit(records: list[dict]) -> list[dict]:
	"""One audited row per PR: number, title, merge sha, and the three outcomes."""
	rows: list[dict] = []
	for record in records:
		commit = record.get("mergeCommit") or {}
		rows.append({
			"number": int(record["number"]),
			"title": str(record.get("title") or ""),
			"mergedAt": str(record.get("mergedAt") or ""),
			"sha": str(commit.get("oid") or "")[:12],
			"blocks": parse_declarations(str(record.get("body") or "")),
		})
	return rows


def outcomes(row: dict, wanted: str) -> list[str]:
	"""Block names in one audited row whose outcome is `wanted`."""
	return [b for b in BLOCKS if row["blocks"][b]["outcome"] == wanted]


def _reachable(sha: str) -> bool:
	"""Whether a merge commit exists in the local object store."""
	if not sha:
		return False
	probe = subprocess.run(["git", "-C", str(ROOT), "cat-file", "-e", f"{sha}^{{commit}}"],
		capture_output=True, text=True)
	return probe.returncode == 0


def _cell(text: str, width: int = 0) -> str:
	"""One-line markdown table cell: pipes escaped, newlines flattened.

	`width` 0 means print it whole. Declared and qualified text is the evidence
	this packet exists to carry, so it is never shortened; only incidental fields
	such as a PR title take a bound, and those say so with an ellipsis.
	"""
	flat = " ".join(str(text).split()).replace("|", "\\|")
	if width <= 0 or len(flat) <= width:
		return flat
	return flat[: width - 1] + "…"


def _head(out: list[str], meta: dict, rows: list[dict],
		lo: datetime.datetime, hi: datetime.datetime) -> None:
	"""Title, the coverage verdict, and the evidence basis -- before any finding."""
	out += ["# Astra review packet", "",
		"<!-- GENERATED by tools/review_packet.py. Regenerate, do not edit. -->", "",
		f"Requested window {_iso(lo)} .. {_iso(hi)}. Refusals, deviations and "
		"missing evidence lead, because they are the only entries where the executor "
		"and the plan disagreed -- or where nobody can tell whether they did.", ""]
	stamps = [r["mergedAt"] for r in rows if r["mergedAt"]]
	observed = f"{min(stamps)} .. {max(stamps)}" if stamps else "nothing observed"
	out += ["## Evidence basis", "",
		f"- **Source**: {meta['detail']}",
		f"- **PR records audited**: {len(rows)}; observed mergedAt range {observed}.",
		f"- **Local ref for cross-checks only**: `{_git('rev-parse', 'HEAD').strip() or 'unknown'}`. "
		"No finding below is derived from commit messages.",
		f"- **Truncation**: {_truncation(meta)}", ""]
	if not rows:
		out += ["> **THIS PACKET CANNOT DISTINGUISH \"no exceptions\" FROM \"no "
			"evidence\".** It audited zero PR records, so every statement below about "
			"declarations is a statement about nothing. Re-run with `--query` or point "
			"`--pr-source` at a preserved snapshot before drawing any conclusion.", ""]


def _truncation(meta: dict) -> str:
	"""One sentence on whether the source could have silently dropped records."""
	if meta["kind"] == "live":
		return ("no sub-query returned its limit, so nothing was dropped; a saturated "
			"window is bisected and a saturated one-second window raises.")
	if meta["kind"] == "snapshot":
		return ("unknown. A preserved snapshot cannot prove it was complete when taken; "
			"it is evidence of what was seen, not of what existed.")
	return "not applicable -- there is no source."


def _declared_section(out: list[str], rows: list[dict]) -> None:
	"""Section 1: blocks carrying real content. These lead."""
	out += ["## 1. Declared exceptions (DECLARED)", "",
		"A lane wrote something other than `none`. Read every one.", ""]
	hits = [(r, b) for r in rows for b in outcomes(r, "DECLARED")]
	if not hits:
		out += ["No PR in the audited records carries a DECLARED block. This is a "
			"statement about the records above and nothing else.", ""]
		return
	out += ["| PR | Block | Declared |", "|---|---|---|"]
	for row, block in hits:
		for value in row["blocks"][block]["occurrences"]:
			if classify_value(value) == "DECLARED":
				out.append(f"| #{row['number']} | {block} | {_cell(value)} |")
	out.append("")


def _qualified_section(out: list[str], rows: list[dict]) -> None:
	"""Section 2: "none -- <prose>". The machine refuses to rule on these."""
	out += ["## 2. Qualified declarations (QUALIFIED) -- the machine will not rule", "",
		"The value begins `none` and then keeps going. That is not a clearance and it "
		"is not a live survivor either: it is a sentence only a human can grade. "
		"PRs #103 and #104 are the reason this outcome exists -- both explained "
		"mutants that were killed, and the previous parser reported them as carrying "
		"survivors while `tools/auto_merge.py` held them for review. The full text is "
		"printed, never summarised, so nothing can hide behind the word.", ""]
	hits = [(r, b) for r in rows for b in outcomes(r, "QUALIFIED")]
	if not hits:
		out += ["No PR in the audited records carries a QUALIFIED block.", ""]
		return
	out += ["| PR | Block | Full text |", "|---|---|---|"]
	for row, block in hits:
		for value in row["blocks"][block]["occurrences"]:
			if classify_value(value) == "QUALIFIED":
				out.append(f"| #{row['number']} | {block} | {_cell(value)} |")
	out.append("")


def _gap_section(out: list[str], rows: list[dict]) -> None:
	"""Section 3: MISSING and MALFORMED blocks. Missing evidence, not approval."""
	out += ["## 3. Missing and malformed declaration blocks", "",
		"A block nobody wrote is **missing evidence**. It is not an approved exception, "
		"and it is not a retroactive finding that the work violated a gate that did not "
		"exist when it merged. It means this packet cannot say.", ""]
	missing = [(r, b) for r in rows for b in outcomes(r, "MISSING")]
	malformed = [(r, b) for r in rows for b in outcomes(r, "MALFORMED")]
	clear = [r for r in rows if all(o["outcome"] == "CLEAR" for o in r["blocks"].values())]
	out += [f"- **{len(clear)}** of {len(rows)} audited PRs declare all three blocks as "
		f"an unqualified `none`.",
		f"- **{len(missing)}** block-instances are MISSING across "
		f"{len({r['number'] for r, _ in missing})} PR(s).",
		f"- **{len(malformed)}** block-instances are MALFORMED (written, left empty) "
		f"across {len({r['number'] for r, _ in malformed})} PR(s).", ""]
	for label, hits in (("MISSING", missing), ("MALFORMED", malformed)):
		if not hits:
			continue
		by_pr: dict[int, list[str]] = {}
		for row, block in hits:
			by_pr.setdefault(row["number"], []).append(block)
		out.append(f"{label}: " + ", ".join(
			f"#{n} ({'/'.join(by_pr[n])})" for n in sorted(by_pr, reverse=True)))
		out.append("")


def _grammar_section(out: list[str]) -> None:
	"""Print the grammar into the artifact, so the reader can check the verdicts."""
	out += ["## 4. The grammar these verdicts came from", "", "```", GRAMMAR, "```", "",
		"Case matters: a lowercase `deviations:` is MISSING, not a declaration. "
		"`n/a` is DECLARED, not CLEAR -- only the literal word `none` clears a block. "
		"Justified in "
		"[decision 0139](../decisions/0139-a-declared-grammar-for-the-declaration-blocks.md).", ""]


def _questions_section(out: list[str], items: list[dict], approvals: dict) -> None:
	"""Sections 5 and 6: what is waiting on Astra and what is waiting on Brendan."""
	out += ["## 5. Waiting on you", ""]
	blocking = [i for i in items if i.get("blocks")]
	for item in blocking:
		held = ", ".join(f"`{b}`" for b in item["blocks"])
		out.append(f"- **{item['title']}** (asked {item['asked']}) — holding {held}. "
			f"[Full question](../rulings/requests/OPEN.md#{item['anchor']})")
	out += ([] if blocking else ["Nothing blocking."]) + [""]
	advisory = [i for i in items if not i.get("blocks")]
	if advisory:
		out.append("Advisory, not blocking anything today:")
		out.append("")
		out += [f"- {i['title']} (asked {i['asked']})" for i in advisory] + [""]
	out += ["## 6. Waiting on Brendan", ""]
	pending = [a for a in approvals["approvals"] if a["status"] == "pending"]
	for entry in pending:
		credits = entry.get("estimated_credits")
		cost = ""
		if entry.get("spends_credits"):
			cost = f" **Spends {credits} credits.**" if credits else \
				" **Spends credits, not yet costed.**"
		out.append(f"- **{entry['id']}** — {entry['what']}{cost}")
	out += ([] if pending else ["Nothing pending."]) + [""]


def _queue_section(out: list[str], tasks: list[dict]) -> None:
	"""Section 7: the work queue by status."""
	out += ["## 7. State of the queue", ""]
	by_status: dict[str, list[str]] = {}
	for task in tasks:
		by_status.setdefault(task["status"], []).append(task["id"])
	for status in ("in_flight", "review", "ready", "blocked", "done"):
		if status in by_status:
			out.append(f"- **{status}** ({len(by_status[status])}): "
				+ ", ".join(f"`{i}`" for i in sorted(by_status[status])))
	out.append("")


def _reachability_section(out: list[str], rows: list[dict]) -> None:
	"""Section 8: which audited merge commits the local clone can actually see."""
	out += ["## 8. Local reachability cross-check", "",
		"Not a source of findings -- a measure of how wrong a commit-based audit would "
		"have been. A merge commit absent here is work the old generator could not have "
		"seen at all.", ""]
	absent = [r for r in rows if not _reachable(r["sha"])]
	out += [f"- {len(rows) - len(absent)} of {len(rows)} audited merge commits are present "
		"in this clone's object store."]
	if absent:
		out.append("- Absent from this clone: "
			+ ", ".join(f"#{r['number']}" for r in sorted(
				absent, key=lambda r: r["number"], reverse=True)))
	out.append("")


def _limits_section(out: list[str], meta: dict, lo: datetime.datetime,
		hi: datetime.datetime) -> None:
	"""Section 9: what this packet could not see. Named, in the artifact."""
	bullets = [
		f"- Anything merged outside {_iso(lo)} .. {_iso(hi)}.",
		"- Whether a declaration is TRUE. This reads what a lane wrote about itself; "
		"it verifies nothing.",
		"- PR bodies as they were at merge. `gh` returns the body as it stands now, so "
		"a later edit is invisible here.",
		"- Work that never became a pull request: direct pushes, force-pushed history, "
		"and anything merged through the web UI without a PR record.",
		"- Closed-unmerged PRs, and open PRs, which are `tools/auto_merge.py`'s job.",
		"- Requirements dropped in planning that no PR ever mentioned. Absence is the "
		"failure mode nothing in this repository can detect."]
	if meta["kind"] == "snapshot":
		bullets.append("- Anything merged, or any body edited, AFTER the snapshot was "
			"taken. Re-run with `--query` to audit against GitHub instead.")
	out += ["## 9. What this packet could not see", ""] + bullets + [""]
	if meta["queries"]:
		out += ["Sub-queries issued:", ""] + [f"- {n}" for n in meta["queries"]] + [""]


def _blindspots_section(out: list[str]) -> None:
	"""Section 10: the judgement calls no automated check in this repository makes."""
	out += ["## 10. What to look for that no check can see", "",
		"The gate checks arithmetic, the suite checks behaviour and CI checks both. "
		"None of them can see:", "",
		"- A requirement from your plan implemented in a narrower form than you "
		"specified, where the narrower form passes its own tests.",
		"- A detail you supplied in planning that was dropped because it was "
		"inconvenient, with nothing recording that it was dropped.",
		"- Art that satisfies every manifest and still does not read as Redwall.",
		"- A task in the queue whose title has drifted from what you actually asked "
		"for, so the work is correct against the title and wrong against you.", ""]


def build_packet(args: argparse.Namespace) -> tuple[str, str]:
	"""Assemble the whole packet. Returns (markdown, one-line summary)."""
	lo = datetime.datetime.strptime(args.since, "%Y-%m-%d")
	hi = datetime.datetime.strptime(args.until, "%Y-%m-%d").replace(
		hour=23, minute=59, second=59)
	records, meta = load_pr_records(args, lo, hi)
	rows = audit(in_window(records, lo, hi))
	items = json.loads(ITEMS.read_text(encoding="utf-8"))["items"]
	approvals = json.loads(APPROVALS.read_text(encoding="utf-8"))
	tasks = json.loads(QUEUE.read_text(encoding="utf-8"))["tasks"]
	out: list[str] = []
	_head(out, meta, rows, lo, hi)
	_declared_section(out, rows)
	_qualified_section(out, rows)
	_gap_section(out, rows)
	_grammar_section(out)
	_questions_section(out, items, approvals)
	_queue_section(out, tasks)
	_reachability_section(out, rows)
	_limits_section(out, meta, lo, hi)
	_blindspots_section(out)
	counts = {name: sum(len(outcomes(r, name)) for r in rows) for name in SEVERITY}
	missing = sum(len(outcomes(r, "MISSING")) for r in rows)
	summary = (f"review_packet: {len(rows)} PR record(s) from {meta['kind']}; "
		f"{counts['DECLARED']} declared, {counts['QUALIFIED']} qualified, "
		f"{counts['MALFORMED']} malformed, {missing} missing block(s)")
	return "\n".join(out) + "\n", summary


def main() -> int:
	"""Parse arguments, write the packet, print what it actually covered."""
	parser = argparse.ArgumentParser(description="Build Astra's review packet.")
	today = datetime.date.today()
	parser.add_argument("--since", default=(today - datetime.timedelta(days=7)).isoformat(),
		help="ISO date, inclusive; default 7 days ago")
	parser.add_argument("--until", default=today.isoformat(),
		help="ISO date, inclusive; default today")
	parser.add_argument("--query", action="store_true",
		help="query GitHub for final PR bodies instead of reading a snapshot")
	parser.add_argument("--pr-source", default=None,
		help="path to a preserved merged-PR JSON snapshot")
	parser.add_argument("--limit", type=int, default=100,
		help="per-sub-query result limit; saturation bisects, never truncates")
	args = parser.parse_args()
	markdown, summary = build_packet(args)
	OUT.write_text(markdown, encoding="utf-8")
	print(f"{summary}; wrote {OUT.relative_to(ROOT)}")
	return 0


if __name__ == "__main__":
	sys.exit(main())
