# 1041 — The routes harness lays its dig where nobody stands

Date: 2026-10-02 · Status: Accepted

## Decision

`godot/test/live/demo_routes_live.gd` chooses the tunnel it lays for its dig
checks with the Dig tool's own entrance rules. Each candidate in `DIG_ROUTES` is
tried both ways round. It is kept only when the plan takes it
(`laid_piece_reason() == REFUSE_NONE`) **and** its new entrance passes
`entrance_refusal(choose_digger(), start)`: nobody is standing on it, and the
digger has a way to reach it. The confirm then runs **once**. A refusal at that
point is a real one, and it fails with the tool's own notice.

The retry added in `d12a57d8` is removed. That retry called `confirm` for up to
120 frames, and the game is paused at that point, so retrying it could never help.

## Cause (the CI flake of PRs #207 and #216)

CI showed `dig: dug: FAIL confirm refused for 120 frames` at either size, on
placeholders. The check after it then failed with the text "If this piece is dug
as laid", because the piece was still only laid.

- `_routes_group` sends residents 0, 1 and 2 to the far bank, (30, 0, −1). It
  unpauses for 30 frames and then pauses.
- The path they take runs east along z ≈ 9.5, which passes over the only
  candidate the plan takes on placeholders, (6, 9.5)→(−2, 9.5).
- A resident is "walking" (`cast_space.resident_walking`) only in
  `State.WALK`. At each waypoint the brain enters `State.TURN`, and while it
  waits for the routing desk it is in `State.ROUTE`. In either state it counts as
  standing.
- So if the pause catches a group member turning within reach of (6, 9.5),
  `occupied_at` refuses the confirm with `REFUSE_ENTRANCE_OCCUPIED`.
- The game stays paused through the dig step, so the refusal lasts.
- How far the group gets in 30 frames depends on how fast the runner is.

This was reproduced locally by standing resident 1 (walking 0) at (5.75, 9.6)
before the confirm. The output matched CI exactly: `confirm refused for 120 frames`,
followed by the identical "If this piece is dug as laid" failure. With the fix,
the same forced stand lays the reversed piece (start (−2, 9.5)) and all 35
checks pass.

The game's rule is correct. Someone standing on the hole refuses the dig, and a
resident turning on the spot is standing. Only the harness changed.

## Verification

- With the forced stand: `LIVE-SUMMARY 35 0`, laid start (−2.0, 9.5).
- Unforced at 1280x720 and 1920x1080, without staged assets and with them:
  `LIVE-SUMMARY 35 0`.
