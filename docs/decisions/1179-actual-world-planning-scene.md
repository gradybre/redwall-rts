# 1179 — Actual-world planning from the demo

Date: 2026-10-05 · Status: implemented; focused and native acceptance recorded below

The Tunnels panel opens the actual-world room inspector from1176 over the
terrain view from1175. Normal demo startup composes the already mounted original
SettlementSystem Room/Route owners. Opening the view therefore changes no
canonical gameplay state. After an actual World Create, a later explicit open
composes the replacement World's missing owners and discards the old draft;
it never adopts a stopped constructor prefix. It does not create a second simulation,
move the original datum to the legacy village, seed an entrance, or spend
materials during presentation setup. Access and actual worker construction
remain their own explicit admission gates.

Use a separate instance of the existing RTS camera rig for this view. The
legacy camera keeps its pose and mode; its presentation updates are suspended
while hidden. Dedicated render bits hide the older demonstration geography.
The finite tree of existing input handlers and canvas layers is recorded once,
temporarily withheld and restored on close. Their simulation/process callbacks
continue. No clock pause or speed change is implicit in opening or closing a plan.

Independent review found three input/lifetime defects in the first candidate:
held camera keys could continue behind a stall; popup Windows could outlive
the view or cross a World reset; and Tab navigation could reach controls behind
a mouse-only shield. The existing camera mechanics now have a narrow guard
which clears held motion and easing whenever the actual CRITICAL hold or modal
takes ownership. The original banner temporarily draws above a dimming mouse
shield and every planning control, with its original layer restored on close.
Owned popups close at the modal transition, close and World retirement. A
pre-GUI input gate also contains keyboard/gamepad navigation; the existing
banner retains Enter/Space acknowledgement. No automatic acknowledgement or
new clock semantics are introduced.

The planning toolbar reads actual settlement resource counters and controls
the existing GameManager's player pause and1x/2x/4x commands. Its draft remains
on dirt at the actual selected floor. Escape first cancels an active drawing
gesture; otherwise it leaves the planning view without discarding the draft.
The explicit Back button has the same retention behavior. A stale original
World closes the view; a later explicit mount must not adopt the old draft.

Native 1280x720 acceptance enters through the real panel button, draws with
actual input, switches floors, tests GUI interception, closes/reopens a retained
plan, and demonstrates resource-conserving refusal without completed access.
It also holds a movement key across an actual clock overload, attempts a new
middle drag, checks 32 Tab and 32 Shift-Tab transitions plus navigation keys,
acknowledges through Enter, and uses the actual UI World Create command while
a purpose popup is open. Reopening binds the new full World identity and its
real owners, with an empty new draft.

Evidence: `docs/validation/evidence/underground-planning-scene-2026-10-05/`.
Final focused candidate9: **30 tests, 1,132 assertions, zero failures**; every
suite reports zero unexpected errors/warnings and zero object/resource leaks.
Analyzer: **0 GDScript warning(s) in 0 of 6 file(s)**, raw editor findings zero.
Native4: **74 checks, zero failures**, five inspected 1280x720 PNGs, default
Metal/Forward+ renderer, raw import/runtime diagnostics and leaks zero.
Original project, assets and source pins are restored. The focused run is not
a replacement for the full no-argument integrated milestone.

This scene integration does not claim the empty Kitchen or stairs are playable
until paid access, worker travel and excavation finish through their real
owners. Original game state and per-owner source checks remain unchanged.
