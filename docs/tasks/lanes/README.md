# Lane records

**One file per lane. Never append to a shared file.**

When a lane finishes, it writes exactly one new file here:

```
docs/tasks/lanes/<task number>/<YYYY-MM-DD>-<short-slug>.md
```

opening with a title, the task file it belongs to, and its date:

```markdown
# §9 NAVIGATION landed — 2026-09-12

Task: 09_persistence_replay_reliability.md
Date: 2026-09-12
```

That is the whole convention. `python3 tools/lane_notes.py --check` enforces it
and runs in CI; `python3 tools/lane_notes.py` prints the index.

## Why it is a file each

Every lane used to append a dated `## ` section to the end of its task
checklist. Two lanes finishing against the same checklist appended at the same
place, so git called it a conflict **every single time** — five for five on
`09_persistence_replay_reliability.md` in one round of parallel work, each one
resolved by hand as a mechanical keep-both where the resolution was never in
doubt. The cost was not the risk of getting it wrong. The cost was that it
happened on every lane, forever, and one of those resolutions eventually gets
done carelessly.

Two new files with different names cannot conflict, in any landing order.

There is deliberately **no committed index**, because an index is a shared file
with a shared append point and would reintroduce exactly what this removes. The
directory listing is the index. `tools/lane_notes.py` renders it on demand.

## What still lives in the task file

The checklist itself — the `[ ]` and `[x]` items. That is real task state, it is
what a checklist is for, and lanes tick distinct lines, which collides rarely
and meaningfully when it does. Only the dated write-ups moved.

## What `--check` refuses

- A task file that has grown a dated `## ` section again. This is the important
  one: it makes the old habit fail in CI rather than quietly coming back.
- A lane file not named `<date>-<slug>.md` in lowercase.
- A lane file with no `# ` title, no `Task:` line or no `Date:` line.
- A `lanes/<n>/` directory naming no task file.
