# 0591 — Notices get tiers, kinds, grouping, snooze and a toast budget
Date: 2026-10-01 · Status: Accepted; Brendan ruled on all ten proposals the same day (below)

Numbered 0591 because the brief asked for 0591–0599. No record numbered 0590–0599 exists on any branch
(`git log --all`) or in any sibling worktree.

Feature #39, "a better notices system", approved by Brendan on 2026-10-01. It builds on the demo's one notice feed
(decision 0196), its folded repeats (0210), the incidents, history and top-centre card (0331), the sound (0351) and
the pause ledger (0471). Presentation only: nothing here writes the simulation.

## What the documents already rule

- **UI §7** (the severity table). INFO is "soft optional chime", 12 real seconds, history retained. ADVISORY and WARNING
  have no default pause. CRITICAL is "auto pause only the cases in Section 3". The rest:
  - Order by severity, then the earliest tick.
  - "Repeated same code/source updates count/last-seen tick without replaying chime."
  - "Group multiple residents with the same code into one card."
  - "Clicking focuses the problem."
  - "Each notice includes severity word+icon."
- **UI §3**: the pause-reason set, and critical auto-pause only in the listed cases. The demo's critical incidents
  already pause through the ledger's INCIDENT hold (0471).
- **UI §2.1**: "Interactive minimum hitbox 32×32".
- **UI §1 and UI-SET-012 / UI-SET-102**: the notification history expands from the top centre; N opens it.
- **GDD §2, Notice**: `severity`, `category`, `source`, `code: StringName`, "deduplicated active key(code, source)".
  REQ-SET-175 says a resolved condition keeps its history record.
- **Decision 0076** (the narrow alert card) is the shell's settlement card. The demo raises no HUD card (0196), so it
  is untouched.

## Decision

1. **Tiers.** Every entry has a tier: `TIER_URGENT`, `TIER_NORMAL` or `TIER_INFO` (`demo/demo_notices.gd`).
   - A poster may name the tier. Otherwise it is inferred: a WARNING is normal and a NOTE is info.
   - An incident's line takes its severity (`demo_incidents.gd tier_of`): critical is urgent, warning is normal and
     routine is info.
   - The strip and the history draw each tier differently.
     - Urgent: the heading face, clay, and the word "Urgent:".
     - Normal: clay, and "Warning:".
     - Info: ink, with no word.
   - The tier never pauses anything. A critical *incident* pauses, through the ledger, as it already did.
