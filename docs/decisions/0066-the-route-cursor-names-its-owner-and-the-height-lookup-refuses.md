# 0066 — The route cursor names its owner, the height lookup refuses, and the hot path carries scalars
Date: 2026-09-11 · Status: Accepted

Three defects found by an independent adversarial review of `movement.gd`, all
three confirmed against `master` at `a34afb0` before any change was written.

## Decision

### 1. `ResidentRouteCursor` gains a fourth column, `_cursor_owner_id`

`_advance_row()`'s only identity check was `_residents.ref_of(row)`, which
answers with whoever occupies that **typed row now**. The three cursor columns
stamped the *route* generation and never the *owner*, so the row's route
outlived the entity it was attached for.

The failure is reachable and needs no misuse. Resident A travels in row 7.
`residents.despawn()` (`residents.gd:488`) clears the row and the directory slot
and **does not call `movement.stop()`** — nothing does — so `_movement_phase[7]`
stays `MOTION_TRAVELLING` and `_cursor_request[7]` still names a `PHASE_READY`
request, which keeps `_route_still_valid(7)` true. `entity_directory.create()`
hands typed rows back from a **min-heap** (`entity_directory.gd:144`), so the
next resident spawned is very likely to land in row 7. On the next
`advance_tick()` the guard saw a live reference and walked **B along A's route**,
with `_travelling_count` a resident too high for the whole interval.

One honest qualification, since defect 4 in the same review is about exactly this
kind of claim: **`movement.gd` has no production caller either.** The only
`preload` of it in the repository is `godot/test/test_movement.gd`, so today the
hazard is latent rather than live. The guard lands before the wiring instead of
after it, which is the cheap order.

`_cursor_owner_id[row]` is stamped at `_attach_route()` with
`_directory.get_persistent_id(resident)` and compared in `_advance_row()`; a
mismatch settles `MOTION_ROUTE_LOST`. `stop()` releases it to `NO_OWNER_ID`.

**It is the persistent id and not a generation**, for the reason
`transforms.gd:27-33` already records and decision 0053 repeats: a generation
belongs to a directory **slot**, every slot's first use carries generation 1, and
slots and typed rows come from separate free heaps, so a generation stamp matches
across two different entities routinely. `test_movement.gd` makes that
observable rather than assuming it — the owner-stamp test creates an unrelated
entity first so the traveller's persistent id and its slot generation are
different numbers, and an implementation that stamped `resident.y` fails it.

This is the same shape as `transforms.gd`'s `_bound_persistent_id`, and the two
modules now guard the same hazard the same way instead of one being protected and
its neighbour not.

### 2. `_height_at()` becomes `_height_at_into()` and refuses

The old form returned `0` on two distinct lookup failures.
`world_init.gd:222` defines `WATER_SURFACE_Y_UNITS = 0`, so **0 is an authored
height**, not an absence: a failed lookup was indistinguishable from standing on
open water, and the value went straight into `_transforms.advance()`, which is
authoritative state. That is exactly the in-band sentinel AGENTS.md and
decision 0059 forbid.

It now returns a bool and writes through `IntMath.IntResult`, and
`_advance_row()` settles `MOTION_ROUTE_LOST` on a refusal — the treatment it
already gave a failed `read_into`. No height is committed for a position that has
none.

### 3. The per-tick path constructs nothing

