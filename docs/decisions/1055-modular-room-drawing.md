# 1055 — Retained modular room drawing and explicit confirmation

2026-10-02 · Accepted engineering increment UG04; village integration remains UG09.

## Authority and scope

The approved D01 room painting and D08 blueprint → construction → empty room
workflow require an editable drawing separate from orders. `modular_draft.gd`
and `modular_editor.gd` provide that drawing session and its inspector. They
do not install a simulated room, spend inventory, reserve space, publish a
route or change a room's type. They consume the canonical footprint helper
from decision 1052. They are new components; the village's existing template
tool is connected to them only in the later UG09 integration lane.

The session has an explicit room type, level, pitch, bounds, capacity and hole
policy. Existing paint or undo history must be discarded before those inputs
can change. Pitch must represent the GDD's 2m furnishing grid exactly; that
constraint does not adopt a production paint pitch or equate a painted cell
with a paid excavation quantum. Physical conversion remains owned by the
space and excavation contracts under SET-MOVE-ECON-001.

## Editing behavior

Rectangle, rounded rectangle, independent-axis oval, connected paint and a
width-bearing tunnel route all add to or erase from the same blueprint.
Combining strokes produces wings, recesses and irregular rooms; no room type
is restricted to an oval. Rounding is a maximum radius clamped to the dragged
extent. The brush and route use the canonical integer supercover and disk;
their nominal width is `2 * radius + 1` cells. The route records pointer bends
instead of filling its bounding box.

During a drag the new shape is transient. Release retains one complete edit;
it never submits construction. Escape through `cancel_stroke()` consumes only
that gesture. Undo/redo keep up to 32 complete edits; at the geometry helper's
16,384-cell engineering ceiling, those packed cells are at most 4MiB for one
history stack. Moving an edit between stacks or beginning new edits does not
grow their combined history beyond that bound. This is one active UI session,
not object-per-room authoritative storage. Out-of-bounds or capacity failures
refuse the entire stroke rather than silently clipping the requested shape.

Disconnected, empty or otherwise invalid retained drawings remain editable.
Confirmation requires valid topology. Written reasons accompany disabled
confirmation; color is not the sole signal. Whole-plan topology is cached by
the committed revision. A distinct visual revision updates the displayed drag
without pretending the accepted drawing changed. Identical pointer-cell
samples do no geometry work. No per-frame simulation polling is introduced.

## Host boundary and callback safety

The inspector is a 280px-minimum VBox using existing demo colors. Action
targets are at least 32px high and preserve keyboard focus. The host supplies
the surrounding panel, padding, camera picking, pointer capture, modal gating,
and level selection; this widget does not register global input handlers.
The native fixture uses a 348px inspector with 12px content padding at 1280×720.

Before enabling Confirm, the host must bind both a fresh authoritative checker
and an atomic submitter. The checker returns a textual refusal or an empty
string; the submitter returns an explicit boolean `ok` receipt. Geometry alone
never enables an order. A refused check or transaction retains the draft.
An ambiguous receipt disables resubmission until the owner is re-bound; it is
not treated as evidence of rollback.

Independent review found that callback mutation could otherwise discard a
newer draft after a successful world transaction. Confirmation now captures
the submitted session identity and revision. Both must still match after the
checker. After submission, success is reported truthfully, but only that exact
unchanged drawing is consumed. A newer or replacement session survives for
review. A reentrancy guard prevents recursive submissions through widget APIs.

## Evidence and remaining integration

Focused strict runner results: 11 draft tests / 201 assertions and 10 editor
tests / 104 assertions, all passing. Both have zero unexpected diagnostics,
zero expected/tolerated diagnostics and zero leaked objects/resources. The
five changed GDScript files initially passed the analyzer at zero warnings;
the final padding-only harness change was checked separately.

`test/live/modular_editor_live.gd` uses real `Viewport.push_input` events to
exercise drag/release, GUI Undo/Redo, release outside the canvas, disconnected
shape repair, owner refusal and explicit confirmation. Headless execution
reports 50 checks, zero failures; native capture adds three screenshot-save
checks for 53 checks, zero failures. Inspector bounds are checked both before
and after the longer refusal text. Its test wrapper rejects child errors,
warnings, leaks and a missing summary, rather than trusting process exit.

The fixture and images explicitly say component test with synthetic geometry.
They are not evidence of workers digging, a completed Kitchen, real 3D picking
or full village modal/camera integration. Those remain UG09/UG17 gates. The
actual native captures and source hashes are under
`docs/design/underground-planning/evidence/modular-build/editor/`.

No worst-case interaction or target-hardware frame budget is claimed by these
tests. Larger drawings and final curve presentation remain subject to measured
integration work. No new room price, biological capability, movement profile,
level spacing or construction timing was introduced.
