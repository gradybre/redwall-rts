# Independent review — SAVE-D2-R02 joint directory/cursor restore

2026-09-19 · independent Opus review, **not the author** of the module or its test.

Scope: `godot/scripts/core/save_identity_restore.gd` v1 and
`godot/test/test_save_identity_restore.gd`, against
[SAVE-D2-R02](../../../rulings/2026-09-19_save_identity_restore.md) and
[decision 0152](../../../decisions/0152-restore-directory-and-cursor-together.md).
Bounded to the six §3 columns plus §1's separately decoded cursor. **Not** reviewed: full
save/load coordination, disk transactions, whole-world rollback. No tool ran; nothing was
executed; no runtime behaviour is claimed. Every statement below is read off the source.

**Verdict: accept, with two bounded acceptance items (A1, A2) and two coordinator notes (C1, C2).
No blocker.**

## What the ruling asked for, and what the source does

| Ruling clause | Source |
|---|---|
| stateless `static apply(record, next_persistent_id, store, clock) -> SaveHeader.Refusal` | matches exactly; module holds no `var` |
| refuse null record/store/clock explicitly | `_participants_refusal`, three distinct codes |
| require `is_load_barrier_held()`; pause bits are not that barrier | checked last before validation; never acquires/releases |
| validate through `SaveSectionDirectory.record_refusal` | runs before the owner call |
| one call to `restore_columns_and_cursor`, six decoded columns + actual decoded cursor | single call; no `clear()`, no `restore_columns`, no derivation, no private-field write |
| return the exact record refusal or the owner's exact `last_column_refusal` | passthrough of both; see A1 |
| no seventh column, no schema change, frozen WORLD body untouched | `entity_directory.gd` and the §3 byte map are unchanged |

The adapter reaches no tick, debt, RNG, save or other store. The only new coupling is a preload of
`sim_clock.gd`; `sim_clock.gd` preloads nothing from the save layer, so no cycle is introduced.

## Correctness

**Atomicity, as actually claimed.** `restore_columns_and_cursor` evaluates `cursor_refusal`
against the **incoming** `persistent_id` column before anything is written, then delegates to
`restore_columns`, which validates fully before `_install_columns`. The one path that mutates
before deciding — `_fill_owner_map` — rebuilds `_typed_owner_slot` and `_kind_live_count` from the
directory's own columns on collision or living-cap refusal. Both members are inside
`state_bytes()`, as is `_next_persistent_id`, so the "byte-identical on refusal, cursor included"
claim is structurally supported rather than asserted. The module's header is careful to claim
no wider transaction; that framing is accurate.

**Ordering.** `record_refusal` runs before the owner call, so a record that is both malformed and
carries a stale cursor reports the §3 code, not `COLUMN_CURSOR_STALE`. That is the right order —
the wire record is the outer contract — and it is pinned by test. See A2.

**Cursor domain.** `cursor_refusal` compares against the maximum of the incoming column, and
destroyed rows hold 0, so the rule is a comparison and never a computation. `PERSISTENT_ID_EXHAUSTED`
(2147483648) has no i32 spelling, which is precisely why it must travel as the separate u32 scalar;
the module does not attempt to smuggle it through a column.

**No aliasing.** `_install_columns` duplicates each packed array, so the target cannot alias the
decoded record. The adapter copies nothing itself and mutates no input.

**Barrier semantics.** Observation only: `is_load_barrier_held()` is read, never raised or
lowered. `sim_clock.gd` keeps the barrier out of `_pause_mask`, and the adapter's refusal detail
says so in terms. Correct.

**No regression to §3.** `entity_directory.gd` is byte-unchanged. `save_section_directory.apply`
retains its columns-only contract and now points at the adapter. The existing grep assertions in
`test_save_section_directory.gd` still hold against the edited header: `BLOCKER D1 -- CLOSED` and
`BLOCKER D2` are both present, and the new prose introduces no `_next_persistent_id =` and no
`_free_heap[`.

