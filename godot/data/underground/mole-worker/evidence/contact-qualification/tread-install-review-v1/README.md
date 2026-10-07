# Tread installation tap: human review packet (ADR 1209 step 4)

This packet is for **Brendan's review** of the new short-reach fitting motion that installs tread T_k from the tread
above it. Nothing after it has been authored: no handling program, native capture, integer rows, content 7 or
Frontier rows. Those wait for this review.

## Why a new motion

The accepted fitting tap (`install-source-v4`, profile 16) touches the bearer workpiece 448 u ahead of a station
on L0. A tread is only 512 u deep, so that station would leave the worker's feet hanging off the tread behind it
(ADR 1209).

## What is fixed (derived, not chosen)

- **The workpiece.** T_k's left bearer is quarter-turned exactly as T0's part 8 is, and laid across the forward top
  edge of T_{k−1}. In station-local coordinates it is `[-256,0,-310, 256,128,-182]`, and its top (y = 128) is the
  contact plane, as in v4.
- **The station.** On T_{k−1}, at x = 0, yaw 0, 310 u behind its far edge. Below y = 128 the ready body reaches
  z = −168.3. Between y = 64 and 128 it reaches z = +188.4, the band where the deck behind sits. So the station must
  be 297–323 u behind the edge. 310 is the midpoint: 13.7 u from the workpiece and 13.6 u from the riser.
- **One fixture covers every tread, T1…T6.** It holds the support deck, the deck behind and side boxes. The side
  boxes are supersets that contain each tread's bearers and posts, and L0's or any tread's.

## The finding that shapes the pose

Standing upright, no recipe works. The probe (`../tread-install-v1/probe.json`) tried handle leans of 25–60° and
azimuths of 0–60° at 246–278 u ahead:

| Result | Count |
|---|---:|
| Shaft through the right forearm or upper arm (self-clearance fails) | 70 |
| Pick head through the bearer (escapes the workpiece) | 2 |
| No arm solution | 8 |
| Clear | 0 |

Pitching the torso forward made it worse: the snout meets the handle. With the **upper body pitched back 20–35°**
about Spine02, clear recipes exist: 20 of 36. The lower body stays the planted ready source, bit for bit.

## The candidates

All three pass the accepted v4 proofs, unchanged (`../tread-install-v1/candidate-v*/proof.json`):

- the exact adze crossing patch lies inside the workpiece's top;
- the tool below the plane stays inside the workpiece;
- continuous body self-clearance holds over the work, entry and recovery clips;
- the complete world proof holds against all seven prisms, with full-foot support and sole contacts only.

| Candidate | Torso | Handle lean, azimuth | Contact (x, z) | Tool to non-grip body | Image |
|---|---:|---|---|---:|---|
| v1 | −30° | 50°, 30° | 128, −278 (32 u in from the bearer's front) | 4.8 u | `613567035f9e…` |
| v2 | −35° | 50°, 30° | 128, −262 | 4.5 u | `c29ab94822d2…` |
| **v3** | **−25°** | **60°, 30°** | **128, −246 (the bearer's centre line)** | **7.8 u** | `d9599098a96d…` |

How to read the table:

- The gaps are float vertex diagnostics over every key (`review.json`). For comparison, the accepted v4 has the same
  7.8 u minimum, at the grip boundary.
- Each candidate also holds 13.7 u to the workpiece and 13.6 u to the riser.
- The images are 114,860 bytes each: three clips, 33 + 31 + 31 keys.

**Recommendation: v3.** It taps the bearer's centre, pitches back the least and keeps v4's tool clearance. Its
handle lean is 60°, beyond v4's 50°. If that reads wrong, v1 keeps v4's 50° at the cost of a 30° pitch.

## Images

These are orthographic painter renders, not clearance proofs. Grip triangles are tinted. Green outlines are the
support deck and the deck behind; orange is the workpiece.

- `candidate-v3/overview.png`, `candidate-v3/hands.png`, `candidate-v3/motion.png`
- `candidate-v1/…` and `candidate-v2/…`, the same three images each

`motion.png` shows side views of entry keys 0, 10, 20 and 30 and tap keys 0 and 16.

## What to judge

1. **The posture.** Does a mole leaning back 25° (v3) and tapping its adze down beside its toes read as fitting a
   bearer, or as awkward?
2. **The contact.** The broad adze end meets the bearer's top at the centre line (v3) or near its front (v1).
3. **The entry swing** (`motion.png`). The pick head passes in front of the snout on its way down. The exact proof is
   clear; is it visually acceptable?
4. **Feet and riser.** The toes are 13.7 u behind the bearer, and the riser is 13.6 u behind the heel band.

## Known open items (not part of this review)

- **Arrival.** The descent ends 169 u behind the far edge, so the worker must step back 141 u to the station. No
  backward reposition on a tread is authored yet (step 5).
- **T6 is the sill.** Its bearer is 64 u tall, so its workpiece top is y = 64, not 128. It needs a variant of this
  tap at the lower plane, authored after approval.
- **Still to do after approval:** the handling program (v4's row 29 counterpart), native capture, the integer rows,
  content 7 and the Frontier.

## Reproduce

`invocation.json` lists the commands. Inputs come from the accepted source closure; the gitignored demo assets were
staged from the frozen `redwall-rts-codex-ug-space` worktree, verified against their pins, and removed afterwards.

`../test_tread_install.py` holds 7 tests: the fixture, the input-domain refusals, the stored proofs and pins, the
image digests and the probe. Its reconstruction test skips without the assets.
