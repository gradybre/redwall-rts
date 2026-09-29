# 0201 — Meshy's idles are untwisted to the walk's heading, with the feet pinned
Date: 2026-09-29 · Status: Accepted

## The defect

Brendan, watching the live demo: *"when still the squirrel gatherer kind of spins in this odd half
circle"*. The demo's yaw was constant (0.0000 change over 4 s). The cause is Meshy's own `anim_idle`,
the same in the raw file and in `repaired/`, `tailed/` and `grounded/`, **on all ten rigged creatures**.

Measured from the files (`hips_headings`: the twist about the vertical of the Hips' world rotation
away from its rest; the T-pose faces +Z, so 0 is +Z):

| creature | idle heading mean | min | max | swing | feet slide | walk heading mean |
|---|---:|---:|---:|---:|---:|---:|
| badger_cellarer | −40.0 | −78.8 | +7.7 | 86.5 | 0.124 m | +1.9 |
| badger_quarryman | −40.0 | −79.2 | +7.7 | 86.9 | 0.151 m | +1.7 |
| mole_digger | −42.9 | −74.8 | −2.3 | 72.5 | 0.076 m | +1.3 |
| mole_mason | −41.4 | −75.6 | +1.6 | 77.2 | 0.061 m | +1.8 |
| mouse_fieldworker | −39.7 | −79.0 | +8.6 | 87.6 | 0.010 m | +1.9 |
| mouse_keeper | −40.2 | −79.0 | +8.3 | 87.3 | 0.038 m | +1.8 |
| otter_boatwright | −39.4 | −78.6 | +9.6 | 88.1 | 0.116 m | +1.8 |
| otter_fisher | −39.0 | −80.2 | +10.5 | 90.7 | 0.010 m | +2.0 |
| squirrel_forester | −41.9 | −78.3 | +2.6 | 80.9 | 0.204 m | +1.3 |
| squirrel_gatherer | −39.4 | −80.5 | +11.2 | 91.7 | 0.279 m | +0.8 |

(Godot 4.7.2, playing the grounded files through its own import at 30 Hz; the Python measure of the
same files agrees to 0.1°. Feet slide is the furthest either foot joint moves across the ground from
where it stands on the first key.)

- The idle **stands turned −43°** from the walk. The feet stand on a line rotated about −60 to −67°.
- From about 0.6 s the hips turn to about +8° with the head at +80 to +100°. Then they turn to about −79°
  with the head at −120 to −137°. By 3.4 s they are back at −43°. The body swings through 72–92°.
- **The head faces +Z on the first key while the body is turned.** Meshy's idle looks at the viewer.
- On the larger creatures the feet shuffle round with the turn: 6–28 cm. On the mice and the fisher they
  stay put (1–4 cm) and the legs twist.
- Every walk → idle blend turns the body about 50° (measured in Godot, 0.3 s crossfade).

No other clip swings like this. Across all 100 clips, the widest swing outside the idles is 31.9°
(`carry_water_bucket_walk`, a travelling clip). The widest in an in-place clip is 28.7° (a run's
stride). No clip turns for good: every clip ends within 0.3° of the heading it started at.

## Decision

`tools/ground_meshy_clips.py` gains an **untwist** step. It runs before the lift and the seat, in the
same tool and the same `grounded/` output, and is recorded in the output's stamp and in
[`grounded.json`](../art-reference/asset_library/grounded.json).

It applies to an **in-place** clip (no root motion, decision 0195) whose Hips heading **swings more than
`TWIST_SWING_DEG = 45°`** and **ends within `TWIST_NET_DEG = 10°` of where it began**. Today that is exactly
the ten idles. Such a clip is rewritten so that:

1. **The Hips face `FORWARD_DEG = 0` (+Z) on every key.** Each key's Hips world rotation is turned about
   the vertical by exactly its own heading. The swing–twist split means a tilt or a lean is kept, in
   the new facing. **Everything above the hips** (spine, arms, neck, head, tail) keeps its local keys,
   so breathing, arm and head motion survive.
2. **The feet are pinned.** Each foot keeps the position and rotation it has on the first key, turned
   with the whole creature to the new heading. The thigh and shin are re-solved every key by two-bone
   IK. The knee bends in the first key's plane, and each bone is the first key's, swung the least way
   onto its new direction.
3. **The hips stand over the rest pose's hips.** That is where the walk's hips are, to within 1–4 cm.
   Meshy's idle stands up to 26 cm to one side (the squirrel gatherer). The hips keep the clip's own
   height, lowered only where a leg would otherwise be **straighter than the clip ever holds it**
   (capped at 0.99 of its length). The largest drop is 4.3 cm (squirrel gatherer), then 2.9 cm
   (squirrel forester) and 2.7 cm (otter boatwright). Three creatures need less than 1 cm, and four need
   none.
