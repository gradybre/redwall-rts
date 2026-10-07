# Live demo — a small Mossflower village

A presentation-only demo (decision 0196). It boots the real game — settlement, simulation clock,
HUD, UIManager — and draws a small village of real library assets on top: buildings, trees,
crops and props at game scale, and nine real rigged residents -- an original community, each named (see People) --
who walk between work spots with live tail springs (`TailRig`, decision 0194), grounded clips (0193) and
stride-matched speed.
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

`python3 tools/build_demo_windows.py --out <folder>` makes a standalone Windows playtest copy (a debug export;
`--release` for a final build, decision 0562) -- a folder
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
  fade and the selected residents' silhouette, two of the frost and snow overlay on the village
  (decision 0301), two of the night's light (decision 0541), and two of every falling leaf below the ground, after the
  trees' bare boughs are made (decision 0551), so a first fade, a first selection under a crown, a first frost, a first
  dusk and a first autumn cost no compile. While the banner
  is up it is the one overload surface (the HUD's CLOCK_OVERLOADED card is withheld); Resume resolves
  the notice, and a 2x/4x step-down warning (no pause) is resolved once the clock has run 10 s quiet.

## For playtesters: the crash and error log (decision 0562)

Every run of the demo writes a **playtest log**, one file per session, beside Godot's own `godot.log`:

| System | Folder |
|---|---|
| Windows (the build) | `%APPDATA%\Godot\app_userdata\Redwall Demo\logs` |
| macOS (an exported copy) | `~/Library/Application Support/Godot/app_userdata/Redwall Demo/logs` |
| Run from the project | the same, with `Redwall RTS` in place of `Redwall Demo` |

The file is `playtest-<date>_<time>-p<process>.log`, and the newest sorts last. The folder keeps the last ten sessions.
Each file holds at most 2 MiB, with a reserve so that marks, freezes and the session's end are still written.

**In the game.** Press **F12** the moment something goes wrong (on a Mac keyboard, Fn+F12). It writes a numbered
*mark* with the time and the last 24 breadcrumbs, and a toast says "Marked #n". **Game menu → Settings → Playtest log**
shows the folder and has three buttons:

- **Open log folder**, which opens Explorer or Finder;
- **Copy report**, which copies this machine's details and the session's last 120 lines to the clipboard, with no paths;
- **Mark a problem here**, which does the same as F12.

Help's "Something went wrong? Report it" topic says the same, and its button opens the folder.

**What a file holds** (`demo/playtest/`):

- **A header.** It records the start time and UTC offset; the version, which is the commit a build was made from
  (`demo/build_info.json`, baked by the build script) or `dev <commit>` from git in a project run; and the build type
  (export or project, debug or release). It then records Godot, the OS, CPU and memory, the graphics adapter, its
  driver (Windows reports it; macOS does not) and the rendering method and driver actually running, after any
  fallback. Last come the screen, the window (its mode, size and vsync), the demo's settings with the presets
  fully in effect, and the language. It also records whether **the previous session ended cleanly**. A missing end
  marker means a crash, a forced quit or a hang, and the header names that file, so the tester knows to send it too.
- **Breadcrumbs**: a 64-entry ring of notable events, written in batches at most once a second:
  - the village built, opened and restarted;
  - the modal on top of the input gate opened and closed (the game menu, the Pantry, the Lab, Work and so on);
  - the right column's panel, the underground view, the map layer and the layer compared with it (decision 0581);
  - every order, accepted or refused, with how many residents were selected, plus Dig tunnel, Release and the room
    buttons;
  - the clock's speed and state;
  - each village-news post (its source and level only).

  There is never one per frame, and none holds typed text or anything about the player.
- **Errors**: every `push_error`, `push_warning`, GDScript runtime error, engine error and `printerr`, caught through
  Godot 4.7's `OS.add_logger`. Each is written with its place and up to six script frames, and the breadcrumbs before
  it are written first, so the file stays in time order. A line repeated more than five times is only counted.
- **A heartbeat every 30 s**: the game's date and speed, the frame rate and the worst frame, the slow frames (over
  100 ms), memory and video memory, object, node and orphan counts, and the error totals.
- **Freezes.** A frame longer than 3 s once the village runs (20 s while it loads) is written when the game recovers,
  with the breadcrumbs. A watch thread writes the same freeze *while it is still going*, so a hang the tester ends by
  killing the game is in the file too.
- **The end**: `== session end` with the totals. Every line is flushed as it is written.

Home and user-data folders are replaced by `~` and `<user data>` in every line. Nothing is sent anywhere: the tester
sends the file.

