# Actual future-Room leaf/kernel prerequisite

The accepted four-file scope is recorded in `room-leaves-2/source-sha256.json`.
Parent independent review accepted those exact pins after the original
issuer/bracket/Budget correction. The separate Locations/Routes/WorldRoutes
Room companion changes were in progress and are excluded from this verdict.

| Suite | Tests | Assertions | Failures |
|---|---:|---:|---:|
| SpaceOwner |110|5397|0|
| FinalFacts |25|1077|0|
| EntryOrders regression |17|721|0|
| Total |152|7195|0|

All strict and raw-log unexpected errors/warnings and object/resource leaks
were0. The selected analyzer reported0 warnings in4 files. Invocation, source
pins, suite manifests and raw logs are retained. Asset presence was restored
to its initial state and the four candidate files stayed unchanged.

Reproduce from the repository root with a fresh output directory:

```sh
python3 docs/validation/evidence/underground-entry-placement-2026-10-03/reproduce-room-leaves.py --out /tmp/ug1108-room-leaves --port 6245
```

`room-leaves-1` passed its runtime checks but was rejected during independent
source review: a foreign/replaced Budget or absent actual publishing bracket
was not yet directly excluded at the kernel. `room-leaves-2` adds those direct
checks, explicit full World liveness before allocation, and adversarial
regressions. Tests use actual allocator, Buildings, RoomOrders, Space and arena
state with synthetic physical admission only. They do not qualify the missing
future Placement companions or playable entry content. See decision1108 for
the exact work and logical frame census.
