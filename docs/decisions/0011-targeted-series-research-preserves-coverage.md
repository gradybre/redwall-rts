# 0011 — Keep expanded novel studies explicit about targeted coverage
Date: 2026-09-06 · Status: Accepted

## Decision

Add the eleven newly supplied novels as primary-text research in
`docs/redwall-series/`. Preserve distinct statuses for extraction, inspected
passages and complete sequential reading. Keep source digests, precise locators,
coverage measurements and original analysis in the repository, with the novels
and complete extracted text outside it.

## Why

Brendan requested deeper analysis including books outside the original focus.
The eleven files contain 1,174,789 extracted words. This pass inspected 102,954
unique extracted words and registered 96 passage entries, including selected
beginnings, developments, endings and counterexamples. That supports eleven
bounded studies and a comparative handoff; it does not justify claiming eleven
complete readings. Lord Brocktree remains the only complete supplied-text reading.

The expanded evidence also distinguishes a genuine unresolved founding-account
conflict from Martin's explicitly explained omission of his earlier history.
Moral counterexamples coexist with prejudgment and severe conduct by heroes.
Recording those tensions is more useful than silently making canon uniform.

## Consequences

- Read `docs/redwall-series/README.md` and the relevant individual study before
  using a new passage claim. `source_audit.json` resolves file identity and ranges.
- This supersedes only the current availability statements in decision 0010:
  four more focus texts are now supplied; complete Eulalia! remains unavailable
  in the verified corpus. The older decision remains intact as history.
- The six-book focus and all confirmed DEC choices remain unchanged. No new
  scenario, character biography, family rule, grief system or balance is adopted.
- A source character's speech is not automatically an objective fact. User
  content limits apply to sympathetic characters and source-derived backstory.
- Research remains static authoring context, outside runtime ECS state and RNG.
- Leave these changes uncommitted for review; do not push or publish the books.

## Source

Brendan's eleven supplied local files and request of 2026-09-06;
SET-RESEARCH-SERIES-001 and its source audit; AGENTS.md's requirement to record
durable decisions. Prior method decisions 0009 and 0010 remain applicable.