2. **Kinds and subjects.** The kind is the GDD's `code` and the subject its `source`.
   - A poster may name both (`post`'s new last three optional parameters, or `notify`).
   - An incident's line takes them from its key. The words before the first whole number are the kind, and the rest
     is the subject: "tunnel:flooded:4:2" gives kind `tunnel:flooded` and subject `4:2`.
   - Any other line's kind is "<source>:<its words>".
   - A missing subject falls back to the target ("bed:3").
3. **Grouping.** A post that names its kind joins the newest entry of the same kind and subject, if that entry was said
   within `GROUP_WINDOW_TICKS` (one game day). The entry counts it ("Crows at the barley (×3)"), takes the new words,
   tier and date, and moves to the newest place.
   - It writes no new row, so it does not chime again (UI §7).
   - Incident lines never group: the incident is the group, and the history keeps each date (0331).
   - Untagged lines keep 0210's adjacent fold unchanged.
   - Because a row can now move, a reader of new rows uses entry ids (`is_new_since`). The sound and "Run until..."
     (`session/time_control.gd`) were changed to do so.
4. **Go to.** The strip's lines gain the same Go to the history and the card have, through `demo_news_jump.gd`.
   - It shows only when the subject is found, and it selects the subject and centres the camera.
   - It uses the HUD's own centre-view crosshair (`ui/icons/center_view.svg`), with "Go to" as its tooltip.
5. **Snooze and dismiss.**
   - *Snooze* quiets a kind for N game hours (`snooze_kind`, `demo/demo_notice_snoozes.gd`, 16 kinds).
   - *Dismiss* takes one entry off the strip (`dismiss`).
   - Both keep the entry in the history, which deletes nothing but by overflow.
   - The strip has × on each line. Each history row has *Snooze 6 h* (*Wake* while its kind is quiet) and *Dismiss*.
     The window names the snoozed kinds with their hours left, and has *Wake all*.
6. **History by tier.** The village news window's severity row is now a tier filter: All, or any of Urgent, Normal and
   Info, picked the way places are picked. `set_severity_filter` maps onto it.
7. **Throttle.** A new row is announced (toasted and chimed) only while its tier's toast budget allows.
   - The budget is `TOAST_BURST` (4) at once, plus one every `TOAST_REFILL_MSEC` (2.5 s) of the news clock (unpaused
     real time).
   - Info and normal have a budget each, so a burst of reports never silences a warning.
   - Urgent is never held back.
   - The strip's title counts what was held back lately ("Village news (demo) · 6 more (N)"). Everything is kept in
     the history.
8. **The strip keeps to its band.** Each line now has 32 px buttons beside it (UI §2.1), so lines can be taller than
   before. Where they would make the strip taller than its band, it draws fewer lines.
   - The most urgent lines are kept first, then the newest, drawn newest on top.
   - At 1280×720 the strip would otherwise rise over the Map layer picker. It now draws one or two lines there.
   - The strip's own history button is now 32 px tall too. It was 28 px, under the floor.
9. **Sound, from the cues the table already has.**
   - Info is silent (§7's chime is "optional").
   - Normal plays the `warning` cue once, as every warning did before.
   - Urgent plays it, then again `URGENT_ECHO_MSEC` (1.6 s, just past the cue's 1.5 s gap) later. A critical incident
     raised counts as urgent.
   - A held-back or snoozed row is silent.
10. **The hook.** The feed emits `notice_posted(entry_id, tier, kind, text)` for every accepted post, including folds
    and grouped repeats, for the crash log's breadcrumbs. Entries carry `entry_id`, `first_tick` and `said_tick`, so a
    chronicle can read the history incrementally.

**API compatibility.** Every existing call site is unchanged. `post` keeps its seven parameters in order and adds
`tier = TIER_AUTO`, `kind = NO_KIND` and `subject = ""` after them. `report`, `raise`, `poster`, `rows_posted`, `level`
and the line formats of normal and info entries are unchanged.

## The ten proposals and Brendan's ruling

**Ruling, 2026-10-01: Brendan approved all ten as built**, each with the recommended option below; relayed to this
work by the feature coordinator. Where the documents were silent, each was the smallest demo behaviour; they are now
adopted demo rules, not open questions.

| # | Question | Options | Ruled (as built) |
|---|---|---|---|
| P1 | Three tiers against §7's four severities | (a) urgent = CRITICAL, normal = WARNING + ADVISORY, info = INFO; (b) add an advisory tier | (a), as the brief asked |
| P2 | Distinct sounds with only one alert cue in the table | (a) info silent, normal one chime, urgent two; (b) a new softer cue (a new staged file, `tools/stage_demo_audio.py` CHOICES and its ledger); (c) info plays `complete` | (a) — no new asset, no change for today's warnings |
| P3 | How long a repeat still groups | (a) one game day since it was last said; (b) while its toast is fresh; (c) for ever | (a) |
| P4 | The history's Snooze length | (a) one button, 6 game hours; (b) 2 / 6 / 24 h choices | (a); `snooze_kind` takes any whole number of hours |
| P5 | May urgent notices be snoozed or held back? | (a) never — the incident card has its own Snooze; (b) yes | (a) |
| P6 | The toast budget | (a) 4 at once, +1 per 2.5 s, per tier; (b) only at 2x/4x; (c) none | (a) — real time, so it only bites when the village says a lot a real second, which is 4x |
| P7 | An urgent toast's life on the strip | (a) 60 s of unpaused time; (b) until dismissed | (a) |
| P8 | Per-line buttons cost a line at 1280×720 | (a) Go to and × on every line, fit to the band; (b) verbs only in the history (three lines, no buttons); (c) verbs on the newest line only | (a) |
| P9 | What Dismiss on a notice does to its incident | (a) nothing — the notice is off the strip; the incident keeps its own Dismiss; (b) acknowledges the incident | (a) |
| P10 | An untagged line's kind | (a) its source and words, so Snooze quiets that exact line; (b) its source, so Snooze quiets the whole source | (a) |

## Review

An independent review (code-reviewer) found no CRITICAL or HIGH issues; API compatibility holds. From its MEDIUM
findings, these were fixed:
- The strip's × and Go to are now 32×32 (UI §2.1's hitbox), and the live harness checks their width too.
- Tests were added that catch a grouped repeat losing its new tier, `_remove` losing a column's place, a named notice
  joining an incident's line, and the urgent size.

Left as they are, for a ruling if wanted:
- **"Run until the next warning" counts every new warning row**, including rows of a snoozed kind and rows the budget
  held back, so such a row can end a run without a toast to show why. Counting announced rows only would change
  decision 0471's target.
- The `matches` / `filtered_into` filters (by level) and the history (by tier) disagree on a NOTE posted with a
  normal tier. No caller does that.

## Also found

- **The pause card is drawn far taller than its one row.** It covers the top centre and part of the village news, and
  its frame takes the mouse. Another review branch's capture of the player pause shows the same.
  Not changed here (`demo/ui/demo_pause_card.gd` is not this feature's). The new live harness hides the card while it
  clicks the news, and says why.
- The brief named the incidents panel "(I)". The village news window is on N (UI-SET-102), and **no key was added**.