**What the tester can paste** (Brendan's message to a playtester):

> If anything goes wrong -- a crash, a freeze, something odd -- press **F12** right then (on a Mac, Fn+F12), then
> carry on or quit. Afterwards, open the game menu (Esc) → Settings → Playtest log → **Open log folder**, and send
> me the newest `playtest-….log` file. If the game crashed and you have started it again since, send the newest
> two, since the crashed session's file is then the second-newest. `godot.log` in the same folder helps as well. If you can't find the folder, it is
> `%APPDATA%\Godot\app_userdata\Redwall Demo\logs` on Windows (paste that into Explorer's address bar) or
> `~/Library/Application Support/Godot/app_userdata/Redwall Demo/logs` on a Mac (Finder → Go → Go to Folder).
> **Copy report** in the same place puts a summary on the clipboard to paste into a message.

**The Windows build.** The build needs nothing new to switch this on:

- `debug/file_logging/enable_file_logging.pc` is on by Godot's default, release exports included, and
  `test_demo_playtest_log.gd` pins it.
- The build script bakes `demo/build_info.json` before the export and removes it afterwards. The pack's verification
  fails if that file is missing, or if the log did not start.
- The README in the zip says where the logs are.

**Playtest builds are debug exports** (Brendan's ruling, 2026-10-01): `build_demo_windows.py` exports with
`--export-debug` by default, and `--release` makes a final build on the release template. The reason, measured on the
4.7.2 **release** template (the macOS one, which runs the same engine code as Windows'):

- a method called on null **ends the process at once** (signal 11), with no message anywhere;
- an out-of-range index raises nothing;
- `print` output that has not been flushed is lost.

The **debug** template reports both as SCRIPT ERRORs with script frames, and carries on. The packed build info names
the mode, the header quotes it, and the pack check fails when it is not the mode asked for (decision 0562). With a
release build, the breadcrumbs and the unclean-end note are what explain a crash.

## Time

The demo opens running: `Game` starts the real clock and UIManager holds UI-SET-103's opening
inspection pause, which the demo releases once, after its first three frames are drawn (the prewarm). From then on the HUD's pause and
1x / 2x / 4x buttons (and Space) are the game's own, and the whole village follows them through one
presentation clock (`demo_clock.gd`): residents' walking, turning and work, digging and walking
tunnels, the mound over a digger and every resident's clip. Paused, everyone holds their pose;
at 2x and 4x they move and dig two and four times as fast. The camera, the HUD, the demo party
panel and the selection and order marks stay on real time, so the player can still select, order
and dig while paused -- the orders are carried out on resume.

## Time controls: the pause types, Resume and "Run until…" (decision 0471)

Review UX-022 (`session/`). **Every pause says why, and there is one Resume.**

- **The pause card** (`ui/demo_pause_card.gd`) stands in for the HUD's "Paused: PLAYER" line, top centre: "Paused —"
  and each reason in words, most urgent first, then **Resume (Space)**. Its tooltip says what Resume clears. While a
  pop-up is open (the Pantry, the Work screen, the object list) it sits bottom centre above it. Otherwise it steps below
  the one card shown at the top centre under the alerts -- the incident card, else the first-village guide's card, else
  the people's offer card -- and steps back the frame that card goes or changes size. It is always one row (two when the
  words wrap) and takes the mouse only on its own panel (decision 0931: windowed, it once grew to about 435 px at 1080p,
  because its wrapping words were measured at their hidden 1 px width, and it swallowed the clicks there).
- **The kinds** (`session/pause_ledger.gd`): *Critical* -- a critical incident (a resident in difficulty in the water, a
  tunnel threat), with "Pause on a critical incident" on (the default), or a stall (the stall banner's own, as before);
  *the game menu*, or *the village guide* (its window holds its own MENU hold, so neither releases the other's);
  *Planning* -- the Pantry, the Work screen, the seasonal planner (T), the village news, the Residents list, the object
  list or the Dig tool open, with "Pause while planning" on (off by default, UI §8.1); *You paused* -- Space, the HUD's pause button,
  or a "Run until…" that arrived ("Reached dawn: Y1 Spring 2, 06:00").
- **Resume** -- the card's button, Space while paused, or the HUD's pause button pressed while paused -- clears your
  pause, a planning pause and a critical pause. It never closes the game menu (its own Resume does) and never
  acknowledges a stall (the stall banner's Resume, which drops the owed time, does). After Resume a planning surface left
  open stays unpaused until every one has closed. **Panels never override your pause**: closing one lets go of its own
  planning pause only. The menu, a planning surface and a critical incident share the clock's MENU reason through the
  ledger, so closing the menu never lifts the others.
- **Run until…** -- the button in the time controls (in the cluster's first row, right of 4x; left of the cluster at the
  narrow profile), or **G**: a menu with the speed (1x / 2x / 4x) and six targets, each saying when or why not --
  **Dawn** (06:00, the night routine's), **Dusk** (20:00), **Next meal** (the kitchen's 07:00 or 17:00 call), **Project
  done** (the selected room being dug, else the selected tunnel being dug, else the bridge planned at the Water panel's
  site), **Harvest window** (a bed coming ripe), **Next warning** (a new warning line, not of a snoozed kind, or a new or recurring incident; decision 0591). The village runs at the
  speed, then pauses saying where it got to. The calendar targets land **on the tick** (the demo clock's next frame is
  capped, `demo_clock.gd limit_usec`): from 05:40 at 4x, Run until dawn stops at 06:00:00. Any pause or critical event
  first cancels the run, and the card says so ("Run until dawn cancelled: paused (you paused)"); the button reads
  "■ Dawn" while it runs, and the menu has **Stop the run**.

## One village: one calendar, one weather, one water, one feed

The farm and the tunnel works were built apart; in the demo they are one village (the woods too), sharing four things
that `demo_village.gd` makes once (`demo_services.gd`) and hands to both:

- **One calendar** (`demo_calendar.gd`). Farm time, the weather's hour and the **date the HUD shows**
  are one tick counter on the real offset calendar, run on the demo clock at the GDD's own rate: a game hour
  every 25 demo seconds, 30 ticks a second, a day ten minutes at 1x (decision 0421, Brendan's ruling; it was a day
  a minute until then). Everything on the calendar reads its time from it and keeps no conversion of its own;
  walking and work run on the same demo seconds, so a resident covers 18-26 m a game hour. The farm's model
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
  filtered by place (*All*, *Farm*, *Woods*, *Tunnels*, *Water*, *Village* -- weather, threats, the crew's
  reports and the village's chronicle, a finished guide or project (decision 0481); the first place picked shows it alone, more add to it) and by tier (*All*, *Urgent*, *Normal*, *Info*; decision 0591, below).
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

## Better notices: tiers, kinds, grouping, snooze and the toast budget (decision 0591)

Feature #39 (`demo_notices.gd`, `demo_notice_snoozes.gd`, `ui/demo_news_strip.gd`, `ui/demo_news_history.gd`).

- **Tiers.** Each notice is *urgent*, *normal* or *info*.
  - Urgent: the heading face, clay, "Urgent:", 60 s on the strip, and two chimes.
  - Normal: clay, "Warning:", 30 s, and one chime.
  - Info: ink, unworded, 12 s, and silent.
  - A tier never pauses. A *critical incident* pauses through the ledger, as before.
- **Grouping.** A notice that names its kind joins the same kind about the same subject said within a game day.
  "Crows at the barley (×3)" moves to the top, and does not chime again.
- **Strip.** Each line has a Go to (the centre-view crosshair: it selects the subject and centres the camera) and a ×
  (dismiss that one).
  - The title counts the lines held back: "· 6 more (N)".
  - Where the lines would not fit the band (1280×720), it draws fewer, keeping the most urgent.
- **Village news (N).** The severity filter is a tier filter: All, Urgent, Normal, Info.
  - Each row has Go to, *Snooze 6 h* (quiet that kind for six game hours: kept, not toasted or chimed) or *Wake*, and
    *Dismiss*.
  - A line names the snoozed kinds, with *Wake all*.
  - Urgent notices are never snoozed or held back.
- **Run until the next warning** skips warnings of a snoozed kind. A warning the budget held back still stops it, and
  the strip's "N more" says why.
- **No spam at 4x.** New toasts are budgeted: 4 at once, +1 per 2.5 s of unpaused real time, info and normal apart.
  The rest are kept in the history and counted on the strip.

### The notice API (for other features)

Every existing call is unchanged. To add a new kind of notice, use `notify`:

```gdscript
# notify(from_source, as_tier, as_kind, words, about_subject = "", brief = "", to_kind = TARGET_NONE, to_id = -1) -> bool
services.notices.notify(NoticesScript.SOURCE_CREW, NoticesScript.TIER_NORMAL, &"cold_home",
	"The east burrow is cold — light a fire", "home:%d" % home, "Cold home")
services.notices.notify(NoticesScript.SOURCE_CREW, NoticesScript.TIER_URGENT, &"out_of_fuel", "The village is out of fuel")
services.notices.notify(NoticesScript.SOURCE_CREW, NoticesScript.TIER_INFO, &"chilled", "A resident came in Chilled", "",
	"", NoticesScript.TARGET_RESIDENT, who)
```

- **`kind`** (a StringName) is what sort of notice it is: the GDD's notice `code`. Repeats of a named kind about the
  same **`subject`** group. The subject defaults to the target ("resident:4"), else none.
  - Snooze works by kind, so use one kind per sort of notice, not one per resident.
- **`tier`**: `TIER_URGENT` | `TIER_NORMAL` | `TIER_INFO`. `notify` posts urgent and normal as WARNING and info as NOTE.
- **`to_kind` / `to_id`**: the jump target, `TARGET_*`. Go to shows when the village's jump can find it.
- **`post`** is unchanged, with three optional parameters added last: `post(from_source, at_level, words, brief = "",
  to_kind = TARGET_NONE, to_id = -1, serial = NO_INCIDENT, as_tier = TIER_AUTO, as_kind = NO_KIND, about_subject = "")`.
  (The parameters are named apart from the accessors `text()`, `kind()`, ... that they would shadow; GDScript passes
  arguments by position, so no caller changes.) `TIER_AUTO` infers the tier (warning -> normal, note -> info). Without a kind, a line
  folds only with an identical line said just before it (decision 0210), and its kind is "<source>:<its words>".
- **Incidents** (`incidents.report(key, ...)`): the line's tier is the severity's (critical -> urgent), and its kind and
  subject come from the key. "farm:wet:3" gives kind `farm:wet` and subject `3`, so key a new incident
  "<area>:<what>:<ids>". Only a critical incident pauses (and the ledger decides whether it does).
- **Reading the history** (the chronicle):
  - The village chronicle reads this way (decision 0631), and turns Village lines beginning `Chronicle: ` into the
    season page's gatherings.
  - `count()` and per entry `k` (0 newest): `text`, `summary`, `stamp`, `tier`, `kind`, `subject`, `repeats`,
    `first_tick`, `said_tick`, `entry_id`, `is_dismissed`, `is_announced`.
  - `entry_id` is stable and never reused; `index_of(id)` finds it again.
  - A grouped repeat keeps its id and moves to the top. Read new rows with `is_new_since(k, seen_rows_posted)`, never
    as "the newest N".
  - `tiers_into(group_mask, tier_mask, out)` filters.
- **Breadcrumbs** (the crash log): `notices.notice_posted.connect(func(entry_id: int, tier: int, kind: StringName, text:
  String) -> void: ...)`. It fires for every accepted post, folds and grouped repeats included.
- **Snooze and dismiss from code**: `snooze_kind(kind, hours)`, `wake_kind(kind)`, `wake_all()`,
  `is_kind_snoozed(kind)`, `dismiss(k)` and `dismiss_id(entry_id)`.

**One stores** (`demo_services.gd` `stores`, `tunnel/tunnel_stores.gd`): the village's wood, stone, planks,
finds and water (the kitchen's butt by the well, 40 U at most; decision 0381). The woods put their wood in and saw
their planks from it; the tunnels' bracing and lanterns are paid from it; the kitchen burns 0.1 U of its wood a batch;
the hearths burn it for heat (see Winter, decision 0571). The top bar's Wood and Stone are these figures, its Heating fuel
the days the wood lasts, and the ledger and Wood's tooltip carry the planks (below); the settlement simulation's own
stock is never written.

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
1280x720. The Map layer picker sits bottom left (see Map layers). The Village news strip is centred on the action bar and follows it (at 125 % on 1280x720,
where that leaves too little, it takes the gap between the minimap and the right column; the incident card narrows
to the gap between the side columns: decision 0391).

**Pop-ups own the input** (decision 0261, `ui/demo_input_gate.gd`). The Pantry, the game menu and the Demo Lab
are modals: a light scrim covers the world and the HUD, so no click, drag or wheel outside the frame reaches
them, and no world or HUD key works behind them (focus keys, Enter, Space, F11 and key releases pass). Focus
lands inside (the Pantry's first ingredient; its "×" is last), Tab and Shift+Tab stay inside, and Esc -- or
its own key, K for the Pantry, F8 for the Lab -- closes it and puts focus back where it was. That Esc does
not also clear the selection. The notification history is not a modal (UI §3 layer 30): a click on it never
reaches the world, and the world stays live beside it.

**The game menu** (`ui/demo_menu.gd`): the HUD's Menu button ("≡"), or Esc when nothing else is left to
close, opens it -- Resume, Restart demo…, Help (the searchable help that replaced the Controls page: decision 0481, see
The first-village guide), Settings, Demo Lab and Quit…, then the first-village guide's row (where it stands, Skip guide /
Reopen guide, Village guide (O), Practice stories) -- with the
line that **the demo can't save yet**. Restart and Quit ask first and say again that the village will be lost.
Opening it holds the clock's MENU pause reason and closing releases only that, so the village comes back at
the speed it had (and a pause of your own stays). Settings holds only what works: the interface scale
(100 / 125 / 150 %, the HUD and every demo panel, the level indicator and the action cards' tooltips together; a
size the window cannot show at 576 logical rows and 1024 logical px wide is disabled and says so -- at 1280x720, 150 %;
decision 0391), full screen, and the sound's volumes, mutes and mixes
(see "Sound" below), and **Accessibility** and **Time** (see "Accessibility" below). The Menu button no longer opens the New Settlement form: its Create would discard the settlement the demo runs on.

**The Demo Lab** (`ui/demo_lab.gd`, F8, or the menu's "Demo Lab"): the demo's test triggers, and only here --
Next weather (the one calendar runs on to the next change of weather, at most 48 h), Test event (the tunnels'
next seeded threat now), Storm gust (through the woods), Cramp (every selected resident swimming tires at
once; disabled with no swimmer selected), **Skip to next season** (decision 0571: the one calendar to 06:00 on day 1 of
the next season; see Winter), Season preview (decision 0551: the village drawn at the next of five seasons,
presentation only; its button names the one drawn), and Injury and Serious injury (the selected residents hurt; see The
herbalist and the infirmary) -- and Practice stories (the village guide's practice tab; decision 0481). They are the
same actions the panels' "(demo)" buttons were; the Tunnels, Woods and Water panels now hold only the village's own
choices.

**Keyboard focus** (decision 0261). The demo's panel buttons -- the right column's tabs and "×", the Farm,
Pantry, Tunnels (rooms and fit-out too), Woods and Water panels, and the party panel's Dig and room buttons --
take keyboard focus and wear the HUD's brass focus ring while they have it (a click's focus is not drawn). Every demo
panel that scrolls -- the Woods, Tunnels and Pantry panels and the menu's Settings now too -- brings the focused control
into view in its own pixels at any interface scale (`ui/demo_scroll.gd`; decision 0471 finished F35's list).

| Key | Does |
|---|---|
| F7 | Move focus: world -> the right column (its first tab) -> the left column (the party panel) -> the Map layer picker -> the guide's objective card (when shown; decision 0481) -> the people's offer card, while one shows (decision 0491) -> world. A control the Residents workspace (L) covers is skipped, and Enter on one is not pressed (decision 0391) |
| Tab / Shift+Tab | Next / previous button where the focus is (in a pop-up: its buttons only) |
| Enter / Space | Press the focused button. Only the keyboard's focus takes them: after a click, Enter still digs the piece the Dig tool has laid, Space still pauses and the arrows still pan the camera |
| Esc | With focus in a panel: back to the world. Otherwise the pop-up, tool or selection ladder below, then the game menu |
| Space | Pause; paused, Resume (your pause, a planning pause, a critical pause; never the menu's or a stall's) |
| G | "Run until…" (decision 0471): Tab and the arrows move through it, Enter chooses, G or Esc close it |
| F6 | The object list (decision 0471): every resident, crop bed, tree, bridge, tunnel mouth and room; Enter on a row selects it and centres the view on it |

**Accessibility** (decision 0471, review UX-023, `access/`): the game menu's Settings holds four **presets** -- pointing at
one (mouse or keyboard focus) previews what it would change, pressing applies it at once, live, and lights it while all it
sets is in place -- and each setting as its own toggle, which a preset only ever turns on:

| Preset | Sets |
|---|---|
| Large readable | the interface at 150 % where the window offers it, else 125 %; bigger tooltips (x1.25); high-contrast panels (a flat, opaque face under every panel's text, re-drawn in place: `woodland_styles.gd set_high_contrast`) |
| Keyboard planner | focus hints (a line under the keyboard's focus naming it and its keys: `access/focus_hint.gd`); show interactive targets (a brass ring on every resident, bed, tree, bridge, mouth and room a click selects: `access/target_marks.gd`) |
| Reduced motion | the camera stops easing (a follow holds its resident, a bookmark or the cutaway angle lands at once; the orbit still turns, steadily); the selection rings, a swimmer's ripple and the mound over a digger stop pulsing; every particle system at 35 %; the rain and snow thinner and half as fast (`access/demo_motion.gd`); autumn's falling leaves off altogether (decision 0551). The demo has no camera shake |
| Quiet focus | the sound's Quiet focus mix; fewer news toasts (warnings only, one at a time; everything stays in the village news) |

Under **Time**: Pause while planning (off) and Pause on a critical incident (on). Under **Camera**: Edge scroll (on;
decision 0801). **Restore defaults** says everything it
will change and asks first. The settings last for the session and through Restart, as the scale and sound do; nothing is
saved to disk. Key rebinding is not offered: the demo has no rebinding system yet.
| (typing) | In a pop-up's text field (the help or field-guide search, a project's name) every key but Esc, Tab and Enter types; Enter is swallowed, so it never reaches the Dig tool (decision 0481) |

**The top bar tells the village's truth** (decision 0251, review group E). One read model
(`ui/demo_hud_model.gd`, painted by `ui/demo_hud_counters.gd`) gives every cell exactly one owner, the
same object its panel reads, and writes nothing into the settlement simulation:

| Cell | Figure | Owner (and where else it shows) |
|---|---|---|
| Ready food | days of meals, one decimal, floored (`2.5 days`; decision 0381) | the kitchen: portions held plus the portions the stores' grain, roots, fresh fish, beans and greens would cook (each dish at its own portions: decisions 0436 and 0601), over the portions the village eats a day; the ledger adds one line of the stock behind it, the portions, grain, roots and any fish (the Pantry's Kitchen tab, K) |
| Heating fuel (Fuel's slot) | days of fuel, one decimal, floored (`2.5 days`), or "No demand" -- UI-SET-003's "No current heat demand" in its tooltip and the ledger; clay with the warning glyph under 2 days | the winter: the wood over today's heating demand plus the three-day cooking mean (decision 0571; its click opens the Heating fuel breakdown) |
| Wood / Stone | U, one decimal | the village stores (Tunnels, Woods, Water panels); Wood's tooltip and ledger line add the planks |
| Residents | count | the cast (the Residents roster) |
| Beds | count | beds installed in dug burrow homes (the Tunnels panel's housing line) |

Fuel's slot showed Planks while the village burned no fuel (decision 0251); the hearths burn wood now, so it is
UI-SET-003's Heating fuel again and the planks are on the ledger's Wood line ("Wood: 40.0 U · planks 2.5 U in store",
short enough that the ledger keeps its eight lines) and in Wood's tooltip (decision 0571). Clicking any cell opens the ledger, which lists
the same six figures and where each is. A figure whose owner is missing reads **Unavailable**, never 0.
UIManager still repaints the cells with the settlement's figures when the simulation's stock changes;
the demo paints its own back the next frame.

**Residents (L)** lists the cast, one row per resident: its name, species and trade ("Wenna Tallowby — mouse,
keeper"; ★ after a resident the player pinned as notable -- see People), where it is (on the
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

## People (decision 0491)

The demo's nine residents are an **original community** (Brendan's rulings, 2026-10-01) -- not Rowan, not book
characters -- each with a name, an interest and a way of speaking, from ONE data file, `people/demo_people.json`
(edit it there; its provenance note says they are original). Their trades stay roles.

| Resident | Name | Interest |
|---|---|---|
| Mouse keeper | Wenna Tallowby | carves tiny animal figures for the windowsills |
| Mouse fieldworker | Jory Whitethorn | can whistle a dozen birdcalls |
| Squirrel gatherer | Linnet Whinberry | plays a reed pipe, badly and often |
| Squirrel forester | Tobit Highbough | sorts a pebble collection by colour |
| Otter boatwright | Tegwin Slipstone | is teaching himself to read from an old almanac |
| Otter fisher | Corra Netley | sings rounds and teaches them to anyone nearby (calls everyone "friend") |
| Mole digger | Tuppen Clayholm | keeps a box of odd keys and buttons (light molespeak: "hurr", "burr aye") |
| Badger quarryman | Hulda Slatebrook | embroiders samplers with old sayings |
| Beaver bridgewright | Elstan Weirholt | plays the fiddle in the evenings |

- **One name everywhere.** `display_name` is the person's: the roster, the party panel, the Work screen ("Wenna
  Tallowby (mouse keeper) — Haulers crew"), the news, incidents, action cards, refusals and every feed name the same
  person. A placeholder (nothing staged) keeps its label.
- **The resident inspector** (the party panel with one resident selected): its name and role ("Mouse, keeper"), what it
  is doing and **why** ("Why: the Field crew's own work (Farm)", "Why: the village cook", "Why: your order", "Why: free —
  no task taken yet"), how fed it is, and its **skills as meters** ("Felling · Level 3" over its progress to the next
  level, from the XP real work earned). **About <name> ▸** opens, only when asked, its interest, its evening line,
  its relationships ("Rescued by Corra Netley", "Often works with Tobit Highbough"), **Pin as notable**, and its
  **notable moments**, newest first, each with **Go to** (the place) and the other person in it.
- **Notable moments are committed deeds only** (`people/people_taps.gd` into `people/people_ledger.gd`): a rescue that
  succeeded (never a victim washed ashore), a bridge, tunnel or room built (a dig called away is paused, not built: no
  memory), a first harvest (a cancelled one carried in as its delivery is none), a skill level reached, and a first
  meal cooked that fed everyone. A meal's deed and its shared suppers are read from the kitchen's **meal finalized**
  event, once every bowl of it has been eaten or given back (decision 0997), never from the tally at 19:00.
- **The spotlight**: after a rescue or a build, a top-centre card offers to mark the resident notable (★ on the roster;
  nothing about the work changes) -- once per resident and kind; it waits behind any incident card and the guide's card,
  and while the Residents list is open.
- **The season's reflection**: at a season's end the card offers up to three of its moments -- **Pin to chronicle**
  (posted to the village news: "Chronicle: Corra Netley brought Tuppen Clayholm ashore (Spring 4)"), **Keep private**
  or **Dismiss** (it leaves the resident's history); **Later** leaves them as they are.
- **Relationships** grow from what happens, by the GDD's own numbers (REQ-SET-035..037): +2 for an hour worked side by side
  together or a supper shared (once a pair a day), +8 for a rescue; friends from 40. They change nothing mechanical.
- **Evening lines**, at most one a day at 19:00: the next resident in turn who is free then, at its own pastime where
  it actually is -- with its own pleased words only after a deed of its own that day. A note in the news, nothing more.

## The village chronicle (decision 0631)

At each season's end the village writes **a page in a record-keeper's voice** (`chronicle/`). The page is drawn **only
from what the village recorded**: the news (read by entry id), the incidents' lines, the farm's after-action record,
the people's ledger and the songs. Nothing is invented. A section with nothing recorded is left out, and a bare season
says so in one line.

- **What a page tells**, in sections:
  - **The harvest and the table**: food into store and its three largest items, portions eaten, meals missed and crops
    withered. The village's first food and first meals are told once.
  - **Weather and trouble**: the season's §5.10 event and its days; trees blown down, the garden flooded, tunnels
    flooded or fallen in, shelter from a threat, residents in difficulty in the water, frost nights, blight, days
    without a meal and nights without a bed (at most four lines).
  - **Deeds**: rescues, bridges, tunnels, rooms, first harvests, meals and skills, best first, three shown. A village
    first says so.
  - **Friends and neighbours**: friendships made, friendships lapsed ("drifted apart"; the demo records no quarrel), and
    the pair who worked side by side most.
  - **Songs and gatherings**: the season's "Chronicle:" Village lines (the regatta's feast and later gatherings), the
    first village standing, projects done, songs learned and the evenings the supper table sang.
  - An opening by the season's mood, and a closing line.
  - The wordings vary by season, deterministically per seed (`chronicle_text.gd` `pick`).
- **When.** A page is written once the farm's record has closed the season's last day, so its totals are whole. It posts
  a Village info line, "The chronicle's page for Spring, year 1 is written…".
- **The player's curation holds.** A deed the season's reflection kept private or dismissed is never shown. A pinned one
  comes first, even when it was answered after the page was written.
- **The book** (`chronicle/chronicle_window.gd`) opens from a **Chronicle** button in **Village news (N)** and in the
  **village guide (O)**; there is no key of its own.
  - It shows one tab per page by season and **This season**, the season under way written so far, so a short playtest
    still ends on a page.
  - Earlier page and Later page step through it; Esc or × closes it.
  - It is a modal and a planning surface. It sits at most 720 wide in the HUD's modal rectangle and reads at 1280x720.
- **For other features.** To put a line on the season's page, post a Village notice beginning `Chronicle: `
  (`notices.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, "Chronicle: ...")`). The great hall's tapestry
  hooks in at one point, `village.chronicle().page_written = func(season: int, title: String, summary: String) -> void:`,
  which is called once per page written.
- Pages last the session (saving is deferred with UX-021) and are capped at 48.

## Map layers (decision 0292)

One map layer shows at a time (`map_lenses.gd`), each answering one question with a small legend:

| Layer | Its question | Its legend |
|---|---|---|
| Growing: Soil moisture | Which beds are too dry or too wet? | dry, low, good, wet, waterlogged (the beds' discs) |
| Growing: Ripeness | Which beds are ready to harvest? | growing, ripe, past its best or lost, empty |
| Growing: Water service | Which beds does the weir's garden leat water? | not served, dry (leat empty), normal, wet (decision 0441) |
| Getting there: Water range | Where can they wade, swim, dive or cross? | wade, swim, dive, ford, bridge site, swim link, landing |
| Getting there: Routes | How do they get there, and what holds them up? | surface, wading, underground, bridge, swimming (optional), by boat, by ferry (decision 0437), the posts (waiting, blocked); public ways never swim (decision 0461) |
| Woods: Zones and trees | Which trees may be felled, which must stay? | forestry (brass) and conservation (sage) zones; mature (leaf green), young (spring green), stump (dark umber), cleared (clay) -- the six pass the colour-blind check (decision 1044) |
| Underground: Tunnels | What lies under the village? | the U view's cut (U switches it too) |

- **The Map layer picker** (`ui/demo_lens_picker.gd`) names the shown layer on its header button ("Getting
  there: Water range ▾", or "Map layer: off ▾"); the button unfolds the list of layers, one button each, its
  question as the tooltip. A pick shows that layer alone and folds the list; picking the shown one again, or
  **Off**, shows none. Under the header: the question, the subject, what they can do there, and the legend.
- **V** steps the same layer: off, moisture, ripeness, water service, water range, routes, woods, off. **U** switches the underground
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
  enough (1920x1080), else just above the bottom band (1280x720, 125 % there, and whenever the resident journal
  pushes the news strip left), else right of the minimap. It is clear of the minimap, the news strip, the
  command strip, the party panel and the right column; where its slot is short, its list and card scroll under
  its header (decision 0391).

### Legends, the hover readout and comparing two layers (decision 0581)

`lenses/` (wired by `demo_village.gd _build_lens_picker`, one `lenses/demo_lens_kit.gd`):

- **The legend** (`ui/demo_lens_legend.gd`, in the picker's card): what the layer's ramp measures, with its units
  (the caption), then its ordered **ramp** as one continuous colour bar with each entry's word and threshold under its
  segment ("good / in range", "swim / ≤1.00 m") -- then its **keys** (fords, bridge sites, landings...). The Water range's
  depths follow whoever is painted (a badger's wade reaches 0.64 m). The scales are data: `lenses/lens_scales.gd`.
- **The hover readout** (`ui/demo_lens_readout.gd`): beside the pointer, the exact value under it for the shown
  layer -- "Soil moisture 60% · good" with that bed's own band edges ("dry <5% · low <25% · wet ≤90% · waterlogged
  >90%"), "Bed 3, Carrot · 80% grown / ripe in about N h at this hour's rate", "Bed 2 · leat: normal / up to 15 points
  a day toward its good range's middle", "Water 1.40 m deep · dive / for a 1.0 m mouse: wade ≤0.25 m · swim ≤1.00 m",
  "Oak · mature tree / forestry zone North stand: may be felled (keeps 20% mature)". Read ten times a second, worded
  only when what is under the pointer changes, hidden over any panel; nothing is allocated per frame. Routes and
  Underground have no readout (no probe).
- **Compare** (the picker header's button between the layer's name and Off, two overlapping squares): pick a second layer and its areas are drawn as **outlines** over the
  shown one (`lenses/lens_contours.gd`: each area traced in its own colour on its inside, round an ink core) -- a bed
  filled by moisture and ringed by the leat's service; the readout adds the compared layer's value. Its legend shows
  below its "Outlined: …" line, compact and outlined. Picking it again, or **✕**, turns it off. V and the list change the shown layer and keep
  the compared one (unless it becomes the shown one); U's view drops it. Only layers with an outlining probe are
  offered: the three Growing layers, the Water range and the Woods' zones.
- **Colours** (`lenses/lens_palette.gd`): one token per area colour, read by the bed discs, the water's zone paint,
  the legends and the outlines; every layer's area colours pass the colour-blind check (`lenses/lens_colour_check.gd`:
  deuteranopia and protanopia, legend, day and night). The moisture and ripeness ramps changed for it (moisture: orange
  dry, pale low, sage good, periwinkle wet, indigo waterlogged; ripeness: blue-grey growing, gold ripe, plum past its
  best).
- **At night**: every layer's marks are unshaded, and the outlines also ignore the haze, so the moon and lamps do not
  dim them; only the frame's own grade does, and the check includes it.
- **Reduced motion**: the readout fades in and out over 80 ms (UI §2.2), at once with Reduced motion on.
- **Adding a layer** (a seasonal one, the winter's fuel): fill one `lenses/lens_def.gd` record -- group, label,
  question, `show(on)`, swatches and words, which swatches form the ramp with a threshold each, the caption with
  units, which swatches are areas, the ground they lie on, and optionally a probe (`lenses/lens_probe.gd`: `read_into`
  with no allocation, `describe`, and a field to outline) -- and call `demo_farm.lenses.add_def(def)`. V, the picker,
  the legend, the readout, compare and the colour check (`test/live/demo_lens_live.gd` checks every layer the village
  has) pick it up with no other change. Put its area colours in `lens_palette.gd`.

## Routes and infrastructure previews (decision 0461)

Review group P (packet P5, ECO-039, ECO-045). `routes/`, wired by `demo_village.gd _build_routes`:

- **Estimates from the real router** (`routes/route_estimator.gd`): a trip is planned as a resident's own (tunnels it fits
  with its load, the water's crossings when it offers some) -- "before" on the live network, "after" on a COPY of it with
  the proposal in it (a dig's segments open, the Dig tool's plan laid and open, or a bridge offered as an open one is,
  `routes/preview_crossings.gd`) -- and costed by the router itself (`tunnel_router.gd last_cost_m`); a route the live
  planner prices without the water has its wading priced as the router would, so before and after are on one footing.
  Nobody is standing about; times are walking only, at the walker's pace (a carrier slower), on the demo calendar; every
  estimate says so and that the movement rules are not final (MOVE-G01–05).
- **Through the routing desk** (decision 0361): ONE step a frame across all estimates -- the copy, or one trip's one
  plan -- at the end of the frame's routing window (`cast/demo_cast.gd window_tail`, after the residents' plans), only
  when no resident waits and the window can take it, charged to the window; only for what is on screen.
  "Before" is the live router's own plan (its warm cache shared); "after" is planned on a copy. After a step longer
  than the budget (one plan is never cut in two), the estimate rests that many windows.
  The panels say "calculating…" until it is done; a change to the network, the crossings, the weather, or a bridge
  planned or opened starts it again (a bridge's work in progress does not).
- **The Water panel's site**: Build shows only for a kind that can be built now. A kind the stores cannot pay for says
  what is missing ("Plank footbridge: missing 4.7 U planks") with **Saw planks ▸** (the Work screen's saw task when one is
  queued, else the Woods panel -- nothing is ordered) or **Woods: fell or haul logs ▸**. Under it the **benefit**: up to
  three work trips that cross the water near the site, now and after ("the hall to the far bank by the mill: now about
  3.8 game hours, after about 3.3 game hours (14% quicker)"), who can use it, its cost from the Build card. A planned
  bridge: its materials (paid when planned: nothing missing) reserved at their source, being carried, or delivered at the
  site; its stages; its builder; **Bridge task ▸** on the Work screen. An open bridge: its route across, its condition and
  the route a work trip takes now -- no construction controls.
- **The Tunnels panel's project**: the piece laid in the Dig tool, once it may be dug -- its benefit if dug; else the
  first dig in the job list -- its **stages** (`routes/dig_stages.gd`, ECO-045: a junction where it meets another dug
  bore, then a connection or a spur), a **dead-end heading** said apart from a finished stage, the **next payoff** with
  how far the dig to it is and its benefit (the piece open to that stage), who fits the bore (by body; a group member by
  member), and that digging takes no materials. **Work ▸** opens the Work screen's projects.
- **The Routes layer** (`routes/route_overlay.gd`): the selected residents' routes, each its own, coloured by stretch
  (`routes/route_kinds.gd`: surface, wading, underground dashed with its level, bridge, swimming, and **by boat** -- a
  crew member aboard, drawn along the boat's own course to its station or back to its berth, since a boat's legs are
  its task's, not the router's; and **by ferry** -- the ferry's crossing row, and anyone aboard the ferry boat: decision
  0437), and a post with the
  words where one is held up (`routes/route_reasons.gd`, from the real cause): "finding a route", "waiting for mouth",
  "no safe exit", "closed by flood", "closed by a roof fall", "load too wide", "too big for the bore", "can't find a way
  there", "gave up", "waiting for the ferry". The ferry's course is drawn with its line ("Ferry: open · next departure
  10:00", or "closed: a storm"). The picker's notes give each member's stretches or hold-up. With nobody selected (ECO-039): each
  work district's **public way** from the square for the public walker (the widest body, carrying -- so never swimming),
  labelled with its time; a narrow body's tunnel **shortcut** beside it where there is one, marked optional; and the swim
  links drawn as what they are -- optional crossings for swimmers (a swimmer's whole trip is not estimated for the layer:
  a plan offered the swim links costs a dozen surface plans).
- **The rescue card** (`routes/rescue_card.gd`): each rescue's incident card adds its phase, an approximate time to
  safety or the blockage, and **Victim: *name* ▸ / Responder: *name* ▸ / Landing ▸** (each resident by name, decision 0491) (select and centre; `ui/demo_incident_cards.gd`
  DETAILS), the same while paused.
- Checked on the real scene by `test/live/demo_routes_live.gd` (`test_demo_routes_live.gd`), the rest by
  `test_demo_routes.gd`.

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
Work: about 40 game minutes, plus the walk
Who: Assign selected: Squirrel forester (nearest of 2)
Interrupts: Felling the oak — goes back to it after
Needs: a site both banks take; planks (sawn at the sawhorse) and wood for any piers
```

- **The card is the order's own decision.** Each system's order and its card run the same function:
  `farm_crew.gd decide`, `forest_crew.gd decide`, `tunnel_actions.gd refusal`, `room_fixtures.gd
  order_refusal` / `suggest_refusal` / `take_refusal`, `demo_waterplay.gd build_refusal`, the dive loop's
  `dive_spot` and `dive_refusal`, and the Dig tool's `choose_digger` with its capacity gate
  (`underground_graph.gd any_piece_refusal`, decision 0361). So a card's refusal is the order's
  (code and words), its resident is the one sent, its cost is what is spent, and a button is pressable
  exactly when its card allows it. The bridge, tunnel and fixture buttons now refuse a short store before
  they are pressed, not after.
- **Costs** are have / need from the stores the HUD reads (wood, stone, planks), the farm's compost store,
  and the earth on the fullest spoil heap or in the stores (Raise, Bank; decision 0401). **Work** is in game time of the demo calendar (25 demo seconds a game
  hour): whole game minutes under an hour, hours to the tenth from one; the walk is not counted, and a mole job's card says a crew is quicker.
- **Who**, in one grammar everywhere: "Assign selected: X (nearest of 3)" (farm, woods, bridges);
  "Assign selected: X (first of 3 who fits the bore)" and "Assign X (the nearest free resident who fits
  the bore)" (tunnels); "Lead: X (nearest of 3) + 2 waiting to haul" (felling); "Queue for the Field crew:
  Jory Whitethorn or Linnet Whinberry, then anyone free who can" -- the work board's own words (decision
  0411: the crew preferring that work first, then anyone eligible); "Already under way: X is on it". With two or
  more selected a card also previews **each member** (decision 0411, review UX-001): "Of 3 selected: Wenna Tallowby,
  Tuppen Clayholm can; Hulda Slatebrook can't (does not fit the bore, or is below)" -- the farm's, the woods' and the
  tunnels' cards, in the Work screen's Reassign words.
- **Interrupts** says what the named resident stops and whether it goes back to it (the brain's resuming
  rule, `control/work_interrupt.gd`; `demo_command.gd interrupt_text`): a farm, woods, spoil or tunnel job
  resumes; a dig with nothing dug drops its route; a bridge waits for a builder; a sleeper goes back to bed.
- **A harvest with no store room** (decision 0222) is not refused: its card says it waits on the board, uncut,
  and how much has nowhere to go -- what the order then does.
- The cards wear the HUD skin's tooltip (the map piece, ink text) and break their lines to stay inside
  UI-SET-073's 360 × 240.

## Work: one board, named crews and order lists (decision 0411)

Review group M (F22, F32, F44's remainder, SOC-004, UX-001, UX-002, UX-007). `work/`:

- **The work board** (`work/work_board.gd`) is the one common owner of who does what. Each job owner keeps its own
  board -- the farm's, the woods', the bridges', the tunnels' jobs, the rooms' fit-out, the spoil heaps' -- read
  through one adapter each (`farm_work.gd`, `woods_work.gd`, `bridge_work.gd`, `tunnel_work.gd`, `fit_out_work.gd`,
  `spoil_work.gd`, water part B's `fishery_work.gd`: trips' seats, traps, the rack, the mill and the gear, decision
  0431, `ferry_work.gd`: the far copse's gathering, ferried wood's hauls and the crossings' crews, decision 0437;
  the hall's `hall_work.gd`, decision 0771; and the orchard's `orchard_work.gd`, decision 0671); every command goes to
  the owner's own function, so its conservation rules hold (decision 0222:
  a load in hand is carried on, never paused or handed over from afar -- earth too: a farm job carrying earth back
  to its heap reads "Carry earth back", a delivery, and Cancel refuses it; decision 0401). The kitchen's cook and
  water drawers are listed as well (`kitchen_work.gd`; the kitchen hands them out itself), and the board hands no
  work to a resident at its meal (`set_needs_gate`, `kitchen.gd kept_for_meals`; decision 0381). The food stores'
  moves into a cooler store are a ninth source, **Food stores** (`stores_work.gd`, decision 0611; see The cool cellar),
  which also lists the cellar buildings' places (decision 0612).
- **Nobody wanders while eligible work waits.** Every half second of cast time each resident is reconsidered
  (staggered); an idle one -- wandering, on the surface, not resting, not in the water nor held by its rescue, its
  needs not first -- takes the best waiting task it is eligible for (skills and physical fit -- fits the bore, can
  dig, on land, one job a board -- never a species lock): an URGENT task first, then its crew's priority for the work,
  the task's own priority, the nearest. The farm's, the woods' and the bridgewright's old routine crews stand down.
  A paused tunnel job (its worker called away) waits for a resident who can work it -- unless its worker means to
  come back to it. The fit-out keeps its own hand-out (anyone free who can reach the room); spoil heaps are cleared
  by order only.
- **Crews** (`work/work_crews.gd`): Field, Woods, Diggers, Haulers and Builders, each with a preferred activity
  and two fallbacks (priority 1, 2, 3; anything else 4; 0 forbids). Everyone starts on its trade's crew and the
  player moves them. A member is **available, occupied, resting or absent**. **Presets** -- Normal, Harvest week,
  Winter stores -- are whole priority tables, previewed (what each would change) on hover and keyboard focus
  before they are applied.
- **The order list** (resident_brain.gd THE ORDER LIST): **Shift+right-click** appends an order -- a bed's most
  pressing job, a tree's, trunk's, deadfall's or the sawhorse's, or a walk to open ground -- to the end of the list
  (at most 8 queued; up to 3 jobs kept from interruptions besides); a job kept from an interruption goes to the front.
  The queue starts at once for a resident with nothing to do, when a plain move arrives, or when a job is done. The Residents roster and the Work
  screen read it as "Next: back to Brace, tunnel 2 → Harvest, the carrot bed"; then the resident's routine. The
  party panel lists it under "Next:", a row each ("→ back to Brace, tunnel 2"). A task
  queued for a resident (or kept to come back to) is left to it.
- **The Work screen** (`work/work_screen.gd`): the HUD's **Jobs** command (UI-SET-029, **J**) -- unlocked by the demo
  for it, as Food is for the Pantry -- opens it over the HUD (Esc, J or × close it; Tab and Enter work inside it).
  **Tasks**: every task, blocked first, then under way, queued, paused: "Harvest — the carrot bed · Mouse
  fieldworker", its state and why it waits ("Blocked: no store has room for 5.1 U of carrot — make room in the
  Pantry (K)", "Travelling: finding a route", "can't reach it"), the work left in game time and who means to come
  back to it; with **Go to**, **Pause/Resume**, **Cancel this task**, **Reassign…** (every resident, each with its
  eligibility; with residents selected, the group previewed member by member), **▲/▼ Priority** and **Urgent**. A
  command a task cannot take is disabled saying why. **Residents and crews**: each crew, its members' status, what each
  is doing now and its order list (▲ Sooner, ▼ Later, ✕ Remove), ◀ Crew / Crew ▶; the presets above. **Projects**: the
  tasks grouped by where they are. **Standing orders**: the goals the village keeps (see Standing orders). **Cancel all
  work…** only shows its scope (counted per source; deliveries, paid
  tunnel jobs and bridges go on) until Cancel them is pressed.

## Standing orders (decision 0711)

Goals rather than tasks: `orders/`, the Work screen's fourth tab, **Standing orders** (the HUD's Jobs command, **J** --
no new key). A standing order keeps a good stocked; when it falls below the amount the village queues the work itself.

- **What can be kept** (read from data: `orders/standing_kinds.gd goods_into` lists the stores' goods, then every crop
  of the farm's catalog, so a new crop slots in): **planks** (by sawing at the sawhorse), **wood** (deadfall first,
  else a fell in a forestry zone -- the winter's own Firewood rule, `forest_crew.gd raise_wood`), **days of meals** (the
  HUD's Ready food: by harvesting the ripe beds of any crop a dish takes) and **a crop** (by harvesting its ripe beds).
  Sowing stays the farm's. The **Add row**: − amount + of ◀ good ▶, **Add order**.
- **Each game hour** every order is kept: its finished jobs let go, the good measured and **what its jobs will still
  bring counted** (REQ-SET-098), then the **latch** -- it starts working below the amount and stops once the good is back
  at the amount plus a band (a saw batch, a large deadfall pile, half a day of meals, a unit of a crop), so it never
  starts and stops at the line. It opens at most 2 (woods) or 3 (farm) jobs at once through the owners' own boards,
  which the work board lists and claims like any other (a harvest the farm already queued is adopted, not doubled); a
  job takes the **order's priority** and is **Urgent** (bucket 2) while fuel-days (wood) or food-days (meals and food
  crops) are under two -- but a priority or Urgent mark you set on a task yourself holds.
- **Each order's row**: its target, priority and switch; its **state** -- Satisfied, Working, Off, or **Blocked: why**
  ("not enough wood to saw: …", "no pea is growing — sow some from a bed's panel"); the good now and what is coming;
  and every job it has queued with its worker. **− / + Amount**, **▲ / ▼ Priority**, **Switch off/on**, **✕ Remove**
  (the work it queued goes on).
- **Notices**: only a **blocked** order raises one (a Village warning, resolved when it is no longer blocked).
- **The winter's Firewood** is the book's **built-in** order: kept by the winter on its own hour exactly as before
  (decision 0571), listed first, only switched off or on.

## The first-village guide (decision 0481)

Review group U (F49, P7, UX-017, UX-019) and UX-018 and UX-020: `guide/`. One objective card at a time (UI-SET-072, top
centre under the alerts), each completed **only by what really happens in the village** -- never a button or a timer:

| # | Objective | Done when |
|---|---|---|
| 1 | Meet a villager | a resident is selected (a click, a box, the roster) |
| 2 | Bring in a harvest | a harvest is shelved in a store (the pantry's delivered total; an order, a cut crop or a load in hand is not) |
| 3 | Serve the first supper | a resident finishes a cooked supper portion (their own record; the plan, the pot, a portion held, raw food, breakfast are not) |
| 4 | Ready the village for the frost | the first of: someone over the middle of an open bridge; someone walking through a tunnel and up 6 m or more from where they went down (not the digger, a dig crew or a tunnel job's worker); a bed with a crop covered, raised, banked, ditched or tunnel-drained |

- **The card** teaches (what and why), says the current cause or blocker and the next legal action, and confirms the
  real outcome ("5.1 U of carrot came into store") for 10 s of unpaused time or until Next; one already done before its
  card came up says "Already done:". A brass ring and a bobbing brass point mark its target in the world (a resident, a
  bed, the cauldron, a bridge, a tunnel mouth). **Show me** eases the camera over it (the target below the card) and
  opens a bed's, tunnel's or bridge's panel; a resident is only centred. **Help** opens this step's how-to. **Hide
  guide** hides it. A lost target is replaced (another ripe bed, the soonest, an empty bed to plant, a lost crop to
  clear); a blocked meal or bridge says why in its owner's own words and the fix; objective 4 shows its three ways side
  by side. The frost is the farm's own (the night into Spring 11, then the next).
- **Where**: between the side columns, at most 420 wide; it yields to a critical incident's card, the stall banner, the
  news history and the open Residents list (it would cover the list's rows at 1280x720), and the people's offer card
  waits behind it -- one card at the top centre: incident, guide, offer; and never reaches the Map layer picker -- it drops its teaching, then its next action, and where even
  that cannot fit (125 % on 1280x720 with a legend unfolded) it waits.
- **Skip and reopen** (the card's Hide guide, the game menu's row, the window's Objectives tab) only hide or show the
  card: nothing is granted or lost. Hidden, it keeps up; reopened, it is on the first objective not done.
- **Done**: "The first village stands", and a chronicle entry in Village news under the new **Village** source. Free
  play goes on; the Hearth Charter, the long-term goal, is beyond the demo.
- **The village guide** (O, the HUD's Objectives command, unlocked for it): a modal that holds a menu pause through the
  pause ledger, "The village guide is open" (the village waits) with six tabs -- **Objectives** (done, current with its cause, ahead), **Goals** (decision 0781, below), **Projects**, **Field guide**, **Help**
  and **Practice**.
- **Help** (also the game menu's Help page, in place of the 21-key Controls wall): 25 how-to topics (the ferry and the
  regatta among them: decisions 0437, 0438; decision 0571 added "Keep the village warm in winter", with its Open
  Heating fuel button) and the 28 keys,
  searched in plain words ("how do I cross the stream", "eat", "why is my job waiting"), each topic a command answers
  with that command as a button.
- **Field guide**: 80 entries built from the demo's own tables (counted at the batch 7 integration, decision 0902) --
  the 16 crops (which dishes each feeds), the recipe book's 20 dishes (decisions 0601, 0603; the feast's nut loaf among
  them), 7 materials (fishing gear among them), 14 buildings, stations and occasions (fishing and the boats, the drying
  rack and mill, the ferry and the regatta, the hearths and heating fuel of decision 0571, and foraging trips among
  them), 5 skills, 4 water-safety entries, and 14 goods (the six fish, dried fish, flour, the potato and honey still
  waiting for a source, and the woods' nuts, mushrooms, herbs and berries) -- each with Uses, Requires, Alternatives
  and Available here, linked, a crop's pantry stock live; nothing the demo lacks.
- **Practice stories**: a loaded crew at the stream, a delivery with nowhere to go, a winter pantry -- three choices each,
  what happened, a debrief comparing all three, Restart. Built from fresh copies of the village's own models (a pantry,
  a farm with its own calendar, a bridge surveyor over the stream's shape), never the village: it is untouched (the
  window's pause holds it too). From the Practice tab, the menu's row or the Demo Lab.
- **Projects**: up to three, your name, the places selected when pinned (with Go to) and one measure with a target --
  wood, planks, stone, ready food, harvested or suppers eaten from now, bridges or tunnel stretches open. Reached, it is
  ticked and Village news records it once with before and after. Session only (no save).

## Village goals and milestones (decision 0781)

`goals/`: optional goals that guide play once the first-village guide is done, in the village guide's **Goals** tab (O,
the second tab; the Objectives tab's *Goals for after the guide* opens it). No new key. The guide's four objectives and
its completion are unchanged; once it completes, one Village news note (at the next game hour, after the guide's own
line) points at the tab.

- **Each goal** has a title, a short *why*, its parts' progress ("Harvested into store: 12.0 U of 40.0 U") and, reached,
  the date ("✓ Wood for the cold -- reached Y1 Spring 5, 03:00"). Its reward is **a Village news note** ("Goal reached:
  ...") -- the news strip shows it while fresh and the history keeps it. Nothing else is granted: no resource, unlock or
  mood. A reached goal stays reached.
- **Evaluated on the game hour**, never per frame: `demo_goals.gd update()` costs an integer compare until the calendar's
  hour index changes; then the ledger reads the kitchen's and the planner record's logs (a supper's tally once its day is over) and every measure
  is read once.
- **Village goals** (approved by Brendan as built, 2026-10-01; decision 0781): Harvest home (40.0 U into store), Every dish on the table (each of the
  kitchen's dishes cooked), A table for everyone (a supper where every resident ate cooked), A full larder (4.0 days of
  Ready food the village cooked or brought in: the opening wheat and carrots still held are left out, read off the
  pantry's own lots, whose opening share follows every split, move, merge, meal and spoiling -- decision 0994), Wood for the cold (60.0 U), Over the water (a bridge open), A way below (3 tunnel stretches), A clean
  season (a whole season in the planner's record with food harvested and no crop lost), The first winter weathered.
- **Milestones**: the GDD's M1-M4 (§5.11), every condition a part worded as the GDD states it. What the demo models is
  measured (day, residents, portions prepared, year, winters, Ready food); the rest -- mastery, feasts, specialists,
  mood, warm beds, deaths, winter fuel, the three-day hold -- reads "not in this demo yet" and blocks its milestone. With
  nine residents and no arrivals none is reachable here; they show the road ahead and would grant nothing.

**Adding a goal from a later feature** (`goals/goal_book.gd`, THE REGISTRATION API). Reach the book through the guide
(`demo_village.guide().goals.book`) and register a data entry with a measure -- a cheap, allocation-free `() -> int`
read once a game hour, met at or above its target:

```gdscript
const GoalBook := preload("res://demo/goals/goal_book.gd")
var book: GoalBook = village.guide().goals.book
var parts: Array[GoalBook.Part] = [GoalBook.part(&"winters", "Winters with no one chilled", 1,
	GoalBook.UNIT_COUNT, warmth.unchilled_winters)]   # a latched count your model keeps
book.register(&"warm_first_winter", "A warm first winter", "Why it matters, in a sentence.", parts,
	GoalBook.GROUP_VILLAGE, "no one was chilled all winter.")   # "" when taken, else why not
book.bind_measure(&"m4_hearth_charter", &"fuel", warmth.fuel_winter_days_milli)   # M4's fuel>=18 winter days, milli-days
book.keep(warmth)   # if nothing else holds the measuring object (a Callable does not keep it alive)
```

Units: `UNIT_COUNT`, `UNIT_MILLI` (thousandths, "12.0 U"), `UNIT_DAYS` (thousandths of a day) and `UNIT_FLAG` (1 or more
is "yes"). A "none of X" goal measures a latch the feature keeps (1 once a winter ended with nobody chilled), since every
part is read as at-least. Register before the first hour or after; a goal is first measured at the next hour.

## Commanding the residents

| Input | Does |
|---|---|
| Left click a resident | Select it alone (Shift: toggle it in the selection) |
| Left drag | Box-select by screen position (Shift: add to the selection); "Selecting residents: n" beside the box says how many it holds (decision 0791) |
| Double left click a resident | Select every resident of its kind in view (UI §5 `select_similar`; decision 0791) |
| Ctrl+0–9 / 0–9 | Keep the selection as control group N / select group N again; the digit twice quickly also goes to it (UI §5; decision 0791) |
| Left click empty ground | Clear the selection |
| Right click ground | Move there in a formation, then hold |
| Right click a work spot | Work there; anyone beyond its free slots holds behind it |
| Shift + right click | Append the order to the selection's order lists instead: a bed, tree, trunk, deadfall or the sawhorse queues its job for the nearest selected, open ground a walk for each (see Work) |
| J (or the Jobs command) | The Work screen: tasks, residents and crews, projects (see Work) |
| O (or the Objectives command) | The village guide: objectives, your projects, the field guide, help and practice stories (see The first-village guide) |
| R | Release the selection back to its own routine |
| Esc | Close the top pop-up; else drop the Dig tool's piece or close the tool; else clear the selection; else open the game menu |
| Menu ("≡") | The game menu (above) |
| F8 | The Demo Lab (above) |
| B (or "Dig tunnel (B)") | The Dig tool: lay out tunnels and branches (below); again: close it. (B is the HUD's Build key, locked in the demo, so the demo takes it; the command strip says so) |
| H / C in the Dig tool (or "Burrow home (H)" / "Root cellar (C)") | The room tools: place a burrow home or a root cellar as its own structure (see Burrow homes and root cellars) |
| U | Underground view: a top-down section cut at the tunnels' level (see The underground view) |
| PgUp / PgDn in the U view | Show level 1 / level 2 (see The second level). On the surface they stay the camera's zoom; Alt+PgUp/PgDn its pitch |
| L in the Dig tool | Lay a link down to level 2: once a ramp, again stairs, again back to tunnels (see The second level) |
| Left click a finished tunnel | Select it for the "Tunnels & burrows (demo)" panel (see below) |
| Left click a dug home or cellar | Select it for its fit-out in the same panel (see Fit-out and living) |
| Right click a tree, trunk, deadfall, stump, cleared spot or the sawhorse | The woods' verb for it (see The woods) |
| Right click deep water | Swimmers swim out and tread water there; an otter over water deeper than it is tall dives; a non-swimmer is refused by name (see Water gameplay) |
| Right click / left click a bridge site | Build the planned bridge there with the selection / select the site for the Water panel |
| Middle-button drag | Turn the camera: across turns it (right turns right, as E), up and down tilt it -- per logical pixel, so as far at 4K as at 1080p |
| Pointer resting at a window edge | Edge pan, after a quarter second; not over a panel, behind a pop-up or while a button is held (see The camera's modes) |
| End | Follow the selected resident; End again, or any pan, stops (see The camera's modes) |
| Ctrl+Shift+1..4 / Shift+1..4 | Save the view as bookmark 1-4 / go back to it |
| Shift+O | Orbit the building in the middle of the view, slowly; Esc or Shift+O stops |
| Shift+U | The U view at its cutaway angle, framing the tunnels; Shift+U again gives your angle back |
| (any camera move) | The eye never sits inside a tree crown, the crowns between it and what it looks at are thinned, and a selected resident shows through foliage and roofs (see The camera and the trees) |
| Left click a spoil heap | Select it: a brass ring, and the party panel says how much earth it holds |
| Right click a spoil heap (or C with it selected) | The selected residents who can carry dig it out and haul its earth to the village stores (Clear; see Spoil heaps) |
| V | Steps the one shown map layer (see Map layers): Growing: soil moisture, Growing: ripeness, Growing: water service, Getting there: water range (wade / swim / dive, fords, bridge spans, landings, fish stocks), Getting there: routes, Woods: zones and trees, off -- the same layer the Map layer picker shows |

The "Demo party" panel in the HUD's left column lists the selection, and **never hides** (decision 0391,
review F20/F31). Its header says how many are selected; a summary line says who and what -- one resident's name
and what it is doing, or a group's common activity ("Holding ×3 · Walking to the well ×2"), cut with an
ellipsis and whole in its tooltip; then the actions, always in view: **Release (R)**, **Follow (End)** (decision 0801), and Dig tunnel (B),
Burrow home (H) and Root cellar (C) with a digger selected. Below them a scrolling **inspector**: the notice
line, then for one resident its species, what it is doing, the progress or step of that on its own row, "Then
back to:" with a row per unfinished job, its skills, and **what it can be ordered to do**
(`control/resident_abilities.gd`) in full -- a line a kind of work with what to right-click, the gated ones
marked × with the rule: anybeast who fits a bore digs (moles start skilled), the otters and the badger are too
big for a bore until it is widened, only otters dive, the badger wades only and breaks rock, the beaver gnaws.
For a group, a row for **every** member (no "+ n more"): click one to select it alone and centre the camera
on it. Where the column is too short for the header, summary and actions and a useful inspector (125 % at
1280x720), the summary and actions go to the top of the inspector, reached by scrolling. Its **notice line is each resident's own**: a prompt or answer is
kept for whoever was selected when it was said, so selecting someone else shows theirs. A resident
called away from a job it had not finished (a tunnel job, a dig, a farm or a woods job, a spoil heap)
**comes back to it** when the work that took it is done -- the latest three are kept, the panel says
"Next: back to ..." (with any orders queued by Shift+right-click; decision 0411), and R (release) forgets them -- a
finished dig takes its saved job back up once the
digger has stepped clear of the hole (at night it keeps it for the morning). Orders move the demo cast only,
never the simulation.

**Selecting a group** (decision 0791, `control/group_select.gd`). **Select idle (n)**, under the party panel's actions
and shown with or without a selection, selects every resident the Work screen calls *available* (no key: UI §5 has
none). With two or more selected, the inspector opens with a **group section** (`control/group_panel.gd`): what they
are doing ("Doing: Wandering ×4 · Drawing water at the well ×1", whole), **Needs attention** -- each warning they hold,
"Hungry ×1 — Tobit" -- then the notes ("No bed ×2 — Hulda, Elstan") and who is idle; a **tile** per member (its colour,
first name and first warning, else what it is doing: click centres the view on it and keeps the group, Shift+click drops
it from the selection; the tiles are colour marks, not portraits -- the demo has no portrait art); **Crews** -- one
press puts them all on Field, Woods, Diggers, Haulers or Builders (a crew they are all on already is disabled; the
tooltip says who joins); **Send to…** -- the next left click on the world orders them there, as a right-click would
(Esc cancels; in the U view right-click instead); and their control group's line. **Statuses come by data**
(`control/group_status.gd`): a status is one row -- id, word, WARN or NOTE, and its owner's existing query -- added
with `village.group_select().statuses.add(...)` where the owner is wired; the section shows it with no code of its own
(built in: Can't get there, Hungry, Peckish, No bed, Idle). The single-resident inspector is unchanged.

**Finding a route, and giving one up** (decision 0361). Route planning is spread over frames: a group order
picks its formation at once, and its residents' routes are planned a few a frame -- one waiting for its turn
says **"finding a route"** in the panel (paused too; it sets off once planned). A resident whose way is gone
-- no route at all, or one that stayed blocked -- gives the trip up and holds, and the panel says why
("holding — can't find a way there", "holding — gave up: the way there stayed blocked"); a job it was walking
to is kept to come back to. Nobody is credited work, a load or a delivery for a walk it did not finish.

**Route planning at scale** (decisions 1001, 1003 and 1004; measured in
`docs/performance/2026-10-02-route-planning.md`). A plan is local and can be cut across frames.
- **Local.** A plan rings only the standing residents its search comes near, tests each link against the residents
  near it, and links each node to the plan's nodes in the cells round it. A goal ringed by a crowd, or tucked where no
  route reaches, is found shut in from its own side in a few expansions, without reading the whole village.
- **Cut across frames.** The routing desk plans a resident's surface trip a few expansions at a time. A plan the frame
  cannot finish is carried to the next frames, and its resident says "finding a route" until it is done. A wanderer
  keeps the spot it picked. The routes are the ones the planner found before (`test_demo_route_planning.gd` checks
  this against the old planner, kept in `test/fixtures/`).
- **Bursts spread.** The kitchen calls at most 8 diners a frame, and dusk sends at most 8 residents to bed a frame.
- **Neighbours by cell.** A walker's step reads the residents in the cells round it, not everyone. The people's
  shared-work pairs and the work board's claim index no longer grow with the village.
- **The cook serves as it cooks** (decision 1005). While a meal is served, the cook carries the pot out whenever
  the table is empty, then cooks on. A diner with no seat waits on a ring beyond the seats, off the cook's spot. A
  walk whose plan found no route waits 2 s before planning again.

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

## The camera's modes (decision 0801)

Feature #60 (`camera/camera_modes.gd`, `camera_bookmarks.gd`, `edge_pan.gd`, `camera_strip.gd`). All presentation: the
rig stays the player's, and none of it reaches the simulation.

| Key | Mode |
|---|---|
| End | **Follow** the selected resident (UI §5's `camera_follow`): the view eases after them as they walk (held on them, no easing, with reduced motion). Turning, zooming and tilting keep it; any pan -- the keys, the edge, the minimap, a "Go to", Home, a bookmark -- or End again stops it |
| Ctrl+Shift+1..4 | **Save** the view (where the camera is going: centre, heading, pitch, distance) as bookmark 1-4 |
| Shift+1..4 | **Go back** to a bookmark (eased; at once with reduced motion). An empty one says how to fill it. Bookmarks last the session and through Restart; nothing is saved to disk |
| Shift+O | **Orbit** the village building nearest the middle of the view (within 12 m; else the middle itself): 35 degrees down, from a distance fitted to its size, turning six degrees a second -- paused too. Zoom and tilt still work; Esc, Shift+O, a pan, a turn, a bookmark or End stop it. Esc keeps its ladder: an open pop-up or panel, then the Dig tool's piece and the tool, come first; the orbit's stop before clearing the selection |
| Shift+U | **The cutaway angle**: the U view (turned on if it is off) from 65 degrees down, over the middle of the network on the level shown, far enough to see all of it (18 m at the least). Shift+U again, or leaving the U view, gives back the pitch and distance you had. The camera only; the U view's lights are the tunnels' |

A dark **strip** in its own row just above the command strip -- the village news stands on top of it while it shows, so
neither covers the other -- says which mode is on ("Following Wenna Tallowby · End or a pan stops", "Orbiting the hall ·
Esc stops", "Cutaway angle · Shift+U: your view back") and, for a moment, what a bookmark key did. **Follow (End)** in
the party panel's actions does what End does, and reads "Stop following (End)" while the camera follows. None of the keys
works behind a pop-up or the HUD's scrimmed workspace.

**Edge pan** (UI §6; **Edge scroll** under Camera in the menu's Settings turns it off -- on by default, UI §8.1): rest the pointer in the 12-logical-pixel band along any window edge (24 physical pixels at 4K) for
a quarter second and the view pans that way at the keys' speed; corners pan diagonally, no faster. It is off over any
panel, behind a pop-up, in a text field, while a mouse button is held, and while the window does not have the focus or
the pointer is outside it. A diagonal key pan is now normalised too (W+D is no faster than W).

**At 720p and at 4K** the camera frames the same: one vertical field of view kept by height, zoom limits in metres,
frame-rate-independent easing, the edge band and the middle drag in logical pixels.

## Digging tunnels

The tunnels are one **network** (decision 0208, `tunnel/underground_graph.gd`): bores meeting at
junctions, reached from the surface by mouths. Press **B** (or the party panel's "Dig tunnel (B)"):
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
  (`tunnel/dig_readout.gd`): e.g. "14.0 m · 14 quanta · 32 min (crew of 3)" over "28 U spoil · clay 4 m
  (slow), sand 2 m (weak: brace)" -- length, the metres the network will cut, the time on the demo calendar
  (minutes under an hour, else hours to the tenth; decision 0421) for the crew that would dig it, the spoil, and the ground that slows or weakens it.
- **Refused, in words** (demo values, `tunnel/tunnel_rules.gd`): a point off the map or on top of the last;
  a new mouth inside an obstacle or heap, on a work spot or another mouth, or with someone standing on it
  or no way for the digger to reach it; a leg under a building or the well, or under the water; a piece
  under 8 m from mouth to mouth (two ramps) or over 64 m; a junction within 1.5 m of another node, or
  a meeting at under 40°; four bores at a junction already; a ramp joined (join the bore below it); a host
  being dug, worked or closed; a crossing at under 40° (a steeper one becomes a four-way junction); a bore
  passing within 1 m of earth of another it does not join ("it would break into Tunnel 3: join it
  instead"); a bend tighter than a 1 m radius, or one on a mouth's 4 m ramp; and the network's capacity,
  named for what the piece would exhaust -- all 24 mouths open ("join the tunnels you have instead"), all 96
  junctions and ends used, or all 96 bores laid. The tool itself opens while any piece could still fit: with
  every mouth taken, a connection between existing bores is still dug (decision 0361).
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
- Later phases: the switch's crossfade. The generated props and clips are P7's (decision 0371, below). The second
  level is P6's (below).

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
  foot of its cutting, a cellar's two-leaf hatch leaning against its bank. Since P7 the home's door is the library's
  burrow door at the foot of an open cutting, and it swings open for whoever comes through (below). The mound is an
  obstacle from the moment the room is laid.
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
| Hearth | 6 stone | 60 WU | home | heats the home while it has wood (see Winter); comfort while fuelled; glows and smokes while it burns; warms cellars near it |
| Table and stools | 2 planks | 8 WU | home | decoration |
| Rag rug | 1 wood | 4 WU | home | decoration |
| Lantern | 1 wood | 4 WU | home | decoration; one of the pooled lights |
| Hanging stores | 1 wood | 4 WU | home, cellar | decoration in a home; 10 U in a cellar |
| Shelf | 2 planks | 16 WU | cellar (two) | 20 U |
| Pantry rack | 2 planks | 16 WU | cellar | 30 U |
| Root bin | 2 planks | 12 WU | cellar | 25 U |

A planned fixture shows as a chalk ring; a resident **walks in and puts it in** (the work clip, 0.15 s of demo
time a WU): the residents selected when it was ordered, else the nearest one wandering on its own, three at
most at once, never at night. One called away (to bed at dusk, say) keeps the place for a game day (ten minutes at 1x) and comes back
to it (`burrow/fixture_crew.gd`). Since P7 the root bin, the hanging stores, the rug, the chimney pot and the large
bed are the library's (below); each keeps its procedural stand-in for a demo with nothing staged.

**Comfort** (a home's panel and the resident panel): 2000 bare, 4000 with a bed, 6000 with a hearth too (the
GDD's dormitory target) -- the hearth counts only while it is fuelled (out of fuel or let go out, it adds nothing;
decision 0571) -- and 250 a decoration up to 1000 -- the suggested layout reads 7000, "cozy". A readout
only (`burrow/room_fixtures.gd` COMFORT).

**The night** (`burrow/night_routine.gd`, on the demo calendar): at dusk, 20:00, everybeast not in an emergency or
the water goes home to bed -- through the round front door or the tunnels, whichever is cheaper -- parking the job in
hand (it takes it up in the morning), crosses the floor to its bed and lies down in it (the staged
`sleep_normally` clip, seated on the mattress by its body's lowest point). Beds go by REQ-SET-132 (its own bed,
else the nearest free one of its size -- a large bed for a big resident, a burrow bed for a small one; ties to the
lower room, then place) -- WARM beds first (decision 0571: a bed in a heated home, or any bed when no heat is
demanded, before a cold one). At 06:00 they get up and go back to work; whoever
is still on the way home turns back. The kitchen's cook is the **early riser** (`set_early_riser`): it gets up at 05:00
while it has the day's meals to cook (see The kitchen). **No bed** (or none of its size) -- it sleeps on the hall's floor
(REQ-SET-133; it goes in at the hall's steps and is not drawn), the panel says "No bed", and dusk's news names who.
A direct order wakes a sleeper; free again, it goes back to bed. Nothing parked is taken up before morning. A threat gets sleepers up by their beds until it
clears; one in the water or held by its rescue is left be. Paused, nobody moves; at 2x and 4x the night runs faster.
A walk home across the village takes under a game hour, so everyone is in bed by about 21:00 (the GDD's schedule
sleeps from 22:00). A home's hearth glows and its chimney smokes (at most 16 puffs a home) while it burns -- fuelled
and heat demanded (`night_routine.gd hearth_lit`, the winter's; decision 0571). Without a winter bound (a suite's
village) it keeps the old hours, 19:00 to 07:00.

**Cellars**: a cellar's capacity is its racks' (a bare cellar is no store); it is **cool** (the GDD's cellar,
350 per mille) while it is 1 m or more down, racked, and no hearth is within 3 m of it or in a room its passages
open onto within 6 m -- else it keeps like a pantry (750). A carrier who can take its load down walks the harvest
in at the hatch and shelves it; the racks fill in place -- jars on the rack, sacks by the shelves, strings on the
hanging stores, the bin's roots heaped -- as the stock rises.

**News**: a line said again straight after is counted, not repeated ("Tunnel 10: Good sticky clay... (×4)").

## The cool cellar: food moved where it keeps longer (decision 0611)

Digging pays off at the table. A root cellar dug and racked (above: 3 x 4 m, at least 1 m down, a shelf, rack, bin or
hanging stores in it, no hearth near) is a **cool** store: GDD §5.8's cellar factor, food there ages at 350 per mille
where the covered store ages it at 1000 -- it keeps 2.8 times as long. Nothing about the room changed; what is new:

- **Surplus food is carried down** (`stores/cellar_haul.gd`, stepped by `stores/demo_stores.gd`). Every 2 s of demo
  time the haul looks for food that would keep longer in another store with room: food nobody has reserved (the
  kitchen's takes are left alone), the lot that spoils SOONEST where it is first, but none with under 6 game hours left
  (not worth the walk). Its destination is the slowest-ageing store with room, the nearer on a tie -- so a covered
  store's harvest goes down into a cool cellar, a warm cellar's into a cool one, and the covered store's into the
  kitchen pantry (750) when that has room. A move is at most 48 U, §5.2's smallest carry (12000 g) of raw food at 250 g
  a unit, so anybeast who can carry may take it. At most 4 moves stand at once. Part of a lot is never under 1 U, and
  with every lot row taken only whole lots move. A move that cannot be made (walks failing, the pick-up or the
  shelving refused) leaves the store that failed it alone for 60 s, and a cellar warmed by a hearth meanwhile is no
  longer a destination.
- **On the work board** as HAULING, source **Food stores** (`work/stores_work.gd`): "Move to a cooler store -- 9.0 U of
  carrot: Covered store → Root cellar 1 (keeps 2.8× as long)". The board claims it for an idle carrier; the claim holds
  the room at the cellar (the Pantry shows it Incoming there). The carrier walks to the store, picks the food up (1 WU),
  carries it -- down the hatch to the cellar's middle when it can take a load below, else to the hatch -- and shelves it
  (1 WU). Pause, Cancel and Reassign work before the pick-up and are refused with the food in hand.
- **The lot moves, it is not re-made** (`farm/farm_pantry.gd` MOVING FOOD BETWEEN STORES): §5.8's "changing stores
  never resets age" and REQ-SET-111's exact split. The food stays booked at its store until it is shelved; nobody else
  may take from it on the way. Called away (another order, the night) the carrier's load goes back to its store and the
  move waits again; a walk that fails three times closes it. The pantry's ledger never sees a move.
- **The Pantry says why** (`farm/farm_pantry_rows.gd` `why_text`): under the stores, "Why food keeps longer in some
  stores:", a line a store in its own words -- "Root cellar 1 — cool: deep, racked and away from any hearth: food keeps
  2.8× as long as in the covered store", a warm one "warm: a hearth within 3 m of it warms it" -- and a row with food in
  hand says "· 5.0 U being moved to a cooler store". The Stocks rows already give each lot's store and its days to spoil.
- **For later stores** (`farm/farm_storage.gd` STORAGE CLASS): a store declares its §5.8 class (`storage_class`, open
  pile 1500 / covered 1000 / pantry 750 / cellar 350) and its `why`; a ground pile or a stockpile zone that says OPEN_PILE
  is hauled from by the same rule. A cool cellar is the CELLAR class, a warm one keeps like a PANTRY.

## The Cellar building (decision 0612)

Brendan's ruling on 0611's P7 was "Build both cellars": beside the dug root cellar stands the GDD's **Cellar** building
(`stores/`), every figure read from the settlement's own tables (`scripts/core/building_definitions.gd`,
`construction.gd`): wood 20 and stone 60, 900 WU, 1,000,000 g -- **2000 U** at the GDD's 500 g a unit -- and §5.8's
cellar factor, 350 per mille.

- **Placing**: the Pantry's Stocks tab has a **Cellar buildings** line and **Build a cellar…** (no key). It closes the
  Pantry and arms the placing tool (`stores/cellar_place.gd`): a ghost of the library cellar follows the pointer, turned
  to the square, brass where it may stand and clay with the reason where it may not (off the village, an obstacle, a
  work spot or mouth, a building, the beds, the water, a tunnel or dug room, the other cellar). Click places it; Esc or a
  right click puts the tool away. At most two stand. Placing deducts nothing.
- **Building** (`stores/cellar_builders.gd`, REQ-SET-124/125/126): four places a cellar on the work board's **Food
  stores** source, claimed for idle carriers. A builder walks to the open stockpile, lifts a load (2.4-4.8 U, its §5.2
  carry at 5000 g a unit -- only now taken from the stores), carries it to the site and sets it down; once everything is
  there they build it, their time summed (a WU is 0.15 s). Called away, a load goes back into the stores whole. The
  Pantry's **Cancel** lets the builders go and returns what was delivered: all of it before the work, 80% after.
- **The look**: the library cellar model pressed flat as a marked footprint, rising with the work, whole when built; a
  plank stack and a heap of rubble at its site grow with the wood and stone; its name and percent over it. Its footprint
  is an obstacle from the moment it is placed.
- **Built, it is a store like any other**: the CELLAR class, filled by the haul, explained by the why note ("Cellar 1 —
  a large store above ground: food keeps 2.8× as long as in the covered store").
- **Brendan's rulings** (decision 0612, 2026-10-01): it is **open from the start** (`cellar_rules.gd UNLOCK`, one
  constant; the GDD's M1 needs 12 residents); a unit is **500 g**, so it holds 2000 U; there are no job slots, so **any
  idle carrier** hauls its food ("Hauler 2"); it is drawn as the **library cellar at its lookdev size**.

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

## The generated props and clips (decision 0371)

The underground pass's seven props and nineteen clips (decision 0204) are in, with their known defects fixed in Blender
or in code; nothing was spent. Every piece keeps its procedural stand-in, drawn when nothing is staged (CI).

- **The mouths** (`tunnel/tunnel_mouth.gd`). A tunnel's ramp is an **open cutting**: its floor follows the ramp down --
  the floor the residents walk -- between hand-dug earth walls, its middle worn paler, and the ground is cut open over
  it (`world/ground_cut.gd`: the ground's triangles over the hole dropped, the rest of them drawn again round it in the
  ground's own grass). Where the bore goes under the turf the cutting opens into a forecourt and the generated
  **tunnel arch** stands, its doorway's slab cut out in Blender, framing the bore, a wall lantern on its lintel; beyond
  it the bore goes on dark. A resident walking the cutting is drawn on the surface too, so it is seen going down and
  under the arch. Nobody is sent to stand over a cutting or its forecourt, and no spoil heap is laid on one
  (`tunnel_mouth.gd cutting_gap`, asked by `cast/cast_space.gd on_mouth` and `tunnel/tunnel_heaps.gd`).
- **The burrow door** (`burrow/room_view.gd`, `burrow/door_swing.gd`). A home's door ramp is an open cutting down to
  its door: the generated burrow door, its round leaf split from its stone face in Blender and hung from a hinge. It
  swings open as a resident comes through below, and shut behind it.
- **The crouch walk** (`cast/demo_actor.gd`). In a bore that makes a resident stoop, its walk is the crouch walk
  (Meshy's `Cautious_Crouch_Walk_Forward`), played at the speed its planted feet move; the procedural stoop adds only
  what the crouch leaves to clear. A mole, upright in every bore, walks. The mouse keeper's crouch is pinned again as it
  is staged (`tools/stage_demo_assets.py REPIN`).
- **The dig** (`cast/strike_clock.gd`). A digger at the face with the swing (the mole digger and the badger quarryman:
  Meshy's `Heavy_Hammer_Swing`) swings it once per quantum cut, timed to land as the cut falls, and stands between
  swings. It is never looped: the swing ends turned 68-81 degrees.
- **The hand lantern and the basket** (`tunnel/warren_kit.gd`): the library's candle lantern (made at the furniture
  budget, its horn panes glowing) set down at the face, and the library basket for hauling.
- **The fit-out** (`burrow/fixture_kit.gd`): the root bin, the rag rug, the chimney pot on the mound, the hanging
  stores -- at the furniture budget, in parts, hung by their wall brackets from the room's ring beam, a cellar's
  strings showing one by one as it fills -- and the large bed, the library bed lengthened in Blender without
  stretching its quilt. The library root bin is modelled full of roots, so it shows full whatever the cellar holds.
- **The stairs** (`tunnel/stair_view.gd`): timber tread boards whose nosing overhangs a timber riser, over packed earth,
  in a procedural grain.

The fixed props are made by `tools/make_demo_derived_props.py` (Blender half `tools/demo_derived_blender.py`) from the
library high-polys, into `assets/props/<key>__<part>.glb`; `stage_demo_assets.py` runs it with the props.

## Farming

The twelve field beds -- the six world beds and the south field's six (decision 0886) -- and the kitchen garden's beds,
once laid out (below), grow **individual pantry ingredients** -- radish, turnip, carrot, beetroot, parsnip,
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
- **Recipes**: every pantry item in catalog order with its stock -- the crops, then the catch, dried fish and flour
  (decision 0602) -- and the content library's dishes the picked one feeds. Every recipe-book dish the kitchen cooks
  from it is marked **Cookable (active)**, with how the cook picks among them; the rest are ideas. Salmon and carp are
  not in the library's pantry and say so. The index is `farm/pantry_index.json`, rebuilt by
  `python3 tools/make_demo_pantry_index.py`.
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
| Plant… (bed panel) | The crop picker: every ingredient, sowable ones first, with its ROLE (decision 0881: keeping root, fresh greens, soil restorer, flour crop -- its two differences and its uses, read from the kitchen's dishes), growth hours, yield, family and its rotation effect in this bed; the rest say why not (soil, planting window). It stays current while open (decision 0391, review F36): when the calendar or the bed changes, each crop is enabled or refused where it stands -- no row moves, the focus and the scroll stay -- and its title has today's date. Its title and Back stay in view; only the list scrolls |
| Water / Harvest / Clear / Compost / Cover | Given to the selected residents, or queued for the field crew (the fieldworker and gatherer take queued work while wandering) |
| Drain | A wet or waterlogged bed: a resident digs a ditch round it (6 WU); its moisture drops at once to the top of its crop's band, and the ditch sheds up to 1000 a day for good (decision 0205) |
| Raise / Bank | A resident fetches 2 U of tunnel earth from the nearest spoil heap or the stores that hold it and carries it to the bed: a raised bed drains and is warmer at night; a banked bed keeps half of each dry day's loss. Earth adds no fertility. Cancelled (or unable to reach or work the bed) with the earth in hand, the resident carries it back to where it came from (decision 0401) |
| Rest | Rest the bed fallow (+0.5 fertility points a day; nothing is sown) |
| V | Map layer: moisture, then ripeness, then the water service, then the water range, then the routes, then the woods, then off -- or pick one on the Map layer picker (see Map layers) |
| K / Food | The Pantry |
| T / Planner (T) (bed panel) | The seasonal planner (below) |
| Compare… (bed panel) | Every bed side by side, sortable, ringed and ranked on the map (below) |

Threats: spring is wet (beds waterlog and stop growing -- Drain them, run a tunnel under them, or raise
them, or fit a drain outlet to a tunnel under them; every bed sheds up to 500 a day above its band's top, so in the
first spring only the Ideal spell waterlogs a roots bed, around spring 8), summer dry (water), frost nights are announced at noon the day
before (cover or raise; the first spring's is the night into spring 11), blight (first outbreak at the
midnight opening spring 12 -- the first threats now fall about two days apart) spreads to
the next beds at midnight unless the blighted bed is cleared, and a ripe crop starts losing yield after
48 hours and withers at 120. A finished tunnel under a bed is TRANSPORT ONLY (decision 0884): fit an outlet (the bed
panel's Tunnel outlet box, a 6 WU job) and set it to Drain -- the bed sheds into a dry tunnel -- or Feed -- a tunnel
with a mouth at the real stream's edge (dry ground within 2.5 m of its waterline -- inside the square, by the ford or
at x 19.5 m, z 4) waters it -- or Shut. Details and every number's source: `farm/*.gd` headers.

## Crop plans: roles, the kitchen garden, harvest plans, tending and tunnel outlets (decisions 0881-0885)

Review group X (ECO-001, ECO-003, ECO-004 with feature #48, ECO-006, ECO-007). Every crop number is still GDD §5.6's.

- **Crop roles** (0881, `farm/farm_crop_roles.gd`): a crop's role is its §5.6 row's -- Keeping root (keeps 10 days,
  ripens in 5), Fresh greens (sown summer and autumn, keeps 6 days), Soil restorer (gives the soil 800 fertility, keeps
  20 days), Flour crop (10 U a bed, ripens in 8 days) -- with its uses read from the kitchen's dishes, the mill and the
  raw-emergency table. Siblings of one row stay equal. Shown in the crop picker and the harvest plan.
- **Twelve field beds** (0886, Brendan's balance ruling E5): the six world beds and the **south field**'s six 2 m tiles,
  one 6 m x 4 m field on the grass south of the covered store, laid from the start, loam and clay.
- **Sowing in season** (0886): the live village starts with the tending policy **Sow empty beds in season** on for the
  field, so hands-off play sows: each empty bed gets the crop chosen for it, else its **rotation**'s next crop -- GDD
  §5.6's grain → beans → roots (wheat, pea, carrot) on loam, grain → beans → grain on clay, roots only on sand; the bed
  panel's **Rotation ▸** steps a bed through the cycles its soil can follow. A crop waiting for its window is said once.
- **The kitchen garden** (0883, `farm/farm_garden.gd`): four 2 m garden sites round a cross of paths across the road
  from the kitchen, between the square and the covered store, drawn as pegs and string. Click one and **Lay out a bed
  here** (at once, free: a designation); **Take up** a bare bed again. The garden's beds are Bed 13-16 and share one plan
  (Planner ▸ Kitchen garden: its crop and **Sow every empty garden bed**), a **work shelf** (GDD §5.9 Shelf: a 200 U
  pantry store at the pantry's 750, up with the first bed) and the **well**; each bed's panel and the tab say the
  walking to the shelf and the well. **Between meals (09:00-15:00) the cook tends it**: the routine crew and the work
  board leave its jobs to the cook while the cook could take them, for up to a game hour (the tab turns it off).
- **Harvest plan** (0882, Planner ▸ Harvest plan, `farm/farm_harvest_plan.gd`): Steady table, One preserving harvest or
  Custom dates (pick a bed's row, Sow a day earlier / later) for the empty beds with a crop chosen; each bed's sowing,
  ripening and harvest; each harvest day's work against the field crew's hands, its food against the stores' room and
  what the kitchen eats before it spoils, in clay with a suggestion when overloaded (a later sowing, or leave a bed
  empty); **Book this plan** orders today's sowings and books the rest for their days.
- **Tending** (0885, Planner ▸ Tending, `farm/farm_tending.gd`): for the field beds and the kitchen garden, Protect from
  forecast frost (Cover), Water below the suitable band (Water), Avoid waterlogging (open a fitted drain outlet, shut a
  feeding one) and Sow empty beds in season (0886: on for the field at the start, the others off); a daily budget
  (0-32 WU, 16 by default); the next day's most shown first; only what a policy could not do goes to the news.
- **Tunnel outlets** (0884, the bed panel's Tunnel outlet box): see Farming's threats above. The weir's sluice and
  leat (0441) are the closable inlet for Bed 2, 4 and 6.

## The seasonal planner (decision 0451)

Review group O (F45, UX-008, ECO-005's presentation, P1's "Seasonal forecast", P4). **T**, or **Planner (T)** in the
Farm panel's head, opens it (`farm/farm_planner.gd`): a modal of the input gate in the HUD's modal rectangle, like the
Work screen -- T, Esc or its "×" close it, Tab stays inside, focus goes back where it was -- at the interface scale.
(T is UI §5's calendar key, `open_calendar`; it was the Dig tool's alias for B until decision 0492 gave it back, and G
went to "Run until…".) Open, it is a planning surface: with "Pause while planning" on it pauses the village. Four tabs (and the crop plans'
Harvest plan, Kitchen garden and Tending: decisions 0881-0885, above):

- **Farm overview** (`farm/farm_plan_rows.gd`): one row a bed -- bed, crop, stage (and the verb when it needs attention:
  "Needs: Drain"), harvest when and how much, soil moisture in the bed panel's words ("Good · 66%"), the work on it and
  who has it (or queued, paused, blocked), the next sowing. **Needs attention** (a warning Needs line, a harvest waiting
  for store room, a job nobody can reach) and **Harvest soon** (ripe, or within 24 game hours at today's rate) filter
  it, counted on their buttons. A growing crop's date is the bed panel's own "ripe in about N h" dated on the one
  calendar -- "≈ Spring 9, 14:00 · about 5.1 U", an estimate at this hour's growth rate; a ripe crop's dates are the
  rules' (full yield until 48 h after it ripened, withers at 120). A row (click or Enter) closes the planner, opens that
  bed and centres the camera on it -- the news' "Go to".
- **Season calendar** (`farm/farm_season.gd`, `farm/farm_timeline.gd`): this season or the next, as a timeline of lanes
  (the four crop rows, weather, frost, blight, beds, meals, and the **Fuel** lane -- the hearths' rule for the season,
  autumn's twelve-day winter target, today's "No current heat demand" or how long the wood heats the village, to the last
  heated hour; decision 0571) or as a **Table** of the same entries in words. Each entry is
  **Scheduled** (solid bar: §5.6 planting windows, the season's §5.10 baseline, the demo's frost and blight schedule,
  the season event once announced -- three days ahead, never before -- a ripe bed's grace and withering, the kitchen's
  planned meals), **Recorded** (small square: each past day's weather), **Now** (ringed diamond: today's) or **Estimate**
  (outlined bar: when crops sown in their window would ripen at a full rate, each bed's ripening, until when the food in
  store makes meals -- the HUD's Ready food from today). What is not known is said in words. Today is the HUD's date.
- **Soil plans** (`farm/farm_soil_plans.gd`, ECO-005): for one bed over one season, **Compost, then sow**, **A legume in
  rotation** and **Rest it fallow** side by side -- what each sows and when, this season's harvest, the fertility at the
  season's end, what the next crop would then yield, and the staff time (the jobs' own work, and staff-days of 10 game
  work hours, GDD §5.3), from GDD §5.6's own rules; presentation only (the bed's own buttons act).
- **Record** (`farm/farm_record.gd`): yesterday, this season's days as a table and the season's totals -- harvested,
  food used (cooked and raw), portions eaten, spoiled (in store, on the table, a cancelled batch), who went without and
  crops lost -- read only from committed outcomes: the pantry's ledger of food stored, withdrawn and spoiled (never
  reset; every pantry item, so a catch, the rack's dried fish and the mill's flour count with the crops -- "harvested"
  is everything stored), the kitchen's counters and meal log, and the crops that withered. Each day is closed at the farm's hour after
  its midnight (once the kitchen has tallied its supper) and posted to the village news (place Farm), each season's
  totals at its last day.

**Compare…** in the bed panel (UX-008, `farm/farm_compare_view.gd`) swaps the readout for every bed side by side --
ready, harvest, moisture, fertility -- sortable by Harvest, Ready, Moisture, Fertility or Bed; the order holds while it
shows (press a sort to sort again), a row opens that bed with the view kept, and the beds wear a cream ring and their
rank under their label ("#2 by harvest") until Back. There is no bulk bed order to preview.

## The kitchen (decision 0381)

Breakfast and supper, cooked from the pantry's real stock (`kitchen/`). The recipe book (`kitchen/dish_book.gd`,
decision 0601) holds eight dishes, each a content-library dish cooked as a GDD §5.7 row with that row's numbers; the
first three are below, and **the recipe book** after them adds the rest. **Wild oat
porridge** at breakfast (the GDD's `porridge` row: grain 2 U + water 2 U, 12 WU) and **Togget's vegetable soup** at
supper (its `root_stew` row: roots 3 U + water 1 U, 16 WU), each batch 2 portions of 1800 NP that keep 24 h, and 0.1 U
of wood. Grain is wheat, barley or oats; roots are radish, turnip, carrot, beetroot, parsnip or onion -- and potato once it is grown (each crop's
§5.6 row). If one dish's food is short the other is cooked. **The third dish** (water part B, decision 0436): at
supper, whenever the stores hold a batch's fresh fish and roots nobody has set aside, the kitchen cooks **poached perch
or trout** instead of the soup -- the GDD's `fish_stew` row: fresh fish 2 U (any of the six species) + roots 2 U + water
2 U, 20 WU, 3 portions of 2200 NP that keep 24 h; both inputs reserved from real lots and withdrawn together. Dried fish is
not the stew's `fish`: it is the village's reserve, eaten as it is by a hungry resident (1800 NP a unit, after anything
spoiling sooner). **The feast's dish** (decision 0438): the GDD's `bean_hotpot` row (beans 2 U + cabbage 2 U + water 2 U,
20 WU, 3 portions of 2100 NP, keeping 36 h), cooked for an **occasion** -- the regatta's supper -- from the food the
regatta reserved. Since the recipe book (decision 0601: Brendan's "the hotpot cooked from the start") it is an everyday
supper dish as well; the batch 7 integration kept that ruling (decision 0902). Its **second course** (decision 0682), the
`nut_loaf` row (flour 2 U + nuts 2 U + water 1 U, 24 WU, 3 portions of 2600 NP, keeping 72 h), is the recipe book's one
OCCASION dish: cooked after the hotpot for the same occasion, each guest eating one portion of each, and never chosen by
the cook for an everyday meal.

**The recipe book** (decision 0601). Adding a recipe is adding a row to `kitchen/dish_book.gd`; every other table is
built from it. Beside the three above:

| Dish | Library recipe | Cooked as (§5.7) | Takes | Meal |
|---|---|---|---|---|
| Barleymeal porridge | `pearls_lutra::PL_RECIPE_barleymeal_porridge` | `porridge` | barley or oats 2 U + water 2 U | breakfast |
| Wild-beetroot soup | `triss::TRI_recipe_wild_beetroot_soup` | `root_stew` | beetroot or onion 3 U + water 1 U | supper |
| Vole vegetable stew | `taggerung::TAG_recipe_vole_vegetable_stew` | `root_stew` | carrot, onion or turnip 3 U + water 1 U | supper |
| Poached dace | `taggerung::TAG_recipe_poached_dace` | `fish_stew` | dace 2 U + any roots 2 U + water 2 U | supper |
| Bean hotpot | the GDD's own | `bean_hotpot` | pea or broad bean 2 U + greens 2 U + water 2 U; 3 x 2100 NP, 20 WU, keeps 36 h | supper |

A dish naming its own ingredients takes only those; the numbers are its row's (0.1 U of wood a batch, as every batch).

**The directed families** (decision 0603, Brendan's DEC-045 and tuning E2/E3): eleven more dishes, ten on Brendan's DEC-045 rows
in §5.7's format, confirmed by him ("Approve all"). Cookable now: **Breakfast oatcake** (oats), **Barley farl** (barley),
**Haversack hardtack** (flour, keeps 480 h), **Spring salad** (greens and roots), **Baked fish** (fresh fish, no roots:
E2), **Durral's dried-fish biscuit soup** (dried fish, flour and roots: E3), and -- with the foragers' nuts and
mushrooms (decision 0681; the library's hazelnut and mushroom are those items, decision 0902) -- the **Vegetable pasty**,
**Hazelnut scones** and the GDD's **Woodland pie**. Waiting, listed with why: the **Turnip, potato and beetroot pie**
(potato: crops) and **Raspberry cordial** (honey: hives; its raspberries are the foragers' berries) -- a drink, never a
meal's dish. Potato and honey are pantry items with no source yet. The Recipes tab marks each "Cookable (active)" or "Waiting (needs ...)", the Kitchen tab lists
"Waiting for ingredients", the field guide says the same. **The cook's choice**: of the meal's dishes whose free food makes a batch, one that feeds the
whole meal, then the one whose food keeps least long (fresh fish, then greens, roots, grain), then the one the village
likes most, then the book's order; with none, the other meal's best; deterministic. **Favourites** (`kitchen/dish_favourites.gd`): each species' liked
and disliked dishes -- moles Togget's soup (Togget is a mole) and the beetroot soup, badgers the beetroot soup,
squirrels the barleymeal and the vole stew, moles also the root pie (their deeper'n'ever pie), otters the poached dace, mice and the beaver the hotpot, the beaver
disliking both fish stews; all but the moles' Togget's soup are proposals. Data and display only: no mood. A resident
who ate a favourite reads "Last meal: supper, beetroot soup — a favourite"; the Kitchen tab's plan says "(liked by 2)";
the field guide's dish entries say whose favourite each is. Monotony counts §5.7 recipes, so the three soups are one.

- **The day** (decision 0421). Breakfast is called at 07:00 and served until 08:59; supper at 17:00 until 18:59, an
  hour before dusk (so whoever goes to eat raw food at its end has eaten before bed). The cook (the keeper; a free
  resident stands in) rises at 05:00 for breakfast and cooks supper from 15:00 (out on the table a portion ages
  fast: see decision 0381). It fetches the planned meals' food -- reserved from real
  lots, soonest to spoil first, and only withdrawn when a batch starts -- from the **kitchen pantry** at the path's
  end (10.5, -2.6; 120 U, 750 per mille) or wherever it is, cooks at the cauldron (steam rises), carries each meal's
  pot to the hall's east table and puts the bowls out. Diners are called once a meal is on its way (their work is
  parked and taken up after), sit at the hall's tables (`chair_sit_idle` when staged) and eat one portion each.
- **Water** is drawn at the well into the butt beside it (1 WU a unit). **Keep water drawn** (on) keeps the butt
  full: whoever is free and not due at a table draws, two at most.
- **Fed.** Each resident's need is the GDD's NP a day (6000 small, 7200 medium, 9600 large). The resident panel
  reads "Fed · 72% full · 1800/6000 NP today" and "Last meal: breakfast, porridge" (fed above 3500, peckish to
  1501, hungry below), the monotony memory when it applies -- its own rows, right after what the resident is doing;
  a group's rows and the roster show the word. No penalties.
- **Short.** A meal called with nothing coming raises "No supper tonight: <why>. To fix: <where>" in the village
  news; at its end anyone hungry eats raw roots or cabbage nobody has reserved (at most 3000 NP), the rest go
  without, and the tally is posted ("Supper, day 2: 8 ate, 1 went without").
- **Finalized.** That tally is provisional while a diner still holds its bowl. Once nobody holds anything of the
  meal, the kitchen publishes one **meal finalized** event with who actually ate it (`kitchen.gd` `finals`,
  decision 0997); the regatta's feast and the people's memories read that, not the 19:00 tally.
- **The Kitchen tab** (Pantry, K): the cook and what it is doing, any refusal and its fix, the next meals, the pot
  and table, the butt and fuel, how the village is fed, the last meals; **Cook now** and **Draw water** (each with
  its action card, from the same decision as the order), **Keep water drawn**, **Cancel the next meal** (a batch
  already cooking yields half its food as spoiled food; fetched food stays in the larder).

Interrupted work loses nothing and makes nothing fresher: a cook called away leaves the batch at the cauldron for
whoever cooks next; a load in hand is delivered before bed. Details and every number's source: `kitchen/*.gd`
headers and decision 0381.

## Winter: heating fuel, the cold and firewood (decision 0571)

Brendan's rulings of 2026-10-01; `winter/`. Presentation only: the settlement simulation is never written.

- **The hearths** (`winter/hearth_fuel.gd`): the hall's, every burrow home's fitted hearth, and -- once it is built --
  **the infirmary's own** (decision 0995, Brendan's ruling on the review's R03: GDD §5.9 has the infirmary "heated", and
  its 6×6 interior is one normal hearth's) burn the village stores' wood by GDD §5.8's continuous demand -- **4 U a day in winter, 2 U on a spring or autumn day whose mean is under 10 °C,
  nothing in summer** (1 U heats a hearth 6 hours) -- taken each game hour through a milli-U accumulator (166 or 167 milli
  an hour in winter; exactly 4 U a day, never a milli-U adrift). The homes take theirs first, in row order, then the
  hall, then the infirmary; each hour all or nothing. A resident inside a building is read in **that** building's room
  (`resident_brain.gd interior`): a patient in the infirmary warms at the infirmary's fire whether the hall's burns or
  not, and the infirmary's demand counts in the fuel-days, the top bar's heating demand and the winter projection; with
  a patient inside, an infirmary out of fuel and below freezing is reported as a cold home. A heated room holds **18 °C**; a hearth **out of fuel** lets its room move halfway to
  the outside air each hour (REQ-SET-131) until wood comes in -- then it burns again the next hour. A hearth glows and
  smokes while it burns (fuelled and demanded: `night_routine.gd hearth_lit(r)`, which the glow reads), and counts for
  its home's comfort while it is fuelled.
- **The day's mean** is the mean of its 24 hours' air, so a demo frost night's spring or autumn day (9.5 °C, 7.8 °C)
  demands heat and the hearths burn through the frost.
- **Fuel-days** = the wood over today's heating demand plus the last three days' mean cooking wood; with no heating
  demand the top bar says so. Recomputed every game hour. Under 2 days with frost forecast (today and the next two days'
  §5.10 temperatures -- an event only once announced -- and the demo's frost nights), the village news warns with the
  **last heated hour** and the hearths (REQ-SET-147).
- **The cold** (`winter/cold_exposure.gd`): clothing tier 1 for everyone. Outdoors (or in the water), or in a hearth's
  room below 0 °C that is not heated, a resident gains 1 exposure-hour an hour (2 in a hard freeze); in a heated room it
  clears 2 an hour (`scripts/core/needs.gd`'s own constants); in the tunnels or a cellar, neither. Integrated over the
  calendar's ticks each frame, exact; a jump of more than a game hour in one frame (a skip) is not lived.
- **Chilled** at 4 exposure-hours (capped at 8): the resident **works at 80%** (§5.10's storm factor) -- the farm's, the
  woods', the bridges' and the spoil heaps' work -- and is sent for a **warm-up break** (`winter/warm_up_task.gd`) to the
  nearest lit hearth -- its own bed's home, else the nearest heated home, else the hall -- parking its job, back to it
  when **warmed through** (exposure 0), or as soon as that fire goes out. It is Chilled until warmed through. **No
  health is lost and nobody dies of cold.** The party panel says it ("Chilled — 4.6 exposure-hours, last outdoors at
  -5 °C; works at 80% until warmed through at a heated hearth"; "Why: Chilled — warming up at a lit hearth"), the
  Residents list adds "chilled", the news warns, and says when they are warmed through.
- **Beds** go to warm homes first (above). **The Firewood order**: while the stores hold less wood than the twelve-day
  winter projection -- in autumn and winter, or on any day heat is demanded -- one "Firewood" order stands on the woods'
  board (deadfall first, else the nearest fellable tree in a forestry zone; never a conservation zone), listed under
  Woods on the Work screen, and **Urgent** (the work board's bucket 2) under 2 fuel-days or while a hearth is out. It is
  the standing orders' built-in order (decision 0711): listed on the Work screen's Standing orders tab, where it can be
  switched off.
- **Heating fuel** (the top bar's Fuel slot, UI-SET-003): "2.5 days", or "No demand" ("No current heat demand" in its
  tooltip and the ledger), in clay with the warning glyph under 2 days. **Its click opens the breakdown**
  (`winter/fuel_panel.gd`, a modal; Esc closes it): the wood, today's demand, the last heated hour, in autumn and winter
  the **twelve-day winter projection** (every hearth at 4 U a day plus the cooking mean, REQ-SET-114) with its progress,
  the Firewood order, each hearth's state and room temperature, who is Chilled, and the **emergency choices**, never
  taken by themselves: **Consolidate sleepers into heated homes** (the sleepers packed into the fewest homes with a hearth
  that hold them, sent to their new beds, and the hearths of the homes left empty let go out; its tooltip says what it
  would do) and, per hearth, **Let it
  go out / Light it again**.
- **The season's notes**: at autumn's first dawn the twelve-day projection; at the first winter's dawn the
  **preparation summary** (REQ-SET-149: ready food, heating fuel, warm beds, who works outdoors), pinned on the top-centre
  card until you dismiss it. The planner's calendar has a **Fuel** lane (see The seasonal planner); the guide has a help
  topic and a field-guide entry.
- **Skip to next season** (the Demo Lab, F8; `winter/season_skip.gd`): the one calendar runs on, an hour crossing at a
  time, to **06:00 on day 1 of the next season**, exactly on the tick. The farm's hours run (the crops grow, ripen and
  wither, the beds take their rain, the season's event is drawn, the stores age), and the hearths burn in step, each hour
  on its own day's weather. **Skipped**, and the news says so: the residents' walking and work (they carry on where they
  stand), the kitchen's meals (none is cooked or eaten, nobody's hunger falls; the table's portions age), and the cold.
  The woods, the pond's ice and the people catch up on the next frame. The skip's own real time is forgiven, so it is not
  a stall. The spring opening is unchanged.
- **For the balance sim**: `demo_village.winter().metrics_into(out)` -- the wood burned, the hearth-hours heated and out
  of fuel, fuel-days, today's heating and cooking demand, the projection, the Chilled now and ever, the breaks sent.

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
  The dig's lead says its sayings under its own name, plainly ("Wenna Tallowby: "A big job, this. Dug before
  supper.""); only Tuppen adds a word of his light molespeak. The rock warning is plain (decision 0491).
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

## The art passes, wired (decision 0903)

Three paid art passes -- the food, plants and props pass (decision 0941), art pass 2 (0951, DEC-047) and art pass 3
(0971, DEC-048), with 0972's flax, linen and wax icons -- are staged by `tools/stage_demo_assets.py`
(`--only art` restages them alone: `make_demo_food_art.py` and `stage_art_passes.py`, which runs `make_art_pass2.py` or
`make_art_pass3.py` only when a pass's record is missing) and drawn by the demo. **Every one degrades to the stand-in it
replaced** when it is not staged (CI, a fresh clone): the same code runs either way.

| Art | Where it is drawn | Without it |
|---|---|---|
| `apple_tree`, `pear_tree` | the orchard's trees, at every age (a sapling 0.2-0.45, young 0.5, full-grown 1.0, the old trees 1.11 of the prescaled model; the pear let down its plate) | the oak and its sapling, drawn small |
| `raspberry_canes`, `bramble_blackberry`, `strawberry_patch` | the orchard's berry hedge; the patch is a third season slot | the oak's crown knee-high; five strawberry plants |
| `apple_basket` | the old orchard stand: one full basket per started third of its store while it holds apples most | baskets and the fruit heap |
| `hazel_bush` (3), `mushroom_forage` (2), `herb_patch`, `bramble_blackberry` (2) | beside the four foraging spots (`forage_view.gd` THE SPOTS); the hazels and brambles are season slots | nothing drawn at the spots |
| `infirmary_ward` | the infirmary (prescaled to its 5.5 m envelope, sunk its 0.33 m earth base; the door's herbs and shelf before its front) | the borrowed `residence` |
| `herb_patch` | the infirmary's herb patch, smaller as its stock runs down | twelve procedural clumps |
| `pine_scots`, `yew_ancient` | fifteen evergreens (ten pines, five yews) in the woods past the clearing (`world/evergreens.gd`: never felled; their trunks are obstacles either way) | none drawn |
| `oak_mature_bare` | every bare oak in winter (`season_view.gd` THE AUTHORED BARE OAK) | the leaf triangles cut from the leafed oak |
| `tunnel_set` | every brace frame (and the rooms' ribs) | the old `tunnel_brace`, else a box frame |
| `rock_face` | the bore's walls where the ground is rock (`bore_dressing.gd` ROCK FACES) | nothing |
| `hall_stage2`, `hall_banner`, the `_windows` models | the great hall at tier 2 (its roundels kept, its own chimney), its four banners, the homes' window glow (see The hall, Night lights) | the composed chimney and roundels; dark windows |
| portraits, the tapestry's ground and emblems, the chronicle's page | the group tiles (two across while shown) and the inspector's person header; the tapestry panel; the chronicle | the drawn panels |
| pass 1's and 3's icons | by key: an item's `item_<pantry key>` (apple, pear, berries, nuts, mushrooms, herb, potato, honey, flour, dried fish; jam, cider, flax, wax and the rest wait for their items), a dish's `dish_<recipe key>` in the Kitchen tab and on the Stocks rows | the item's model icon, else its roundel; no dish icon |

**The modelled berries.** The bushes carry their berries in their texture, so the tree shader hides them
(`season_leaves.gdshaderinc` `berry_hide`): a ripe red or dark purple texel is painted its bush's leaf colour as the
hedge's (or the berry patch's) stock above its floor runs down, and every one while it is dormant; a hidden berry is
leaf from then on, so it tints and falls with the leaves. The hazel's nuts are brown as its bark and stay drawn.

**Mapped, not drawn yet** (their features are not built): the wildlife, the bee skep and the bees, flax's plant row,
the preserving and brewing props, fire, lightning and the winter ice, the find icons for coins, an old map and a spring,
and the herb infusion's icon. Each mapping file names the code that will draw them
(`docs/art-reference/asset_library/food_art_mapping.json`, `docs/art-reference/art_pass2_mapping.md`,
`docs/art-reference/art_pass3_mapping.md`).

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
  from its mesh at boot (`forest_root_field.gd`, 12.5 cm cells, about 8 ms a model; kept by the mesh's resource path,
  so a Restart demo bakes nothing again and keeps nothing more, decision 1048) and read in the
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

## The seasons (decision 0551)

The woods, the grass and the ground follow the one calendar (`seasons/`; presentation only -- nothing reads
it back). Twelve days a season; each change eases in over a tree's first 2.5 days, which every tree starts up to
1.5 days late by a stable hash of where it stands, so no season arrives as a swap and no two neighbours turn
together:

- **Spring**: fresh light green, and the oaks' catkins (a pale speckle) over the first nine days. The leaf-out
  itself is the thaw at the END of winter, so the demo, which opens on Spring 1, opens in leaf.
- **Summer**: the trees as authored.
- **Autumn**: each tree turns, at its own pace, to its own gold, ochre or russet (a tenth of them a dark red),
  the crowns kept whole; the grass dries a little, fallen leaves gather in drifts (thickest toward the woods),
  and from day 3 a few leaves fall over where the camera looks (`falling_leaves.gd`: one pool of 40, at the
  game's speed). **Reduced motion turns the falling leaves off entirely.**
- **Winter**: the leaves come down over the first days; then the oaks and beeches stand bare -- drawn as each
  model's own **bare boughs** (`bare_boughs.gd`, its leaf triangles taken out once at boot) -- but for the trees
  that keep their dry leaves (most young oaks, a third of the beeches, a few old oaks). The weather's frost and
  snow lie on the boughs' upward faces as they do on the roofs. The grass is dry; old leaves lie under the snow.
  The demo stages no conifer: an EVERGREEN kind in `season_look.gd` would keep its summer look all year.

Every tree wears its model's ONE tree material (the canopy's shader with the season in it) or that shader's
in-leaf variant, with three per-tree instance numbers written when the calendar's hour turns; nothing is
duplicated per tree and nothing is made per frame. **The Demo Lab's Season preview** (F8) draws the village at
mid-spring, mid-summer, early autumn, late autumn or mid-winter and then back at the calendar's own season;
it moves no calendar, crop or weather, and it stays on after the Lab closes (step it round to the calendar's to
end it).

## Foraging trips (decision 0681; feature #22)

Brendan, 2026-10-01: "send a small party into the woods for nuts, mushrooms and herbs; they come back hours later with a
haul" (berries too, at the dishes lane's request). `forage/`:

- **The woods' forage basin is the settlement's real forage store** (`scripts/core/forage.gd`, run by
  `forage/forage_driver.gd` as the fishery runs `fishing.gd`): one basin, its five §5.5 patches at 80% with the compiled
  catalogue's ids, the **seasons** (nuts summer–winter, mushrooms spring–autumn, herbs all year, berries summer and
  autumn), the **daily quota**
  shared by every kind (spring 10.7 U, summer 21.1, autumn 22.2, winter 6.1), the **sustainable floor** (20% of each
  patch) and the **daily regrowth** at midnight. Natural danger 1 (§5.5: within 64 m of the hall, no lookout); the
  injury chance is shown, never rolled.
- **Woods panel ▸ Foraging**: what the woods hold of the chosen kind, its seasons and today's quota left, what a trip
  would bring home; **Gather ▸** nuts / mushrooms / herbs / berries, **Party ▸** 1–3, **Authorise trip**, **Cancel trip** (each
  order's tooltip its action card). A basket is 4 U a forager (a demo value), bounded by what the basin admits now.
- **A trip**: each forager is a seat on the work board (J; "Forage nuts — the hazel brake", the Woods activity, source
  12 since the batch 7 integration), the selected residents first. It walks to its spot -- the hazel brake (nuts), the beech hollow (mushrooms), the herb
  bank (herbs), the bramble edge (berries) -- is checked there (in season, its share still admitted, room in a store), claims its share from the
  basin, gathers it (§5.5's work per U at its FORAGE skill, which it learns), and carries the haul home in a basket to the
  store holding its room: **the Pantry's Stocks show Nuts, Mushrooms, Herbs and Berries** like the crops. "The foraging party is
  back from the hazel brake: 8.0 U of nuts in the stores" is said in the village news.
- **Nothing is lost**: called away, a seat goes back on the board with its claim, room and work kept; a haul in hand is
  delivered before the night or a meal; Cancel ends the seats not yet carrying and gives their claims and room back.
- **The items**: `nuts` (1600 NP, raw edible, 720 h), `mushrooms` (72 h), `herb` (480 h), `berries` (700 NP, raw edible,
  48 h) -- the catalogue's keys, items 26–29 of the pantry (after the dishes' potato and honey). Nuts and herb are the
  regatta feast's (below); nuts and mushrooms also cook the pasty, the scones and the woodland pie, and the berries
  the cordial once there is honey (decision 0902). The herb is the infirmary's too: see The herbalist and the infirmary.
- **The spots are drawn** where the food art is staged: three hazels round the hazel brake, ceps in the beech hollow,
  the herb bank's patch and two brambles at the bramble edge. **The bramble edge** is at the south-west woods' edge,
  west of the old orchard, (-25.0, 27.0) since the batch 8 integration (decision 0903): its lane's (8.0, 25.5) lay inside
  the orchard's east planting block.
- The party panel says what each forager is doing and its "Foraging N"; the Routes layer's public ways include **the
  forage grounds**; the field guide has the four goods and "Foraging trips".
- Checked by `test_demo_forage.gd` (the placeholder cast on the real layout; no staged assets).

## The orchard (decisions 0671-0677)

Feature #20 and the review's group Y (ECO-008, 009, 010, 015): perennial fruit that takes years to mature, with fruit
seasons (`orchard/`). Presentation only; every number not the GDD's is named in `orchard/orchard_rules.gd`.

- **The trees are real OrchardPlot rows** (`scripts/core/orchard_hive.gd`, GDD §5.6): apple 96 days to maturity and
  80 U a year in Autumn 1-6, pear 144 days and 110 U in Autumn 3-8; 20 WU of care a day in spring and summer (2 U of
  the butt's water in a drought); an untended spring or summer day costs 100 health, a tended one restores 50; fewer
  than 6 winter chill days give 75%; picked once a year (REQ-SET-079/080). Each midnight closes the day just ended.
- **The inherited old orchard** (decision 0672, the M3 timing change): an old apple and an old pear south of the field
  beds, neglected (35% health) -- tend them and their first autumn gives four times what neglect does. **Early yield**:
  a young tree a year old gives a fifth of a crop once a year in its window until it matures. The M3 grant (2 apple + 2
  pear saplings) waits in the nursery from the start.
- **The east orchard**: two empty 8 m blocks (brass pegs) by the south road, and the **berry hedge** -- raspberry
  canes, a blackberry bramble and a strawberry bed sharing one §5.5 Berries patch (decision 0676): fruit in summer and
  less in autumn, none in spring or winter, never picked below a fifth. Whichever bush is picked, the pantry gets the
  one generic **Berries** item (the foraging lane's `berries`, item 29); apples and pears are their own items (30 and
  31, after the forage, since the batch 8 integration).
- **Eaten raw** (decision 0671, proposal 9): a hungry resident with no portion may eat fruit (900 NP a unit) or berries
  (700) raw, as GDD §5.7 allows -- from a store, never from a basket stand.
- **Groups** (decision 0674): each orchard gathers its picking at its **basket stand** (a pantry store 120 U, never a
  destination for other harvests), and the Haulers carry the baskets on, 10 U a trip, to the **kitchen pantry** or the
  **best keeping store**, the food keeping its age. Timing: *as each ripens* or *all together* (the apple waits for the
  pear). A share (0, 4 or 8 U of each fruit) stays at the stand for the nursery.
- **The nursery** (decision 0673): a plan promises a sapling to an empty site; the routine propagates it once the
  baskets hold the fruit (4 U; the kitchen never reserves food waiting at a stand), compost (2) and water (2) -- 120 WU and 12 days -- and plants it. Every empty site and
  plan shows when its tree would first fruit (REQ-SET-081).
- **The North hollow** (decision 0675): a protected grove in the North stand (a sage ring, a mossy stone): the woods
  never fell its trees (no order, no auto-fell, no firewood), and once a season someone observes it -- a line in its
  record and the news.
- **The seasons** (decision 0677): the fruit trees and bushes are season trees -- blossom (pink-white apples, white
  pears) in spring, green fruit swelling in late summer, red apples and yellow pears in autumn until picked, bare
  boughs in winter. The trees are the food art's apple and pear where staged (see The art passes, wired), else the
  staged oak drawn small (0671's art gap).
- **The work** is on the work board as source 13 since the batch 8 integration (decision 0903), **Orchard** (`work/orchard_work.gd`): tend, harvest, pick berries, haul
  baskets, plant, propagate, observe -- each conserving its load (a delivery always finishes).

| Input | Does |
|---|---|
| Left click an orchard tree, a site's pegs, a bush, the baskets, the nursery or the grove's stone | Select it: the **Orchard (demo)** panel takes the right column (it has no tab; any tab takes the column back) -- the thing's readout and verbs (each with its action card), its group's policy, the nursery's plans, the grove's record |
| Right click one (residents selected) | The nearest does its most pressing work: a tree's harvest (else its tending), an empty site's planting, a bush's picking, the baskets' haul, the grove's observation |
| Orchard panel | Tend, Harvest, Pick berries, Send baskets on, Plant apple/pear, Plan an apple/pear, Drop the plan, Observe now -- with nobody selected, queued for the Field crew; Timing, To, Keep (the group's policy); Protected (the grove) |

## Hives, honey and wax (decision 1601)

Review group Y's ECO-011 and ECO-012 (`hives/`, inside the orchard's panel and board). Presentation only; every number
not the GDD's is named in `hives/hive_rules.gd`.

- **The hive is a real Hive row** of `scripts/core/orchard_hive.gd` (GDD §5.6), in the orchard's own store, so its
  pollination links reach the trees: strength starts 8000 (healthy from 5000); spring to autumn a hive tended that day
  makes honey 2 U and wax 0.25 U × strength/10000, for 20 WU of service a day; a missed day costs 200 and makes
  nothing; a tended spring day restores 300; winter makes nothing and eats 0.5 U of honey a day from the hive's feed,
  a day without it costing 500; at 0 the hive is abandoned.
- **The apiary** stands from the start north of the field, before the old orchard (one skep, tiles 57..59 × 73..75). Its keeper's work is
  on the work board under **Orchard**: **Tend the bees** (the day's service, then the collection), **Feed the bees**
  (winter, when the hive's feed falls short: the pantry's free honey), **Recolonise** (an abandoned hive in spring:
  honey 4 U and wood 2 U, 60 WU, a 3-day wait).
- **The winter feed first** (ECO-012): a collection tops the hive's feed up to a whole winter's 6 U before any honey
  leaves it; the rest goes to the **old orchard's baskets**, and the Haulers send it on with the fruit. Honey is food
  (the pantry's `honey`, 1440 h, raw-edible 1200 NP); the raspberry cordial no longer waits for it.
- **Wax** is a material: until the village stores keep it, it waits on the apiary's own shelf (40 U), shown in its
  readout.
- **Pollination** (REQ-SET-082, ECO-011): a healthy hive within 12 m gives beans and orchard fruit ×1.10 (×1.15 with
  two). The apiary reaches the old apple and pear and the four northern field beds (beds 3–6): beans sown there yield
  ×1.10 (`farm/farm_sim.gd` `pollinate`); the cabbage beds and the east orchard are out of reach. The readout lists
  what benefits.
- **Wildlife** (§5.8): at midnight in summer and autumn a 2% roll takes min(2 U, the honey in the hive) -- news, never
  an injury.
- **The bees** are the free `fx/bee_swarm.gd` effect over the food art's `bee_skep` (or its placeholder box): out spring
  to autumn, resting in winter and gone while the hive is abandoned; reduced motion slows and gathers them.

| Input | Does |
|---|---|
| Left click the skep | Select the apiary: the **Orchard (demo)** panel -- its strength and season, REQ-SET-083's service and feed deficits, its honey, wax and winter feed, the crops it pollinates, and its verbs |
| Right click it (residents selected) | The nearest does its most pressing work: the service, else a feeding, else a recolonisation |

## Preserving: dried fruit and rations (decision 1611)

Feature #18 and the review's ECO-028 (`preserve/`, through the fishery's station jobs). §5.7's preserving rows the demo
can make; every number not the GDD's is named in `preserve/preserve_rules.gd`.

- **Dry fruit** on the smoking rack, which is §5.9's Dryer (decision 0434): fruit 4 → **dried fruit** 3 (1400 NP a
  unit), 20 WU to hang, then 12 game hours in its slot with the worker free, then taken down. Fish and fruit share the
  rack's four slots.
- **Pack rations** at **the preserving table** west of the kitchen (art pass 3's shelf of jars and salt-glazed crock):
  flour 2 + dried fish 1 + nuts 1 + water 1 → **rations** 3 (2400 NP a unit), 24 WU, carried to the stores.
- Both are **pantry items** (dried fruit 720 h, rations 1440 h), aged by where they are kept (a cellar keeps them about
  three times as long as the covered store) and **eaten as they are** by a hungry resident when a meal is missed --
  the village's reserve; the kitchen still cooks fresh food first (ECO-028).
- The inputs that spoil first are set aside when a batch is ordered and taken only when its work starts; cancelled
  after that, half its food is spoiled (REQ-SET-094). Each button's card says what is short and where to get it.
- **Not built**: salt fish (salt is coastal brine only, and the village has no coast); jam, pickles and a plant-milk
  cheese have no GDD row and wait on Brendan's recipe approval (open question Q-D5).

| Input | Does |
|---|---|
| Water panel ▸ Preserves ▸ **Dry fruit** | 4 U of the fruit that spoils first onto the rack (selected residents first, else the board) |
| Water panel ▸ Preserves ▸ **Pack rations** | A batch of rations at the preserving table |

## Brewing: mead and the cordial (decision 1621)

Feature #19 and the review's ECO-031, a modest drink culture (`preserve/preserve_rules.gd`'s brewing rows, through the
fishery's station jobs). Nothing models what drink does: mead is "a feast ingredient only; no intoxication subsystem".

- **The brewery** stands east of the kitchen: art pass 3's mash vat (steam rises over its rim while a batch brews) and
  conditioning cask. Its **four vats** are §5.9's Brewery's passive slots.
- **Brew mead** (§5.7 `mead`): honey 3 + water 3 → **mead** 4, 20 WU, then 72 game hours in a vat with the brewer
  free, then drawn off to the stores (1440 h).
- **Make cordial**: the raspberry cordial of the recipe book (Brendan's DEC-045, decision 0603: berries 2 + honey 0.5
  + water 2 → 4, 10 WU, 72 h) at the brewery's bench, kept as a drink. Its honey is the apiary's (decision 1601).
- **At the feast**: the regatta's supper pours what the brewery has made -- mead and the cordial, a unit each for
  every four guests, for those who came -- beside the Hearth feast's warm infusion. A drink never decides Shared
  Warmth, and the preview says which will be poured.
- **Not built**: ale and cider (icons exist; no GDD row) wait on Brendan's ruling on how drink is depicted (DEC-007)
  and new drink recipes (open question Q-D5).

| Input | Does |
|---|---|
| Water panel ▸ Brewing ▸ **Brew mead** | A batch of mead into a free vat (selected residents first, else the board) |
| Water panel ▸ Brewing ▸ **Make cordial** | A batch of the raspberry cordial at the brewery's bench |

## New recipes: jam, nut cheese, ale and cider (decision 1625)

Brendan's "Approve and build Q-d5 and dec-007" (2026-10-07): four content-library dishes drafted as station rows in
`preserve/preserve_rules.gd`, **every number provisional** (decision 1625 names each one's source).

- **Make jam** at the preserving table: berries 2 + honey 1 + water 1 → **berry jam** 3 (850 NP a unit, eaten as it
  is), 16 WU, keeps 720 h -- the library's honey-sweetened fruit jams.
- **Make cheese** at the preserving table: nuts 2 + water 1 → **nut cheese** 2 (1600 NP a unit), 16 WU, then 24 h
  setting in one of the table's **two crocks**, keeps 480 h -- the library's one salt-free plant cheese.
- **Brew ale** at the brewery: barley 3 (barley only) + water 3 → **ale** 4, 20 WU + 72 h in a vat, keeps 1440 h.
- **Make cider** at the brewery: apples 4 (apples only) + water 1 → **cider** 4, 16 WU + 72 h in a vat, keeps 1440 h.
- **How drink is depicted** (Brendan's ruling on DEC-007's open point): ale and cider follow the mead rule -- a feast
  or table drink only, never eaten, no intoxication, no effect on Shared Warmth. The regatta's supper pours them with
  the mead and the cordial, a unit for every four guests.
- **Pickles are not built**: every pickle in the content library takes salt, and the village has no coast (decision
  1625 asks Brendan how to proceed).

| Input | Does |
|---|---|
| Water panel ▸ Preserves ▸ **Make jam** / **Make cheese** | A batch at the preserving table (the cheese then sets in a crock) |
| Water panel ▸ Brewing ▸ **Brew ale** / **Make cider** | A batch into a free vat |

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
and returns each cycle's catch as species lots; the fishery (water part B, below) opens, completes or cancels
those cycles and lands the lots in the pantry. The depths and the
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
  water (below 10.0 °C) doubles the drain; a flood doubles the flow. **Health** (HAZ-001, decision 1045): nobody
  goes into the water -- a swim, a dive, a route's swim link, a rescue -- under health 70 or with an untreated
  injury (the infirmary's `fit_for_water`, set on the swim state as its `fitness`); refused as "isn't well enough".
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
  short of air goes down itself once it has breathed). A patient -- under health 70 or with an untreated injury -- is
  sent to no rescue at all, not even to throw a line (decision 1045). One rescuer answers a victim at a time; one the
  player calls away frees it at once and is not sent back to it, and one whose swim shortcuts are turned
  off on its way lets the victim go at the water rather than going in. Nobody drowns: with nobody coming
  after 90 s (or a rescuer on the way but not there after 240 s, who then stands down) it washes ashore
  at a landing. It then rests 20 s, recovering three times as fast. The Demo Lab's Cramp (F8) starts
  one on demand.
- **The Water panel** (decision 0391, review F12) pins at its top, never scrolled away, every resident in
  difficulty (the rescue incident's own line) and the selected residents' swimming (two, then "n more selected"
  opening the list). Below, scrolling: **Swimmers** -- how many are in the water, the water today, Dive and Swim
  shortcuts, and **All residents**, folded until opened, a row per resident that selects it and centres the
  camera on it -- then **Bridges** -- the site, each kind's cost with the Build buttons right under them (each shown
  only when it can be built now, the missing material and its source button below them: decision 0461),
  ◀ Site / Site ▶ / Span two banks…, the bridges, the stores and the news. At 1280x720 Dive, Swim shortcuts and
  both Builds are in view without scrolling; every button is at least 32 px tall, every line at least 14 px. The
  pinned alert shows up to four lines (all of it in its tooltip), and where the pinned selection would squeeze the
  sections below two button rows -- a rescue at 125 % -- it folds into All residents.
- **Bridges.** The Water panel steps through the map's three bridge candidates or spans any two banks
  you click. A plank footbridge costs 1.0 U of planks a metre of deck (and 1.0 U of wood a pier, one per
  started 2.5 m of span over 3.5 m); a log bridge costs one 6.0 U log -- a felled trunk lying ready, else
  the log stack -- and spans at most 5.5 m of deck. Paid all or nothing from the one stores; refusals say
  why. The builder fetches and carries the material, then works piers, beams and deck (WU at the woods'
  rate, §5.3's skill factor); the beaver bridgewright starts at level 6 and gnaws its log. Anyone who
  selects nothing leaves it for the bridgewright. Finished bridges are walked by everyone, loaded or not,
  the badger included. A builder loads and builds only standing at its spot: one who could not get to the
  material or the site leaves the bridge waiting and goes back to its own work, the feed names who could not get
  where, and the bridgewright leaves that bridge alone for 10 s before trying again (decision 0361).
- **Who goes in to rescue** is the nearest by route to where it goes in, not in a straight line (decision
  0205): a swimmer across the stream with a long way round loses to one a little farther on the near bank.
- **Water tab** (right column): conditions, alerts, who is swimming, the chosen site and its costs,
  bridges, stores and the water's news. The alert line is one incident per victim, updated in place:
  where it is and its breath, who is answering and at what, the landing once it is settled, and why
  nothing better went -- or, with nobody, when the water will bring it ashore.
  The **Water range** layer (V or the Map layer picker) paints the zones
  for its subject -- one resident's own height, or a group's, member by member (see Map layers) -- the bridge candidates, the swim links and the landings; the fishery's site labels are two
  lines each (quota and slots; each species' stock and state), laid out so they never overlap.

## Fishing, boats, ice, the rack and the mill (water part B; decisions 0431-0436)

Fishing trips feed the pantry through the real fishery (`fishery/`, `boats/`): the catch is debited from
`scripts/core/fishing.gd`'s stock and quota and lands in the stores as its species.

- **Authorise a trip** (Water panel ▸ Fishing): **Site ▸** the run, the ford or the pond; **Method ▸** a hand net or a
  trap from the bank, a boat on the pond, ice fishing on the frozen pond; **Fish ▸** that water's fish (trout, dace,
  salmon in the stream; perch, carp, whitefish in the pond -- never eel or pike; no coast here, so no herring, mackerel
  or mussel). Before it is authorised the panel and the card show the stock and today's quota, any closure and when it
  reopens, the expected catch, the gear's condition and the numerical risk (REQ-SET-055). **Authorise trip** puts its
  seats on the work board (J), to the selected residents first.
- **The methods** are the GDD's gear rows, each in its own role: a **hand net** (60 WU, one fisher, any fish), a **trap**
  (set 20 WU, left 6 game hours, collected 20 WU; dace, perch, carp), a **boat** (two crew, 120 party-WU, the biggest
  catch; the helm needs fishing 1, the second may be a learner) and **ice fishing** (an ice kit and a winter outfit, 90
  WU, safe ice only). There is no line: the GDD has none.
- **A trip**: the fisher fetches its gear from the locker by the fisher shelter, walks to the water, and the trip is
  checked again there (a storm, a hard freeze, ice, a closure, the quota, worn gear: refused, nothing is taken and the
  trip waits on the board saying why); the fishing cycle opens (its effort slots, the gear's durability claim, room held
  in a store for the catch), the work is done, the store's catch is taken, and the catch is carried to the store. **Cancel
  trip** releases everything at once; a catch out of the water is always landed. One called away sets its catch down
  where it stands, for the next to fetch. A trip two game hours past its estimate is an OVERDUE warning.
- **Boats** (Water panel ▸ Boats): two rowboats kept at the boathouse (and a third, the ferry boat: see The ferry), moored at the **jetty** on the pond's west bank
  (outside the boathouse). The crew wait at the jetty, board, row a **fixed route** to a fishing station and back, and
  step off; out on the water they are held (nothing calls them off mid-pond). A boat wears 15 a trip and none sets out
  below its wear (Mend gear). **Boat rescue**: a resident in difficulty at the pond's surface may be answered by a boat
  -- when its crew's way is shorter than a swimmer's, or no swimmer is free -- rowed out, hauled aboard, landed at the
  jetty.
- **Gear** (Water panel ▸ Fishing): real gear in the locker (hand nets, traps, ice kits, winter outfits), each piece's
  durability and cycles left shown; a worn piece is refused before a trip, never broken during one. **Make net / trap /
  ice kit** at the workbench (the stores' wood, the locker's rope or iron: the village came with 4 U of rope and 2 U of
  iron); **Mend gear** mends the most worn free piece or boat (wood 1 + rope 0.25 for 200 points).
- **Winter ice**: the pond freezes in the cold (frozen at 10 mm, safe at 60 mm; a millimetre a game hour at −5 °C). Ice
  stops boats, nets, traps and swimmers on the pond (a boat, net or trap out when it freezes is called in); THIN ICE is
  a warning while it lasts; SAFE ICE takes ice fishers out to the hole. The Water range layer paints safe ice white and thin ice slate.
- **The smoking rack** (Water panel ▸ Drying rack and mill ▸ **Dry fish**): the GDD's dryer running its `dry_fish` row --
  4 U of the fresh fish that spoils first, hung (24 WU), cured 12 game hours in one of four slots (smoke rises), taken
  down: 3 U of dried fish that keep 720 h.
- **The mill** (**Mill grain**): 3 U of grain carried over the stream to the watermill, ground (12 WU, the wheel
  churning), 3 U of flour back to the store whose room was held for it. The hardtack, the biscuit soup, the pasty, the
  pies and the scones bake with it (decisions 0603, 0902), and the regatta feast's nut loaf with foraged nuts (decision
  0682).
- **The Pantry's Stocks** lists each fish species, dried fish and flour like the crops, and so does its Recipes tab
  (decision 0602). The sound: a splash where a net
  or trap goes in, a boat pushes off or a hole is cut, and the oars' knock as a boat rows.

## The ferry and the regatta (water part B lane 3; decisions 0437-0439)

Brendan approved ferries and the regatta feast with the rest of water part B (decision 0493, group K), though the review
rated the ferry "Stretch" and moving vessels lie outside the adopted movement scope (MOVE-G01–05 stay open): decision
0439 records that authority. `ferry/`, `regatta/`.

**The ferry** (`ferry/ferry.gd`; numbers in `ferry_rules.gd`; decision 0437) -- one fixed two-landing cargo ferry:

- **Two landings**, the boathouse jetty's pattern, outside every building: **the ferry stage** on the run's west bank
  below the fisher shelter, and **the far stage** on the stream's far bank at its mouth. A **third boat**, the ferry
  boat, lies off the ferry stage and rows **one fixed route** (10.1 m) down the run into the pond's north-east lobe and
  back. No free sailing; fishing never takes it; the regatta races the boathouse's two.
- **Its reason, the far copse**: windfall at the east woods' edge across the run (the woods' deadfall numbers: 1.0–2.0 U a
  pile, 20 WU a U; two lie at the start, one falls each midnight). By land it is over the ford; carried to the log stack
  it is about 3.2 game hours that way and 2.3 by ferry -- the Ferry section's benefit line, from the cast's own planner.
- **Water panel ▸ Ferry**: its state and timetable, the stacks, the copse, the benefit; **Gather the far copse** (each pile
  on the work board, to the selected first), **Send the ferry** (a crossing now), **Cancel crossing** (only before its crew
  is aboard) -- each with its action card.
- **A staffed timetable**: departures 06:00–18:00 every 2 game hours when anything waits to be carried, or at once when
  **4.0 U** waits at the far stage; the crew is a **helm, fishing 1** (the boatwright or the fisher; anyone who learns).
  The crew walks to the stage, boards, **loads** the far stage's stack (1 WU a unit, up to **12 U**), rows, **unloads** at
  the ferry stage, steps ashore and **gives the boat back** -- free between crossings, so a boat rescue may take it (a
  rescue in it walks to the ferry stage). A hauler carries the landed wood to the log stack: **the stores' wood rises**.
- **Closure**: a storm, a hard freeze, the stream in flood or ice on the pond. Nothing departs; a crossing under way
  **finishes its leg and holds** -- at the far stage its crew steps ashore and the boat waits there until the ferry opens, when a crew walks round to
  bring it home (none can reach it: the job stays on the board, never ended with the boat out; Cancel is refused).
  Wood stranded at the far stage or aboard while closed is the incident **"The ferry is closed: …"** (Village news ▸
  Needs attention). The Routes layer and the Water panel say it.
- **Passengers**: the router offers the ferry to any trip across the water while it is open, staffed and boardable
  within 2 game hours, costed as its decks, its row and **the wait for its next boarding** -- so it is chosen only when it
  is quicker. A passenger waits at the stage ("waiting for the ferry" on the Routes layer), boards the second seat, rides
  (held: no order takes it off; its panel says "aboard a boat") and steps off at the other stage. Any refusal while it waits -- closed, too long a wait,
  the seat taken, another order -- ends the leg where it stands, and it goes by land.
- **The books**: every unit that fell in the copse is lying there, in a hand (or set down for the next), on a stack,
  aboard, or in the stores -- at every frame, through cancel, closure and interruption.

**The regatta** (`regatta/regatta.gd`; numbers in `regatta_rules.gd`; decision 0438) -- a once-a-season occasion, the
first in summer:

- **Water panel ▸ Regatta** (or the HUD's **Feast** command, unlocked for it): **◀ Day / Day ▶** (the season's days from
  tomorrow; before summer, summer's), **Host ▸** (anyone but the village cook), and the **preview** -- the GDD's Hearth
  feast for every resident: bean hotpot ×ceil(E/3) (beans and cabbage, free in the pantry), the second course -- **nut
  loaf** ×ceil(E/3) (flour from the mill, nuts from a foraging trip) -- and the **warm infusion** (water and herb), each
  read from the pantry's real stock and, when short, named with its shortfall and fix (decision 0682, Brendan's ruling
  "add nuts & herbs now"); the **Shared Warmth** line (cold exposure −25%, mood +400 for 48 h if 80% eat every course);
  seats, staffing,
  the 1 U of service wood, the reserves after it, and the race's crews and paces. **Hold the regatta** refuses what is
  invalid with its fix; under 3 days of ready food or wood it needs **Override reserves** (REQ-SET-101). Held, the feast's
  beans and cabbage are reserved at once and its wood set aside. **Skip this season** costs nothing and gives everything
  back. Once a season: held or skipped, the season is done.
- **The day**: crews called at 13:00 to the boathouse jetty; at 15:00 both rowboats race out to a floating barrel and
  home, each at its crew's fishing-skill pace (deterministic; equal paces a dead heat); the otters sing their work songs
  as they row. A storm or a crew not aboard by 16:00 calls the race off; the feast goes on.
- **The feast** is the day's supper: the kitchen cooks the occasion's bean hotpot and then its nut loaves from the reserved
  food and serves them at the hall's tables at 17:00 -- each guest eats one portion of each course -- with the warm
  infusion poured from the reserved herb and water drawn from the butt then (used for those who came); the supper song is
  sung there; the service wood burns. At its end, **Shared Warmth** for 48 h when 80% ate every course (never stacked or
  extended; shown in the chronicle and the Regatta section). The demo models no mood or cold exposure, so the buff is a
  readout (`regatta_menu.gd`) nothing consumes yet.
- **Remembered**: once the supper is finalized -- its last bowl eaten or given back, which can be after 19:00 (decision
  0997) -- the tally, the buff and the chronicle (Village news, Village): the day, the host, the race, who shared the
  feast and **one moment** (the finish); the winners' deed in their own histories, pinned to the chronicle; +5 affinity
  for every pair who shared the feast (REQ-SET-036).
- Checked by `test_demo_ferry.gd` and `test_demo_regatta.gd` (the placeholder cast on the real layout and water, the real
  kitchen at the hall's tables: no staged assets).

## Spoil heaps

A finished tunnel's spoil heaps can be cleared (`spoil/`, decision 0205). Left click a heap to select
it; right click it (or press C) with residents selected, and those who can carry dig it out a basketful
(2 U, the farm's own load off a heap) at a time and haul it to the village stores, tipped by the
open stockpile. At most four work one heap; the emptied heap stops being an obstacle.
A heap still growing under a dig is refused. The party panel says who is "Clearing a spoil heap" or
"Hauling earth to the stores". A worker digs or tips only standing at its own spot: one whose walk failed
waits a few seconds -- "... — can't reach it, trying again" -- and tries again, at most three times, keeping
any basket in hand. A basket reaches the stores only by being tipped at the drop spot: a worker called away, or
one that gives up, puts its basket back on the heap -- nothing is delivered from afar, nothing is lost
(decision 0361).

**Spoil is earth, not compost** (decision 0401, Brendan's ruling of 2026-09-30, the adopted
`excavated_earth` rule: dug earth is never fertiliser). What a tunnel digs out is earth. It is heaped at the mouth,
carried, and then either built into a bed by **Raise** or **Bank** or kept -- on its heap, or in the stores, where
the Tunnels and Water panels' stores line shows it ("earth 4.0 U"; it is not a top-bar figure). Raise and Bank fetch
it from whichever holds 2 U nearest the resident: a spoil heap, or the stores. Every milli-U goes through the farm's
earth books (`farm/farm_tunnels.gd` EARTH): dug = on the heaps + in baskets + in hand + in the stores + built in, at
every moment. A raise or bank cancelled (or refused at its bed, or unable to reach it) with earth in hand becomes
"Carry earth back": the carrier walks it back to its heap or the stores and tips it there; one that cannot get back
either puts it back from where it stands. **Compost comes only from plant waste** -- a cleared crop's 0.5 U and the
Pantry's spoiled food at 4 : 2 -- and Compost spends only the compost store; earth never raises fertility. There is no
backfill yet: the tunnels have no way to fill a dug passage, so that use waits for one (decision 0401).

## The weir sluice and the garden leat (decision 0441)

The weir's sluice gate is a player control (review ECO-006: bounded, discrete water service; no hydrology). **Click
the weir** (or a bed's **Sluice…**) and the farm panel shows it: **Close**, **Half** and **Open**, each button's
tooltip its action card, and the **affected-bed preview** -- for the setting under the pointer, else the setting now --
in words ("Open: Bed 2 and Bed 4 go to wet, Bed 6 to normal. Bed 4 is already waterlogged.") and bed by bed (its
band now, its service then, what the leat adds at the next midnight). The order is done at once (no one walks to the
wheel: a demo simplification); the beds' water changes at midnight.

- **The zone** is Bed 2, Bed 4 and Bed 6 -- the east column -- fed by a covered culvert from the weir to a timber
  leat head at Bed 2's north-east corner (`water/weir_sluice.gd`). Its table: Closed, all three **dry**; Half, Bed 2
  and 4 **normal**, Bed 6 dry; Open, Bed 2 and 4 **wet**, Bed 6 normal. Other beds are not served. The demo opens
  closed, so its tuned spring is unchanged.
- **Through the moisture model** (`farm/farm_sim.gd` THE GARDEN LEAT): normal moves a bed up to 1500 a day toward its
  band's middle (as a tunnel irrigates), wet raises it up to 1500 toward 1000 over its band's top and never lowers it,
  dry adds nothing. The leat's share is worked on the bed as the day left it, so the preview's "+15% from the
  leat" is exactly the leat's own share; the night's weather and the loam's drainage above the band's top come on
  top of it.
- **Tunnels**: a bed the leat waters takes the leat's water instead of a tunnel's and is not drained that day; a bed
  it leaves dry keeps whatever its tunnels, ditch and raising do. A travel tunnel never changes because of the sluice.
- **Floods**: while the tunnels' flood runs with the sluice not closed, an incident says which beds it will
  waterlog or wet and to close the sluice (the preview says it too). Closed in time, it resolves; left open, as the
  flood passes the wet beds are raised past their WET band (waterlogged; capped at the scale's top) and the normal
  ones into it, and the feed says so.
- **Drawn**: a three-plank board in the weir's gate bay (the model's baked board is taken out) winds up on the demo
  clock -- half its lift at Half -- with broken white water below the bay while it is up; the leat head's water stands
  empty, half full or brim full. The stream keeps its one level (decision 0301), so the pool does not drop. The head
  is a 0.55 m walking obstacle (`weir_gate_view.gd land_obstacles`, a circle as (x, radius, z): decision 1043).
- **The Water service map layer** colours each bed by its service.

## Day and night (decision 0541)

The world's light follows the demo calendar (`world/day_night.gd`). Everything tunable is in one data file,
`world/daylight_curves.gd`. It holds named curves (the light's energy and colour, its shadow, the ambient, the sky, the
haze, saturation, exposure, the lamps), each given at four keys: NIGHT, DAWN, DAY and DUSK. `world/daylight.gd` samples
the curves, allocating nothing.

- **The hours are the GDD's §5.10 daylight.** Spring is 06:00-19:00: dawn 05:00-07:00 (sunrise in its middle), dusk
  19:00-21:00, night from 21:00. Summer (05:00-21:00), autumn (07:00-18:00) and winter (08:00-16:00) shift the windows.
  Every window lies inside its day, so the change of season at midnight shows nothing. Neither the GDD nor the calendar
  gives the sun's height, so its peak stays the same all year.
- **One light, the sun by day and the moon by night.** By day it is the sun on its arc: east at sunrise, due south in the
  middle of the daylight, west at sunset, and never lower than 12°. By night it is a soft blue moon from the south-west.
  The DAY key is the world's own reviewed look (decision 0301's values exactly; a test holds it to `world_look.gd`).
  The shadow fades out over the dusk's first half and in over the dawn's second. From the middle of the dusk to the
  middle of the dawn, while the light swings between the moon's and the sun's, the shadow pass is off.
- **Night stays playable.** The ambient turns a moonlit blue of its own, the selection rings and marks are unshaded, and
  the paths still read lighter than the grass. **Brighter nights** (Settings, Accessibility; also part of *Large
  readable*) raises the night's ambient, moonlight and exposure, in proportion to how much night there is. Noon is
  unchanged.
- **The weather sits on top.** Rain, a storm (rain on a heavy-rain day), snow and an overcast dry hour of a wet day
  each have a gloom (`weather/weather_view.gd gloom`). Gloom darkens the ambient and sky, greys the colours and softens
  the shadow, whatever the hour. The rain's share still dims the light, and its haze adds to the hour's. The rain,
  the snowflakes and the chimney smoke are unshaded, so they take the hour's tint and darken with the evening. The
  smoke is tinted per chimney. Frost
  and snow cover stay lit by the moon, pale blue at night.
- **Night lights** (`world/night_lights.gd`): a pool of at most 8 shadowless omni lights on the surface layer, given to
  the spots nearest the camera's focus. The spots are the five homes' doors (the hall, three residences, the kitchen)
  and every standing tunnel mouth's lantern. Homes read lit by lamplight spilling from their fronts, and where a home's
  `<key>_windows` model is staged (art pass 2, decision 0951; wired by decision 0903) its window mask glows: emission 0
  by day, up to 1.5 x the lamps' level at night, on the same flag as its door lamp (the hall's goes dark with
  `hearth_cold`); the residences' shutters carry almost no glass, so their door lamps remain. Which homes are lit is one query
  (`set_home_lit`); without one, every home is lit at night. While the lamps are lit, the surface
  environment's glow is on, so the lanterns' emissive glass blooms. The lamps flicker gently in real time while the
  village runs, stand still while paused, and hold steady with reduced motion. The underground keeps its own pool of 32 (decision 0207).
- **The underground is not touched.** The U view wears its own environment (decision 0206), which the cycle never
  writes. The light and the night lights reach only the surface layers.
- **How often.** The light is written:
  - when the calendar has moved about a game minute (13 ticks);
  - when the weather's eased look moves, at most every quarter second;
  - when Brighter nights changes;
  - when the season changes.

  While paused, nothing is written.
- **The prewarm** holds the boot's frames at noon (the shadow on), then draws two at midnight (the moon, no shadow
  pass, the glow, the pool lit), then gives sunrise back. Neither the first shadowed morning nor the first dusk
  compiles anything.
- **The HUD's date trigger** wears a sun by day and a moon by night, drawn like the HUD's own line icons. The 3D
  lighting never touches the UI skin.
- Nothing here changes gameplay timing. The night routine (dusk 20:00, dawn 06:00), the hearths (19:00-07:00), the
  songs' evening (19:00-22:00) and the kitchen keep their own hours.

## Songs (decision 0442)

The otters sing, and teach their songs (`songs/`; review SOC-026, UX-030, UX-032). **Four short original songs**
(`songs/songs.json`, quoted in decision 0442): two work songs, a supper song and an evening song, written for this
demo -- no name, line or phrase from any book -- a line at a time in a parchment bubble over the singer.

- **Only in their context** (`songs/demo_songs.gd`): a work song only while actually working (carrying, at an
  order's work, at a kitchen step, or holding a work-board task that is working or hauling -- not walking to it), the
  supper song only seated at the supper table, the evening song from 19:00 to 22:00 while wandering free or walking
  home to bed. A song stops the moment its singer leaves its context; nothing waits for a song.
- **Who** (`songs/song_circle.gd`): the otters know every song; anyone who hears one sung to its end twice within
  6 m learns it, and sings it from then on (a routine Village news line). At most two lead at once; supper is one
  table -- one leads, everyone seated who knows it joins (a "♪ ♪"), and the day's first supper song is a news line.
- **Verse slots** name only what the village has recorded: a bridge it opened ("A cup for the weir bridge!"), a
  rescue; with none, the song's own words.
- **Settings** (the game menu's Sound): **Residents sing: on/off** -- off, nobody sings, hums or makes song news --
  and a sixth bus, **Songs (humming)**, with its own volume and Mute.
- **The hum** (`songs/song_hum.gd`): no new files -- each song's tune is synthesised once (the boot prewarm) into a
  soft closed-mouth hum, played at the singer on the Songs bus as each line begins. It is diegetic and never a score.

## Sound (decision 0351)

The first sound pass (`sound/`; review F43, UX-029, UX-031). **The files are staged, not committed**:
`python3 tools/stage_demo_audio.py` (also run by `tools/stage_demo_assets.py`) copies or renders 56 files for the
21 cues from nine CC0 packs in the gitignored audio library, then `godot --headless --path godot --import` imports
them. Where each file came from, its licence and hash: `docs/art-reference/audio_library/`. Without them (CI)
every cue is still wired, takes its voice and keeps its limits, and plays nothing (each missing cue warns once at
boot). First volumes were set by measured loudness, not by ear: they wait on Brendan's listen.

- **One owner, not an autoload** (`sound/sound_director.gd`, a child of the village). Everything it hears is the
  demo's -- cast, woods, tunnels, water, notices, camera -- so it is made and freed with the scene, and the sixth
  autoload slot stays free for the game's own AudioManager.
- **Six buses**: Master, Ambience (wind, rain), Work (tools, loads, footsteps; through "Work Surface" and "Work
  Under"), Water (the stream, splashes, wading), Cues (warnings, completions, clicks) and Songs (the residents'
  humming, decision 0442). Made by name once.
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
  room or bridge opening (complete), a *new* announced warning in the notice feed (a folded or grouped repeat,
  a held-back or a snoozed one does not chime) or a critical incident raised or come back (decision 0331's
  `incident_cue`; one chime a frame at most) -- an URGENT one chimes twice, 1.6 s apart, and info is silent
  (decision 0591),
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
  worn-path grid) took about 16 ms with nothing staged and 22 ms loading all 56 files.

## Soak test: twenty game days, leaks and slowdown (decision 0921)

`python3 tools/soak_test.py --out-dir <dir> --days 20` runs the real village headless at 4x for twenty game days
(`godot/tools/soak/soak_test.gd`, on the scale test's per-system driver, decision 0561). It runs about 6-12 minutes on
the Mac at nine residents. It writes `<dir>/soak.json`, a markdown report and a verdict JSON (`tools/soak_report.py`,
thresholds and their reasons in `tools/soak_thresholds.json`).

- **What it samples.** Every game hour: static memory, objects, nodes, resources, orphan nodes, video memory, errors
  and warnings, and the village's capped books. Every game day: frame-time percentiles and each system's time.
- **What it does, as a player would.** It tops up the pantry at 04:00, sends a work party to the square at 10:00, and
  can press Restart demo every `--restart-every-hours`.
- **The restart leak watch.** It names anything of the old village still alive once the new one is open, and whether
  anything alive still reaches it.
- **The first runs** are in `docs/performance/2026-10-01-soak-test.md`. They found the kitchen's Restart cycle (fixed:
  decision 0922) and the farm alerts' said-once keys growing a few a day (fixed: decision 0923).
- **The suite** runs five game hours with a Restart. One whole game day runs with `REDWALL_SLOW_TESTS=1`
  (`test/test_soak_harness.gd`).

## The hall and the village tapestry (decision 0771)

`hall/`. Brendan's ruling of 2026-10-01: **the adopted version**. The GDD gives the hall exactly two stages, so it
grows by two and no more:

| Stage | What it is | Its rule |
|---|---|---|
| 1 · Community hall | the hall the village starts with | GDD §5.9's refuge/community hall |
| 2 · Great hall | its one tier-2 upgrade: stone 40 · wood 20 · cloth 8 · 1200 WU; a hearth here burns fuel ×0.75, the common room's comfort target +1000; no new floor or beds | REQ-SET-136; BAL-SAFE-013 refuses a second ("tier 3 is absent") |
| Banners (dressing, not a stage) | up to four of §5.9's Decoration row: wood 1 · 12 WU each (the demo has no wax: decision 0210's substitution), +250 comfort each, at most +1000 | §5.9 |

- **Building.** Each is a project of materials and work through the **work board** (`work/hall_work.gd`, the board's
  "The hall" source): builders -- up to four on the upgrade (§5.9), one a banner; anybeast on land; the Builders crew
  first -- walk to the stockpile, lift one material a load (their §5.2 carry capacity at §5.7's masses: a mouse 2.4 U
  of stone, 48 U of cloth), carry it to the site pile by the hall's east end and set it down; once everything is
  delivered they build before the hall (REQ-SET-124/125). Nothing leaves the stores until it is lifted; a carrier called
  away puts its load back whole and keeps the project to come back to. **Cancel** (the hall's panel) gives back
  REQ-SET-126's share: all of it before work begins, 80% rounded down after.
- **Unlock (Brendan's ruling).** The GDD names none for the upgrade, and the adopted milestones need 12 residents; so one data
  constant, `hall_rules.gd UNLOCK_CONDITION`, opens it once **the first harvest is gathered into store**.
- **The cloth.** The village's **one** cloth, the GDD's opening 24 U (§5.1), is kept in the village stores
  (`tunnel/tunnel_stores.gd` CLOTH; decision 0993, Brendan's ruling on the review's R01). The hall's upgrade, the
  infirmary building and the treatments all **reserve** there before they take, so cloth one has reserved is never free
  to another: build the infirmary (12 U) and upgrade the hall (8 U) and 4 U is left for dressings.
- **What it gives** (the panel's first section): 12 seats for meals, songs and feasts -- a feast seats up to 36 (seats
  >= ceil(E / 3), §5.7); floor sleep for anyone without a bed (REQ-SET-133); the comfort target; a hearth's fuel.
- **Seen.** Clicking the hall opens its panel (no key). While the upgrade is carried in, a stone heap, a timber stack
  and the cloth grow by the hall's east end; while it is built, a work rail of fence lengths stands before it; the great
  hall is the staged stone hall (`hall_stage2`, art pass 2) in the timber hall's place, at its own transform, with two
  woven roundels in its outer bays (Brendan, decision 0903) -- without it, the same roundels and a second chimney pot; each banner is the linen `hall_banner` (its cloth
  dyed in the woodland palette, its wood not), or a cloth stand-in. `hall_view.gd` never moves or scales the hall.
- **The village tapestry** (`tapestry.gd`, `tapestry_panel.gd`; The tapestry, in the hall's panel): the village's
  history as a woven timeline -- oldest first, each entry a knot in its kind's colour on one thread -- with stage 1 at
  the start, the first harvest, the first winter, stage 2 and each banner, each woven once. An **original** community
  tapestry (setting bible LORE-R07): never Martin's.
- **The API for other features** (`demo_village.gd`):
  - `tapestry()` -> `tapestry.gd`: `add_entry(kind, title, text = "", once_key = &"") -> int` (its index, or a
    `REFUSED_*` code: no title, unknown kind, full at 128, or the once-only key woven already), `add_entry_at(tick, ...)`,
    and the readers (`count`, `title_of`, `text_of`, `date_of`, `kind_of`, `has_key`, `revision`). Kinds for the
    chronicle (#10) and milestones (#57): `KIND_CHRONICLE`, `KIND_MILESTONE`.
  - `hall()` -> `demo_hall.gd`: `gathering_seats()` (12), `seats_needed(E)`, `can_gather(E)`, `gathering_capacity()`
    (36) for the feasts (#9); `tier()`, `comfort_target()`, `fuel_permille()` (750 at tier 2, for a hearth lit here).

## The herbalist and the infirmary (decisions 0621-0623)

Injuries and their care, by the GDD's own rules (`infirmary/`), and the GDD's Infirmary building the hurt go to. The demo
is **non-fatal**: health never falls below 16, so nobody is incapacitated or dies (a demo floor, decision 0622 P1,
ruled). No illness is modelled: the family illnesses (CHILL) are a draft.

- **Health and the Injury row are the real stores'** (`care_state.gd`): a private `scripts/core/needs.gd` and
  `injury.gd`, one row a resident, run on the one calendar. Hunger (the kitchen's) and rest (the water's stamina) are
  mirrored in, so REQ-SET-017's recovery (+2 health an hour when fed and rested, +4 in the infirmary) and REQ-SET-014's
  starvation (−4) read the demo's own figures. An untreated injury costs −1 an hour (minor) or −4 (serious,
  REQ-SET-172); one aggregate injury a resident, the worse severity replacing (GDD §4.2).
- **What hurts** (decision 0621 lists the GDD's sources): a swimmer exhausted in the water (HAZ-003) and one left below
  with no air (HAZ-002); a bramble cut while gathering herbs (REQ-SET-068). Storms, wildlife, tunnels and digging hurt
  nobody, by the GDD. The Demo Lab's **Injury** and **Serious injury** give the selected residents §5.4's net hazard (a
  bite, −20) or its boat hazard (exposure, −35).
- **The infirmary building** (decision 0623; Brendan: "The infirmary should be its own place and that's where residents
  go to rest and heal"): GDD §5.9's Infirmary -- wood 40, stone 30, cloth 12, 1000 WU, 8 patient beds, Healer 2 --
  available from the start. The Tunnels panel's **Infirmary** section (under the housing line) says how it stands, the
  herbs and cloth, the herb patch and the patients, with **Build the infirmary…**: a ghost follows the pointer, brass
  where it may stand, clay with the reason where not; a click places it (nothing taken), Esc or a right click puts the
  tool away. Residents then build it through the work board ("Infirmary" source, REQ-SET-124/125/126 as the cellar
  building does): wood and stone fetched from the stores at the open stockpile, cloth -- the village stores' one cloth,
  shared with the hall and the treatments (decision 0993) -- fetched at the care shelf by the hall's steps, the books
  always adding up; **Cancel the infirmary** returns all before the work begins, 80% after. It is drawn
  with the food art's infirmary ward (decision 0941; wired by decision 0903; else the library's residence) at the
  infirmary's 5.5 m envelope, with herb strings and a shelf of remedies before its door, flat while fetched for, rising as
  it is built. Its herb patch is the food art's herb patch where staged, else procedural clumps.
- **A hurt resident rests** (`care_tasks.gd` BedRest): in the infirmary when it is built and has a bed -- in at its
  door, admitted to a bed, treated there, mending at +4 an hour, at most 2 healers inside at once; before it is built,
  or when it is full, in its own bed, else lying at its **field-care spot** before the hall's steps (decision 0623 P2).
  It stays until treated and back at 70 health (P4, ruled) -- but it gets up to eat, a minor injury the shelf cannot pay
  for is borne at work, and a treated one that cannot recover (hungry or tired) gets up too. The news says who is hurt
  and why; an incident stays open until it is up again.
- **The healer** (`care_desk.gd`): the best free resident who can reach the patient -- the highest Healing level first
  (the squirrel gatherer, Linnet Whinberry, starts at level 2), then the nearest. Treatment pays herb 1 U and cloth 0.5 U
  once, at work start, and takes 60 WU of HEAL (an hour at level 0); its work stays with the patient if the healer is
  called away. A healer goes only while the shelf covers every healer already sent; its treatment's 0.5 U of cloth is
  **reserved** in the village stores as it is sent and given back if it stops before work (decision 0993).
- **The resident card** (the party panel): "Hurt: a bite (minor) · health 80", its untreated hours and rate, who treats
  it and how far or what it waits for; then "Recovering · health 67 · +4 an hour in the infirmary · up at 70 in about 1
  h"; "Work at 85% (health 85%)" while health is under 70; the healer's "Healing · Level 2"; a builder's "Carrying wood
  to the infirmary".
- **Herbs** (§5.5's herb row): the shelf starts with the GDD's 12 U of herb (the 24 U of cloth is the village stores'
  one cloth). One herb patch grows by
  the south road (160 U, 128 at the start, regrowing each midnight, gathered down to 32 U); by day, while the shelf
  holds under 12 U, the idle herbalist gathers 4 U and carries it to the shelf. **One shelf, two sources** (decision
  0902): a treatment's herb is the pantry's `herb` item, the one foraging trips bring in, so while the shelf is short
  the pantry's free herb is moved onto it first and only what is still short sends the herbalist out. Cloth is not made
  in the demo (0622 P8, ruled): building the infirmary takes 12 U of it (0623 P1).
- **The work pace** (`work/work_pace.gd`, `demo_services.gd` `work_pace`): each owner's per-resident work factor,
  multiplied; the infirmary adds the health factor (600 under 40, 850 under 70) and the winter its Chilled factor (800),
  so a hurt, Chilled resident works at 68% (decision 0902). HEAL work reads it, and the winter writes it into each
  resident's `work_permille`, which the outdoor crews credit their work by -- once, never twice.

## Wildlife (decision 1631; feature #11)

Robins hop and peck about the lawn and paths and fly from spot to spot; peacock butterflies flutter over the beds and
settle on the plants; common frogs sit on the pond's bank and hop along it; brown trout leap in the pond and the
stream's run (`wildlife/`). They are the rigged art pass 2 models (decision 0951) at DEC-047's sizes: robin 0.45 m,
butterfly 0.36 m across, frog 0.40 m, trout 0.80 m. **Ambient, never simulated**: what shows is a function of the
season, the hour and the weather (`wildlife_rules.gd`), and nothing is written anywhere (REQ-SET-059/065, the fauna
contract's "no active fauna"). Nobody can select, feed or hunt them (REQ-ADM-001).

| | When | Does |
|---|---|---|
| Robin | all year (fewer in winter), in daylight; half in rain or snow | rests, pecks, hops, flies to another spot; **takes wing when a resident on the surface comes within 1.6 m** (not in rain or snow) |
| Butterfly | spring to autumn, dry daylight at 10 °C or more | flutters round its spot, settles on a plant top, rises again |
| Frog | spring to autumn, day and night, above freezing | sits facing the water, hops along the bank and back |
| Trout | spring to autumn, in daylight | leaps every 6-16 s, along the run's flow or round the pond |

- **Reduced motion** stills them: no hops, flights, flutters or leaps; each still breathes in its idle clip.
- **Paused**, they hold, clips and all; at 2x and 4x they run faster.
- **Pooled**: 14 animals and 4 robin flight bodies are built once; a hidden body's AnimationPlayer is off; every mesh is
  culled past 55 m. The boot prewarm draws them all once.
- **Not staged** (CI), each is a rounded stand-in of its size and colour, so the suites test the same logic.
- The live harness: `godot --path godot --script res://test/live/demo_wildlife_live.gd -- --size 1920x1080 --capture <dir>`.

## Livelier weather (decision 1632; feature #34)

Each of GDD §5.10's seven events is shown and felt by its numbers (`weather/weather_fx.gd`, `event_look.gd`,
`weather_events.gd`, `storm_pace.gd`). The forecast says the event, its first day, its length and what it does
(REQ-SET-142); the village is told when it begins and when it is over.

| Event | Applied | Shown |
|---|---|---|
| Storm (heavy rain) | rain +2000, 3 °C colder; boats stay at the jetty; **outdoor work at 80%** | driven rain, a dark sky, **lightning** over the trees and open ground |
| Drought | 30 °C, no rain, beds dry faster; orchards want water | the grass parched straw-brown, a heat haze |
| Blight | crops lose 400 health a day | the farm's blighted beds |
| Early frost | -3 °C, frost on the beds | a rime lying all its days |
| Hard freeze | -12 °C; outdoor cold twice as fast; no boat leaves | a heavy hoar frost, a freezing mist, a low cold sun |
| Calm days | nothing (an announced safe interval) | the notice |
| Ideal spell | 18 °C, crops grow 20% faster, gentle rain | a little brighter |

- **The storm's 80%** is one factor, "storm", on the village's work pace: residents outdoors on a storm day, not those
  inside a building or below ground. The woods' and the bridge builders' own storm slowdowns are gone (they counted it
  for themselves only).
- **Lightning** strikes a standing tree or open ground near where the camera looks -- never a building (the village's,
  the mill, the boathouse, the shelter, the weir, anything the player has built), the water or within 6 m of a resident
  -- every 5-12 demo seconds while a storm day rains. A struck tree's foot smoulders briefly and the rain puts
  it out; nothing burns down (GDD §5.9: no structure fire in release 1).
- **Photosensitivity**: the flash runs in real time at any game speed, strikes are at least 3 real seconds apart, and
  with **reduced motion** each strike is one soft swell.
- **Paused**, a strike holds still and nothing new strikes.
- The live harness: `godot --path godot --script res://test/live/demo_weather_live.gd -- --size 1920x1080 --capture <dir>`.

## Layout

| Folder | Owns |
|---|---|
| `demo_manifest.gd` | Reads the staged manifest |
| `demo_clock.gd` | The presentation clock that follows the HUD's pause and speed |
| `world/` | Terrain, lighting, village layout, points of interest; the day and night (the curves, their sampler, the cycle, the surface's night lights; decision 0541) |
| `cast/` | The residents: body, clips, live tail, job routines, orders |
| `control/` | Selecting and ordering residents, the demo party panel, and group selection (control groups, the group section and its status registry) |
| `people/` | The cast's names and interests (`demo_people.json`, `people_book.gd`), the committed deeds, curation and affinity (`people_ledger.gd`, written by `people_taps.gd`), the spotlight, reflection, evening lines and inspector info (`demo_people.gd`), the inspector's person section and the offer card (decision 0491) |
| `tunnel/` | Player-dug tunnels: rules, the tunnel network and planner, planning, drawing, the underground view; and their extensions -- ground, queues, crews, jobs, hazards, finds, the demo stores, the tunnel panel; the construction theatre -- the warren's particle budget, the dig face, the baskets, the hazards' warnings, the surface signs |
| `demo_calendar.gd`, `demo_services.gd`, `village_water.gd`, `demo_notices.gd`, `demo_notice_snoozes.gd` | The one calendar, the shared set, the one water adapter (over `water/water_map.gd`), the one notice feed and its snoozed kinds (decision 0591) |
| `demo_incidents.gd`, `demo_news_clock.gd` | The incidents (open conditions, the card queue, the sound hook) and the news clock that stands still while paused |
| `weather/` | The demo's one weather (read from the farm's real §5.10 row) and its rain, snow and light |
| `burrow/` | Rooms as their own structures: the templates, sockets and refusals (`underground_rooms.gd`), placing one and its passage (`room_plan.gd`, `room_tool.gd`), drawing it (`room_view.gd`, `room_mesh.gd`); the cellar API; the fit-out (`room_fixtures.gd`, `fixture_crew.gd`, `install_task.gd`, `fixture_view.gd`, `fixture_kit.gd`, `room_text.gd`) and the night (`night_routine.gd`, `bed_allocation.gd`, `sleep_task.gd`) |
| `events/` | Seeded threats (a flood, a fire) and evacuation |
| `water/` | The stream and pond: the integer depth/shore map, carved banks, surfaces, dressing, the fishery driver, the water overlay (the Water range map layer), the weir's sluice table and its gate and leat head (decision 0441) |
| `fishery/` | Water part B: the trips, jobs and stations (`fishery.gd`, its rows `fishery_tables.gd`, its task), the numbers (`fishery_rules.gd`), the real gear locker over gear.gd, the FISH skill, the pond's ice, the words, the drawing and the node wiring it into the village (`demo_fishery.gd`) |
| `boats/` | The boat core: the jetties, berths and fixed routes (`boat_routes.gd`; the ferry's stages and third boat, decision 0437), the boats as integer rows (`boat_fleet.gd`), their drawing, and the boat as a rescue rank (`boat_rescue.gd`) |
| `ferry/` | The ferry (decision 0437): its rules, the crossings, the far copse, the stacks, the passengers and the books (`ferry.gd`), its task, its drawing, and the node wiring it into the village, the Water panel and the incidents (`demo_ferry.gd`) |
| `regatta/` | The regatta (decision 0438): its rules (the GDD's Hearth feast, the race), the occasion, race and tally (`regatta.gd`), the crews' task, and the node wiring it into the village, the Water panel and the HUD's Feast command (`demo_regatta.gd`) |
| `waterplay/` | Wading, swimming, diving, rescue and bridges: the rules, per-resident swim rows, the band and swim links, the crossings the router offers, the tasks, the bridge crew, their drawings and the Water panel; whose water range the map layer paints (`water_range.gd`) |
| `farm/` | The farm: real FarmPlot rows, the pantry (and its ledger) and its storage providers, the Pantry's Stocks table (`farm_pantry_rows.gd`), the crew's jobs, beds, panels, alerts; the goods' models and icons, carrying and the stores' shelves; the seasonal planner -- its overview rows, season calendar and timeline, soil plans, the after-action record and its tables (`farm_planner*.gd`, `farm_plan_rows.gd`, `farm_season.gd`, `farm_timeline.gd`, `farm_soil_plan*.gd`, `farm_record*.gd`) -- and the bed panel's Compare view (`farm_compare_view.gd`); the crop plans -- crop roles (`farm_crop_roles.gd`), the kitchen garden (`farm_garden*.gd`), harvest plans (`farm_harvest_*.gd`), tending policies (`farm_tending*.gd`) and the tunnel outlet box (`farm_outlet_box.gd`) |
| `kitchen/` | The meal loop: the recipe book (`dish_book.gd`) and each species' favourites (`dish_favourites.gd`), the dishes' columns and numbers (`meal_rules.gd`), the portions (`meal_store.gd`), the ingredient holds (`ingredient_takes.gd`), nourishment, the kitchen and its places, task and words, the steam, bowls and carrying (`kitchen_view.gd`), the Pantry's Kitchen tab and the node with the kitchen pantry (`demo_kitchen.gd`) |
| `orchard/` | The orchard (decisions 0671-0677): its numbers (`orchard_rules.gd`), the trees as real rows with the hedge, nursery plans, groups and the grove (`orchard_model.gd`), the jobs and their task (`orchard_jobs.gd`, `orchard_task.gd`), the words and cards (`orchard_text.gd`, `orchard_cards.gd`), the panel, the drawing, and the node wiring it into the village (`demo_orchard.gd`) |
| `seasons/` | The seasons on the woods and ground (decision 0551): the sampling (`season_look.gd`), the view that writes it to every tree, the ground and the tufts (`season_view.gd`), the leaf shader include and the in-leaf tree shader, the bare boughs and the falling leaves |
| `forestry/` | The woods: the trees as real ResourceNode rows, zones, deadfall, skills, the job board and crew, the yard, the drawings (falls, stumps, trunks, particles, zone marks), the pick, the zone tool and the Woods panel |
| `spoil/` | Selecting and clearing spoil heaps: the crew that digs and hauls, and the picking |
| `routes/` | Route and infrastructure previews (decision 0461): the estimate on copies of the network through the routing desk, the proposal's crossing, the stretches and hold-ups, the work places, a dig's stages, a bridge's project words, the Routes map layer and its subject, the rescue card's details, and the controller over the Water and Tunnels panels |
| `winter/` | The winter (decision 0571): the rules (`winter_rules.gd`), the hearths' fuel and the rooms' warmth (`hearth_fuel.gd`), each resident's cold (`cold_exposure.gd`), the warm-up break (`warm_up_task.gd`), the words, the Heating fuel breakdown (`fuel_panel.gd`), the season skip (`season_skip.gd`) and the node wiring it into the village (`demo_winter.gd`) |
| `guide/` | The first-village guide (decision 0481): the outcome ledger, the objectives' progress and words, the card and its world marker, the village guide window and its pages -- help, field guide, practice stories, projects |
| `goals/` | The village goals and milestones (decision 0781): the goal book and its registration API, the built-in goals as data with their evaluator, the ledger of running counts, the owner (hour tick, Village news) and the Goals tab's page |
| `orders/` | The standing orders (decision 0711): the kinds and goods (`standing_kinds.gd`), the book with its latch and notices (`standing_orders.gd`), one goal per kind over the woods, the farm and the kitchen (`goal_*.gd`), the Work screen's section (`standing_view.gd`, `standing_row.gd`, `standing_text.gd`) and the node keeping it on the game hour (`demo_standing.gd`) |
| `work/` | The work board over every job owner (one adapter each), the claim, the named crews and presets, the order lists' entries, Shift+right-click's queue and the Work screen (decision 0411); the village's one work pace (`work_pace.gd`, decision 0622) |
| `hall/` | The hall's two stages and banners (`hall_rules.gd`, `hall_projects.gd`), the builders' rounds (`hall_crew.gd`, `hall_task.gd`, `hall_resume.gd`), its drawing (`hall_view.gd`), its panel, the village tapestry and its panel, and the node with the gathering query (`demo_hall.gd`) (decision 0771) |
| `infirmary/` | Injuries and their care (decisions 0621-0623): the numbers (`care_rules.gd`), health and the Injury row on the real stores (`care_state.gd`), the patients, healers and herbalist (`care_desk.gd`), the bed rest, treatment and gathering tasks, the words, the herb patch's drawing; the infirmary building -- its numbers, books, builders, placing tool, drawing and node (`infirmary_*.gd`) -- its section in the Tunnels panel, and the node wiring it all into the village (`demo_care.gd`) |
| `session/` | The time controls: the pause ledger (the kinds, their words, the one Resume), "Run until…" (its targets read from the calendar, the kitchen, the projects, the beds and the news) and the frame-by-frame control (Space, G, the HUD's pause button, the planning surfaces, the critical incidents) (decision 0471) |
| `access/` | Accessibility: the settings and presets, their effects on the village, reduced motion, the world's interactive targets (the object list, F6, and their rings), the focus hint, the Settings section (decision 0471) |
| `demo_prewarm.gd` | The boot prewarm: what would first load mid-game, loaded while the village opens; then the underground view drawn once |
| `demo_layers.gd` | The four render layers every drawn node is on, and the plane each view picks on (decision 0206) |
| `map_lenses.gd`, `lens_subject.gd` | The map layers: one shown at a time, each with its question, legend and subject; V's cycle and U's followed layer (decision 0292); each layer's scale, probe and the compared layer (decision 0581) |
| `lenses/` | The map layers' legends, hover readout and compare outlines (decision 0581): a layer as one record, the probes (beds, water, woods), the legend scales, the colour tokens and the colour-blind check, the outlines, and the kit that wires them |
| `props/` | The staged small props (one table, one mesh per model, icons and their roundel fallback) and the store shelf |
| `ui/` | The woodland HUD skin; the HUD date, the news strip, the village-news history, the incident card and "Go to", and the right column's tabs; the HUD's village read model (counters and ledger), the Residents roster and the village map; the Map layer picker; the pause card and the "Run until…" button and menu (decision 0471) |
| `camera/` | The RTS camera, and the canopy clearance: the eye kept out of crowns, the crowns in the way thinned, the selected shown through; the camera's modes (bookmarks, follow, orbit, the cutaway angle), the edge pan and their strip |
| `sound/` | The sound pass: the cue table (data), the mix and its buses, the voice pool, the event map, the owner and the Settings section |
| `chronicle/` | The village chronicle (decision 0631): one season's tally of the news (`chronicle_tally.gd`), the pages (`chronicle_book.gd`), their words and writer (`chronicle_text.gd`, `chronicle_writer.gd`), the owner that writes a page at each season's end (`demo_chronicle.gd`) and the book (`chronicle_window.gd`) |
| `songs/` | The residents' songs: the repertoire (data), who sings what when, the bubbles, the hum (decision 0442) |
| `playtest/` | The playtest log (decision 0562): the session and its file, the breadcrumb ring, the error logger, the freeze watch, the header, the folder's rotation, F12's mark and toast, the Settings section, and the village's taps |
| `assets/` | **gitignored** — staged by `tools/stage_demo_assets.py` |
