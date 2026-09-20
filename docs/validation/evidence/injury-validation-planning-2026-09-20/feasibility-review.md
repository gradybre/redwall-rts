# Injury owner 6 — feasibility review (read-only)

2026-09-20. Independent re-derivation while other work runs. **No accepted Injury contract, no
implementation, no execution, no reproduction claim, and no human-permission claim.** Source is
the main-branch material supplied to this review; anything below marked as a question stays open.

## Re-derived layout

Owner 6 `injury`, version 1, 512 primary rows, 0 child extents, 11 fields, owner-local ordinals
122–132 in the compiled field table. Canonical order is five u8 (`_present`, `_kind`,
`_airless_episode`, `_exhaustion_latch`, `_care_context_blocked`), three i32 (`_severity`,
`_rescuer_slot`, `_rescuer_generation`), three i64 (`_untreated_ticks`, `_care_progress_mwu`,
`_last_incident_ordinal`). Values: 5·512·1 + 3·512·4 + 3·512·8 = 2560 + 6144 + 12288 = **20992**.
Payload adds the child-count word and eleven count words: 4 + 0 + 88 + 20992 = **21084**. Block
adds 24 fixed wrapper bytes and the 6-byte key: **21114**. Offset 8539433 + 21114 = 8560547, which
is the recorded Jobs offset. All four figures reproduce; the earlier note stands.

## Writer audit — what the current code actually guarantees

* `clear()`, `_write_empty_row()` (spawn and despawn) zero every field **except** the rescuer
  pair, which is the null `(-1, 0)`. So "free row all zero" is false as stated; it is all-zero
  plus a null rescuer.
* Present rows: `_kind == KIND_NONE` iff `_severity == SEVERITY_NONE`. Both merge paths and
  `_complete_treatment_checked()` move them together; `_check_incident_arguments()` admits only
  severity 1 or 2 with a kind in 1..5.
* Kind 0 implies zero untreated ticks and zero care progress (treatment clears both), but **may**
  retain a positive ordinal, an airless latch, an exhaustion latch, a blocked-care byte, and a
  live rescuer — `set_rescuer()` requires only a live patient and a valid non-self resident
  target, never an active injury. A healthy bound rescuer is reachable.
* Active kind implies `_last_incident_ordinal > 0`: every write of the ordinal comes from an
  incident whose argument check demands `ordinal > 0` and strict increase.
* Care accepts any positive i64 through `checked_add_into`; there is **no** 60000/120000 ceiling on
  the accumulator, only on the exact `required_mwu` argument to `complete_treatment()`. Ordinals
  likewise accept any strictly increasing positive i64, so i64 max is admissible.
* Stale Directory rescuer refs are retained on purpose — `rescuer_is_live()` documents that the
  generation check, not a sweep, is the guard. A duplicate exact non-null rescuer pair across two
  present rows is forbidden by the current setter via a bounded 512-row scan with no allocation.
  Distinct generations on one slot are correctly *not* rejected, so stale history survives.

## The boundary

`tick_all()` performs `_untreated_ticks[slot] += 1` unchecked. At `INT64_MAX` that is undefined
for the contract's purposes. It is the only unchecked authoritative increment in the module.

Minimal source-backed preflight, in the module's own idiom: a first pass over the 512 rows
selecting present ∧ injured ∧ `needs.is_alive(slot)`, refusing `REFUSE_OVERFLOW` and setting
`_last_refused_slot` if any selected row is at `INT64_MAX`; a second pass performing the
increments only if the first pass accepted. That preserves allocate-before-consume (a refusal
leaves the image byte-identical) and adds no column, no cap and no new refusal code.

## Observing the boundary without expanding the API

1. **No public setter exists** for `_untreated_ticks`; reaching `INT64_MAX` by ticking is not
   reachable in any real run. So a direct public reproduction is currently impossible.
2. A production getter/setter addition would expand the API to serve a test — rejected here.
3. A saved-image path (framed columns restored through a future owner-6 bridge, as owner 13 does)
   would observe the boundary **without** a new production mutator, since the domain question is
   a saved-domain question anyway. This is the only option that needs no API widening, and it is
   blocked on whether owner 6 gets a bridge and whether that bridge accepts `INT64_MAX`.

## Technical questions (for explicit follow-up before publication)

1. Does the accepted Injury contract admit `_untreated_ticks == INT64_MAX` as a legal saved value,
   or is a narrower bound declared? Shrinking it silently is not on the table.
2. If the domain is the full non-negative i64, is the two-pass preflight the accepted behaviour at
   the boundary — whole-sweep refusal — or a per-row skip that lets other rows advance?
3. Should the same treatment extend to `_care_progress_mwu` and `_last_incident_ordinal`, which
   are already checked but likewise uncapped?
4. Is an owner-6 framed-column bridge planned, and may it be the boundary's observation point?
5. Is the retained rescuer-on-healthy-row state intended to survive a save/load round trip?

Saved presence/injury-state/resident-identity/context bindings remain a separate explicit
follow-up. Nothing here has been run, tested or applied.
