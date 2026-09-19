# Final independent review — REG-C4-R01, UI-C4-R01, STOCK-C4-LIFETIME-R01

2026-09-19 · independent reviewer session · authored none of the work under review
(author sessions `a7af9fea` capacity, `009ffac8` UI, a third session for stock lifetime).

**Scope.** I read the complete tracked diff, the exact supplied excerpts of
`godot/scripts/ui/ui_shell.gd`, `godot/scripts/core/inventory.gd`,
`godot/scripts/core/stock_age.gd`, `godot/scripts/ui/ui_focus_order.gd`,
`godot/scripts/ui/ui_availability.gd`, both new suites, `tools/audit_registry_capacities.py`
with its self-test, the two rulings, and the two evidence logs. I ran nothing. I do not
certify unsupplied source, the full suite, the release, or any visual/art acceptance.
The final full run with the weakref change was still in flight when this was written and
is not claimed here.

---

## Verdict

| Packet | Verdict |
|---|---|
| REG-C4-R01 (bounded sum grammar) | **Accept as bounded, read-only sidecar work.** No blocker found. |
| STOCK-C4-LIFETIME-R01 (borrowed predicate) | **Accept the code.** One evidence item must be reconciled. |
| UI-C4-R01 (context ↔ hit table) | **Not yet complete against its own ruling.** Two must-fix items. |

No regression in the bounded proof, the fail-closed transaction/reentry path, or the
repaired workspace/selection gating was found. The UI findings are *incompleteness*
against UI-C4-R01's explicit text, not a re-break of what the packet fixed.

---

## Must-fix blockers

### B-1 (UI, code) — a gate change refreshes input but not focus

`ui_shell.gd::_recompute_selection_gate()` ends with `_register_hit_regions()` only.
`_wire_focus()` is reachable **solely** from `layout_for()`. `select_job()`,
`select_resident()`, `select_basin()` and `select_zone()` therefore flip
`Gates.has_selection`, which changes `UiAvailability.creates_control()`, which changes
what `UiFocusOrder.visible_sequence_into()` would emit — and no layout runs on those
paths, so `focus_next`/`focus_previous`/`focus_neighbor_*` keep the previous order.

UI-C4-R01: "A false contextual Gate means absent from drawing, input, focus and
accessible navigation… Update the contextual gate state when opening, closing, changing
selection and rebuilding layout." Input and focus now disagree for one frame class.

`open_workspace_page()` already recognised this hazard and added a standalone
`_register_hit_regions()` with the comment "Context changes must refresh input even when
an off-tree layout cannot run" — but did not add the matching `_wire_focus()`, so the
asymmetry is deliberate in the hit table and accidental in the focus chain.

*Repro (headless, no window):* build the shell, `layout_for(1280,720)`, capture
`focus().wire_hud(shell.gates())` / the wired stop count; call `select_resident(...)`;
`test_ui_context_gates.gd::test_an_unavailable_true_gated_control_only_registers_when_selected`
already proves `region_count()` grows — assert in the same test that the focus stop count
grows too. It will not until `_recompute_selection_gate()` also rewires focus.

*Fix:* call `_wire_focus()` alongside `_register_hit_regions()` wherever a gate changes
outside a layout pass (`_recompute_selection_gate`, `open_workspace_page`,
`_on_back_pressed`), and pin it with an assertion.

### B-2 (UI, test) — the visible↔gate invariant the ruling asks for is absent

UI-C4-R01: "Also assert the invariant between visible controls and their gate state so
registration cannot conceal erroneous drawing." `_register_hit_regions()` reads
`consumes` from the Control but still passes `_availability.creates_control(id, _gates)`
into `add_visible_region()`, and that flag is what previously suppressed the region for a
drawn, opaque panel. The packet repaired **SELECTED** and **WORKSPACE** only. Every other
gate family in `ui_registry` (WORLD_TOOL, TUTORIAL, CONDITION, M1–M3) is still capable of
reproducing the original defect class, and `test_ui_context_gates.gd` contains no test
that would catch it.

*Fix:* one loop over `UiAvailability.RENDERED_IDS` asserting, for every control that is
visible with a visible ancestor chain, that `creates_control(id, gates)` is true —
across the four supported compositions already enumerated in
`test_workspace_gates_hold_at_every_supported_profile()`. This is the general guard; the
two repaired families are the special cases.

### B-3 (evidence) — the engine probe has no positive control

`ui-engine-final.log` reports six cases, `"failures":0`, and
`pending_commands_before`/`after` = **0 in every case**, including `open_world`, where
`expected_world` and `engine_unhandled_world` are both true. A probe in which a
deliberately legitimate world click also queues nothing cannot distinguish "no world
command leaked through the panel" from "this harness never queues commands at all."
The `unhandled` canary is real routing evidence and is correctly scoped in the log's own
`"scope"` string; the command-count column is currently unfalsifiable.

*Fix:* extend the probe so the `open_world` case queues a real command and
`pending_commands_after > pending_commands_before` there, keeping 0→0 under the panel,
detail and Back cases. Until then, UI-C4-R01's "prove no world command is queued through
a panel" is met by the unhandled canary alone, which should be stated as such.

### B-4 (evidence) — the stock lifetime log contradicts the new suite

