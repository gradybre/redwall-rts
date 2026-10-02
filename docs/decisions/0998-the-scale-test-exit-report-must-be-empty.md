# 0998 — The scale test's exit report must be empty, and one injected resource must fail it
Date: 2026-10-02 · Status: Accepted

Numbered 0998: the review-fix batch used 0993–0997, and no branch or worktree used 0998.

## Decision

`test_scale_stress.gd` no longer tolerates any line of the engine's exit report. Decision 0561 had accepted one
`ERROR: \d+ resources still in use at exit` line of any count. The test also ignored the `WARNING: N ObjectDB instances
were leaked at exit` line, because it failed only on lines that start `ERROR:`. Now any count of either fails the run.
A real run's report lines are passed on to the outer runner exactly as printed, so its diagnostics line and leak counts
see them. `tools/run_tests.sh`'s raw-log gate sees them too.

The residual line was not a kitchen cycle any more. It came from the harness quitting while sounds were still playing.
The harness now frees the village and waits until the audio server has let those sounds go before it quits
(`scale_test.gd`, "THE END FREES THE VILLAGE FIRST"). After that, its exit report is empty.

A fault-injection case runs the same harness, with the same end, plus one extra retained resource
(`test/fixtures/scale_exit_leak_fixture.gd`). The engine then has to report exactly 1 resource and 1 object, and the
check has to fail both.

## The rule used

Brendan's ruling on review finding R06 (2026-10-02):

> remove the blanket `\d+` resources-at-exit tolerance in `test_scale_stress.gd`. If a residual line remains, check its
> exact identity and a bounded count, and surface it in the outer evidence. Add a fault-injection case where one extra
> retained resource must fail.

The ruling also noted that the soak lane found these lines can be ambient sounds still playing; `tools/soak_test.py`
parses those.

## What the residual line was

On this tree, with the demo's assets staged, these are the runs of the suite's subprocess
(`scale_test.gd --residents 25 --plan short`, headless, `--fixed-fps 60`):

| Run | Leaked at exit |
|---|---|
| Plain | 2 of 3 printed `WARNING: 6 ObjectDB instances were leaked at exit` and `ERROR: 3 resources still in use at exit` |
| `--verbose` | 0 of 5 printed anything (the timing moves) |

- **The kitchen cycle is gone.** It was the cycle 0561 tolerated, and decision 0922 broke it.
- **What was playing.** A probe that extended the harness listed the players still playing when `_finish` ran: up to
  seven pooled footstep and drop voices (`step_dirt_0N.ogg`, `step_grass_0N.ogg`, `drop_01.ogg`) and both ambient
  loops (`amb_wind_01.wav`, `amb_stream_01.ogg`).
- **Why it leaked.** The harness quit with the village in the tree. A sound that is stopped or freed is let go by the
  audio server on its next mix. Headless, the dummy driver mixes on its own thread about every 23 ms. When the quit
  comes first, the stream and its playback outlive the exit, which is the soak's finding (decision 0921 §7).
- **The soak's own end was not enough.** That end frees the village and waits 30 frames. With the village gone, 30
  uncapped frames pass in about 1 ms. A probe found the playbacks still alive at frame 29 in 2 of 3 runs. One
  fault-injected run under that end reported 4 resources and 7 objects where 1 and 1 were injected.

**So the close waits on the thing itself.**

- At the close it takes a WeakRef to the playback of every player that is playing.
- It quits when all of those are released, after at least 30 frames and 250 ms of real time. The 250 ms covers a sound
  stopped just before the close.
- It sleeps 1 ms per frame so that it does not spin.
- After 5 s it gives up with a `SCALE-ERROR`.
- As it quits it prints `SCALE close <playing at close> <still held> <frames> <ms>`. Both live tests assert that this
  line exists and that its held count is 0.

Measured with the final code:

| Run | Result |
|---|---|
| Real run | 5 of 5 clean |
| Fault run | 6 of 6 reported exactly `1 resources` and `1 ObjectDB instance` |

Under `--verbose`, the fault run names the injected resource: `Resource still in use:
res://test/fixtures/scale_exit_leak_injected.tres (Resource)`.

**No residual is tolerated, so there is no identity or bounded count to pin.** The only exit-report lines a passing run
can contain are none.

## A gap found on the way: the engine's singular

For one leaked object the engine prints `1 ObjectDB instance was leaked at exit`. That is singular, not the plural
`instances were`. Three patterns miss it:

- `run_tests.gd LEAKED_OBJECTS_PATTERN`;
- `tools/run_tests.sh`'s object `grep`;
- `tools/soak_test.py EXIT_SUMMARY`.

The outer run still fails such a line, because it is an unexpected `WARNING:` line. Its "leaked at exit: N object(s)"
count reads 0, though. `test_scale_stress.gd` uses its own patterns, which accept both forms.

## What changed

