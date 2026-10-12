# Evil Genius 2 building study — and a plan for ours

**Status:** research and proposal, 2026-10-11. **Brendan ruled on §6 the same day: see DEC-061 in
`docs/setting_decisions.md`. DEC-061 overrides this document wherever they differ.** In short: match EG2 as closely
as possible; one build panel for all levels; 1 m cells; **the surface becomes painted rooms too** (Q3 (b), which
reverses this study's recommendation); tunnels become painted passages; the entrance is a placed item; access cells on
furniture; room purpose stays permanent; payment stays as the GDD has it (hauled materials). Q6: surface + 4 underground
levels at 5 m spacing. Slice G below must therefore be re-planned around painted surface rooms. The GDD rows DEC-061
supersedes are amended in slice A.

**Brendan's direction, given in chat 2026-10-11** (recorded here as stated; not yet a numbered ruling): look at how
Evil Genius 2 does layered building, building by rooms and building on a grid; and, from EG2's stairs, *"the same
concept should be had with building an entrance on the ground level that lets you begin building underground."*

**Sources.** Brendan's eleven EG2 screenshots (corridor drawing, stairs, the room-type bar, a barracks dug from rock
and furnished); a web research pass over the Evil Genius wiki (read through its MediaWiki API), Rebellion's lair
dev blog (evilgeniusgame.com/en/news/385), patch notes 1.5.0/1.6.0, Rebellion's accessibility page, Steam discussion
threads and reviews (VGC, DSOGaming, TheSixthAxis, GamingTrend). URLs are in §7. Community-wiki and forum claims are
marked *(community)*; my readings are marked *(inferred)*. Our side was mapped from the repository at `f95eecdc`.

---

## 1. How EG2 builds, in one page

