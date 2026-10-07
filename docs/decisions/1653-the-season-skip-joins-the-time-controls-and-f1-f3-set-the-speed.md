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

## Review (independent `code-reviewer`, on 4a5055b6)

Nothing CRITICAL. Confirmed: the skip's effects are the Lab's (the same function, forgiving the real time it takes);
F1–F3 never clear a pause; no F-key collides; F1–F3 were unread before.

- **HIGH, fixed: the menu ran off the screen at 1280×720 with Large readable (125 %).** Measured 460 logical px tall
  unasked and 568 asked, against 576 at that scale. Now the skip sits beside Close on the last row ("Skip to next
  season…", the landing in its tooltip and the question), and the question **takes the targets' place** while it
  stands, the frame fitted again. The session harness now checks the frame is on screen at 100 % and at the largest
  scale the window offers (125 % at 1280×720, 150 % at 1920×1080), unasked and asked: 527.5 px from y 102.5 at
  1280×720 / 125 %.
- **MEDIUM, fixed: F1–F3 reached the time controls through a pop-up's text field** (the input gate passes a typing
  field every key but Enter). `take_key(key, focus)` ignores a speed key while the focus is a LineEdit or TextEdit
  (`is_typing`); tested.
- **MEDIUM, fixed: the question could name a stale date.** The landing is kept when asked; Skip answered after the
  season turned asks again with the new date and skips nothing; tested.
- **MEDIUM, fixed: Cancel as the default answer was untested.** The session harness now asks by the keyboard (focus on
  the skip, Enter), checks Cancel has the focus, and Enter cancels with the menu still open.
- **LOW, fixed:** F1–F3 match exactly (Shift/Ctrl+F-key requests nothing); Cancel returns the focus to the skip; Skip
  re-checks that no run is under way (tested by a run started under a standing question).
- **LOW, answered:** a refused `set_speed` (only while loading) still takes the key, as the HUD's toggles do.

Mutation after the review: 9 more mutants (exact matching, both `is_typing` cases, the guard at the call site, the
moved landing, the targets hidden, the focus on Cancel (killed by the harness), Skip while running), **9 killed**.
The lane's total: 25 mutants, 25 killed. Frames re-taken in `scratchpad/time_check2/`: `skip_asks_*`,
`skip_asks_large_*` (1280×720 at 125 % and 1920×1080 at 150 %), `skip_landed_*`; looked at. `LIVE-SUMMARY 89 0` at both
sizes.

## Branch gates (`feat/demo-small-leftovers`, all three packets and their review fixes; 2026-10-07)

- **Full suite, CI-style** (assets moved aside, `godot/.godot` deleted, fresh import, `./tools/run_tests.sh`):
  `9149 test(s), 612086 assertion(s), 0 failure(s)`;
  `diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 272 expected, 353 tolerated; leaked at exit: 0 object(s), 0 resource(s)`;
  `log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).`
- **Analyzer**: `0 GDScript warning(s) in 0 of 1028 file(s)` (one run during the contracts reported a spurious
  "Cannot find member" while the cache was busy; the rerun and the run after the CI-style suite both read 0).
- **Contracts**: every check in `.github/workflows/tests.yml`'s contract and preflight groups (43 commands, among them
  `decision_numbers.py`, `ready07_arithmetic.py`, `merge_gate.py`, `setting_contract.py`, `dispatch_plan.py --validate`,
  `astra_inbox.py --check`, `generate_canonical_state_table.py --check`, `lane_notes.py --check`, the movement checks
  and `state_registry_coverage.py`) exit 0. No settlement bytes were added, so the memory ledger and capacity audit are
  unchanged.

## Brendan's rulings (2026-10-07)

Relayed by the coordinator on 2026-10-07 as approved as built:

- **P1**: (a). The skip sits in the Run until… menu, beside Close. There is no new button and no new key.
- **P2**: (a). The Demo Lab keeps its own "Skip to next season" trigger too.
- **P3**: (a). The skip is disabled while a Run until… is under way.
