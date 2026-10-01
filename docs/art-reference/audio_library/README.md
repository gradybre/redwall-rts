# Audio library — CC0 sound packs for the live demo, 2026-09-30

Nine CC0 packs, downloaded on 2026-09-30 with Brendan's approval of exactly these nine, give the live demo's 21
sound cues their files. Why the demo sounds the way it does, and what is not done:
[decision 0351](../../decisions/0351-the-demo-s-first-sound-pass.md) ("Phase 2"). The research that chose the
packs, before any download: [sound_sourcing.md](sound_sourcing.md).

**Nothing here is tuned by ear.** The first volumes come from measured loudness; they wait on Brendan's listen
(see *What to listen for*).

## Where things are

| What | Where | In git? |
|---|---|---|
| The packs as downloaded, and unzipped — 374 files, 23.6 MB | `assets/library/audio/<pack>/` (`download/` holds the file as fetched) | **No** — gitignored |
| Every file: pack, path, bytes, SHA-256, licence as stated, source page, download date, which cue uses it and how | [`files.json`](files.json) | yes |
| Which file plays for which cue, and how it is cut or levelled | `tools/stage_demo_audio.py` (`CHOICES`) | yes |
| The staged files the demo plays | `godot/demo/assets/sound/<cue>_NN.ogg\|wav` | **No** — gitignored, made by staging |

```bash
python3 tools/stage_demo_audio.py              # stage (tools/stage_demo_assets.py runs it too)
godot --headless --path godot --import         # import what staging added
python3 tools/stage_demo_audio.py --measure    # the staged files' loudness, and the volume_db each cue needs
python3 tools/stage_demo_audio.py --ledger     # rewrite files.json from the library (only after a new download)
```

Staging checks every source against `files.json` and skips, with the reason, any file that is missing or whose
SHA-256 changed. **Lost the library?** Every pack's `download` URL is in `files.json`; the downloaded file's
SHA-256 is there to check it against.

## The packs

All nine pages were read again on 2026-09-30, just before downloading, and still said CC0. None needed a login. Each file came
from the page's own link and nothing else, and its size was checked with a HEAD request first. No file was over 50 MB, and the
downloaded sizes match the HEAD sizes exactly.

| Pack (library key) | Page | Downloaded file | Bytes | SHA-256 | Licence as stated |
|---|---|---|---:|---|---|
| Kenney "Impact Sounds" (`kenney_impact_sounds`) | <https://kenney.nl/assets/impact-sounds> | `kenney_impact-sounds.zip` | 800,850 | `029d734af1582474edf3a694d1b0cebc97c1c152f2f39fa34d4c2bafc5de77f8` | page: "License: Creative Commons CC0"; `License.txt`: "License: (Creative Commons Zero, CC0)" |
| Kenney "RPG Audio" (`kenney_rpg_audio`) | <https://kenney.nl/assets/rpg-audio> | `kenney_rpg-audio.zip` | 964,837 | `6dbeaf8544da958d8f2adcb4a4a4b76c1ade34a05f8ab9edccd327da7375f38b` | page: "Creative Commons CC0"; `License.txt`: "License (Creative Commons Zero, CC0)" |
| Kenney "Interface Sounds" (`kenney_interface_sounds`) | <https://kenney.nl/assets/interface-sounds> | `kenney_interface-sounds.zip` | 834,536 | `f2193d072726d6758a5f7871b2dcc54dcce0d5c35c6f0a62f92549b327c81232` | page: "Creative Commons CC0"; `License.txt`: "License: (Creative Commons Zero, CC0)" |
| OGA "30 CC0 SFX loops" (`oga_30_cc0_sfx_loops`) | <https://opengameart.org/content/30-cc0-sfx-loops> | `sfx_loops.zip` | 3,526,706 | `9c013474c7e56192a0d1b2840535a1e1d8b93166948d4a9f7136bb6c3d5421cd` | page: "License(s): CC0" |
| OGA "Rain (loopable)" (`oga_rain_loopable`) | <https://opengameart.org/content/rain-loopable> | `Rain OGG.zip` (the OGG zip only) | 2,736,596 | `e68f3e1c77493cf43bec84cebff5043bff6be9ce16d59b24caa988cd460aa75b` | page: "License(s): CC0" |
| OGA "tree chop fall thud" (`oga_tree_chop_fall_thud`) | <https://opengameart.org/content/tree-chop-fall-thud> | `chop-tree-fall.ogg` | 194,760 | `21842dd004b46315a5d52be80997773421d8b1d3a0d473ddbcad388efd93b33a` | page: "License(s): CC0" |
| OGA "40 CC0 water/splash/slime SFX" (`oga_water_splash_slime_sfx`) | <https://opengameart.org/content/40-cc0-water-splash-slime-sfx> | `water-splash-slime-sfx.zip` | 2,259,262 | `7cd39abb49d4362a37ba18dc0e454c7dc1d08029d4e5b683149046bc237b2eba` | page: "License(s): CC0" |
| OGA "wind whoosh loop" (`oga_wind_whoosh_loop`) | <https://opengameart.org/content/wind-whoosh-loop> | `wind woosh loop.ogg` | 251,584 | `0cfdbd3f21ed449689a9024264edf267d0037a6495813a7010827672ec191dac` | page: "License(s): CC0" |
| OGA "Shovel Sound" (`oga_shovel_sound`, the optional ninth) | <https://opengameart.org/content/shovel-sound> | `shovel_0.ogg` (saved by the page as `shovel.ogg`) | 21,923 | `1ad178afa5d959ecd4454c3d8388abb23451a1f43a028f476aa37aa3a944d195` | page: "License(s): CC0" |

