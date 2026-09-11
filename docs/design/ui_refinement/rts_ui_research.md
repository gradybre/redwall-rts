# RTS interface comparison and Redwall implementation guidance

2026-09-11 · Research supplement to SET-UX-VIS-002 and task04.5.
**Six games reviewed; six source images across five games visually inspected.**
StarCraft II is a documented-interaction comparison, not a visual audit this run.
These are selected useful precedents, not a measured ranking of the industry's
best interfaces. No game was launched or usability-tested during this research.

## Recommendation

Keep the FOREST HUD / JOURNAL detail direction. Use Against the Storm for economic
explanations, Northgard for compact settlement context, Anno for decision support
and restrained material treatment, Age of Empires IV for command organization,
StarCraft II for explicit interaction semantics, and Frostpunk 2 for lessons in
identity and misleading navigation. Those are this project's design judgments.
Copy neither a whole interface nor another game's pacing or mechanics.

The biggest improvement is a complete decision path:

**Notice a condition → understand its cause → inspect the relevant place/person →
choose an allowed action → see queued/committed/refused status → recover.**

Each link already has owners in the UI specification. Polish must make the whole
path readable. Attractive panels alone do not establish it.

## Method and evidence limits

Public developer articles, designer portfolios, official patch notes, accessibility
guidance and two screenshot archive entries were retrieved and reviewed. Developer
statements establish reported behavior; images establish only visible composition.
An archive image does not establish current-release behavior, focus order, contrast
ratios, tooltips, timing or accessibility support. Portfolio outcome claims are
the author's report, not independently measured results.

[Source register](rts_ui_sources.json) records URLs, scope and source-image hashes.
The images were inspected at source resolution from temporary downloads. They are
linked, not vendored as production assets. Saved repository content is original
analysis and bounded metadata, not copies of whole articles. The two Against the
Storm screenshots came from the developer page after the web reader timed out;
ordinary public HTML/image retrieval succeeded. Unsuccessful candidate URLs were
not used as evidence. Published years below describe the cited material, not an
assertion that the UI is unchanged today.

## Six comparisons

### 1. Age of Empires IV — command organization