- **`godot/tools/scale_test/scale_test.gd`**
  - `_finish` and `_fail` call `_close`, where they used to `quit`.
  - `_close` stops the driver, notes the playing sounds (`playbacks_of`) and frees the village.
  - `_count_close` waits as described above and prints the close line.
  - New constants: `CLOSE_FRAMES` (30), `CLOSE_MIN_MSEC` (250) and `CLOSE_MAX_MSEC` (5000).
  - `tools/scale_test.py` runs gain about 0.25 s each.
- **`godot/test/test_scale_stress.gd`**
  - `EXIT_LEAK` and its regex are removed.
  - New: `exit_report` (counts and lines), `exit_report_findings` (any count is a finding), `_errors_in`, `_done_line`,
    `_close_held` and `_run_harness`.
  - The live 25-resident test fails on any exit report, passes the report on with `printerr`, and asserts the close.
  - New test `test_one_extra_retained_resource_fails_the_exit_check`. This is the fault-injection run, about 10 s,
    most of it the village's boot.
  - New test `test_the_exit_check_allows_no_count`. It parses 1, 1000 and singular-object report lines.
- **`godot/test/fixtures/scale_exit_leak_fixture.gd`** (new). It extends the harness, retains one path-cached
  `Resource` that holds itself in its metadata, and cuts the plan to 10 ticks.
- **Decision 0561** has a pointer here.

Focused run (`test_scale_stress.gd` alone): `13 test(s), 57 assertion(s), 0 failure(s)`, and `diagnostics: 0
unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)`.
The three changed files have 0 analyzer warnings (`tools/gdscript_warnings.py --max 0`).

## Mutation testing

There were 12 mutants. 10 were killed, and 1 more was killed in 1 of 2 runs.

**Killed:**

- The one-line, any-count tolerance restored.
- The bound raised to `> 1`.
- The object check dropped.
- The fault assertion inverted.
- The fixture retaining nothing.
- The fixture retaining two.
- A wrong resource pattern.
- A plural-only object pattern.
- `_errors_in` counting the report as an ordinary error.
- The harness quitting with the village in the tree (the close line goes missing).

**Killed in 1 of 2 runs:** the close without the audio wait (quit after 30 frames). It is a race against the audio
thread, and the close line's held count catches it whenever the server has not yet let go.

**Survived:** dropping the forwarding `printerr`. The live test fails either way. Forwarding only changes what the
outer summary shows, and that was checked by hand instead. The live test was pointed at the fixture for this check:

| Forwarding | Outer runner printed |
|---|---|
| On | `1 unexpected error(s), 1 unexpected warning(s) ... leaked at exit: 7 object(s), 4 resource(s)` |
| Off | `0 ... 0` |

## Why

- **Fix the cause rather than pin a count.** The ruling allows an exact identity and a bounded count only if a
  residual cannot be removed. This one could be removed: it was the harness's own way of quitting, not the game's.
- **Wait on WeakRefs, not on frames or time alone.** Frames are nearly free once the village is gone. A fixed sleep
  would be either too short on a loaded machine or wasted on an idle one.
- **Use a fixture that extends the real harness, not a string test alone.** It proves that the check sees a real
  engine report from the real end. Its exact count of 1 also fails if the harness's teardown regresses: the mutant
  that quit early reported 4 resources and 7 objects.
- **Do not forward the fault run's lines.** They are the expected outcome of that test. Reprinted, they would be
  counted by `tools/run_tests.sh`'s raw grep, even under an `EXPECTED` prefix.

## Proposals for Brendan

1. **Count the singular in the outer leak gates.** Widen the object pattern in `run_tests.gd`, `tools/run_tests.sh`
   and `tools/soak_test.py` to `instances? (were|was) leaked`.
   - The options: widen all three (recommended; additive, and every allowance stays zero), or leave them, since the
     unexpected-warning count already fails such a run.
2. **Fail the scale subprocess's other `WARNING:` lines.** The live test still ignores them. In CI, where no assets
   are staged, the subprocess prints the sound cues' "plays silent" warnings.
   - The options: fail on any `WARNING:` except a named, machine-dependent fragment, the way
     `tolerate_diagnostic` works, or keep the scope to the exit report (as built).
   - Recommended: the first, as a follow-up.
3. **Give the soak's end the same audio wait.** The soak's 30-frame close (`soak_test.gd CLOSE_FRAMES`) can race in
   the same way. Its exit-report reader already sets audio classes apart, so this matters less there.
   - Recommended: add the same WeakRef wait when that harness is next touched.

## Source

Brendan's ruling on R06 (2026-10-02). The finding is in `docs/reviews/2026-10-02-codex-review.md` on branch
`codex/review-2026-10-02`. Decisions 0501 (a clean
log is asserted), 0561 (the scale test and its tolerance), 0921 §7 (sounds in the exit report) and 0922 (the cycle
broken). The runs above are on the development Mac with staged assets, Godot 4.7.2.
