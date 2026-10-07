# 1653 — The season skip joins the time controls, and F1–F3 set the speed

Date: 2026-10-07 · Status: Accepted (placement P1–P3 are PROPOSALS, below)

Handoff packet TIME, feature #59 (`docs/handoff/BACKLOG.md` "TIME"). Branch `feat/demo-small-leftovers`.

## Approval and rules

- Feature #59, time controls: Brendan, 2026-10-01 ("NEW 3"), recorded only in the coordinator's tracker;
  `docs/handoff/RULINGS.md` (2026-10-01, "New features, 'NEW 3'") is its first repository record. Winter ruling 4
  (decision 0571): "a Skip-to-next-season control"; the tracker placed it "in the speed area".
- GDD REQ-SET-002/003/004 (1×/2×/4× fixed ticks, the pause's freeze) and REQ-SET-008 (the overload ladder, a pause with
  a diagnostic at 1×) are already built in `scripts/core/sim_clock.gd` and `scripts/systems/game_manager.gd`, with the
  demo's stall banner (`demo/ui/demo_stall_banner.gd`) as the player's way out. UI-SET-014–017 (pause and the three
  speed toggles) are the HUD's, and the pause reasons are the pause ledger's (decision 0471). Nothing here changes them.
- `ui_ux_controls.md` §5's input table: `time_pause` Space / Ctrl+Space, `time_speed_1/2/4` on **F1 / F2 / F3**, no
  3×. Pinned by `test_input_map.gd`.

## What was found

The three speed actions were mapped in `project.godot`, but **nothing in the demo read them** (only `time_pause` was
read, by `session/time_control.gd`; `scripts/main.gd` reads only `time_pause` too). F1–F3 did nothing in the live demo.
The packet's pitfall asked to check F1–F3 against the demo's own F-keys: F6 object list, F7 focus switch, F8 Demo Lab,
F11 full screen, F12 playtest mark (`demo_window_keys.gd`, `demo_input_gate.gd`, `demo_lab.gd`, `playtest_log.gd`,
SEQUENCE.md §4). **No collision.**

## Decision

- **`demo/session/time_control.gd`**: F1 / F2 / F3 (`time_speed_1/2/4`) request 1× / 2× / 4× through GameManager
  `set_speed`, as the HUD's toggles do: the requested speed only, never clearing a pause (UI-SET-015–017 "does not
  clear other pause reasons"). The key handling moved into `handle_key(key) -> bool` (Space, F1–F3, G), which
  `_unhandled_input` calls and marks handled, so a suite drives it off-tree. **No key was added**: these are UI §5's
  own bindings, now read.
- **`demo/ui/demo_run_menu.gd`** (SKIP TO NEXT SEASON): the Run until… menu (its button sits in the HUD's time cluster;
  G opens it) gains a last line, "Skip to next season: Y1 Summer 1, 06:00…". Its tooltip says what is not lived (the
  packet's pitfall: walking, work, meals and exposure). A click **asks first**: the question, and Skip / Cancel
  (focus on Cancel). Skip calls the host's `on_skip` and closes the menu; Cancel does nothing. Disabled while a run is
  under way ("Stop the run first"); not shown without a host and a calendar.
- **`demo/winter/season_skip.gd`**: `target_words(calendar)`, where a skip lands as the demo prints a date.
- **`demo/demo_village.gd`** (shared file; the hook): two lines where the run menu is wired (its wiring moved out of `_build_session`, then 31 lines, into `_build_run_menu`),
  `_run_menu.calendar = _services.calendar` and `_run_menu.on_skip = skip_to_next_season`. That is the same function
  the Demo Lab's "Skip to next season" trigger calls, so **the effects are the Lab's by construction**: the crops,
  stores, weather and hearths hour by hour, the kitchen's quiet catch-up, the exposure clock rebased, the news line.
- **Words**: the help's "Pause and speed" topic and key list, and `godot/demo/README.md`'s time controls and key table.

## PROPOSALS for Brendan

- **P1. Where the skip sits.** Built: the last line of the Run until… menu, opened by the button in the time cluster
  or G. (a) As built: no new key, and no new button in a cluster that is already full at 1280×720 (the Run until…
  button moves left of the cluster at the narrow profile). (b) Its own button in the time cluster. (c) Its own key.
  Recommendation: (a).
- **P2. The Demo Lab keeps its trigger too.** (a) Keep both (the Lab is the testing panel; harnesses use it).
  (b) Remove it from the Lab. Recommendation: (a).
- **P3. During a run.** Built: the skip is disabled while a Run until… is under way. (a) As built. (b) The skip
  cancels the run and then skips. Recommendation: (a): two time commands at once should not race.

## Follow-up (not done here)

`scripts/main.gd` (the settlement game) reads only `time_pause`; F1–F3 do nothing there either. The settlement UI is
outside this lane (a parallel workflow owns it); a later settlement lane should read `time_speed_1/2/4` the same way.

## Tests and gates

- `test_demo_time_controls.gd` (new): the speed keys are the input table's (no other key, no 3×); F3/F2/F1 set the
  game's requested speed; a speed key while paused does not resume; a release or repeat is not taken; where a skip
  lands (spring → Y1 Summer 1; the last hour of winter → Y2 Spring 1); the skip asks and Cancel does nothing; Skip
  calls the host once and closes, never again without asking, reopened unasked; disabled while a run is under way,
  not offered without a host or a calendar; a held G (a repeat) is not taken. `8 test(s), 44 assertion(s), 0 failure(s)`.
- Live `demo_session_live.gd`, both sizes, by real input: F3 then F1; G, the skip asks, Cancel leaves the calendar;
  asked again and Skip: the calendar lands on Y1 Summer 1, 06:00 to the tick, the menu closes, the news says what was
  skipped. `LIVE-SUMMARY 77 0` at 1920x1080 and 1280x720.
- Frames (looked at): `scratchpad/time_check/skip_asks_{1920x1080,1280x720}.png` (the question under the targets; at
  720 the menu still ends above the bottom edge), `skip_landed_*` (Summer 1, 06:00 in the cluster and the farm panel).
- Mutation: 16 mutants, **16 killed** (F3's speed, the keys ignored, a speed key resuming, a repeat taken, every key
  1×; no confirmation, Skip without asking, the menu left open, Cancel skipping, the skip allowed or enabled during a
  run, offered without a calendar, the question kept across an open, the landing's year; and either `demo_village.gd`
  line removed, killed by the session harness). "A repeat taken" first survived (a repeated F-key is not an action
  press anyway) and was killed by a held-G case.
- The full suite (CI-style), the analyzer, the contracts and the independent review are run once the branch's three
  packets are in; their lines are added below under "Branch gates" and "Review".
