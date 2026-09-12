# 0073 — A UI element's gate is evaluated before its availability, and there are four states

Date: 2026-09-11 · Status: **Accepted** ·
Amends decision [0057](0057-the-ui-shell-renders-the-registry-and-refuses-to-imply-more.md) §1
and §4 · Owning modules: `godot/scripts/ui/ui_availability.gd`, `ui_registry.gd`,
`ui_focus_order.gd`, `ui_hit_test.gd`

## Decision

Four structural contracts in the UI shell's foundation modules are now explicit, and each is
pinned by a behavioural test rather than by a table nothing reads.

1. **Visibility is decided before availability.** `ui_availability.gd::state_of()` tests §4's
   Gate column first and returns `STATE_ABSENT` **without reading the availability claim at
   all**. An absent element creates no Control, so it has no focus stop, no accessibility node
   and no input rectangle.
2. **There are four availability states, not two.** `ABSENT`, `LOCKED`, `UNAVAILABLE`,
   `AVAILABLE`. Decision 0057 §1 said "every element is in exactly one of two states"; that
   reading loses two distinctions §4 and §2.2 make in writing.
3. **The registry is not the render set.** §4 has 103 rows. This milestone builds **60**
   Controls: 46 available, 14 unavailable-with-a-named-owner. The other 43 are specification
   entries and nothing draws them.
4. **§4's activation column is transcribed.** `ui_registry.gd::OPENS` records what each row
   opens and which §3 surface class that is, so UI-SET-031 opens the roster and nothing opens
   UI-SET-087, whose gate is a key.

## 1. Why the ordering is the contract, not an implementation detail

Asking "is the owning store missing?" first and hiding the control afterwards produces the
same pixels and a different program. By the time anything hides it, the Control has been
constructed, has taken a tab stop, has announced itself to a screen reader and has registered
an input rectangle that eats a world click.

The case that makes it concrete is UI-SET-098 Pin resident. §4.3 gates it `SELECTED` and this
milestone has no panel behind it. Availability-first reports `UNAVAILABLE` — a disabled pin
button drawn while nothing is selected, with a rectangle over the world. Gate-first reports
`ABSENT`, which is no control at all.

`test_ui_availability.gd::test_an_unavailable_element_behind_a_closed_gate_is_absent_not_unavailable`
and `test_ui_hit_test.gd::test_the_gate_decides_before_the_availability_claim_does` pin it from
both sides. Swapping the two blocks in `state_of()` was mutation-tested: it fails seven tests.

## 2. Four states, because §4 and §2.2 describe four situations

| State | Specification | Rendering |
|---|---|---|
| `ABSENT` | §4's Gate is not satisfied | no Control exists |
| `LOCKED` | §4: "A locked M-gated control remains visible in its catalog with the GDD milestone condition; it is hidden from quick commands until unlocked" | visible in the catalog, printing the GDD's own M1/M2/M3 condition; absent from quick commands |
| `UNAVAILABLE` | §2.2: "disabled MUTED text with 'Unavailable' reason" | visible, disabled, naming the missing owner |
| `AVAILABLE` | — | driven by real state |

`LOCKED` is **view-dependent**, which is why `Gates.view` exists: the same row is in the
catalog and out of the quick commands at the same instant. REQ-SET-166 ("allow inspection and
show unlock requirements rather than concealing the underlying rule") and UX-T11 both require
the catalog half.

The M1/M2/M3 conditions are quoted from the GDD's own milestone table (`docs/game_gdd.md`,
"M1 Settled Hearth | Day≥4 AND at least 12 residents AND prepared 200 portions cumulatively").
**Nothing here invents a milestone condition**, and an unknown progression state locks rather
than unlocking — `MILESTONE_UNKNOWN` is never "reached".

## 3. An unreadable gate is UNAVAILABLE, not hidden and not false

`Gates.condition` is tri-state — `FACT_UNKNOWN`, `FACT_MET`, `FACT_NOT_MET` — because the three
are different claims. A CONDITION-gated row whose owning store does not exist yet is
`FACT_UNKNOWN`, and that leaves the element **visible and unavailable with a named reason**.
Only a condition known to be false removes it. Collapsing unknown into false would hide
elements because their owner has not been written, which reads identically to a bug.

