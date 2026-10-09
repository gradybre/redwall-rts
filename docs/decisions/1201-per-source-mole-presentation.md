# 1201 — Per-source mole presentation: one Content and one Actor per profile source image

Date: 2026-10-06 · Status: Accepted

## Decision

ADR 1198 step 7, and the presentation half of ADR 1197 G8. The mole presentation can now draw rows
whose Profile source is not the actor image. No published content, profile row, `ACTOR_SHA`,
`MAX_CLIPS` or pinned consumer script changes.

| Piece | Where | What it does |
|---|---|---|
| Content set | `godot/demo/cast/underground_content_set.gd` | Up to three immutable `Content`s, one per source index, inside one declared byte budget. Each load is exact-sha pinned and carries one part mask per clip. |
| Mole presenter | `godot/data/underground/mole-worker/mole_presentation.gd` | The mole pin table (`load_sources`), one Actor per loaded source, source selection, mask application, and the row-29 handling mode. |
| Session reservation | `godot/scripts/core/underground_session.gd` | Paths, digests and byte counts for the handling and haul images, plus `PRESENTATION_SET_BYTES`. |
| Demo | `godot/demo/demo_village.gd` | Boot loads the actor and handling images through the set and mounts the Session with source 0. |

### Sources

| Index | Image | SHA-256 | Clips | Masks | Reservation (B) |
|---|---|---|---|---|---|
| 0 | `install-program-compile-v3/result/mole-worker.ugactor` | `adc61764…` (`Pins.ACTOR_SHA`) | 14 | all 3 | 7,141,920 |
| 1 | `qualified-assembly-v1/compiled-3/mole-worker.ugactor` | `b94d676e…` (`Assembly.ACTOR_SHA`) | 3 | all 3 | 6,628,488 |
| 2 (optional) | `haul-handling-v1/evidence/native-program-v8/compiled/haul-handling.ugactor` | `cc854271…` | 12 | `[3,3,3,3,3,3,3,3,1,1,3,3]` | 7,486,168 |

Each reservation is that image's exact `Content.required_peak_bytes()`: the retained palette, plus
the larger of a second palette copy or the 17,172-vertex mesh pass, plus the tables and the 2 MiB
control reserve. **`PRESENTATION_SET_BYTES` = 21,256,576** is their plain sum. Nothing is shared or
discounted, so it is an admitted upper bound, not a measurement. The retained palettes alone are
647,752 + 134,848 + 992,096 = 1,774,696 B. Without the haul image, the demo admits 13,770,408 B.
This is presentation memory. It is not inside the simulation's 100 MB gate (REQ-SET-163), and no
native measurement was made.

### Selection rules

- **Which Actor shows.** It is the source whose image digest equals the row's own Profile source
  digest (`Content.profile_matches`, via `ContentSet.source_for_row`). A frame whose
  `source_digest` differs from that image is refused.
- **Masks.** Every shown frame applies its clip's mask (`set_parts_visible`). The clip comes from
  the absolute frame index, using spans derived from the Content's own clip reader. A frame equation
  that blends clips with different masks is refused (`MOLE_PRESENTATION_CLIP_MASK`). No current
  program blends across a mask change, because the haul joins are authored clips.
- **Hidden Actors.** Other Actors get mask 0 and are never posed while hidden, so their last pose
  is stable. Every check runs before the first visible change, so a refusal changes nothing.
- **Row 29.** `handling_frame_into` reads the actual Routes owner: `read_actor_into` gives the
  profile tuple, Job, point and yaw, and `source_state_leaf_into` gives the handling phase and time.
  The existing `handling_clock.source_into` maps them onto the assembly image: entry is clip 0,
  recovery is clip 2, and HANDLED_READY is clip 2's last frame. The presenter never advances the
  clock. Load refuses unless clips 0 and 2 are clamped and exactly `SOURCE_INTERVALS` long.
- **Haul.** `present_clip(SOURCE_HAUL, clip, time)` and the `HAUL_*` clip ordinals are the whole
  haul mapping. While the haul image is absent, it refuses with `MOLE_PRESENTATION_SOURCE_ABSENT`
  and leaves the shown Actor unchanged. Haul *program modes* (load, CARRY, unload, tool-free
  walk/stand) are not built. They need content-5 rows and a source clock that do not exist yet.

## Why

- **A set instead of a recompiled image.** ADR 1198 chose this so that `MAX_CLIPS` and
  `ACTOR_SHA` stay fixed. Each image keeps its own proofs and native replay.
- **A new presenter instead of editing `mole_profile_driver.gd`.** The driver is one of the ten
  pinned consumers, and another agent is renewing pins for content 5 at the same time. The
  presenter consumes the driver's `Frame` unchanged, so source-0 rows keep using the driver and
  row 29 adds a mode beside it.
- **Masks are a load-time table.** The `.ugactor` wire has no per-clip part presence (ADR 1198,
  step 4a), so the mask must travel with the pinned digest.

## Superseded in part (ADR 1211)

- `ContentSet.MAX_SOURCES` is now **4**: the native stone image v9 is source 3 (rows 37–41).
  `PRESENTATION_SET_BYTES` is now **28,541,580** B, the plain sum of four exact peaks (stone 7,285,004). The
  three-source figures below are this ADR's history.
- The live demo loads all four images and composes the worker Actors (`entry_worker_view.gd`).
- Rows 30–41 are drawn by `present_row`'s row program. The "Haul program modes are not built" paragraph below no
  longer holds: they are built presentation-side, on the settlement's fixed tick, because no simulation haul source
  clock exists.

## Not covered

- No mole Actor is drawn in the live demo yet. Nothing composes a worker presentation for the
  foreman's crew. The demo loads and validates the images, and the presenter is the seam for that
  hookup. Its tests use recording Actors over the real shared Palette, because headless runs cannot
  configure a native Actor.
- The haul image path points at the v8 evidence directory. When content 5 stages a runtime copy,
  only `HAUL_ACTOR_PATH` should change; the digest stays the same.
- No native census of the joint images.

## Tests

`godot/test/test_mole_presentation.gd`, 7 tests:

- pinned loads and the exact reservation;
- contiguous clip spans;
- refusals: wrong sha, more than 16 clips, mask-table size, invalid mask, the exact-peak reserve,
  budget, duplicate digest and an occupied slot;
- haul masks for every clip, with a stable hidden pose;
- an absent haul source;
- selection of rows 0 and 29 by source digest against the actual published catalog;
- the actual paid L0 handling cycle: READY, 30 entry ticks, 30 recovery ticks and HANDLED_READY,
  each frame checked against the clock equation.
