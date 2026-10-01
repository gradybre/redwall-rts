# 0492 — The seasonal planner takes T, Run until keeps G, and T is no longer the Dig tool's alias
Date: 2026-10-01 · Status: Accepted

Numbered 0492: the next free number above 0490 on every local branch, worktree and origin ref when this was written
(0491 is group T's; 0501, 0511, 0521 and 0531 belong to other lanes).

## Decision

At the batch 5 integration, two branches built from the same base both bound **G**: group O's seasonal planner
(decision 0451, `demo/farm/farm_planner.gd`) and group S's "Run until…" (decision 0471, `demo/ui/demo_run_menu.gd`,
read in `demo/session/time_control.gd`). The coordinator's resolution:

- **The planner moves to T** (`farm_planner.gd KEY = KEY_T`): T is UI §5's calendar key (`open_calendar`, UI-SET-101's
  "T shortcut", already bound to T in `project.godot`'s input map). The bed panel's button reads **Planner (T)**, its hint
  "T: planner", its close tooltip "T or Esc", and the input gate watches the planner with T as its close key.
- **T stops being the Dig tool's alias.** The Dig tool stays on **B** (and the party panel's "Dig tunnel (B)"); the three
  `KEY_B, KEY_T` arms in `demo/tunnel/tunnel_control.gd` (open, close while planning, close from a room tool) are B
  only. `test_demo_tunnel.gd` checks that B is taken and that T is no longer the tool's.
- **"Run until…" keeps G.**

## Why

The alias was the only reason decision 0451 had not used T: it said so, and called reclaiming T "a separate decision".
That is this one. G is the more natural key for the session control S added beside the speed buttons; T is the one the
UI spec already gives the calendar, which is what the planner is. With the alias gone, nothing else in the demo binds
T: the input map's only T is `open_calendar`, which no script read until now, and every hard-coded demo key was checked
(B, H, C, L, U, V, K, R, J, N, O, G, F6, F7, F8, F11).

Rejected: keeping the planner on G and moving Run until (S chose G for its time cluster's button, and its tests,
harness and README use it); keeping T as a second Dig key (two keys for one tool, and the calendar's key taken).

## Consequences

- Every reference moved: the bed panel's button, hint and signal comment; the planner's and the farm's headers; the
  README's farm table, planner section, Dig rows and key table; the help topics (decision 0481: the "B" key row, a new
  "T" key row and a "Plan the season" topic; the "G" and "F6" rows from S); decision 0451; the planner's tests and its
  live harness (`test/live/demo_planner_live.gd` presses T); the help and menu key checks.
- Inside the Dig tool T now falls through to the farm, so it opens the planner as any modal would; B still closes the
  tool.
- The HUD's date trigger (UI-SET-101) still opens the shell's own calendar panel; routing it to the planner stays open
  (0451's Left open).

## Source

UI §5 (`docs/ui_ux_controls.md`: UI-SET-101's "T shortcut", the Calendar / open_calendar row); `godot/project.godot`
`open_calendar`; decisions 0451 and 0471; the coordinator's batch 5 ruling.
