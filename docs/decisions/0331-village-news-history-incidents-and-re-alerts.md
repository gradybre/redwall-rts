# 0331 — Village news: the history, incidents that stay until resolved, and re-alerts on recurrence
Date: 2026-09-30 · Status: Accepted

External review group I (F11, F37, UX-011; the review's P1 "Village news / chronicle" row), written against
157a3a4 and reconfirmed here on `fix/review-c-water` (b400886 + 89672be) before any fix. **Numbered 0331:** the
highest decision on this branch is C's 0231, plus 100 (parallel review branches each take their highest plus a
step so they cannot collide). 0331 was checked against every branch and every review worktree and was free;
H, whose base is E's 0251, does not land on it. Everything is in `godot/demo/` (presentation over integer
rules); the HUD's shell (`scripts/ui/ui_shell.gd`) is read, never modified.

## What was confirmed first

- **F11.** `demo_news_strip.gd` dropped a warning 30 s of real time after it was posted, paused or not (a probe:
  shown at post, gone at +31 s with nothing able to say "paused"); the feed kept 32 rows and nothing could show
  them; N opened the shell's history, which holds no demo notice.
- **F37.** The review's probe on the real farm: bed 4 (radish) at 9800 -> 6000 -> 9800 moisture, `collect_into`
  after each, six farm hours apart: "Bed 4 (radish) is waterlogged and has stopped growing — Drain it", then
  nothing, then nothing, though the bed was waterlogged again. The key was bed + condition + season and never
  cleared. Dry ("too dry to grow") and worn out used the same season key.

## Decision