`_consume()` returned a packed `Vector2i` pair, which forced `_spend_budget()`
and `_advance_row()` to build roughly 35 `Vector2i` per travelling resident per
tick at `MAX_SEGMENTS_PER_TICK = 8` — about a million a second at 256 residents,
30 Hz, 4x. `Vector2i` is a value type, so this was never a leak; it is
CLAUDE.md's own named banned pattern, and every other per-tick store here
(`scheduler_events.gd`, `navigation.gd`'s A\* inner loop) works on scalars.

`_consume_into()` writes `_step_position`/`_step_budget`, `_spend_budget()`
writes `_here_x`/`_here_z`, and both callers read scalars. One implementation of
the clamp remains; it was split by output, not duplicated.

**Behaviour is unchanged, and that was proved rather than asserted.** A scratch
scenario — four residents of two size classes on four routes including the ford
crossing, 400 ticks — was digested with `transforms.authoritative_digest()`
against the pristine module and against the rewritten one:

```
pristine (a34afb0): DIGEST=1955880550 MOVED=1013 EXPANSIONS=1564
rewritten:          DIGEST=1955880550 MOVED=1013 EXPANSIONS=1564
```

## The ledger, and the row this change cannot write itself

The fourth cursor column costs `512 × 4 =` **2048 bytes**, taking
`ResidentRouteCursor` from decision 0053's **6144** to **8192**.

Carried through decision 0054's post-merge basis, the figures would be:

| Quantity | Ledgered now | With this column |
|---|---:|---:|
| Decision 0053's addition | 520192 | 522240 |
| Planned allocated payload | 60821078 | 60823126 |
| One live world plus reserve | 69209686 | 69211734 |
| Headroom below decimal 100 MB | 30790314 | 30788266 |
| Additional candidate mutable state | 54605494 | 54607542 |
| Rejected two-world peak | 123815180 | 123819276 |

**Those rows are NOT applied by this change.** `docs/systems_architecture.md`
§2.3 and `docs/validation/ready07_arithmetic.py`'s `DECISION_0053_ADDED` are
owned by other work in flight and are byte-unchanged here, so the ledger reads
2048 low until their owner applies the table above. `movement.gd`'s header names
the gap at the column that causes it. The registry row that *is* written is in
`docs/persistence_state_registry.md`, classified **category 1,
future-affecting** and assigned §9 NAVIGATION with the rest of the cursor: a load
that dropped the stamp would let one reused typed row walk the wrong body,
which is the precise divergence the column exists to prevent.

## What was considered and not done

- **Making `residents.despawn()` call `movement.stop()`.** It would close this
  instance and leave the class open: any other path that releases a typed row —
  a future bulk clear, a loader, a migration — reopens it, and a store reaching
  into the mover inverts the dependency direction. The guard holds whatever
  clears the row, and is cheap: one int compare per travelling resident per tick.
  `residents.gd` is untouched by this change.
- **Settling the mismatch as `MOTION_IDLE` instead of `MOTION_ROUTE_LOST`.**
  `IDLE` would read as "this body has no route", which is true of the successor
  but silently loses that a route *was* abandoned mid-flight. `ROUTE_LOST` is the
  phase that already means exactly that, and it is what `transforms.gd` chose in
  shape: report the stale binding rather than absorb it.
- **Zeroing the whole cursor on a mismatch.** Rejected for the same reason
  `_settle()` retains the remainders: the row is diagnostic evidence until its
  next `_attach_route()`, which resets everything anyway.
- **A refusal code on `advance_tick()`.** `_advance_row()` has never set
  `_last_refusal`, and making one of four settle paths set it would leave the
  accessor meaning two different things. The phase is the report.

## Evidence

Suite before: **2365 test(s), 92629 assertion(s), 0 failure(s)**. After:
**2369 test(s), 92683 assertion(s), 0 failure(s)** (`./tools/run_tests.sh`).
`docs/validation/ready07_arithmetic.py` and
`docs/validation/state_registry_coverage.py` both PASS.

Four tests were added and one dead assertion was repaired:
`test_movement.gd:370` read
`assert_equal(_x_of(mouse), _x_of(mouse), "the body is exactly where it was")` —
the same expression twice with no intervening call, an assertion that could not
fail. It now captures `before_x` ahead of the 120-frame paused loop.

**13 mutations, one per Godot invocation, `movement.gd` restored and
sha256-compared against a pristine copy after every one. 11 killed, 2
equivalent, 0 real survivors.** The failure count is parsed as an integer, not by
substring — the very first mutation reported **10** failures, and a harness
testing `"0 failure(s)" not in summary` would have called that a survival.

| # | Mutation | Result |
|---|---|---|
| 1 | stamp the owner id as nobody | killed (10 failures) |
| 2 | owner comparison always `true` | killed |
| 3 | drop the owner guard from the advance condition | killed |
| 4 | `stop()` no longer releases the stamp | killed |
| 5 | compare the directory **generation** instead of the persistent id | killed |
| 6 | height lookup returns the water-surface 0 on a bad position | killed |
| 7 | height lookup reports success whatever the cell read did | **equivalent** |
| 8 | `_advance_row()` ignores the height refusal | killed |
| 9 | `_consume_into()` keeps the whole budget after paying a segment | killed (2) |
| 10 | `_consume_into()` banks the leftover on a partial step | killed after a test was added |
| 11 | the X scratch is read after the Z call clobbers it | killed (6) |
| 12 | `_spend_budget()` publishes the start instead of the walked position | killed (6) |
| 13 | the cursor columns are allocated but never marked ownerless | **equivalent** |

Mutation 5 is the one that justifies the extra entity in
`test_the_route_cursor_records_its_owner_and_releases_it_on_stop`. Without it the
traveller is the first entity created, so its persistent id and its generation
are **both 1** and stamping the generation passes by coincidence — the exact
collision `transforms.gd:27-33` warns about, reproduced here as a live mutant.

Mutation 10 initially survived, which is a real coverage finding rather than an
equivalence: `_spend_budget()` breaks out of its loop the moment an axis falls
short, so the partial-step leftover is unobservable from every public path.
`test_one_clamp_step_publishes_both_scalars_and_leaves_no_stray_budget` exercises
`_consume_into()` directly, as `test_needs.gd` already does with
`_integrate_step`, and kills it.

The two equivalents are kept and documented at the line, not deleted:

- **7** — `cell_of_position_into()` only succeeds on an in-range cell, which is
  exactly what `height_units_into()` re-checks, so its refusal is unreachable
  through `_height_at_into()`. The guard costs one branch and keeps the two
  modules' bounds from drifting apart silently.
- **13** — `PackedInt32Array.resize()` zero-fills and `NO_OWNER_ID` is 0, so the
  explicit initialization writes the value the allocation already wrote. It is
  written because the column's null value is part of its contract, not a property
  of the allocator.

The repaired dead assertion was itself mutation-checked: inserting one
`advance_tick()` into the paused-clock loop makes it fail with
`the body is exactly where it was (expected 98560, got 98669)`. The test file was
restored and sha256-compared afterwards.

## Source

`docs/systems_architecture.md` ARCH-SYS-012, ARCH-MEM-008; AGENTS.md's
integer-state and `EntityRef` non-negotiables;
[decision 0053](0053-movement-ground-slice-identity-and-storage.md) for the
cursor and the persistent-id precedent;
[decision 0059](0059-allocate-before-consume-is-a-repository-wide-rule.md) for
refusing rather than returning a sentinel;
[decision 0062](0062-the-future-affecting-state-registry.md) for the registry
row; `godot/scripts/core/transforms.gd:16-33` for the hazard this now shares a
defence with.
