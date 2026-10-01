# 0351 — The demo's first sound pass: a scene-scoped owner, five buses, a bounded pool and an observed event map
Date: 2026-09-30 · Status: Accepted

Review group R ("the first sound pass"): finding F43 of the live-demo review (`redwall-review/REVIEW.md`), the
sound parts of its plan P8, and the digest's UX-029 ("sound that reveals work and place") and UX-031
("intelligible, adjustable sound"). **Numbered 0351, not 0262:** the highest record on this branch is 0261
(group G), and groups C, H, J, Q and tunnel phase 6 are writing records in parallel, so this group took the
highest number plus 90 to avoid a collision.

F43 was confirmed on this branch (`fix/review-g-input`, ab6b765) before the work: no `AudioStreamPlayer`,
`AudioServer` or audio bus anywhere in `godot/demo`, `godot/scripts` or `project.godot`, and the game menu's
Settings page said "the demo has no sound yet".

**This is phase 1 only. No sound file was downloaded or added.** Every cue is wired and plays *silent* until
its file is staged; the sourcing plan (CC0 packs, per cue) waits on Brendan's approval of each download.

## Decision

### 1. One scene-scoped owner, not the AudioManager autoload

`godot/demo/sound/sound_director.gd` is a child of the village, made and freed with it. `project.godot` already
has five autoloads (EntityManager, GameManager, SettlementSystem, EconomySystem, UIManager) against CLAUDE.md's
cap of six; ARCH-GODOT-001 reserves an AudioManager as the settlement's "optional presentation" service.

Rejected: spending the sixth slot now. Everything the demo's sound hears is demo state -- the cast's brains,
the woods' job board, the tunnel network, the swim rows, the notice feed, the demo camera -- none of which
exists outside the demo scene. A global would point at nothing in the game, would have to be re-bound on
every Restart, and would take the last slot from the game's real AudioManager. The table, mix and voice pool
read no demo model, so that AudioManager can take them over unchanged later.

### 2. Five buses, two internal halves

Master; Ambience (wind, rain); Work (tools, loads, footsteps); Water (stream, splashes, wading); Cues (warnings,
completions, clicks). Work sends through two halves of its own, "Work Surface" and "Work Under", so the U view
can filter one without the other. Buses are made **by name, once** (`sound_mix.gd ensure_buses`): a Restart
finds them standing. Rejected: a `default_bus_layout.tres` -- it would touch the shared project settings for a
demo feature.

Defaults are UI §8.1's: master 80, ambience 60, effects (Work) 75, notice (Cues) 70. §8.1 lists water under
ambience ("wind/water/hearth ambience"), so Water defaults to 60. §8.1's controls are steppers 0–100 in 5 %
steps; the demo keeps those steps.

### 3. A bounded voice pool with real-time gaps (no stacking at 4x, no pitch-up)

`sound_voices.gd` makes 8 Work, 4 Water and 3 Cues players at boot and never another. Ambience has no
one-shot voices: its three loops (wind, rain, the stream) are the director's. A play is refused when:

- **the gap**: the cue played less than its `gap_ms` of **real** time ago (`Time.get_ticks_msec`, never the
  demo clock). At 4x the models raise strikes four times as often; the gap folds them into the same plays per
  second as 1x (`folded` counts them). Twenty fellers raise about four times the strikes at 4x and the chop
  plays no more than its gap allows (`test_four_x_raises_more_strikes_but_never_stacks_them`);
- **the cue's cap** (`voices`, per cue) or **the bus's pool** is full.

