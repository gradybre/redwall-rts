# Review closure — B-1 … B-4 (UI-C4-R01, STOCK-C4-LIFETIME-R01)

2026-09-19 · independent closure pass · I authored none of the work under review and
**executed nothing** — no tests, no probes, no suite. Everything below is read from the
supplied sources, the two probe scripts and the two logs. I do not certify unsupplied
source, the full suite, the release, or any visual/art acceptance.

---

## Verdict

| Blocker | State |
|---|---|
| B-1 focus not rewired on gate change | **Closed.** |
| B-2 visible↔gate invariant absent | **Closed.** |
| B-3 engine probe had no positive control | **Closed.** |
| B-4 stock lifetime log contradicted the suite | **Closed.** |

No regression found in the bounded sum grammar (REG-C4-R01, unchanged), the fail-closed
borrowed-predicate path, or the repaired workspace/selection gating.

---

## B-1 — context mutation now refreshes input *and* focus

`_recompute_selection_gate()` computes `has_selection`, returns early when `not _built`,
then calls `_register_hit_regions()` **and** `_wire_focus()`. `open_workspace_page()` and
`_on_back_pressed()` carry the same pair. The asymmetry I charged is gone: every path that
flips a gate outside a layout pass now rewires both tables.

`test_selection_rewires_keyboard_order_without_waiting_for_layout` pins it in both
directions — the wired stop count grows on `select_resident(...)` and returns to the
exact prior value on clear — which is stronger than the one-sided assertion I asked for.

The `not _built` guard also resolves my advisory 4: `select_job()`/`select_resident()`/
`select_basin()` can no longer fault on `_zones[ID_WORKSPACE]` before `build()`.

*New observation, non-blocking.* `set_detail_open()` → `_recompute_selection_gate()` →
`_wire_focus()` calls `wire_hud()`, which re-applies the HUD chain while a modal surface
may be open, re-writing `focus_next` on controls `_suppress_background()` had unwired.
This is not exploitable: those controls keep `focus_mode == FOCUS_NONE`, and
`focus_element()` refuses any non-member with `REFUSE_TRAPPED` while `is_trapped()`. The
trap therefore holds; only the dormant NodePaths are restored. Worth a comment, not a fix.
`_on_back_pressed()`'s `_wire_focus()` after `close_surface()` (which already calls
`wire_hud`) is a harmless duplicate.

## B-2 — the invariant is now universal, and the two named holes are shut

`_assert_visible_controls_have_satisfied_gates()` loops `RENDERED_IDS`, walks each
control's ancestor chain to the shell root, and asserts `creates_control(id, gates)` for
every control that is genuinely shown. `test_visible_control_gate_invariant_in_every_
context_and_profile` runs it across the four supported compositions × detail open/closed ×
ROSTER / NEW_SETTLEMENT / NAME_EDITOR × post-Back. That is the general guard the ruling
asked for; the SELECTED and WORKSPACE families are now its special cases.

`_apply_workspace_gate()` adding `ID_SEARCH` closes the owning-surface bit for 075.
`open_workspace_page()` rejects a `GATE_SELECTED` page with `REFUSE_NO_TARGET` **before**
`_focus.open_surface()`, `_retire_outgoing_members()` or any visibility write, so a refused
082 mutates nothing — `test_name_editor_without_selected_context_refuses_before_drawing`
asserts the refusal code, that the frame stayed hidden, and re-runs the invariant. The
fixture selects a resident before naming, so the positive path is exercised too.

*Limits I record rather than charge.* The invariant is one-directional (visible ⇒ gated),
by design; a gate true with nothing drawn is still unpinned — relevant to `ID_SEARCH`,
which is now opened for every workspace page including those without a filter row.
WORLD_TOOL, TUTORIAL, CONDITION and M1–M3 are covered only in whatever state the
enumerated contexts leave them. `_shell.availability().RENDERED_IDS` reads a const through
an instance — legal, stylistically loose.

## B-3 — the command column is now falsifiable

`ui_engine_input_probe.gd` instruments `WorldCanary._unhandled_input` to submit a real
`NAME_RESIDENT` through the real `UiCommandBridge` against the real `Settlement` queue,
and `_click_case()` asserts `pending_after - pending_before == (1 if expect_world else 0)`
plus `canary.refused == 0`. `ui-engine-command-command-control.log` shows exactly the
shape that distinguishes routing from a dead harness: `open_world` 0→1, `detail_open`
1→1, `detail_closed` 1→2, `workspace_open` 2→2, `back_button` 2→2, `workspace_closed`
2→3, `failures: 0`. The count is now a positive control, not an unfalsifiable zero.

The `scope` string states plainly that this is headless viewport routing with a seeded
fixture and **not** the production world router, native pointer, or visual acceptance. I
accept that framing and repeat it here: B-3 closes the *probe*, not the world router.

## B-4 — the log no longer contradicts the suite

The probe now labels the skipped call honestly: `cleanup_unbind_attempted` is
`retained_inventory`, and `cleanup_unbind_succeeded` is `null` when it is false.
`stock-lifetime-final.log` reports `bound: true`, both `*_retained_after_external_refs_
dropped` false, both `*_released_at_probe_end` true, `cleanup_unbind_attempted: false`,
`cleanup_unbind_succeeded: null`. There is no longer a published field asserting an
unbind failure the suite disproves; the WeakRef binding demonstrably retains nothing.

The replacement of the discarded-guard assertion with a local strong owner plus a
zero-queries assertion is consistent with the borrowed contract, but that test source was
not supplied and I do not certify it.

---

## Still open — scope, not blockers

1. **The full suite is not evidence yet.** 166 focused tests are reported passing by the
   author; the final full run was still in flight. Nothing here claims a green suite.
2. **Broader focus/router semantics** — keyboard traversal beyond stop counts, Escape
   ladder integration, production world routing and native pointer behaviour — remain
   outside these packets, as before.
3. Prior advisories 1–3 and 5 (audit template/comment edges, `set_seed_expiry_authority`
   not `_attesting`-guarded, `has_seed_expiry_authority()` tri-meaning, `work_queue.json`
   field naming) are unchanged and still non-blocking.
4. Pre-existing debt unchanged: `_apply_geometry()` stretch mismatch, `reserve_lot()`'s
   absent row store (BLOCKED U4/U5), the 14 leaked ObjectDB instances (`QA-SHUTDOWN-LEAKS`).

This closure covers the four bounded repairs only. It is not acceptance of the full UI,
the starter settlement, the save lane, art (ART-UI-12 remains Brendan's), performance, or
any release candidate.
