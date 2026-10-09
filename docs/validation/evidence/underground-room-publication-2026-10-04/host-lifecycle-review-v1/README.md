# 1149 frozen host-lifecycle review

Date: 2026-10-04. Independent read-only review by Geometry. No Godot run, foreign
source edit, capacity change, or runtime qualification. The reviewed root base
was `f44efa7d0e29177bb97c499442078565099b3f12` plus the eight exact files in
`underground-host-lifecycle-2026-10-04/focused-1/source-sha256.json`. All eight
pins matched during review; `source-sha256.json` preserves that reviewed set.
The author was explicitly released to correct the findings after review.

## Blocking findings

**MEDIUM — Create holds a second complete WorldInit over the same stores.**
At the reviewed `ui_world_session.gd:354`, `WorldInit.new` runs before the reset
callback. The host, its Session and (after an earlier Create) the UI still hold
the original generator. `world_init.gd:704–739` allocates 175,364 packed bytes
per instance, excluding native overhead. `world_lifetime.py` derives every
resize from the actual source. Its published and staged maps are already
included in that one-instance figure; allocating a second instance is not the
existing staging allowance. Architecture's 159,968 map/tree row and separate
15,360 fauna row are each charged once, plus 36 fish scratch bytes. The extra
175,364 bytes do not fit the current 1,218-byte logical global headroom.

The bounded correction is to use the exact host WorldInit's already allocated
staging banks. Its `clear()` intentionally retains a prepared plan for the
preflight → reset → seed → cohort → publish transaction. Session's ordinary
current-source check should continue refusing a prepared World; only an exact
retirement boundary may accept the same original World with a replacement
plan while all live World/full-ref/PID/seed/store facts still match. Root
acknowledged this finding and chose that correction, removing adoption of a
second generator.

**MEDIUM — a successful in-scene Create drops the mounted foundation.**
Settlement's reset retires the Session and clears the retained handle at
`settlement_system.gd:1837–1845`. The successful Create tail only adopts the
generator and materializes the colony. The sole production mount call is in
`demo_village.gd:514–522`, reached by `_ready()`; this does not run when Create
is invoked in the existing scene. Therefore boot → successful Create leaves
`underground_session()` null. The new UI regression proves retirement of the
old Session but does not assert a replacement. Preserving the admitted Content
through host replacement and remounting after successful colony/economy setup
would close this lifecycle gap without loading another content image. Add a
real Create assertion for the replacement's current full World and owners.

## Remaining reviewed scope

No other high/medium finding was identified in the frozen component. The host
publishes its candidate Session handle before initialization observers, so a
nested reset poisons/refuses initialization. Quiescent retirement refuses held
arena leases, prepared Space and installed external authorities, and never
clears private weak authority bindings. Boot retirement precedes destructive
Entity/Economy reset. Refused UI reset preserves the original map/store tuple.
DemoCast/Actor do not load a second underground ActorContent in this path.

The author reports 286 tests / 7,020 assertions / 0 failures across seven
suites, six existing expected diagnostics, zero unexpected/tolerated/leaks,
and analyzer 0/8; the reviewed invocation records source and project/registry/
assets restoration. Those tests were inspected, not rerun. The later live demo
probe is separate evidence and was not counted as successful here. Operational
Room/phase teardown and playable underground permissions remain outside this
foundation-only packet.

## Reproduce the read-only allocation count

```sh
python3 -B world_lifetime.py /path/to/redwall-rts-codex-ug-integration
```

`world-allocation.json` retains the exact output. This script measures declared
packed payload and simultaneous logical lifetime, not engine/native RAM.