4. **The head gets one constant twist.** It is chosen so that on the first key the head too faces +Z.
   It is applied in the neck's frame, so it is exactly a turn about the vertical on that key and moves
   with the neck afterwards. The look-around is kept relative to that: the head still glances about
   50° one way and 100° the other, with the body still (per creature; these are the mouse keeper's).

The grounding that follows (0193, 0197) is unchanged. The untwisted idles stand on pinned feet, so the
lift or seat is the same on every key.

## Why these choices

- **Why the pipeline, not the demo.** This follows decisions 0190–0197. It is a defect in Meshy's
  output. The crowd bake plays the same files, and a presentation-side fix would leave every other
  consumer spinning.
- **Why in `ground_meshy_clips.py`, not a fifth tool.** The step has to come before grounding, because
  pinning the feet changes their heights. It shares grounding's Hips rewrite, its in-place test (root
  motion) and its read-back checks. It belongs with 0195's root-motion extraction: grounding is where a
  clip is made to *play in place*. After 0195 that meant not travelling; now it also means not turning.
  The documented chain stays four commands.
- **Why 45° and 10°.** The idles swing 72.5–91.7°. Everything else swings at most 31.9°. 45° sits near
  the geometric middle of that gap (√(31.9 × 72.5) ≈ 48), and leaves a margin of more than 1.4× on
  both sides. The 10° net-turn limit leaves alone a clip that **turns on purpose**, such as a future
  turn-in-place or look-behind. Every current clip ends within 0.3° of its start. A travelling clip is
  never untwisted: its heading follows its path.
- **Why +Z, not the walk's own mean heading.** The walk's hips yaw ±3–7° with the stride around a mean
  of +0.8° to +2.0°. +Z is the rest pose's facing and the direction every travelling clip moves (0195).
  The 1–2° between them is invisible, and a constant keeps each clip independent of the others.
- **Why pin the feet, not let them follow the hips.** Two options failed when measured:
  - Turning the Hips alone takes the legs with them. On the mice, whose feet stand still while the
    body twists, that sweeps the feet round on 10–20 cm arcs.
  - Keeping Meshy's own foot paths keeps the 20–28 cm shuffle on the squirrels, which reads as
    stepping without turning.

  Pinned feet slide 0 by construction. Measured in Godot, they move at most 2.0 mm, which is Godot's
  interpolation between keys. That is well inside the 6.2 mm Meshy in-place loop gap (0195).
- **Why hold the hips horizontally, and lower them only where needed.** Keeping Meshy's horizontal hips
  path with pinned feet left the squirrel gatherer's legs needing 1.52× their length. That path is the
  body walking round with the turn, not weight shift. Keeping the hips' offset from the feet centre
  still needed 1.17×, because the feet step independently. Holding the hips over the rest hips needs
  at most 1.06×, and the height-only drop covers that.
- **Why fix the gaze.** Meshy's idle looks at the viewer with the body turned 43°. Turning the body
  alone leaves the creature looking 32–47° off to its left at rest (per creature, `gaze_deg` in the
  manifest).

**The fallback was not needed.** The fallback was to loop the calm stretch (≈3.4 s → wrap → 0.6 s),
turned to the walk's heading. Every creature took the untwist; none refused.

## What the tool refuses, and checks

It refuses, for its own reason each time, a swinging clip that:
- has no `Head` above the Hips;
- is missing an `UpLeg`/`Leg`/`Foot` chain on either side;
- has a leg bone that changes length;
- has a pinned foot beyond its leg's horizontal reach;
- has a leg dead straight on the first key, so its knee has no direction.

It also refuses any clip whose Hips key is upside down, because its heading is undefined.

On the result it checks three things, each of which only it can see:
- **In memory, before the lift:** every foot is on its pin in all three axes on every key.
- **Read back from the written file:** the Hips face `FORWARD_DEG` within 0.1° on every key, and no
  foot moves more than 1 mm across the ground.

## Stamp and manifest

The grounding stamp **keeps `version: 3`**. An untwisted clip carries
`untwisted: {turned_deg, gaze_deg, hips_drop_max_m, decision: "0201"}` in it. This was deliberate:
- A clip the untwist leaves alone is byte-identical to its 0197 output.
- So `grounded.json` and `baked.json` show exactly which files changed.

Every manifest row gains `heading_swing_deg`, `heading_net_deg` and `untwisted`. Untwisted rows also
record `turned_deg`, `gaze_deg`, `hips_drop_max_m`, `feet_slide_before_m`, `feet_slide_after_m` and
`heading_off_after_deg`. The manifest header records the three thresholds.

## Evidence

- **The library, regenerated in order** (repair → tail → ground → bake, `--library` explicit):
  - `repaired.json` and `tailed.json` are byte-identical to master.
  - `grounded.json`: exactly **10 output hashes changed, all `anim_idle`**. The other 90 are identical,
    and their rows differ only by the three new fields.
  - Untwisted idles: turned +42.9° to +47.7°, gaze −32.0° to −47.3°, feet slide 0.010–0.279 m → 0.000 m,
    loop gap up to 6.1 mm → 0.
  - `baked.json`: **6 hashes changed, all `anim_idle`**; the other 54 are identical. **Every verdict is
    unchanged**: 0 tails below the ground; 1 flick (otter fisher `collect_object`, pre-existing); 2 clips
    burying the feet or tail base (mouse keeper `chair_sit_idle`, squirrel forester `collect_object`,
    pre-existing); worst clearance shortfall 0.03 mm, as before.
  - The idles' tails whip less: the largest one-frame tail step fell from 31.4° to 8.4° (fieldworker),
    28.7° to 20.2° (keeper), 10.3° to 7.1° (fisher) and 6.2° to 2.4° (boatwright).
