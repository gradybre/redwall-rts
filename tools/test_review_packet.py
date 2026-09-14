#!/usr/bin/env python3
"""Self-test for review_packet.py's declaration grammar and evidence labelling.

A parser with no negative tests is a parser nobody can trust. The grammar this
drives decides whether a merged PR is reported as clean, as carrying a live
survivor, or as unreadable-by-machine, so every outcome is driven here by a
defect and by a clean input, and the two hardest cases are REAL:

  * PR #103 and PR #104 both wrote `SURVIVED_MUTANTS: none -- <explanation>`,
    where the explanation describes mutants that were killed. The old parser
    called those non-empty and reported both as carrying survivors. Treating
    them as CLEAR would be worse: it would let a lane hide a live survivor
    behind the word "none". The grammar answers QUALIFIED -- not cleared, not
    counted, handed to a human with its full text -- and the two tests below
    pin that from the real strings.

  * PR #106's body contains `| **A1** | An agent report whose `DEVIATIONS:` ...`
    inside a markdown table, and PR #113's contains the same names mid-sentence.
    Neither is a declaration. Both are pinned as non-matches, because a parser
    that counts prose is how "None in this window" gets printed over 94 PRs
    that declared nothing.

    python3 tools/test_review_packet.py
"""

from __future__ import annotations

import argparse
import datetime
import json
import pathlib
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import review_packet as rp  # noqa: E402

FAILURES: list[str] = []
CASES: list[str] = []

# Verbatim from PR #103. Two mutants survived, both were real defects, both were
# fixed, and every required mutant died against the final source. Not a survivor.
PR103_SURVIVORS = (
	"none — two survived initially, both were REAL DEFECTS and both were fixed "
	"(`_read_block()` comparing the reader against itself; an unreachable "
	"`declared != count` gate removed with the reason in its docstring). All seven "
	"required mutants were re-run against the final source and all died.")
# Verbatim from PR #104.
PR104_SURVIVORS = (
	"none — two survived initially (arena garbage between spans; the rebuild gate "
	"catching a cursor rather than an offset), two tests were added, both then died, "
	"no existing test weakened.")
# Verbatim from PR #104: a genuine, non-empty deviation that a human accepted.
PR104_DEVIATIONS = (
	"the lane implemented SAVE-LAYOUT-R01's record-major form over my column-major "
	"brief, citing AGENTS.md's authority order — a ruling outranks a working "
	"instruction — and raised it as BLOCKER P1 for me to overrule.")
# Verbatim from PR #112: a real argued survivor, declared without the word "none".
PR112_SURVIVORS = ("M12 unreachable, M13 equivalent — both argued above, neither "
	"deleted to manufacture a kill")
# Verbatim from PR #106: a table row, not a declaration.
PR106_TABLE_ROW = ("| **A1** | An agent report whose `DEVIATIONS:` / "
	"`SURVIVED_MUTANTS:` / `BLOCKED:` blocks are non-empty **or missing**. |")
# A markdown table that documents the blocks. The names sit immediately after the
# cell pipe, so only excluding "|" from the margin keeps these out. PR #106 carries
# a table of exactly this kind, and a docs table is a specification, not a lane
# declaring anything about its own change.
TABLE_CELL_BACKTICKED = "| `DEVIATIONS:` | must be `none` before auto_merge will merge |"
TABLE_CELL_BARE = "| SURVIVED_MUTANTS: none | what a clean lane writes |"
# Verbatim from PR #113: prose, not a declaration.
PR113_PROSE = ("The `DEVIATIONS`/`SURVIVED_MUTANTS`/`BLOCKED` blocks keep a human in "
	"the loop without keeping them in the way: most changes declare nothing.")

TEMPLATE_BODY = ("## Declarations\n\nDEVIATIONS: none\nSURVIVED_MUTANTS: none\n"
	"BLOCKED: none\n")


