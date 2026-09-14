# 0135 — Lane records are one file each, never appended to a shared checklist

**Status:** accepted. **Date:** 2026-09-14.

## Context

Every lane finished by appending a dated `## ` section to the end of its task
checklist. Two lanes finishing against the same checklist therefore wrote at the
same place, and git called it a conflict **every single time**.

In one round of five parallel lanes, `docs/tasks/09_persistence_replay_reliability.md`
conflicted **five times out of five**: on the bulk-column rebase, on §7's, on
§12's, again on §12's after §7 landed, and once more during the stack merge. Every
resolution was the same mechanical keep-both, and the correct answer was never in
doubt — both sections belong, in either order.

That is what made it worth fixing rather than tolerating. The cost was not the
risk of resolving one wrongly. The cost was that it recurred on every lane,
forever, and a resolution done thirty times by hand eventually gets done
carelessly — on a file that records what shipped.

The pattern was not unique to §09. Ten task files carried 38 dated sections
between them: §06 had seven, §04 eight, §04.5 five. Every one of those files was
a future conflict waiting for two lanes to touch it.

## Decision

A lane writes exactly **one new file**:

```
docs/tasks/lanes/<task number>/<YYYY-MM-DD>-<short-slug>.md
```

opening with a title, a `Task:` line naming its checklist and a `Date:` line.
Two new files with different names cannot conflict, in any landing order. All 38
existing sections were migrated, headings promoted one level, fenced code blocks
left alone.

**There is deliberately no committed index.** An index is a shared file with a
shared append point and would reintroduce precisely what this removes. The
directory listing is the index; `tools/lane_notes.py` renders it on demand.

**The checklist itself stays.** The `[ ]` and `[x]` items are real task state,
which is what a checklist is for, and lanes tick distinct lines — that collides
rarely, and when it does the collision is meaningful and worth a human. Only the
dated write-ups moved.

## Why the check matters more than the migration

`tools/lane_notes.py --check` runs in the `contracts` job and refuses:

- **a task file that has grown a dated `## ` section again** — the habit coming
  back, which is the actual failure mode,
- a lane file not named `<date>-<slug>.md` in lowercase,
- a lane file with no title, no `Task:` line or no `Date:` line,
- a `lanes/<n>/` directory naming no task file.

Without that first check this is a tidy-up that lasts until the next lane
forgets its brief, and lane briefs are written fresh each round. Verified by
appending a dated section and confirming the check refuses it, then restoring
the file and confirming both a pass and a byte-identical `shasum -a 256`.

## Consequences

38 files where there were 10 appendable sections' worth of shared surface. The
directory is larger to browse, which is the trade: `tools/lane_notes.py` exists
because a listing of 38 filenames is worse than a rendered index, and a rendered
index that lives in git is worse than both.

This does not touch the other shared-file conflict sources. `docs/systems_architecture.md`
is still serialised by hand through the dispatcher's ownership rule, because a
memory ledger genuinely is one document and splitting it would break the
arithmetic every validator depends on.