The principal UX designer describes minimizing permanent HUD coverage, placing
resource readouts near spending decisions, clarifying toggles, and using a shared
pattern library. The inspected campaign image groups resources, selection and
commands along the lower edge, leaving a broad world view. The page also describes
text-scaling work and iterative playtesting. [Designer account, S01](https://kevinhustler.me/aoe4).

**Adapt:** consistent command order, distinct active states, contextual detail,
and testing the first finished slice before repeating its components.
**Do not copy:** its corner positions, icon-heavy command density or transparent
text treatments. Our six-zone contract and labeled commands still control.
**Review focus:** UXV-009/010/013/033/040; A04/A05/A07/A22.

The official Season One notes include clearer cumulative stat effects, stronger
remapping-conflict feedback and removal of keyboard navigation from decorative
portraits. These are useful regression cases, not just cosmetic fixes.
[Official notes, S02](https://www.ageofempires.com/news/age-of-empires-iv-season-one-update-release-notes/).

### 2. Against the Storm — explain why the economy behaves this way

Update1.7 adds town/global-effect summaries and building-level worker production
statistics. The two inspected images visibly separate descriptions from numerical
sections; the town view includes search and a visible scrollbar. The notes also
describe an alert opening its related management screen. This is the strongest
precedent here for inspectable causes near the affected system.
[Developer update, 2025, S03](https://eremitegames.com/quality-of-life-update-1-7/).

**Adapt:** resident need explanations and resource-ledger drill-down using actual
state, aligned value columns, obvious scrolling and relevant alert destinations.
**Do not copy:** its ornate borders, pervasive decorative body typography, species
bonuses, production chances, hunting, or roguelike urgency. No source-game value
becomes a Redwall formula. **Review focus:** UXV-016/018/020–022/028; A09/A11/A12.

An earlier update removes resource-icon background gradients for readability and
moves world indicators beside panels rather than above them. This supports testing
icons at actual size and ensuring world markers do not obscure open UI.
[Developer notes, S04](https://eremitegames.com/achievements-update/).

### 3. Northgard — compact settlement information

In the inspected Build image, the thin resource strip pairs stock numbers with
signed smaller values; a seasonal notice sits near the minimap. A selected worker
has a named detail panel, while building categories occupy the right. The world
remains prominent. Some objective text sits directly over bright snow; its actual
contrast was not measured. [Archived screenshot, S08](https://interfaceingame.com/screenshots/northgard-build/).

**Adapt:** compact status plus accessible detail, person identity, and seasonal
information tied to an actual consequence. **Do not copy:** color-only trend
meaning, tiny text, its building/category count or automatic profession changes.
Redwall's calendar, jobs, species and work policies retain their owners.
**Review focus:** UXV-008/013/016/017/019/032; A07–10/A12.

### 4. Anno 1800 — economic decisions and material hierarchy

Game Update6 documents separate production/consumption, stock, population and
finance views, reachable from HUD counters, production buildings and shortcuts.
It also addresses notification volume with filters. That is a useful separation
between overview and diagnosis. [Developer notes, 2019, S05](https://www.anno-union.com/updates/game-update-6-december-10-2019/).

The inspected shipyard image combines dark framing, warm paper quest rows and
restrained gold rules. Its construction panel distinguishes upkeep from purchase
cost. [Archived screenshot, S09](https://interfaceingame.com/screenshots/anno-1800-building-shipyard/).

**Adapt:** our journal/forest contrast, action-relevant quantities and direct access
to their explanation. **Do not copy:** all production charts into the HUD, finance
systems absent from our scope, or maritime/industrial iconography.
**Review focus:** UXV-006/011/016/027/029; A04/A06/A09/A15/A16.

Later notes fix three-digit counters and localized resource-bar overlap: use large
values and long strings as regression fixtures. [Update17, S06](https://www.anno-union.com/updates/anno-1800-pc-game-update-17/).

### 5. StarCraft II — predictable input semantics

Blizzard's guide distinguishes selecting an idle worker from centering the camera
on it on a repeated action; it also documents explicit selection modifiers and
command queuing. [Official controls guide, S07](https://news.blizzard.com/en-us/article/6640645/game-guide-simplified-controls).

**Adapt the principle:** make selection, inspection, camera movement and issuing
an order distinguishable and consistently documented. Test the same enabled
action through its button and configured shortcut.
**Do not copy the bindings or mechanics:** our F1 is speed1, not an idle-worker
key. Foreign combat queues, attack-move and control-group behavior are not
authorized by this comparison. Preserve Redwall's own manual walking, workplace/
zone preferences, rescue, rest/bed assignment and bounded task queues under UI §5.1.
Settlement economic commands and local camera state remain separate.
**Review focus:** UXV-023/029/033; A05/A12/A16.

### 6. Frostpunk 2 — memorable identity, but semantics must win

A participating designer describes community tabs whose icons suggested the wrong
outcomes and event markers whose shapes did not match their destination windows.
Her case study reports icon corrections. The inspected annotated image shows the
original confusing tabs. Its load-screen redesign is explicitly described as
unimplemented; do not cite that proposal as shipped behavior.
[Designer case study, 2026, S10](https://www.milenamlynarska.com/uxui/2026/5/8/game-ux-case-study-frostpunk-2-2024).

**Adapt:** stable labels and symbols from alert to detail; group actions by the
player's intended outcome. Keep ordinary community messages and grief distinct
from urgent failures. **Do not copy:** industrial distress, unreadable atmospheric
text, or icon-only categories requiring repeated tooltip decoding.
**Review focus:** UXV-004/012/018/028/034; A03/A06/A11/A17.

The console team's separate account documents context-sensitive radials and
automatic pauses. That illustrates device-specific design; it does not justify
replacing our Mac pointer/keyboard shell or importing its pause rules.
[11 bit studios account, 2025, S11](https://news.xbox.com/en-us/2025/09/18/adapting-frostpunk-2s-depth-to-a-gamepad/).

## Immediate application to task04.5

The following are review procedures for **existing** requirements, not new gameplay
rules or another competing UI specification. [The machine-readable checklist](rts_ui_review_checks.csv)
maps each procedure to its owner and acceptance case. Use PASS/FAIL/BLOCKED/NOT_RUN
with evidence. Research completion is never implementation completion.

Routing clarification: UI §1.2's generic statement that counters open a ledger
must be read with each registry row's specific destination: population opens the
roster, beds open housing, fuel opens its breakdown, materials open lots. This
research consistently means the **matching detail view**, not one universal page.

| Check | Required review | Existing owner |
| --- | --- | --- |
| RUI-C01 Decision path | Activate food/population readouts; inspect the matching ledger/roster, return and recover focus. If its store/route is unavailable, use the specified compact reason and keep live acceptance blocked | UI-SET-002/006/009/069; UXV-004/016/030; A03/A09 |
| RUI-C02 Quantities | Compare the same committed resource in overview and detail. Verify units, available versus reserved, ready versus potential food and missing versus zero. A value may differ only through its declared aggregation/formatter | UI-SET-002–009; UXV-016/029/031; A09/A16 |
| RUI-C03 Need explanation | Inspect a live need; percent, direction, per-hour unit and explanation match its owner. Unknown modifiers/rates are unavailable, never neutral or fabricated | UI-SET-039; UXV-020–022; A12 |
| RUI-C04 Alert recovery | Group same-code residents and update count/last-seen for repeated same-code/source notices without replaying the chime. Activate the real destination; acknowledgment never resolves the condition or removes its required unresolved badge/count; revalidate stale sources | UI §7; UI-SET-010–012/085; UXV-018/028; A11; UX-T09 |
| RUI-C05 Understandable actions | The same icon/label denotes the same intent. People opens residents, not access mode. A momentary Create/Confirm action never presents a persistent selected check as if it were a toggle | UI-SET-031/069/087/103; UXV-004/010/012/025; A03/A04/A13 |
| RUI-C06 Context and focus | Inspect, then center a resident; change workspace; close it. No command is sent by inspecting, no stale children remain, and focus returns as specified | UXV-004/005/023/029/033; A03/A05/A12/A16 |
| RUI-C07 Tooltip access | Test350ms pointer / immediate keyboard descriptions, viewport clamping, and readable disabled reasons. Tooltip073 remains noninteractive; longer explanations use the owned detail surface | UI-SET-073; UI §2.2; UXV-030/034; A05/A17 |
| RUI-C08 Shortcut parity | For each enabled scoped action, compare UI and current binding; edit a name while pressing gameplay keys. No game command leaks from fields, and no hard-coded foreign binding appears | UI §5; UXV-029/033; A05/A16 |
| RUI-C09 Busy background | Inspect actual summer/bright ground and darker scenes, open/closed detail, narrow drawer and long names. Functional text uses its prescribed solid surface; ornaments/markers never obscure controls | UXV-008/011/013–015/032; A04/A06–08 |
| RUI-C10 Honest command feedback | Exercise paused draft→queued→commit/refusal/cancel with actual IDs. A successful input gesture is not successful simulation work; preserve requested speed and all other pause holds | UXV-017/026/027/029; A10/A14–16 |
| RUI-C11 Learn from observation | Have a person attempt the journeys below without coaching; log errors, assistance and their interpretation. Fix observed failures and keep personal aesthetic verdict separate | UXV-037/040/042; A20/A22/A23 |

**Correction to the synthetic New Settlement target:** its dark Create button has
a check drawn by the shared selected-button helper. That is an illustrative defect,
not a direction to give a momentary submit button toggle semantics. Implement an
ordinary action button under the existing theme; reserve checked/selected semantics
for stateful controls. This note also appears in the package's reference caveats.

### First visual/playability review script

Starting paused, ask the reviewer to (1) identify whether time is advancing and why;
(2) find ready food and its explanation; (3) select a resident, explain Fullness,
then center the camera; (4) submit and cancel a zone while paused; (5) explain a real
refusal and find its recovery; (6) use the same flows in the narrow profile; and
(7) complete New Settlement with an invalid then corrected field.

Record first choice, wrong destinations, missing information, assistance and
completion. Elapsed time is diagnostic, not an invented universal pass threshold.
Zero incorrect simulation actions or unexplained loss of entered data is the
functional expectation. Report participant count; one owner's review is useful
formative evidence, not a representative study. With unavailable runtime bindings,
record BLOCKED for that journey and use a labeled specimen only for appearance.

## Accessibility finding and deferred proposals

Microsoft XAG101 recommends at least18px **rendered body height** for PC text at
1080p, and resizing to200% without losing function. This metric is not the numeric
font size in a Godot theme. Our current contract uses14px secondary /16px body
font settings and100/125/150% user scale. It has not demonstrated equivalence.
Passing contrast checks does not establish compliance with that text guidance.
[XAG101, S12](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101).

The Game Accessibility Guidelines also emphasize redundant color cues, readable
text, clear interactive elements and adjustable interfaces. These reinforce the
existing keyboard, contrast and shape/text requirements; they do not certify this
project. [Guidelines, S13](https://gameaccessibilityguidelines.com/full-list/).

| Proposal | Recommendation and closure evidence | Status / owner |
| --- | --- | --- |
| RUI-P01 Text accessibility | Before claiming accessibility qualification, measure actual Noto glyph body heights on native1080p; design a text-only200% reflow candidate, retaining useful world space. Compare default readability and larger-text layouts. A theme value of18 alone is not a solution | PROPOSED, not an approved constant. Design lead must amend UI §1–2/§8, SET-UX-VIS-002, fixtures and references before dependent implementation |
| RUI-P02 Additional economic history | Evaluate any extra retrospective history view only where sampled data, time window, exclusions and accounting meanings have owners. Existing UI §7 forecasts and table alternatives remain required in their assigned milestone | ADDITIONAL history proposal deferred beyond immediate04.5; architecture must own collection, storage, cadence, save/hash classification and missing data. This does not defer or replace existing forecast scope |
| RUI-P03 Save comparison | At the save-UI milestone, review whether already-owned metadata supports choosing the right save before loading. No invented metadata field or save-format change | FUTURE review of UI-SET-076/077 and current save owner; existing save-browser requirements remain mandatory. Any extra comparison layout must be specified before implementation |
| RUI-P04 Contextual teaching | Later evaluate a small sequence around pause, food, resident inspection and zone feedback under UI-SET-072; measure confusion before adding hints | FUTURE tutorial task; no background telemetry, automatic hint engine, new pause trigger or tutorial scope added here |

None of these proposals blocks independent04.5 fixes. P01 is a recorded unresolved
qualification issue, not permission to say the current typography meets XAG101.
No foreign screenshot authorizes a new subsystem, recipe, speed, hotkey, world
layer or save constant. User visual approval remains pending.

## Claude handoff

Read this after the owning amendment. Plan-parser maps RUI-C01–11 into the existing
A-cases; game-coder fixes the applicable existing requirements. User-qa performs
the bounded journey review and inspects native screenshots; test-runner records
actual results. Code-reviewer checks input/data truthfulness and stale-reference
behavior. Keep the existing six-agent models/file ownership from task04.5.

The deliverable is still the task04.5 slice, followed by its planned propagation.
Do not rebuild the interface around a source game's screenshot. Report which
RUI checks passed, failed or remain blocked, and leave RUI-P01–04 clearly proposed.

[Research package validation](rts_ui_validation.json) records document checks only.
The original42-requirement package and its runtime evidence requirements still apply.