def check(name: str, actual: object, expected: object) -> None:
	"""Assert one equality, recording rather than raising so every case runs."""
	CASES.append(name)
	if actual == expected:
		print(f"  ok  {name}")
		return
	FAILURES.append(f"{name}: expected {expected!r}, got {actual!r}")
	print(f"  FAIL  {name}: expected {expected!r}, got {actual!r}")


def test_real_qualified_cases() -> None:
	"""The two real `none -- <explanation>` bodies are QUALIFIED, not CLEAR."""
	check("#103 SURVIVED_MUTANTS is QUALIFIED",
		rp.classify_value(PR103_SURVIVORS), "QUALIFIED")
	check("#104 SURVIVED_MUTANTS is QUALIFIED",
		rp.classify_value(PR104_SURVIVORS), "QUALIFIED")
	check("`none, but see below` is QUALIFIED",
		rp.classify_value("none, but see below"), "QUALIFIED")
	check("`none (one equivalent)` is QUALIFIED",
		rp.classify_value("none (one equivalent)"), "QUALIFIED")
	check("`none —` with only punctuation left is QUALIFIED",
		rp.classify_value("none —"), "QUALIFIED")


def test_genuine_declarations() -> None:
	"""Content that never says `none` is DECLARED, and `none`-prefixed words are not."""
	check("#104 DEVIATIONS is DECLARED", rp.classify_value(PR104_DEVIATIONS), "DECLARED")
	check("#112 SURVIVED_MUTANTS is DECLARED",
		rp.classify_value(PR112_SURVIVORS), "DECLARED")
	check("`nonexistent column removed` is DECLARED, not QUALIFIED",
		rp.classify_value("nonexistent column removed"), "DECLARED")
	check("`n/a` is DECLARED -- only the literal word `none` clears a block",
		rp.classify_value("n/a"), "DECLARED")
	check("`M4 survived` is DECLARED", rp.classify_value("M4 survived"), "DECLARED")


def test_clear_and_malformed() -> None:
	"""Exactly `none`, in any casing or emphasis, clears. Nothing else does."""
	for text in ("none", "none.", "None", "NONE", "**none**", "`none`", "  none  ",
			"*none*.", "__none__", "**none.**"):
		check(f"{text!r} is CLEAR", rp.classify_value(text), "CLEAR")
	for text in ("", "   ", "**", "  `` "):
		check(f"{text!r} is MALFORMED", rp.classify_value(text), "MALFORMED")


def test_line_matching() -> None:
	"""Which lines are declarations at all: bullets and quotes yes, prose and tables no."""
	cases = {
		"DEVIATIONS: none": "CLEAR",
		"  SURVIVED_MUTANTS: none": "CLEAR",
		"> BLOCKED: none": "CLEAR",
		"- **DEVIATIONS:** none": "CLEAR",
		"* `SURVIVED_MUTANTS`: none": "CLEAR",
		"**BLOCKED**:   none": "CLEAR",
		"DEVIATIONS : none": "CLEAR",
		"\tBLOCKED:none": "CLEAR",
	}
	for line, expected in cases.items():
		block = next(b for b in rp.BLOCKS if b in line)
		check(f"line {line!r} parses", rp.parse_declarations(line)[block]["outcome"], expected)
	for body, label in ((PR106_TABLE_ROW, "#106 table row"), (PR113_PROSE, "#113 prose"),
			(TABLE_CELL_BACKTICKED, "backticked table cell"),
			(TABLE_CELL_BARE, "bare table cell"),
			("deviations: none", "lowercase"), ("see DEVIATIONS: none above", "mid-line")):
		parsed = rp.parse_declarations(body)
		check(f"{label} matches nothing",
			[parsed[b]["outcome"] for b in rp.BLOCKS], ["MISSING"] * 3)


