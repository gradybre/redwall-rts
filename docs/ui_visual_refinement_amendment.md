# UI visual refinement amendment — SET-UX-VIS-002

2026-09-11 · Revision 3 · **Implementation design; first visual sign-off pending.**
Owner: Brendan's request for a high-quality woodland interface, with Astra as
design lead and Claude as implementation lead. Ruleset `settlement_rules_v2`.
This document is incorporated into [UI/controls](ui_ux_controls.md) and supersedes
only the explicitly listed presentation choices. Gameplay, save, movement,
command and accessibility obligations otherwise remain in force.

## 1. Purpose, authority and exact changes

The first shell has a useful theme but does not yet provide the intended visual
quality. [The screenshot review](rulings/2026-09-11_ui_visual_review.md) and the
independent source audit identify both visual shortcomings and functional defects.
This amendment makes the visual work an immediate bounded milestone, not a promise
of unspecified final polish. [Task 04.5](tasks/04_5_ui_visual_refinement.md) executes it.

| Owning UI rule | Explicit change under this amendment | Preserved obligation |
| --- | --- | --- |
| §2.1 all Noto Sans | Noto Serif Semibold 600 for 20 px panel/page-section headings and 28 px page titles; keep Noto Sans everywhere else | All body/number sizes, readable weights and vendored fonts |
| §2.1/2.2 universal dark panel surface | Add opaque JOURNAL variants for resident detail, roster and New Settlement; FOREST remains HUD, tools, notices and menus | Functional text always has a solid known background; contrast and complete states |
| §2.2 gold focus everywhere | JOURNAL uses a 2 px INK focus outline offset 2; FOREST keeps GOLD | Focus is distinct from selection and always visible |
| §2.2 full border on all button profiles | Only the six primary toolbar commands gain TOOL_COMMAND, with no default outline, as defined below | Visible button bounds on hover/selection, complete focus and disabled cues; ordinary form buttons remain outlined |
| §1.2 full-height detail and fixed-height command strip | Detail fits content up to the old available height; toolbar fits its visible rows | Six zones, width formula, safe bounds, 240 px command minimum, scroll/overflow |
| UI-SET-037 clickable title | Full title becomes a semantic heading; its existing center-camera action appears as a labeled Center view button in the same detail component | Same action/target, no new simulation command; stable instance 037/center |
| UI-SET-039 label | Display Fullness; accessible description begins Hunger/fullness | The hunger value is not inverted and no new thresholds exist |
| UI-SET-051 workspace/modal ambiguity | Define separate placement/focus variants in §4 | One workspace, actual input rectangles, pause policy and proper modal trapping |
| Gate versus availability | Define the four-state availability mapping in §3 after gate evaluation | Gates, unlocks and permitted gameplay are not changed |

These are newly authored **presentation** values and layouts. Do not label them
pre-existing GDD constants. No new resource/recipe, species scale, rule, population,
work rate, traversal contract or authoritative data column is adopted. Exact
colors, font identity and structural layouts are required. Revision2 §2.4 raises
the art-finish bar: the original flat references are structural evidence, not
finished visual art. Subsequent changes remain recorded through design review.

## 2. Art direction and theme recipes

**A living community, presented through a keeper's field journal.** The world
occupies the center. Forest-green HUD elements stay compact; resident and
community pages have warm paper surfaces, readable dark ink and editorial
hierarchy. Familiar bowls, timber, bedding and leaves convey ordinary life.
Species identity comes before costume or heraldry. Serious events use direct,
restrained language; a grief notice is never a playful reward animation.

Creative owners remain DEC-018/019, setting bible §14.7 and the content library's
[material/theme synthesis](redwall-content-library/shared/theme_and_material_direction.md).
IMG-04 was directly inspected for practical clothing, kitchen materials and
household activity; IMG-25 for species silhouettes. IMG-03 was inspected in the
preceding brief. These supply direction, not reusable UI art or gameplay buffs.
Do not import the slides' troop counts, recipes or hunting claims. The design's
journal, rule ornaments, generic mouse emblem and hall line study are original
interpretations, not source illustrations or a canonical building plan.

### 2.1 Tokens and fonts

Keep original INK/PANEL/HOVER/PRESSED/TEXT/MUTED/GOLD/SUCCESS/WARNING/DANGER tokens.
Add these only:

