# 0441 — The weir's sluice feeds a bounded garden leat: three beds, three settings, three discrete services
Date: 2026-10-01 · Status: Accepted

**Numbering.** Water part B runs in lanes: lane 1 (boats, fishing, gear, ice, smoking, the mill) takes 0431–0439,
this lane (the weir's irrigation and the otters' songs) 0441–0449. No record numbered 0440–0449 exists on any branch
or worktree; 0442 is this lane's other record.

Brendan approved water part B (2026-10-01). This is the review's **ECO-006** ("Explicit irrigation and drainage",
`redwall-review/REVIEW.md` 2315–2337, read-only): deliberate water-service fittings instead of "any tunnel irrigates",
a small discrete wet / normal / dry model, an affected-bed preview, a transport-only choice kept, and **full
hydrology excluded**. The review says ECO-006 needs "an adopted water-service decision": for the live demo, this is
it. The GDD has no irrigation (its weir is a fishing structure, §5.4); everything here is a **demo rule** over the
farm's existing moisture model, like decision 0196's tunnel irrigation and 0205's Drain.

## Decision

### The zone: Bed 2, Bed 4 and Bed 6

The six beds stand in a 2 x 3 block on the village's west side (`world/world_layout.gd` CROPS); none is near the
stream, which runs down the east edge, and the demo has no mill race (the mill is lane 1's). So the leat is a
**covered culvert** from the weir under the village (not drawn) to a **leat head** -- a small timber basin at the
north-east corner of Bed 2, (-7.45, 7.3) -- and along the beds' **east column**, the side nearest the stream:

| Zone order | Bed (panel number) | World crop id | Soil | Opening crop |
|---|---|---|---|---|
| 1 | Bed 2 | `bed_cabbage_e` | clay | empty |
| 2 | Bed 4 | `bed_roots_e` | loam | radish |
| 3 | Bed 6 | `bed_grain_e` | loam | wheat |

Bed 1, 3 and 5 (the west column) are **not served** whatever the sluice does. The head is one land obstacle (radius
0.55 m) so nobody walks through it.

### The sluice: three settings, a table of services

The sluice is a player control with three settings, never a flow rate: **Closed**, **Half**, **Open**
(`water/weir_sluice.gd`). Each zone bed's water service is one of three discrete states, read from one table:

| Sluice | Bed 2 | Bed 4 | Bed 6 | Leat flow (presentation) |
|---|---|---|---|---|
| Closed | dry | dry | dry | 0 |
| Half | normal | normal | dry | 500 ‰ |
| Open | wet | wet | normal | 1000 ‰ |

The water reaches the beds in zone order, so the far bed is a step behind. **The demo opens Closed**: the zone is
dry, which adds nothing (below), so the opening garden -- and 0205's tuned first spring, whose Ideal spell waterlogs
the radish in Bed 4 at the midnight opening spring 8 -- is exactly as before. A test runs three days with the sluice
closed and with no leat at all and finds every bed's moisture equal.

### What each service does: through the existing moisture model

At each farm midnight (`farm/farm_sim.gd` THE GARDEN LEAT, `day_delta`, through `apply_moisture_delta()`):

| Service | Its effect, per farm day | Demo constant |
|---|---|---|
| wet | raised toward **1000 over the band's top** (the middle of the WET band, which is MOISTURE_NEAR_MARGIN 2000 wide); never lowered | WET_ABOVE_TOP 1000, at most LEAT_PER_DAY 1500 |
| normal | moved toward the **band's middle**, up or down -- as a tunnel irrigates (decision 0196) | at most LEAT_PER_DAY = IRRIGATE_PER_DAY 1500 |
| dry | **nothing**: the leat runs empty | -- |
| (not served) | nothing | -- |

- **The leat's share is worked on the bed's moisture as the day left it**, before the night's weather (the
  midnight records each bed's moisture before `run_day_into`). The panel's preview reads the bed during the day, so
  its "+15% from the leat" is exactly the leat's own share; the night's weather and the natural drainage above the
  band's top come on top of it, so a bed near its top keeps less (Bed 2 at 7600 opened: the leat adds 1400, a +600
  spring night takes it past 8000, and the loam sheds 500 where it would have shed 200 -- 1100 more than closed). The
  preview names the share, not the net: the net depends on tonight's weather, which is not known. (On the moisture after the weather, a
  "normal" preview of +10 % became +4 % after a +6 % spring day -- the preview would have lied. Tunnel irrigation is
  unchanged and still works on the moisture after the weather.)