def test_missing_and_multiple() -> None:
	"""MISSING is not CLEAR, and a trailing `none` cannot cancel a real declaration."""
	parsed = rp.parse_declarations(TEMPLATE_BODY)
	check("template body is all CLEAR",
		[parsed[b]["outcome"] for b in rp.BLOCKS], ["CLEAR"] * 3)
	parsed = rp.parse_declarations("## What changed\n\nSome prose and no blocks.\n")
	check("a body with no blocks is all MISSING",
		[parsed[b]["outcome"] for b in rp.BLOCKS], ["MISSING"] * 3)
	parsed = rp.parse_declarations("SURVIVED_MUTANTS: none\nBLOCKED: none\n")
	check("one absent block is MISSING while the others are CLEAR",
		[parsed[b]["outcome"] for b in rp.BLOCKS], ["MISSING", "CLEAR", "CLEAR"])
	doubled = f"DEVIATIONS: {PR104_DEVIATIONS}\nDEVIATIONS: none\n"
	parsed = rp.parse_declarations(doubled)
	check("most severe of two occurrences wins", parsed["DEVIATIONS"]["outcome"], "DECLARED")
	check("both occurrences are kept", len(parsed["DEVIATIONS"]["occurrences"]), 2)


def _packet(records: list[dict], since: str = "2026-09-10",
		until: str = "2026-09-14") -> str:
	"""Build a packet from synthetic records through the real snapshot path."""
	with tempfile.TemporaryDirectory() as directory:
		path = pathlib.Path(directory) / "synthetic_merged_prs.json"
		path.write_text(json.dumps(records), encoding="utf-8")
		args = argparse.Namespace(since=since, until=until, query=False,
			pr_source=str(path), limit=100)
		return rp.build_packet(args)[0]


def _record(number: int, body: str, merged: str = "2026-09-12T10:00:00Z") -> dict:
	"""One synthetic merged-PR record in gh's own JSON shape."""
	return {"number": number, "title": f"PR {number}", "body": body,
		"mergedAt": merged, "mergeCommit": {"oid": "0" * 40}}


def _fake_window(moments: list[str]):
	"""A stand-in for gh: returns the synthetic records merged inside a window."""
	def fetch(lo: object, hi: object, limit: int) -> list[dict]:
		"""Records inside [lo, hi], cut to `limit` exactly as a saturated page would be."""
		rows = [_record(i, TEMPLATE_BODY, m) for i, m in enumerate(moments)
			if rp._iso(lo) <= m <= rp._iso(hi)]
		return rows[:limit]
	return fetch


def test_pagination_never_truncates() -> None:
	"""A saturated sub-window is bisected, and an unsplittable one raises."""
	lo = datetime.datetime(2026, 9, 10)
	hi = datetime.datetime(2026, 9, 14, 23, 59, 59)
	moments = ["2026-09-10T01:00:00Z", "2026-09-10T02:00:00Z", "2026-09-12T03:00:00Z",
		"2026-09-13T04:00:00Z", "2026-09-14T05:00:00Z"]
	original = rp._fetch_window
	try:
		rp._fetch_window = _fake_window(moments)
		whole, notes = rp.fetch_merged_prs(lo, hi, 99)
		check("an unsaturated window needs one query", len(notes), 1)
		check("an unsaturated window returns every record", len(whole), 5)
		split, notes = rp.fetch_merged_prs(lo, hi, 2)
		check("a saturated window is bisected", len(notes) > 1, True)
		check("bisection loses no record and adds none", len(split), 5)
		check("bisection returns the same numbers",
			sorted(r["number"] for r in split), sorted(r["number"] for r in whole))
		rp._fetch_window = lambda lo, hi, limit: [_record(i, "") for i in range(limit)]
		try:
			rp.fetch_merged_prs(lo, hi, 2)
			check("an unsplittable saturated window raises", "returned", "raised")
		except RuntimeError as error:
			check("an unsplittable saturated window raises",
				"will not truncate" in str(error), True)
	finally:
		rp._fetch_window = original


def test_snapshot_shapes() -> None:
	"""Both accepted snapshot shapes load, and an unrecognised one refuses."""
	check("a bare list loads", len(rp._snapshot_records([{"number": 1}])), 1)
	check("a {records: [...]} object loads",
		len(rp._snapshot_records({"records": [{"number": 1}, {"number": 2}]})), 2)
	try:
		rp._snapshot_records({"prs": []})
		check("an unrecognised snapshot shape refuses", "returned", "raised")
	except ValueError as error:
		check("an unrecognised snapshot shape refuses", "neither a list" in str(error), True)


