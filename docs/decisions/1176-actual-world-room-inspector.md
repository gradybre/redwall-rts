# 1176 — Room inspector over the actual settlement

Date: 2026-10-05 · Status: independently reviewed component; integrated native acceptance remains open

The first demo composition uses the existing on-dirt drawing tool and command
adapter over the original mounted SettlementSystem World. The inspector borrows
that Session weakly. It never creates a second World or moves the authoritative
datum to match the older demonstration village, whose layout has different
coordinates. Decision1175 supplies the actual terrain presentation; the shared
demo entry point owns camera, visibility and input handover.

Room purpose comes from the existing eight-entry catalog. Floor selection comes
from the actual bound LevelCatalog, including surface inspection; no fixed
two-floor limit or legacy demo height enters a room order. Looking at another
floor preserves the draft and stops painting until its own floor is shown.
Changing purpose or starting a plan on another floor requires an empty,
explicitly discarded draft, including its undo history. Closing the inspector
retains the draft. No action converts an accepted room's purpose.

The inspector passes the exact original integer datum, fine cells, purpose and
floor to ModularRuntime. It may bind an existing actual access endpoint when
the host supplies one. A missing entrance stays an explicit construction
refusal; no endpoint, passage, worker, paid cut or material is invented by UI.
Confirm continues through RoomOrders' complete physical checks.

Use a scrolling right inspector with 32-pixel buttons, readable body text and
the current woodland theme. The world remains the drawing surface. Preserve
camera input, GUI interception, modal interruption and the draft on close or
level inspection. Reset invalidates the original weak Session and hides its
marks; reopening must not attach an old draft to a replacement World.

This is presentation and command composition, not a new gameplay rule or a
claim that the playable Kitchen is complete. Required evidence includes actual
World identity, unchanged economic state for refused commands, floor/purpose
preservation, native 1280×720 input and visual checks, and independent review.
UG09 still requires real access, movement, delivery, excavation and empty-shell
completion, followed by the other approved workflows.

The final focused component candidate passes10 tests/148 assertions with zero
unexpected diagnostics, warnings or leaks, and zero analyzer warnings in both
files. Independent review closed two MEDIUM findings: fallible Session getters
are captured and null-checked before draft replacement; a modal observer must
return a boolean and preserve the original owner/tool/draft/floor tuple before
input continues. Exact pins and both reviews are retained with the1175 evidence.
This does not replace the pending1179 integrated native input acceptance.
