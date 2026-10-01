# Demo sound pass — sourcing plan (phase 1: for approval, NOTHING downloaded)

> **Status, 2026-09-30 (phase 2).** Brendan approved P1–P8 and the optional Shovel Sound, and nothing else.
> All nine were downloaded and are in the audio library. What each cue actually plays, the measured levels and
> what changed from this plan are in [README.md](README.md) and decision 0351's "Phase 2". The plan below is
> kept as it was written, as the record of the research. Its target names (`chop_01..03.ogg`, `*_loop.ogg`)
> were superseded by `tools/stage_demo_audio.py`.

Decision 0351 (branch `feat/review-r-sound`). Every cue below is already wired in
`godot/demo/sound/sound_table.json` and plays silent until its file is dropped in at the target path
(`res://demo/assets/sound/<target>`, the gitignored staged-asset folder the Windows build already exports).
Drop-in is a copy/rename (or a path edit in the JSON): no code change.

Research was read-only (page fetches and searches; no downloads, no logins), 2026-09-30. "Verified" = the
licence was read on the page itself. Kenney file names come from the third-party mirror gamesounds.xyz
(Kenney's own pages do not list files without downloading) — check them against the zip when it is opened.

## Recommended packs (8 downloads, all CC0, no account needed)

| # | Pack | Source page | Licence as stated | Download (as stated) | Covers |
|---|---|---|---|---|---|
| P1 | Kenney "Impact Sounds" (130 files, 2019) | https://kenney.nl/assets/impact-sounds | "Creative Commons CC0" (verified) | kenney_impact-sounds.zip, size not stated | chop variants, drop, pickup, dig alt, step_grass, step_wood, complete alt |
| P2 | Kenney "RPG Audio" (50 files) | https://kenney.nl/assets/rpg-audio | "Creative Commons CC0" (verified) | size not stated | chop, step_dirt / step_tunnel |
| P3 | Kenney "Interface Sounds" (100 files) | https://kenney.nl/assets/interface-sounds | "Creative Commons CC0" (verified) | size not stated | ui_click, warning, complete |
| P4 | OpenGameArt "30 CC0 SFX loops" | https://opengameart.org/content/30-cc0-sfx-loops | "CC0" (verified) | 3.5 MB zip | saw (hand saw loop), amb_stream (flowing water loop) |
| P5 | OpenGameArt "Rain (loopable)" | https://opengameart.org/content/rain-loopable | "CC0" (verified) | Rain OGG.zip 2.7 MB | amb_rain (4 loops, 25–45 s) |
| P6 | OpenGameArt "tree chop fall thud" | https://opengameart.org/content/tree-chop-fall-thud | "CC0" (verified) | chop-tree-fall.ogg 194.8 KB | tree_fall |
| P7 | OpenGameArt "40 CC0 water / splash / slime SFX" | https://opengameart.org/content/40-cc0-water-splash-slime-sfx | "CC0" (verified) | 2.3 MB zip | splash, water_in, water_out, step_wade (15 splash files; 16 slime files unused) |
| P8 | OpenGameArt "wind whoosh loop" | https://opengameart.org/content/wind-whoosh-loop | "CC0" (verified) | wind woosh loop.ogg 251.6 KB | amb_wind (audition: may be too "whoosh") |

Confirmed sizes total about 9 MB plus the three Kenney packs (sizes not stated on their pages).

## Per cue

| Cue (target file) | First choice: file in pack | Second choice | Notes |
|---|---|---|---|
| chop (`chop_01..03.ogg`) | P2 `chop.ogg` + P1 `impactWood_medium_000..004.ogg` | P1 `impactWood_heavy_*` | RPG Audio has one chop; Impact adds variants |
| gnaw (`gnaw_01..02.ogg`) | P1 `impactWood_light_000..004.ogg` (fallback) | OGA "Tiny vicious creature" (CC0, 126.4 KB) — a creature vocal, probably wrong | **Gap**: no CC0 wood-gnawing found |
| saw (`saw_01..02.ogg`) | P4 the "hand saw" loop (file name not listed), cut into strokes | — | One saw recording only |
| dig (`dig_01..03.ogg`) | OGA "Shovel Sound" `shovel.ogg` (CC0, 21.9 KB, https://opengameart.org/content/shovel-sound) | P1 `impactMining_000..004.ogg` | Shovel is a 9th, tiny download; Mining needs none extra |
| tree_fall (`tree_fall_01.ogg`) | P6 `chop-tree-fall.ogg` (trim to the fall) | P2 `creak1..3.ogg` + P1 `impactWood_heavy_*` layered | |
| pickup (`pickup_01..02.ogg`) | P1 `impactSoft_*` (audition) | P2 cloth/leather files (names not itemised) | **Soft gap**: no clean CC0 "lift" foley; OGA "Pickup/plastic" is CC-BY 3.0, excluded |
| drop (`drop_01..02.ogg`) | P1 `impactPlank_medium_000..004.ogg` | P1 `impactWood_heavy_*` | |
| step_grass (`step_grass_01..03.ogg`) | P1 `footstep_grass_000..004.ogg` | — | |
| step_dirt (`step_dirt_01..03.ogg`) | P2 `footstep00..09.ogg` (surface unstated; audition) | OGA "Different steps on wood, stone, leaves, gravel and mud" (CC0, 77.7 KB) — mud | |
| step_wood (`step_wood_01..03.ogg`) | P1 `footstep_wood_000..004.ogg` | the OGA steps pack's wood | |
| step_tunnel (`step_tunnel_01..02.ogg`) | same files as step_dirt (the Work Under bus muffles it) | the OGA steps pack's mud | |
| step_wade (`step_wade_01..02.ogg`) | P7 small splash files (names not listed) | OGA "Water Splash and sand footsteps" (CC0) `splash2.wav` 150.6 KB | |
| splash (`splash_01..02.ogg`) | P7 large splash files | OGA "Water Splash and sand footsteps" `splash1.wav` 225.4 KB | |
| water_in (`water_in_01.ogg`) | P7 a light splash | the same OGA page's `splash2.wav` | |
| water_out (`water_out_01.ogg`) | P7 a drip/light splash | — | |
| amb_stream (`amb_stream_loop.ogg`) | P4 "flowing water" loop (up to 8 s: check the loop point) | P7's water loops | |
| amb_wind (`amb_wind_loop.ogg`) | P8 `wind woosh loop.ogg` | OGA "Forest Ambience" (CC0, 716.7 KB MP3, "loops seamlessly"; wind content unverified) | Audition both |
| amb_rain (`amb_rain_loop.ogg`) | P5 one of the four OGG loops | OGA "AMB Rain Loop 2" (CC0, amb_rain2.ogg 19 MB — large) | |
| warning (`warning_01.ogg`) | P3 `error_001..008.ogg` or `bong_001.ogg` (audition: "gentle but distinct") | OGA "Alert/Notification Sound" (CC0) `alert.wav` 197.2 KB | |
| complete (`complete_01.ogg`) | P3 `confirmation_001..004.ogg` | P1 `impactBell_heavy_*` | OGA "Completion sound." shows both OGA-BY 3.0 and CC0 badges — excluded as ambiguous |
| ui_click (`ui_click_01.ogg`) | P3 `click_001..005.ogg` | Kenney "UI Audio" (CC0, 50 files, names unverified) | Pick one of Interface Sounds / UI Audio, not both |

## Excluded sources

- **Sonniss GDC Game Audio Bundle**: not CC0. https://sonniss.com/gdc-bundle-license/ says the licensee "may not
  distribute, publish, sub-license or otherwise supply the sound effects as sound effects to any other person"
  without permission. It is royalty-free for use inside a game, but not CC0-compatible, so it is left out.
- **Freesound.org**: needs an account to download. Not needed: every cue is covered above.
- **OGA "Pickup/plastic Sound"**: CC-BY 3.0 (attribution required). **OGA "Completion sound."**: mixed badges.
- **Kenney "Foley Sounds"** (older pack): no longer listed on kenney.nl; only third-party mirrors found.

## Approval needed per download (Brendan)

P1, P2, P3 (Kenney zips, sizes not stated), P4 (3.5 MB), P5 (2.7 MB, the OGG zip only), P6 (194.8 KB),
P7 (2.3 MB), P8 (251.6 KB), and optionally OGA "Shovel Sound" (21.9 KB). After the downloads: audition and
trim, convert to Ogg Vorbis, stage at the target names, and record provenance and licences in the repository.