`stock-lifetime-after.log` reports `"explicit_unbind_succeeded":false` while
`inventory.gd::set_seed_expiry_authority(null)` returns `_ok(NULL_REF, 0)` on every path
except an open transaction, and `test_stock_authority_lifetime.gd::test_an_explicit_unbind_enforces_nothing`
asserts that same call is `ok`. The probe source is not supplied, so I cannot tell whether
the probe attempted the unbind after the store was already released (in which case the
field is now meaningless post-repair) or whether it misreads `OpResult`.

*Fix:* re-run or re-label the probe so the published field means what its name says;
a sidecar artifact that appears to contradict the suite is worse than an absent one.

---

## What I checked and found sound

**REG-C4-R01.** `resolve_expression()` splits on `+` outside `resolve_product()`, so `*`
binds tighter and both associate left to right; `NON_ALLOWLISTED_OPERATORS` retains
`-/%()<>&|^~`, so unary sign, parentheses and division still halt. `_guard_int64()` is
applied to the running product **and** the running sum, and nested constants re-enter
`resolve_expression()`, so an overflowing intermediate cannot be rescued downstream —
`test_c4_overflow_cannot_be_rescued_by_zero` pins exactly that. `classify_from_source()`
now flattens across summands, so a runtime var mixed into a sum refuses instead of
collapsing equality and maximum. Widening `LHS_RE` to admit `+` is safe because
`audit_field()` still requires prose text to equal the source resize argument.
F-01/F-02 close two real pre-existing soundness holes (an indented or `self.`-prefixed
second resize; an augmented assignment after a single clamp). The rename to
`registry_canonical_json_sha256` corrects a genuine mislabel — the value always hashed
canonical JSON — and the schema bump to 2 is the right way to carry it. The sidecar stays
`"adopted": false`, and P06/P07 move to 470 eq / 46 bound / 0 quarantined with proof
chains that still run through `orchard_hive.gd:316`. I did not regenerate the sidecar;
byte-identity rests on `--check` (P09), which I did not run.

**STOCK-C4-LIFETIME-R01.** The binding is a `WeakRef`, explicit-null and dead-binding are
kept distinct (`has_seed_expiry_authority()` false for both; `_seed_consumption_refusal()`
returns `REFUSE_NONE` for null and `REFUSE_INVALID_SEED_EXPIRY_AUTHORITY` for dead), which
is exactly the fail-closed asymmetry the ruling demands. A live predicate is pinned in a
strong local for the call only, `_attesting` still raises before it, and `_guard()` still
tests `_attesting` first — `test_a_live_binding_that_re_enters_the_store_is_still_refused`
proves the re-entrant sink refuses and removes nothing. Nothing enters `state_bytes()` or
the journal, and `clear()` preserves the binding. `refuses_seed_consumption()` in
`stock_age.gd` remains fail-closed on unbound store, unloaded catalog and invalid lot.

**UI-C4-R01 (accepted parts).** `_apply_workspace_gate()` writing 051 and 092 alongside
the page, `_on_back_pressed()` becoming an idempotent close instead of `_toggle_zone()`,
and `_recompute_selection_gate()` treating an open tile detail as a selected context are
all correct against §4 and against `ui_manager.gd`'s tile path as described. The corrected
test in `test_ui_shell.gd` is a real improvement: asserting `frame.has_point(outside)` is
false makes the world probe self-guarding, which the old `(1000,300)` point was not.

---

## Advisory (non-blocking)

1. `DIRECT_RESIZE_TEMPLATE`'s optional `(?:\S.*:[ \t]*)?` prefix matches a commented-out
   inline compound statement, while `call_count` skips comment lines — a mismatch that
   quarantines rather than proves. Likewise a resize with a trailing `# comment` fails
   `\)[ \t]*$` and quarantines. Both fail safe; both will surprise a future author.
2. `set_seed_expiry_authority()` is not guarded by `_attesting`, so an authority can
   rebind or unbind wiring from inside its own predicate. The in-flight call is safe
   (strong local), and wiring is not saved state, so this is not corruption — but it is
   undocumented.
3. `has_seed_expiry_authority() == false` now means "never bound, unbound, **or** dead."
   Call sites were not supplied; any caller reading it as "consumption is unenforced" is
   now wrong. Worth an audit pass in the owning packet.
4. `select_job()`/`select_resident()`/`select_basin()` now reach `_register_hit_regions()`,
   which touches `_zones[ID_WORKSPACE]`; calling them before `build()` newly faults where
   only `select_zone()` did before.
5. `work_queue.json` records `STOCK-AUTHORITY-LIFETIME`'s ruling under `astra_request`
   rather than `astra_ruling`, unlike every sibling entry. `REG-C4-ADDITION`'s acceptance
   still says "158 checks" against a now-larger self-test.

## Pre-existing debt, explicitly not charged to these packets

`_apply_geometry()`'s canvas-vs-window stretch mismatch (owned in `project.godot` by the
integration lead, and honestly reported in-source); `reserve_lot()`'s absent Reservation
row store (BLOCKED U4/U5); wider keyboard/router/selection semantics beyond the gate
wiring in B-1; the 14 leaked ObjectDB instances and 3 resources still reported at exit in
`ui-engine-final.log`, which are distinct from the Inventory↔StockAge cycle this packet
removed and remain `QA-SHUTDOWN-LEAKS`'s work.

## Scope of this verdict

This review covers correctness repair plus the explicit roadmap in the supplied diff. It
is not acceptance of the full UI, the starter settlement, the save lane, native pointer
behaviour, art (ART-UI-12 remains Brendan's), performance, or any release candidate.