- **Godot 4.7.2**, every creature's regenerated grounded idle through Godot's own glTF import and
  `AnimationPlayer`, sampled every 1/30 s across the loop:

  | | Hips heading range | feet slide (worst foot) |
  |---|---:|---:|
  | before | 72.5–91.7° | 0.010–0.279 m |
  | after | **0.00°** on all ten (mean 0.00) | **0.3–2.0 mm** |

  Idle → walk → idle with 0.3 s crossfades, as the skeletal pool would play them: the walk → idle blend
  turned the body 45.9–53.4° before, and **2.3–8.3°** after. What remains is the walk's own stride yaw
  at the moment the blend starts. The whole sequence stays within the walk's own range, −5.5° to +8.6°.
- **Contact sheets** (`docs/art-reference/asset_library/contact_sheets/idle_untwist_<key>.png`): master
  on the left and untwisted on the right, at ten times across the loop, from above and from the front,
  with a ground arrow pointing along the walk. Sheets exist for the squirrel gatherer, mouse keeper,
  otter boatwright and badger cellarer. They were looked at:
  - The untwisted creature faces the arrow throughout.
  - Its feet stay planted.
  - Its head glances left and right.
  - Its knees take the otter's and squirrels' hip drop.

  Scripts: `viewer/measure_idle.gd`, `viewer/blend_idle.gd`, `viewer/shots_idle.gd`.
- **`tools/test_ground_meshy_clips.py`: 95 checks (47 before).** The new biped fixture is literal:
  - Two three-bone legs with the knees 5 cm forward.
  - The clip stands 0.2 m aside and yaws the hips −40/−40/+10/−80/−40° with a 5° pitch on two keys.
  - The head looks ahead on key 0 with the body turned, as Meshy's does.

  The tests cover:
  - the Hips face 0° on every key and keep the pitch;
  - they stand over the rest hips;
  - the feet sit at (±0.1, 0.02, 0) on every key, where the source slid 0.1087 m (computed by hand);
  - the knees stay forward;
  - the head's look-around is kept less the 40° gaze fix (0, 0, +40, −40, 0);
  - with a 20°-pitched spine, the head's key 0 is the source's turned exactly about the vertical;
  - the spine's channel is untouched;
  - the clip loops;
  - a 3 cm rise is taken out by exactly a 3 cm hip drop, and a 5 cm crouch bends the knees on pinned feet;
  - 44.8° is left alone and 45.2° is untwisted; a net turn of 10.2° is left alone and 9.8° is untwisted;
  - a travelling clip swinging 90° is left alone;
  - the stamp records the untwist only where one happened;
  - N07 covers every refusal, each matched on its reason;
  - three sabotages each reach the one check that can see them: hips written high (the 3-D pin
    check), the untwist skipped (heading), a foot shoved after it (slide).
- **Mutants: 33 of 33 killed** (`python3 -B`, a fresh copy of `tools/` per mutant): never untwist;
  threshold 30° and 60°; ignore the net turn; net limit 20°; untwist travelling clips; turn by the first
  key only; keep the stance heading; drop the hips' tilt; no gaze fix; gaze fix not conjugated into the
  neck frame; gaze fix of the wrong sign; pins following each key's feet; knee bending backwards; shin
  and thigh swings reversed; no hip drop; a drop that raises; a drop ignoring the horizontal; no reach
  cap; cap by `max`; no leg-length check; stand at the first key; no unwrap; no quaternion sign
  continuity; no upside-down refusal; no pin check; no heading check; no slide check; no stamp record;
  Head not required; no straight-leg refusal; no reach refusal.

  Six survived at first, and each was killed by a test that should have existed:
  - the pin check and the heading and slide checks, which fire only on a broken untwist: the three
    targeted sabotages;
  - the swings reversed: the fixture's legs never moved from rest, so the crouch test was added;
  - quaternion continuity: the first test pair never crossed a branch of the matrix conversion; −150° → −100° does.

  A seventh, "feet follow the source", was written wrong: it changed nothing. It was replaced by
  "pins follow each key's feet", which is killed.

## Not done here

- **The demo still plays the old files** until its assets are restaged. That is left to the lead.
- **Other clips' feet still slide** (walk, run and the carry walks do so by nature, and the kneels as
  0193 records). Only the idle's feet are pinned.
- **The look-around remains.** The head still turns about 100° one way and 50° the other, with the body
  still. If that reads as too much, the neck's share of the twist can be scaled down later in this step.
- **Other stances Meshy may hold turned.** A new in-place clip that swings less than 45° but stands
  turned at a constant angle is not corrected. None of today's other 90 clips stands more than about 9° off (squirrel forester `collect_object`).