The Kenney zips carry their own `License.txt`, kept in the library. The OpenGameArt downloads ship no licence
file, so each pack's folder has a `LICENCE_AS_STATED.txt` that records what the page said and when.

**What the archives held.** Every archive was listed before it was unzipped: Ogg Vorbis audio (356 files unzipped, plus the
three single-file downloads: all 359 confirmed `Ogg data` by `file`), Kenney's three `License.txt` files, and **six Windows internet shortcuts**
(`Kenney.url`, `Patreon.url` in Impact and Interface; `Visit Kenney.url`, `Visit Patreon.url` in RPG Audio:
`[InternetShortcut]` text pointing at kenney.nl and Patreon). The shortcuts are not audio or licence text, so
they were deleted, each by its exact path. Nothing else unexpected was found, and nothing downloaded was run.
RPG Audio also has `Preview.ogg`, a demo reel, kept and unused.

## Cue to file

`CHOICES` in `tools/stage_demo_audio.py` is the source; this table is it as staged on 2026-09-30. **Copied**
files are the pack's Ogg byte for byte. Files that are **cut** or **levelled** are rendered to 16-bit WAV,
because this Mac has `afconvert`, which decodes Vorbis but cannot encode it, and no ffmpeg. "Level" is the
loudest 400 ms block (ITU-R BS.1770 K-weighted, so a file shorter than a block counts as one padded block), or
the gated integrated loudness for a loop. It is measured as Godot plays the file: a mono file (`complete`,
`ui_click`) goes to both speakers, so it counts 3 dB above the single channel BS.1770 alone would count.

