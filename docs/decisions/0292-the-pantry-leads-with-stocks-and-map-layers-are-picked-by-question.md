# 0292 — The Pantry leads with stocks, and map layers are picked by their question
Date: 2026-09-30 · Status: Accepted

The external review of the live demo found two clarity faults: **F46** (the Pantry gave a full column to recipe
candidates that cannot be cooked, while usable stock was a sentence per ingredient and the stores one joined line)
and **F47** (one V cycle served moisture, ripeness, water and woods, so the player had to remember where in the
cycle they were; and the water view painted only the first selected resident's zones, which misrepresents a mixed
group). UX-009 in the review digest asks for map lenses named by planning question, with a legend and scope.

Numbered 0292: the highest record on this branch was 0222, plus 70, so that branches working in parallel on the
same review do not collide.

## Decision

### 1. The Pantry has two tabs, and Stocks comes first (F46)

`farm_pantry_panel.gd` opens on **Stocks**; **Recipe ideas (not cookable yet)** is its own tab.

- **Stocks** is a table built by `farm_pantry_rows.gd`, one row per **(ingredient, store)**: in store
  (`milli_at`), **incoming** (a harvest on its way, its room reserved -- decision 0222's holds), the store, and
  the next lot to spoil there with its calendar hours (`first_to_spoil_at_into`, the same sum the hourly ageing
  makes). One row per store, not per ingredient, because the review asked for exact endangered lots with their
  location, and a lot's spoil time depends on its store.
- **Soon first.** Food that spoils within **48 game hours** (`SOON_HOURS`, a demo value: two game days) goes first,
  soonest first, worded "Soon" and coloured clay; the rest in catalog order, store by store.
- **The order does not move under the pointer.** It is set when the Pantry opens or Stocks is chosen
  (`rebuild`) and kept while it is open (`extend`): figures change in place, a new row is appended, a row whose
  stock has gone stays reading "0 U". Re-sorting on every refresh (the old code did, every quarter second) would
  move rows as hours tick past the threshold.
- **Stores are rows**: stored, reserved for harvests, free, capacity and how fast each ages food. "Reserved" is the
  room the holds keep, so free = capacity − stored − reserved, exactly what `room_milli_of` lets a harvest have.
- **Empty is not silent.** With nothing stored and nothing incoming, the Pantry names a real source from the beds:
  a ripe bed to harvest, else the bed that ripens soonest (with its hours), else an empty bed to plant, else a lost
  crop to clear -- with an **Open bed N** button that closes the Pantry and opens that bed.
- **Recipe ideas** keeps the content library's dishes, headed "Recipe ideas — not yet cookable" with a note that
  there is no kitchen. Its ingredient list stays in catalog order (it no longer jumps in-stock items to the top).
- **No Orders tab.** Nothing in the demo cooks, processes or orders food; a tab with nothing real in it would be
  the same fault as the recipe column.

To say what is incoming per ingredient, a hold now records its **item** (`farm_pantry.gd _hold_item`, set by
`reserve_near_into`, cleared by `release`); `incoming_milli(item, location)` reads it. Nothing else about holds
changed. Text in the new tables is at least 14 px (UI §2's floor; the farm's `SMALL_PX` is 13 and is left alone).

Rejected: one row per ingredient with a "stores" sub-list (it hides which store's lot spoils first), and a fixed
sort by name (it puts the endangered lot wherever the alphabet does).

### 2. Map layers: one at a time, by question, picked directly (F47, UX-009)

`demo/map_lenses.gd` holds the layers as rows -- group, label, **one question**, a legend (swatches and words), an
optional **subject**, and the switch `show(on)` -- and `active`, the one shown. `select` switches every other off
first, then the chosen one on, so two layers' marks never share the map.

| Layer | Question |
|---|---|
| Growing: Soil moisture | Which beds are too dry or too wet? |
| Growing: Ripeness | Which beds are ready to harvest? |
| Getting there: Water range | Where can they wade, swim, dive or cross? |
| Woods: Zones and trees | Which trees may be felled, which must stay? |
| Underground: Tunnels | What lies under the village? |

- **V** steps the same `active` (`cycle`): off → moisture → ripeness → water range → woods → off. The old step
  counter in `demo_farm.gd` is gone, so V and the picker cannot disagree.
- **Underground is U's.** U already toggles the underground view (`tunnel_control.gd`), so that layer is
  *followed* (`follow_state`): it is off V's cycle, and `sync` adopts what U did -- U on makes it the shown layer
  and switches the others off; U off leaves none. Picking it in the list toggles the view through the same
  `toggle_view`. V from it goes to moisture (and back to the surface).
- **The picker** (`demo/ui/demo_lens_picker.gd`) has a header button naming the shown layer ("Getting there: Water
  range ▾"), which unfolds the list, and **Off**; picking the shown layer again also turns it off. The card shows the
  question, the subject and the legend. The legends reuse the overlays' own colours (farm_look.gd, water_overlay.gd,
  forest_marks.gd); none was invented.

Labels the UX-009 entry names but that have no data here -- "Home & comfort", "Work & supply" -- are not added; the
digest itself says those lenses need their own simulation.

### 3. A mixed group's water range is the group's, member by member

`demo/waterplay/water_range.gd` is the Water range layer's subject. Nobody selected: the 1.0 m mouse anchor, said
as such. One resident: its own zones. **A group: the whole group** -- the zones are painted for its **shortest**
member, because the wade limit scales with height (water_rules.gd), so yellow is exactly the water every member
wades; the notes say by name who swims and who dives ("Swim: all but Badger quarryman. Dive: Otter fisher.").
**◀ ▶** step from the group to each member and back, painting that member's zones with its own wading depth,
swimming and diving. A new selection returns to the whole group; the same selection keeps the member chosen.
`demo_waterplay.gd` repaints the overlay only when the subject's revision moves.

Rejected: painting the first selected (the fault), painting the tallest (its yellow would include water the
shorter members must swim), and painting every member's bands at once (unreadable overlapping zones).

### 4. Where the picker goes

UI §1.1 puts "Minimap + layers" bottom left, and UI-SET-022 (Map layers) belongs with the minimap. The demo's
left column is the party panel's, and at 1280x720 it fills that column with anyone selected (measured: 235–253 px
of the 284 available with one or three selected), so the picker cannot share it without hiding the party panel.
`slot_rect` therefore puts the picker **just right of the party panel's column**, so it can grow upward without
meeting it: **down on the command strip's top** where the space left of the news strip's band is at least the
picker's 340 px (1920x1080, journal closed), else **just above the bottom band** (1280x720, where the band leaves
196 px, and whenever the resident journal pushes the band left). The slot depends on the viewport alone, so the
picker does not jump when a layer with a taller card is picked. The band comes from the news strip's own static
`band_placement` with the journal query (`demo_detail_zone.journal_open`): the picker never calls the strip, whose
`band_in` records the journal state the strip follows. Tests check the whole slot -- every pixel the picker may grow
into, frame included -- is clear of the minimap, the news band, the command strip and the party panel at 1280x720
and 1920x1080 with the journal open and closed, and has room for the tallest card measured (234 px).