## Tests

The suite exercises the real thing on both sides: actual `EntityDirectory` objects, actual §3
bytes through `capture_into -> encode_record -> decode_into`, and the cursor encoded and decoded
as its own `u32 LE` scalar through `SaveCodec`.

The cases that matter are adversarial in the right way:

* **The derivation is defeated by an allocation, not a comparison.** Both the normal-deleted
  (create 1/2/3, destroy 3) and all-deleted variants restore cursor 4 and then *create a row* and
  read `get_persistent_id()`. A `max(live)+1` loader yields 3 and 1 respectively; both are caught.
* **Exhaustion round-trips.** The final signed-int32 cursor is staged through the existing owner
  API, `MAX_INT32` is issued, and the reloaded directory retains `EXHAUSTED` and refuses the next
  `create()` with `REFUSAL_PERSISTENT_ID`. Bytes `00 00 00 80` are pinned.
* **Invalid cursors 0, 2147483649 and 2 (≤ stored id)** each assert the owner's exact code *and*
  full `state_bytes()` equality, and the record's own column is compared before and after.
* **Missing and released barrier** each assert full `state_bytes()` equality, and the missing-barrier
  case first sets `LOAD` and `PLAYER` to prove pause bits do not stand in.
* **Clock invariants** — held-after-success, held-after-failure, unchanged tick/debt/mask and no
  counted sub-tick discard — are pinned. That last counter matters: it is the field RESTORE-R01
  names as the corruption a mis-routed restore would cause.
* **Aliasing** is proved by mutating the decoded record after success.

Memory discipline is reasonable: source directories are dropped once decoded, and `after_each`
releases fixtures, so no test holds more than two capacity-sized images.

## Bounded acceptance items

**A1 — empty owner code would read as success.** `apply` constructs
`SaveHeader.Refusal.new(store.last_column_refusal(), ...)`. `Refusal.is_ok()` is
`code == REFUSE_NONE`, and `REFUSE_NONE` is `&""` — the same empty StringName the directory uses
for "no column refusal". Today both owner branches that return `false` set a non-empty code, so
the invariant holds by inspection. It is nonetheless an unguarded dependency on another module's
internal ordering, and the failure mode is the worst available: a refused restore reported as a
success. Accept on either (a) a guard substituting a distinct `SAVE_IDENTITY_*` code when the
owner returns `false` with an empty refusal, or (b) an explicit test pinning that `false` always
carries a non-empty code. Both are inside this worker's two files.

**A2 — keep the validator ordering pinned.** `test_a_malformed_column_set_refuses_before_the_owner_is_ever_asked`
is the only thing preventing a future reordering from silently changing which code a doubly-invalid
input reports. It already asserts `last_column_refusal() == REFUSAL_NONE`, which is the strong form.
No change required; flagged so it is not treated as redundant later.

## Coordinator notes (explicitly out of this packet)

**C1 — world association is uninferable and must be supplied.** Two independent objects carry no
link. The module documents this rather than pretending otherwise, which is right, but it means a
coordinator passing the wrong world's clock gets a successful restore under a barrier that
protects nothing. That obligation belongs to `SAVE-ORCHESTRATOR`.

**C2 — a cursor stale only against destroyed identities is undetectable here.** The owner's rule
compares against *stored* ids; `destroy()` zeroes them. A save carrying cursor 3 for the
create-1/2/3-destroy-3 world would be accepted and would reissue the spent 3. Nothing in this
bounded scope can see that, and nothing should try to. The guarantee has to come from §1 and §3
originating in the same capture, verified by the coordinator.

## Not claimed

No suite was run and no runtime result is reported here. The registry's category-3 stateless
declaration is Astra's and was not supplied in this packet, so it is unverified rather than
endorsed. This adapter closes D2's missing consumer only: full-file validation, disk coordination
and whole-world rollback remain separate and unimplemented, and `release_save_ready` stays false.
