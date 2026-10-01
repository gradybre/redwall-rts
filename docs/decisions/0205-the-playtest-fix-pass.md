# 0205 — The playtest fix pass
Date: 2026-09-30 · Status: Accepted

Brendan played the Windows build of the live demo on 2026-09-29
([`docs/playtests/2026-09-29-windows.md`](../playtests/2026-09-29-windows.md)). This records what the
fix pass chose, with the numbers and why. It amends [0196](0196-the-live-demo.md) (the demo's own
record); the underground view, tunnel geometry and burrow/cellar chambers were left to the underground
revamp and are not touched here.

## Decision

### 1. Stalls: prewarm at boot, start the clock after the first frames, resolve the alert on Resume

1. **The opening pause is released after the first frames, not in `_ready`.** `demo/demo_prewarm.gd`
   lets `WARM_FRAMES` = 3 frames be drawn before the demo releases UI-SET-103's opening pause, so the
   pipelines the village compiles in its first frames are paid while paused (the playtest's first
   overload was at tick 16).
2. **What first loads mid-game loads at boot** (`warm()`, each step timed in `report`): every staged
   prop and icon (`demo_props.gd warm_all`), every plant's card atlases (`farm_assets.gd
   ensure_all_loaded`: decoded and mipmapped on the main thread, ~7 MB each), the woods' stump and
   sapling models and each tree kind's split for its fall (`forest_view.gd prewarm`). Godot compiles a
   surface's pipelines when the surface is created, so loading is what moves the compile to boot.
   Measured on the Mac at 1920x1080: props and icons 45 loaded in 36 ms, plant atlases 9 in 85 ms, the
   woods 5 in 7 ms -- ~128 ms that used to land as separate mid-game hitches. Texture memory rises by
   the atlases (~65 MB with mipmaps); accepted, since each was loaded anyway the first time a bed showed it.
3. **Resume resolves the overload alert** -- see the HUD section.

### 1-3, 6-7. The HUD: one surface per overload, fitted text, working closes, tooltips, the news bar

- **What "two stacked cards" were** (reproduced with a forced 1.2 s stall at 1x): the alert card and,
  under it, UI-SET-073's keyboard-focus description -- drawn when the history closes back onto a card,
  styled as a panel, a fixed 32 px tall, so "Warning. <the whole sentence> Open alert details." spilled
  below it; and the stall banner said the same thing again right under both.
- **One surface per condition.** While the stall banner is up it is the only overload surface: it
  prints the clock's own sentence, and the shell withholds the CLOCK_OVERLOADED card
  (`ui_shell.gd withhold_cards_with_code`, from the very call that raises it, so it never draws for a
  frame; handed back after `PENDING_MAX_S` = 0.25 s if a reported pause never lands -- counted from the
  frame after the report, since the stalled frame's own delta is longer than the grace). The notice stays
  active and in the history.
- **Resume ends the condition** (`ui_shell.gd resolve_notices_with_code`): the banner resolves
  CLOCK_OVERLOADED when CRITICAL goes, however it was acknowledged; the history keeps the row and a
  later stall regroups onto it. A 2x/4x step-down warning has no pause and no Resume, so the banner
  resolves it once the clock has run `CLEAR_TICKS` = 300 (10 s at 1x) without raising it again -- the
  playtest's "Simulation overloaded message stays throughout".
- **Fit.** The focus description is as tall as its wrapped text (a 360x240 band, flipped above a control
  near the bottom, clamped to the safe inset); a card is measured with its Label's real break flags and
  line spacing (the old measure was 6 px short on three lines).
- **Closes, each pressed in a test.** The notification history has a header "×" (Esc closes it, N
  toggles it -- not over a modal); the Pantry draws above the HUD (`LAYER` 2; the banner 2 -> 3 above
  it), so its "×" is clickable at 1280x720 where the time cluster covered it; the right column collapses
  from a new "×" on its tab strip or from a panel's own close (the bed panel's "×"), and a tab or an
  intent reopens it. The Tunnels tab reads "Tunnels" (the full name is its tooltip and the panel's
  title): with the "×" the four tabs measured 362 px in a 336 px column at 1280x720.
- **Tooltips.** Every command on the action bar reads "Name (Key) — what it does", the key read from the
  input map (so a rebinding follows), a locked one adding "Not in the demo yet: <the shell's reason>";
  an enabled command now also answers its key (a tooltip naming a key that did nothing would mislead).
  The woodland theme styles the tooltip legibly at both sizes. The party panel's Dig button says what it
  does and its key.
- **The news bar is centred on the command strip** (±1 px at 1280, 1920 and 3840 wide) and follows it
  when the journal opens; at 1280x720 it is 328 px wide, clear of the right column.

### 4. The party panel's notice line is each resident's own

`demo_command.gd say()` is the one entry for the party panel's notice (the tunnel tool, the farm, the
woods, the water and the spoil heaps all say through it). A notice is kept for every resident selected
when it was said -- except a tunnel's own news (opening, pausing), which `say_about` keeps for its mole
whoever is selected then; the panel shows the latest said to anyone selected now, and with nobody selected a
general line. Selecting the otter no longer shows the mole's "Resuming the tunnel at 44%".

### 8. Middle-mouse drag turns the camera

`demo_camera.gd`: the middle button's press arrives through `_unhandled_input` (a press on the HUD
starts nothing); while held, its motion is read in `_input`, before the tunnel tool can take it. Across
is yaw at `DRAG_YAW_DEGREES_PER_PX` = 0.3 (right turns the view right, as E), up and down is pitch at
`DRAG_PITCH_DEGREES_PER_PX` = 0.2 within the rig's 30-75 degrees. A release, a motion without the button
(a missed release) or losing focus ends it.

### 9. Faster movement, and a much smaller carry penalty

- **`demo_actor.gd WALK_PACE` = 1.4**: every creature walks at 1.4 times the gait speed recorded on its
  walk clip (decision 0202), and the walk clip plays 1.4 times as fast (`resident_brain.gd
  set_gait_speed` / `gait_rate`: clip rate = walk speed over gait speed), so the pinned feet keep their
  ground -- the stride is the clip's, the cadence rises. The mole was the slowest creature for its size;
  one factor for all keeps the cast's relative paces. A side effect kept on purpose: "a slow walker works
  longer" (`SLOW_WALK_M_S` 0.75) now finds the mole at 0.72 m/s rather than 0.52, so its routine bouts are
  about 30% shorter -- it walks less of its day, as the rule intended.
- **`resident_brain.gd CARRY_WALK_FRACTION` 0.5 -> 0.65, `CARRY_MAX_RATE` 1.6 -> 4.2.** A carry used to
  be clamped to 1.6 times its clip's own root speed, which for every staged creature was ~37% of its walk
  (the mole with a log: 0.19 m/s). Now a carry is 65% of the (raised) walk and its clip is sped to match;
  the carry clips' strides are about half a walk's, so at 0.65 they step a little quicker than a walk --
  short, hurried steps under a load -- which is why the fraction stops at 0.65 rather than nearer 1.
  Every staged creature's carry rate lands between 3.0 and 4.05, inside the 4.2 cap.
- **Swimming** (`waterplay/swim_rules.gd SWIM_MM_S`) 600, 550, 500, 1100, 900 -> 840, 770, 700, 1900, 1400
  (mouse, squirrel, mole, otter, beaver): the land creatures x1.4 with the walk, so they still swim slower
  than they walk; the otter and the beaver more, so they swim about as fast as the quicker otter walks.
  `STROKE_MM_S` keeps the part A table as the speed each stroke clip reads right at rate 1.0; the stroke
  plays at swim speed over it (`stroke_rate`), so a faster swimmer strokes faster rather than gliding.
- **Wading** stays 55% of the walk (`WADE_PERMILLE` 550), now of the raised walk, the clip at 55% of the
  walk's own rate; weather, lanterns and bores multiply the raised walk as before.

| Resident | walk m/s before -> after | carry m/s before -> after | carry clip rate | wading m/s |
|---|---|---|---|---|
| mouse keeper | 0.75 -> 1.05 | 0.28 -> 0.68 | 3.86 | 0.58 |
| mouse fieldworker | 0.69 -> 0.97 | 0.25 -> 0.63 | 4.05 | 0.53 |
| squirrel gatherer | 0.62 -> 0.87 | 0.30 -> 0.57 | 3.02 | 0.48 |
| squirrel forester | 0.68 -> 0.95 | 0.25 -> 0.62 | 4.03 | 0.53 |
| otter boatwright | 0.95 -> 1.33 | 0.36 -> 0.87 | 3.86 | 0.73 |
| otter fisher | 1.21 -> 1.70 | 0.44 -> 1.10 | 4.02 | 0.93 |
| mole digger | 0.52 -> 0.72 | 0.19 -> 0.47 | 3.91 | 0.40 |
| badger quarryman | 2.14 -> 3.00 | 0.78 -> 1.95 | 4.01 | 1.65 |
| beaver bridgewright | 0.99 -> 1.39 | 0.36 -> 0.90 | 3.96 | 0.76 |

### 10. Fewer, longer weather spells, and a lighter rain

- **Spells** (`weather/demo_weather.gd`): ordinary rain falls in spells of `SPELL_DAYS` = 3 days -- all
  of a spell's rain on its one wet day (`SPELL_WET_DAY` = 2: spring 2, 5, 8, 11; every season the same,
  12 days a season), the other two dry. A day whose own figure is `DOWNPOUR_RAIN` = 2000 or more
  (§5.10's heavy rain) still falls on its own day. A spring wet day is 3 x 1200 = 18 hours of rain
  (06:00-23:59). A baseline spring is now four spells (eight changes) instead of twelve daily showers
  (24 changes). **The beds are not moved:** each still takes its own day's §5.10 rain at midnight, so
  over a spell of ordinary days the rain on screen is the rain the beds took (a downpour inside a spell
  falls on its own day as well). The opening day is a dry day.
- **Rain look** (`weather/weather_view.gd`): rain's sun share 0.45 -> 0.75, its added haze 0.012 ->
  0.0024 (the clear day's 0.0022 again, not six and a half times it), the streaks' alpha 0.38 -> 0.30.
  The streaks say it rains; the fog that read as "a heavy grey fog over the scene" is gone.

### 11. The resident's orders list

With one resident selected the party panel lists what it can be ordered to do
(`control/resident_abilities.gd`), one short line a kind of work with what to right-click, the gated
ones said with the rule: only moles dig (`tunnel_rules.is_digger`), a body too big for a standard bore
until it is widened (`fits_bore`), only otters dive and the badger wades only (`swim_rules`), the beaver
gnaws, the badger breaks rock (`tunnel_crew`), no carry walk. Everything else anybeast does (LORE-P12).
In a short column (1280x720) the panel gives up the least useful first: the hint, then the skill and
species lines, then it folds the orders into one paragraph, then drops them -- before it would hide.

### 12. Coming back to unfinished jobs

A resident keeps the latest `RESUME_MAX` = 3 unfinished jobs it was called away from
(`resident_brain.gd` RESUMING, `cast/unfinished_job.gd`): a tunnel job (the task's `unfinished()`), a
dig with progress (`_leave_dig`), a farm job and a woods job (their crews' `_drop`), a spoil heap. When
the work that took it is done -- a task ends on its own, or a crew ends a job with `work_done()` instead
of `release()` -- it takes up the latest one that still waits for it (still posted, the same job,
nobody on it), dropping stale ones on the way; a job kept again (the same words) moves to the latest place
rather than twice. Work that ended inside a bore walks out to a mouth first and takes the job up there --
a job is never started from inside a bore. The player's R forgets them all (a crew that notices the release
a frame later keeps nothing: it keeps a job only for a worker ordered elsewhere, never one released). In
the water it swims ashore first and keeps them. A paused dig is held by a small `DigBack`, never by a
Callable on the brain (that would be a reference cycle the brain could never be freed from). The party panel says "Then back to: ...". Rejected: re-queuing the job on
its board for the crew, which gives the playtest's lanterns to whoever wanders past, or to nobody (the
tunnel works have no hand-out).

### 13. Spoil heaps: select and Clear

`demo/spoil/`: a left click on a heap selects it (a brass ring; the notice says how much it holds);
right-click (or C) with residents selected clears it. A basketful is the farm's own load off a heap
(`LOAD_MILLI` = `farm_jobs.SPOIL_PER_JOB_MILLI`, 2 U), dug in the farm's dig work (2 WU, 3 s) and tipped
in its drop work (1 WU, 1.5 s), at most `MAX_PER_HEAP` = 4 on a heap; only residents with a carry walk.
**Where it goes:** the demo's one use of spoil is compost (the farm's Compost job digs a heap as a bed's
compost), so it is hauled into the farm's compost store, tipped by the open stockpile. Every milli-U is
taken through the farm's own spoil books (`farm_tunnels.take_spoil_into`, the ones Raise and Bank take
from) and delivered, or in a basket; a worker called away tips its basket into the store and keeps the
heap to come back to. (*Amended by [0361](0361-explicit-arrival-crew-hand-offs-and-routes-planned-across-frames.md):
a basket reaches the store only by being tipped at the drop spot; a worker called away puts it back on its heap.*) (*Superseded by [0401](0401-spoil-becomes-earth-not-compost.md): a heap is earth, not compost; it is hauled
into the village stores' earth, which Raise and Bank can fetch.*) The emptied heap stops being an obstacle (its spot stays in the network, where a
widening re-heaps) -- and one that takes spoil again (a fall cleared, a chamber dug) is an obstacle again.
Each emptied heap rebuilds the cast's obstacles, so the next plan of each body class pays its graph
rebuild (about 11 ms, `cast_space.set_heaps`) -- accepted: it happens once per heap cleared. Moving a
worker to another heap closes its old row quietly. Only a finished tunnel's heaps are cleared.

### 5, 14. The farm

- **The bed panel shows only its bed** (`farm/farm_bed_panel.gd`): the three lines of the farm's notice
  feed are gone (the news strip carries the feed). With a bed: its title, one **Needs:** line naming its
  most pressing work in right-click's order and why ("Needs: Drain — waterlogged, not growing"; clay for
  a warning, hidden when nothing presses), the readouts (the stage line says why growth stalled), the
  verbs. Without one: the date and the hint.
- **Drain** (`KIND_DRAIN`, 6 WU: the same spade-work as raising or banking): a wet or waterlogged bed's
  moisture drops at once to the top of its crop's band (integer, through the sim's own moisture delta)
  and the bed is ditched for good -- a ditch sheds up to `DITCH_DRAIN_PER_DAY` = 1000 a day toward min +
  500, between a tunnel's 1500 and raising's 800. Refused ("not too wet") otherwise. Right-click's order:
  clear > harvest > drain a waterlogged bed > water a dry one > cover (from the noon warning, not on a
  raised bed) > sow.
- **A softer first spring** (demo values only; the §5.10 tables in `scripts/core/` are untouched):
  every bed sheds up to `NATURAL_DRAIN_PER_DAY` = 500 a day above its band's top (well-drained village
  loam), so only the forced Ideal spell waterlogs a roots bed, on spring 8 (it was spring 6, with the
  wheat too); `farm_weather.gd FROST_NIGHT_MASK` spring 4 and 9 -> the night into spring 11 (warned at
  noon on spring 10); `BLIGHT_MASK` spring 7 -> spring 12. The first waterlogging, frost and blight now
  fall on days 8, 10-11 and 12 (a test walks the first spring with the real sim and pins it), not all
  together by spring 6.
- **Looks** (`farm_look.gd`, `farm_bed_visual.gd`): a wet bed's soil is a mild dark film and a
  waterlogged one a darker, glossier film with seven soft, lobed puddles of dark blue-grey water (one
  MultiMesh a bed, built once) -- not a flat pale-blue sheet; the V overlay's wet and waterlogged
  colours are muted slate tints. A raised bed is two stacked planks a side (grained, three tones,
  jittered, a gap between) and four taller corner posts under the bed's own lifted soil, not a brown
  slab; a banked bed a rounded, speckled soil berm; a ditched bed a dark matte trench with a spoil lip.
  The staged `bridge_plank` was not usable for the boards (a whole bridge, its texture an atlas).

### 15. Trees and buildings flush in the ground

`world/world_sizes.gd SINK_M`: a staged model is let down into the flat ground by its own base,
MEASURED from each model at drawn scale (never by eye), in one place every construction path uses
(`demo_world.gd piece_transform`, so replanted trees agree): oak 1.20 m (its mound's shoulder: median
surface 1.39 m at 2 m out, 1.05 at 3 m), beech 0.50 (a flat-topped mound, median 0.44-0.45), residence
0.42 (a stone plinth 0.36-0.41 m), covered store 0.12 and kitchen 0.11 (earth slabs to 0.11), workbench
0.07 (its earth border). Not sunk: the hall (its post footings stand on the ground), the well (its
apron), the open stockpile (a raised deck), the fence, stumps, saplings, props and every placeholder.
The oak's roots now run into the ground by ~3.5 m, its flare at most ~0.2 m proud. `forest_roots.gd`
heights are above the ground after the sink (0 where the mound is buried), so the walkers' lift, the
fall's pivot, the stump and the shoot agree; the split still cuts the MODEL at its own height
(`model_cut_m`). Rejected: a ground-tint ring under every tree (the ground shader would loop over ~170
trees a pixel).

### 16. Water part A leftovers

- **The badger's slot.** The 0.42 m was part A's probe measuring from the badger's resting point; the
  exact slot, stockpile[0], cleared 0.373 m -- and every POI slot was short of the badger's 0.561 m body
  plus 0.12 (stockpile 0.373, cauldron and hall table 0.400, workbench, log stack and store front 0.350,
  hall steps 0.598, well 0.504). But clearance was not what made it give up: stockpile[0] sits in a
  pocket (the wheelbarrow, the pile, the east slot) that, with someone in the east slot, left 0.81 m for
  the badger's 1.12 m width, and it was held back until it abandoned. Both are fixed:
  `cast/cast_space.gd` keeps every slot `SLOT_BODY_MARGIN_M` = 0.12 (the ordered spots' own
  `cast_orders.CLEAR_MARGIN_M`, pinned equal by a test) beyond the widest registered body -- 0.681 m in
  the real cast -- walking a short slot straight out from its nearest circle (`SLOT_PUSH_PASSES` = 6),
  re-placed when a wider body registers; the water's edge alone never pushes a slot. And the stockpile's
  spot moves along its front, `along` 0.0 -> 0.75 m (0.6-0.85 clears the otter-neighbour case; only 0.75
  also clears two badgers side by side). With the old slots the badger was off its order 28 of 40
  half-seconds at the stockpile; now 0 of 40 at the stockpile, the cauldron and the hall steps.
- **The fishery overlay's labels** (`water/water_overlay.gd`): two lines a site (site, quota and slots;
  each species' stock and state) instead of five; laid out every frame the overlay shows, the lowest over
  its landing and the others rising just clear (`LABEL_GAP_PX` = 6), nudged inside the view while their
  landing is on screen; drawn from their anchor and after the zone paint (render priority 4, outline 3),
  which had washed them out. A site whose landing the map lacks is hidden with a warning, not drawn at the
  world origin. Given up: the hand-net catch preview and the season/day line, which belong in the Water
  panel and are not shown there yet.
- **The rescuer by route length** (`waterplay/rescue.gd`): candidates are ranked by the planned route to
  where each goes in -- a swimmer's own connection plus twice its straight swim on (the swim links'
  weight, 2.0), a thrower's landing -- with the straight line as a lower bound, planning in bound order
  and stopping once no bound can beat the best route. An unroutable candidate wins only if nobody else
  can route. At most `MAX_PLANS` = 4 routes are planned a ranking, nearest bound first, so a dispatch with
  nobody routable never plans the whole cast in one frame. Dispatch still runs once a second. `cast_nav.path_length` sums a planned path.

## Why

The playtest's notes are Brendan's; each item above answers one. Everything here is presentation: the
simulation's rules, clock and stores are untouched, integer state stays integer (spoil in milli-U,
moisture in its 0-10000 scale), and the new numbers are named demo values with their reasons at their
definitions.

## Consequences

- **Measured** (Apple Silicon Mac, Metal, 1920x1080, the demo's shader and pipeline caches moved aside
  before each run, 300 s at 1x; "events" = two test threats, four weather skips, a storm gust, the
  Pantry opened and 130 s at 4x):

  | Run | Worst frame | Frames > 50 ms | Clock diagnostic pauses | Pipeline compiles after the opening |
  |---|---|---|---|---|
  | before, no events | 11.7 ms | 0 | 0 | (not counted in this run) |
  | before, events | 11.0 ms (a threat) | 0 | 0 | (not counted) |
  | after, no events | 17.6 ms (76 s, no event) | 0 | 0 | 2 background specializations |
  | after, events | 15.3 ms (the Pantry opening) | 0 | 0 | 1 canvas (the Pantry), 4 background specializations |

  A repeat "before" run with the compile counter (other work running on the machine, so its frame times
  are not comparable: worst 38-39 ms) counted the same: no draw-time pipeline compile, a canvas compile at
  the Pantry. The Mac does not reproduce the Windows stalls either way: Metal compiles quickly and the
  OS keeps its own shader cache. What the prewarm moved is measured by its own timing: ~130 ms of first
  loads (45 props and icons 35-38 ms, 9 plant atlases 80-89 ms, the woods 8-10 ms) now paid at boot
  while paused, instead of as separate hitches during play -- several times that on a slower PC's disk
  and CPU -- the likely source of the playtest's mid-game stall at tick 4616, which the Mac cannot
  reproduce. The Windows stalls cannot be measured
  here; the prewarm removes their known causes outside the underground view. The first U toggle's
  stall is the underground revamp's (its P0 prewarm registry can register steps with
  `demo_prewarm.gd add_step`).
- Walk, carry and swim speeds are demo values on top of the recorded gait; a real movement system
  (MOVE gates) will own them.
- **For the underground revamp:** register the underground view's warm-up with `demo_prewarm.gd
  add_step` (the opening waits for it); the walk pace applies in bores too, so a stoop must play its
  clip at `resident_brain.gd stride_rate()`; a tunnel job's `unfinished()`/`take_back` and a dig's
  `_remember_dig` are how interrupted underground work is resumed -- keep them when jobs and digs are
  re-keyed to segments; spoil clearing reads `network.heap_at`/`heap_radius_m`, the farm's spoil books
  and `cast_space.set_heaps`; the sunk trees' buried root balls show under the U view's see-through
  veil; the party panel's notice is per resident (`demo_command.gd say`), so the tunnel tool's prompts
  follow the mole. Farm `Label3D`s still draw through the U view.
- Open: the fishery's catch preview left the overlay labels and is not yet in the Water panel; the
  Pantry's first opening still compiles one canvas pipeline (15 ms on the Mac); the bridge crew's and the
  rescue's `work_done` (in place of `release`) are exercised only through the brain's own tests.

## Source

The playtest record; decisions 0196, 0202 (gait speed), 0195 (carry root motion); REQ-SET-008
(the clock's diagnostic pause); farm_jobs.gd's WU and spoil dose (§5.6); §5.10 (rain per day).
