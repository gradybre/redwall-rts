# Source review — W1 save-layer runtime install contract

2026-09-19. Read-only audit of the reviewed sources only. **Nothing was run, built or applied.**
No production file is edited by this document and no runtime acceptance is claimed. Astra owns
every decision below; this is advice plus an explicit unresolved list.

**RESTORE-R01 is acknowledged and is the governing ruling here** (`docs/rulings/2026-09-12_clock_restore_and_layout_followup.md`).
Where this review and RESTORE-R01 could be read apart, RESTORE-R01 wins.

## 1. Correction of record: the "no writer" premise is false

`save_section_world_runtime.gd`'s BLOCKER W1 header states there is "NO WAY TO PUBLISH THIS BLOCK
INTO A LIVE `sim_clock.gd`" and that `_completed_tick`, `_debt` and the six counters "have NO
writer at all". At the reviewed source that is stale in three places:

- `sim_clock.gd` publishes `restore_runtime(...)` — the single validated ten-field assignment
  boundary RESTORE-R01 mandates — plus the static pure `restore_refusal(...)`.
- `sim_clock.gd` publishes `acquire_load_barrier()` / `LoadBarrier` / `is_load_barrier_held()`,
  and `restore_runtime()` is deliberately **not** on the barred command surface.
- `game_manager.gd` publishes `begin_load()`, `restore_clock_runtime(...)`,
  `publish_restored_world()`, `end_load()`, `rollback_load()`, and takes the clock token inside
  `begin_load()`.

So W1 is not "a missing API". W1 is **a missing joiner**: no module turns a decoded WorldRuntime
Record (and the section-10 Record that depends on its seed) into those existing calls. The
planning matrix's own 2026-09-19 reconciliation already says this; the module header has not been
updated and should be, but that edit is out of this packet's scope.

## 2. Smallest complete contract: one joint §1+§10 adapter

**Recommendation: a single stateless adapter, not two independent publishers.** Reseeding RNG at
§1 time and then installing streams at §10 time is the worse shape, for reasons that are visible
in the reviewed source rather than stylistic:

1. `rng.gd::seed_world()` overwrites all nine states and zeroes all nine draw counts. Between a
   §1 reseed and a §10 apply the store is a **third state** that is neither the saved world nor
   the prior world. If §10 then refuses (zero state, negative count, tombstone non-canonical,
   length), the prior world is already destroyed and `save_section_rng.apply()`'s own rollback
   cannot help — it captures prior state *inside* `apply()`, i.e. after the reseed.
2. `restore_stream()` validates the HUNTING tombstone against `_world_seed`, so §10 is only
   checkable once §1's seed is installed. Seed install and stream install are one transaction by
   construction; splitting them across two callers splits a transaction across two owners.
3. The wrong-world check (§4 below) needs both the §1 seed and the §10 tombstone in hand.

Proposed module: `godot/scripts/core/save_world_runtime_install.gd`, `extends RefCounted`, all
static, no stored state, cold path. Suggested surface:

```gdscript
class InstallRefusal:      # code: StringName, detail: String, is_ok()
class Snapshot:            # tiny rollback record; see §6

static func preflight(world: SaveSectionWorldRuntime.Record,
        rng: SaveSectionRng.Record, header_completed_tick: int,
        clock: SimClock, store: Rng) -> InstallRefusal

static func install(world: ..., rng: ..., header_completed_tick: int,
        manager: GameManager, store: Rng, out: Snapshot) -> InstallRefusal
```

`install()` takes the **GameManager**, not the raw clock, because the barrier and the
`_started`/`_state` publication live there and RESTORE-R01 forbids a coordinator-only guard.
It does **not** call `begin_load()` / `end_load()` / `publish_restored_world()`: the coordinator
owns the barrier lifecycle, the adapter runs inside it. `install()` refuses if
`manager.is_loading()` and `manager.is_load_barrier_held()` are not both true.

This adapter claims **no** disk read, no file rotation, no section ordering, no digest, no world
replacement and no other section. It is one joiner for two already-decoded Records.

## 3. Validation order (all of it before the first write)

Decision 0059, allocate-before-consume, applied across two sections:

1. `SaveSectionWorldRuntime.extent_refusal()` / `SaveSectionRng.extent_refusal()` — caller's, if
   decoding here at all; the adapter should prefer taking already-decoded Records.
2. `SaveSectionWorldRuntime.record_refusal(world)` — tick, speed, mask, non-negative debt and
   counters.
