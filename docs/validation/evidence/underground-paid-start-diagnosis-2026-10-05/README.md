# Paid L0 START blocker — reproduction and diagnosis (2026-10-05)

Commit `11ccb765` (branch `claude/ug-paid-start`) puts the overlay-only paid-12
state into git on top of `4a51beaf`. It adds geometry `diagnostic-source-7`,
construction `declaration-6` owners, the contact-retirement scope, the paid
fixture and the two evidence images that the fixture reads. Running only the
paid suite reproduces paid-12 exactly:

```text
6 test(s), 107 assertion(s), 1 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
```

This is a diagnostic focus run (no assets-aside, cache deletion or analyzer). It
is not a qualification receipt.

## Where START refuses

`ModularProjects.start_work` → `ConnectorWork.transition_refusal` →
`Workpieces.prepare_start` → `Placements.prepare_workpiece_start` →
`EntryBindings._stage_timber_locations` → `_timber_refresh_locations` →
`Locations.stage_refresh` → `_record_geometry_refusal`.

The staged bearer is an `OBSTACLE` row with box
`[122880,512,102400, 124928,640,102528]`. The first refreshed live Location,
row 0, overlaps it and returns `LOCATION_ENVELOPE_BLOCKED`.

## Live Locations at START (entry origin = (123904,512,102400))

| Row | Role | Point | Relative point |
|---|---|---|---|
| 0 | WORK | (123072,512,102912) | (-832,0,512) — handling station H |
| 1 | STORAGE | (124416,512,102912) | (512,0,512) |
| 2 | STORAGE | (122496,512,102912) | (-1408,0,512) |
| 3,4 | WORK | (122368/125440,512,101888) | (∓1536,0,-512) — first dig pair |
| 5,6 | WORK | (…,100864) | (∓1536,0,-1536) |
| 7,8 | WORK | (…,99840) | (∓1536,0,-2560) |

**All nine Locations carry the same envelope**, `[120832,512,97792,
126976,2560,104448]`. That is the whole 6 m × 6.5 m room. Any bearer placed in
the room therefore blocks every Location. Retiring dig contacts alone cannot fix
this, because rows 0–2 also overlap the bearer.

## What ADR 1191 requires to clear it

1. A source successor with narrow per-contact envelopes. H keeps relative
   (-832,0,512), but material/output storage moves to (-832,0,2048) and
   (-832,0,1536), clear of the bearer.
2. Even H's narrow envelope `[-445,0,-732,910,1036,346]` still overlaps this
   bearer (absolute X 122627–123982, Z 102180–103258). START at H therefore
   needs the exact pending-bearer endpoint certificate. Geometry's untracked
   `qualified-assembly-v1/endpoint_certificate.gd` in `diagnostic-endpoints-2`
   provides it.
3. Retire the completed first dig pair (rows 3,4) through the two-publication
   WorldRoutes → Locations sequence, using hostile-observer rechecks.
