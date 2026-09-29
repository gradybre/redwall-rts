# 0198 — The focus description and outline go when their control does
Date: 2026-09-28 · Status: Accepted

## Defect

Brendan, in the live demo: after closing a panel, a small framed box reading "x" stayed on
screen.

It was UI-SET-073, the focus tooltip. §2.2 shows a control's description at 0 ms on focus.
Pressing the detail panel's Close gives it focus, which put its description, "x", up, with
UI-SET-074's gold outline. The panel then closed around it. `_show_focus_visuals()` showed both,
and **nothing in the shell ever hid them**. The same happened with any focused control whose
zone was hidden. Opening and closing Residents left "Residents" up.

## Decision

`ui_shell.gd` records the control the visuals describe (`_focus_visuals_owner`). It takes both
down when:

- **that control loses focus** (`focus_exited`, connected for every §4 button and alert card);
- **that control is no longer shown**. `_drop_hidden_focus_visuals()` checks it at the end of
  `_register_hit_regions()`, which every visibility change in the shell already goes through
  (15 call sites, `set_detail_open()` included).

The second rule does not rely on the engine moving focus off a hidden control. Godot does that on
a live tree, but not off-tree, where the suite runs. The shell's own visibility chain
(`_is_visible_chain`) decides instead, the same one the hit table uses.

## Evidence

`test_ui_shell.gd`: two new tests.

- The detail panel closing around a focused Close hides both visuals.
- Focus leaving hides them.
- Neither another panel closing nor an unfocused control's focus loss does.

Mutants, 5 of 5 killed:

- no `focus_exited` watch;
- any control's focus loss hides;
- the outline is left up;
- ancestors are ignored;
- no sweep in the hit-table rebuild.

A sixth call in `set_detail_open()` was redundant (that path already rebuilds the hit table) and
was removed.