- Natural drainage (500 a day above the band's top, decision 0205) still applies after the leat: a wet bed at its
  top settles at 500 over it, in its WET band.
- **Dry adds nothing; it does not drain.** Rejected: a dry (empty) leat shedding water like a ditch. It would have
  made the opening sluice drain Bed 4 and cancelled 0205's tuned spring-8 waterlogging, and silently changed every
  existing bed history; the Drain job (0205) is the farm's drainage.

### Tunnels and the leat

Decision 0196's tunnel drainage and irrigation (`farm_tunnels.gd`) are unchanged and recomputed hourly as before.
The leat is combined in `day_delta`:

- a bed the leat **waters** (normal or wet) takes the leat's water **instead of** a tunnel's irrigation, and is not
  drained that day by a tunnel, a raised bed or its ditch (as a tunnel-irrigated bed already was not);
- a bed the leat leaves **dry** (or does not serve) keeps exactly what its tunnels, ditch and raising do.

So a **travel tunnel never changes because of the sluice**, and closing the sluice puts every zone bed back where the
tunnels alone would have it -- the review's "transport-only choice" kept.

### Floods

The demo's flood is the tunnels' threat (`events/demo_events.gd` KIND_FLOOD; real time, about 40 s). The leat follows
it once a frame (`farm/farm_leat.gd` `follow_flood`):

- **While a flood runs and the sluice is not closed**, an incident (`leat:flood`, WARNING, Farm, targeted at the first
  bed at risk) says what the flood will do and how to stop it: "Flood at the weir with the sluice open. Flood: left
  like this, it waterlogs Bed 4 and wets Bed 2 and Bed 6 as it passes. To spare them, close it (Farm ▸ Sluice…)." The preview adds
  the same flood sentence and each bed's rise.
- **Closed in time**, the incident resolves and nothing happens. **Opened during a flood**, the incident comes.
  Changing the setting while it is open rewrites its words in place; the feed is warned once a flood, not at every
  turn of the wheel.
- **When the flood passes with the sluice still open**, at once: a wet-served bed is raised to its band's top + 2000
  + 500 (FLOOD_OVER_WET: past its WET band, so waterlogged), a normal-served bed to its top + 1000 (wet), never
  lowered, capped at the moisture scale's 10000. (Bed 2's empty band reaches 10000 at its WET band's edge, so it can
  only be wetted; the preview's words follow the resulting band, not the service.) The feed says which beds and
  what band; the incident resolves; the waterlogged beds raise the farm's own wet incidents (0331), answered by Drain.
- A dry bed takes no surge.

### The order, the card and the preview

- **Click the weir** (the click ray meets a box over the fitted footprint grown 0.15 m, from 0.25 m under the
  ground datum to 0.75 m over it; asked AFTER the water's play, so a bridge at the `weir_bank` landing is still that
  play's click) or a bed's **Sluice…** (the bed panel's twelfth button): the farm panel shows "Weir sluice · garden leat":
  the setting, the zone in words, **Close / Half / Open** (the setting now lit and refused), and the **affected-bed
  preview** for the setting under the pointer or keyboard focus, else the setting now: one sentence ("Open: Bed 2 and
  Bed 4 go to wet, Bed 6 to normal. Bed 4 is already waterlogged.") and a row per bed ("Bed 2 · good now · leat dry →
  wet · +15% from the leat"). Esc closes it.
- **Each button's tooltip is its action card** (decision 0332): "Sluice: Open", the preview as its result followed
  by "At once, no cost; the beds' water changes at the next midnight." (so no Work or cost line), "Who: the sluice
  wheel on the weir (no one walks there: demo)", "Needs: the weir (it stands across the stream)". The card and the order share one refusal (`refusal`): the setting it
  already has ("the sluice is already open"), or no such setting.
- **The order is done at once and costs nothing.** No resident walks to the wheel: a demo simplification. A worker
  job (walk, turn the wheel) is a later step and would make the card's Who and Work real.
- A served bed's panel says its service under its moisture: "Garden leat: wet (sluice open)".

### The map layer

J's map layers (decision 0292) get **Growing: Water service** -- "Which beds does the weir's garden leat water?" --
the beds' discs by service: not served, dry (leat empty), normal, wet. V's cycle is now off, moisture, ripeness,
water service, water range, woods, off.

### Drawn (presentation only)

- **The gate.** The fitted weir keeps the library model's gate bay (between the posts under the wheel; decision
  0301's fit leaves that middle part as made). Its baked board is taken out of the mesh -- faces centred in model
  units x 0.30–0.44, y 0.25–0.86, z −0.13–0.12 (`weir_gate_view.gd` `open_bay`) -- and a three-plank timber board of
  our own hangs in the bay, a child of the weir so it shares its scale. It rises 0.30 model units at Open (half at
  Half), winding at 0.22 a second **on the demo clock** (it freezes while paused, runs 2x / 4x with the game).
  Unstaged, the board hangs in front of the placeholder wall and still rises.
- **The gush.** While the board is up, a patch of broken white water (unshaded white, noise in its alpha) lies on the
  tail water below the bay, its strength the lift.
- **The leat head** (two courses of timber planks, the beds' own edging) holds water drawn with the **stream's own
  water material** (the same instance, so it flows with it): empty at Closed, half full at Half, brim full at Open.
- **The one-level limit.** The stream has one level per body (decision 0301), so the sluice does **not** lower the
  weir pool or raise the tail water; the gate, its gush and the leat head's water show the setting instead. The leat
  between the weir and the garden is a covered culvert and is not drawn.

## Why

- Bounded, discrete and legible, as the review asks: three settings, three services, three beds -- a player predicts
  what rain or drought does to each bed from the table, and the preview says it before the change.
- The table, the order, the card, the preview and the midnight all read the same functions (`service_for`,
  `leat_delta`, `flood_surge`, `refusal`), so they cannot disagree.
- No new moisture rule is invented beyond the leat's own three rows; every application goes through
  `apply_moisture_delta()`, and the constants reuse 0196's and §5.6's numbers where they exist (LEAT_PER_DAY is
  IRRIGATE_PER_DAY; the WET band is MOISTURE_NEAR_MARGIN wide).

## Consequences

- A fourth zone bed, or another setting, is one row of `SERVICE_TABLE` (and its tests); the zone order is the leat's.
- `farm_sim.gd day_delta` now takes the leat's service and the bed's pre-weather moisture; anything else that wants a
  midnight's preview should read it, not reimplement it.
- The bed panel's action grid has twelve buttons (Sluice… is the twelfth).
- Lane 1's mill and any later mill race may draw a race channel; the leat is separate from it.
- Open: a resident to turn the wheel (a job); seasonal tuning (the review's last implementation slice); a drawn
  leat channel if the village is ever laid out with the beds by the stream.

## Evidence

- `test/test_weir_sluice.gd` (20 tests, no staged assets): the table, the order and its refusals, each service
  through the moisture model, the leat yielding to no drain, a closed sluice equal to no leat over three days, the
  preview against two farms' first midnight (and a bed near its top keeping less than the share), the preview's
  words, the card, floods (incident, surge, closing in time, opening mid-flood, one warning a flood), the tunnels'
  real flood reaching the garden through the farm's frame, the bed panel's weir view and Esc, the Water service layer,
  the gate's winding, `open_bay` and the pick. `test_demo_farm_ui.gd` and `test_demo_map_lenses.gd` follow the
  layer's new place in V's cycle. The suite line is in the lane's hand-back.
- Mutation (shared with 0442; `scratchpad/weir_check/mutate.py`, one mutant at a time, each file restored and its
  SHA-256 checked): 109 mutants over the new logic, every one killed in the end. The first pass left 7 alive (the
  preview read the setting now's service; the flood rise outside a flood; the head's level; a missing context; a
  joiner outliving its lead; walking home; the layer's binding) and the review's added set left 1 (lying down while
  free): each was answered with a test.
- A live pick through the village's real handler chain: the weir's crest takes the click and shows the sluice; open
  ground does not; a bed is still the farm's.
Frames in `scratchpad/weir_check/`: the sluice closed, half and open from downstream and above; the leat head empty,
half and full; the panel showing the setting now and the preview of Open; a served bed's line; the Water service layer.

## Review

The independent `code-reviewer`: no CRITICAL. HIGH, fixed: the integration paths were untested (8 of 10 of its
mutants survived) -- now an end-to-end test brings the tunnels' real flood through the farm's frame, a raised and a
ditched bed are tested against the leat, and the songs' supper, work-board and hum paths are tested. MEDIUM, fixed:
the preview claimed to be "what the midnight adds" while the loam's drainage above the band's top takes some of it
-- it now names the leat's own share (tested at 7600: share 1400, net 1100); the weir's pick took clicks meant for the
weir bridge -- it is now asked after the water's play and is a box test; toggling the sluice in a flood re-posted the
warning -- once a flood now; three functions over 30 lines split. LOW, fixed: the gate is not redrawn at rest; the
header cited a function that does not exist. (Its songs findings are in 0442.)


## At the batch 5 integration (2026-10-01)

- **The map layers.** "Growing: Water service" stays the farm's third layer, after ripeness; P's "Getting there:
  Routes" now sits beside "Getting there: Water range" (it was added after the woods). V steps off, moisture, ripeness,
  water service, water range, routes, woods, off. The lens tests that count layers count both.
- **The bed panel.** Its verb grid carries both "Sluice…" (this record) and O's "Compare…" (0451). Showing the weir
  closes an open Compare view, as showing no bed does.

## Source

Review ECO-006 (`REVIEW.md` 2315–2337) and the digest's guidance (`review_digest/part1.md`: "bounded, discrete
water service zones … no full hydrology"); Brendan's approval of water part B (2026-10-01); decisions 0196 (tunnel
drainage and irrigation, the moisture rules), 0205 (Drain, natural drainage, the tuned spring), 0292 (map layers),
0301 (the weir fitted; one level per body), 0331 (incidents), 0332 (action cards), 0421 (the ten-minute day).
