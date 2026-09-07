---DOC:ui_ux_controls.md---

# Redwall RTS — Settlement UI, UX & Controls

**Adopted movement amendment:** [SET-MOVE-001](movement_direction_amendment.md) implements DEC-035 at the direction/specification level. Its requirements supersede ground-only and one-floor claims as the complete settlement design. `settlement_rules_v2` remains the incomplete implementation baseline; MOVE-G01–05 identify exact engineering closure still required.

| Field | Value |
|---|---|
| Document | SET-UX-001, revision 1.1, 2026-09-05 |
| Rules source | `game_gdd.md` revision 1.1 and `setting_rules_amendment.md`; settlement rules v2 |
| Engine | Godot 4.7.2 Control-based UI, Windows primary, Mac development |
| Supported display range |1280×720 through 3840×2160; windowed/borderless/fullscreen |
| Input |Mouse+keyboard; Mac trackpad equivalents; no controller-only release claim |
| Accessibility target |WCAG 2.2 AA contrast/target guidance plus required keyboard/NVDA/VoiceOver qualification flows |
| Units |All layout dimensions below are logical UI pixels unless explicitly called physical pixels |

Every UI element has a unique `UI-SET-nnn` definition in Section 4. Each row explicitly selects a complete style/state profile; inheritance is mandatory, not an invitation to invent missing states. Repeated rows are instances of a definition with stable runtime IDs `UI-SET-nnn/entity_id` or `UI-SET-nnn/catalog_key`. Text/icons inside an atomic element inherit its profile and accessible name; independently focusable children have their own listed definition.

*Rationale: a finite element catalog and shared complete profiles provide exhaustive behavior without contradictory copies of the same button specification.*

## 1. Information Architecture and Screen Zones

### 1.1 Permanent zone map

```text
+--------------------------------------------------------------------------------+
| TOP-LEFT                     TOP-CENTER                      TOP-RIGHT          |
| Food Fuel Wood               Active alerts                   Pause 1x 2x 4x     |
| Stone Residents Beds         Warning / critical              Season Day Menu    |
+----------------------+--------------------------------+------------------------+
|                      |                                |                        |
|                      |      CENTER: GAME WORLD        | Bottom-right detail    |
|                      |                                | grows upward from      |
|                      | Click-through except actual    | bottom safe edge       |
|                      | world labels / ghosts          |                        |
|                      |                                | Title / tabs / data    |
|                      |                                | / policies             |
|                      |                                |                        |
+----------------------+--------------------------------+------------------------+
| BOTTOM-LEFT          | BOTTOM-CENTER                  | BOTTOM-RIGHT           |
| Minimap + layers     | Selection commands             | Context details        |
+----------------------+--------------------------------+------------------------+
```

The resource ledger expands from top-left. Notification history expands from top-center. Time/calendar/menu open from top-right. Build/zone/roster/job/recipe/feast tools open from bottom-center. Entity detail remains bottom-right. Modal dialogs may occupy center temporarily; they are the only ordinary HUD panels allowed to block the full world. This resolves zone ownership for every element in the registry.

### 1.2 Scaling and rectangle equations

Let physical viewport size be W×H. Base scale=`clamp(min(W/1920,H/1080),1,2)`. User scale is 1.00,1.25, or 1.50. Effective scale S=base×user scale; logical viewport Lw=W/S, Lh=H/S. Rendering occurs at physical resolution; UI vertices/text scale by S and final edges round to physical pixels. Do not scale the entire game through a low-resolution pixel viewport. Godot's resolution/stretch facilities support separate UI layout choices; retain crisp fonts and explicit logical layout. [Multiple resolutions](https://docs.godotengine.org/en/4.7/tutorials/rendering/multiple_resolutions.html)

Safe inset 16 logical pixels; grid spacing 8; panel internal padding 12; section gap 16. Breakpoints use logical width:

| Layout | Condition | Minimap width/height | Detail width | Resource width | Top-right width | Alerts |
|---|---|---|---:|---:|---:|---|
| Wide |Lw≥1600 |256×288 |384 |480 |320 |420×96 at y16 |
| Standard |1120≤Lw<1600 |208×240 |336 |360 |304 |360×96 at y16 |
| Narrow |Lw<1120 |160×192 |320 drawer |176 compact summary |256 |min(360, Lw−32)×48 at y76 |

Rectangles: resources `(16,16,R,88)`; time `(Lw−16−T,16,T,88)` (narrow 48 high); alerts `(Lw/2−A/2,alert_y,A,alert_h)`; minimap `(16,Lh−16−Mh,Mw,Mh)`; detail `(Lw−16−D,128,D,Lh−144)`. Detail is hidden until selection and closed by default in narrow layout. Modal frame is centered with width=`min(960,Lw−32)`, height=`min(720,Lh−32)`.

Command strip uses the remaining bottom interval: left=`Mw+32`; right=`Lw−D−32` when detail open, otherwise`Lw−16`; available=right−left; width=min(640, available); x=left+(available−width)/2; y=Lh−152; height 136. Minimum command width 240. At the minimum tested logical width 853.33 (1280 pixels with 1.5× user scale), open-detail available width 309.33, so it still fits. Command buttons wrap into two or three rows; excess commands live in the context quick menu, not outside the viewport.

