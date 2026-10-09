# 1142 supported stair handoff source

Status: **offline source candidate; independent review pending. Zero production
qualification.** No live consumer, profile, renderer, pace, timber cost or
runtime capacity changed. The accepted 1139 ascent/descent tables are unchanged.

The final source is `candidate-6/result/`, with all six continuous results under
`proof-v1/`. Candidate 6 has exactly the same F32 palette and grounding bytes as
candidate 5; its endpoint metadata now reports the actual retained ready pose,
including the slightly raised right foot. `palette-comparison.json` records
that equality. The final small tests are `tests-5/`: 8 source-equation checks and
13 proof/column checks, all pass. Source SHA manifests bind every executable.

## Actual finite source

The three new nonlooping clips retain original body, clothing, active pick,
materials, topology, weights, rig lengths, ankle/toe links and ready pose. Only
actual local leg rotations and explicit source root/heading/foot keys change.
There are 91 approach keys, 271 turn/reposition keys and 91 retreat keys. No
stationary interval is removed. All clips begin/end at the exact compact ready
palette/grounding digest
`393edbafa3490d93e19959d5b8e84b5022bfd475a2afdfca79754712e7fdf462`.

The fixed root-authored 1113 frame is:

| Source | Start root XYZ / yaw | End root XYZ / yaw | Intervals |
| --- | --- | --- | ---: |
| New approach | `(0,0,-1536)` / 0 | `(0,0,-1879)` / 0 | 90 |
| Accepted descent | `(0,0,-1879)` / 0 | `(0,-128,-2391)` / 0 | 90 |
| New turn/reposition | `(0,-128,-2391)` / 0 | `(0,-128,-2217)` / 32768 | 270 |
| Accepted ascent | `(0,-128,-2217)` / 32768 | `(0,0,-1705)` / 32768 | 90 |
| New retreat | `(0,0,-1705)` / 32768 | `(0,0,-1536)` / 32768 | 90 |

`column-proposal-v2/result/program.json` checks all four root/heading/pose joins
against the actual accepted source images and fixed fixture placements. It
does not turn the earlier exact fixture quarter-turn proof into native-yaw
permission. The terminal heading is 32768; there is no reset to the initial
heading and no closed-loop route claim.

Q16 phase selects an adjacent source pair; the terminal pair repeats the final
key with share zero. Signed componentwise ceil evaluates the fixed-frame root
once. The integer interpolated heading selects an exact row from the original
65,536-row OpenGL WorldBasis. That moving basis rotates local skinned geometry;
it never rotates or reapplies the already fixed-frame root. Source joint
authoring uses proper rotations to preserve link lengths; playback/proof keeps
the native table's nonunit coefficients. Tests reject both double-root and
root-rotation equations and a substituted normalized playback basis.

The half-turn alternates actual feet, narrows the ankle stations during its
middle headings, holds the root while completing the turn, then moves the
remaining 87u. The complete foot geometry is unchanged. Flat handoffs use a
32u foot lift; this is authored geometry, not a tolerance or pace. Exact ready
has only the left foot in contact; no second contact is invented at endpoints.

## Continuous source proof

Every new interval includes all **10,209 body/clothing and 1,150 tool triangles**
against all **22** unchanged positive fixture prisms: 14 timber parts and 8
natural bearing parts. The actual L0 top is Y0; T0 top is Y−128. The full 2×2m L0,
64u decks, bearers and posts are retained. A whole-body collision box is only
an outward search bound; it never excuses a triangle from the solid proof.

| Source | Terrain/support checks | Tool/non-palm checks | Intervals | Result |
| --- | ---: | ---: | ---: | --- |
| Approach | 869 | 522 | 90 | Clear |
| Turn/reposition | 3048 | 1566 | 270 | Clear |
| Retreat | 874 | 522 | 90 | Clear |

The proof encloses the coupled local affine interpolation, finite heading
range and signed-ceil root with outward integer interval arithmetic. It checks
the actual rotating path, not a line between world-space endpoints. Exact
integer separating planes plus bounded Q16 subdivision prove separation;
exhaustion refuses. A continuous full-foot XZ enclosure must lie in the actual
support prism and a single actual vertex must retain its contact throughout
the interval. The complete anatomical foot triangles, including mixed boundary
triangles, remain in collision proof. The source must stay at or above its
plane before any numerical sole residual exception is considered. Real
positive penetration is never permitted by that exception.

Tool/non-palm proof uses the accepted common-origin simplex argument and the
full finite inverse-heading norm to enclose native errors in the source frame.
All 450 intervals are covered by overlapping bounded source hulls. The 448
intentional palm triangles are excluded only from tool/palm self-contact;
all 10,209 body triangles remain in terrain proof. This is not a general
limb-versus-limb self-contact or native visual-quality certificate.

