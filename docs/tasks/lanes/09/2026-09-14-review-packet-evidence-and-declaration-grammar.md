# Review packet: PR-sourced evidence and a declared grammar — 2026-09-14

Task: 09_persistence_replay_reliability.md
Date: 2026-09-14

`tools/review_packet.py` and `tools/test_review_packet.py`. Reasoning, the
grammar and the rejected alternatives are in
[decision 0139](../../decisions/0139-a-declared-grammar-for-the-declaration-blocks.md).

- [x] **The source is merged pull request bodies**, via
      `gh pr list --search 'merged:<from>..<to>' --state merged --json
      number,title,body,mergedAt,mergeCommit`. Commit messages feed nothing but
      one labelled reachability cross-check. The old generator read local HEAD
      commit bodies and `git log --merges`, which omits every squash-merged PR,
      and printed "None in this window" over 94 PRs that declared nothing.
- [x] **Pagination by time bisection**, because `--search` has no cursor. A
      sub-window returning exactly `--limit` rows is split into two overlapping
      halves and re-queried; results de-duplicate by PR number. A saturated
      one-second window raises rather than returning a short list. Verified
      live: 105 records at `--limit 100` (3 sub-queries) and the identical 105
      at `--limit 10` (37 sub-queries).
- [x] **Grammar v1 declared**, printed in the tool docstring, in `GRAMMAR`, and
      into the packet itself. Five outcomes: CLEAR / QUALIFIED / MALFORMED /
      DECLARED / MISSING. Multiple lines for one block take the most severe
      outcome and every occurrence is printed, so a trailing `DEVIATIONS: none`
      cannot cancel a real one above it.
- [x] **`none — <explanation>` is QUALIFIED**: not cleared, not counted as a
      survivor, printed in full, handed to a human. PRs #103 and #104 wrote
      exactly this about mutants that were *killed*; calling it non-empty
      misreports them, and calling it empty would let `none — M7 is still alive`
      clear. The parser refuses to decide rather than folding an undetermined
      value into a neighbouring one.
- [x] **MISSING is not CLEAR.** A block nobody wrote is missing evidence, not an
      approved exception and not a retroactive violation of a gate that did not
      exist. `n/a` is DECLARED; a lowercase `deviations:` is MISSING, which is
      the louder bucket, so casing cannot be used to evade quietly.
- [x] **`|` excluded from the margin**: a markdown table cell naming the blocks
      is a specification, not a declaration. Pinned by two negative fixtures
      after the first version of that test failed to kill the mutation.
- [x] **Evidence limits are in the artifact.** `docs/planning/review_packet.md`
      opens with source (snapshot path + sha256, or the live query and its
      sub-query count), requested window, observed `mergedAt` range, record
      count, the local ref used only for cross-checks, and truncation status. §9
      enumerates the blind spots. Zero records prints, in the file, that the
      packet cannot distinguish "no exceptions" from "no evidence".
- [x] **Declared and qualified text is never abbreviated.** A test asserts the
      full #103 and #104 strings appear character-for-character and that no
      ellipsis occurs anywhere in the packet.
- [x] `python3 tools/test_review_packet.py` — `review_packet self-test: 67
      case(s), 0 failure(s) -- PASS`, including a replay of Astra's preserved
      103-record corpus (9 complete, 94 with none of the three).
- [x] **16 mutations, one per run, all died.** Two survived first: a margin
      admitting `|` (the #106 fixture had prose before the name, so it never
      exercised the exclusion) and silent cell truncation (the assertion checked
      only a prefix). Both tests were strengthened, both mutants then died, no
      test weakened or deleted. `tools/review_packet.py` byte-compared
      `shasum -a 256` against a pristine copy after restore.

Reported to other owners, not claimed here:

- [ ] `tools/auto_merge.py::check_report` treats an **empty** block as passing
      and reads only the **first** occurrence of each block via `re.search`. A
      bare `DEVIATIONS:` with nothing after it auto-merges today. It should
      import `review_packet.classify_value()` instead of keeping a second
      parser. Not on this lane's allowlist.
- [ ] `docs/planning/astra_cycles/cycle_01_merged_prs.json` is a bare list with
      no query metadata, so the window it covered must be inferred from the
      `mergedAt` range. The loader already accepts
      `{"query": {...}, "records": [...]}`; populating it is the snapshot
      owner's call.