3. `SaveSectionRng.record_refusal(rng)` — length, zero state, negative counts, HUNTING count 0.
4. **Explicit decoded header tick check.** `SaveSectionWorldRuntime.header_tick_refusal(world,
   header_completed_tick)`. RESTORE-R01: "Header completed tick and section1 tick must match
   before this API is invoked." This must be an explicit call in the adapter with its own refusal
   code, not an assumption that the header decoder already did it.
5. Seeded/unseeded semantics (§5).
6. `SaveSectionRng.tombstone_refusal(rng, world.world_seed)` — checked **against the saved §1
   seed**, before any store mutation, so the seed-dependent half is pre-validated rather than
   discovered inside `apply()`'s per-stream loop.
7. `SimClock.restore_refusal(...)` — the static pure form, run on the ten §1 values **before**
   `restore_runtime()` is called. See §7: this is the preflight for a write that can fail.
8. Barrier check: `manager.is_loading()` and `manager.is_load_barrier_held()`.

Only then: snapshot (§6), `store.seed_world(world.world_seed)`, `SaveSectionRng.apply(rng, store)`,
`manager.restore_clock_runtime(ten fields)`.

**Order of the two installs matters.** Install RNG first, clock last. `restore_clock_runtime()` is
the cheapest and best-validated of the two to redo, and `game_manager.gd` already holds its own
ten-scalar checkpoint from `begin_load()`, so a clock failure after a successful RNG install is
recoverable from the tiny snapshot without touching the clock at all.

## 4. Wrong-world obligation

The adapter must refuse rather than blend when the live store is not the saved world. Two checks,
both derivable from the reviewed source:

- If `store.is_seeded()` and `store.world_seed_value().value != world.world_seed`, the store
  belongs to a different world. Refuse (`WORLD_SEED_MISMATCH`) unless the coordinator has
  explicitly declared a full world replacement — which this adapter does not perform and must not
  silently assume.
- The §10 tombstone check in step 6 is a second, independent wrong-world detector: a section-10
  payload whose HUNTING state is not `seeded_state_for(world.world_seed, STREAM_HUNTING)` was
  written against a different seed than §1 claims, and is a corrupt or mismatched pair.

ARCH-NAME-001's positive-i32 naming domain is *not* imposed here; `save_section_world_runtime.gd`
is right that no contract restricts the saved seed, and this adapter must not invent one.

## 5. Seeded / unseeded semantics

§1 carries both `world_seed:i32` and `rng_seeded:u8`, and the byte is validated as exactly 0 or 1.
The adapter must treat them as one joint statement:

- `rng_seeded == true`: a §10 Record is **required**. Install seed then streams. A missing or
  absent §10 is a refusal, not a defaultable condition — `seed_world()` alone would restore every
  stream to draw 0 with plausible-looking values, which is exactly the silent divergence
  `save_section_rng.gd` exists to prevent.
- `rng_seeded == false`: the saved world had never seeded. The adapter must **not** call
  `seed_world()` and must refuse any accompanying §10 Record. The correct live shape is
  `store.clear()` (nine zero states, unseeded), which `rng.gd` already provides. Note the asymmetry
  this creates: `SaveSectionRng.capture_into()` refuses an unseeded store, so an unseeded world has
  no §10 payload at all — consistent, but it means §10's presence is conditional on a §1 field,
  which the section walker must be told.

Unresolved: whether a release save is *permitted* to be `rng_seeded == false` at all (Q-W1-2).

## 6. Bounded rollback: a tiny RNG snapshot, not a second world

Rollback state for this adapter is exactly:

- `Rng` prior seeded flag, prior world seed, and a `SaveSectionRng.Record` (nine i32 + nine i64,
  108 bytes of values). `capture_into()` produces it when the store is seeded; when it is not, the
  snapshot records "was unseeded" and rollback is `store.clear()`.
- **No clock snapshot is taken here.** `game_manager.begin_load()` already captured the ten clock
  scalars into its pre-allocated `_checkpoint` column and reinstalls them through the same
  `restore_runtime()` in `rollback_load()`. Duplicating that in the adapter would create two
  checkpoints that can disagree.

That is the whole rollback surface. No second `Rng`, no second `SimClock`, no shadow world. Note
that `SaveSectionRng._roll_back()` ignores the `OpResult` of each `restore_stream()`; the adapter's
own rollback should not, and should mark the load unrecoverable — reusing the coordinator's
existing `REFUSE_LOAD_UNRECOVERABLE` posture — if a rollback stream write refuses.

