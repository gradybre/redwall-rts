# Live demo — a small Mossflower village

A presentation-only demo (decision 0196). It boots the real game — settlement, simulation clock,
HUD, UIManager — and draws a small village of real library assets on top: buildings, trees,
crops and props at game scale, and eight real rigged residents who walk between work spots with
live tail springs (`TailRig`, decision 0194), grounded clips (0193) and stride-matched speed.
The HUD wears a demo-only woodland skin in the visual language of
`docs/design/ui_refinement/visuals/05_woodland_art_concept.png`.

**Movement here is scripted wandering, not the simulation's.** The settlement's movement
system is not built (MOVE gates are open), so the demo cast is presentation-only and does not
feed the simulation. `scenes/main.tscn` is untouched.

## Run it

```
python3 tools/stage_demo_assets.py      # copy and make the library assets (gitignored, ~2.8 GB; the weir's structure too)
godot --path godot demo/demo_village.tscn
```

Without staging it still runs, on placeholder shapes.

## Windows build

`python3 tools/build_demo_windows.py --out <folder>` makes a standalone Windows copy -- a folder
with `RedwallDemo.exe`, its `.pck` and a README, zipped -- that boots straight into this scene
(`docs/ENVIRONMENT.md` has the details and what it needs). Decision 0196 records the choices:

- **Boot.** The export preset (`tools/demo_build/windows_export_preset.cfg`) sets the custom feature
  `demo_build`; `godot/project.godot` overrides the main scene to this one, the window to maximized and
  the title to "Redwall Demo" for that feature only. The editor and every other run still open
  `scenes/main.tscn`. F11 toggles full screen (`demo_window_keys.gd`; Alt+Enter is `brush_erase`).
- **Textures** (`tools/demo_texture_imports.py`, run by staging and by the build): every map a staged
  GLB carries is VRAM-compressed -- S3TC: DXT1 colour and roughness, BC5 normal maps (flagged as
  normal maps), the roughness map capped at its colour map's size with its mipmaps filtered by the
  material's normal map (glTF's green channel) -- the role read from the GLB's material, never the
  file name. Measured at 1920x1080 on the Mac: texture memory 6,216 -> 926 MB, video memory 6,502 ->
  1,115 MB, no visible change in close-ups of a resident, the beds, bark, water and props. The card
  atlases and item icons, which the demo reads itself, stay lossless and are packed as files
  (importer `keep`) and read through `demo_manifest.gd readable_path` -- the project folder's file in
  the project, the packed file in an export. Any other unrecognised image is refused, not guessed at.
  UI art is not touched.
- **Renderer.** Forward+ on Vulkan, Godot 4.7's Windows default, falling back to Direct3D 12 (the
  system runtime) and then native OpenGL (Compatibility). No D3D12 Agility SDK or ANGLE libraries
  ship: Godot's templates do not carry them, so OpenGL is the dependable fallback.
- **Stalls.** A frame long enough to put the clock a quarter second behind at 1x makes it hold its
  REQ-SET-008 diagnostic (CRITICAL) pause; `ui/demo_stall_banner.gd` shows "The simulation paused after
  a stall" with Resume (Enter or Space), which calls `GameManager.acknowledge_overload()`. It never
  resumes by itself. To keep such frames away (the playtest's recurring overloads, decision 0205),
  `demo_prewarm.gd` loads at boot what would first load mid-game -- every staged prop and icon, every
  plant's card atlases, the woods' stumps, saplings and tree splits (about 0.13 s on the Mac, timed in
  its `report`) -- and the clock starts only once the first three frames are drawn, and then two frames
  of the underground view with a sample of everything it can show (decision 0206), two of the canopy's
  fade and the selected residents' silhouette, and two of the frost and snow overlay on the village
  (decision 0301), so a first fade, a first selection under a crown and a first frost cost no compile. While the banner
  is up it is the one overload surface (the HUD's CLOCK_OVERLOADED card is withheld); Resume resolves
  the notice, and a 2x/4x step-down warning (no pause) is resolved once the clock has run 10 s quiet.

## Time

The demo opens running: `Game` starts the real clock and UIManager holds UI-SET-103's opening
inspection pause, which the demo releases once, after its first three frames are drawn (the prewarm). From then on the HUD's pause and
1x / 2x / 4x buttons (and Space) are the game's own, and the whole village follows them through one
presentation clock (`demo_clock.gd`): residents' walking, turning and work, digging and walking
tunnels, the mound over a digger and every resident's clip. Paused, everyone holds their pose;
at 2x and 4x they move and dig two and four times as fast. The camera, the HUD, the demo party
panel and the selection and order marks stay on real time, so the player can still select, order
and dig while paused -- the orders are carried out on resume.

## One village: one calendar, one weather, one water, one feed

The farm and the tunnel works were built apart; in the demo they are one village (the woods too), sharing four things
that `demo_village.gd` makes once (`demo_services.gd`) and hands to both:

- **One calendar** (`demo_calendar.gd`). Farm time, the weather's hour and the **date the HUD shows**
  are one tick counter on the real offset calendar, run on the demo clock at a game hour every 2.5 demo
  seconds (a day a minute at 1x) -- the one demo compression, applied to all three. The farm's model
  advances it; the HUD's date trigger prints its day (`ui/demo_hud_date.gd`, through the shell's
  public `set_status_line`, so the settlement's own clock runs on apart, unwritten) -- "Spring 3": the
  trigger's 88 px hold no hour, so its tooltip carries the full `Y1 Spring 3, 14:00` -- and the farm
  panel's clock line and every notice's stamp are that same date, e.g. `Y1 Spring 3, 14:00`.
- **One weather** (`weather/demo_weather.gd`). The authority is the farm's REAL §5.10 weather row
  (`scripts/core/weather.gd` in the farm's private `crop_weather.gd` stage): the season baselines, the
  forced first-spring Ideal spell and one seeded event a season. Each day's rain wets the beds at the
  day's start. On screen, ordinary rain comes in **spells** of three days (decision 0205: fewer, longer
  spells): a spell's rain all falls on its wet day -- spring 2, 5, 8 and 11 (every season the same) --
  as `rain / 200` whole hours centred on 15:00 (spring's 3 x 1200 is 06:00-23:59), and its other two
  days are dry; a downpour (a day's figure of 2000 or more, §5.10's heavy rain) falls on its own day.
  So over a spell the rain that slows walkers is the rain that wets the beds. Frost nights (the farm's
  demo overlay) read as frost. Rain slows surface walking to 80%, snow to 60%, frost to 85%; tunnels
  are not slowed, so walkers take them in bad weather. Rain and snow fall; a shower dims the light by
  a quarter and adds a little haze (the streaks say it rains -- no grey fog). Frost and snow LIE ON
  THINGS (decision 0301, review F42 -- they were a 60 m white sheet following the camera, over the water
  as well): the ground's and the bank film's own shaders take the cover in world space, so it has no
  edge, on what faces up, thinner on the worn paths, never at or below the water line; the village's
  buildings and props wear a cover overlay (roofs, lids, the tops of stones) while any lies. The water
  never whitens. Snow lies fully, frost patchily at about half (`weather/weather_view.gd` COVER).
- **One water adapter** (`village_water.gd`, `demo_village.water()`) over the real water map
  (`water/water_map.gd`, see Water): the farm's water-edge query (irrigation: dry ground within 2.5 m
  of the waterline), the tunnels' wet ground (within 4.5 m), their flood (the stream spills over the
  ford's west bank, 8.2 m into the village) and their routes (no bore passes within half a bore of
  water: "a tunnel cannot pass under the stream or the pond"). The three reaches are demo values,
  each the one the placeholder it replaced used; the placeholders -- the farm's reed pond and the
  tunnels' stream table and flood sheet -- are gone.
- **One notice feed** (`demo_notices.gd`, 128 entries since decision 0331). Every farm warning, weather change,
  tunnel happening, threat and crew report is posted there with its date; the newest show bottom centre as
  **Village news (demo)** (`ui/demo_news_strip.gd`: notes 12 s, warnings 30 s of *unpaused* time --
  the news clock, `demo_news_clock.gd`, stands still while paused -- warnings worded and in clay), and the
  tunnels' own latest stay in their panel (the farm's bed panel shows only its bed: decision 0205). Nothing in the demo raises a HUD alert card
  any more: the HUD shows the two earliest unresolved notices, and demo lines, which nothing resolves,
  held both cards for good. A toast is only the transient view; see **Village news** below.

## Village news: the history, incidents and the top-centre card (decision 0331)

- **The history** (`ui/demo_news_history.gd`): every kept entry, newest first, "date · place · Warning: text",
  filtered by place (*All*, *Farm*, *Woods*, *Tunnels*, *Water*, *Village* -- weather, threats and the crew's
  reports; the first place picked shows it alone, more add to it) and by severity (*All*, *Warnings*, *Notes*).
  An entry about a bed, tree, tunnel, resident or bridge has **Go to**: it selects the target as a click would,
  brings its panel and eases the camera over it (`ui/demo_news_jump.gd`), closing the window. Above the
  history, **Needs attention** lists every open or pinned incident ("No active problems" erases nothing below).
  Open it with **N**, the HUD's own history trigger (the window stands in for the shell's history in the
  top-centre zone; *Settlement notices* in its header opens the shell's), the news strip's button or the
  card's *All news*. Esc or × closes it. It draws the newest 40 rows; *Show older* draws 40 more. When the feed
  is full the oldest entry goes -- but never an open or pinned incident's newest entry.
- **Incidents** (`demo_incidents.gd`): a warning that stays true until dealt with -- a waterlogged or dry bed,
  a worn-out bed, blight, tonight's frost, a farm job nobody could reach, a full store, a flooded or collapsed
  tunnel, a blown-down tree, no bed, a threat, a resident in difficulty. Each is *Needs a decision*,
  *Assigned* (a Drain, Water, Clear, haul or pump job is on it; a rescuer is on the way), *Recovering* (a bed
  back in band waiting to be sure; a victim being brought ashore) or *Resolved*. A repeat while open merges
  into the same card, counted "(×3)"; a recurrence after it resolved reopens it, counted, and announces again.
  The strip counts the open ones ("2 need attention") until they resolve; *Dismiss* on a routine one (a worn-out
  bed left fallow) stops it asking, while a dismissed warning still counts until it resolves.
- **The card** (`ui/demo_incident_cards.gd`): critical incidents (a threat, a resident in difficulty) queue at
  the top centre under the HUD's alert zone, ONE card drawn with "1 of 3"; *Pin* puts any incident at the front
  and keeps it there, resolved or not; *Snooze 2 min* (unpaused time) and *Dismiss* step to the next.
  A resolved critical card says so for 6 s, then goes. Warnings and routine incidents stay in the history.
- **The farm re-alerts** (review F37): a bed waterlogged, drained and waterlogged again in the same season is
  warned of again -- once it had stayed back in its band for 2 farm hours (`farm_alerts.gd` STANDING
  CONDITIONS); back within those 2 hours it is the same occurrence, said once. Dry and worn out alike.
- **The sound hook**: `demo_incidents.gd` emits `incident_cue(cue, serial, severity)` when a critical
  incident is raised or recurs and when any incident resolves, never for a merged repeat.

