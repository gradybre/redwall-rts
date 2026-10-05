# Ground pace content v1

This is a **pace-only** immutable ConnectorCatalog image. It grants no physical
clearance, actor state, route, support, paid geometry or source transition.

The artifact uses explicit `UGCONN01` wire version2, Catalog revision1. All six
geometry/material counts are zero. Nine sorted pace rows name the actual WALK
descriptors1–9 of the reviewed mole profile-publication-v3 (content2, rowrev1).
Profile0 is MODE_STAND and profiles10–25 are MODE_WORK, so they are excluded by
descriptor mode rather than by an arbitrary profile range. No CARRY or climbing
row is synthesized. The source wire remains unchanged.

Every pace has family−1, variant0, Movement profile1/rev1,
`P_RATE=0`, `RATE_GROUND_CAP=0`. The actual Movement profile is
`starter.ground.adult.mole`; its species/stage and current revision/cap are
validated by the runtime loader and every pace query. The wire contains no
numeric speed. Existing `Movement._build_starter_profiles` derives that cap
from Residents, as before.

`manifest.json` pins all input source bytes, the Profiles source digest and
whole wire, exact Levels image, derived rows and the output hash. Rebuild and
test from the repository root:

```sh
python3 -B godot/data/underground/ground-pace-v1/compile_ground_pace.py
python3 -B -m unittest discover -s godot/data/underground/ground-pace-v1 -p 'test_*.py' -v
```

The unchanged runtime API is `Catalog.configure(Catalog.RESERVED_BYTES)`,
`bind_actual(actual Profiles, actual Levels, actual Movement, Residents,
Transforms, exact World Domain)`, then `load_file(path, manifest digest, 1)`.
This initial actual Movement must be constructed from those same original
Directory/Residents/Transforms. The Catalog continues to use its existing two
fixed banks and reservation; a ground-only image does not allocate a third
bank or release/reassign that reservation.

For actual host composition, the existing Profiles source/current-consumer
guard remains mandatory before routing, as do source readiness, support,
complete body/tool geometry and current occupants. The artifact does not close
that consumer renewal or produce World activation by itself. Later profile
publications require an explicitly regenerated and reviewed successor image;
coincident row numbers never qualify a changed content revision or source hash.