| Cue (bus) | Staged file | Library source | How | Level (LUFS) | Peak (dBFS) |
|---|---|---|---|---:|---:|
| **chop** (work) | `chop_01.wav` | `kenney_rpg_audio/Audio/chop.ogg` | -10.0 dB | -26.0 | -10.0 |
|  | `chop_02.ogg` | `kenney_impact_sounds/Audio/impactWood_heavy_000.ogg` | copied | -26.1 | -7.0 |
|  | `chop_03.ogg` | `kenney_impact_sounds/Audio/impactWood_heavy_001.ogg` | copied | -26.4 | -7.3 |
|  | `chop_04.ogg` | `kenney_impact_sounds/Audio/impactWood_heavy_002.ogg` | copied | -26.0 | -7.3 |
|  | `chop_05.ogg` | `kenney_impact_sounds/Audio/impactWood_heavy_003.ogg` | copied | -25.8 | -8.5 |
| **gnaw** (work) | `gnaw_01.wav` | `kenney_impact_sounds/Audio/impactWood_light_000.ogg` | +4.0 dB | -27.5 | -10.3 |
|  | `gnaw_02.wav` | `kenney_impact_sounds/Audio/impactWood_light_001.ogg` | +4.0 dB | -29.2 | -10.2 |
|  | `gnaw_03.wav` | `kenney_impact_sounds/Audio/impactWood_light_002.ogg` | +4.0 dB | -27.2 | -9.8 |
|  | `gnaw_04.wav` | `kenney_impact_sounds/Audio/impactWood_light_003.ogg` | +4.0 dB | -29.1 | -11.0 |
|  | `gnaw_05.wav` | `kenney_impact_sounds/Audio/impactWood_light_004.ogg` | +4.0 dB | -29.5 | -10.6 |
| **saw** (work) | `saw_01.wav` | `oga_30_cc0_sfx_loops/saw.ogg` | cut 0.20–0.68 s | -24.2 | -8.5 |
|  | `saw_02.wav` | `oga_30_cc0_sfx_loops/saw.ogg` | cut 0.90–1.36 s, +2.0 dB | -23.3 | -11.6 |
|  | `saw_03.wav` | `oga_30_cc0_sfx_loops/saw.ogg` | cut 1.58–2.08 s, -2.0 dB | -23.2 | -10.3 |
| **dig** (work) | `dig_01.wav` | `oga_shovel_sound/download/shovel_0.ogg` | cut 0.00–0.40 s, -6.0 dB | -19.8 | -6.0 |
|  | `dig_02.wav` | `oga_shovel_sound/download/shovel_0.ogg` | cut 0.50–0.78 s, +13.0 dB | -19.9 | -5.1 |
|  | `dig_03.wav` | `kenney_impact_sounds/Audio/impactMining_004.ogg` | -2.5 dB | -19.8 | -3.4 |
| **tree_fall** (work) | `tree_fall_01.wav` | `oga_tree_chop_fall_thud/download/chop-tree-fall.ogg` | cut 0.96–2.40 s | -14.1 | -0.5 |
| **pickup** (work) | `pickup_01.ogg` | `kenney_rpg_audio/Audio/handleSmallLeather.ogg` | copied | -34.0 | -11.6 |
|  | `pickup_02.ogg` | `kenney_rpg_audio/Audio/handleSmallLeather2.ogg` | copied | -36.4 | -16.5 |
|  | `pickup_03.ogg` | `kenney_rpg_audio/Audio/cloth4.ogg` | copied | -32.5 | -14.6 |
| **drop** (work) | `drop_01.ogg` | `kenney_impact_sounds/Audio/impactPlank_medium_001.ogg` | copied | -16.6 | -1.0 |
|  | `drop_02.ogg` | `kenney_impact_sounds/Audio/impactPlank_medium_002.ogg` | copied | -17.4 | -1.0 |
|  | `drop_03.ogg` | `kenney_impact_sounds/Audio/impactPlank_medium_003.ogg` | copied | -17.5 | -1.0 |
|  | `drop_04.ogg` | `kenney_rpg_audio/Audio/dropLeather.ogg` | copied | -18.2 | -0.1 |
| **step_grass** (work) | `step_grass_01.ogg` | `kenney_impact_sounds/Audio/footstep_grass_000.ogg` | copied | -37.1 | -15.7 |
|  | `step_grass_02.ogg` | `kenney_impact_sounds/Audio/footstep_grass_001.ogg` | copied | -32.7 | -14.7 |
|  | `step_grass_03.ogg` | `kenney_impact_sounds/Audio/footstep_grass_002.ogg` | copied | -34.9 | -18.4 |
|  | `step_grass_04.ogg` | `kenney_impact_sounds/Audio/footstep_grass_004.ogg` | copied | -35.1 | -14.0 |
| **step_dirt** (work) | `step_dirt_01.ogg` | `kenney_rpg_audio/Audio/footstep00.ogg` | copied | -19.7 | -0.0 |
|  | `step_dirt_02.ogg` | `kenney_rpg_audio/Audio/footstep01.ogg` | copied | -17.6 | 0.0 |
|  | `step_dirt_03.ogg` | `kenney_rpg_audio/Audio/footstep03.ogg` | copied | -19.1 | 0.0 |
|  | `step_dirt_04.ogg` | `kenney_rpg_audio/Audio/footstep08.ogg` | copied | -16.4 | 0.0 |
| **step_wood** (work) | `step_wood_01.wav` | `kenney_impact_sounds/Audio/footstep_wood_000.ogg` | +12.5 dB | -34.0 | -12.5 |
|  | `step_wood_02.wav` | `kenney_impact_sounds/Audio/footstep_wood_001.ogg` | +7.4 dB | -34.0 | -12.3 |
|  | `step_wood_03.wav` | `kenney_impact_sounds/Audio/footstep_wood_002.ogg` | +5.4 dB | -34.0 | -14.9 |
|  | `step_wood_04.wav` | `kenney_impact_sounds/Audio/footstep_wood_003.ogg` | +14.4 dB | -33.9 | -13.2 |
| **step_tunnel** (work) | `step_tunnel_01.ogg` | `kenney_rpg_audio/Audio/footstep02.ogg` | copied | -22.1 | -1.2 |
|  | `step_tunnel_02.ogg` | `kenney_rpg_audio/Audio/footstep06.ogg` | copied | -21.9 | -0.3 |
|  | `step_tunnel_03.ogg` | `kenney_rpg_audio/Audio/footstep07.ogg` | copied | -21.2 | 0.0 |
|  | `step_tunnel_04.ogg` | `kenney_rpg_audio/Audio/footstep09.ogg` | copied | -24.1 | -6.1 |
| **step_wade** (water) | `step_wade_01.ogg` | `oga_water_splash_slime_sfx/splash_10.ogg` | copied | -22.8 | -0.5 |
|  | `step_wade_02.ogg` | `oga_water_splash_slime_sfx/splash_14.ogg` | copied | -21.8 | -1.7 |
|  | `step_wade_03.ogg` | `oga_water_splash_slime_sfx/splash_15.ogg` | copied | -21.0 | -1.3 |
| **splash** (water) | `splash_01.ogg` | `oga_water_splash_slime_sfx/splash_04.ogg` | copied | -16.9 | -1.0 |
|  | `splash_02.ogg` | `oga_water_splash_slime_sfx/splash_07.ogg` | copied | -18.9 | -1.0 |
|  | `splash_03.ogg` | `oga_water_splash_slime_sfx/splash_08.ogg` | copied | -15.5 | -0.5 |
| **water_in** (water) | `water_in_01.ogg` | `oga_water_splash_slime_sfx/splash_02.ogg` | copied | -21.0 | -1.9 |
|  | `water_in_02.ogg` | `oga_water_splash_slime_sfx/splash_13.ogg` | copied | -20.2 | -3.1 |
| **water_out** (water) | `water_out_01.ogg` | `oga_water_splash_slime_sfx/splash_12.ogg` | copied | -23.8 | -2.0 |
|  | `water_out_02.ogg` | `oga_water_splash_slime_sfx/splash_05.ogg` | copied | -23.1 | -2.2 |
| **amb_stream** (water) | `amb_stream_01.ogg` | `oga_30_cc0_sfx_loops/water_flowing.ogg` | copied | -31.3 | -23.9 |
| **amb_wind** (ambience) | `amb_wind_01.wav` | `oga_wind_whoosh_loop/download/wind woosh loop.ogg` | loop join cross-faded 500 ms | -28.2 | -17.3 |
| **amb_rain** (ambience) | `amb_rain_01.ogg` | `oga_rain_loopable/4.ogg` | copied | -30.5 | -9.7 |
| **warning** (cues) | `warning_01.ogg` | `kenney_interface_sounds/Audio/error_004.ogg` | copied | -20.7 | -2.8 |
| **complete** (cues) | `complete_01.ogg` | `kenney_interface_sounds/Audio/confirmation_001.ogg` | copied | -10.6 | -1.2 |
| **ui_click** (cues) | `ui_click_01.ogg` | `kenney_interface_sounds/Audio/tick_002.ogg` | copied | -31.4 | -9.2 |

