# 0115 — The persistent-ID cursor is section 1's, and both standing barriers are wired

Date: 2026-09-12 · Status: **Accepted**

Closes **BLOCKER D2** from
[decision 0103](0103-section-3-writes-six-columns-and-rebuilds-the-rest.md) /
[0105](0105-the-directory-publishes-its-columns-and-rebuilds-the-rest-on-restore.md),
and wires two authorities that existed in code and were called by nobody. It does
**not** claim release-save completeness, a load orchestrator, §15 verification,
cross-store ordering or any MOVE gate.

## Decision

1. **`_next_persistent_id` is a section 1 owner block of its own.** REG-R01 registers
   `entity_directory` in §1 at schema 1, primary_count 1, payload **4 bytes**:
   `_next_persistent_id:u32 LE`. Its domain is `1..2147483648`, and **2147483648 is the
   exhausted cursor** left after the final signed-int32 identity has been issued. That
   widens the **ledger** to unsigned; the live `_persistent_id` column stays i32 and
   never holds the exhausted value. No directory state enters `world_runtime`'s payload,
   which keeps schema 1, primary_count 1 and its **exact existing 80 bytes and offsets**.

2. **The cursor is assigned, never derived, and a stale cursor is a refusal.**
   `entity_directory.next_persistent_id()` captures it; `restore_columns_and_cursor()`
   installs §3's six columns and the cursor **together**, after checking that the cursor
   lies in domain and **strictly exceeds every positive stored id**. `restore_columns()`
   keeps its old columns-only contract so §3's codec cannot write a §1 value. `clear()`
   returns the cursor to 1 because a new world issues from 1; it is not a load step.

3. **Section 1 composes as prefix, count, ASCII-ordered blocks.** 44-byte SAVE-R09-003
   map-provenance prefix, `store_count:u32`, then SAVE-LAYOUT-R01 wrappers in ASCII owner
   key order, tiling the section remainder with no gaps, overlaps, repeats or trailing
   bytes. `encode_section()` refuses if its own emitted key list is not strictly
   ascending, so the ordering rule is enforced rather than assumed.

4. **`game_manager.begin_load()` now takes `sim_clock.acquire_load_barrier()`**, beside
   the existing checkpoint capture and before a single field moves. A refused grant
   refuses the whole `begin_load()` as `LOAD_BARRIER_UNAVAILABLE`, changing nothing.
   `end_load()` and `rollback_load()` release the token where each already reset
   `_last_host_usec`; an **unrecoverable** rollback deliberately leaves it held.
   `GameManager._loading` **stays**: two checkpoints, one barrier.

5. **`settlement_system._compose_stock_layer()` binds the seed-expiry authority.**
   `_inventory.set_seed_expiry_authority(_stock_age)`, after both collaborators exist
   and before `_init()` returns. A refused bind is fatal, like the ecology bind.

6. **The saved debt domain is `0..INT64_MAX`, not `INT64_MAX/4`.** RESTORE-R01 supersedes
   the old derived cap in `save_section_world_runtime.gd`.

## Why

`destroy()` zeroes `_persistent_id`. `max(live ids) + 1` therefore reissues an identity
the saved world already spent the moment anything has died — create 1/2/3, destroy 3 and
it answers 3 — and with every entity dead it collapses to 1 and reissues all of them.
That is why the cursor is saved rather than recomputed, and why every D2 fixture is
written to kill that derivation specifically. Repairing a stale cursor upward instead of
refusing would silently accept a file whose allocator ledger disagrees with its own
columns; the next `create()` would then look correct while the save it came from was not.

The two wirings are the same class of defect found twice in one review: an API that
exists, is tested in isolation, and is called by nothing, so the guarantee holds in the
suite and not in the running game. `sim_clock.gd` grew the token barrier and nothing
raised it, so a raw caller reaching `clock()` or `scheduler_events()` past GameManager
walked straight past `_loading` — which RESTORE-R01 names: "a GameManager-only check is
insufficient". `inventory.set_seed_expiry_authority()` and
`stock_age.refuses_seed_consumption()` both existed and nothing called the setter, so the
settlement's own store admitted expired seed. Neither needed rebuilding; both needed a
call.

The old `INT64_MAX/4` debt cap was read off `_is_overloaded()`'s `4*debt` comparison. It
made this codec **refuse debts `sim_clock.restore_runtime()` accepts** — a codec quietly
narrowing stored debt, which is what the ruling forbids. The overload test already uses
`IntMath.checked_mul_into` and treats overflow as overloaded, so the checked side owns
that bound.

## Consequences

* A §1 reader must accept `2147483648` as a cursor and must never admit it into an i32
  column. GDScript ints are 64-bit, so `0x80000000` is positive while `-2147483648` is
  the same four bytes read as int32; the fixture asserts both readings and asserts they
  are different numbers, because a test written with one literal passes against a store
  that quietly held the other.
* `encode_section()` emits `store_count = 2`. **BLOCKER W2**: seven of §1's nine
  registered owners — `buildings, farming, forage, resource_nodes, spatial_world,
  weather, world_init` — have no §1 encoder anywhere. `missing_owner_keys()` reports the
  gap; nothing is invented to close it, and this is a development section 1.
* §1's 44-byte prefix fields (`scenario_version`, `map_generator_schema`,
  `authored_map_digest`) are carried and bounded here but **produced by nobody**;
  `world_init.gd` does not supply them. No default is manufactured.
* Two registry rows are owed in files this lane does not own — see the task checklist.
* `test_game_manager.gd`'s two barrier tests changed: a raw queue submission taken
  *during* a load is now refused rather than queued. That is the hole closing. Both tests
  now admit the record before the barrier goes up and additionally assert the refusal.

## Source

`docs/rulings/2026-09-12_save_registry_answers.md` — "§1 WORLD composition and D2", and
items 1 and 2 under "Engineering work may proceed".
`docs/rulings/2026-09-12_clock_restore_and_layout_followup.md` — RESTORE-R01 and
SAVE-LAYOUT-R01. `docs/rulings/2026-09-11_save_codec_contract.md` — SAVE-R09-003's
44-byte prefix. Decisions [0059](0059-allocate-before-consume-is-a-repository-wide-rule.md),
[0092](0092-the-load-barrier-and-the-one-restore-call-site.md),
[0104](0104-the-load-barrier-is-a-token-the-clock-holds.md),
[0105](0105-the-directory-publishes-its-columns-and-rebuilds-the-rest-on-restore.md).