**A news clock** (`demo_news_clock.gd`): real milliseconds that stand still while the village is paused,
advanced by the news strip every frame from the real clock and `GameManager.is_paused()`. The feed's post times,
the strip's toast ages, a resolved card's linger and a snooze all run on it. A toast still expires in real time
(UI §7's "12 real seconds") and still does not run faster at 4x -- but it no longer runs while paused: pausing
permits reading indefinitely (P1). Expiring toasts at all is kept: they are the transient view, and nothing
actionable is lost with them (below).

**The feed grows and keeps what is still true** (`demo_notices.gd`). CAPACITY 32 -> **128 (x4)**: with every
entry readable in a history, 32 was under two game hours of a busy morning. An entry may carry a TARGET (bed,
tree, tunnel, resident, bridge, with its id) and the INCIDENT serial it reports. When full, the oldest entry goes
-- unless it is the newest entry of an incident still unresolved or pinned, when the oldest entry that is not
goes. An incident holds at most one entry and there are 48 incident rows against 128 entries, so a victim always
exists. Storage became oldest-first packed columns (a `remove_at` per overflow, a rare event) so that overflow
can skip a row; the public reading API is unchanged.

**Incidents** (`demo_incidents.gd`, packed columns, 48 rows, named by a never-reused serial): a KEY, source,
severity (ROUTINE / WARNING / CRITICAL), state (NEEDS A DECISION / ASSIGNED / RECOVERING / RESOLVED), the
latest text and date, a target, and a count.
- Raised while open: a **merged repeat** (count up, newest text, no cue, an acknowledgement stands). Raised after
  it resolved: a **recurrence** (same card, count up, needing a decision, unacknowledged, unsnoozed, cued).
- A source hands `raise` a WATCH, `() -> state`, which `sweep()` (the card's refresh, 4 Hz real time) asks; or
  says so itself (`update`, `resolve`).
- **Who sees what.** CRITICAL incidents queue at the top centre under the HUD's alert zone, **one** card drawn
  with "1 of N" (`ui/demo_incident_cards.gd`): pinned first, then severity, then the earliest. A pinned card of
  any severity joins the front and stays, resolved or not. A resolved critical card says "Resolved" for 6 s
  (news clock), then goes. Warnings and routine incidents never take the card unless pinned: they are in the
  history's "Needs attention" and the strip's count ("2 need attention", UI §7's badge that persists until
  resolved). The card yields to the stall banner and to the open history (one surface for the most urgent
  thing; one expansion per zone).
- **Verbs:** Go to, Pin / Unpin, Snooze (2 min of unpaused time; offered only where a card would queue:
  critical or pinned), Dismiss (acknowledge: out of the queue and unpinned; a dismissed warning or critical
  incident stays in the history's list and the strip's count until it resolves -- UI §7 WARNING, "badge persists
  until resolved" -- and a dismissed ROUTINE one leaves both -- UI §7 ADVISORY, "acknowledgment hides the card
  until the condition changes").
- A new occurrence takes the watch it is given, none included, so a reused row never keeps another incident's
  watch; a merged repeat keeps its watch unless given one. A raise refused by a full table (48 open) still posts
  its feed line, unlinked, with a warning in the log: the warning is never lost with the incident.
- **The sound hook** (review group R): `incident_cue(cue, serial, severity)` -- CUE_CRITICAL_RAISED when a
  critical incident is raised or recurs, CUE_RESOLVED when any resolves; never for a merged repeat. A UI signal
  only; nothing in the game listens.

**What is an incident** (each with its watch):
| Key | Severity | Target | Assigned / recovering | Resolved |
|---|---|---|---|---|
| `farm:wet:<bed>`, `farm:dry:<bed>` | warning | bed | a Drain / Water job on it; ENDING (back in band) | 2 farm hours back in band, or the bed stops growing |
| `farm:worn:<bed>` | routine | bed | a Compost job; ENDING | 2 hours fertile again, or sown |
| `farm:blight:<bed>` | warning | bed | a Clear job | not blighted |
| `farm:frost` | warning | -- | -- | `Weather.frost_due` false (the night's last frost hour over) |
| `farm:stuck:<bed>:<kind>` | warning | bed | that job on the board again | the bed no longer wants it (`refusal_for`) |
| `farm:store_full` | warning | -- | -- | a store has room for 1 U |
| `tunnel:flooded|collapsed:<slot>:<gen>` | warning | tunnel | a job on it | reopened (`closed` none) or gone |
| `threat` | critical | -- | while it lasts (everyone sheltering) | over |
| `woods:windthrow:<tree>` | warning | tree | a haul on it | trunk hauled clear |
| `village:no_bed` | warning | first bedless resident | -- | everyone bedded (each dusk's allocation) |
| `water:rescue:<who>` | critical | resident | a responder on it; towed | out of difficulty |

The rescue incident's text is C's one incident line per victim (`waterplay_text.gd incident_words`), updated in
place (`demo_waterplay.gd sync_incidents`, at the panel's 4 Hz, whether the panel is shown or not). C's latched
LOW_AIR / AIR_OUT notices are unchanged and still post once per dive (tested beside the incident).

**F37: standing conditions re-alert** (`farm_alerts.gd` STANDING CONDITIONS). Dry, waterlogged and worn out are
per-bed conditions with phases IDLE / ACTIVE / ENDING. Announced on IDLE -> ACTIVE; silent while ACTIVE; on the
condition's absence ACTIVE -> ENDING (RECOVERING on the card); after **REARM_HOURS = 2** farm hours of staying
absent ENDING -> IDLE (resolved, re-armed); present again while ENDING -> ACTIVE silently (the same occurrence);
present again after IDLE -> announced again, same season or not. A bed that stops growing (harvested, withered,
cleared) ends dry and wet at once; a bed sown ends worn out at once. Blight and frost were already per event /
per night; they gained incidents. The forecast (per event per season) is an announcement, not a condition, and
keeps its season key.

**The history window** (`ui/demo_news_history.gd`, non-modal, top centre under the alert zone, at most 680 x
600 logical, down to just above the command strip). Filters by place (All / Farm / Woods / Tunnels / Water /
Village; Village is the weather, threats and the crew's reports) and severity (All / Warnings / Notes). "Needs
attention" lists open and pinned incidents (place-filtered) with their verbs; "History" every kept entry passing
the filters, "date · place · Warning: text", "— still open" while its incident is, and Go to where it has a
target -- the target the row was DRAWN with, so a post arriving between drawing and the click cannot move it
onto another entry. The first PAGE = 40 rows are drawn, "Show older (N more)" adds 40 more; a redraw rewrites
only a row's text or colour that changed (a post with the window open costs about 0.2 ms headless, from 3.4 ms
when all 128 rows were rewritten and recoloured). Go to (`ui/demo_news_jump.gd`) selects the target the way a click would (`select_bed`, `select_tree`,
the tunnel's selection and panel, the resident, `select_bridge`) and eases the camera over it
(`demo_camera.gd centre_on`), and closes the window so the target is not under it. Rows are pooled and grow
only; a refresh rewrites text, only when the feed, the incidents or the filters changed.

**Opening it.** The strip's button ("2 need attention — Village news history (N)"; the strip now stays up
while anything is open), the card's "All news (N)", **N** and the HUD's own history trigger. N is read by the
window's `_unhandled_key_input`, which runs before the HUD's (later in the tree), so the shell's history is
never opened under it -- except while the shell's own history is open (from a settlement card), when N is left to
the HUD, which closes it, and the routing below closes the window with it; the card also yields to the shell's
open history. The trigger is a button, so the demo listens to `shell_action(ID_HISTORY_TRIGGER)`: the
shell's history just opened -> it is closed again (the window stands in for it in the top-centre zone, UI §1 /
§3 one expansion per zone), the focus it handed back to the trigger is let go (else the HUD draws the
trigger's keyboard description over the window), and the window toggles; the shell's history just closed
(opened from a settlement card) -> the window closes too. "Settlement notices" in the window's header opens
the shell's own history.

## Why

- Toasts expire in real time by design (UI §7); the review's complaint was that expiry deleted TRUTH. Separating
  the transient view (toast, news clock) from the record (history, 128) and from what is still true (incidents)
  answers it without restoring the two permanently occupied HUD cards (decision 0196).
- A paused clock rather than "toasts never expire": a toast that never expires would rebuild the clutter;
  one that does not age while nobody can act matches P1's "Pausing permits reading indefinitely".
- Incidents live beside the feed, not in it: the feed is a dated log (a repeat folds, an entry ages out); a
  condition is keyed and has state. UI §7 already names both ("active conditions remain in the active-condition
  store even if their historical entries aggregate").
- REARM_HOURS = 2 (a demo value, 50 s at 1x): the farm checks hourly, so a cooldown under 2 hours is none; rain
  can lift a drained bed back over its band within the hour, and that is the same occurrence, not a new one.
- Watches rather than pushes: each module knows its own resolution in one line (a job on the bed, the segment
  reopened); pushing from every place a condition can end would touch far more code.
- N read by the window rather than routed through the shell: routing opened and shut the shell's history
  inside one key press and left the HUD's keyboard focus description on the trigger (seen in the first capture).

## Consequences

- `demo_notices.gd post()` gained optional `target_kind`, `target_id`, `incident` arguments; REPEATS FOLD also
  compares them. Every existing caller is unchanged.
- The HUD is untouched. Group G's input gate (`fix/review-g-input`, decision 0261) changed the strip's
  `band_placement` to `DemoUiScale.percent`; the new card and window use `UiLayout.USER_SCALE_100` through
  `farm_ui.gd geometry_for` like the rest of this branch and should follow `DemoUiScale` when merged. G's gate
  reads input first: the window's Esc and N should be checked against it on merge (the window is non-modal).
- Group R can connect `services().incidents.incident_cue` directly.
- Feed overflow drops the oldest unheld entry whatever its level; UI §7's history evicts "oldest resolved INFO
  first". Kept as is: the demo feed holds 128, not 500, entries, and level-first eviction would keep a stale
  warning over newer notes; the open conditions themselves are held by their incidents.
- A tunnel or bridge target is a slot / row without its generation, so an old entry's Go to may land on a tunnel
  that has since reused the slot (resolution itself checks the generation). Accepted for the demo.
- On this branch the HUD shell has no public scrim query, so N is not withheld under a HUD workspace's scrim;
  G's `workspace_owns_input()` (decision 0261) should be added to `defer_keys_while` on merge.
- Not done: a per-resident "stuck job" for the woods' and tunnels' crews (only the farm crew's unreachable jobs
  are incidents); the history is not saved (nothing in the demo is); the card's verbs are mouse-only
  (`farm_ui.gd` buttons take no focus), as every other demo panel's.
- Tested in `godot/test/test_demo_news.gd` (33 tests, no staged assets). Mutation-tested one mutant at a time,
  each restored and shasum-checked. First pass: 54 mutants, 53 killed; the survivor (ACTIVE -> ENDING guarded by
  `applies`) was equivalent -- the guard was redundant -- so the guard was removed and the mutant re-aimed at the
  at-once resolution. The independent review then found six more survivors (recurrence unsnoozing, severity
  order, a snoozed pin, a routine line's level, folding across incidents, the serial tie-break) and a vacuous
  full-store check; tests were added for each and for its own findings. Final pass on the committed code: **71
  mutants, 71 killed** (the double watch reset was cut to one, so its now-redundant mutant was dropped). Frames:
  the review scratchpad's `rv_i_check/` at 1280x720 and 1920x1080 (the incident card with a merged repeat, the
  history from N and from the HUD trigger, the Farm + Warnings filter, the Go to result on bed 4).
- Independent review (code-reviewer agent): C1 (a reused row kept the previous incident's watch: a rescue raised
  into it was resolved and re-raised four times a second), H1 (a full table silently dropped the feed line), and
  MEDIUMs -- Go to on a stale index, a 3.4 ms redraw per post, N bypassing the shell's open history, vacuous and
  missing tests, dismissed routine incidents never leaving, `show` shadowing `CanvasLayer.show` -- all fixed and
  tested; LOWs fixed where cheap (same-day blight recurrence, the strip button's focus) and the rest recorded
  above.

## Source

`/Users/brendan/Developer/redwall-review/REVIEW.md` F11, F37 and P1's "Village news / chronicle" row; the review
digest's UX-011; UI §1 (top-centre alerts and history), §3 (one expansion per zone), §7 (lifetimes, the badge,
reannounce after clear and recur, the active-condition store); decisions 0196, 0205, 0210, 0231.
