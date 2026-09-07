# 0010 — Verify ebook contents before claiming reading coverage
Date: 2026-09-06 · Status: Accepted

## Decision
Identify supplied ebooks from their archive, reading order and actual narrative,
not their filename or collection metadata. Keep full-text reading material out
of the repository; keep source digests, coverage, passage locators and original
analysis in repository documents.

## Why
Brendan's supplied EPUB advertises Redwall Books 1–20, but contains Lord Brocktree
alone. Its complete supplied narrative has now been read, including Prologue,
Chapters 1–38 and Epilogue. This advances the earlier excerpt-only state recorded
in decision 0009; it does not establish that twenty books, or all six focus
novels, were read. Visible conversion errors also prevent certification of an
exact publisher edition from metadata alone.

## Consequences
- Use `docs/lord_brocktree_source_audit.json` to identify EV-LB02 and its locators.
- Read `docs/lord_brocktree_analysis.md` with the parent research and setting
  decisions. Its proposals are not new creative approvals.
- Edition, publication date and validated ISBN remain null until verified.
- The other five focus novels still need full texts and full readings.
- User content boundaries and existing gameplay owners retain authority.
- Leave these research changes uncommitted for review, as in decision 0009.

## Source
User-provided EPUB, 2026-09-06; verified SHA-256 in EV-LB02; archive and narrative
inspection; SET-RESEARCH-LB-001; AGENTS.md requirement for durable decisions.