World click-through rectangle is the viewport minus the **actual visible input rectangles**. A transparent full-screen Control must not block the center. Full-screen HUD roots and decorative graphics use `MOUSE_FILTER_IGNORE`; interactive controls consume `_gui_input` events. World commands use `_unhandled_input`, after UI handling. Visual z-order alone is insufficient to define interaction priority. [Control input/anchors](https://docs.godotengine.org/en/4.7/classes/class_control.html)

At 1280×720 default scale: resources x16..376; alerts x460..820; time x960..1264; minimap x16..224, y464..704; detail x928..1264, y128..704; commands with detail x256..896, y568..704. These rectangles do not overlap. At 1920×1080: wide layout with scale 1. At 3840×2160: wide layout with scale 2 and the same logical 1920×1080 composition. Non 16:9 windows use the equations without letterboxing UI.

Resource/time/minimap frames override profile padding to 8 px; the narrow time row uses 4 px. Standard/wide resources use three columns and two 36-high rows, top y8/y44, horizontal gap 8, counter width `min(144,(R-32)/3)`. Expand-resources control is hidden there because all six counters open the ledger. Standard/wide time has two 36-high rows at y8/y44; row 1 holds Pause and three speed buttons, row 2 date and menu, with 8 px gaps. Alert stack padding is 2; two 44-high cards plus a 4 px gap fit 96. Each card width is `A-40`; its right 36 px rail contains the 32×32 history trigger. Narrow uses one card in 48 px. The history trigger remains visible on its own even with no active card.

### 1.3 Responsive content rules

| Situation | Behavior |
|---|---|
| Narrow resource area |Food-days and population occupy two 104×36 rows at local (8,8) and (8,44); expand button 32×44 at (136,22) opens the complete ledger |
| Narrow time area |One 36-high row: Pause 44 wide, three speed buttons 36 each, calendar 36, menu 36; gaps 4, padding 4, y6. Total width 252 fits the 256-wide cluster. Calendar icon exposes the full date on focus/activation |
| Narrow alerts |One highest-severity active alert plus count; history contains all |
| Narrow detail |Explicit drawer toggle; world remains active outside drawer; commands resize before drawer opens |
| Narrow minimap |144×144 map content; 8 px padding; 32 px header; total 160×192. Standard and wide keep the same padding/header with 192×192 and 240×240 maps |
| Long labels |Wrap to 2 lines within fixed-height cells only if font≥16; otherwise expand row height; never truncate warnings/costs |
| Large text |Scroll panels vertically; fixed bottom confirmation row; no reduced font size fallback |
| Long inventories/rosters |Virtualized rows,44 px base height; screen-reader semantic rows follow the full filtered model |
| Localization overflow |Content grows/scrolls; no auto shorten quantity or critical condition; release 1 English with localization keys |
| Window resize during placement |Recompute UI rectangles/ghost ray at next frame; do not commit placement from stale pointer position |

## 2. Visual Tokens, Typography, and Complete State Profiles

### 2.1 Palette and contrast

All functional panel/text backgrounds are opaque. Decorative shadows may be translucent, but text never relies on a variable game-world background for contrast.

| Token | Hex / alpha | Use |
|---|---|---|
| INK |#14211B /1.00 |Dark text on selected gold; deep background |
| PANEL |#1E3028 /1.00 |Panels and default buttons |
| HOVER |#2B4638 /1.00 |Hovered interactive background |
| PRESSED |#111C17 /1.00 |Pressed interactive background |
| TEXT |#F5F0DF /1.00 |Primary text/icons |
| MUTED |#BECABF /1.00 |Secondary/disabled text and interactive borders |
| GOLD |#E6C77A /1.00 |Selection/focus/positive action |
| SUCCESS |#9DD8AF /1.00 |Success icon + wording |
| WARNING |#FFD28A /1.00 |Warning icon + wording |
| DANGER |#FFB3AD /1.00 |Critical icon + wording |
| SCRIM |#000000 /0.65 |Modal backdrop only; dialog itself opaque |
| SHADOW |#000000 /0.30 |Decorative panel shadow, offset(0,4), blur 12 |

Computed sRGB contrast ratios: TEXT/PANEL 12.20:1; MUTED/PANEL 8.21:1; TEXT/HOVER 9.04:1; MUTED/HOVER 6.09:1; INK/GOLD 10.15:1; GOLD/PANEL 8.49:1; DANGER/PANEL 8.16:1; WARNING/PANEL 9.84:1; SUCCESS/PANEL 8.53:1. These are arithmetic checks of specified solid colors, not screenshot certification. All normal text targets≥4.5:1; large text also targets≥4.5:1 even where 3:1 would qualify; functional icons/boundaries≥3:1. [WCAG text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html), [Non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html)

Font: vendored Noto Sans Regular 400, Medium 500, Semibold 600, Bold 700. Runtime font file paths are`res://ui/fonts/NotoSans-Regular.ttf`,`NotoSans-Medium.ttf`,`NotoSans-SemiBold.ttf`,`NotoSans-Bold.ttf`. No OS font substitution in qualification builds. Body 16/400/TEXT, line height 1.35; label 16/600/TEXT; secondary 14/400/MUTED; panel title 20/600/TEXT; page title 28/700/TEXT; numerical counter 18/600/TEXT with tabular numbers. Minimum rendered font size 14 logical pixels; critical message body 16 minimum. Numeric values use comma-grouped integers and decimal point; time 24-hour; food-days 2 decimals.

*Rationale: warm gold/cream on opaque green preserves the woodland tone while making every displayed quantity readable over snow, water, and foliage.*

### 2.2 Profile definitions

Each registry row selects one profile. This provides font, size weight/color, background opacity/radius, all five interaction states, animation, and accessibility defaults. Row-specific constraints override only the listed size or label; no other override is implicit.

| Profile | Typography | Background / border / radius | Default, hover, pressed, disabled, selected | Animation |
|---|---|---|---|---|
| PANEL |16/400/TEXT; title 20/600 |PANEL 1.0;1 px MUTED;8 px radius |Default static; hover static; pressed static; disabled MUTED text with“Unavailable”reason; selected 2 px GOLD header border |Show alpha 0→1 over 120 ms, linear; hide 80 ms; no animation while scrolling |
| BUTTON |16/600/TEXT |PANEL 1.0;1 px MUTED;6 px |Default PANEL/TEXT; hover HOVER/TEXT; pressed PRESSED/TEXT; disabled PANEL/MUTED+lock icon; selected GOLD/INK+check |Background color 80 ms linear; press scale 1→0.98 over 50 ms, ease out quad; release 80 ms |
| TOGGLE |16/600/TEXT |PANEL 1.0;1 px MUTED;6 px |BUTTON states; selected GOLD/INK+check; disabled selected retains check with MUTED label on PANEL |Color 80 ms linear; check appearance instant |
| ROW |16/400/TEXT; secondary 14/MUTED |PANEL 1.0; bottom 1 px MUTED;0 px |Default PANEL; hover HOVER; pressed PRESSED; disabled PANEL/MUTED+reason; selected GOLD/INK |Color 80 ms linear; rows appear instantly during virtualization |
| FIELD |16/400/TEXT |INK 1.0;1 px MUTED;4 px |Default INK; hover HOVER; pressed/focus INK+2 px GOLD; disabled PANEL/MUTED; selected text GOLD/INK |Border color 80 ms linear; no resize animation |
| READOUT |18/600/TEXT; caption 14/MUTED |PANEL 1.0;0 px;4 px |Default static; hover HOVER only if opens detail; pressed PRESSED only if interactive; disabled MUTED+“Unavailable”; selected 2 px GOLD outline |Value changes instant; optional color flash 120 ms without movement |
| METER |16/500/TEXT |PANEL 1.0;1 px MUTED;4 px |Default fill SUCCESS; hover text tooltip; pressed static unless slider; disabled MUTED fill+reason; selected 2 px GOLD outline |Fill interpolates 100 ms linear for presentation; numeric value immediate |
| NOTICE |16/600/TEXT; body 16/400 |PANEL 1.0;2 px severity token;8 px |Default render icon+word severity; hover HOVER; pressed PRESSED; disabled resolved MUTED; selected 2 px GOLD outline |Show alpha 120 ms linear; hide 80 ms; no automatic bouncing/flashing |
| OVERLAY |16/600/TEXT |Dedicated opaque PANEL label if text; world shape outlined INK then GOLD;0 radius |Default visible only when applicable; hover GOLD outline; pressed static; disabled gray hatch+reason; selected GOLD double outline |Geometry immediate; fade 80 ms unless reduced motion |
| MODAL |16/400/TEXT; title 28/700 |PANEL 1.0 over SCRIM;2 px MUTED;12 px |Default focus-trapped; hover/pressed owned by children; disabled children retain reason; selected title GOLD underline |Dialog alpha 120 ms linear; no zoom; closing 80 ms |

Every interactive element has a 2 px GOLD keyboard focus outline offset 2 px **in addition** to selected state. Default interactive border MUTED contrasts with PANEL 8.21:1. Disabled text is not opacity-dimmed; its≥4.5:1 contrast remains. Interactive minimum hitbox 32×32; ordinary buttons 44 px high; destructive confirm 44×120 minimum. This exceeds WCAG 2.2's24×24 minimum target criterion for ordinary targets, without claiming the entire game is certified. [Target size guidance](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html)

METER values/labels sit on opaque PANEL above an 8 px fill track; light text is never drawn directly on the light SUCCESS fill. Modal body height scrolls independently of its 60 px confirmation footer. The 16 px normal scrollbar is the only pointer-width exception; all scrolling also has wheel, arrow, and PageUp/PageDown alternatives, with a 24 px bar in access mode.

Reduced motion setting makes all alpha, color, scale, and meter transitions instant; no information depends on them. Tooltips wait 350 ms pointer hover or 0 ms keyboard focus, then use 80 ms alpha. No animate-layout on need updates, numbers, or alerts. Animation uses unscaled UI Time and continues while game paused unless reduced motion.

Screen-reader defaults: interactive elements are focusable, have explicit role/name/description, state, value, and logical order; decoration is excluded. Locked controls explain unlock requirements without requiring hover. Non interactive panels use group names, not extra tab stops. “Disabled” is spoken as state and the reason follows. On close, focus returns to the opening control if still present, otherwise the zone's first control.

## 3. HUD Priority, Focus, and Dismissal

| Layer / z | Content | Input/dismissal |
|---:|---|---|
|0 |3D world |World input only after UI declines |
|10 |World selection/placement/zone overlays |Visuals IGNORE; explicit world labels act through world picker |
|20 |Permanent HUD zones |Hit rectangles only |
|30 |Entity detail/ledger/calendar/history |Latest opened receives focus; one expansion per zone |
|40 |Build/recipe/roster/job/feast workspace |Only one primary management workspace open; replaced workspace preserves filters |
|50 |Context quick menu |Outside click closes and consumes that click; Esc closes |
|60 |Tooltip |IGNORE mouse; never trap focus |
|80 |Confirmation/error/modal menu |SCRIM blocks background; focus trap; Esc cancels unless an irreversible operation is already running |
|90 |Victory/collapse |Modal; no auto dismiss; explicit continue/load/menu |
|100 |Accessibility focus outline/announcer |Outline visual only; announcer semantic and not a click block |

Use Canvas Layer ordering and explicit input ownership; do not assume`z_index`alone prevents input from reaching controls below. A single UIPanelRouter owns focus, open workspace, pause-reasons, and dismissal stack.

Escape priority: cancel rebind capture→close quick menu→cancel current placement/zone/room stroke→close top confirmation→close workspace→close detail→clear selection→open game menu. Closing a modal does not also clear selection in the same key press. Enter activates the focused control; Space activates a focused native button/toggle and otherwise pauses the world. Ctrl+Space is global pause outside text entry and rebinding.

Pause-reason set contains PLAYER, MENU, CRITICAL, VICTORY, LOAD. Effective pause is any reason present. Closing the menu removes MENU only. Requested 1×/2×/4×speed is retained separately. Critical alerts auto pause only for first starvation death, first incapacitated resident, settlement collapse, or save error; first low food/fuel warning does not auto pause. Settings permit disabling critical auto pause except collapse/load integrity errors.

## 4. Exhaustive UI Element Registry

Sizes are`minimum→maximum`width×height. Fixed sizes repeat both ends. Container bounds from Section 1 override a maximum only by reducing available height and adding internal vertical scroll; they never reduce font size or hitboxes. `Gate` values: ALWAYS, SELECTED, WORLD_TOOL, WORKSPACE, MODAL, TUTORIAL, M1, M2, M3, CONDITION. A locked M-gated control remains visible in its catalog with the GDD milestone condition; it is hidden from quick commands until unlocked.

### 4.1 Persistent HUD and selection

| Element ID / name | Zone / anchor | Size min→max | Profile | Accessible name/value binding | Show/hide and activation |
|---|---|---|---|---|---|
| UI-SET-001 Resource cluster |TL, left/top |176×88→480×88 |PANEL |“Settlement resources” |ALWAYS; compact composition in narrow |
| UI-SET-002 Food counter |TL, grid cell |104×36→144×40 |READOUT |“Ready food: ”+food_days.to_fixed(2)+“ days; ”+ready_NP+“ nutrition” |ALWAYS; opens food ledger; critical icon<1 day |
| UI-SET-003 Fuel counter |TL, grid cell |104×36→144×40 |READOUT |“Heating fuel: ”+fuel_days+“ days” or no-demand state |ALWAYS except narrow ledger; opens fuel breakdown |
| UI-SET-004 Wood counter |TL, grid cell |104×36→144×40 |READOUT |“Wood: ”+available_U+“ available; ”+reserved_U+“ reserved” |ALWAYS except narrow ledger; opens item lots |
| UI-SET-005 Stone counter |TL, grid cell |104×36→144×40 |READOUT |Same formatter for Stone |Same |
| UI-SET-006 Population counter |TL, grid cell |104×36→144×40 |READOUT |“Residents: ”+living+“ of 256; ”+idle+“ idle” |ALWAYS; opens roster |
| UI-SET-007 Bed counter |TL, grid cell |104×36→144×40 |READOUT |“Beds: ”+used+“ assigned; ”+free+“ free; ”+warm+“ warm” |ALWAYS except narrow ledger; opens housing |
| UI-SET-008 Expand resources |TL, cluster bottom/right |32×32→44×44 |BUTTON |“Open all resources” |ALWAYS; toggle 009 |
| UI-SET-009 Resource ledger |TL, below cluster |320×240→640×640 |PANEL |“Resource ledger” |CONDITION 008; groups ready food, potential food, fuel, materials, seeds; close 093 |
| UI-SET-010 Alert stack |TC, top center |280×48→420×96 |PANEL |“Active settlement alerts” |CONDITION active alerts; empty does not block world |
| UI-SET-011 Alert card |TC, stack row |280×44→420×88 |NOTICE |Severity+message+source+resolution action |CONDITION; click focuses source/detail; acknowledge via history |
| UI-SET-012 Notice history |TC, below alerts |400×280→720×640 |PANEL |“Notification history, ”+filtered_count+“ entries” |CONDITION UI-SET-102 activation; filter 075, rows 011 |
| UI-SET-013 Time cluster |TR, right/top |256×48→320×88 |PANEL |“Time and season” |ALWAYS |
| UI-SET-014 Pause button |TR, time row |44×36→56×44 |TOGGLE |“Pause simulation”/“Resume at ”+requested_speed |ALWAYS; selected when effective paused; reason in description |
| UI-SET-015 Speed 1 |TR, time row |36×36→56×44 |TOGGLE |“Normal speed, one times” |ALWAYS; set requested 1; does not clear other pause reasons |
| UI-SET-016 Speed 2 |TR, time row |36×36→56×44 |TOGGLE |“Double speed” |ALWAYS; same |
| UI-SET-017 Speed 4 |TR, time row |36×36→56×44 |TOGGLE |“Quadruple speed” |ALWAYS; same; overload explanation if limited |
| UI-SET-018 Calendar |TR, below time |240×240→560×600 |PANEL |“Year ”+year+“, ”+season+“, day ”+day+“, ”+hour 24 |CONDITION UI-SET-101 activation; opens 071 forecast |
| UI-SET-019 Menu button |TR, far right |36×36→44×44 |BUTTON |“Game menu” |ALWAYS; opens 078 menu variant; adds MENU |
| UI-SET-020 Minimap frame |BL, left/bottom |160×192→256×288 |PANEL |“Settlement minimap” |ALWAYS; toggle with M; hidden state has restore button 022 |
| UI-SET-021 Minimap view |BL, inside 020 |144×144→240×240 |OVERLAY |“Map. Current focus ”+tile_coordinate+“. Enter to move camera.” |ALWAYS when 020; pointer click pans; keyboard uses 087 world list |
| UI-SET-022 Map layers |BL, minimap header |32×32→44×44 |BUTTON |“Minimap layers and visibility” |ALWAYS; opens layers in 096 |
| UI-SET-023 World surface |CENTER, full viewport |Full remaining viewport |OVERLAY |“Settlement world; use world list for keyboard navigation” |ALWAYS; not a fullscreen UI hit block |
| UI-SET-024 Selection ring |CENTER, entity projected |8×8→512×512 |OVERLAY |Entity name announced by selection, ring excluded |SELECTED; gold solid ring+short health strip if injured |
| UI-SET-025 Box selection |CENTER, pointer drag rect |1×1→Lw×Lh |OVERLAY |“Selecting residents: ”+candidate_count |WORLD_TOOL; INK 2 px outer/GOLD 1 px inner; fill GOLD alpha 0.08 |
| UI-SET-026 Command strip |BC, remaining bottom interval |240×136→640×136 |PANEL |“Commands for ”+selection_summary |ALWAYS; global tools when empty; wrap buttons |
| UI-SET-027 Build command |BC, command cell |44×44→112×44 |BUTTON |“Build exterior structures” |ALWAYS; opens 052 |
| UI-SET-028 Zone command |BC, command cell |44×44→112×44 |BUTTON |“Designate work or conservation zone” |ALWAYS; opens 059 |
| UI-SET-029 Jobs command |BC, command cell |44×44→112×44 |BUTTON |“Set job priorities and schedules” |ALWAYS; opens 070 |
| UI-SET-030 Food command |BC, command cell |44×44→112×44 |BUTTON |“Manage recipes and food orders” |ALWAYS; opens 060 |
| UI-SET-031 Residents command |BC, command cell |44×44→112×44 |BUTTON |“View residents” |ALWAYS; opens roster rows 069 |
| UI-SET-032 Feast command |BC, command cell |44×44→112×44 |BUTTON |“Plan a feast” |M1; opens 063 |
| UI-SET-033 Objectives command |BC, command cell |44×44→112×44 |BUTTON |“Hearth Charter objectives” |ALWAYS; opens progress in 051/071 |
| UI-SET-034 Demolish command |BC, selection cell |44×44→120×44 |BUTTON |“Demolish ”+building_name+“; review evacuation and refund” |SELECTED building; opens confirmation, never immediate destruction |
| UI-SET-035 Upgrade command |BC, selection cell |44×44→120×44 |BUTTON |“Upgrade or repair ”+building_name |SELECTED eligible building; locked reason if missing materials |
| UI-SET-036 Context detail |BR, right/bottom, grows up |320×240→384×936 |PANEL |“Details: ”+entity_or_zone_name |SELECTED; closed by 093; drawer in narrow |
| UI-SET-037 Detail title |BR, top inside 036 |280×32→352×64 |READOUT |Full entity name/status |SELECTED; title 20/600 override; click center-camera |
| UI-SET-038 Detail tabs |BR, below title |280×36→352×72 |TOGGLE |Tab name+“ tab ”+index+“ of ”+count |SELECTED; wrap 2 rows; selected panel one at a time |

### 4.2 Data editors and production workspaces

| Element ID / name | Zone / anchor | Size min→max | Profile | Accessible name/value binding | Show/hide and activation |
|---|---|---|---|---|---|
| UI-SET-039 Need row |BR, needs list |280×44→352×56 |METER |Need name+value/100+“ percent; ”+hourly_change+“ per hour” |SELECTED resident; click explains decay/restoration |
| UI-SET-040 Skill row |BR, skill list |280×44→352×56 |ROW |Skill+level+“; ”+XP+“ of ”+next_XP |SELECTED resident |
| UI-SET-041 Priority cell |BR or BC, job grid |32×32→44×44 |FIELD |Resident+job+priority word;0 means forbidden |WORKSPACE 070/selected resident; click cycles 1,2,3,4,0; Shift click reverse |
| UI-SET-042 Schedule grid |BC, workspace |480×160→896×320 |FIELD |Resident+hour+activity |WORKSPACE;24 columns with horizontal scroll if needed; keyboard arrow/select/paint |
| UI-SET-043 Lot row |BR or TL, inventory list |280×52→896×64 |ROW |Item+available/reserved quantity+quality+effective hours remaining+provenance |SELECTED container/ledger; details never hide age |
| UI-SET-044 Order row |BR or BC, orders list |280×64→896×80 |ROW |Recipe+mode+target+in progress+blocking reason |SELECTED station/WORKSPACE 060; edit 062 |
| UI-SET-045 Fish stock row |BR, habitat detail |280×64→352×88 |METER |Species+stock percent+quota+closure/reopen date |SELECTED habitat; opens risk/quota |
| UI-SET-046 Crop stat row |BR, plot/field detail |280×52→352×72 |ROW |Crop+growth+fertility+moisture+expected yield+harvest date |SELECTED field; warn wrong plant window |
| UI-SET-047 Room row |BR, interior list |280×52→352×80 |ROW |Room type+tiles+capacity+temperature+validity cause |SELECTED managed building; click highlights room |
| UI-SET-048 Relationship row |BR, resident detail |280×44→352×64 |ROW |Other resident+affinity+friend state+last contact |SELECTED resident/social tab |
| UI-SET-049 Danger consent |BR, zone/policy footer |280×64→352×88 |TOGGLE |“Allow dangerous work for ”+resident_or_zone+“; injury chance ”+chance+“ per 10000 cycles” |CONDITION danger≥2 or hazard policy; never prechecked |
| UI-SET-050 Quota slider |BR, stock policy |280×64→352×88 |FIELD |“Harvest quota ”+U+“ units per day; protected floor ”+percent |SELECTED habitat/zone; min 0, max catalog quota; intensive policy separate 100 |
| UI-SET-051 Workspace/modal frame |BC opens CENTER |480×320→960×720 |MODAL |Workspace title |WORKSPACE or MODAL; nonmodal workspace uses no SCRIM/MENU pause unless user chose pause-on-management |
| UI-SET-052 Build catalog |BC, inside 051 |448×240→928×624 |PANEL |“Construction catalog” |WORKSPACE 027; category tabs 038/search 075/cards 053 |
| UI-SET-053 Building card |BC, catalog grid |136×128→208×160 |BUTTON |Building name+cost+footprint+worker/room capacity+unlock |WORKSPACE 052; locked cards inspectable; activate placement 054 |
| UI-SET-054 Placement ghost |CENTER, ground snapped |Footprint projection |OVERLAY |“Place ”+type+“ at tile ”+x+z+“; ”+validity |WORLD_TOOL; valid GOLD solid, invalid DANGER hatched, blocked tiles numbered |
| UI-SET-055 Placement cost strip |BC, above commands |240×80→640×112 |PANEL |Materials available/required+work+adjacency+blockers |WORLD_TOOL; fixed until cancel; values recompute per ghost |
| UI-SET-056 Rotate placement |BC, placement strip |44×44→112×44 |BUTTON |“Rotate placement 90 degrees clockwise” |WORLD_TOOL; R key; Shift+R reverses |
| UI-SET-057 Room tool |BC, selected interior workspace |280×128→640×240 |PANEL |“Designate interior rooms” |SELECTED managed building; types 038/paint 059; invalid cells readable |
| UI-SET-058 Furniture palette |BC, interior workspace |280×160→640×320 |PANEL |“Furniture catalog” |WORLD_TOOL interior; cards 053 with furniture catalog keys |
| UI-SET-059 Zone brush |BC, tool strip |240×112→640×160 |PANEL |“Zone type ”+type+“; brush ”+size+“; selected tiles ”+count |WORLD_TOOL; type 038, size 062; conservation distinct hatch |
| UI-SET-060 Recipe list |BC, inside 051 |448×240→928×624 |PANEL |“Recipes and production” |WORKSPACE 030; category tabs/filter/cards 061 |
| UI-SET-061 Recipe card |BC, list row |280×96→896×128 |ROW |Recipe+inputs+outputs+NP+work+station+unlock |WORKSPACE 060; activate creates/edits order 044 |
| UI-SET-062 Number stepper |BR or BC, owning form |160×44→320×64 |FIELD |Field label+value+minimum+maximum+unit |CONDITION numeric field; minus/plus 32 px hit areas; typed entry; Enter commit |
| UI-SET-063 Feast planner |BC, inside 051 |480×400→960×720 |PANEL |“Plan feast; attendees ”+E+“; reserve after feast ”+food days |M1 WORKSPACE; themes 064; confirm 066; errors visible |
| UI-SET-064 Feast theme picker |BC, feast form |280×64→896×88 |TOGGLE |Theme name+exact main/second/beverage+buff |WORKSPACE 063; only legal fixed themes; no custom recipe guessing |
| UI-SET-065 Reserve override |BC, confirmation footer |280×72→896×96 |TOGGLE |“Allow this feast or immigration despite reserve warning” |CONDITION post action reserves below threshold; default off; expires with dialog |
| UI-SET-066 Confirm |Owning modal/workspace, bottom right |120×44→240×48 |BUTTON |Action verb+affected quantity; “Confirm demolition”for 034 |MODAL/WORKSPACE; disabled while invalid with reason; Enter only when focused |
| UI-SET-067 Cancel |Owning modal/workspace, bottom left |96×44→160×48 |BUTTON |“Cancel ”+operation |MODAL/WORKSPACE; Esc same; no financial effect before commit |
| UI-SET-068 Immigration review |TC alert opens CENTER 051 |480×360→960×720 |PANEL |“Immigration candidates; ”+selected+“ accepted; ”+spare beds+“ spare beds” |CONDITION immigration event;069 rows;065 override;066 commit |
| UI-SET-069 Resident row |BC roster or 068 |280×56→896×72 |ROW |Name/anonymous label+species+role+mood+health+current job |WORKSPACE/SELECTED; click single; Shift multi; double centers world |
| UI-SET-070 Job matrix |BC, inside 051 |480×320→960×720 |PANEL |“Work priorities” |WORKSPACE 029;11 active job columns, omitting reserved index 3; resident rows 069; cells 041; virtualized |
| UI-SET-071 Forecast/chart |TR calendaror BCobjectives |320×240→896×480 |PANEL |Chart title+current value+next change+table alternative |CONDITION forecast/progression; keyboard readable table, not image-only |
| UI-SET-072 Tutorial card |TC, below alerts |280×120→420×192 |NOTICE |“Tutorial: ”+step_title+instruction |TUTORIAL; one card; Next 066/Skip 067; does not intercept world outside card |
| UI-SET-073 Tooltip |Owning zone, pointer/focus adjacent |160×48→360×240 |PANEL |Description associated with owner, not duplicated announcement |CONDITION hover 350 ms/focus 0 ms; clamp inside viewport; IGNORE |
| UI-SET-074 Focus outline |All zones, focused rect |Owner rect+4 px |OVERLAY |Excluded; owner provides semantics |CONDITION keyboard focus; never hidden by selected state |
| UI-SET-075 Search/filter |Owning workspace, top |200×44→640×44 |FIELD |“Search ”+collection_name; result count description |WORKSPACE with list; debounce 150 ms UI-time; Esc first clears text only if text field owns it |

For UI-SET-068/069, an authored admission exception has the explicit readout label “Individual petition” and its catalog description in the selected-row detail. Use 16 px READOUT text, wrapping within the panel and scrolling above the fixed action footer. Show species and exact housing/food consequences. UI-SET-066 action instances use `accept_candidates` (“Accept selected”) and `decline_candidates` (“Decline selected”); both bind only live selected candidate rows. UI-SET-067 closes without deciding. Pending rows expire next midnight under SET-AMEND-001; auto-immigration skips exception rows. Do not present aid, probation or trust controls: those mechanics do not exist. The same resident-row definition in an ordinary roster retains its existing selection behavior.

All content pickers exclude retired hunt zones, hunter huts, hunting gear, game meat and game recipes. Meal descriptions and Orchard feast previews use `nut_roast` and the exact replacement ingredients; meals do not imply hidden leather or prey production. Use SET-AMEND-001 §3 to validate active keys; removed content is not shown as a future unlock.

### 4.3 Menus, accessibility, and uncommon states

| Element ID / name | Zone / anchor | Size min→max | Profile | Accessible name/value binding | Show/hide and activation |
|---|---|---|---|---|---|
| UI-SET-076 Save browser |TR menu opens CENTER 051 |480×320→960×720 |MODAL |“Save and load settlements” |MODAL; Manual/Autosave/Prewinter tabs;077 rows |
| UI-SET-077 Save row |CENTER,076 list |448×64→896×80 |ROW |Settlement+year/season/day+real time time stamp+version+validity |MODAL 076; load requires 066; overwrite confirmation explicit |
| UI-SET-078 Settings/menu |TR opens CENTER 051 |480×320→960×720 |MODAL |“Game menu”or“Settings” |MODAL; Resume, Save, Load, Settings, Main menu, Quit via 066/067/092 templates |
| UI-SET-079 Setting control |CENTER,078 row |280×56→896×80 |FIELD |Setting label+value+effect+restart requirement |MODAL 078; complete field catalog in Section 8 |
| UI-SET-080 Key binding row |CENTER, controls settings |448×48→896×64 |ROW |Action+primary binding+alternate binding+conflict state |MODAL 078; activate 081 |
| UI-SET-081 Rebind capture |CENTER, top modal |320×160→560×240 |MODAL |“Press a new key or mouse button for ”+action+“; Escape cancels” |MODAL; consumes all input except OS reserved keys |
| UI-SET-082 Name editor |BR title opens CENTER |320×200→560×280 |MODAL |“Name this notable resident” |SELECTED resident pin;2–32 characters; invalid unicode controls rejected |
| UI-SET-083 Victory panel |CENTER, z90 |480×360→800×600 |MODAL |“Hearth Charter earned”+summary |CONDITION M4; Continue 066; Save 076; Menu 092 |
| UI-SET-084 Collapse panel |CENTER, z90 |480×320→800×560 |MODAL |“Settlement ended; no living residents remain” |CONDITION collapse; Load 076; New/menus 092 |
| UI-SET-085 Error panel |TC notice or CENTER modal |320×160→720×480 |NOTICE |Error code+plain reason+recovery action |CONDITION save/path/capacity fault; critical integrity use stop modal |
| UI-SET-086 Pause label |TC, below time/alerts |96×32→240×40 |READOUT |“Paused: ”+ordered_pause_reasons |CONDITION paused; not clickable; no empty hit rect |
| UI-SET-087 World access list |BC opens CENTER 051 |480×320→960×720 |PANEL |“World locations and entities” |F6/accessible mode; resident/building/zone/resource/tile categories; keyboard camera/pick/place |
| UI-SET-088 Cycle selection |BC, selection cell |32×32→44×44 |BUTTON |“Next selected resident”/“Previous selected resident” |SELECTED multiple; Tab/Shift Tab in world focus |
| UI-SET-089 Zoom buttons |TR time popover or BL map header |32×32→44×44 |BUTTON |“Zoom in”/“Zoom out” |ALWAYS via map layers; keyboard PageUp/Down |
| UI-SET-090 Pitch slider |TR camera/settings popover |240×56→320×72 |FIELD |“Camera pitch ”+degrees+“ degrees below horizon” |CONDITION camera options; min 35, max 65, step 1 |
| UI-SET-091 Schedule template |BC, schedule form |240×44→360×48 |FIELD |“Schedule template: ”+name |WORKSPACE 042; Day/Night/Flexible; preview before apply |
| UI-SET-092 Back/menu action |Owning menu, bottom left |96×44→240×48 |BUTTON |Explicit action“Back”/“Main menu”/“Quit game”/“New settlement” |MODAL; dirty save warning when leaving world |
| UI-SET-093 Panel close |Owning panel, top right |32×32→44×44 |BUTTON |“Close ”+panel_title |CONDITION panel open; never close unrecoverable LOAD state |
| UI-SET-094 Scroll bar |Owning panel, right/bottom |16×48→24×600 |FIELD |“Scroll ”+panel_title+position percent |CONDITION overflow;24 px in access mode; wheelworks inside owner |
| UI-SET-095 Tab navigation |Owning tab bar |32×32→44×44 |BUTTON |“Next tab”/“Previous tab” |CONDITION overflow tabs; Ctrl+Tab/Shift+Ctrl+Tab |
| UI-SET-096 Context quick menu |Owning zone, next to invoker |200×88→320×480 |PANEL |“Actions for ”+target |CONDITION context; row buttons 066/067 with action labels; outside click consumed |
| UI-SET-097 Relief seed action |BR farm detail or critical food notice |240×44→352×72 |BUTTON |“Request annual relief seeds; arrives next dawn” |CONDITION seed deadlock or help menu; disable if used this year |
| UI-SET-098 Pin resident/item |BR titleor TLledger |32×32→44×44 |TOGGLE |“Pin and name resident”or“Pin resource counter” |SELECTED/ledger; resident pin opens 082; resource pin changes ledger favorites |
| UI-SET-099 Ration reserve |BR food policy |280×64→352×88 |FIELD |“Keep ”+quantity+“ ration units for reserves” |M2; future transfer execution hidden |
| UI-SET-100 Work policy |BR resident/zoneor BC 070 |280×64→896×88 |TOGGLE |Policy name+enabled state+consequence |CONDITION; Auto fallback, Dangerous work, Intensive harvest, Pause production, Auto immigration each has stable instance key |
| UI-SET-101 Date trigger |TR, time row 2; narrow row 1 |36×36→120×44 |READOUT |“Year ”+year+“, ”+season+“, day ”+day+“, ”+hour24+“. Open calendar” |ALWAYS; icon in narrow, text otherwise; activates 018; T shortcut |
| UI-SET-102 History trigger |TC, right rail of 010 |32×32→32×32 |BUTTON |“Notification history; ”+unread_count+“ unread” |ALWAYS, even when no alerts; activates 012; N shortcut |
| UI-SET-103 New settlement |TR/main menu opens CENTER |480×320→960×720 |MODAL |“Create a settlement” |Main menu New settlement action; configuration and initialization below |

UI-SET-103 fields use 079/062/075 templates with fixed keys: `settlement_name` text 2–32 Unicode characters, default “Rowan's Refuge”; `seed` integer 1–2147483647, default 20260905; `architecture` dropdown ABBEY/HOLT/FORTRESS, default ABBEY; `mode` STANDARD/SANDBOX, default STANDARD; `tutorial` bool, default true. Invalid fields disable Create (066) and expose an inline reason. Cancel (067) returns to main menu. Create queues generation; its progress replaces form content; failed generation leaves the form and seed available. The tutorial toggle changes disclosure prompts only. Main menu has New settlement, Continue most recent valid save, Load, Settings, Quit; all use 092 instances. Continue is disabled with “No valid settlement save” when none exists. Generation succeeds into paused world inspection with PLAYER pause; the first Resume starts tick advancement.

No extra unregistered HUD feature is needed for settlement release 1. New interactive features that cannot be expressed by these templates require a new UI-SET ID and complete profile/gate/input definition. Repeated confirm/menu actions use fixed action keys listed in their row; runtime accessible names always contain the action, not“Button.”

## 5. Complete Input Map and Interaction Precedence

All actions below are Godot `InputMap` actions with the exact snake_case IDs. Use physical key positions for WASD/QE movement and logical keys for text editing. Bindings are saved in user settings and validated for conflicts. InputMap supports named actions and attached input events; the input router applies the context rules below. [InputMap API](https://docs.godotengine.org/en/4.7/classes/class_inputmap.html)

| Action / InputMap ID | Mouse / trackpad | Keyboard | Context and result |
|---|---|---|---|
| Pan / camera_pan_left, camera_pan_right, camera_pan_forward, camera_pan_back |Edge scroll; middle drag; Option/Alt+left drag |WASD; arrow keys outside editing/tools |Unscaled camera movement; diagonal normalized |
| Rotate left/right / camera_rotate_left, right |None |Q/E |Hold 90°/s; no yaw limit |
| Zoom in/out / camera_zoom_in, out |Wheel; two-finger vertical scroll over world |PageUp/PageDown |One step changes distance by factor 1.10; UI scroll never zooms world |
| Pitch / camera_pitch_up, down |Alt+middle vertical drag |Alt+PageUp/PageDown |1° increments,35–65° range |
| Select / select_primary |Left click |Enter on focused world-list row |Resident/building/zone/object under cursor |
| Box select / select_box |Left drag from world |World list multi select with Shift+arrows |Threshold 6 logical pixels; residents only |
| Add/toggle / select_toggle |Shift+left click |Shift+Enter on world-list row |Toggles membership without clearing other residents |
| Select visible similar / select_similar |Double left click within 250 ms |Ctrl+Enter on world-list row |Same species residents in current viewport; cap 256 |
| Clear selection / selection_clear |Left click empty ground |Escape at selection dismissal level |No implicit move order |
| Cycle selection / selection_next, previous |UI-SET-088 |Tab/Shift+Tab with world focus |Changes primary selected resident; does not alter group |
| Assign group / group_assign_0..9 |None |Ctrl+0..9 |Store selected resident persistent IDs; ignore buildings |
| Recall group / group_recall_0..9 |None |0..9 |Replace selection with valid living group members |
| Center group / group_center_0..9 |None |Double digit within 300 ms |Recall and center bounding-box centroid |
| Context command / command_context |Right click world |C opens 096 for focused/selected target |Behavior from Section 5.1; never a battle attack |
| Queue commands / command_queue |Shift+right click |Shift+Enter on context action |Append up to 8 manual tasks per resident; needs still preempt |
| Cancel preferred work / command_cancel |Context action |X with world focus |Cancel manual preference/queue; return to normal priorities |
| Pause / time_pause |UI-SET-014 |Space with world focus; Ctrl+Space outside text/rebind |Toggle PLAYER pause reason |
| Speed 1 / time_speed_1 |UI-SET-015 |F1 |Set requested 1× |
| Speed 2 / time_speed_2 |UI-SET-016 |F2 |Set requested 2× |
| Speed 4 / time_speed_4 |UI-SET-017 |F3 |Set requested 4× |
| Build / open_build |UI-SET-027 |B |Open construction catalog |
| Zones / open_zones |UI-SET-028 |Z |Open zone types/brush |
| Safe harvest / open_harvest |Context/zone palette |H |Select FORAGE zone brush, without dangerous consent |
| Jobs / open_jobs |UI-SET-029 |J |Open job matrix |
| Food orders / open_food |UI-SET-030 |K |Open recipes/orders |
| Roster / open_residents |UI-SET-031 |L |Open residents |
| Feast / open_feast |UI-SET-032 |F |Open feast planner if M1; otherwise show requirement |
| Objectives / open_objectives |UI-SET-033 |O |Open Charter conditions |
| Notifications / open_history |Alert stack history control |N |Open notification history |
| Calendar / open_calendar |Date indicator |T |Open seasonal calendar/forecast |
| Minimap toggle / minimap_toggle |UI-SET-022 |M |Hide/show map while preserving restore control |
| Center home / camera_home |Minimap home action |Home |Center central hall; retain yaw/pitch/zoom |
| Follow selected / camera_follow |Detail title context action |End |Toggle following primary resident; manual camera movement cancels follow |
| Roof mode / roof_cycle |Interior palette action |F4 |Cycle AUTO/HIDE_SELECTED/SHOW_ALL |
| Place / placement_commit |Left click valid ghost |Enter in placement context |Queue blueprint at quantized tile/rotation |
| Rotate placement / placement_rotate |UI-SET-056 |R; Shift+R reverse |90° increments; Q/E still rotate camera |
| Repeat placement / placement_repeat |Shift+left click |Shift+Enter |Remain in same catalog item after commit |
| Brush size / brush_smaller, larger |Palette stepper |[ / ] |1/2/4/8-tile brush widths |
| Erase zone / brush_erase |Right drag while zone brush active |Alt+Enter on current tile/rectangle |Removes only current zone-type designation, not buildings/resources |
| Place room/furniture / interior_commit |Left click/drag inside selected building |Arrow tile navigation+Enter |Only valid interior cells; respect partitions/access |
| Demolish / open_demolish |UI-SET-034 |Delete with world focus |Open refund/evacuation review; does not demolish immediately |
| Pin/name / resident_pin |UI-SET-098 |P with resident selected |Open notable/name action; does not pause |
| World accessibility / open_world_list |UI-SET-087 |F6 |Open keyboard-operable locations/entities/tile picker |
| Quicksave / save_quick |Menu |F5 |Write separate quicksave at next tick boundary; allowed while paused |
| Quickload / load_quick |Menu |F9 |Confirmation names save/date; does not load without confirmation |
| Confirm / ui_accept |UI-SET-066 |Enter |Focused valid action only |
| Cancel/back / ui_cancel |UI-SET-067/093 |Escape |Dismiss exactly one layer |
| Next/previous tab / ui_tab_next, previous |Tab selector |Ctrl+Tab/Shift+Ctrl+Tab |Within current panel; not control groups |
| Undo uncommitted stroke / tool_undo |Tool action |Ctrl+Z; Cmd+Z on Mac |Undo current preview stroke only; no historical resource rollback |
| Select all field text / text_select_all |Field context |Ctrl+A; Cmd+A on Mac |Text focus only; never select residents |
| Game menu / open_menu |UI-SET-019 |Escape when dismissal stack empty |Adds MENU pause reason |

Pan bindings are A/Left→camera_pan_left, D/Right→camera_pan_right, W/Up→camera_pan_forward, S/Down→camera_pan_back. Pointer-derived gestures (box selection, double-click, shift-toggle, queue, placement repeat) are semantic actions emitted by the input router after classifying the one pointer event; they must not each execute independently from duplicate raw mouse bindings. Classification precedence is active UI/tool, modifier gesture, drag, double-click, single-click. Single-click selection may happen immediately; a double-click replaces its result, but never issues a second economic command. A right-button down within a zone tool begins erase preview; a release within 6 px cancels the tool instead. Erase commits only on a drag release or keyboard Alt+Enter.

Activating a valid building/furniture catalog card closes the primary workspace and transfers focus to world placement. Escape cancels the ghost and restores the catalog at its previous scroll/selection; successful placement returns world focus, unless repeat placement remains active. Numeric steppers are a single accessible SpinButton with increment/decrement actions; internal glyphs are not extra semantic controls. Menu actions, confirmation actions, and filter options reuse registered templates with stable action keys.

Keyboard shortcuts are suppressed while a text/number field, rebinding capture, or system file dialog owns input, except Escape and that field's documented editing keys. An unbound action remains reachable through UI. No two enabled actions may share a chord in the same context; a binding conflict offers Swap, Unbind previous, or Cancel using modal 066/067/092. OS-reserved shortcuts such as Cmd+Q and Alt+F4 are not captured for gameplay; the application exit path presents an unsaved-progress prompt when the OS permits it.

### 5.1 Right-click decision table

Evaluate the first matching row. A right-click consumed by a tool/UI never reaches this table.

| Selection / target | Result |
|---|---|
| Placement/room/zone tool active |Cancel placement or erase zone as specified; no resident order |
| Resident selected; compatible station |Set 6-hour preferred workplace, provided job kind is permitted and ordinary safety requirements pass |
| Resident selected; harvest zone |Set preferred eligible zone; danger consent still required; no individual wildlife attack |
| Resident selected; injured resident |Offer rescue/treatment only if worker is eligible and supplies/path exist |
| Resident selected; empty reachable ground |Set manual walk-to-cell task with 6-hour expiry; urgently unmet needs preempt it |
| Resident selected; home/bed |Offer assign home/bed or rest; confirm reassignment if another occupant would be displaced |
| Building/zone selected; any target |Open its context quick menu, without issuing resident movement |
| Nothing selected |Open target's inspection context; empty ground offers center camera/designate zone |

Manual queues store up to 8 task descriptors `(kind,target_ref,goal_x,goal_z,issued_tick,expiry_tick)` per resident. They are saved separately from the active JobAgent. Expired/invalid tasks are skipped with a grouped notice; the next valid task resumes after emergency needs. A manual walk does not award job XP or purpose restoration.

### 5.2 Selection feedback and picking

Single selected resident: solid GOLD root ring,1 px INK outer border, small numeric group index, detail panel, command strip. Secondary selected residents: SUCCESS dashed rings with the same group numbering; primary selection has a double ring. Injured selected residents also show a labeled health bar. Species/team distinction never depends on ring color alone.

Picking order: explicit world label→nearest visible resident's screen-space capsule→furniture in selected cutaway interior→building exterior→zone→ground. Ignore hidden roofs/occluded residents unless the accessibility list explicitly selects them. Equal-depth ties use entity ID. A screen-space pick radius is max 6 logical pixels for small residents; nearby ambiguous picks open a short 096 list ordered by distance/ID. Raycasts and projection affect selection only; committed world orders record integer coordinates.

Box selection begins only if pointer-down was unhandled world input. It selects living residents whose projected root lies inside the rectangle; occluded residents inside may be included only when “select occluded residents” setting is enabled(default off). Shift adds/toggles; Ctrl does not begin an unrelated group assignment until a number is pressed. Group recall removes dead/departed/transferred residents and announces remaining count. Selection does not consume animation/simulation RNG.

## 6. Camera Contract

| Property | Exact value |
|---|---|
| Projection |Perspective; vertical FOV 55°; KEEP_HEIGHT |
| Initial orbit |Yaw 45°; pitch 48° below horizon; distance 40 m; target central hall |
| Zoom |Orbit distance 8–120 m; wheel multiplier 1.10/step; PageUp/Down same |
| Yaw |Continuous 360°, stored wrapped 0–360°; hold rotation 90°/real second |
| Pitch |35–65°; initial 48°; keyboard 1°/step |
| Pan speed |`clamp(0.8*distance,8,64)` m/real second; Shift×1.75 |
| Edge-scroll band |12 logical pixels;250 ms dwell; default enabled with mouse, off with trackpad preset |
| Orbit smoothing |`a=1-exp(-12*real_delta)`; interpolate pivot/distance; shortest-arc yaw |
| Reduced motion |Camera smoothing off; movement still continuous and user-controlled |
| Map clamp |Pivot XZ clamped to map bounds inset 2 m; no input accumulation past edge |
| Ground following |Pivot Y samples visual terrain; camera origin≥terrain height+1.5 m |
| Obstacle protection |Sweep 0.5 m camera sphere from pivot to desired camera; shorten orbit to hit distance−0.5 m, minimum 2 m emergency distance |
| Zoom release |When obstacle clears, return toward requested distance using the same smoothing; no instant jump |
| Pause |All camera operations continue on real delta |

If obstacle shortening would violate camera clearance, raise the camera until 1.5 m above terrain, retaining its look-at target; display distance remains requested 8–120 m rather than rewriting the player's zoom setting. This is a view-only safety exception. Edge scrolling is disabled while pointer is over any visible UI hit rectangle, during a modal, text editing, placement drag, or when the application lacks focus.

Drag-pan sensitivity is distance×0.0015 m per physical pixel divided by S, projected onto the ground plane; pointer movement right shifts camera pivot left for grab-and-drag behavior. Keyboard pan follows camera's ground-projected forward/right vectors. Normalize diagonal input. Mouse wheel zoom anchors toward the cursor's ground point by moving pivot 20% of the difference between pre/post zoom ground intersection, then apply map clamp; if ray misses ground, zoom about current pivot.

Use`Camera3D.project_ray_origin(screen_point)` and`project_ray_normal(screen_point)` for view picking and`unproject_position(world_point)` for world labels. The camera remains a presentation service, never an entity-state writer. [Camera 3D API](https://docs.godotengine.org/en/4.7/classes/class_camera3d.html)

Roof AUTO hides only the selected managed building's roof when its interior tab/tool is active. HIDE_SELECTED hides that building's roof regardless of selected tab. SHOW_ALL restores all roofs but interior objects remain accessible through room list. Walls on the camera-facing side of a selected interior hide down to 1 m height; the collision/navigation representation does not change. Roof/wall visual changes complete in 120 ms alpha-dither fade, or instantly under reduced motion.

## 7. Notifications, Forecasts, and Explanation

| Severity | Examples / trigger source | World interruption | Lifetime / dismissal |
|---|---|---|---|
| INFO |Recipe mastered, milestone, arrival completed |No pause; soft optional chime |12 real seconds on HUD; history retained |
| ADVISORY |Idle eligible workers, planting window approaching, low variety |No pause |20 real seconds; acknowledgment hides the card until the condition changes |
| WARNING |Food<2 days, fuel<2 cold-weather days, unreachable jobs, depleted habitat |No default pause |Persist until acknowledged; badge persists until resolved; reannounce only after state clears and recurs |
| CRITICAL |Food<1 day, incapacity, first starvation death, collapse, save integrity failure |Auto pause only the cases in Section 3 |Persist until acknowledged; unresolved critical count always visible; collapse/error requires modal action |

Order active cards by severity descending, then earliest tick, then notice ID. Wide/standard HUD shows at most 2 cards; narrow shows 1 and an unread count. Group multiple residents with the same code into one card listing count and a drill-down roster. History cap 500 evicts oldest resolved INFO first, then oldest resolved higher severity; active conditions remain in the active-condition store even if their historical entries aggregate. Repeated same code/source updates count/last-seen tick without replaying chime.

Each notice includes severity word+icon, title, plain consequence, affected entity/zone, one primary action, and resolved state. Clicking focuses the problem and opens the exact tab; it does not automatically change production policies. “Insufficient flour:2.0 U missing; mill order disabled” is valid. “Production issue” alone is not. Forecast charts have a table alternative with day, expected stock, known consumption, committed production, and uncertain harvest separately. Potential harvest is never drawn as guaranteed ready food.

Screen-reader announcements use one polite queue, maximum one noncritical announcement per 2 real seconds. A new critical condition may interrupt once; subsequent count updates are polite. Pause and selected entity changes announce immediately; meter updates do not announce every frame. Notification volume is separate from world ambience. All sound cues have visible text; no auditory-only deadline.

## 8. Settings, Accessibility, and Non-Mouse Completion

### 8.1 Settings field catalog

Each row is an instance of UI-SET-079 with FIELD typography/state profile and a visible label; controls are toggle, dropdown, stepper, or rebinding row 080 as declared. Settings are applied immediately unless noted. Restoring defaults shows a diff and requires 066.

| Setting key | Control/range | Default | Consequence |
|---|---|---|---|
| display_mode |Dropdown Windowed/Borderless/Fullscreen |Borderless |15-second real-time revert confirmation for video changes |
| resolution |Dropdown supported modes 1280×720–3840×2160 |Desktop mode |Preserve layout;15-second revert if not confirmed |
| ui_scale |Dropdown 100/125/150% |100% |Reflow logical viewport; immediate |
| master_volume |Stepper 0–100, step 5 |80 |All audio |
| effects_volume |Stepper 0–100, step 5 |75 |World/UI effects |
| ambience_volume |Stepper 0–100, step 5 |60 |Wind/water/hearth ambience |
| notice_volume |Stepper 0–100, step 5 |70 |Alert chimes |
| edge_scroll |Toggle |On mouse/Off trackpad preset |12 px band/250 ms dwell |
| pan_sensitivity |Stepper 50–200%, step 10 |100% |Multiplies pan and drag, not zoom |
| zoom_sensitivity |Stepper 50–200%, step 10 |100% |Multiplies logarithmic wheel steps |
| invert_zoom |Toggle |Off |Reverses zoom direction |
| camera_smoothing |Toggle |On |Reduced motion forces Off |
| camera_pitch |Slider 35–65°, step 1 |48° |Same as 090 |
| reduced_motion |Toggle |Off |Disables all nonessential UI/camera smoothing/fades |
| high_contrast |Toggle |Off |Adds 2 px MUTED panel borders,3 px GOLD focus; keeps opaque already-compliant palette |
| select_occluded |Toggle |Off |Box selection may include residents behind objects |
| pause_management |Toggle |Off |Opening primary management workspace adds MENU reason while that workspace is open |
| critical_autopause |Toggle |On |Section 3 critical cases; integrity/collapse cannot be disabled |
| screen_reader_mode |Dropdown Auto/On/Off |Auto |Accessibility tree/labels remain present; mode controls announcer verbosity/world list prompts |
| tooltips |Toggle |On |Keyboard descriptions remain accessible when visual tooltips hidden |
| autosave |Dropdown Daily/Every 3 days/Off |Daily |Retains separate prewinter/protected quicksaves |
| keybindings |List 080 |Section 5 defaults |Conflict checked by input context |

### 8.2 Screen reader and keyboard implementation

Use Godot Control accessibility names/descriptions and ordered focus navigation. Godot integrates screen readers through AccessKit; labels alone do not make a 3D strategy game usable. Verify export behavior with NVDA on Windows and VoiceOver on Mac. A custom-drawn minimap or chart requires an accessible equivalent. [Godot accessibility integration](https://docs.godotengine.org/en/4.7/tutorials/ui/creating_applications.html)

The F6 world list has categories Residents, Buildings, Zones, Resources, and Tiles. Search and distance/category filters are keyboard operable. Enter on an entity selects and centers it; C opens legal context actions. Tiles category offers X/Z integer fields 0–127 and“Use this tile” action. During placement, arrow keys move the ghost one tile, Shift+arrow four tiles; R rotates; Enter validates/commits. During zone room painting, Space marks first corner, arrows move endpoint, Enter commits rectangle; this tool owns Space, so Ctrl+Space remains global pause. Nonrectangular zones can be extended with additional rectangles.

Logical focus order: F6 world access shortcut→resources left-to-right/top-to-bottom→alerts→time controls→minimap controls→commands→detail title/tabs/content. Within modal/workspace: title announcement→search/filter→content→Cancel→Confirm. Focus never moves automatically when stock numbers update. When an inspected entity dies, departs, or is transferred, focus moves to a concise chronicle entry with status and Back, not to a random new entity reusing the slot.

No job matrix requires drag-only editing: arrow keys select cell,0–4 set priority, Enter cycles, Shift+arrows extend selection, typed priority applies to selected cells. Schedules use arrow keys,0 Sleep/1 Anything/2 Work/3 Social, and Apply. Sliders provide equivalent number entry. Recipe order reordering has Move Up/Move Down actions in 096. Minimap navigation has world list/Home/group alternatives. Hover explanations also appear on keyboard focus and in the detail panel.

### 8.3 Explicit UX requirements

| ID | EARS requirement |
|---|---|
| REQ-UX-001 | The UI shall implement every registered element using its complete size, profile, label, gate, and behavior contract. |
| REQ-UX-002 | When an input event is accepted by a visible control or active tool, the UI shall prevent that event from issuing a world command. |
| REQ-UX-003 | While any modal is open, the UI shall trap focus in that modal and prevent background selection/construction changes. |
| REQ-UX-004 | When the viewport or UI scale changes, the UI shall reflow to the defined breakpoint without overlapping active HUD rectangles or shrinking text below 14 logical pixels. |
| REQ-UX-005 | If a requested action is invalid, then the UI shall show the exact reason and required correction before allowing confirmation. |
| REQ-UX-006 | While simulation is paused, the UI shall keep camera, selection, inspection, and command previews operational without advancing gameplay. |
| REQ-UX-007 | When a critical condition changes, the UI shall announce it once, group repeated causes, and preserve unresolved-condition visibility after acknowledgment. |
| REQ-UX-008 | Where reduced motion is enabled, the UI shall remove the specified animations without removing information or changing action timing. |
| REQ-UX-009 | The UI shall expose keyboard-operable alternatives for all required mouse drag, world pick, slider, and reorder actions. |
| REQ-UX-010 | When a control is focused, the UI shall provide an accessible name, role, state, value, and description matching its visible function. |
| REQ-UX-011 | If an operation would discard a save or demolish a structure, then the UI shall show the concrete affected save/building, resource refund, and blocked evacuation before confirmation. |
| REQ-UX-012 | When the player cancels a preview, the UI shall remove only uncommitted preview state and leave inventory/job state unchanged. |
| REQ-UX-013 | When a resident is selected by group or accessible list, the UI shall resolve persistent identity and generation rather than trusting a stale render instance index. |
| REQ-UX-014 | Where future battle/campaign modules are absent, the UI shall hide attack, army, territory, and transfer-execution commands entirely. |
| REQ-UX-015 | When a gameplay unlock is unavailable, the UI shall show its milestone requirements in the relevant catalog without presenting it as an unexplained disabled button. |

## 9. End-to-End Flows and Acceptance Tests

### 9.1 Core flows

**Create food production:**open Food(K)→select recipe→choose eligible kitchen→choose MAINTAIN_STOCK→enter 24 portions→review inputs/work/output space→Confirm→order appears with blocking cause or queued workers. A target of 24 counts committed outputs; repeated clicks do not create duplicate in-flight batches beyond the target.

**Plan a safe fishery:**select habitat→read stock/closure→select gear/species→set quota→assign eligible priority→read numeric risk→explicit danger consent if needed→Confirm. Habitat shows reserved versus used effort; no more fishers can quietly multiply the catch.

**Build a residence:**B→Residence card→ghost→R if needed→read cost/access→left click→blueprint→hauling progress→construction progress→room validity→beds assigned. Invalid door/path placement never commits. Cancel before build refunds delivered goods according to the GDD and shows ground lots.

**Manage an interior:**select hall→Interior tab→roof cutaway→Room tool→paint connected tiles→read capacity/invalidity→place beds/hearth→confirm→assignment updates. Occupants are not deleted when room validity changes. The keyboard tile picker can perform the same flow.

**Hold a feast:**F→theme→attendee/capacity check→exact courses/beverage/fuel→post feast reserves→optional one-event reserve override→Confirm→preparation progress→ready 18:00 service→attendance/benefit report. A missing dessert, seat, or beverage is identified by name and quantity.

**Recover from winter shortage:**critical food card→ready food breakdown→disable feast reservations→enable eligible cooking/hauling→inspect fuel/heat→consolidate housing→watch forecast. UI offers actions; it does not quietly change forbidden jobs or intensive harvest policy.

### 9.2 Acceptance matrix

| Test | Pass criterion |
|---|---|
| UX-T01 Rectangles |At 1280×720,1920×1080,3840×2160 and 100/125/150%user scale, all active HUD rectangles remain inbounds; commands and detail/minimap do not overlap |
| UX-T02 Contrast |Rendered TEXT/MUTED/selected/error states meet 4.5:1; functional outline/icon boundaries meet 3:1 over actual opaque backgrounds |
| UX-T03 Hit targets |All interactive controls≥32×32 except scrollbar width 16, which provides wheel/keyboard alternatives; access mode width 24 |
| UX-T04 World leakage |Click/drag/scroll through 1000 UI interactions issue zero unintended world orders |
| UX-T05 Pause |Camera/selection remain operational for 60 real seconds while all need/job/food age states remain unchanged |
| UX-T06 Selection |10,000 batch/LOD slot migrations preserve inspected resident ID; dead group members cannot select new slot occupants |
| UX-T07 Keyboard |From new game, using keyboard only: construct residence, set porridge order, assign job priority, paint field, plan Hearth feast, save/load |
| UX-T08 Screen readers |Repeat UX-T07 with NVDA and VoiceOver; focus order and dynamic statuses are understandable without visual hover |
| UX-T09 Alerts |Twenty identical shortage causes produce one grouped alert and one chime; acknowledgment does not clear unresolved condition |
| UX-T10 Resize |Resize while placement/feast confirmation is open; no offscreen Confirm/Cancel and no ghost commit from stale position |
| UX-T11 Locked content |Inspect M2 recipe before M2; accessible label states the condition and no order can commit |
| UX-T12 Save safety |Corrupt/incompatible load preserves the file and world; quickload requires named-save confirmation |
| UX-T13 Reduced motion |No animated scale, fade, meter interpolation, or camera easing; all actions and feedback still available |
| UX-T14 Performance |UI update p95≤1.5 ms at 256 residents; virtualized roster/lot lists avoid per frame Node creation |

Document checks passed for unique UI IDs, Markdown structure, and persistent HUD bounds/nonoverlap at all nine combinations of 1280×720, 1920×1080, 3840×2160 with 100%, 125%, and 150% text scaling. Contrast values and layout equations are specification checks. Actual Godot rendering, Windows/Mac input behavior, and assistive-technology completion remain release-validation tasks; this document does not claim those tests have already passed.

## UI-MOVE-001 — required connected-movement controls

Close MOVE-G03 by extending this document's component registry and existing responsive/focus contracts. No new hotkey or final pixel geometry is assigned by the research sketch. Until registered controls and layouts are complete, the UI feature is `SPEC_INCOMPLETE`, not satisfied by an unlabeled layer toggle.

| Required control/content | Binding and behavior to carry into the completed registry |
|---|---|
| Layer/level selection | Ground, canopy, water and underground views; explicit underground level; retain selected identity and a follow action |
| Route inspection | Actual destination with level, ordered movement modes, committed activity, carried load and blocked/wait reason |
| Picking | Select visible active-layer candidates; entity-list selection follows explicit ID to another layer; no accidental selection through a floor |
| Construction preview | Show planned versus finished space, affected access, occupants and edit refusal before commit |
| Cancellation | Acknowledge pending stop/return until authority reaches safe supported state; never imply immediate teleport |
| Accessibility | Domain and route state indicated by text/icon as well as color; keyboard focus and screen-reader labels included |

Canonical state labels for binding are `Planning route`, `Waiting for access`, `Digging`, `Using tunnel`, `Climbing`, `Swimming`, `Diving`, `Returning to air`, `Blocked: no exit`, and `Blocked: load does not fit`. Show each only when the corresponding committed state/reason exists. A closed visual cutaway cannot change discovery or simulation visibility. The existing 1280×720 through 3840×2160 layout range and plain operational wording remain required.