def test_packet_labels_its_evidence() -> None:
	"""The artifact must say what it covered, and must refuse to imply a clean bill."""
	empty = _packet([])
	check("empty packet says it cannot distinguish",
		'CANNOT DISTINGUISH "no exceptions" FROM "no evidence"' in empty, True)
	check("empty packet still prints the grammar", "MALFORMED  <- " in empty, True)
	populated = _packet([
		_record(103, f"SURVIVED_MUTANTS: {PR103_SURVIVORS}\nDEVIATIONS: none\nBLOCKED: none"),
		_record(104, f"DEVIATIONS: {PR104_DEVIATIONS}\nSURVIVED_MUTANTS: none\nBLOCKED: none"),
		_record(90, "## What changed\n\nNo declarations at all."),
		_record(88, TEMPLATE_BODY),
	])
	check("packet prints the whole declared text, first character to last",
		" ".join(PR104_DEVIATIONS.split()) in populated, True)
	check("packet prints the whole qualified text, first character to last",
		" ".join(PR103_SURVIVORS.split()) in populated, True)
	check("packet never abbreviates evidence with an ellipsis",
		"…" in populated, False)
	check("packet names the PR with no blocks", "#90 (DEVIATIONS/SURVIVED" in populated, True)
	check("packet counts the fully clean PR",
		"**1** of 4 audited PRs declare" in populated, True)
	check("packet does not claim completeness", "unknown. A preserved snapshot" in populated,
		True)
	check("out-of-window records are excluded",
		"#70" in _packet([_record(70, TEMPLATE_BODY, "2026-09-01T10:00:00Z")]), False)


def test_against_the_preserved_corpus() -> None:
	"""Replay Astra's 103 preserved records, if this clone has them."""
	path = rp.SNAPSHOT_DIR / "cycle_01_merged_prs.json"
	if not path.exists():
		print(f"  SKIP  preserved corpus: {rp._relpath(path)} is not in this clone")
		return
	records = rp._snapshot_records(json.loads(path.read_text(encoding="utf-8")))
	rows = rp.audit(records)
	complete = [r for r in rows
		if all(r["blocks"][b]["outcome"] != "MISSING" for b in rp.BLOCKS)]
	none_at_all = [r for r in rows
		if all(r["blocks"][b]["outcome"] == "MISSING" for b in rp.BLOCKS)]
	check("corpus holds 103 records", len(rows), 103)
	check("9 records carry all three blocks", len(complete), 9)
	check("94 records carry none of the three", len(none_at_all), 94)
	by_number = {r["number"]: r for r in rows}
	check("#103 SURVIVED_MUTANTS QUALIFIED in the corpus",
		by_number[103]["blocks"]["SURVIVED_MUTANTS"]["outcome"], "QUALIFIED")
	check("#104 DEVIATIONS DECLARED in the corpus",
		by_number[104]["blocks"]["DEVIATIONS"]["outcome"], "DECLARED")
	check("#112 SURVIVED_MUTANTS DECLARED in the corpus",
		by_number[112]["blocks"]["SURVIVED_MUTANTS"]["outcome"], "DECLARED")


def main() -> int:
	"""Run every case, then report the count and fail loudly on any mismatch."""
	print("review_packet self-test")
	test_real_qualified_cases()
	test_genuine_declarations()
	test_clear_and_malformed()
	test_line_matching()
	test_missing_and_multiple()
	test_pagination_never_truncates()
	test_snapshot_shapes()
	test_packet_labels_its_evidence()
	test_against_the_preserved_corpus()
	if FAILURES:
		for failure in FAILURES:
			print(f"  {failure}")
		print(f"review_packet self-test: {len(CASES)} case(s), "
			f"{len(FAILURES)} failure(s) -- FAIL")
		return 1
	print(f"review_packet self-test: {len(CASES)} case(s), 0 failure(s) -- PASS")
	return 0


if __name__ == "__main__":
	sys.exit(main())