The same reasoning is applied a second time on the value axis, which is a different question
from availability and was previously only implicit in `ui_shell.gd`'s `"--"` marker:
`VALUE_TRUE_ZERO`, `VALUE_NO_SELECTION`, `VALUE_UNINITIALIZED`, `VALUE_UNSUPPORTED`. Only the
first has a figure to print; `value_reason_key_of()` **refuses** for it, which is the exact
moment a genuine zero would otherwise be turned into a dash.

## 3a. Long content grows, then scrolls. It never shrinks, clips or ellipsizes

`overflow_policy_of()` has exactly **two** values, `GROW` and `SCROLL`, because §1.3 rules out
every alternative by name: "never truncate warnings/costs", "no reduced font size fallback",
"no auto shorten quantity or critical condition". There is no enum value a caller could select
that means clip.

Three measurements are the contract, and all three take a MEASURED line count and line height
from the caller rather than guessing glyph widths in a table:

* `grown_height_of()` — §1.3's "expand row height", clamped into §4's own min→max. It **refuses**
  a line height below §2.1's 14 px floor, and refuses for a scrolling container.
* `overflow_needs_scroll()` — §4's preamble: a container bound "override[s] a maximum only by
  reducing available height and adding internal vertical scroll".
* `body_height_of()` — §2.2's "Modal body height scrolls independently of its 60 px confirmation
  footer", so Confirm and Cancel cannot be pushed under the content.

