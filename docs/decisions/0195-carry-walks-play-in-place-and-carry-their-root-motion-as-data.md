# 0195 — Carry walks play in place, and carry their root motion as data
Date: 2026-09-27 · Status: Accepted

## Decision

`tools/ground_meshy_clips.py` now also **extracts root motion**. For any clip whose hips travel
more than 1 cm over its loop, it takes the travel out of the hips, keeping each stride's own sway,
and records what it took on the Hips bone's glTF extras. Godot imports those as bone metadata:

```
root_motion = {period_s, travel_m: [x, z], mean_speed_m_s, window_s, keys_xz: [[x, z] per key]}
```

The clips in `grounded/` therefore all play in place. That is crowd §9.1's in-place root
convention: the fixed-tick simulation owns movement (crowd §1383), and animation never decides
where a creature is.

The new `godot/scripts/presentation/clip_root_motion.gd` reads the entry back, and gives the
playback rate at which a clip's strides match the speed the simulation moves the creature:
`playback_rate(motion, ground_speed) = ground_speed / mean_speed`.

## Which clips, and what they do

Exactly 20 of 100 clips travel: the two carry walks, on all ten rigged creatures. Every other clip
moves less than 6.2 mm, which is Meshy's own loop gap. The travel is straight forward (+Z).

- **`carry_heavy_object_walk` is steady locomotion.** It covers 0.8–3.2 m in 6.5 s (0.12–0.49 m/s),
  and its speed varies with each stride.
- **`carry_water_bucket_walk` is an action with travel.** It steps back about 20 cm, stands, walks
  about 2.3 m (badger), steps back and stands. Its hips stray up to 75 cm from a constant-speed
  line, so subtracting a constant velocity would leave the creature drifting that far around its
  spot.

## How the root is taken out

The root is the hips' horizontal path averaged over **one gait cycle** (`ROOT_WINDOW_S = 1.0` s;
Meshy's in-place walk loops in 1.03 s). The average is centred and symmetric (31 keys at 30 Hz).
It runs past the clip's ends as the loop would continue: one loop further on, the pose is the same
one moved by the whole travel.

The root is taken relative to the first key, so it starts at 0 and ends at the travel. The hips
then close their loop, and a stride's sway, which the average does not contain, stays in the clip.

It is applied in the same single rewrite of the Hips translation as the lift. The lift is vertical
and the root horizontal, and the world direction is converted into the Hips parent's space. The
output is read back, and refused if the hips still travel more than 1 cm.

## Why this was needed: a live spring whips at the loop

A clip that travels snaps its hips back to the start at every loop. The skeletal pool's live tail
spring (decision 0194) sees that as a 1–3 m teleport.

Measured live (Godot 4.7.2, `TailRig`, 60 Hz, three loops of `carry_heavy_object_walk`), as the
largest one-frame tail-joint turn:

| creature | root motion left in | in place |
|---|---|---|
| mouse fieldworker | 121.6° | 27.2° |
| otter boatwright | 169.0° | 6.2° |
| squirrel gatherer | 122.5° | 3.2° |

The crowd bake handled this with a special case. At the wrap it moved the creature forward by the
loop's travel (0192). That special case is gone. The bake now **moves the creature along the
recorded root path**, key by key, adding the whole travel at each loop, so the baked tail still
feels the body walk on.

## Evidence

- **The library:**
  - 20 clips extracted;
  - every clip's hips now close their loop to within 6.2 mm (Meshy's own in-place clips close to
    6.2 mm);
  - the lifts are unchanged (the largest is still 0.371 m).
- **Re-bake:**
  - verdicts identical to decision 0194 (1 tail 5.4 mm under, 1 flick, 2 clips burying their tail
    base);
  - worst clearance shortfall 0.06 mm;
  - the carry walks' seams are 1–12° and their largest steps 12–43°.
- `tools/test_ground_meshy_clips.py`: **35 checks**. The new fixture is a 63-key walk at 0.5 m/s
  with a sideways-and-forward sway whose period is exactly the averaging window, starting
  mid-stride. The sway's average is then exactly 0, so the expected root, the kept sway and the
  recorded path are literals. The tests cover:
  - the clip closes;
  - the sway stays;
  - the travel, period and speed are recorded;
  - an in-place clip gets nothing;
  - no height changes;
  - a clip left travelling is refused.
- **Mutants, 9 of 9 killed:**
  - never extract;
  - clamp the ends instead of continuing the loop;
  - use a lopsided window;
  - add the root instead of removing it;
  - swap x and z;
  - take the root from the hips' first position;
  - drop the loop-gap check;
  - don't record;
  - extract every clip.

  Two survived at first. A sway starting at 0 hid the first-key offset, so the sway now starts
  mid-stride. The loop-gap check only fires on a wrong extraction, so a test now sabotages it.
- `godot/test/test_clip_root_motion.gd`: 4 tests. Godot 4.7.2 imports the entry as bone metadata
  (checked on the otter boatwright: 196 keys, 0.224 m/s).

## Not done here

- **Using it.** The skeletal pool and crowd presentation must move each creature where the
  simulation says, and play travelling clips at `playback_rate()`.
- **`carry_water_bucket_walk` is not a loop of steady locomotion.** Played at its mean speed, its
  step-back and standing phases will still slide against a constant-speed creature. A real
  bucket-carry cycle should be cut from its walking middle, or authored.