## 7. Preflight ownership: unchecked writes do fail

Three writes on this path can refuse, and each needs a named preflight owner:

| Write | Can refuse on | Preflight owner |
|---|---|---|
| `store.seed_world(seed)` | non-i32 seed; internal state conversion | adapter, via §1 `record_refusal` i32 bound + explicit i32 test on the seed |
| `store.restore_stream(...)` ×9 | zero/out-of-range state, negative count, non-canonical tombstone, unseeded | adapter, via §10 `record_refusal` + `tombstone_refusal` in step 6 |
| `manager.restore_clock_runtime(...)` | any of the ten clock rules | adapter, via static `SimClock.restore_refusal()` in step 7 |

`save_section_rng.apply()` deliberately does **not** re-check the tombstone, so that its rollback
path is reachable and tested. The adapter checking it in preflight does not conflict with that: the
preflight is an early refusal for a better message and an untouched store, and `apply()`'s rollback
remains the authority if a stream still refuses.

## 8. Unchanged-on-refusal obligation

On any refusal at any of the eight validation steps, and on any rollback, the following must be
byte-identical to their pre-call values: the nine RNG states, the nine draw counts, the store's
seeded flag and world seed, all ten clock runtime fields, the clock's `_last_error` and
`_last_diagnostic`, the pending scheduler queue, `_started`, `_state`, and the barrier's held bit.
No signal, day-boundary callback, tick, pump or counter increment occurs. `restore_clock_runtime()`
already meets its half of this; the adapter must not weaken it by writing a reason string onto the
clock.

## 9. Test matrix

Preflight refusals, each asserting byte-identical pre-call state:

1. Header tick vs §1 tick mismatch (explicitly, both directions).
2. §1 invalid: negative tick; `COMPLETED_TICK_MAX + 1`; speed 0; speed 3; mask bit 32; negative
   debt; each of the six counters negative in turn.
3. §10 invalid: zero state in each of the nine slots in turn; negative draw count; HUNTING count
   non-zero; wrong column length.
4. Tombstone non-canonical against the §1 seed.
5. Live store seeded to a different seed (wrong world).
6. Barrier not held; `is_loading()` false; called from inside a tick.

Exact-install cases:

7. Debt `1`, `999999`, `1000000`, `2500001` × speeds 1/2/4 × masks `0`, `PLAYER`,
   `MENU|CRITICAL`, `PLAYER|VICTORY`, `31`. Assert debt exact — in particular `2500001` restores
   as `2500001`, and a restored `PLAYER` mask with `999999` debt does **not** zero it or increment
   `_subtick_debt_discards`.
8. Six distinct nonzero counters survive exactly and none is derived from another.
9. All nine RNG states and counts exact, including a state ≥ `2^31` round-tripping through the
   signed storage form.
10. `rng_seeded == false`: store ends unseeded, no §10 accepted.
11. Restore at tick 13500 and 18000: no midnight replayed; the next real crossing delivered once.

Rollback:

12. Force a §10 stream refusal after `seed_world()` succeeded; assert the store returns to its
    exact prior nine-pair state (or to unseeded), and the clock was never written.
13. Force a clock refusal after §10 installed; assert RNG rolls back from the snapshot and the
    coordinator's own checkpoint restores the clock.
14. Force a rollback-write refusal; assert the load is marked unrecoverable and the barrier stays
    held.

No float appears in the new module (ARCH-AUTH-002); add the same source grep the existing suites use.

## 10. Unresolved decisions for Astra

- **Q-W1-1** Does this adapter take already-decoded Records (recommended) or raw bytes plus
  offsets? Taking Records keeps section walking with `save_section_01.gd` and the §10 decoder.
- **Q-W1-2** May a release save carry `rng_seeded == false`, or is that a development-only shape?
- **Q-W1-3** On wrong-world (live seed ≠ saved seed): hard refusal always, or permitted when the
  coordinator declares a full world replacement? This adapter cannot detect that declaration.
- **Q-W1-4** Does the §1 WorldRuntime install remain a separate step from the other eight §1
  owners that `save_section_01.gd` restores, or is this adapter called *by* that module?
- **Q-W1-5** Should the stale BLOCKER W1 header in `save_section_world_runtime.gd` be rewritten to
  point at `restore_runtime()` and this adapter, and by whom?

`release_save_ready` remains **false**. This contract closes one joiner; it supplies no disk path,
no section ordering, no digest verification and no full-world round trip.