Rejected: reserving the foot of the party panel's column (a first version did; at 1280x720 the party panel then
hid itself whenever a group was selected), sitting directly beside the minimap (the tallest card then rose into the
party panel's column at 1920x1080), a button inside the HUD minimap's own header (another group is changing the
minimap), and the top centre (the alerts' zone).

### 5. Review fixes folded in

The independent review found that a stock row kept its store's *index*, so a cellar taken away while the Pantry
was open (its racks out: `refresh_locations`) made the row read another store, or fail out of bounds. Rows now keep
their store's **id**, as lots and holds do, and read "(store gone)" once it has gone. The table is refigured in one
pass over the lots and one over the holds per refresh (it had rescanned every lot per item, store and column). The
picker no longer calls the news strip's `band_in`, which records the journal state the strip follows, and the new
buttons are at least 32 px tall (UI §2).

## Consequences

- `demo_farm.add_overlay(group, label, question, show)` returns the layer's row; callers set legends and subjects on
  `demo_farm.lenses`. `cycle_overlays()` returns the layer's title ("Growing: Soil moisture", "Off").
- Anything that adds a map overlay must add it as a layer, with a question and a legend, or V and the picker will
  not know it exists.
- A store's "reserved" figure is room, not stock: there are still no reservations *of* food (nothing consumes it).
- The Pantry's input handling (modal blocking, Escape, focus) is left to the parallel group G's change; this one
  touches only the Pantry's content and layout.
- Open: the picker's list and buttons do not take keyboard focus (the farm's buttons never do, FarmUi.button); a
  keyboard path to the layers beyond V and U is not built.
- Tests: `godot/test/test_demo_pantry_stocks.gd` (tabs, rows per store, soon first and ties, the order kept while
  open, incoming against stock, a store taken away, the empty state and its button) and
  `godot/test/test_demo_map_lenses.gd` (one layer at a time, V and the picker agreeing, U followed, the subject and
  its stepper, a group painted for all of it, the slot clear of the HUD); `test_demo_farm_ui.gd` and
  `test_demo_conservation.gd` rewritten to the table.
- Mutation testing (87 mutants of the new logic, one at a time in a copy of the tree, each file shasum-checked on
  restore): 86 killed, after tests were added for the 10 that first survived; the 87th was equivalent (the farm
  layers' "clear only my own mode" guard, which `select`'s off-then-on order makes redundant), and the guard was
  removed.

## Source

The external review (`REVIEW.md` F46, F47, P1's Stocks / Pantry, Recipes / orders and Map / layers rows, the pantry
before/after copy), the review digest's UX-009; UI §1.1 (zones), §1.2 (rectangles), §2 (14 px text, 32 px targets),
UI-SET-022; decisions 0196 (the live demo), 0206 (the underground view), 0222 (holds and the calendar forecast).
