# Curled pick paw: human review packet (ADR 1216 step 1)

This packet is for **Brendan's review of the paw shape only**. Nothing is baked, presented or proved yet. After
approval come the palette re-bake (`mole-grip-v4.ugpal`), the per-source presentation, the GDScript port of the
deformation, the successor grip exclusion and exact grip proof, and native capture.

## What was authored (`../author_curled_paw.py`, record `../curled-paw-v1/paw.json`)

**Starting mesh.** The authoring starts from the paw *before* the accepted closing. That closing is exactly
invertible per vertex (round-trip error 0.0 m), so the original paw is recovered from the accepted proofs' mesh.
The deformation acts only on right-hand-weighted vertices, in proportion to their weight, as the accepted one does:

1. **Thin the fingers.** This reuses the accepted closing's own profile: a smoothstep from 0.025 m over 0.105 m
   along the fingers, with 70% narrowing. It narrows **thickness only**, toward the paw's mid-plane. The fingers
   stay side by side so they can lie along the shaft. Thinned finger thickness: 0.044 m.
2. **Rest the shaft on the palm.** The palm is the smooth +Z face; the back of the paw is furred.
   - The shaft runs across the paw at `lateral-1`'s height (hand-local y = 0.078 m, the accepted socket's).
   - Its surface lies on the thinned palm (z = 0.042 m); its axis is at z = 0.070 m.
   - Its radius, 0.028 m, is the pick shaft's own.
   - The pick fit follows: `lateral-1` moved onto the palm, "lateral-2".
3. **Curl.** Beyond the shaft line, each finger cross-section turns about the shaft axis toward the palm by its arc
   length over the neutral radius (0.050 m = shaft radius + half finger thickness). So the claws wrap as far as
   their own length reaches: **about 101°** at the tips. 841 vertices move.

**Float witnesses:**
- paw vertices within one shaft radius of the shaft's surface: 66;
- their angular cover around the shaft: 105°;
- paw vertices inside the shaft: 8.

The exact grip proof comes after approval.

## Images (one zoom per sheet)

| Image | Rows | Views |
|---|---|---|
| `grip.png` | the accepted closed paw with the accepted fit, then the curled paw with the lateral-2 fit | the ready carry from the front, the right side (paw toward the camera) and the top, at ×1.6 |
| `paw-alone.png` | the accepted closed paw, then the curled paw | the paw in its own frame from the palm, the side and the fingertips, at ×1.8; the shaft is drawn as an orange outline |

Digests are in `images.json`. These are painter renders of the authored shape, not native captures.

## What to judge

1. **Do the claws read as wrapped around the shaft?** In the side view the claws arch over and around it.
2. **Is ~101° of curl enough?** The mole's fingers are short against its paw, so their own length stops the curl
   there. A tighter wrap would need longer bends than the fingers have, which means stretching the mesh.
3. **Is the shaft's place on the palm, across the finger base, right?**

## Reproduce

```sh
$PY .../author_curled_paw.py <fresh-dir>
$PY .../render_curled_paw.py <paw-dir> <fresh-dir>
$PY .../test_curled_paw.py
```

The demo assets were staged from the frozen `redwall-rts-codex-ug-space` worktree, checked against their pins, and
removed afterwards. `test_curled_paw.py` (4 tests) needs only committed files.

## Verdict (2026-10-07)

Brendan **approved the shape**. See ADR 1216 for the steps that follow.