## Loudness and first volumes

Each cue has a **target level** before its bus (`TARGET_LUFS` in the tool). The fall of a tree is the loudest
one-shot (-16). Chop and splash sit at -20, dig, saw and gnaw a little under, and loads under those. Footsteps
are a quiet -30, wood a little louder so the bridge reads. The warning is above the work (-18) and the
completion just under it (-20). The ambience is a bed at -26 to -30. `volume_db` is that target minus the cue's
mean level, rounded and clamped to the table's -60..+6. Variants were chosen, or levelled, to sit within about
4 LU of each other. The rule was within 3 LU, but Kenney's grass steps spread 4.4.

| Cue | Measured by | Mean (LUFS) | Spread (LU) | Target (LUFS) | `volume_db` | Lands at |
|---|---|---:|---:|---:|---:|---:|
| chop | loudest 400 ms | -26.1 | 0.6 | -20.0 | +6.0 | -20.1 |
| gnaw | loudest 400 ms | -28.5 | 2.3 | -24.0 | +4.0 | -24.5 |
| saw | loudest 400 ms | -23.6 | 1.0 | -23.0 | +1.0 | -22.6 |
| dig | loudest 400 ms | -19.8 | 0.1 | -22.0 | -2.0 | -21.8 |
| tree_fall | loudest 400 ms | -14.1 | 0.0 | -16.0 | -2.0 | -16.1 |
| pickup | loudest 400 ms | -34.3 | 3.9 | -28.0 | +6.0 | -28.3 |
| drop | loudest 400 ms | -17.4 | 1.6 | -24.0 | -7.0 | -24.4 |
| step_grass | loudest 400 ms | -35.0 | 4.4 | -30.0 | +5.0 | -30.0 |
| step_dirt | loudest 400 ms | -18.2 | 3.3 | -30.0 | -12.0 | -30.2 |
| step_wood | loudest 400 ms | -34.0 | 0.1 | -28.0 | +6.0 | -28.0 |
| step_tunnel | loudest 400 ms | -22.3 | 2.9 | -31.0 | -9.0 | -31.3 |
| step_wade | loudest 400 ms | -21.9 | 1.8 | -27.0 | -5.0 | -26.9 |
| splash | loudest 400 ms | -17.1 | 3.4 | -20.0 | -3.0 | -20.1 |
| water_in | loudest 400 ms | -20.6 | 0.8 | -24.0 | -3.0 | -23.6 |
| water_out | loudest 400 ms | -23.5 | 0.7 | -26.0 | -3.0 | -26.5 |
| amb_stream | integrated | -31.3 | 0.0 | -26.0 | +5.0 | -26.3 |
| amb_wind | integrated | -28.2 | 0.0 | -30.0 | -2.0 | -30.2 |
| amb_rain | integrated | -30.5 | 0.0 | -27.0 | +4.0 | -26.5 |
| warning | loudest 400 ms | -20.7 | 0.0 | -18.0 | +3.0 | -17.7 |
| complete | loudest 400 ms | -10.6 | 0.0 | -20.0 | -9.0 | -19.6 |
| ui_click | loudest 400 ms | -31.4 | 0.0 | -28.0 | +3.0 | -28.4 |