**One build mode, one panel.** Build mode (the hammer, one of five top-level modes) opens a single panel with tabs
**Room type · Items · Decor · Loot**. Items/Decor/Loot are greyed out until a room type is chosen ("Select a Room Type
to begin"). The left card explains whatever is selected: picture, one-line purpose, cost per tile or per item, and the
gesture ("Click & drag to draw area", "Click & drag or R to rotate"). A shared footer carries the running
**Total ($, power)**, **Undo/Redo** and one **Confirm all**. A floor bar — **B 1 2 3 4** plus an overview — is always on
screen; PgUp/PgDn change floor.

**Rooms are painted tile types, not objects.** The room-type row is: **Dirt** (fill back in), **Corridor**, Power,
Barracks, Mess, Staff room, Archive, Infirmary, Vault, Control, Training, Lab, Armoury, Prison, Inner Sanctum, Casino.
You drag rectangles (a live "17 × 6" label follows the pointer); each drag adds to a pending batch drawn as blue
ghost walls, with a per-type line in the top-left ledger ("Corridor (+70) $ −700"). Nothing is spent or ordered until
Confirm all. Minimum shape is 2×2 (no 1-wide strips) *(community)*. A room is just "the tiles of type X": you grow it by
painting more, shrink or split it by painting Dirt or another type, and players drop 2×2 corridor patches inside a
vault to host a camera *(community; inferred that rooms are tile types)*.

**Painting a room on rock *is* the dig order.** There is no separate dig step: a barracks drawn on solid rock beside a
corridor is dug out cell by cell from the corridor side once confirmed (screenshot 10: blue blueprint grid, rubble at
the face). Rock tiers gate where you can paint — starting rock, then Soft / Hard / Heavy rock unlocked by research
*(community)*. Gold veins under a painted area are mined as a by-product ($3,000 a tile on the wiki's island data).
Dirt refills space as soft rock, so digging is reversible.

**Walls are generated, never drawn.** Walls appear where dug space meets rock or Dirt. Adjacent different rooms have
no wall between them; a new corridor merges seamlessly into an existing one. Walls facing the camera are cut low.
Lights and fittings are auto-placed; rooms get automatic decoration that wraps around placed items. Doors are *items*
placed on room tiles, with strict flanking rules *(community)*; they are delays, not locks.

**Items are filtered by room and have access tiles.** Inside a barracks, the Items tab lists barracks items only
(bunk bed $500, lockers…). Each item has a footprint plus separate green **activation tiles** where a minion stands
(screenshot 11: green pads either side of a bunk bed), and some need "a wall behind" (bunk beds, the Megasafe). R
rotates by 90°. Decor gives stat auras within 4 tiles instead of a room-quality score. Confirmed items wait as
blueprints; minions fetch them from the helipad depot and assemble them.

**Floors are fixed slices, joined only by stairs.** Each island has 3–4 floors plus a basement (five at most). You can
*view* every floor from the start; you can only *build* where a path exists — an unreachable room paints red. Stairs
are a large **item placed on corridor tiles** ($5,000, research-gated). The ghost shows **X** (never possible),
**!** (blocked/needs research) or **✓**; after placing, a small card asks direction (up/down; the impossible one is
greyed) and confirms **"✓ Connect to Floor 2"**. The stairs join the same pending batch. A stair can't be removed if it
would cut the base off. There are no buildable lifts — players' most common floor complaint *(community)*.

**Construction flow.** Confirm → money spent at once → Workers converge with their multi-tool → dig tile by tile →
put up walls → fetch items from the depot and build them. No player-facing build priority; minions wandering off
half-way is a top criticism *(community)*.

**What players like / dislike** *(community and reviews)*. Liked: flexible, intuitive painting; verticality; the
rock-gating space puzzle; a UI that stays out of the way. Disliked: painting on a "rock ceiling" plane; fiddly item and
door rotation; strict door rules; stairs-only travel; no room move, partial demolition, bulk sell or bulk power
toggle; room sizes hard to read after building; painting over a room *silently sells* its invalid items.

---

## 2. How ours builds today

Three places, none of them a general build mode:

| Where | What the player can do | Grid | Status |
|---|---|---|---|
| **Demo warren** (`godot/demo/tunnel/`, `burrow/`) — the one players use | **B** opens the Dig tool: draw a tunnel as a polyline (≤8 points, 8–64 m), ends snap to junctions or open a 4 m ramp "mouth" automatically. **H/C** place one of two fixed room templates (Burrow home 4 m round, Root cellar 3×4 m), held for review, confirmed with Enter (ADR 1050); an auto-passage joins it. Fit-out by +/− per fixture into fixed slots. Two levels (PgUp/PgDn), ramps and stairs as straight links (**L**). | Polyline in continuous space; rooms on a 0.25 m lattice; 1 m³ cut quanta for cost | Playable; **presentation only** — never reaches the settlement simulation |
| **Modular room planner** (`burrow/modular_*.gd` over `scripts/core/room_*.gd`) | "Plan an underground room" from the Tunnels panel: choose one of the 8 GDD room purposes, draw with Rectangle / Rounded / Oval / Paint+Erase / Tunnel route, 32-step undo, directly on the world's dirt (ADR 1061) | 0.25 m paint cells; 1 m³ cuts; rooms measured in 2 m tiles for GDD minimums | Runs on the real `SettlementSystem` but **Confirm is refused without completed access**; no modular room is ever dug in play. Purpose is permanent (ADR 1081). |
| **Settlement layer** (`godot/scripts/`, the GDD game) | Nothing yet: 30 fixed-footprint prefab buildings on a 128×128 grid of 2 m tiles, rotation 0–3; rooms painted only *inside* hall/residence/infirmary interiors (8 types, ≥ counts per GDD §5.9). | 2 m tiles (surface), 0.5 m nav cells, 1 m³ underground quanta | Stores and arithmetic built and tested; **no build command is dispatched**; build UI rows UI-SET-027/034/035/052–057 are disabled; only the starter colony places buildings. Real first entry (`begin_underground_entry`) exists but nothing in the demo calls it. |

Surface building in the demo is three one-offs (cellar, infirmary, hall upgrade): auto-faced ghosts, no rotation, no
snap. The shared Buildings panel (BLD-PANEL) is approved but unbuilt.

---

## 3. Where we differ — the highlights

1. **One build mode vs three tools.** EG2: one panel, room-type first, one pending batch, one Confirm all, one
   ledger. Ours: the B dig tool, the H/C template tool inside it, and a separate modular planner, each with its own
   confirm; the surface has no build mode at all.
2. **"Paint a room on earth = the dig order" vs "dig, then place a room".** EG2 has no separate excavation for rooms
   — the room *is* the dig. Our warren digs tunnels as one act and places template rooms as another; our modular
   planner already paints on dirt (closest to EG2) but stops at Confirm.
3. **Rooms as tile types vs rooms as shapes/templates.** EG2 rooms are freely resized, merged and split by repainting;
   corridors are just another room type. Ours: two fixed templates (demo) or freehand shapes with a *permanent*
   purpose and canonical-footprint rules (no holes, no pinches) in the planner; tunnels are a different system
   (polylines with bore sizes) rather than a "passage" room type, although the GDD already has `CORRIDOR`.
4. **Generated walls and joins vs authored bores.** EG2 derives walls from the dug/undug boundary and merges same-type
   rooms seamlessly. Ours derives the earth surface from cut quanta (good — same idea), but junction rules (40° minimum
   angle, 1 m pillars, ≤4 bores per junction) come from the polyline model and have no EG2 equivalent.
5. **One grid for rooms and items vs four grids.** EG2 paints rooms and places items on the same tile grid. We use
   0.25 m paint cells, 1 m cut quanta, 2 m GDD tiles for room minimums and furniture, and 0.5 m nav cells. The player
   sees none of this consistently.
6. **Access tiles.** EG2 shows where a minion stands to use each item, and enforces "wall behind". We have none:
   demo fixtures go into fixed slots, and the core catalog says "no invented access offset".
7. **Room-filtered item lists.** EG2's Items tab is filtered to the room under the pointer. Our GDD furniture is
   room-rule-driven (a kitchen needs a bench and hearth) but no UI filters or places it outside the demo templates.
8. **Floors as fixed slices you can always see.** EG2: a floor bar always on screen, every floor viewable, building
   allowed where reachable, red when unreachable. Ours: two demo levels at 4 m (candidate spacing), the engineering pack
   at 5 m, the player level count *not adopted* (MOVE-G01–05 open), and the level picker spec'd but SPEC_INCOMPLETE
   (UI-MOVE-001).
9. **Connectors are items with a "connect to floor N" check.** EG2 stairs are a placed item with ✓/!/X and a
   direction card. Ours are drawn links (ramp 1:2.5, stairs 4:5) chosen with **L** in the dig tool, plus five connector
   families in the core with no player-facing build. **The surface entrance** — Brendan's point — is today an automatic
   side-effect (a tunnel's free end opens a mouth) in the demo, and a fixed stair-top anchor with no player trigger in
   the simulation.
10. **Undo/backfill.** EG2's Dirt makes any dig reversible. We have no backfill (the DIG packet scopes it), no delete,
    no resize, no relocation.
11. **Removal policy.** EG2 silently sells items when you paint over them — a disliked behaviour. Our demolition
    ruling already returns 50% of materials through an explicit review (UI-SET-034 never destroys immediately). Keep
    ours.
12. **Things EG2 lacks that we already have or plan.** Ramps as well as stairs (EG2 players beg for faster floor
    travel); ground types with different dig speed and spoil (EG2 has research tiers instead); spoil as a real good;
    hazards that bracing removes; diggers with skill; words, not colour alone, for every refusal (MOVE-REQ-018).

---

## 4. Things EG2 does that we should not copy

- **Money spent at confirm.** The GDD (REQ-SET-124..128) has materials delivered, then consumed when work starts,
  with 100%/80% cancel refunds. Keep ours.
- **Research-gated rock.** Our ground types already make rock slower and stonier; gating digging behind research
  adds waiting, not a decision. (Open to Brendan.)
- **Silent auto-sell on repaint.** See §3.11.
- **Doors as pure delays and suspicion values** — battle/espionage mechanics with no settlement counterpart.
- **Gold veins.** Our finds (flint, clay, root store, relic) do the same job in the setting; coins are open (Q-D21).
- **Painting on a "rock ceiling" plane** — EG2's most-cited camera complaint. Our cutaway (layer cull + section
  shader) already shows the dug floor; keep painting on the floor plane of the selected level.

---

## 5. The plan (proposal)

Eight slices, in order. Each is a lane with the usual gates (README §3.4–3.7). Slices B–F are underground-first,
because that is where the room-painting model fits and where the code is closest; G brings the surface into the same
panel. Decision ranges are allocated when Brendan approves (check `docs/validation/decision_numbers.py`).

**A — Rulings and contracts (docs only).** Brendan answers §6. Then amend the owning documents:
`docs/ui_ux_controls.md` (one build panel; the always-visible level bar closes part of UI-MOVE-001),
`docs/design/underground-planning/levels-and-connections.md` (entrance and connectors as items),
`furnishing-and-room-use.md` (access tiles), and the GDD/movement amendment rows these touch. No code.

**B — One build panel shell.** Replace the B dig tool's entry, the H/C template tool and the modular planner button
with one panel: tabs **Rooms · Furnish · Decor**, room type first (Furnish/Decor disabled until a room is chosen);
the left card (picture, purpose, cost per cell, gesture); a shared footer with the running ledger (per-type lines,
total wood/stone/work and spoil in natural measures), Undo/Redo and **Confirm all**; the **level bar** (Surface · L1 ·
L2 … · overview) always visible, PgUp/PgDn kept. Builds on the modular planner's draft/undo (ADRs 1052, 1055) and the
existing words-not-colour refusal style. The legacy demo warren stays playable behind it until slice C replaces it.

**C — Paint a room on earth = the dig order.** Rectangle drag with a live size label (in metres and cells), plus the
planner's existing oval/paint/erase. Room types are the 8 GDD purposes, with **Passage** (`CORRIDOR`) as just another
type — tunnels become painted passages (2 cells wide minimum, matching EG2's 2×2 floor and our standard bore).
Validity per cell, shown before confirm: reachable from a finished passage or entrance (else "no way in" — the
planner's existing access refusal, now shown on the ghost instead of at Confirm), GDD minimums, ground the crew can
dig. Confirm all turns every drafted room into excavation sites (`excavation_sites.gd`) dug cell by cell from the
access face, so the player watches the room open outward as in EG2. Requires the UG24 dispatcher (the "next" item in
`underground-integration-status.md`) and composes with HAUL-H3+ for spoil and materials. Cost per cell comes from the
adopted 1 m³ quantum economy (brace/cut/finish), never invented.

**D — Entrance and connectors as items (Brendan's direction).** From the Surface level, the Rooms tab offers
**Entrance** items: burrow mouth (ramp, 1:2.5), hatch with ladder, and stair-head — the five connector families
already in `room_connectors.gd`, subset to what the economy prices. The ghost shows ✓ / ! / X with the reason in words;
placing it opens a small card: direction (down; up greyed on the surface), "✓ Connects to Underground level 1", Cancel.
It joins the pending batch. When built, level 1 becomes paintable from it. The same item family placed on a passage
gives stairs/ramps/ladders between underground levels ("✓ Connects to level 2"). Removal is refused while it is the
only way into anything (EG2's rule; our stranding rule already says the same). This replaces the demo's automatic
tunnel mouths and gives `begin_underground_entry` its player trigger.

**E — Furnish with access tiles.** The Furnish tab lists only the furniture the selected room type uses (GDD §5.9
table: bed, patient bed, seat, kitchen bench, hearth, shelf, decoration, partition, door). Every piece gets an authored
footprint, rotation (R / Shift+R), **access cells** drawn green on the ghost, and an optional **wall-behind** flag.
Authoring the access offsets is a contract change (the catalog currently refuses to invent them) — slice A must adopt
the values. The room's validity line updates live ("Kitchen: needs a hearth"). Placement joins the batch; pieces arrive
as blueprints, are hauled and fitted by the existing install crews.

**F — Repaint, backfill and removal.** Paint **Earth** to fill cells back in (the DIG packet's backfill, using spoil);
repaint to grow or shrink a room; changing a room's purpose remains forbidden unless Brendan reverses ADR 1081. Any
furniture a repaint would invalidate is listed in a review card with its 50% return (demolition ruling) — never sold
silently.

**G — Surface buildings in the same panel.** The surface keeps the GDD's fixed-footprint prefabs (§6 Q3). The
Rooms tab on the Surface level becomes **Buildings**: the BLD-PANEL catalog with thumbnails, ground-snapped ghost on
2 m tiles, R rotation, Shift+click repeat, cost strip, same batch and Confirm all. Interior room painting for
hall/residence/infirmary uses the same Rooms/Furnish tabs. This is the GDD's UI-SET-052–057 delivered through the
shared panel.

**H — Polish from EG2's complaints.** Show a room's size and validity on hover after it is built; jump-to-problem from
any refusal (EG2's Cancel → camera); bulk select/remove; no "crew abandons the build" — keep the existing per-digger
job queues and show who is assigned on the blueprint.

---

## 6. Questions for Brendan (each with a recommendation)

1. **One build panel for everything?** (a) Yes — retire the separate dig tool and template tool once slices B–D land
   *(recommended)*; (b) keep the dig tool for tunnels and add the panel for rooms only.
2. **Underground paint grid.** (a) **1 m cells**, matching the adopted 1 m³ cut quantum, with GDD minimums restated in
   cells (2 m tile = 2×2 cells) *(recommended)*; (b) keep the planner's 0.25 m paint cells; (c) 2 m GDD tiles.
3. **Surface.** (a) Keep fixed prefab buildings on the surface (GDD) and paint rooms only underground and inside
   interiors *(recommended)*; (b) allow EG2-style painted rooms on the surface too (a GDD change).
4. **Tunnels.** (a) Tunnels become painted **Passage** rooms, 2 cells wide minimum *(recommended)*; (b) keep polyline
   tunnels alongside painted rooms.
5. **Entrance.** (a) A placed surface item (mouth/hatch/stair-head) that opens level 1, as in §5 D *(recommended,
   follows your direction)*; (b) the first room you paint creates its own entrance automatically.
6. **Level count and spacing.** Needed to close MOVE-G01/G03: (a) Surface + 4 underground levels at 4 m *(the GDD's
   candidate)*; (b) 5 m as the engineering pack uses; (c) decide later, ship with 2 levels.
7. **Access tiles.** (a) Author access cells and wall-behind for every GDD furniture piece *(recommended)*; (b) no
   access tiles — residents use any adjacent cell.
8. **Room purpose.** (a) Keep it permanent (ADR 1081) — change it by removing and repainting *(recommended)*; (b)
   allow repainting a room's type in place, with a furniture review.

---

## 7. Sources

- Brendan's screenshots, 2026-10-11 (11 frames; not stored in the repository).
- Rebellion, lair-building dev blog: https://evilgeniusgame.com/en/news/385 ; patch 1.5.0:
  https://evilgeniusgame.com/en/news/patch-v1-5-0 ; patch 1.6.0: https://evilgeniusgame.com/en/news/patch-v1-6-0 ;
  accessibility options: https://rebellion.com/accessibility/evil-genius-2-accessibility/
- Evil Genius wiki: https://evilgenius.fandom.com/wiki/Rooms_(EG2) , /Research_(EG2) , /Islands , /Barracks_(EG2) ,
  /Vault , /Control_Room_(EG2) , /Armoury_(EG2) , /Prison , /Power_Station , /Evil_Genius_2 ; EG1:
  https://evilgeniuswiki.com/wiki/Building
- Steam discussions: app 700600 threads 3071992488487379313, 3085508296760599571, 3194740147280279169,
  5190945662886963581, 3071992424993513857, 4520010992001445733 ; guides 2446671699, 2443150183
- Reviews/guides: VGC (videogameschronicle.com, EG2 review), DSOGaming, TheSixthAxis (2021-03-29), GamingTrend,
  GameSpew (moving rooms; stairs), Gamewatcher (stairs), TheGamer (beginner's guide), trekkingwithdennis.com
  (first impressions, door rule).
- Not found anywhere: the tile size in metres, per-room minimum sizes, EG2's demolition refund, wall-cutaway modes,
  build-priority controls.
- Our side: `godot/demo/README.md` (Digging tunnels … Construction theatre), `tunnel_rules.gd`, `room_tool.gd`,
  `modular_editor.gd`, `room_footprint.gd`, `buildings.gd`, `construction.gd`, `ui_availability.gd`, ADRs 0206–0212,
  1050–1061, 1081, 1197, 1217, 1229; `docs/movement_direction_amendment.md`; `docs/ui_ux_controls.md` UI-SET-052–057,
  UI-MOVE-001; `docs/underground-integration-status.md`.
