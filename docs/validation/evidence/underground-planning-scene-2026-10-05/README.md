# Actual-world planning scene — 1179

Accepted implementation candidate: `candidate-9/`. Accepted native run:
`native-4/`. The six changed GDScript files are copied and SHA-256-pinned in the
candidate. The native run pins every GDScript, demo shader, its runner and the
actual harness scene before and after execution. This is an interaction and
presentation checkpoint; paid access and the first worker-built empty Kitchen
remain open.

## Verification

The focused wrapper moves only this checkout's assets aside, deletes its
`.godot`, performs the exact clean editor import, runs five official singleton
suite shards, and runs the analyzer with `--max 0`. It restores the project,
assets and prior sidecars and checks all source bytes. This is explicitly a
focused run, not the no-argument full-suite milestone.

| Suite | Tests | Assertions | Failures |
| --- | ---: | ---: | ---: |
| Actual planning input | 1 | 89 | 0 |
| Demo build | 6 | 224 | 0 |
| Existing demo input | 3 | 555 | 0 |
| Modular editor | 10 | 116 | 0 |
| Actual room inspector | 10 | 148 | 0 |
| Total | 30 | 1,132 | 0 |

Each suite retains these exact diagnostic lines:

```text
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
```

Analyzer: `0 GDScript warning(s) in 0 of 6 file(s)`. Clean import and raw
analyzer editor findings are also zero. `candidate-9/invocation.json` records
commands, counts and restoration; `source-before.json` equals `source-after.json`.

The actual demo harness performs **64 headless checks**. With native capture it
performs **74 checks, zero failures**, using Metal/Forward+ and five PNGs at
1280x720. `native-4/invocation.json` records zero raw import/runtime findings,
source equality and project restoration. The primary integrator inspected all
five images, including the stall banner above dimmed, inaccessible controls.

The player enters through the existing Tunnels tab, paints a rectangle directly
on dirt, uses real dropdown input to change floors, returns to the plan, and
receives a conserving access refusal. Escape cancels a stroke before closing;
reopening preserves the plan and original camera. The live clock then raises
CRITICAL through real host debt. A previously held W, a new turn/drag, mouse
clicks, repeated Tab/Shift-Tab and navigation cannot operate the underlying
planner. Enter acknowledges the actual banner. Finally, actual UI World Create
retires an open purpose popup and draft; the same entry button reopens over the
new World and its real Room/Route owners.

Independent review evidence is separately owned under
`../underground-planning-scene-review-2026-10-05/`. It identified camera/modal
ordering, popup/reset composition and keyboard-focus gaps; the final candidate
and tests close those findings. Independent acceptance is recorded there,
not inferred from this author's test results.

## Retained iteration history

Earlier candidates and native runs are retained as evidence, not accepted
substitutes. Candidate7/native3 predate the independent modal/reset review.
Candidate8 adds modal and reset regressions; candidate9 also contains keyboard
focus. Native1 and native2 completed their 46 interaction checks but failed the
strict diagnostics gate because this isolated checkout lacked staged assets.
They are rejected runs. Native3 has clean staging and 46 checks; native4 is the
final expanded run. See each invocation for its actual outcome.

Local asset receipts identify read-only copies from our earlier owned
worktrees and audio staged from the existing local library. No asset generation
or paid credits were used. Staged demo assets are not added to Git by this work.

The flat planning terrain and an access refusal are not evidence of final
underground world art, completed excavation, furniture, saves or 256-resident
performance. Those retain their own queue gates.