Worked through in the suite: a 32-character name (§4.3's cap for UI-SET-082) wraps to two lines
in UI-SET-037 and fits at 100%; at §1.2's 150% user scale the same two lines no longer fit and
the answer is **scroll**, not a smaller font. A 30-line refusal overflows UI-SET-085 and scrolls.

## 4. Always-visible unbuilt rows get a compact reason, not a page

§4 gives an `ALWAYS` row no condition to fail, so it is never `ABSENT` — discoverability
survives every gate state, and `test_an_always_gated_element_is_never_absent` walks all of them.

But an always-visible row that is not built must explain itself **on the row**, not by opening
a full-size page about its own absence. `compact_reason_of()` returns a phrase of at most 40
characters ("needs the Building store (task 06)") for focus and inspection; the long sentence
`unavailable_label()` already returned stays where a player asked for detail. A compact phrase
longer than the limit fails an assertion at construction.

`compact_reason_of()` also **refuses** for an element outside the render set: there is no row on
screen to print it on, so a phrase for one would describe nothing.

## 5. §4's activation column, and the two explicit UI-SET-051 variants

`ui_registry.gd::OPENS` is a sparse transcript: opener id → [opened id, surface class]. **Only
rows whose activation column names a numeric UI-SET id are in it.** "opens housing" with no id
is left out rather than guessed at, because a guess would be a surface nobody specified.

Three properties are asserted at construction and re-checked by the suite:

* **UI-SET-031 opens UI-SET-069.** §4.1: "ALWAYS; opens roster rows 069". The Residents command
  opens the resident roster.
* **Nothing opens UI-SET-087.** §4.3 gates the world access list on "F6/accessible mode" — a key
  and an accessibility setting, not an element. No command button can reach it.
* **No `SELECTED`-gated row opens a centre workspace.** §4.2 gates UI-SET-051 "WORKSPACE or
  MODAL", and `frame_variant_for()` refuses for every opener that asks for neither, so an
  ordinary selection cannot produce empty centre scaffolding. Selection may still open a
  **modal**: UI-SET-098 opens UI-SET-082, which §4.3 gives the MODAL profile.

## 6. The focus order is wired into Controls, and the wiring is what moves focus

A focus-order array nothing reads is the defect, not the fix. `ui_focus_order.gd` is now a
router: it holds the shell's Controls and writes `focus_next`, `focus_previous` and all four
`focus_neighbor_*` NodePaths — the properties Godot's own Tab and arrow navigation read.

`focus_step()` **follows the NodePath written on the Control**, not a parallel list, so a
regression that stops writing them stops moving focus rather than leaving a bookkeeping cursor
walking an order nothing on screen obeys.

* The HUD chain is **open**: §8.2 gives one linear order and says nothing about wrapping.
* A modal's chain is **closed**, which is what a focus trap physically is — a ring with no path
  out. Backgrounds additionally have their `focus_mode` set to `FOCUS_NONE`, and the previous
  value is recorded and restored verbatim, because §2.2 gives that decision to the profile.
* On close, focus returns to the opening control if it is still a stop, **otherwise the first
  control of its §1.1 zone** — both branches of §2.2's sentence are taken.
* Switching a workspace retires the outgoing members into `outgoing_into()` for the caller to
  remove, strips their wiring, and drops focus standing on one of them.

### What could not be proved under the headless runner

`Control.grab_focus()` cannot be asserted on. During the runner's `_initialize()`,
`SceneTree.root.is_inside_tree()` is **false**, so `grab_focus()` errors with
`Condition "!is_inside_tree()" is true` and `has_focus()` is always false; Godot's own
`find_next_valid_focus()` needs a tree as well and returns null. The router calls `grab_focus()`
when the Control is in a tree. What the suite proves is the wiring and the cursor, by resolving
each written NodePath back to the Control it names — which is everything that decides where
focus goes.

## 7. A modal SCRIM blocks the background in the hit table

§3 layer 80: "SCRIM blocks background". REQ-UX-003: "While any modal is open, the UI shall trap
focus in that modal and prevent background selection/construction changes." The hit table
previously let a click on bare world next to an open dialog through to the world.
`raise_scrim(layer)` makes `world_receives()` false everywhere and removes every region below
that layer from consideration; `reset()` lowers it, so a rebuilt layout cannot leave a scrim
standing over nothing.

`add_visible_region(..., creates_control)` **refuses** rather than registering a rectangle for an
element that has no Control. The refusal is the ordering contract at the input layer: a caller
that forgot the gate is told, not quietly accommodated.

## Consequences and what is NOT closed

* 103 registry rows; **60** rendered; 46 available, 14 unavailable-with-an-owner; 43 are
  specification entries only. `test_ui_availability.gd` cross-checks the render claim against
  the shell's built control tree id by id, so the two cannot drift.
* **Decision 0057 §1 is superseded in two places.** Its "every element is in exactly one of two
  states" is now four, and its "The other 61 are drawn DISABLED" was never true of the code it
  described: the shell has only ever built 60 controls in total. The two-state claim is kept as
  the *availability* axis; the gate axis sits above it.
* `sequence_into()` keeps its old behaviour — §8.2's full table, unavailable stops included —
  and `visible_sequence_into(gates, out)` is the new, gate-filtered order. No existing assertion
  was weakened; the specification table and the on-screen order are different questions and are
  now asked separately.
* **Four changes are needed in `ui_shell.gd` and are NOT made here**, because that file belongs
  to the integration lead. They are listed in the handoff rather than worked around by
  duplicating logic:
  1. `_on_residents_pressed()` opens `ID_WORLD_LIST` (087). §4.1 says UI-SET-031 opens the
     roster (069). The roster must become a workspace page and F6 / `open_world_list` must be
     the only route to 087.
  2. `open_workspace_page()` does not release focus or remove the outgoing page's children. It
     should call the router's `open_surface()` / `close_surface()`.
  3. `_register_hit_regions()` should call `add_visible_region()` with
     `availability.creates_control(id, gates)`, and raise the scrim while a modal page is open.
  4. Nothing calls `bind_controls()` / `wire_hud()`, so the focus wiring is computed and not yet
     applied at runtime.
* **Mutation-tested**: 31 single-line mutations across the four modules, one per suite run, each
  file restored and SHA-256 byte-compared against a pristine copy afterwards. All 31 are killed.
  Two survived the first pass and are recorded because they say something: `switching-keeps-
  stale-focus` survived because the replacement surface took opening focus and masked the stale
  cursor, and `opening-focus-skips-the-title` survived because the test's member list happened to
  declare the title first, so §8.2's order and the declaration order were indistinguishable. Both
  tests were made discriminating rather than the mutants declared equivalent.
* `docs/ui_visual_refinement_amendment.md`, `docs/design/ui_refinement/`,
  `docs/tasks/04_5_ui_visual_refinement.md` and `docs/validation/ui_refinement_contract.py` **do
  not exist in this repository on any branch**. The UXV requirement wording used here came from
  the task brief; every figure and quotation was re-derived from `docs/ui_ux_controls.md` and
  `docs/game_gdd.md`, which are cited inline above and in the source comments.