| Token | Value | Use |
| --- | --- | --- |
| PAPER | #EAE1C8 | Opaque journal and default journal button |
| PAPER_HOVER | #E0D4B8 | Journal field fill and hovered row/control |
| PAPER_PRESSED | #D3C29E | Pressed journal control |
| PAPER_TEXT | #25372D | Main journal text |
| PAPER_MUTED | #43523F | Secondary and disabled journal text, full opacity |
| PAPER_LINE | #596953 | Functional journal borders and scrollbar thumb |
| SURFACE_EDGE | #708171 | Quiet outer border of noninteractive FOREST panels |
| PAPER_TRACK | #C9C1A9 | Empty need-meter track |
| PAPER_FILL | #466647 | Need-meter fill; value label remains on PAPER |

[contract.json](design/ui_refinement/contract.json) contains the same tokens and
contrast pairs; the package validator checks agreement and actual ratios. PAPER
text/secondary text contrast is at least 4.5:1 against default/hover/pressed
surfaces; borders/focus and fill-to-track contrast at least 3:1. Light severity
tokens are not text colors on PAPER. Embed the standard FOREST notice for a
warning/refusal within a journal, or use dark text plus the relevant symbol.

Runtime heading font: `res://ui/fonts/NotoSerif-SemiBold.ttf`. Reference copy,
licenses, source URLs and hashes are in [the asset manifest](design/ui_refinement/ASSETS.md).
The [official Noto distribution](https://github.com/notofonts/notofonts.github.io/tree/main/fonts/NotoSerif/hinted/ttf)
and [Noto license](https://github.com/notofonts/noto-fonts/blob/main/LICENSE) were
checked for this package. Preserve Noto Sans 400/500/600/700 runtime files. Never
simulate semibold or quietly substitute an OS font. Use actual font metrics.

Typography: 28/600 Serif page title; 20/600 Serif resident and section heading;
16/600 Sans control/need label; 16/400 Sans body; 18/600 Sans counter; 14/400 Sans
secondary/caption. TOOL_COMMAND's stacked caption is the only new 14/600 control
caption exception. Critical message body remains at least 16. Numeric values use
tabular figures. No all-caps body, blackletter, distressed type or textured glyphs.

### 2.2 Complete component styles

Base FOREST profiles still use the original typography, transitions and states.
SURFACE_EDGE replaces MUTED only on a **noninteractive outer panel**; interactive
form/button borders retain MUTED. No nested full outline around every static fact.

| JOURNAL variant | Geometry and base | Hover / pressed / disabled / selected |
| --- | --- | --- |
| PANEL_JOURNAL | PAPER, 1 px PAPER_LINE, radius 8; content inset 20; 1 px binding rule at x+7 | Static surface; children own interactions |
| MODAL_JOURNAL | PAPER, 2 px PAPER_LINE, radius 12; existing SCRIM; content inset 32 | Static surface, children own interactions; full focus trap |
| BUTTON_JOURNAL / TOGGLE_JOURNAL | 16/600 PAPER_TEXT, PAPER, 1 px PAPER_LINE, radius 6 | PAPER_HOVER / PAPER_PRESSED / PAPER with PAPER_MUTED+lock and reason / PANEL with TEXT+check; disabled-selected returns PAPER/PAPER_MUTED and retains check |
| FIELD_JOURNAL | 16/400 PAPER_TEXT, PAPER_HOVER, 1 px PAPER_LINE, radius 4 | PAPER_HOVER / PAPER_PRESSED / PAPER with PAPER_MUTED+reason / text selection PANEL+TEXT |
| ROW_JOURNAL | 16/400 plus 14 secondary, PAPER, bottom 1 px PAPER_LINE, radius 0 | PAPER_HOVER / PAPER_PRESSED / PAPER_MUTED+reason / PANEL+TEXT and check; secondary becomes TEXT on selected |
| READOUT_JOURNAL | Same numerical/caption roles; PAPER; no border unless interactive state needs one | Same surface mappings; selected uses 2 px INK outline |
| METER_JOURNAL | Text on PAPER, track 8 high PAPER_TRACK with PAPER_FILL; rounded radius 4 | Hover explanatory tooltip; disabled track PAPER_LINE+reason; selected/focused distinct INK outline |

JOURNAL focus is a 2 px INK ring offset 2 from the control (4 px total outward
extent). Reserve that clearance before clipping/scroll edges. FOREST remains
2 px GOLD. Selected must include a check; focused+selected shows both. The same
80 ms color/50 ms press/80 ms release behavior from the base profile applies.
Reduced motion and unscaled UI time remain unchanged. No decorative alpha affects
functional text, hit targets, state markers or borders.

TOOL_COMMAND: foreground TEXT (MUTED+12 px lock when unavailable), transparent
within PANEL at rest; HOVER background; PRESSED background; selected GOLD/INK
with 12 px check; focused retains GOLD outline; disabled-selected PANEL/MUTED
with lock+check. Radius 6; target never smaller than 44 high. Wide/standard use
52-high stacked icon/caption, with a 24 px painted icon (revision2 §2.4), 14 px caption and 4 px vertical
insets. Narrow uses 44-high inline 16 px icon and 16 px label. Narrow visible
aliases Build / Zone / Work / Food / People / Goals map respectively to existing
027/028/029/030/031/033 actions; accessible names stay the registry's full names.
Do not globally reduce ordinary controls to 14 px or remove their boundaries.

### 2.3 Asset deliverables and optical checks

The base symbolic family remains original SVG; revision2 §2.4 adds the painted
object and illustrated species variants. Base symbols include: provisions, fuel, wood, stone, residents,
beds, ledger/history, calendar, pause/resume, build, zone, work, food, objectives,
menu, close/cancel, lock, check, warning and center-view. Reuse existing assets
when they pass optical review. Source grid 24×24, optical sizes 16/18/24; source
stroke approximately 1.8 px, adjusted to prevent blur at each displayed size.
Selected/locked state marks use 12 px glyphs within the existing target. No emoji
or icon font is permitted for these actions. Buttons, not glyphs, carry hit areas.

Deliver four generic species emblems for the current founding species: mouse,
mole, otter, squirrel. Mouse needs ears and a projecting muzzle; mole needs its
broad snout; otter its distinct broad muzzle; squirrel its ear/tail silhouette.
Use IMG-25 directly during drawing. These are species identifiers, not individual
portraits. Unknown species use readable text and a neutral identity mark; never
reuse a mouse emblem for every resident. Additional production species follow
when their UI data appears; no new species mechanic is implied.

One original botanical divider and one original menu hall/hearth line illustration
complete this pass. Ornament stays in title margins/illustration gutters and is
removed first when space contracts. No repeating paper texture beneath text,
large wood frames, torn-edge colliders, looping ambient UI or embedded slide text/carousel controls. Direct adaptation
of supplied artwork is authorized under DEC-036.
No paid asset generation is needed or authorized. SVG and font files must have
provenance/license records; UI bitmap references in this package are not runtime
atlases and must not be placed over the game as screenshots.

### 2.4 Visual art finish — revision2

Brendan's visual-appeal clarification adopts the [art-finish specification](design/ui_refinement/visual_art_direction.md)
and its ART-UI-01–12 checks as refinements of UXV-006–012/019/032/040.
This explicitly replaces the flat-reference finish ceiling and symbolic-only
object/emblem delivery with painted object icons, illustrated generic species,
crafted panel edges and distinct component silhouettes. Small functional glyphs
remain symbolic. Wide/standard TOOL_COMMAND icon size changes18→24 logical px;
its52px height,14px caption,4px gap/insets remain. Narrow remains16px/44px.
Illustration pigment is permitted within decorative artwork, not as unreviewed
text/state tokens. Flat opaque text fills, all contrast requirements, fonts,
six-zone geometry and FOREST/JOURNAL role mapping remain unchanged.

The new generated concept is an art candidate and has explicit deviations,
including paper HUD surfaces, enlarged panels and omitted data. It cannot override
the written contract. The earlier four images are retained for structural history.
User visual approval, native rendering and asset qualification remain pending.

### 2.5 Asset generation lock — revision3

[ART-LOCK-001](design/ui_refinement/asset_generation_lock.md) is incorporated for
ART-UI-03–08/11 and UXV-006–012/019:16 asset identities,12 illustration pigments,
225° upper-left light at45° elevation, bounded shadows, always-dark contours with
FOREST-only light keylines, shared framed/clothed three-quarter medallions, and
per-asset24px silhouette tests. Its explicit choices supersede open earlier prose
and conflicting details in the generated concept. These are design-lead-authored
art values, not gameplay constants. Existing UI semantic colors/geometry remain.
DEC-036 explicitly authorizes direct use of supplied images, including IMG-25, for
image-to-image and builds. Purpose-made sheets may be segmented; the full HUD
concept remains non-runtime. No paid quote or final aesthetic verdict is approved.

## 3. Gate, availability and honest copy

Evaluate the owning visibility gate first. A false gate is HIDDEN_BY_GATE: no
layout space, focus/accessibility node or input rectangle. Availability only
applies after the gate is true.

| Availability | Display and interaction |
| --- | --- |
| READY | Operable control; route action through its proper owner |
| GAMEPLAY_LOCKED | Inspectable locked item only where the registry permits it; actual milestone/resource/condition text. Never claim an unbuilt system unlocks through play |
| DEVELOPMENT_UNAVAILABLE | Keep an ALWAYS entry discoverable, but block mutation. On focus/inspection show “Not available in this build.” with a short feature-specific explanation if useful. No store names, task numbers, auto-opened placeholder workspace or fabricated unlocking condition |
| DATA_UNAVAILABLE | Readout “Unavailable” with actual reason (“No settlement loaded.” / “No fuel estimate available.”). Never turn undefined into 0 or plausible sample data |

Locked/unavailable actions may use an inspectable focusable wrapper to expose a
reason while native mutation stays disabled. Inspection is not successful command
execution. A hidden Feast action before M1 stays hidden even if its implementation
exists; a build action defined ALWAYS may remain unavailable. Remove only the
surfaces prohibited by gates, never the whole release feature from the plan.

Player copy uses familiar concepts. Examples: “Paused by you”, “Game menu open”,
“Loading settlement”, “Paused: simulation needs attention”, “Queued — applies when
resumed”, “Zone could not be placed”, “Choose a valid area inside the settlement.”
Use only the applicable real reason/recovery; these examples are not generic text
to conceal errors. Exact error codes remain logged and inspectable. No flavor
notice such as “Mossflower stirs” without an actual owned event. No celebratory
copy over loss, invented kinship, or unverified lore in resident detail.

## 4. Placement, sizing and panel anatomy

All coordinates below are logical UI pixels; apply original S exactly once.
Keep the existing HUD-zone widths, safe inset 16 and breakpoints. Non-16:9 windows
use actual W/H. Source floats here are presentation only. Final transformed edges
round to physical pixels once; use the same transform for input.

### 4.1 Resident journal and command strip

Detail width is inherited (wide384/standard336/narrow320). Its bottom is Lh−16;
height is `min(max(measured_content_height,240), Lh−144)`, so the available
rectangle never changes its right/bottom anchor. Default reference height is
640 for the illustrated content at 1080, and 336 at minimum narrow height480.
Long content scrolls inside the panel, not past the window. Selecting in Narrow
keeps the drawer closed until its explicit toggle; the open reference illustrates
that subsequent state, not auto-opening behavior.

Resident hierarchy: (1) full name, species/age, close control and generic emblem;
(2) health; (3) five needs; (4) current activity and skills; (5) Center view.
Use the reference's 20 px side insets, 16 px section separation, and 52 px need
rows when displaying hourly rates. Header grows to wrap long names; never reduce
name size or overlay Close. Keep the header/close and a 64 px center-action footer
visible; the content body scrolls. Center view is 44 high. A name is a heading,
not a dense concatenation of name/species/health in one line. If additional tabs
are needed, use 038 and its focus contract; this pass need not invent extra tabs.

Command strip uses the original available-width formula and 640 maximum. In the
first six-action state: six columns in wide/standard when they fit; narrow three
columns/two rows. Content inset12, gaps8. Height is
`24 + row_count*button_height + (row_count−1)*8`, capped136. It sits at bottom
Lh−16, no empty second row. Button width divides the usable strip equally; check
actual text fit, and move excess actions to 096 rather than clipping or hiding
them. Where a standard layout lacks room for six captions, use three columns
with the narrow aliases/44-high style. A newly available Feast uses the same
overflow rules; do not shrink targets to squeeze it in.

### 4.2 Workspaces and modals

UI-SET-051 WORKSPACE: resident roster and ordinary management, z40, no SCRIM or
full-screen input block. Width `min(640,Lw−32)`; center on command-strip center,
clamped within safe viewport and avoiding the detail column when open. Bottom
is command-strip top−8; top must be at least128. Height is the lesser of content
height,560 and that available height. If this leaves less than248 pixels, use
the compact modal variant below. Opening focuses search/first operable row;
closing restores opener. Existing pause-on-management preference still owns pause.

Compact roster: centered width `min(640,Lw−32)`, height `min(560,Lh−32)`, JOURNAL,
z80, SCRIM and focus trap. This compact presentation does not invent a MENU pause;
keep the same management pause preference. Header64 and footer60 stay fixed;
rows scroll. Ordinary resident selection never opens either roster variant.

UI-SET-051 MODAL and UI-SET-103: centered up to the owning maximum, SCRIM and
focus trap, safe margins and fixed60 footer. New Settlement target is864×640 at
1920×1080. The form is460 wide with an optional illustration column; when modal
width<800, omit illustration and use one column. All authored fields remain
reachable: name, seed, architecture, mode, tutorial. Name/seed fields44 high;
architecture/mode controls use real availability and selection; defaults/validation
come from UI-SET-103, not the reference's synthetic state. Validation rows grow
inside scrolling content; the footer never leaves view.

Do not show a New Settlement form while roster children remain visible. Never
substitute 087 for roster069. No center placeholder card opens merely because
a selected target has an unavailable tab. An empty valid roster uses one short
message and actual recovery, not a fake resident.

## 5. Data formatting and feedback recipes

- Needs: basis points0–10000 become exact percent with up to two decimals, trimming
  trailing zeroes: 7500→75%, 7501→75.01%, 0→0%, 10000→100%. Health remains0–100,
  e.g.100 / 100. Fullness is satisfaction, not severity; do not fill 25% for7500.
- Per-hour change means per **simulated** hour. Show signed percentage points/hour
  to two decimals; display-only rounding is nearest with ties away from zero.
  −250 need points/hour→−2.50 pp/h. Use the actual effective model context, not
  the baseline formula as a universal answer. If rate isn't published, say Rate
  unavailable; the missing rate remains an unfulfilled binding requirement.
- Skills show current level, exact accumulated XP and next level threshold; the
  reference Keeping3 /45000 of80000 is a synthetic display fixture of existing
  level arithmetic. A max-level row says Max level with its actual XP.
- Resources label units. Food-days retain two decimals and only use ready food.
  Beds distinguish occupied/available/capacity through the owning data definition;
  an unavailable service cannot claim12 legal beds because12 residents exist.
- No selection: close detail. No data: show unavailable. Real empty collection:
  concise no-results state. Initializer failure: preserve form and actual old
  world; do not invent success, residents, collapse or map population.
- Zone intent: draft → queued → committed/refused/canceled. Keep the real pending
  preview while paused and preserve correctable draft on refusal when the command
  owner permits it. Refusal uses the actual cause, symbolic pattern and action.
  A queued action is not a success notice and must not pre-increment stocks.

Reference mockups use synthetic data and a diagrammatic contour backdrop, with
visible labeling. They define hierarchy/material/geometry only. Runtime evidence
must use actual values; no synthetic image is a scene overlay or proof of FP-01.

## 6. Testable requirement registry

All requirements below are mandatory for this bounded refinement. An absent
runtime dependency is BLOCKED with its exact owner, never PASS or silently omitted.
The [CSV](design/ui_refinement/requirements.csv) is the same allocation in machine-readable
form. Acceptance IDs refer to [the test/review matrix](design/ui_refinement/acceptance.md).

| ID | Requirement | Owner | Evidence case |
| --- | --- | --- | --- |
| UXV-001 | Render only the task-04.4 surfaces and their required child templates; the 103-entry registry shall never be expanded wholesale into disabled onscreen panels. | UI registry/04.4 | A01 |
| UXV-002 | Evaluate visibility before availability. Hidden gates create no Control, focus stop, accessibility node or input rectangle. | UI gates/REQ-UX-001 | A02 |
| UXV-003 | Distinguish READY, GAMEPLAY_LOCKED, DEVELOPMENT_UNAVAILABLE and DATA_UNAVAILABLE using the precise rules and copy table in this amendment. | UXV §3 | A02 |
| UXV-004 | Residents shall open the resident roster; F6/access mode alone opens World access. Workspace switching shall remove all outgoing child surfaces and stale focus targets. | UI-SET-031/069/087 | A03 |
| UXV-005 | Use the explicit WORKSPACE and MODAL variants; ordinary selection shall never open a center workspace or opaque empty scaffolding. | UI-SET-051 | A03 |
| UXV-006 | Use a single theme with explicit FOREST and JOURNAL variations and only declared tokens; no per-screen palette or fallback Godot controls. | UI §2 + UXV §2 | A04 |
| UXV-007 | Vendor the specified Noto fonts with licenses; use Serif only for 20/28 px titles, Sans for values, controls and body; never shrink below each role minimum. | UI §2 + UXV §2 | A04 |
| UXV-008 | Every actual text/background state shall reach 4.5:1 and functional icon/border/focus contrast 3:1; disabled text is not opacity-dimmed. | UXV §2 | A04 |
| UXV-009 | Draw one current keyboard focus outline in addition to selection: GOLD on FOREST, INK on JOURNAL. Remove stale outlines immediately on focus exit or hiding. | UI §2/3 | A05 |
| UXV-010 | Implement default, hover, pressed, disabled, selected, focused, selected-focused and disabled-selected; selected state includes a check and correct accessibility state. | UI §2/UXV §2 | A04 |
| UXV-011 | Use original botanical rules, a restrained binding edge and species emblems as specified; decoration shall not overlap text/controls or receive input/accessibility focus. | DEC-018/019 | A06 |
| UXV-012 | Deliver the scoped icon/emblem manifest, optical sizes and license/source hashes. No emoji, missing-glyph squares or unrelated stock icon styles are accepted. | DEC-019/UI §2 | A06 |
| UXV-013 | Compute S once from the actual physical viewport and lay out in W/S by H/S. Keep the six HUD zones and amended content-sized detail/command rectangles. | UI §1.2/UXV §4 | A07 |
| UXV-014 | Narrow detail starts closed on selection, opens only through its drawer action, and leaves commands at least 240 logical pixels wide; overflow stays reachable through 096. | UI-SET-036/096 | A08 |
| UXV-015 | Scale fonts, geometry and actual hit rectangles together; outside visible controls, pointer/trackpad/world selection remains usable at each profile and DPI. | UI §1/3/5 | A05 |
| UXV-016 | Each resource counter shall pair a concise label, exact formatted value and explicit unit. Ready food and potential food stay distinct; undefined is not zero. | UI-SET-001–009 | A09 |
| UXV-017 | Show actual effective pause reasons in player wording, requested speed separately and current date. Use actual pause/menu/calendar glyphs, not unsupported Unicode stand-ins. | UI-SET-013–019/086/101 | A10 |
| UXV-018 | With no active alert, show only History; no empty alert card or invented flavor notice. Real alerts use icon, severity, actual cause and available recovery. | UI-SET-010–012/085/102 | A11 |
| UXV-019 | The journal shall lead with the full persisted display name and actual species/age/status. A generic species emblem is identified as such and never implies a unique portrait or invented biography. | UI-SET-036–038 | A12 |
| UXV-020 | Render five independent need rows with a label, exact percent, 8 px track and current per-simulated-hour change; never expose 7500 as the player-facing 75% value. | UI-SET-039 | A12 |
| UXV-021 | Use Fullness as the visible hunger label, with Hunger/fullness in accessible detail; a larger value means more satisfied. Do not invert or invent mood/risk thresholds. | GDD §5.2/UXV §5 | A12 |
| UXV-022 | Skills include level and current/next-threshold XP; job/role/mood/health use actual fields. Missing values are explicitly unavailable rather than fabricated. | UI-SET-040/069 | A12 |
| UXV-023 | Center view keeps the existing center-camera semantics; pin/rename is resident-specific; zone harvesting policies never appear on a resident merely because a template exists. | UI-SET-037/082/093/098/100 | A12 |
| UXV-024 | Roster rows are left-aligned with an identity line and secondary status, use one separator rather than full boxes around each datum, and remain virtualized with stable selection. | UI-SET-069/075 | A03 |
| UXV-025 | Provide every authored field, label, default and validation rule. One Create button in a large empty frame does not satisfy New Settlement. | UI-SET-103 | A13 |
| UXV-026 | Keep Confirm/Cancel visible, preserve valid input after failure, show validation beside the field and failure at the form, and render actual generation state without simulated progress. | UI-SET-066/067/103 | A14 |
| UXV-027 | Distinguish draft, queued while paused, committed, refused and canceled state by text and shape as well as color; bind it to actual command/result identities. | UI-SET-028/054/059 | A15 |
| UXV-028 | Use action-specific plain reason and actual recovery; keep exact codes in logs/accessibility detail or an inspectable technical detail. Do not blame an engine class/store in the main message. | UI-SET-085 | A11 |
| UXV-029 | Presentation reads committed snapshots. Economic changes use economic commands, speed/pause use scheduler events, and camera/focus/selection remain local view behavior. | ARCH-GODOT-003/UI contract | A16 |
| UXV-030 | An always-visible unbuilt entry shall provide a compact reason on focus/inspection, never an automatically opened full-size unavailable page. Gameplay unlocks remain discoverable in the correct catalog. | UI gates/UXV §3 | A02 |
| UXV-031 | Differentiate no selection, no rows, not initialized, development-unavailable and actual zero. Empty content occupies one purposeful message, not a stretched substitute panel. | UXV §5 | A09 |
| UXV-032 | A 32-character name, long refusal and larger text shall wrap/scroll without clipping, ellipsis on critical content, reduced font size or a covered footer. | UI §1.3 | A08 |
| UXV-033 | Wire actual focus neighbors, opening focus, dismissal priority, modal trap and return focus. Focus-list data without runtime wiring is insufficient. | UI §3/5/UX-T07 | A05 |
| UXV-034 | All controls expose correct role/name/state/value/reason; disabled explanations are keyboard reachable through an inspectable wrapper; decoration is semantically silent. | UI §2/8 | A17 |
| UXV-035 | Use only the inherited short transitions on unscaled UI time; no value-driven layout animation, bounce or urgent flashing. Reduced motion makes all transitions immediate. | UI §2 | A18 |
| UXV-036 | Mark synthetic specimens visibly and in metadata. A specimen can validate component presentation, never a complete initializer, live resident binding or native-world screenshot. | FP-01/FP-12 | A19 |
| UXV-037 | Capture the required native screen matrix with actual physical/logical dimensions, scale, fixture, revision and per-case status; image filenames or requested window sizes do not prove actual dimensions. | UXV acceptance | A20 |
| UXV-038 | Instrument transformed control rectangles, text bounds and hit rectangles: zero unintended overlaps/clipping, zero unreachable overflow actions, and required minimum targets. | UXV acceptance | A07 |
| UXV-039 | Retain bounded dirty updates and virtualization; do not recreate theme/fonts/controls per frame or introduce authoritative scans to fill presentation. Report actual UI timings separately from visual checks. | ARCH-UI-001/REQ-SET-163 | A21 |
| UXV-040 | Complete the structural reference-fidelity checklist and record Brendan's aesthetic verdict separately. Theme compilation and headless success alone never count as visual approval. | UXV acceptance | A22 |
| UXV-041 | Record all intentional profile/geometry changes in this amendment and implementation decisions; preserve old captures and migrate incorrect UI tests with reasons. | AGENTS/UXV §1 | A23 |
| UXV-042 | Deliver owned files, test/evidence links, implemented/blocked requirements and an exact resumable handoff; no private chat is the only source of design intent. | Repository workflow | A23 |

## 7. Completion is evidence, not a theme file

Implement the dependency-ordered task and submit the required actual screenshots,
state traces and visual defect log. Independent technical/player QA verify their
own dimensions; Brendan's aesthetic verdict is a separate field. No numeric
beauty score can compensate for clipped content, incorrect gates or fabricated
state. Theme compilation, passing unit tests and an attractive concept alone do
not establish runtime visual acceptance. Refine the first HUD/detail slice before
propagating a flawed pattern across every other screen.