Three cues sit at the +6 dB ceiling (chop, pickup, step_wood). All three land within 0.4 LU of their target,
but `volume_db` cannot raise them further; to do that, raise the Work bus or add gain to their render, as gnaw
and the wood steps already have. No cue is more than 0.6 LU from its target.
These are levels before the buses (UI §8.1's defaults: Master 80, Ambience 60, Work 75, Water 60, Cues 70) and
before distance attenuation. The placed cues are also quieter by the listener's height over the focus.

## Loops

None of the three loops has silence at either end (under -50 dBFS for more than 10 ms). Their joins were
checked by comparing the jump from the last sample to the first against the file's ordinary sample-to-sample
steps:

| Loop | Length | Join jump | Ordinary step (median / 99th percentile) | Result |
|---|---:|---:|---|---|
| `amb_stream_01.ogg` (P4 `water_flowing.ogg`) | 1.88 s | 514 | 212 / 847 | clean; copied |
| `amb_rain_01.ogg` (P5 `4.ogg`) | 37.50 s | 105 | 157 / 755 | clean; copied |
| `wind woosh loop.ogg` (P8) as downloaded | 5.96 s | 1,140 | 36 / 141 | **a click at every join**: the file fades to about 0 in its last samples, but starts at -1,137 |
| `amb_wind_01.wav` after staging | 5.46 s | 75 | 36 / 141 | clean |

The wind was **trimmed**: its last 500 ms are cross-faded into its first 500 ms with equal-power fades, and then
dropped from the end. The loop is 0.5 s shorter, and its last frame now leads into its first as the recording
does. The WAV carries a `smpl` loop marker over every frame. Godot's import reads it ("Detect From WAV", the
default) and imports the file with `loop_mode` forward, 0 to 262,046, which was checked in the engine.

