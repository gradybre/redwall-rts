# F6 focus and founding-cohort rollback state

2026-09-11 · UI-FOCUS-R01 and STATE-COHORT-R01.

## UI-FOCUS-R01

F6 is an out-of-band shortcut that opens UI-SET-087 World access. The shortcut is
not a focusable widget. When the workspace is closed, its panel and children
must be absent from focus traversal, accessibility traversal and hit testing.
Ordinary HUD Tab order begins with resource element002, then existing resources,
alerts, time, minimap, commands and detail. Opening F6 follows workspace order:
title announcement, search/filter, available content, then Cancel/Confirm where
present. A title announcement does not make the panel container a Tab stop.

Consume handled F6 input; suppress it while a text/number editor, rebind capture
or system dialog owns the input. Restore the valid invoking control on close;
with no surviving invoker use the first valid HUD control (normally002). Never
leave focus on a hidden panel. Residents still opens069, not087.

Audit: ui_focus_order.gd's HUD_ORDER currently includes87 before2 and its test
pins that error. project.godot maps open_world_list but production input still
needs its actual F6 handler. Correct both runtime and obsolete assertion under
the UI owner's task; this documentation change alone does not implement F6.
Test closed/open/close traversal, rebind and edit suppression, no leaked world
click/key action, modal trapping and disappearing invoker at every UI profile.

## STATE-COHORT-R01

residents.gd `_cohort_slots` is category3 transaction rollback scratch, with no
save section and no canonical digest membership. It is written by synchronous
spawn_initial_settlement and read by its rollback routine only. Stale successful
call residue is not an authoritative founder history. Bare reusable slots could
not preserve that history after death even if serialized.

This is the same classification as gear's starter-seed rollback buffer. Save at
completed boundaries only, never midway through either call. A future founder
history must use persistent IDs under its own declared Chronicle/identity owner.
Reset this scratch to null slots during scratch initialization/load; never clear
the authoritative directory merely to reset scratch.

Acceptance: differing out-of-call rollback residue gives identical save bytes,
canonical digest and next authoritative tick; partial cohort failure leaves no
half-cohort, and stale entries are never read as current residents. Retain exact
allocator semantics in failure fixtures: current despawn rollback may advance
ID/generation allocators, so do not falsely assert whole-directory bit parity.
World initialization's separate transactional/preflight contract still applies.
Registry coverage should pass with category3 and no section; add meaningful
behavior tests when the production save/initialization callers exist.
