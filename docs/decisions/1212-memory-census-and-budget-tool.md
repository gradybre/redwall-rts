# 1212 — Joint memory census after content 6, and the memory budget tool

Date: 2026-10-06 · Status: Accepted (tool and census). **The 100 MB gate fails; this needs Brendan's decision.**

## 1. Why `underground_memory_budget.py --check` failed

ADR 1206 reported that the check failed on the qualified-step-v4 witness digest. That was only the first
check the tool happened to run. A bisect on archived trees shows:

- **Last passing commit:** `94dca0a3` (pack 99,999,806 B, headroom 194 B).
- **First failing commit:** `6a8ea69e`, which changed `underground_connector_placements.gd`, a source
  pinned by `memory-manifest-3.json`.
- **Drift by HEAD:** 20 pinned current sources and 6 witnesses, across about 60 commits. The witness
  `qualified-step-v4/catalog_source.gd` changed through in-place pin renewals at `2d9f2cf1`, `0ea4b44a`
  and `a8060ef3` (ADR 1214's historical-publication class).

**Root cause.** The room census (`underground_room_memory.py`) replays frozen, independently reviewed
producers, and every input they read is byte-pinned. Any edit to any of the 65 pinned sources stops the
whole check. No mechanism existed to carry a later change forward short of a new manual review.

**Why nobody noticed.** The check is wired in CI: the `contracts` job in `.github/workflows/tests.yml`
runs `--check` and `test_underground_memory_budget.py`. That job runs only on pull requests and on pushes
to master. The single integration branch never had a PR, so the job never ran on any of this work. The
test runner (`tools/run_tests.sh`) does not run it, and that is deliberate: it is a contract check, not a
Godot suite.

**Rejected fix: renewing the pins.** There is no renewal tool, and the frozen producers fail on real
storage changes (for example "packed resize topology underground_profiles"). Re-pinning would admit
uncounted storage.

## 2. The fix (step 1, `53fe59f6`)

The fix separates the historical replay from the current count.

- **Historical projection.** `underground_room_memory.verified_inputs` replays the reviewed producers on
  the archived manifest-3 bytes of each drifted input:
  - `docs/validation/evidence/underground-memory-census-2026-10-06/reviewed-sources/` holds those bytes,
    taken from `94dca0a3`;
  - `projection.json` lists them and is pinned by `PROJECTION_SHA`;
  - the result lists every projected input (`projected_reviewed_inputs`).

  This follows ADR 1214: historical evidence reads the bytes it was built from. The bytes are archived in
  the repository and not read through `git show`, because CI checks out with depth 1.
- **Current recount.** `tools/underground_current_census.py` (step 2) checks the current bytes of every
  projected input. If a pinned input changes and has no projection row, the check still refuses.

Rows renewed because their sources legitimately changed:

| Row | Change |
|---|---|
| Motion census | Content 6: 42 rows, 377 boxes and **4** sources. The tool had hard-coded 1 source; Session configures `Catalog.SOURCE_COUNT`. The `HEADER` literal's `REVISION` is resolved. The joint is **247,580** B (Profile 62,432, was 53,756). |
| Profile reconcile | The joint is the current Motion count + 1,536 (Session) + 8,192 (retirement) = **257,308 ≤ 262,144** (`PROFILE_BYTES`). The reviewed 248,632 is kept as `historical_joint`. |
| Clock executable pin | Renewed. Only the same-length wire-digest constant changed, which was checked by substituting it back and reproducing the old hash. |
| Delivery | +1 retained bool (`_excavation`); fixed bytes 754 and total 3,827 ≤ 4,096. The new configure-refusal guard lines are added to the expected list. The allocation scanner now skips multi-line docstrings; previously it refused them as "ambiguous". |

## 3. The joint census (step 2)

The census covers simulation-owned memory at 256 residents, with:

- the first-entry owners mounted;
- content 6 (`qualified-stone-v7`);
- both geometry journals;
- haul and stone content.

For each projected input, `underground_current_census.py` compares the storage structure of the reviewed
and current bytes:

- retained members, including nested packet classes;
- packed resizes;
- integer constants;
- allocation-site counts.

The difference must equal the row in `reviewed-deltas.json`, which is pinned by `REVIEWED_SHA` and records
each change's bytes and what carries them. New owners must match an exact member set. Each count is
recomputed from source.

| Store | Bytes | Carried by |
|---|---:|---|
| Content-6 Profile bank (paired, +4 sources) | +8,676 | `PROFILE_BYTES` joint (257,308 of 262,144) |
| Profiles load-time key-order scratch + source digests | 432 | Profiles `CONTROL_RESERVE` (load-time) |
| WorldRoutes `_envelope` + 6 numeric carry controls | 58 | WorldRoutes `CONTROL_RESERVE` (fixed now 924 of 4,096) |
| WorldRoutes `Clearance.changes` (ADR 1205) | 7,168 | WorldRoutes cold 385,024 ≤ `Budget.COLD_BYTES` 1,048,960 |
| Contact-retirement scope private packets | 9,420 | The whole shared cold lease it acquires |
| SurfaceAnchor `_last_checks` | 8 | SurfaceAnchor `RESERVED_BYTES` |
| HaulPlanner and StorePolicy host instances | 0 | Base ledger (decisions 1023, 1031) |
| Ground pace rows (15) | 0 | Catalog's fixed `MAX_PACES` 256 bank |
| **Geometry journals ×2** (ring of 256 sides) | **16,994** | **New: no reserve carries them** |
| **Locations carry controls + retirement context** | **129** | **New** |
| **First-entry runtime chain** | **2,454** | **New** |

The runtime chain is the runtime, Published (11 endpoints), Crew, foreman, 20 tasks (from the pinned
Frontier: 3 × 6 episodes + 2 installs), installer, Plan, and a fourth Quote consumer that the Quote census
did not see.

`BINDINGS_AND_GROWTH_BYTES` is fully assigned (524,288 of 524,288). Routes' actual
`LOCATION_AND_TOPOLOGY` admission is 1,041,728 of 1,048,576, so the journals do not fit there either.
`TERRAIN_BYTES` and `LAYOUT_COLD_BYTES` are envelopes that no runtime code admits. Assigning new stores to
them is a budget decision, so it was not done.

**Result:**

| | Bytes |
|---|---:|
| Joint pack | **100,019,383** |
| Gate | 100,000,000 |
| Headroom | **−19,383** |
| Before (last pass) | 99,999,806 (headroom +194) |
| New contributions | 19,577 |

`--check` therefore fails with `joint pack exceeds unchanged memory limit`. That is the correct outcome, so
the pack artifact is not regenerated and `ready07_arithmetic.py` still records 99,999,806.

**Presentation, outside the gate.** REQ-SET-163 bounds *simulation-owned* memory at 100 MB, and
presentation counts toward the 4 GB process budget (ADR 1201). The declared presentation set is
21,256,576 B, or 28,541,580 B with the stone image (v9 declared peak 7,285,004; image 791,844 B).

## 4. Brendan's decision needed

Choose one:

- (a) Assign the 19,577 B to an envelope no runtime code consumes (`TERRAIN_BYTES` or `LAYOUT_COLD_BYTES`)
  and enforce it at runtime.
- (b) Shrink the journals. 128 sides each saves 8,484 B, but that alone is not enough, and a smaller ring
  raises the full-recheck fallback rate.
- (c) Accept a new contribution and raise the ledger's Auxiliary reserve, which needs a matching cut
  elsewhere in the 86.6 MB base.

## 5. `clipped_triangle_floor` (step 3): not a bug

ADR 1198 recorded that `compile_profiles.clipped_triangle_floor` takes `.min()` where `.max()` belongs.
The line is:

```python
large = max(large, int(-np.floor_divide(-numerator_high, denominator).min()))
```

Method calls bind tighter than unary minus, so this is `-(floor(-n/d).min())`, which equals
`max(ceil(n/d))`. That is the maximum crossing rounded outward. The haul derivation's "corrected copy"
(`derive_haul_rows.py`: `(-np.floor_divide(-n, span)).max()`) computes the same value.

**Checks:**

- 200,000 random arrays: no elementwise mismatch.
- 20,000 random whole-function cases against `clip_below`, 19,688 of them with floor geometry: 0
  differences.
- A mutation to a real minimum is caught by a two-triangle case (5 instead of 20).

**Outcome:** no published row or box changes, and nothing is republished. `compile_profiles.py` is left
byte-identical, because its SHA-256 is pinned in about 270 evidence files and asserted by two live
haul-handling tests. ADR 1198's note is corrected by this record.

## Tests

| Suite | Result |
|---|---|
| `test_underground_current_census.py` (new) | 8 pass |
| `test_underground_room_memory.py` | 37 pass |
| Motion and clock suites | 5 + 5 pass |
| `test_underground_memory_budget.py` | 277 of 285 pass |

The room memory tests now expect a mutated *projected* input to be refused by the current census, not by
the replay. The motion and clock tests were stale on content 3 and now use content 6.

The 8 budget-suite tests that fail all build the whole pack and stop at
`joint pack exceeds unchanged memory limit` (100,019,383). They pass once §4 is decided.

`decision_numbers.py` already failed before this change, because two records claim 1205.

## Not covered

- **Helper frames.** The numeric helper frames of changed call chains are not re-proved here. About 5,900
  changed lines (Routes, WorldRoutes, Locations, Delivery and others) stay inside each owner's declared
  helper/native allowance, as in the original reviews.
- **Unmeasured overhead.** Object, Array and Variant headers are unmeasured, as in every other row.
- **Native measurement.** None was made.
- **Recommendation.** Open a PR for the integration branch, or add it to the workflow's push branches, so
  that the contracts job runs.

## Files

- `tools/underground_room_memory.py`
- `tools/underground_current_census.py`
- `tools/test_underground_current_census.py`
- `tools/underground_motion_memory.py`
- `tools/underground_motion_clock_memory.py`
- `tools/underground_memory_budget.py`
- `docs/validation/evidence/underground-memory-census-2026-10-06/`
- the CI contracts step