A voice is busy until its stream's length has run, or `HOLD_MS` (350) for a silent cue, so the caps behave
the same with and without files. **No player's `pitch_scale` is ever written**; the demo never touches
`Engine.time_scale` either (GameManager's rule), so 4x cannot pitch anything up.

### 4. The listener over the camera's focus

An `AudioListener3D` stands over the camera's focus, 0.4 of the zoom distance up, **turned with the camera's
heading** (Q/E and middle-drag turn the view; without the turn a sound on the screen's left would be heard on the
right once the view faced south): close in, the work at the
focus is near; zoomed out to the 70 m limit the listener is 28 m up, beyond the work cues' 12–45 m ranges,
and the village settles to its ambience (UX-029's "calm bed of sound when zoomed out"). A placed cue farther
from the listener than its range is refused before it takes a voice, so distant work never steals one from
near work. Rejected: the camera as the listener (the default) -- at the default 22 m zoom every footstep in
view would be equally distant and nothing would be "near".

### 5. Pause and the U view

Paused for any reason (the clock's effective speed 0: the player, the menu, the stall banner): the Ambience and
Water buses duck 12 dB, every Work and Water one-shot is stopped and none starts; Cues still sound (a warning
raised while paused, a click). The U view switches a low-pass (800 Hz) on Ambience, Water and Work Surface --
the world above heard through earth -- and off on Work Under; with the U view off it is Work Under alone that
is muffled. Rejected: `AudioStreamPlayer3D.attenuation_filter_*` per voice -- it scales with distance, not a
constant "through the ground" muffle.

### 6. The event map observes committed state; it hooks nothing

`sound_taps.gd` reads the models once a frame and sounds an **edge in state the model has already committed**:
a carry beginning/ending (pickup, drop), `in_water` changing (water_in/out), a swim mode becoming swim, tread or
dive (splash), each whole `STRIDE_M` walked (a footstep by the ground underfoot: tunnel below, wading, a bridge
leg's wood, a worn path's dirt, else grass; none while swimming; a jump over 3 m is a placement), each whole
beat of a woods work step that **has begun** (`issued`): felling (chop, or gnaw for a beaver), grubbing (dig)
and sawing; a tree going from standing to a stump (felled) or straight to cleared (a storm's blow-down)
(tree_fall); each dig quantum cut (`cut_count`), at the
digger, below; a tunnel/room segment DIGGING → OPEN or a bridge PLANNED → OPEN (complete); a **new** warning row
in the notice feed -- a repeat the feed folds ("×2") writes no row and does not chime again (UI §7). New rows are
counted by `demo_notices.gd rows_posted`, a counter added for this (the one line this group adds to the feed):
an earlier time-based check could raise one warning twice, or miss a warning folded in the same frame; every button press (ui_click).
Wind and rain are levels from the weather's condition; the stream is heard from the bank nearest the listener.

Why observation rather than `cue()` calls inside the crews: (a) ARCH-GODOT-003 has signals and effects flow
**outward** from committed state to presentation, and reading committed columns guarantees "completed events
only" by construction; (b) the map writes nothing, so neither a sound nor an animation can ever award a
resource (P8); (c) five other groups are editing the crews, the water and the tunnels in parallel -- hooks in
those files would have collided with all of them. The cost is that the map knows the models' column names;
that coupling is in one file, read-only, and every edge has a test.

Two costs were measured and designed out: `water_map.nearest_bank` (~83 µs, every shore sample) is redone only
after the listener moves 1 m; `world_layout.path_distance` (~3.6 µs) is gridded once at boot (64 x 64 cells of
0.75 m over ±24 m) instead of called per footstep.

### 7. A data table with silent placeholders

`sound/sound_table.json` holds every cue: files (variants), bus, positional, loop, volume, range, real-time gap,
voices and an **equivalent** -- what shows the same thing with the sound off. The loader **refuses a cue with no
equivalent** (UI §7: "All sound cues have visible text"; UX-031), so a cue can never be the only way to learn
something. Files point at `res://demo/assets/sound/<cue>_NN.ogg`, the gitignored staged folder the Windows
build already exports (`include_filter` has `*.json, demo/assets/*`): staging a file is the whole change.
Missing files warn **once per cue** at boot and the cue plays silent. Streams load in the boot prewarm
(`demo_prewarm.gd`'s "sound streams" step, with the path grid), so no first play loads mid-game.

### 8. Settings in the game menu

The Settings page's "Sound" section (`sound_settings_ui.gd`): per bus −, a slider and + (5 % steps), the percent,
and Mute (the volume is kept); and three mixes -- Balanced (UI §8.1's defaults), Quiet focus (alerts 85, world
20–30: UX-031's reduced-stimulation mix) and Atmosphere. The lit mix is the one the volumes match; none when
they are the player's own. The − and + buttons are the keyboard's way: the input gate (decision 0261) steps
through buttons only, so the slider takes no focus. The page now scrolls inside the modal rectangle when the
window is short; at 1280x720 it fits without scrolling (live check). The note says the truth: no files are in,
so the demo is silent, and every sound has a text or picture match.

**Persistence** follows the interface scale's (decision 0261, `demo_ui_scale.gd`): static vars, kept for the
session and through Restart, never written to disk -- the demo saves nothing.

## Integration with the village news (review batch 2)

Group I's incidents (decision 0331) landed beside this pass. Its sound hook, `incident_cue(cue, serial,
severity)`, is now heard: `sound_taps.gd` connects to `services().incidents.incident_cue`, and a
CUE_CRITICAL_RAISED (a critical incident raised, or come back after it resolved -- never a merged repeat) asks
the next poll for the **warning** cue. The poll chimes once a frame at most, so a critical incident that is
`report`ed, and so also posts its warning row, is heard once. A WARNING-severity incident raised without a
feed row stays silent (it is not a new warning row); CUE_RESOLVED is not sounded -- the table has no cue for a
resolution, and adding one is left to the sound files' pass. The connection is the one signal the event map
listens to: a presentation cue the incidents emit for exactly this purpose. Tested in `test_demo_sound.gd`
(`test_a_critical_incident_chimes_once_and_a_warning_or_a_merged_repeat_does_not`). `rows_posted` is bumped
where I's feed appends a row, not where it folds a repeat.

## Not done (recorded so it is not assumed)

- **No audio was heard.** Without files nothing can be; the mix levels, ranges and gaps are first guesses to
  be tuned by ear once the approved files are staged.
- Farm work (hoeing, harvest), fishing, fixture installs, storm gusts and the beaver's distinct gnaw texture
  have no cues yet. UX-031's optional captions are not built: each cue's equivalent is an existing visual.
- UX-030's music motif and UX-032's voices are out of scope.

## Evidence

- `test/test_demo_sound.gd` (44 tests): the table and each of its refusals, a staged file loading (and looping)
  beside a missing one, missing files (one warning per cue, ever), bus routing, gaps, cue and bus caps, 4x
  folding, pitch 1 and variants through `update()` at 4x, the pause ducking and refusing, the U view's filters,
  the listener (lift, far refusal, heading), settings → bus volumes and mutes, the mixes, persistence, the menu
  page, and every event-map edge firing on the committed event only (including blow-downs, reused job rows, a
  warning folded or buried under a note in the same frame).
- `test/live/demo_input_live.gd`, on the real scene at 1280x720 and 1920x1080 (the runner has no tree, so what
  needs one is checked here): the Settings frame fits the window; the owner ducks while the menu holds the clock;
  Work's + moves the real Work bus; with a silent stream injected a chop's player really plays at pitch 1 and the
  pause really stops it; the rain loop starts and stops with its level; a button made after boot clicks.
- `test/test_demo_sound_cost.gd`: twenty residents at 4x (all walking, twelve felling, one digging, loads,
  warnings; trees, bridges, weather and the real water map read): the director's frame p50 37 µs, p95 71–76 µs,
  p99 106–123 µs, max ≤ 230 µs over three runs (headless, Apple Silicon); the boot prewarm step about 16 ms.
- **Mutation testing**, one mutant at a time, restored and hash-checked after each. First pass 40 mutants: 33
  killed; tests were added and the seven re-run, six killed. After review, a second pass of 58 (55 against
  `test_demo_sound.gd`, 3 needing a tree against the live harness): 56 killed. The two survivors are equivalent:
  `_poll_cuts`' "dig time unchanged" early return only saves a `cut_count` call, and the job-step change's beat
  reset is subsumed by the "work begun again" reset.
- **Independent review** (the `code-reviewer` agent): no CRITICAL; one HIGH -- the listener did not turn with the
  camera, so left and right were swapped in a turned view -- fixed and tested. Its MEDIUM findings were fixed
  too: warnings counted by new rows, blow-downs fall, every table refusal tested, the surviving mutants it listed
  killed or shown equivalent, two tests that could not fail rewritten. LOWs fixed: − / + tooltips kept, the
  slider ignores the wheel, the scroll follows the keyboard focus, a paused dig's progress is taken as the
  baseline, `stop_bus` counts only voices still sounding, the unused `cue_id` removed, the stream heard from 45 m
  (the listener rises to 28 m zoomed out).

## Phase 2 — the approved files (2026-09-30)

Brendan approved nine downloads on 2026-09-30, and nothing else: P1–P8 of the sourcing plan and the optional
Shovel Sound. The plan is now [`docs/art-reference/audio_library/sound_sourcing.md`](../art-reference/audio_library/sound_sourcing.md),
moved out of a scratch folder because AGENTS.md wants docs from outside sources in `docs/`. Its ledger is
[`docs/art-reference/audio_library/README.md`](../art-reference/audio_library/README.md) and `files.json`.

### 9. How the packs were taken

Each page was read again just before downloading. All nine still said CC0, and none needed a login. Only each
page's own file link was fetched, after a HEAD check of its size. The total is 11.6 MB, the largest file 3.5 MB,
and every size matched its HEAD. Each archive was listed before it was unzipped. The packs held 356 Ogg files,
Kenney's three `License.txt` files and six Windows `.url` shortcuts. The shortcuts were deleted by exact path,
and nothing was run. The binaries live in `assets/library/audio/<pack>/`, which is gitignored, as decision 0188
lays the library out. The download is kept under `download/`, next to what it unzipped to. An OpenGameArt pack
with no licence file has a `LICENCE_AS_STATED.txt` that records what its page said. `files.json` lists all 374
files in the library: each one's pack, source, licence as stated, date, bytes, SHA-256, and the cue variants
that use it.

### 10. Staging copies where it can, and renders WAV where it must

`tools/stage_demo_audio.py` (called by `stage_demo_assets.py`, or `--only sound`) holds `CHOICES`, the cue →
variants map. It writes `godot/demo/assets/sound/<cue>_NN.ogg|wav`, and `sound_table.json` lists exactly those
files, which `tools/test_stage_demo_audio.py` checks in CI. A file that plays as it is gets **copied**, byte
for byte (38 files). A file that needs a cut, a level change or a loop fix gets **rendered** to 16-bit WAV
(18 files).

The reason for WAV: this Mac has no ffmpeg, and macOS `afconvert` decodes Vorbis but cannot encode it.
Rejected options:
- Installing ffmpeg: the brief said to use it only if it was already there.
- Dropping the cuts: the saw is a single loop, and the tree's recording opens with a chop that the chop cue
  already plays.
- Per-file volume in the table: that would be a code change for something the data can carry.

Staging checks each source's SHA-256 against `files.json`. A file that is missing, unlisted or changed is
skipped and reported, and any earlier copy of it is removed, with its `.import`. A staged file that no choice
names any more is removed too, so the Windows build never exports a sound the latest run refused. Without
`afconvert`, the rendered files are skipped the same way. A copy must be an Ogg Vorbis file. `--ledger` refuses
to re-record a file whose SHA-256 changed unless it is given `--rehash`. In `stage_demo_assets.py` the sound runs
last, so a sound problem cannot stop the models.

### 11. First volumes by measurement

Nothing was heard, so the levels are measured. The tool measures ITU-R BS.1770 K-weighted loudness in pure
Python (`--measure`), checked against a 1 kHz sine (-3.0 LUFS at full scale in one channel). It is measured
as Godot plays the file, so a mono file counts in both speakers (+3.01 dB). The level of a one-shot is its
loudest 400 ms; the level of a loop is its gated integrated loudness. Each cue has a target
before its bus (`TARGET_LUFS`):

| Cue | Target (LUFS) |
|---|---:|
| Tree fall | -16 |
| Chop, splash | -20 |
| Dig | -22 |
| Saw | -23 |
| Gnaw, drop | -24 |
| Footsteps | -28 to -31 |
| Warning | -18 |
| Completion | -20 |
| UI click | -28 |
| Ambience | -26 to -30 |

`volume_db` is set to the target minus the measured level, clamped to -60..+6. Variants were chosen, or
levelled by render, to within about 4 LU of each other. One file was dropped rather than levelled: Impact's
`footstep_wood_004` is 17 LU louder than its siblings. Gnaw and the wood steps are raised in their render, so
that they reach their targets. Three cues sit at +6 (chop, pickup, step_wood), within 0.4 LU of their targets.
No cue is more than 0.6 LU from its target. The numbers are in the ledger's README.

### 12. The wind loop clicked; it is cross-faded

None of the three loops has silence at either end, so none was trimmed for that. Their joins were then compared
with each file's ordinary sample-to-sample steps:

| Loop | Jump at the join | Ordinary step, 99th percentile | Result |
|---|---:|---:|---|
| Stream | 514 | 847 | Clean |
| Rain | 105 | 755 | Clean |
| Wind (P8) | 1,140 | 141 | A click every 6 s |

The wind's recording fades to about 0 in its last samples but starts at -1,137. Its last 500 ms are now
cross-faded (equal power) into its first, and dropped from the end. The WAV carries a `smpl` loop marker, which
Godot's default import ("Detect From WAV") reads: the engine imports the file as loop forward, 0 to 262,046.
After the fix, the jump at the join is 75. `sound_table.gd`'s rule that "a WAV keeps the loop authored in the
file" therefore holds, with no code change. **The wind may still be too "whooshy"**, as the plan warned. It
stays until Brendan has heard it.

### 13. Tests pass staged or not

CI stages nothing, so two phase-1 tests that assumed nothing was staged now hold either way:
- The missing-files test uses the shipped table with its files moved to a folder that does not exist.
- The prewarm test expects as many streams as are staged.

A new test checks that the table is staged whole or not at all. A partial set means a file was skipped or not
imported. When staged, every file loads with a length, each loop cue loops (an Ogg set to loop, or a WAV whose
marker was imported), and no one-shot is longer than 2 s. The player-facing note for no sound files now says
"This copy of the demo has no sound files" instead of "not in yet".

### Evidence (phase 2)

- `./tools/run_tests.sh`, with the files staged and imported: `6471 test(s), 549758 assertion(s), 0 failure(s)`.
  `test_demo_sound.gd` and `test_demo_sound_cost.gd` were also run alone. With the sound folder moved away (as in
  CI): 0 failed, 507 and 19 assertions. Staged: 0 failed, 621 and 19.
- `python3 tools/test_stage_demo_audio.py`: 206 checks. The negative cases come first:
  - a source that is missing, changed, not in the ledger, or a copy that is not an Ogg is skipped;
  - a later refusal removes the earlier staged copy, and an unchosen file is removed;
  - cuts and seams that do not fit refuse;
  - a WAV that is not 16-bit refuses;
  - the ledger will not re-record a changed hash.

  Then it checks the render arithmetic, the seam's join and equal-power blend, the forward loop marker,
  BS.1770 on known sines (mono as played, one channel of two, the gates, the high pass), `measure`, and that the
  table and the ledger match `CHOICES`.
- **Independent review** (the `code-reviewer` agent) found nothing CRITICAL or HIGH. It confirmed, by running
  them, the WAV and `smpl` layout, the seam, the cuts (afconvert's decoded lengths match Godot's), the
  K-weighting and the ledger. It raised four MEDIUM findings, all fixed:
  - stale or orphaned staged files outlived a refusal;
  - mono was measured 3 dB under how Godot plays it, which put the completion above the warning;
  - ten mutants of the self-test survived; there are now tests for each;
  - an audio crash could stop the model staging.

  Its LOW findings were fixed too: dot-files are kept out of the ledger, only an Ogg is copied, writes are
  atomic, `--measure` survives an unreadable file, `--ledger` needs `--rehash` to accept a changed hash, the
  "silent cue" test is made silent, and the ceiling wording is corrected.
- **Headless boot of the demo** (`demo_village.tscn`, 240 frames, three runs after the fixes): the
  `sound streams` step loaded 56 files in 21.7–22.5 ms. In phase 1, with nothing staged, it took about 16 ms.
  There were 0 missing-file warnings and 0 table errors, and the whole prewarm took 144–148 ms.
- The live harness at 1280x720: `LIVE-SUMMARY 126 0`. That includes the chop played, the rain loop playing
  while it rains, and a button's click.
- **Still not heard by anyone.** What to listen for is listed in the ledger's README.
