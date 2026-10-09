# ADR1147 source motion fixed-tick sampler

Candidate 3 is independently accepted as a source/time component. This packet implements the
DEC-050 / ADR1145 timing choice for the existing accepted Motion source image.
It does not activate a route, publish a traversal profile, write a Transform,
or claim native/World qualification.

## Mapping and output contract

| Program | Source / clip | Complete intervals | Adopted fixed ticks | Intervals per tick |
|---|---|---:|---:|---:|
| 0, ascent | 0 / 0 | 90 | 30 | 3 |
| 1, descent | 1 / 0 | 90 | 30 | 3 |
| 3, supported turn with 174u reposition | 2 / 1 | 270 | 45 | 6 |
| 2, approach; 4, retreat | 2 / 0; 2 / 2 | 90 each | Not adopted; refuse | — |

`Clock.sample_into(actual_motion, revision, program, from_tick, to_tick,
pose_out[9], intervals_out[2])` uses exact integer command types and elapsed
ticks. It returns the existing Motion `phase_into` result at
`q = to_tick * step * 65536` and the complete half-open crossed interval range
`[from_tick * step, to_tick * step)`. A source phase includes source frame,
heading and root; stationary roots never delete source intervals. The terminal
sample is the actual last/last/zero pair. Pause gives an empty interval range
and unchanged source pose. Both caller arrays retain all prior values on refusal.

The original immutable wire digest is
`495b22dacb303152651f8ca061a0017aa72a4031e281ac1df34dd9035bf695a0`.
The actual concrete Motion Script and its own current Profile/Level/World
identity are required. Timings do not transfer to another wire, cast, load or
connector. The original source-only wire rate fields remain zero and
`activation_refusal()` still returns `MOTION_SOURCE_ONLY`.

The actual route owner must supply committed progress, verify every reported
interval against actual support, paid parts and occupancy, and own save and
interruption meaning. Source frame offsets/root/heading are taken from Motion;
this helper adds no second rotation, distance clock or presentation interpolation.
Full approach/retreat timing and physical playback remain separate work.

## Exact results

The clean official singleton in `candidate-3` passed **14 tests / 2,090
assertions / zero failures**, all strict/raw diagnostics, expected/tolerated
diagnostics and leaks zero. The analyzer reports **zero warnings / two files**.
Six source-census tests pass. All **1,195** input hashes match before/after;
the invocation records exact HEAD, commands, unique user directory and restored
project/registry/assets/import sidecars. The new stateless registry appendix
was explicitly authorized for this test and restored; parent owns its permanent
integration.

Tests cover every supported fixed tick, exact endpoints and absolute source
frame offsets, complete interval partition, a real stationary lift interval,
pause/repeated/batched ticks, strict integer types and overflow bounds, absent
timings, output shapes and unchanged refusals, a substituted Motion subclass,
unloaded source, changed revision, retired/reused World and actual Profile
replacement. Positives load the real published Profile wire, Level pack and
Motion wire through the existing actual-owner fixture, with no synthetic
certificate flags or private bank writes.

## Joint source census

The stateless helper adds no retained fields, bank, per-resident clock or
packed allocation. Its four integer-valued Variant command payloads, local
scalars and nested duration helper occupy a maximum **64 logical bytes**;
numeric constants add 16 and an expression allowance adds 128: **208 bytes**
within the proposed 256 ceiling. The largest actual Motion-phase-plus-clock
numeric chain is 176. Keeping the whole existing Motion maximum and adding the
clock maximum conservatively gives **1,298 / 4,096 helper bytes**, or 1,346 when
charging the entire 256 ceiling.

The two caller outputs total **44 bytes**, replacing a packet within the
existing 176-byte caller ceiling. Combined Profiles/Level/Motion admission is
unchanged at **232,436 / 262,144 bytes**. The shared 32,768-byte native allowance
remains provisional and unmeasured; its inventory now explicitly includes the
shared Clock Script/digest/StringNames, transient Variant representation and
borrowed references. No whole-client or new native allocation qualification is
claimed. `census.py` imports the accepted shared Motion census and rejects
retained state, helper allocation, unbounded growth, lost integer guards and
changed output shape. Root owns reconciliation into the shared ledger.

## Reproduction and history

Own branch `codex/underground-motion-clock` starts with 205ec79e, exact accepted
Motion 0aeb7f82 cherry-picked as 6b6689b8, and accepted registry/ledger 1eb7a64d
as 798220a7. No existing production source is edited by this increment.

The fresh worktree deliberately began without staged demo assets and with
LFS pointers. Candidate 1 exited 1 after a nominal exit-zero import emitted
actual invalid-PNG/GLB diagnostics; no tests ran. The complete raw log is kept.
Only existing locally cached LFS objects for the 746 visible scanned paths in
`lfs-materialization.json` were checked out and verified against their exact
OID hashes. No network generation, paid service or main-worktree edit occurred.
The failed import's generated tracked sidecars were restored, and incidental
untracked import/UID sidecars were later removed (exact paths retained).

Candidate 2 passed the same 14/2090 suite, then correctly failed its analyzer for
a test subclass's unused `_revision` parameter shadowing Motion's member.
Candidate 3 changes only that parameter name. The old test bytes and locator are
retained under candidate 2. Candidate 1's earlier wrapper is retained separately;
candidate 2/3's wrapper additionally restores incidental import sidecars. A small
initial census harness omitted the data Catalog from the shared source index;
its failed log is retained under `census-rejected-v1`, before the same six tests
passed with the real Catalog included. Historical logs are not rewritten.

With this exact prerequisite state and actual local LFS files present, run from
this worktree (the output directory must not already exist):

```sh
python3 -B docs/validation/evidence/underground-motion-clock-2026-10-04/reproduce.py \
  --out docs/validation/evidence/underground-motion-clock-2026-10-04/reproduction-new \
  --port 6317
```

The wrapper selects the exact singleton using `ci_test_shards.py`, then runs
the unchanged official `tools/run_tests.sh`, raw import checks and
`gdscript_warnings.py --max 0`. Candidate 3's exact singleton is 257/392; use the
computed selection if the corpus changes. The temporary appendix is refused
if a permanent Clock registry row already exists: that later integrated state
must use the normal registry and its own explicit reproduction record. The
current packet is selected-suite component evidence, not a no-argument full
suite or gameplay milestone.

## Independent review

Root verified all seven frozen source/UID/helper hashes, traced the actual
Motion preflight and source/output lifetime, checked complete 3/6-interval
mapping and integer bounds, and independently reran the six census tests.
No blocking finding remained. Root explicitly accepted only the source/time
boundary; actual route/presentation activation and permanent registry/shared
helper accounting remain separate. Executable hashes were unchanged during
review and packaging.