All numerical terms retain their original source/GL backend/full root-range
scope. Metal input census is not a Metal skinning certificate. The source
reconstruction uses the unchanged accepted 1139/1137 adapter and exact eleven
historical script locators plus the original Profiles predecessor. All 537
original inputs are checked, current files are observed unchanged, and only
private temporary source copies are used. Missing ignored raw inputs refuse.

## Retained refusals

- Candidate 1 refuses the first approach: requested leg reach 256.48586u exceeds
  its actual 130.46299u + 123.05965u links. No bone was lengthened.
- Candidates 2–4 retain their unresolved higher-L0-deck triangle witnesses.
  Candidate 4's separately labelled sample-only diagnostic finds actual left
  toe intrusion during the 64u flat lift. Sampling is not the later certificate.
- Candidate 5 reduces only the flat lift to 32u and passes; candidate 6 keeps
  that exact geometry and corrects endpoint diagnostic metadata. All failed
  source images, exact executed snapshots, results and logs remain.
- The first comparison helper attempted an unavailable parser `id` field;
  comparison was rerun using the three explicit source roles. This was a
  diagnostic-script error, not a source/proof failure or a successful run.

## Measured finite storage, no allocation

The optional offline column proposal contains 3 program rows, 453 root/heading/
plant keys, 450 interval rows, 681 exact unique collision boxes, 306 unique
support records, 450 support references and 22 solids. It retains every interval,
primitive identity and source witness. Exact deduplication removes only equal
rows; there is no guessed box cap or geometry reduction.

The numeric proposal is **48,548 bytes per bank; 101,368 bytes** for live plus
replacement banks, 4096-byte decode scratch and 176-byte caller scratch, before
native controls. The distinct prior 1139 proposal is still 42,704 bytes. Neither
fits the latest reported 5,314-byte joint headroom after 1141 controls (1140
remains excluded). The retained column-proposal-v1 records the earlier
8,386-byte headroom; v2 changes that reference only. No runtime arena exists and no
existing Profiles capacity was reduced. This column layout is unadopted.

The new presentation image is 545,892 bytes; retained palettes and simultaneous
raw decode staging are each 545,412 bytes. Its existing content-reader estimate
also charges 456 bytes of tables, 4,396,032 bytes of borrowed mesh-array working
allowance and a 2,097,152-byte unmeasured native/control reservation: 7,039,052
bytes before the separately shared 544,768-byte Basis reservation. This is a
source-counted estimate, not measured native memory. Simultaneous old/new source
images, original borrowed mesh/texture resources, source strings, per-Actor RIDs,
shared Basis and any actual runtime copy lifetime still need a coupled owner
admission; the simulation ledger is not whole-client proof.

## Reproduce

Use this exact NumPy-enabled interpreter; bare `python3` is not assumed to have
NumPy. Run from this worktree root and choose new output directories.

```sh
HANDOFF_PY=/Users/brendan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3
HANDOFF_BASE=godot/data/underground/mole-worker/evidence/contact-qualification
"$HANDOFF_PY" -B "$HANDOFF_BASE/test_stair_handoffs.py"
"$HANDOFF_PY" -B "$HANDOFF_BASE/test_stair_handoff_proof.py"
"$HANDOFF_PY" -B "$HANDOFF_BASE/author_stair_handoffs.py" "$HANDOFF_BASE/stair-handoffs-v1/replay-new/source"
"$HANDOFF_PY" -B "$HANDOFF_BASE/prove_stair_handoffs.py" "$HANDOFF_BASE/stair-handoffs-v1/replay-new/source" "$HANDOFF_BASE/stair-handoffs-v1/replay-new/proof" --name turn --kind terrain
```

All six exact executed proof commands, source pre/post pins and exit results
are retained in `proof-v1/*/*/invocation.json`; repeat with unique output paths.
The column command is in `column-proposal-v2/invocation.json` and requires all
six proof results for the same exact source image. It does not trust a clear
flag for a different image or silently omit an interval/support record.

## Remaining gates

Independent source/math review; native visual and rendered-deformation replay
of the new coupled root/heading equation; full existing stair cardinal/native
scope; default Metal numerical closure; actual paid Placement/Region/support
identity; finite authoritative phase/pace/save and interrupt/retreat lifecycle;
profile/runtime publication; reviewed storage reuse; and whole-client memory
and tick performance. No World, stair, first-prefix, rate or handling permission
is implied by this offline candidate.