## What to listen for (Brendan)

- **The wind (P8) may be too "whooshy"**, as the sourcing plan warned. It is kept for now. Listen for it as a
  gusting whoosh rather than a breeze, and for any bump at its 5.5 s loop. The alternative to audition is
  OGA "Forest Ambience" (CC0, 716.7 KB), which is not downloaded.
- **The stream is a 1.9 s loop.** Listen for a repeating pattern when you stand by it. If you hear one, P7's
  `loop_water_02.ogg` (7 s, a clean join) is already in the library.
- **Chop**: the RPG pack's axe `chop` is mixed with four Impact `impactWood_heavy` knocks. Check that they
  sound like one action.
- **Gnaw** has no real gnawing: Impact's light wood knocks, raised 4 dB, stand in for it. This was a known gap.
- **Dig**: two cuts of one shovel recording, and one Impact pickaxe-on-stone (`impactMining_004`). The second
  shovel cut is raised 13 dB, so listen for hiss on it.
- **Saw**: three push-and-pull strokes cut from one 2.3 s loop. Listen for clipped starts.
- **Tree fall**: the tree's creak and crack, then the thud. The opening chop is cut off, because the chop cue
  has already played.
- **Pickup** (Kenney leather and cloth handling) is the softest work cue. Check that it is heard at all.
- **Warning**: Interface `error_004`, picked by measurement (100 ms, about 600 Hz, not noisy) as gentle but
  distinct. The alternatives are `bong_001` (a low bong, near 80 Hz, which may vanish on laptop speakers) and
  `error_007`.
- **UI click**: Interface `tick_002`, a 20 ms tick. Kenney's `click_00x` files are 7 ms and nearly silent
  (`click_004` peaks at -84 dBFS).
- **Steps**: the dirt and tunnel steps are two halves of RPG Audio's ten boot steps, on a surface the pack does
  not state, with the tunnel half quieter and muffled underground. Grass and wood are Impact's.

## What still has to happen

- Brendan's listen, and a tuning pass of `volume_db`, `range_m` and the bus defaults by ear.
- **Gaps still open**: a real gnaw, a load "lift" foley, and the farm, fishing, fixture and storm-gust cues
  (decision 0351, "Not done").
- **Staging needs macOS** for the rendered files: 18 of the 56 are rendered, and decoding them needs
  `afconvert`. On another system those are skipped and reported, and their variants play silent.