**One stores** (`demo_services.gd` `stores`, `tunnel/tunnel_stores.gd`): the village's wood, stone, planks,
finds and water (the kitchen's butt by the well, 40 U at most; decision 0381). The woods put their wood in and saw
their planks from it; the tunnels' bracing and lanterns are paid from it; the kitchen burns 0.1 U of its wood a batch. The top bar's Wood, Stone and Planks are these figures (below); the settlement
simulation's own stock is never written.

**The right column holds one demo panel at a time** (`ui/demo_detail_zone.gd`): a tab strip, *Farm*,
*Tunnels* (& burrows), *Woods* and *Water*, and a "×" that folds the column away (a panel's own "×"
does too; a tab, or clicking a bed, a tunnel or a tree, opens it again), over the HUD's detail zone. Clicking a bed brings the farm's
panel; selecting a tunnel or laying a route brings the tunnels'; clicking a tree, a zone or giving a woods
order brings the woods'; a swim, dive or bridge order, or clicking a bridge site, brings the water's; the
tabs switch by hand; all hide while the resident journal is open.

## The HUD

The action bar's commands each have a hover tooltip -- what it does and its key, read from the input
map (`ui/demo_command_tips.gd`); an enabled command answers its key. In the demo, N and the history
trigger open the **Village news** window (see above); the shell's own notification history, which has its
own "×" (Esc closes it), is reached from that window's *Settlement notices*. The Pantry draws above the HUD, so its "×" is reachable at
1280x720. The Map layer picker sits bottom left (see Map layers). The Village news strip is centred on the action bar and follows it.

**Pop-ups own the input** (decision 0261, `ui/demo_input_gate.gd`). The Pantry, the game menu and the Demo Lab
are modals: a light scrim covers the world and the HUD, so no click, drag or wheel outside the frame reaches
them, and no world or HUD key works behind them (focus keys, Enter, Space, F11 and key releases pass). Focus
lands inside (the Pantry's first ingredient; its "×" is last), Tab and Shift+Tab stay inside, and Esc -- or
its own key, K for the Pantry, F8 for the Lab -- closes it and puts focus back where it was. That Esc does
not also clear the selection. The notification history is not a modal (UI §3 layer 30): a click on it never
reaches the world, and the world stays live beside it.

**The game menu** (`ui/demo_menu.gd`): the HUD's Menu button ("≡"), or Esc when nothing else is left to
close, opens it -- Resume, Restart demo…, Controls (the keys below), Settings, Demo Lab and Quit… -- with the
line that **the demo can't save yet**. Restart and Quit ask first and say again that the village will be lost.
Opening it holds the clock's MENU pause reason and closing releases only that, so the village comes back at
the speed it had (and a pause of your own stays). Settings holds only what works: the interface scale
(100 / 125 / 150 %, the HUD and every demo panel together; a size the window cannot show at 720 logical rows
is disabled and says so -- at 1280x720 only 100 %), full screen, and the sound's volumes, mutes and mixes
(see "Sound" below). The Menu button no longer opens the New Settlement form: its Create would discard the settlement the demo runs on.

**The Demo Lab** (`ui/demo_lab.gd`, F8, or the menu's "Demo Lab"): the demo's test triggers, and only here --
Next weather (the one calendar runs on to the next change of weather, at most 48 h), Test event (the tunnels'
next seeded threat now), Storm gust (through the woods) and Cramp (every selected resident swimming tires at
once; disabled with no swimmer selected). They are the same actions the panels' "(demo)" buttons were; the
Tunnels, Woods and Water panels now hold only the village's own choices.

**Keyboard focus** (decision 0261). The demo's panel buttons -- the right column's tabs and "×", the Farm,
Pantry, Tunnels (rooms and fit-out too), Woods and Water panels, and the party panel's Dig and room buttons --
take keyboard focus and wear the HUD's brass focus ring while they have it (a click's focus is not drawn).

| Key | Does |
|---|---|
| F7 | Move focus: world -> the right column (its first tab) -> the left column (the party panel) -> world |
| Tab / Shift+Tab | Next / previous button where the focus is (in a pop-up: its buttons only) |
| Enter / Space | Press the focused button. Only the keyboard's focus takes them: after a click, Enter still digs the piece the Dig tool has laid, Space still pauses and the arrows still pan the camera |
| Esc | With focus in a panel: back to the world. Otherwise the pop-up, tool or selection ladder below, then the game menu |

**The top bar tells the village's truth** (decision 0251, review group E). One read model
(`ui/demo_hud_model.gd`, painted by `ui/demo_hud_counters.gd`) gives every cell exactly one owner, the
same object its panel reads, and writes nothing into the settlement simulation:

| Cell | Figure | Owner (and where else it shows) |
|---|---|---|
| Ready food | days of meals, one decimal, floored (`2.5 days`; decision 0381) | the kitchen: portions held plus the portions the stores' grain and roots would cook, over the portions the village eats a day; the ledger adds one line of the stock behind it, the portions, grain and roots (the Pantry's Kitchen tab, K) |
| Planks (Fuel's slot) | U, one decimal | the village stores (Tunnels, Woods, Water panels) |
| Wood / Stone | U, one decimal | the village stores (the same panels) |
| Residents | count | the cast (the Residents roster) |
| Beds | count | beds installed in dug burrow homes (the Tunnels panel's housing line) |

The village keeps no fuel, so Fuel's slot shows Planks. Clicking any cell opens the ledger, which lists
the same six figures and where each is. A figure whose owner is missing reads **Unavailable**, never 0.
UIManager still repaints the cells with the settlement's figures when the simulation's stock changes;
the demo paints its own back the next frame.

**Residents (L)** lists the cast, one row per resident: name, species and trade, where it is (on the
surface, in the water, indoors, or underground and on which level), what it is doing (the party panel's
own words) and the saved work it will go back to. Clicking a row selects that resident, so the Demo party
panel shows it, centres the camera on it and closes the roster (`ui/demo_roster.gd`).

**The minimap draws the village** (`ui/demo_minimap.gd`), north up: paths, buildings, crop beds, the
stream and pond, standing trees, dug tunnels and their mouths, burrow homes, root cellars and bridges,
with the camera's view as a pale frame and each resident as a dot in its party-panel colour (hollow while
underground, ringed when selected). Click or drag on it to move the camera. The base is redrawn only when
the tunnels, bridges or woods change; the frame and the dots are drawn each frame into reused arrays.

**The farm speaks in player terms** (F34): "Soil moisture: Good · 66%" over a banded meter with the crop's
suitable range, fertility and crop health as percentages, fertility's effect on the yield as a change
("−15%"), one expected harvest, and treatments in percentage points ("Rest: +0.5 fertility points a
day"). **Details** in the bed panel shows the harvest's multiplication and the raw 0..10000 readings.

## Map layers (decision 0292)

One map layer shows at a time (`map_lenses.gd`), each answering one question with a small legend:

| Layer | Its question | Its legend |
|---|---|---|
| Growing: Soil moisture | Which beds are too dry or too wet? | dry, low, good, wet, waterlogged (the beds' discs) |
| Growing: Ripeness | Which beds are ready to harvest? | growing, ripe, past its best or lost, empty |
| Getting there: Water range | Where can they wade, swim, dive or cross? | wade, swim, dive, ford, bridge site, swim link, landing |
| Woods: Zones and trees | Which trees may be felled, which must stay? | forestry and conservation zones; mature, young, stump, cleared |
| Underground: Tunnels | What lies under the village? | the U view's cut (U switches it too) |

- **The Map layer picker** (`ui/demo_lens_picker.gd`) names the shown layer on its header button ("Getting
  there: Water range ▾", or "Map layer: off ▾"); the button unfolds the list of layers, one button each, its
  question as the tooltip. A pick shows that layer alone and folds the list; picking the shown one again, or
  **Off**, shows none. Under the header: the question, the subject, what they can do there, and the legend.
- **V** steps the same layer: off, moisture, ripeness, water range, woods, off. **U** switches the underground
  view, and the picker follows it: the Underground layer is then the shown one (the others switch off); V from
  it goes to moisture and back to the surface.
- **Whose water range** (`waterplay/water_range.gd`): nobody selected, the 1.0 m mouse anchor ("Water range
  for: a 1.0 m mouse (nobody selected)"); one resident, its own ("Water range for: Otter fisher"); a group, the
  **whole group** -- the zones painted for its shortest member, so yellow is water every one of them wades --
  with who among them swims and who dives by name ("Swim: all but Badger quarryman. Dive: Otter fisher."), never
  the first selected standing in for the rest. **◀ ▶** step from the group to each member ("Badger quarryman
  (3 of 3 selected)": its own zones, wading depth, swimming and diving) and back. A new selection goes back to
  the whole group.
- **Where** (UI §1.1 bottom left, "Minimap + layers"): just right of the party panel's column, so it can
  grow upward without meeting it -- down on the command strip where the space left of the news strip is wide
  enough (1920x1080), else just above the bottom band (1280x720, and whenever the resident journal pushes the
  news strip left). It is clear of the minimap, the news strip, the command strip and the party panel (which
  at 1280x720 fills its column with anyone selected).

## Action cards: what a button will do, and who will do it (decision 0332)

Every demo action's button carries an **action card** as its tooltip (`ui/action_card.gd`, review group H,
findings F33 and F44), enabled or not: the farm's Plant…, crop rows, Water, Drain, Harvest, Clear,
Compost, Cover, Raise and Bank; the woods' Fell, Haul logs, Grub out, Plant sapling, Gather deadfall and
Saw planks; the tunnels' Widen, Brace, Hang lanterns and Repair; Dig tunnel and the room tools; each
fixture's "+" and "−" and the Suggested layout; the Water panel's Build footbridge, Build log bridge and
Dive. A card reads, top down:

```text
Build a plank footbridge
Can't now: it needs 4.7 U planks; the stores hold 0.0 U planks and 76.0 U wood
To fix: Woods ▸ Saw planks (2.0 U wood makes 2.0 U planks)
3.4 m of water bridged (neck bridge): anyone may cross, carrying or not
Planks: have 0.0 U · need 4.7 U
Work: about 6.7 game hours, plus the walk
Who: Assign selected: Squirrel forester (nearest of 2)
Interrupts: Felling the oak — goes back to it after
Needs: a site both banks take; planks (sawn at the sawhorse) and wood for any piers
```

- **The card is the order's own decision.** Each system's order and its card run the same function:
  `farm_crew.gd decide`, `forest_crew.gd decide`, `tunnel_actions.gd refusal`, `room_fixtures.gd
  order_refusal` / `suggest_refusal` / `take_refusal`, `demo_waterplay.gd build_refusal`, the dive loop's
  `dive_spot` and `dive_refusal`, and the Dig tool's `choose_digger`. So a card's refusal is the order's
  (code and words), its resident is the one sent, its cost is what is spent, and a button is pressable
  exactly when its card allows it. The bridge, tunnel and fixture buttons now refuse a short store before
  they are pressed, not after.
- **Costs** are have / need from the stores the HUD reads (wood, stone, planks), the farm's compost store,
  and the fullest spoil heap. **Work** is in game hours of the demo calendar (2.5 demo seconds a game
  hour); the walk is not counted, and a mole job's card says a crew is quicker.
- **Who**, in one grammar everywhere: "Assign selected: X (nearest of 3)" (farm, woods, bridges);
  "Assign selected: X (first of 3 who fits the bore)" and "Assign X (the nearest free resident who fits
  the bore)" (tunnels); "Lead: X (nearest of 3) + 2 waiting to haul" (felling); "Queue for the field crew:
  …" / "Queue for the forestry crew: …"; "Queue for the bridgewright: Beaver bridgewright (specialist)";
  "Already under way: X is on it".
- **Interrupts** says what the named resident stops and whether it goes back to it (the brain's resuming
  rule, `control/work_interrupt.gd`; `demo_command.gd interrupt_text`): a farm, woods, spoil or tunnel job
  resumes; a dig with nothing dug drops its route; a bridge waits for a builder; a sleeper goes back to bed.
- **A harvest with no store room** (decision 0222) is not refused: its card says it waits on the board, uncut,
  and how much has nowhere to go -- what the order then does.
- The cards wear the HUD skin's tooltip (the map piece, ink text) and break their lines to stay inside
  UI-SET-073's 360 × 240.

## Commanding the residents

| Input | Does |
|---|---|
| Left click a resident | Select it alone (Shift: toggle it in the selection) |
| Left drag | Box-select by screen position (Shift: add to the selection) |
| Left click empty ground | Clear the selection |
| Right click ground | Move there in a formation, then hold |
| Right click a work spot | Work there; anyone beyond its free slots holds behind it |
| R | Release the selection back to its own routine |
| Esc | Close the top pop-up; else drop the Dig tool's piece or close the tool; else clear the selection; else open the game menu |
| Menu ("≡") | The game menu (above) |
| F8 | The Demo Lab (above) |
| B (or T, or "Dig tunnel (B)") | The Dig tool: lay out tunnels and branches (below); again: close it. (B is the HUD's Build key, locked in the demo, so the demo takes it; the command strip says so) |
| H / C in the Dig tool (or "Burrow home (H)" / "Root cellar (C)") | The room tools: place a burrow home or a root cellar as its own structure (see Burrow homes and root cellars) |
| U | Underground view: a top-down section cut at the tunnels' level (see The underground view) |
| PgUp / PgDn in the U view | Show level 1 / level 2 (see The second level). On the surface they stay the camera's zoom; Alt+PgUp/PgDn its pitch |
| L in the Dig tool | Lay a link down to level 2: once a ramp, again stairs, again back to tunnels (see The second level) |
| Left click a finished tunnel | Select it for the "Tunnels & burrows (demo)" panel (see below) |
| Left click a dug home or cellar | Select it for its fit-out in the same panel (see Fit-out and living) |
| Right click a tree, trunk, deadfall, stump, cleared spot or the sawhorse | The woods' verb for it (see The woods) |
| Right click deep water | Swimmers swim out and tread water there; an otter over water deeper than it is tall dives; a non-swimmer is refused by name (see Water gameplay) |
| Right click / left click a bridge site | Build the planned bridge there with the selection / select the site for the Water panel |
| Middle-button drag | Turn the camera: across turns it (right turns right, as E), up and down tilt it |
| (any camera move) | The eye never sits inside a tree crown, the crowns between it and what it looks at are thinned, and a selected resident shows through foliage and roofs (see The camera and the trees) |
| Left click a spoil heap | Select it: a brass ring, and the party panel says how much spoil it holds |
| Right click a spoil heap (or C with it selected) | The selected residents who can carry dig it out and haul it to the farm's compost store (Clear; see Spoil heaps) |
| V | Steps the one shown map layer (see Map layers): Growing: soil moisture, Growing: ripeness, Getting there: water range (wade / swim / dive, fords, bridge spans, landings, fish stocks), Woods: zones and trees, off -- the same layer the Map layer picker shows |

The "Demo party" panel in the HUD's left column lists the selection. With one resident selected it
also lists **what that resident can be ordered to do** (`control/resident_abilities.gd`): a short line
a kind of work with what to right-click, the gated ones marked × with the rule -- anybeast who fits a
bore digs (moles start skilled), the otters and the badger are too big for a bore until it is widened, only otters dive, the badger wades
only and breaks rock, the beaver gnaws. At 1280x720 the list is folded into one paragraph (the hint,
skills and species line go first). Its **notice line is each resident's own**: a prompt or answer is
kept for whoever was selected when it was said, so selecting someone else shows theirs. A resident
called away from a job it had not finished (a tunnel job, a dig, a farm or a woods job, a spoil heap)
**comes back to it** when the work that took it is done -- the latest three are kept, the panel says
"Then back to: ...", and R (release) forgets them. Orders move the demo cast only, never the
simulation.

## The camera and the trees

The woods are dense, and the orbit camera used to sit inside a crown (review F53: the NW oak at 11 m,
pitch 30, was a screen of leaves) while a selected worker under one, or behind a roof, could not be seen.
`camera/canopy_clear.gd` (decision 0301) answers with three things, each scoped to what is in the way:

- **The eye.** If the eye would sit inside a tree crown -- each crown an ellipsoid cut at its base,
  measured from the staged oak and beech (`camera/canopy_math.gd`) -- it is moved along its own line out
  past the crown's far side (at most 25 m farther), or failing that in short of its near side (never
  nearer the focus than 3 m). The move is made the same frame; the zoom you asked for comes back by
  itself once the way is clear (`camera/demo_camera.gd` CLEARANCE).
- **The crowns in the way.** Only the crowns the lines from the eye to the focus and to each selected
  resident pass through, and any crown at the lens, are thinned -- an opaque-pass dither above the crown's
  base (`camera/canopy_fade.gdshader`), at most eight, easing in and out in a fifth of a second. The trunk
  stays whole, the shadow on the ground stays whole, the rest of the woods is untouched.
- **The selected.** A selected resident wears a brass silhouette drawn only where something more than
  0.6 m nearer covers it (`camera/selected_xray.gdshader`): through a crown or a roof, never through the
  grass at its feet.

## Digging tunnels

The tunnels are one **network** (decision 0208, `tunnel/underground_graph.gd`): bores meeting at
junctions, reached from the surface by mouths. Press **B** (or T, or the party panel's "Dig tunnel (B)"):
the Dig tool opens in the underground view (and puts the view back when it closes). **Drag** from where a
piece starts to where it ends -- it is dug as you release, if it may be (Shift while dragging drops a bend
at the pointer) -- or click its points one by one and press Enter or right-click. Backspace takes back a
point; Esc drops the piece laid, and with none closes the tool; B closes it. The tool stays open after a
dig, for the next piece.

- **Where it starts and ends.** Anywhere on open ground a new **mouth** opens, its ramp running 4 m straight
  down at 1:2.5 to the bore (decision 0207). A start or end laid on or near the network **snaps** to it --
  to an existing junction (within 1.5 m), or to a point on a bore's side (within 1.2 m) where a new
  **junction** is cut -- the snap target glowing brass. So a branch dragged out of a finished tunnel joins
  it in a T.
- **The ghost.** While laying, the piece is drawn to the pointer as its bore will curve: chalk-cream while it
  may be dug, clay with the reason beside the pointer when it may not. Beside it, the **cost readout**
  (`tunnel/dig_readout.gd`): e.g. "14.0 m · 14 quanta · 5.2 h (crew of 3)" over "28 U spoil · clay 4 m
  (slow), sand 2 m (weak: brace)" -- length, the metres the network will cut, hours of the demo calendar for
  the crew that would dig it, the spoil, and the ground that slows or weakens it.
- **Refused, in words** (demo values, `tunnel/tunnel_rules.gd`): a point off the map or on top of the last;
  a new mouth inside an obstacle or heap, on a work spot or another mouth, or with someone standing on it
  or no way for the digger to reach it; a leg under a building or the well, or under the water; a piece
  under 8 m from mouth to mouth (two ramps) or over 64 m; a junction within 1.5 m of another node, or
  a meeting at under 40°; four bores at a junction already; a ramp joined (join the bore below it); a host
  being dug, worked or closed; a crossing at under 40° (a steeper one becomes a four-way junction); a bore
  passing within 1 m of earth of another it does not join ("it would break into Tunnel 3: join it
  instead"); a bend tighter than a 1 m radius, or one on a mouth's 4 m ramp; the network full (96 bores,
  96 nodes, 16 mouths).
- **Who digs** (`tunnel/dig_skills.gd`): anybeast whose body fits a bore -- mice, moles and squirrels.
  The digger is the first selected resident who can dig, else the village's most skilled free digger; the
  rest of the selection joins its crew. Moles start at **Digging 3**; everyone learns as they dig (the
  GDD's XP per work unit), and the skill speeds the crew. The party panel shows "Digging 3 · XP
  45000/80000" (or "dig 3" in a list).
- **The job list.** A piece laid for a digger already digging waits behind its present dig ("Queued a ...
  tunnel: ... digs it after its present dig"); when a piece opens its digger takes the next one it is given.

The digger walks to where the piece starts -- a mouth on the surface, or through the network to a
junction below -- and digs it segment by segment: a new mouth's shaft on the surface (the `pull_radish`
clip), then down the ramp, along the bore and up the far ramp. A mound of earth moves along the route
(click it to select the digger), the route fills in, and each mouth's spoil heap grows. The heaps are
placed when the dig is accepted -- off work spots, obstacles and holes -- and are obstacles from then on;
the grass is cleared from the holes, heaps and route. A branch cut into a tunnel's side splits that
tunnel in two at the junction, and anyone walking it, its hazards and finds go with the half they
stand on. The panel reads "Digging tunnel — 43%" of the piece. Called away, the digger backs out and the
piece waits, marked with a clay ring and "Tunnel paused at N%"; right-click where it starts with a digger
selected to resume it (on the one it is digging, a right-click changes nothing; on another, it pauses this
one and goes there). A digger that cannot reach the start leaves the piece paused, and says so. Coming
up, the digger steps clear of the mouth, inside the village, off every hole and resident; a piece that
ends underground (at a junction) is walked out of to the nearest mouth.

A finished tunnel's mouths are fieldstone-and-timber gateways over the ramps' cuttings
(`tunnel/tunnel_mouth.gd`). Below, walkers take a ramp at their own pace along its slope, the body tilted
with it so the feet plant, and stoop to clear the bore's crown (`cast/stoop_modifier.gd`): moles upright,
mice a little, squirrels more, otters, the beaver and the badger as far as they go (decision 0207).

A finished tunnel stays. Mice, moles and squirrels fit its bore and use it whenever it is
genuinely the quicker way ("Using tunnel") and nobody is standing on the mouth they would go in at;
otters and the badger walk round until it is widened. A trip is planned over the whole network
(`tunnel/graph_paths.gd`: the cheapest walk between every pair of mouths, per fit, the MOVE §4 Dijkstra
reference; `tunnel/tunnel_router.gd` weighs it against the surface) and walked bore by bore, through
junctions and on out of whichever mouth is best; a bore closed ahead is walked round below, or out of.
Inside, walkers keep their distance behind anyone going their way -- past a ramp's foot or a junction
too -- and step aside to pass anyone coming the other way; at the far mouth they wait below (at most
6 s) while someone stands on the hole. Where three or four bores meet, the junction is a round chamber
(a hub) with clean openings, drawn and cut into the cap like the bores.

A tunnel may end (or start) at a **room's socket** -- lay a point on or near a free socket and it snaps
there -- leaving the room straight out through its wall; it may not pass within a metre of earth of any
room's void anywhere else (decision 0209).

Digging runs at the adopted excavation rate (113 ticks and 2 U of spoil per cubic metre,
`docs/underground_economy_hazard_amendment.md`); the bore size, the stoop that lets a squirrel
through, the depth and the drawn size of a heap are demo values (`tunnel/tunnel_rules.gd`).

## The underground view

U shows the village cut through at the tunnels' level, seen from above (decisions 0206 and 0207; the
design is `docs/design/underground_revamp.md`, whose P0 and P1 these are). It is a **layer cutaway**: everything the demo
draws is on one of four render layers (`demo_layers.gd`), and U only changes the camera's cull mask and
environment -- the surface, its labels, crops, buildings, trees and water are simply not drawn, and nothing
is faded, built or re-materialed, so the switch costs nothing (the first press measured under 12 ms on the
Mac with a lit tunnel, from 278 ms).

- **The cap** (`tunnel/underground_cap.gd`): solid earth at the level, with the ground types as strata
  (rust clay, pale sand, grey rock, blue-tinted wet ground), a blue hatch wherever a bore is refused for
  water, stone footings where the buildings and the well stand, and roots under the trees. It opens over
  every dug bore and room, which are stamped into it as they are dug.
- **Below** (decision 0207): each bore a hand-dug horseshoe swept along its route (`tunnel/bore_view.gd`,
  `bore_mesh.gd`), in the cap's own earth -- strata, a packed floor with a worn path, stones and roots in
  the walls near trees, fresh walls dark and damp, drying over a game day -- its walls rising to the cut,
  which is a clean section: the cap walks each view ray down and opens wherever it enters a bore. Braces
  stand to under their cap beam (the cutaway shader); lanterns are real lights, at most 32 of them pooled
  where you are looking, flickering gently (`tunnel/tunnel_lanterns.gd`). Finds, the rooms with their
  furniture and the cellar's shelf, and anyone walking in a bore. A resident up on the surface shows as a
  small cream marker.
- **Its own light**: the U view sets its own environment on the camera -- dark earth, a low cool-brown
  ambient, SSAO, glow for the lanterns and a faint haze -- and the surface keeps the world's.
- **Clicks land on the tunnels' floor** in the U view -- where the cap shows it -- so a route, a room or
  an order goes where you point. Only the tunnel tool and the residents answer there; the farm, the
  woods, the water and the spoil heaps are surface things.
- **Prewarmed**: everything it can draw registers with `tunnel/underground_prewarm.gd` as it is built,
  and a sample of each is drawn for two frames behind the opening pause.
- Later phases: the switch's crossfade; the generated arch, door, chimney pot, root bin, hanging stores, rug and
  crouch-walk clips replace the procedural ones (P7). The second level is P6's (below).

## The second level (decision 0212)

The warren goes down a second level (design §3, §5 and §8 P6; Brendan's ruling: "Second level: build it in the
demo now at the candidate 4 m spacing"). Its floor is **5.25 m** down -- level 1's 1.25 m and DEC-040's
**candidate** 4 m spacing (`tunnel/tunnel_rules.gd LEVEL_SPACING_U`), a demo value that MOVE-G01..05 have not
settled. Nothing opens onto it from the surface: it is reached only by a **link**.

- **Links** (`tunnel_rules.gd` LINKS): in the Dig tool press **L** for a **ramp** down (L again: **stairs**; again:
  back to tunnels). Press on level 1's network where it starts -- a junction, a ramp's foot, a room's free socket
  or a bore's side -- and release where its foot lands: it snaps onto level 2's network there, or ends in a new
  blind end to dig on from. A link is straight. A **ramp** is no steeper than 1:2.5 (eased at both ends): at least
  10.9 m of run, at most 16 m, walked at walk pace along its slope. **Stairs** are 16 timber-fronted treads of
  0.25 m rise: 5-8 m of run (4:5 at the steepest, 38.7°), less to dig but walked at half pace, and each quantum is a
  quarter more work (the risers). Both are cut and costed by their slope. The ghost's words give its kind, run and
  slope, quanta, hours, spoil and its risers or grade (`tunnel/dig_readout.gd`); refusals say why (its head off
  level 1's network, a bend, too short or too long, a tunnel joining its slope, earth to keep from the tunnels it
  passes while it is near their height).
- **Level 2** (PgDn in the U view): the Dig tool lays tunnels on the level shown. A piece there starts on its
  network (a link's foot, a junction, a bore) and may end blind; it keeps its pillar from level 2's voids and
  crosses only level 2's bores. **Rooms** too (H, C): a level-2 room has no mound, no door or hatch on the
  surface, no ramp -- its door is a socket its passage joins, and it is placed only with that passage (dug first;
  call the digger away before either is begun and both are dropped, or the room alone and its door is left as the
  passage's blind end). With the U view off the tool lays on level 1; U or PgUp/PgDn with the tool open re-lays on the
  level now shown.
  Voids on different levels never meet: the spacing keeps 1 m of earth or more between them; a link keeps its pillar
  from each level only where its slope comes near that level's height.
- **Deeper ground** (`tunnel/tunnel_ground.gd` THE GROUND AT DEPTH, demo values): level 2 has more clay and rock and
  less sand, and is wet only within 2.5 m of the water (the water table) rather than 4.5 m -- so its bores seep only
  near the water and strain only through their sand.
- **Walking** (`tunnel/graph_paths.gd`): the routes' Dijkstra walks across the levels as through any segment; a
  link's cost is its slope over its pace. Residents go down ramps and stairs with their feet planted (the walk at
  the slope's pace, the body pitched with it, P1's), stooping by the bore; the night sends them to beds on level 2,
  crews haul baskets up the links to the heap, evacuees and called-away diggers walk out up them, and a paused
  level-2 dig is resumed through them. A cellar on level 2 is deep for the cool rule; a hearth warms it only on its
  own level (never up or down a link).
- **The view** (`tunnel/tunnel_view.gd` THE LEVELS): **PgUp/PgDn** show level 1 or level 2 -- one cull-mask write,
  nothing built or re-materialed (each level has its own layers, `demo_layers.gd`). Each level has its own cap at its
  own section with its own void mask and strata, and draws the **other level as a faint outline** only. A link is
  drawn on both levels, each copy cut at its level's section; from level 1 its head is seen going down under the
  cut, from level 2 its foot coming up through it. Clicks land on the shown level's floor. A strip under the alerts
  says which level is shown; holding PgUp/PgDn never zooms in the U view. The camera's pivot stays at the ground. Residents on the other level, or on a link's hidden middle, are cream markers. The
  surface's seams and vents, and a digger's mound, are level 1's only. Particles share P5's 200-particle budget and
  face slots; lights go to the level shown.

## Burrow homes and root cellars

Rooms are their own structures on the network (decision 0209, `burrow/underground_rooms.gd`; design
`docs/design/underground_revamp.md` §3 and §8 P3), not chambers bolted onto a tunnel:

| Template | Shape | Quanta | Sockets | Way in |
|---|---|---|---|---|
| Burrow home | round, 4 m across | 24 (12 floor quanta, two high) | 3 | its own round **front door** in a turfed mound |
| Root cellar | a 3 x 4 m barrel vault, stone-lined | 24 | 2 | a **hatch** over its steps |

- **Placing one**: in the Dig tool press **H** (home) or **C** (cellar), or the party panel's buttons. A
  ghost room follows the pointer -- its outline, its door ramp out to its door, a tick at each socket --
  **R** turns it (Shift+R back; the HUD's placement keys; the wheel stays the camera's zoom), and a click
  digs it. Within 6 m of the network the ghost **proposes its passage**: the shortest straight tunnel from
  an open bore or junction to one of its sockets that the Dig tool's rules accept, drawn in brass and dug
  after the room. **Shift+click** places it standalone; connect it later by digging a tunnel to a socket.
  Esc (or right click) goes back to laying tunnels; the same key again does too. The tunnel panel's
  heading says which room is being placed.
- **Refused in words** over the ghost (wrapped, so they stay clear of the side panels; the ghost turns clay): over the stream, the pond or their no-dig
  band; over the crop beds; under a building or the well; within 1 m of earth of another room; within 1 m
  of a tunnel, or its door ramp within a pillar of another's (join a tunnel at a socket instead); its mound,
  cutting or door on a tree, a heap, a prop, a work spot or a mouth;
  off the village. On level 2 only the void is tested, and it needs its passage (see The second level).
- **Digging**: a room is one piece in the digger's job list, dug by the same diggers and crews as a
  tunnel: its door ramp and shaft, then its 24 quanta cell by cell out from the door, a crew at three
  faces; spoil heaps by its door. The shell grows in stages from the door as it is dug, and its name
  counts the percent. (The door ramp is paid as a standard bore though walked as a wide one: decision 0209.)
- **Headroom**: a room is drawn 2.75 m to its crown (the badger's 2.55 m and a little), so everybeast
  stands upright in it; the floor is the tunnels' (1.25 m down), so the room rises 1.5 m above the ground
  -- that is the turfed mound. Its door ramp is a widened bore, so the badger comes in by the front door.
- **Its look**: below, the bores' own earth grown into a dome (a home, with an alcove bowed out round each
  of its three beds) or a vault (a cellar, cool grey-blue and stone-lined), a packed floor worn down the
  middle, a timber ring beam round the wall (a cellar's a rectangle of wall plates) carried by frames at the
  door and the sockets, a wall lantern (warm in a home, cooler in a cellar) as one of the pooled lights; cut
  clean at the section. On the surface a low turfed mound in the village's own grass, cut back to a bank of
  bare earth where the ramp comes in: a home's round front door in a timber ring on a fieldstone sill at the
  foot of its cutting, a cellar's two-leaf hatch leaning against its bank -- procedural until P7's generated
  doors. The mound is an obstacle from the moment the room is laid.
- **Ways in**: the door and the hatch are mouths of the network (`mouth_kind` DOOR, HATCH), so routes go in
  and out by them as by a tunnel's mouth; a room with a passage is a way through, too.
- A dug room is **bare** -- only its own lantern by the door. What stands in it is its fit-out (below).
- A root cellar with racks is a pantry store at its hatch (`farm/farm_cellars.gd`; the id stays
  `root_cellar:<slot>:<generation>`).

## Fit-out and living (decision 0210)

**Fixtures.** Click a dug burrow home or root cellar (in the U view, or its mound on the surface) and the
"Tunnels & burrows (demo)" panel shows it: its words, a palette row a kind with **+** and **−**, and the
**Suggested layout** -- a whole cozy fit-out in one click, then edit it. A fixture goes on its template's
place for it (`burrow/underground_rooms.gd FIXTURES`), paid from the demo stores all or nothing (refused in
words: "the demo stores are short: the bed needs 2 planks (they hold ...)"); taking one out gives its cost back.

| Fixture | Cost | Install | Rooms | Does |
|---|---|---|---|---|
| Bed | 2 planks | 20 WU | home (three alcoves) | a small resident sleeps in it (up to 1.3 m: the moles, mice and squirrels) |
| Large bed | 4 planks | 40 WU | home (the back alcove, else the one by the door) | a big resident sleeps in it (the otters, the beaver, the badger; decision 0211) -- its alcove is dug on into a nook |
| Hearth | 6 stone | 60 WU | home | comfort; glows and smokes from 17:00 to 07:00; warms cellars near it |
| Table and stools | 2 planks | 8 WU | home | decoration |
| Rag rug | 1 wood | 4 WU | home | decoration |
| Lantern | 1 wood | 4 WU | home | decoration; one of the pooled lights |
| Hanging stores | 1 wood | 4 WU | home, cellar | decoration in a home; 10 U in a cellar |
| Shelf | 2 planks | 16 WU | cellar (two) | 20 U |
| Pantry rack | 2 planks | 16 WU | cellar | 30 U |
| Root bin | 2 planks | 12 WU | cellar | 25 U |

A planned fixture shows as a chalk ring; a resident **walks in and puts it in** (the work clip, 0.15 s of demo
time a WU): the residents selected when it was ordered, else the nearest one wandering on its own, three at
most at once, never at night. One called away (to bed at dusk, say) keeps the place for a game day and comes back
to it (`burrow/fixture_crew.gd`). The root bin, the hanging stores and the rug are procedural stand-ins, and the
chimney pot too, until P7's generated props.

**Comfort** (a home's panel and the resident panel): 2000 bare, 4000 with a bed, 6000 with a hearth too (the
GDD's dormitory target), and 250 a decoration up to 1000 -- the suggested layout reads 7000, "cozy". A readout
only (`burrow/room_fixtures.gd` COMFORT).

**The night** (`burrow/night_routine.gd`, on the demo calendar): at dusk, 18:00, everybeast not in an emergency or
the water goes home to bed -- through the round front door or the tunnels, whichever is cheaper -- parking the job in
hand (it takes it up in the morning), crosses the floor to its bed and lies down in it (the staged
`sleep_normally` clip, seated on the mattress by its body's lowest point). Beds go by REQ-SET-132 (its own bed,
else the nearest free one of its size -- a large bed for a big resident, a burrow bed for a small one; ties to the
lower room, then place). At 06:00 they get up and go back to work; whoever
is still on the way home turns back. The kitchen's cook is the **early riser** (`set_early_riser`): it gets up at 01:00
while it has the day's meals to cook (see The kitchen). **No bed** (or none of its size) -- it sleeps on the hall's floor
(REQ-SET-133; it goes in at the hall's steps and is not drawn), the panel says "No bed", and dusk's news names who.
A direct order wakes a sleeper; free again, it goes back to bed. Nothing parked is taken up before morning. A threat gets sleepers up by their beds until it
clears; one in the water or held by its rescue is left be. Paused, nobody moves; at 2x and 4x the night runs faster.
A home's hearth glows from 17:00 to 07:00 and its chimney smokes (at most 16 puffs a home).

**Cellars**: a cellar's capacity is its racks' (a bare cellar is no store); it is **cool** (the GDD's cellar,
350 per mille) while it is 1 m or more down, racked, and no hearth is within 3 m of it or in a room its passages
open onto within 6 m -- else it keeps like a pantry (750). A carrier who can take its load down walks the harvest
in at the hatch and shelves it; the racks fill in place -- jars on the rack, sacks by the shelves, strings on the
hanging stores, the bin's roots heaped -- as the stock rises.

**News**: a line said again straight after is counted, not repeated ("Tunnel 10: Good sticky clay... (×4)").

## The construction theatre and the warnings (decision 0211)

All presentation: nothing here changes a dig's rate, a cost, the spoil ledger or a hazard's clock.

**The dig face.** The face is a rough, concave, damp cut, darker than the walls behind it; the Foremole's hand lantern
stands on the floor behind and beside it, one of the pooled lights, and clods burst off the face with each quantum
cut (`tunnel/dig_theatre.gd`, `tunnel/warren_kit.gd`). Fresh walls are dark and damp and dry paler over a game day;
a room dries from its door outward as it was dug, and a widening re-cuts the walls it passes.

**Baskets** (`tunnel/spoil_haul.gd`, `tunnel/haul_view.gd`). A crew member at its post fills a basket from the spoil
piled behind the face (1.4 s), carries it out stooped -- up the ramp and to the heap -- tips it (0.9 s) with a puff of
dust, and walks back down. The heap grows by that load when it is tipped. The spoil ledger is still posted at the cut;
the baskets only say where each milli-U of it is -- piled behind the face, in a basket, or on the heap -- and the three
always add up to the ledger. The farm and the spoil clearers take only what is on the heap. A dig with no crew heaps
as before. The member still counts as at its post while it hauls, so the dig's rate is unchanged.

**Braces and lanterns** go up one at a time as the job's work reaches them: each frame rises from the floor with a
small dust puff, each lantern's glow swells on and its light blooms (0.8 s to a peak, settling). **Fixtures** rise out of
their chalk rings as they are put in, with a puff when in; beds, the hearth, the table and the racks are heaved (the
`pull_radish` clip), lanterns, hanging stores and rugs placed by hand (`collect_object`).

**Warnings before the strike** (`tunnel/hazard_look.gd`, `tunnel/hazard_view.gd`). A seep or a strain shows from half
the warning's pressure (250 per mille), growing to the strike: a seep darkens and wets its stretch of bore, glossy, a
puddle spreading, drips from the crown; a strain cracks the walls over its weak section, sand stains and a spill
on the floor, sand trickling from a sagging crown. Past the warning the news says so and the tunnel's ends are ringed
in clay, above and in the U view. Braced, the signs go. The two worst seeps drip and the two worst strains trickle.

**On the surface** (`tunnel/warren_signs.gd`, `tunnel/tunnel_mouth.gd`). A young tunnel's turf seam -- cut and relaid
over its dug stretch, growing behind a dig's face -- heals over three game days; a tunnel at least 6 m long has an air
vent every 5 m; every mouth arch hangs a lit lantern.

**Particles: at most 200 live**, by construction (`tunnel/warren_particles.gd`): chimney smoke 8 homes x 16, face clods
3 x 6 and mound clods 3 x 4, dust 2 x 8, drips 2 x 6 and sand 2 x 6 -- 198. A fourth dig, a third seep or a third puff at
once is not drawn. The weather's rain and snow, the woods' chips and leaves and the swimmers' bubbles are their own.

**The Dig tool's readout** adds what bracing the route would cost: "brace 4.0 wood + 4.0 stone".

## Farming

The six crop beds grow **individual pantry ingredients** -- radish, turnip, carrot, beetroot, parsnip,
onion, cabbage, lettuce, spinach, leek, celery, pea, broad bean, wheat, barley, oats, each a LEAF of the
content library's pantry -- by the settlement's **own crop arithmetic** (`scripts/core/farming.gd` and
`crop_weather.gd`, GDD §5.6): each bed is a real FarmPlot row, and each ingredient grows by the §5.6 row
it belongs to (roots, cabbage, beans or grain), on the demo's one calendar (above). Harvests go into
the **pantry**, counted per item, at the slowest-spoiling store with room -- a **root cellar**, delivered
at its hatch (spoilage 350 per mille, the GDD's cellar) before the covered store (1000), and of two cellars
the one nearer the bed (`farm/farm_cellars.gd` turns `underground_rooms.cellars()` into pantry stores);
the kitchen pantry (750) comes between a cool cellar and the covered store (see The kitchen); the Food command (or K)
opens the Pantry (decision 0292), whose headline is the pantry total:

- **Stocks** (first, and what it opens on): a table, one row per ingredient per store -- **In store**,
  **Incoming** (a harvest on its way there, its room reserved), the **Store**, and **Next to spoil** there ("all
  in 10d", or "1.2 U in 1d 10h" when it is the first of several lots; GDD §5.8 spoilage by where it is kept).
  Food that spoils within two game days goes first, soonest first, marked "Soon" in clay. The order is set
  when the Pantry opens (or Stocks is chosen) and **kept while it is open**: figures change in place, a new
  row goes at the end, a row whose stock has gone stays reading "0 U", and a row whose store is taken away
  (a cellar's racks out) reads "(store gone)". Under it each store is a row: stored,
  reserved for harvests, free, capacity and how fast it ages food; then spoiled food and its compost button.
  An empty pantry says so and names a real source from the beds -- a ripe bed to harvest, else the bed that
  ripens soonest, else an empty bed to plant -- with an **Open bed N** button.
  A row with food reserved for the kitchen says so ("· 2.0 U for the kitchen"); the table ends with each dish's
  portions, as ready food, and the water in the butt.
- **Recipes**: every ingredient in catalog order with its stock, and the content library's dishes the picked one
  feeds. The two the kitchen cooks are marked **Cookable (active)** on their crops; the rest are ideas.
- **Kitchen**: see The kitchen, below.

**Nothing harvested is lost or credited from afar** (decision 0222, the review's F19/F24/F27/F28):

- **Room first.** A harvest reserves room in its store as the cutting starts. With room nowhere it is
  **not cut**: the crop stands, the job waits on the board, the order's answer and the feed say how much
  has nowhere to go, and the bed panel shows it in clay with a **Make room… (Pantry, K)** button. The crew
  takes it up once there is room.
- **What fits.** A store that shrank under a reservation (a cellar's racks taken out) takes what fits;
  the carrier keeps the rest and carries it on to another store with room -- or waits at the store with
  it, trying again, until there is one. Root cellars follow the same rules, down to the shelf.
- **Cancel is not delivery.** "Cancel jobs" on a bed stops its production; a harvest already cut
  becomes its **delivery**: the carrier walks on and the store is credited when it gets there. A carrier
  ordered elsewhere keeps the load with the job and comes back to it (its resume queue); released, the
  field crew takes it.
- **The Pantry's figures.** Every quantity -- stock, totals, capacity, yield, a load carried -- is one form, tenths of a unit floored (`5.1 U`, `400.0 U`, never `0 U` for something:
  `<0.1 U`), and totals are summed in milli-units first. Each row names the **first lot to spoil**, its
  store and the **game hours** until it does, at that store's rate and each season's, a season change
  included -- the very sum the hourly ageing makes.

| Input | Does |
|---|---|
| Left click a bed | Its panel -- that bed only: a "Needs:" line naming its most pressing work and why (clay when urgent), crop, stage (and why growth stalled), moisture band, soil, what was done to the ground, expected yield, jobs, and the verbs |
| Right click a bed (residents selected) | The nearest selected resident does its most pressing work: clear, harvest, drain a waterlogged bed, water a dry bed, cover once a frost is announced, sow |
| Plant… (bed panel) | The crop picker: every ingredient, sowable ones first, with growth hours, yield, family and its rotation effect in this bed; the rest say why not (soil, planting window) |
| Water / Harvest / Clear / Compost / Cover | Given to the selected residents, or queued for the field crew (the fieldworker and gatherer take queued work while wandering) |
| Drain | A wet or waterlogged bed: a resident digs a ditch round it (6 WU); its moisture drops at once to the top of its crop's band, and the ditch sheds up to 1000 a day for good (decision 0205) |
| Raise / Bank | A resident fetches 2 U of tunnel spoil from a heap: a raised bed drains and is warmer at night; a banked bed keeps half of each dry day's loss |
| Rest | Rest the bed fallow (+0.5 fertility points a day; nothing is sown) |
| V | Map layer: moisture, then ripeness, then the water range, then the woods, then off -- or pick one on the Map layer picker (see Map layers) |
| K / Food | The Pantry |

Threats: spring is wet (beds waterlog and stop growing -- Drain them, run a tunnel under them, or raise
them; every bed sheds up to 500 a day above its band's top, so in the first spring only the Ideal spell
waterlogs a roots bed, around spring 8), summer dry (water), frost nights are announced at noon the day
before (cover or raise; the first spring's is the night into spring 11), blight (first outbreak at the
midnight opening spring 12 -- the first threats now fall about two days apart) spreads to
the next beds at midnight unless the blighted bed is cleared, and a ripe crop starts losing yield after
48 hours and withers at 120. A finished tunnel under a bed drains it; a tunnel with a mouth at the
real stream's edge (dry ground within 2.5 m of its waterline -- inside the square, by the ford or at
x 19.5 m, z 4) irrigates the beds it runs under. Details and every number's source: `farm/*.gd` headers.

## The kitchen (decision 0381)

Breakfast and supper, cooked from the pantry's real stock (`kitchen/`). Two dishes, alternating: **wild oat
porridge** at breakfast (the GDD's `porridge` row: grain 2 U + water 2 U, 12 WU) and **Togget's vegetable soup** at
supper (its `root_stew` row: roots 3 U + water 1 U, 16 WU), each batch 2 portions of 1800 NP that keep 24 h, and 0.1 U
of wood. Grain is wheat, barley or oats; roots are radish, turnip, carrot, beetroot, parsnip or onion (each crop's
§5.6 row). If one dish's food is short the other is cooked.

- **The day.** Breakfast is called at 06:00 and served until 12:59; supper at 13:00 until 16:59, an hour before bed
  (so whoever goes to eat raw food at its end has eaten before dusk). The
  cook (the keeper; a free resident stands in) rises at 01:00 for breakfast and cooks supper from 09:00 (out on
  the table a portion ages fast: see decision 0381). It fetches the planned meals' food -- reserved from real
  lots, soonest to spoil first, and only withdrawn when a batch starts -- from the **kitchen pantry** at the path's
  end (10.5, -2.6; 120 U, 750 per mille) or wherever it is, cooks at the cauldron (steam rises), carries each meal's
  pot to the hall's east table and puts the bowls out. Diners are called once a meal is on its way (their work is
  parked and taken up after), sit at the hall's tables (`chair_sit_idle` when staged) and eat one portion each.
- **Water** is drawn at the well into the butt beside it (1 WU a unit). **Keep water drawn** (on) keeps the butt
  full: whoever is free and not due at a table draws, two at most.
- **Fed.** Each resident's need is the GDD's NP a day (6000 small, 7200 medium, 9600 large). The resident panel
  reads "Fed · 72% full · 1800/6000 NP today" and "Last meal: breakfast, porridge" (fed above 3500, peckish to
  1501, hungry below), the monotony memory when it applies; the roster shows the word. No penalties.
- **Short.** A meal called with nothing coming raises "No supper tonight: <why>. To fix: <where>" in the village
  news; at its end anyone hungry eats raw roots or cabbage nobody has reserved (at most 3000 NP), the rest go
  without, and the tally is posted ("Supper, day 2: 8 ate, 1 went without").
- **The Kitchen tab** (Pantry, K): the cook and what it is doing, any refusal and its fix, the next meals, the pot
  and table, the butt and fuel, how the village is fed, the last meals; **Cook now** and **Draw water** (each with
  its action card, from the same decision as the order), **Keep water drawn**, **Cancel the next meal** (a batch
  already cooking yields half its food as spoiled food; fetched food stays in the larder).

Interrupted work loses nothing and makes nothing fresher: a cook called away leaves the batch at the cauldron for
whoever cooks next; a load in hand is delivered before bed. Details and every number's source: `kitchen/*.gd`
headers and decision 0381.

## Weather, upgrades, hazards, finds, crews and threats

The tunnel extensions (`tunnel/tunnel_ext.gd`) add a **"Tunnels & burrows (demo)"** panel, the right
column's second tab. Everything runs on the demo clock: paused, the weather, hazards, jobs and threats
hold; at 2x and 4x they run faster.

| Input | Does |
|---|---|
| Left click a finished tunnel's mouth or route | Select it (selected residents stay selected) |
| Panel: Widen / Brace / Hang lanterns / Repair | A job on the selected tunnel (see below) |
| B, with a digger **and** others selected, then a dig | The others join the Foremole's dig crew |
| Right click a tunnel being dug, residents selected | They join its crew |
| Demo Lab (F8): Next weather / Test event | Run the one calendar -- farm, weather and date together -- on to the next change of weather (at most 48 h) / bring the next threat |

- **Weather**: the village's one weather (above). Hazards soak while it rains.
- **Hauling**: a carrier may take a bore its load fits (a mouse or squirrel a standard bore, an otter a
  widened one, the badger none); only the surface part of its trip counts toward the carry limit.
  A busy mouth has a short **queue**: walkers wait in a line beside it rather than crowding the hole.
- **Upgrades**, each on one bore (a stretch between junctions, ramps' feet or mouths): Widen (a digger re-digs five more quanta a metre; otters and the badger then fit),
  Brace (ECON-002's wood 250 + stone 250 milli-U and 25 ticks a quantum, from the demo's one stores --
  the wood the woods bring in, shown in the top bar's Wood and Stone), Hang lanterns (a lit
  bore, walked 10% faster).
- **Hazards** (deterministic, warned, preventable): an unbraced tunnel through wet ground floods after
  40 s of rain (warned at 20); through sand it partly collapses after 75 s of rain or crossings (warned
  at half). The tunnel closes, walkers inside turn back, and Pump out / Clear the fall reopens it.
  Bracing prevents both.
- **Ground** (`tunnel/tunnel_ground.gd`): loam, clay, sand and rock pockets, and the wet stream edge,
  tinted over the village while laying a route and shown as the strata of the underground view's cap. Clay digs slower,
  sand faster; rock needs the badger on the crew (a digger alone scratches at a quarter pace).
- **Finds**: every metre cut rolls once (seeded) for flint, clay, an old root store or a rare relic;
  relics tell a short story. The tally is in the panel.
- **Rooms** (`burrow/`; above): a burrow home has three bed alcoves, its beds put in (counted in the panel, not
  the HUD's Beds); a racked root cellar is a store, cool or not (see Fit-out and living). The farming demo reads
  cellars through `underground_rooms.cellars()`.
- **Crews**: up to three helpers with the Foremole; one worker per quantum's face, so a helper who
  fits finishes behind it (1506 per mille on a standard bore), more faces when widening. The
  Foremole's digging skill raises the crew's rate (1000 + 50 per level, per mille: a mole's 3 is 1150).
- **Threats** (`events/`): a seeded flood at the stream edge or a fire at the covered store. Residents
  in it take the network out -- in at the nearest mouth, up at the one furthest from the danger --
  (or walk out), shelter, and go home when it clears.

Staging also runs `tools/make_demo_crop_cards.py` (needs `blender` on PATH, ~2 minutes): the grain
and roots L0s shatter, so their beds are rebuilt as a bare bed plus alpha-cutout cards rendered
from the high-poly sources. Re-run it alone after changing it:
`python3 tools/make_demo_crop_cards.py`. Without Blender those two beds are placeholders.

## The asset pass: props, plants, icons (2026-09-29)

The library's farm/tunnel and water/bridge/forestry passes bought 56 assets as a concept and a
textured high-poly each, with **no L0**. `tools/make_demo_props.py` (with `demo_props_blender.py`,
needs `blender`, ~10 minutes, cached per key) makes the game-budget versions free in Blender, into
the gitignored `assets/props/`, `assets/plants/` and `assets/icons/`; staging runs it, and
`python3 tools/stage_demo_assets.py --only props` re-runs just it. Every row in the manifest records
its source's path and SHA-256, its GAP-04 family and budget, the triangles and texture size
reached and how it was reduced.

- **Props** (44): decimated to their family's L0 budget -- small props 1,150 of 1,200, furniture
  (boats, jetty, bridges, rack, trunks) 1,900 of 2,000 -- on a fresh UV unwrap with the high-poly's
  albedo, roughness and normal baked on (512 px small, 1,024 px furniture); bottom origin, facing
  +Z as authored. **Facing is not checked by any tool**: the project's convention is -Z forward, so
  each needs a human look before it leaves the demo.
- **Plants** (12): alpha cards rendered from the high-poly -- full front, full side, thinned and
  sparse (a third and two thirds of the leaves gone, by whole UV charts round the crown), and for
  rosettes the same from above -- cut at the measured soil line (the turnip's and carrot's cut-away
  roots go); and a 580-triangle close-up mesh -- drawn for the lettuce, a solid head its cards
  cannot draw from above, once it fills out; the leafy plants' meshes shatter at that budget and
  are staged only.
- **Icons** (23): the eighteen items and the five finds and relics, one camera and light rig.
- The older library props this pass uses (lantern, bed, basket, jars, shelf, tools) are remade the
  same way: their L0s carry 2,048 px maps, over GAP-04's 1,024 for their families (the basket's also
  shatters). The two buildings (the root cellar's door, the compost bins) are staged as they are
  (`DRESSING`). The one table sizing all of them is `props/demo_props.gd` (demo-only sizes, by
  height for what stands and by length for what lies or is carried).
- **Memory.** Godot extracts every staged model's maps uncompressed (`compress/mode=0`; the editor's
  detect-3D switch never fires in a headless import), which held ~6 GB of textures in the default view;
  the pass added ~0.3 GB of it (measured 5,804 -> 6,088 MB). A plant's atlases are read only when a
  bed first shows it. `tools/demo_texture_imports.py` now VRAM-compresses them (see *Windows build*).

What changed on screen:

- **Every crop its own plant.** Radish, turnip, carrot, beetroot, onion, leek, lettuce, celery, pea,
  barley and oats grow from their own cards (a filled-out lettuce as its mesh); wheat keeps its grain cards; parsnip the roots bed's
  carrot cards; cabbage and spinach the roots bed's turnip cards and, ripe, the cabbage heads; broad
  bean the pea (darkened). A stage shows a subset of the cells (`farm_look.gd stage_cells`): a
  sprout the sparse card, then sparse and thinned, thinned, all three; ripe the full plant. A
  WITHERED bed is thinned, slumped, drooping and bleached to straw; a BLIGHTED one stands full but
  dark and blotched (`crop_card.gdshader bleach` / `spots`).
- **Icons** in the Pantry's list and the crop picker; an item with no model shows a roundel in its
  own colour.
- **Carrying**: a harvest is carried as its own model in the carrier's hands (`farm_carry_view.gd`)
  and put on the store's shelf -- a pantry shelf with the store's goods on its boards, most first,
  and a jar per started third of fullness (`props/store_shelf.gd`, `farm_stock_view.gd`); a root
  cellar's stock shows on its own racks below ground instead (decision 0210).
- **Tunnels**: braced bores show the library's brace frames, a collapse its rubble, lit bores wall
  lanterns on alternate walls with a glow in each, and real light from the nearest 32 (all drawn in the underground view); finds lie where they were cut
  and sit on the tunnel panel as icons; a digging mole holds its pick; rooms are fitted out by the player (decision
  0210).
- **Water**: a jetty off the boathouse with the rowboat alongside and the coracle off its end, a
  raft on the pond, a rod, a net, an eel trap and a smoking rack by the fisher shelter, a trout and a
  perch in the creels. The bridge models are staged only; the gnawed log and felled trunk lie in the
  woods (below).
- **Walking**: the cast walks at 1.4 times the gait speed the grounding tool recorded on each walk clip
  (`gait.speed_m_s`, decision 0202; the pace is `cast/demo_actor.gd WALK_PACE`, decision 0205), and the
  walk clip always plays at ground speed over that gait speed -- so 1.4 on open ground, less in rain
  or wading, more in a lit bore. A carrier walks at 65% of its walk, its carry clip sped to match (was
  about 37%: the playtest's mole was "way too slow with a log").

## The woods

Every tree in the village and its woods -- 173 oaks, beeches and saplings -- is a REAL ResourceNode row
(`scripts/core/resource_nodes.gd`) on the GDD §5.1 tile it stands on, of the compiled `wood` item
(`forestry/forest_stand.gd`): a mature tree holds 12 U. Felling is the store's own single debit, which
dates the stump (REQ-SET-138); the wood lies as the felled trunk until it is hauled to the log stack
into the demo's one stores. A stump regrows on the 48th day after it was cut, if nothing (a tunnel
mouth or spoil heap) stands on it; a storm's blow-down is uprooted, leaving a cleared spot that can be
replanted (compost 0.25 U from the farm's compost store and 4 WU, §5.9), also maturing in 48 days.
Residents work trees within 30 m of the square (`forestry/forest_rules.gd` REACH_M).

| Input | Does |
|---|---|
| Right click a mature tree (residents selected) | The nearest fells it -- with the axe; the beaver gnaws it (same job, its own look) -- and the rest of the selection wait by it and haul it (up to 3) |
| Right click a felled trunk | Every selected resident hauls it, 6 U a trip, to the log stack |
| Right click a deadfall pile | Gather it: no felling, slow (20 WU a U), 1-2 U -- the wood of the early game and of protected woods |
| Right click a stump / a cleared spot | Grub the stump out / plant a sapling |
| Right click the sawhorse or the plank stack | Saw 2 U of logs into 2 U of planks |
| Left click a tree, stump or spot | Select it: the Woods panel shows its state, its zone's floor and its verbs |
| Left click inside a zone | Select the zone: intensive (keep 10%), auto-fell, unmark |
| Woods panel | The same verbs with nobody selected are queued for the forestry crew (the squirrel forester and the beaver, who take the board's work while wandering); Mark forestry / conservation zone, then drag on the ground (Esc: cancel); Gather deadfall; Saw planks; Cancel woods jobs (the storm gust is the Demo Lab's) |

- **Conservation** (decision 0222, the farm's own rule): wood and planks reach the stores only where they
  are stacked. Cancelling woods jobs with a load in hand turns each into that load's **delivery** -- logs
  (a sawyer's too) walked to the log stack, planks to the plank stack -- credited on arrival, never at the
  cancel; a hauler called away keeps the load with the job and comes back to it. Planting's 0.25 U of
  compost is paid **once per job**: a planter called away, a new planter or a retry never pays it again
  (the work itself starts over).

- **Zones** (`forestry/forest_zones.gd`, GDD ZoneType FORESTRY 5 and CONSERVATION 8): a forestry zone keeps
  20% of its trees mature (10% intensive) -- a fell that would breach it, counting fells already ordered,
  is refused with the floor in words; a conservation zone is never cut, by order or routine, but its
  deadfall may be gathered. Auto-fell (off by default) lets the crew work a forestry zone down to its
  floor. The demo opens with the North stand (forestry) and the Old grove (conservation), edged on the
  ground in brass and sage.
- **Seasons and weather**: winter felling takes 80% of the time (no sap, demo); a heavy rain/storm day of
  the one weather slows outdoor work to 80% (§5.10), blows one tree down (a warning in the feed and a
  clearing job for the crew) and brings deadfall down. A pile of deadfall falls every midnight.
- **Skills** (`forestry/forest_skills.gd`): felling and sawing, §5.3's arithmetic (10 XP a WU, level =
  floor_sqrt(xp / 5000), work time / (1000 + 50 x level)), shown in the party panel; anybeast learns
  (LORE-P12); the forester and the beaver start at felling 3.
- **Drawing** (`forestry/forest_view.gd`): a felled tree is cut above its root mound -- its model split
  once per kind (`forest_split.gd`) -- and the trunk and crown topple away from the feller, land in a
  burst of leaves and dust and give way to the felled trunk (the beaver's: the gnawed log); the stump
  wears the fresh-cut oak stump for a season, then the mossy one, and grows a shoot. A regrowing tree
  (decision 0301, review F52) climbs one height ramp over its 48 days: the shoot or sapling first, then,
  once the ramp passes the sapling's full size (about a quarter of the way), the tree's own mature model
  scaled down to the ramp's height -- about a third at the swap, the heights equal either side -- let
  down by the same share of its sink, at the tree's centre, with the stump and stub gone; it reaches full
  size the midnight it matures. A spot something stands on keeps its shoot. The staged trees
  and the plinth buildings are let down into the ground by their own measured base (decision 0205,
  `world/world_sizes.gd SINK_M`: oak 1.2 m, beech 0.5, residence 0.42, store 0.12, kitchen 0.11,
  workbench 0.07), so roots run into the ground and walls rise out of it. Residents stand on the roots
  where the roots are (decision 0301, review F40): each staged model's own support heightfield is baked
  from its mesh at boot (`forest_root_field.gd`, 12.5 cm cells, about 8 ms a model) and read in the
  tree's own frame -- its spot, its yaw, its size, a young tree's share -- so a walker rises onto a root
  and stays on the ground in the hollow beside it (`forest_lift.gd`). Roots standing more than 0.45 m
  proud are walked round instead: a flare circle about each staged trunk and up to fifteen lobe circles
  join the cast's obstacles. The yard by the workbench holds
  the sawhorse, the plank stack (as tall as the planks), a second woodpile (as tall as the wood), the
  chopping block and the sapling baskets.
- **For bridges and boats next**: the planks are `tunnel_stores.gd` `plank_milli_u` with
  `add_planks`, `can_pay_planks` and `pay_planks` (all or nothing), on `demo_village.services().stores`.

Every number that is not the GDD's is a demo value named in `forestry/forest_rules.gd` (and the root
mounds' measured profiles in `forest_roots.gd`).

## Water

A stream runs down the village's east edge -- narrowing to a neck at the north-east corner, past
the weir and the mill, spreading into a shallow ford where the east road crosses it, then deepening
by the fisher shelter -- into a pond beyond the south-east corner with a boathouse on its shore.
It lies east of the ±20 m square; the walking area is widened over it (see Water gameplay), and
nothing in the village moved. **The weir** (decision 0301, review F41) is the library weir's structure,
not its diorama: `tools/make_demo_weir.py` strips the L0's baked pool, tail water and earth slab, and
`water/weir_fit.gd` fits what is left to the stream -- its ends moved out onto both banks (0.7 m past each
waterline, the gaps filled with its own plain wall), its piers' and wall's foot let down to the bed, and
a stone sill under the wall from bank to bank on the bed -- in the demo's one water surface. Its crest
stands where the model has it. It stands at z = -16.2, 2.2 m upstream of its first spot, clear of the
`weir_bank` landing; the one swim link that crossed where it now stands is gone (22 remain). Unstaged,
a plain wall and sill of the same fitted span stand in for it. The ground and water colours answer to
the world-art direction (DEC-038), not the UI pigment lock: `world/world_look.gd` WORLD MATERIAL TARGETS. The ground is carved into banks and beds; the surface flows at the stream's own speed and
stops when the game pauses. The Water range map layer shows the zones and the live fishery. The fishery
runs on the demo's one calendar (its days are the farm's and the HUD's). A flood (the tunnels' threat)
raises the stream up its banks at the ford.

`water/water_map.gd` is the foundation the next phase builds on: integer depth, wade / swim / dive
zones, ground and bed height, flow, nearest bank, landings, ford and bridge candidates, and
`segment_crosses_water` for tunnels. `water/fishing_driver.gd` runs the real fishing store
(`scripts/core/fishing.gd`) on demo time -- the stream is the river habitat, the pond the lake --
and returns each cycle's catch as species lots without touching any pantry. The depths and the
zone thresholds are demo values (`water/water_rules.gd`); decision 0196 records them.

## Water gameplay

Wading, swimming, diving, rescue and beaver bridges (`waterplay/`, part A; decision 0196). Every number
is named in `waterplay/swim_rules.gd`, as cited (HAZ-001..003) or as a demo value.

- **Reaching the water.** Orders, formations, routines and tunnels use x -20..36 m, z -34..42 m (the
  stream from above the neck, both banks and round the pond); tunnels are still refused under water.
  Water deeper than a mouse wades is a band no walker enters; the ford is open ground. Nothing is sent
  to stand, idle or work in the water: every spot chooser keeps a body clear of the waterline.
- **Wading.** In water shallower than its own wade depth a resident walks on the bed at 55% pace; a
  route through the ford costs that pace, so a longer dry way can win.
- **Swimming** (per resident, seeded by species -- mouse 0.60, squirrel 0.55, mole 0.50, otter 1.10,
  beaver 0.90 m/s; the badger wades only). Routes offer swimmers the swim links across the run and the
  pond's chords at twice their length; a loaded resident never swims. At the surface with the swim clip,
  treading water when it stops, angling into the flow and swept by what it cannot hold; the tail floats.
  Stamina (HAZ-001/003): no routine swim under 40%, turn for the bank at 15%, in difficulty at 0; cold
  water (below 10.0 °C) doubles the drain; a flood doubles the flow.
- **The bank recheck** (review F07, decision 0231). A route's swim is checked again at the water, every
  step down the bank until the swimmer goes in: swim shortcuts, stamina, a load, and whether it can still
  swim against the flow there. Refused, it climbs back up, plans again from land (round, the ford, a
  bridge -- or still water it may swim) and the water's news says why ("Mole won't swim across: swim
  shortcuts are off — going round by land"). One already swimming is never pulled out: it finishes the
  crossing to the far bank (or turns back tiring, or is rescued), and its next trip is planned by land.
- **Diving** (otters): a planned dive needs the descent, 8 s of search, the ascent and a 300-tick reserve
  in air (HAZ-002: 1200, 1 a tick below, 4 back); it turns for the surface when the air says so. Each
  dive's find is drawn from the dive's number (a stone, a hook, silt, a relic, ...); a relic joins the
  stores' finds, a stone 0.25 U of stone. Bubbles rise from a diver; the party panel shows breath and
  stamina. **Low air (450) and air out (0) are said once each** as the air crosses them (review F38,
  decision 0231), not once a tick: they re-arm only back at the surface with 600 air, so one dive says
  "low on air" at most once and the next dive can say it again. The breath itself is a meter the panels
  update in place; the news keeps its history.
- **Rescue** (REQ-SET-054): a resident in difficulty is warned in the feed and drifts, treading hard.
  **By capability** (review F39, decision 0231): one held below goes to the nearest free *diver* whose air
  covers the way down, back up with it and a 300 reserve; one at the surface to the nearest free swimmer,
  who tows it (60% of its speed) to a landing it can reach against the flow. Fallbacks say why in the
  feed: with no diver for one below, a swimmer treads above it, ready to tow the moment its air runs out
  and it floats up; with no swimmer at all, anyone takes a line (8 m) to the nearest landing and hauls it
  in once it is within reach. A fallback is looked at again every second: a diver come free takes over
  from one waiting above or on the bank, and it stands down (an otter sent to wait above because it was
  short of air goes down itself once it has breathed). One rescuer answers a victim at a time; one the
  player calls away frees it at once and is not sent back to it, and one whose swim shortcuts are turned
  off on its way lets the victim go at the water rather than going in. Nobody drowns: with nobody coming
  after 90 s (or a rescuer on the way but not there after 240 s, who then stands down) it washes ashore
  at a landing. It then rests 20 s, recovering three times as fast. The Demo Lab's Cramp (F8) starts
  one on demand.
- **Bridges.** The Water panel steps through the map's three bridge candidates or spans any two banks
  you click. A plank footbridge costs 1.0 U of planks a metre of deck (and 1.0 U of wood a pier, one per
  started 2.5 m of span over 3.5 m); a log bridge costs one 6.0 U log -- a felled trunk lying ready, else
  the log stack -- and spans at most 5.5 m of deck. Paid all or nothing from the one stores; refusals say
  why. The builder fetches and carries the material, then works piers, beams and deck (WU at the woods'
  rate, §5.3's skill factor); the beaver bridgewright starts at level 6 and gnaws its log. Anyone who
  selects nothing leaves it for the bridgewright. Finished bridges are walked by everyone, loaded or not,
  the badger included.
- **Who goes in to rescue** is the nearest by route to where it goes in, not in a straight line (decision
  0205): a swimmer across the stream with a long way round loses to one a little farther on the near bank.
- **Water tab** (right column): conditions, alerts, who is swimming, the chosen site and its costs,
  bridges, stores and the water's news. The alert line is one incident per victim, updated in place:
  where it is and its breath, who is answering and at what, the landing once it is settled, and why
  nothing better went -- or, with nobody, when the water will bring it ashore.
  The **Water range** layer (V or the Map layer picker) paints the zones
  for its subject -- one resident's own height, or a group's, member by member (see Map layers) -- the bridge candidates, the swim links and the landings; the fishery's site labels are two
  lines each (quota and slots; each species' stock and state), laid out so they never overlap.

## Spoil heaps

A finished tunnel's spoil heaps can be cleared (`spoil/`, decision 0205). Left click a heap to select
it; right click it (or press C) with residents selected, and those who can carry dig it out a basketful
(2 U, the farm's own load off a heap) at a time and haul it to the farm's compost store, tipped by the
open stockpile -- the demo's one use for spoil is compost (the farm's Compost job digs it off a heap too).
Every milli-U goes through the farm's spoil books, the ones Raise and Bank take from: taken, carried,
delivered, nothing made or lost. At most four work one heap; the emptied heap stops being an obstacle.
A heap still growing under a dig is refused. The party panel says who is "Clearing a spoil heap" or
"Hauling spoil to the compost".

## Sound (decision 0351)

The first sound pass (`sound/`; review F43, UX-029, UX-031). **No sound files are staged yet**, so the demo is
silent: every cue is wired, takes its voice and keeps its limits, and plays nothing until its file is dropped in
at the path the table names (`sound/sound_table.json`; each missing cue warns once at boot). The sourcing plan
waits on Brendan's approval of each download.

- **One owner, not an autoload** (`sound/sound_director.gd`, a child of the village). Everything it hears is the
  demo's -- cast, woods, tunnels, water, notices, camera -- so it is made and freed with the scene, and the sixth
  autoload slot stays free for the game's own AudioManager.
- **Five buses**: Master, Ambience (wind, rain), Work (tools, loads, footsteps; through "Work Surface" and "Work
  Under"), Water (the stream, splashes, wading) and Cues (warnings, completions, clicks). Made by name once.
- **A bounded voice pool** (`sound/sound_voices.gd`): 8 Work, 4 Water and 3 Cues players made at boot; each
  cue has its own voice cap and a **real-time gap** (`gap_ms`), so at 4x, or with twenty residents chopping, the
  extra events fold rather than stack. No player's pitch is ever changed.
- **The listener** stands over the camera's focus, 0.4 of the zoom up, turned with the view: close in you hear the work at the focus;
  zoomed out the village settles to its ambience. A placed cue beyond its range takes no voice.
- **Paused** (any pause: yours, the menu's, the stall banner's): wind, rain and water duck 12 dB, work and
  water one-shots stop and none start; warnings and clicks still sound. **The U view** low-passes the world
  above (ambience, water, surface work); with it off, digging below is the muffled one.
- **The event map** (`sound/sound_taps.gd`) sounds only what the models have already committed: a carry
  beginning or ending (pickup, drop), entering or leaving the water, starting to swim or dive (splash), each
  stride by the ground underfoot (grass, a worn path's dirt, a bridge leg's wood, a tunnel, wading), each whole
  beat of a felling, grubbing or sawing step that has begun, a tree coming down, each dig quantum cut, a tunnel,
  room or bridge opening (complete), a *new* warning in the notice feed (a folded repeat does not chime again)
  or a critical incident raised or come back (decision 0331's `incident_cue`; one chime a frame at most),
  and every button press. A tree blown down falls too. It reads the models and writes nothing: no sound, and no
  animation, awards anything.
- **Every cue has a text or picture match** (the table refuses a cue without one): chips and the task line for a
  chop, clods and the tunnel panel for a dig, the news strip's "Warning:" line for the warning, and so on.
  Muted, nothing is missed.
- **Settings** (the game menu): each bus's volume (−, +, a slider; 5 % steps) and Mute, and three mixes --
  Balanced (UI §8.1's defaults), Quiet focus (alerts forward, the world well down) and Atmosphere. They last
  for the session and through Restart, as the interface scale does; nothing is saved to disk.
- **Cost**: twenty residents at 4x -- all walking, twelve felling, one digging, loads changing hands, with the
  trees, bridges, notices, weather and water read too: p50 37 µs, p95 71–76 µs, p99 106–123 µs, max ≤ 230 µs a
  frame (`test/test_demo_sound_cost.gd`, headless, Apple Silicon). The boot prewarm step (streams and the
  worn-path grid) takes about 16 ms.

## Layout

| Folder | Owns |
|---|---|
| `demo_manifest.gd` | Reads the staged manifest |
| `demo_clock.gd` | The presentation clock that follows the HUD's pause and speed |
| `world/` | Terrain, lighting, village layout, points of interest |
| `cast/` | The residents: body, clips, live tail, job routines, orders |
| `control/` | Selecting and ordering residents, and the demo party panel |
| `tunnel/` | Player-dug tunnels: rules, the tunnel network and planner, planning, drawing, the underground view; and their extensions -- ground, queues, crews, jobs, hazards, finds, the demo stores, the tunnel panel; the construction theatre -- the warren's particle budget, the dig face, the baskets, the hazards' warnings, the surface signs |
| `demo_calendar.gd`, `demo_services.gd`, `village_water.gd`, `demo_notices.gd` | The one calendar, the shared set, the one water adapter (over `water/water_map.gd`), the one notice feed |
| `demo_incidents.gd`, `demo_news_clock.gd` | The incidents (open conditions, the card queue, the sound hook) and the news clock that stands still while paused |
| `weather/` | The demo's one weather (read from the farm's real §5.10 row) and its rain, snow and light |
| `burrow/` | Rooms as their own structures: the templates, sockets and refusals (`underground_rooms.gd`), placing one and its passage (`room_plan.gd`, `room_tool.gd`), drawing it (`room_view.gd`, `room_mesh.gd`); the cellar API; the fit-out (`room_fixtures.gd`, `fixture_crew.gd`, `install_task.gd`, `fixture_view.gd`, `fixture_kit.gd`, `room_text.gd`) and the night (`night_routine.gd`, `bed_allocation.gd`, `sleep_task.gd`) |
| `events/` | Seeded threats (a flood, a fire) and evacuation |
| `water/` | The stream and pond: the integer depth/shore map, carved banks, surfaces, dressing, the fishery driver, the water overlay (the Water range map layer) |
| `waterplay/` | Wading, swimming, diving, rescue and bridges: the rules, per-resident swim rows, the band and swim links, the crossings the router offers, the tasks, the bridge crew, their drawings and the Water panel; whose water range the map layer paints (`water_range.gd`) |
| `farm/` | The farm: real FarmPlot rows, the pantry and its storage providers, the Pantry's Stocks table (`farm_pantry_rows.gd`), the crew's jobs, beds, panels, alerts; the goods' models and icons, carrying and the stores' shelves |
| `kitchen/` | The meal loop: the dishes and numbers (`meal_rules.gd`), the portions (`meal_store.gd`), the ingredient holds (`ingredient_takes.gd`), nourishment, the kitchen and its places, task and words, the steam, bowls and carrying (`kitchen_view.gd`), the Pantry's Kitchen tab and the node with the kitchen pantry (`demo_kitchen.gd`) |
| `forestry/` | The woods: the trees as real ResourceNode rows, zones, deadfall, skills, the job board and crew, the yard, the drawings (falls, stumps, trunks, particles, zone marks), the pick, the zone tool and the Woods panel |
| `spoil/` | Selecting and clearing spoil heaps: the crew that digs and hauls, and the picking |
| `demo_prewarm.gd` | The boot prewarm: what would first load mid-game, loaded while the village opens; then the underground view drawn once |
| `demo_layers.gd` | The four render layers every drawn node is on, and the plane each view picks on (decision 0206) |
| `map_lenses.gd`, `lens_subject.gd` | The map layers: one shown at a time, each with its question, legend and subject; V's cycle and U's followed layer (decision 0292) |
| `props/` | The staged small props (one table, one mesh per model, icons and their roundel fallback) and the store shelf |
| `ui/` | The woodland HUD skin; the HUD date, the news strip, the village-news history, the incident card and "Go to", and the right column's tabs; the HUD's village read model (counters and ledger), the Residents roster and the village map; the Map layer picker |
| `camera/` | The RTS camera, and the canopy clearance: the eye kept out of crowns, the crowns in the way thinned, the selected shown through |
| `sound/` | The sound pass: the cue table (data), the mix and its buses, the voice pool, the event map, the owner and the Settings section |
| `assets/` | **gitignored** — staged by `tools/stage_demo_assets.py` |
