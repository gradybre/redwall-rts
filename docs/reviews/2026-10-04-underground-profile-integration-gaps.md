# Published worker profile versus the first timber entrance

Read-only review by `/root/ug_geometry`, recorded by the integration owner on
2026-10-04. Compared integration `77cd67e3`, Construction's `75096e56` fixture
and the accepted profile wire
`b8033048f55d38ff477388bc6be528a096fd847d040c24faaf374a5e8cfea0ac`.
No engine test or production activation follows from this review. File lines
refer to those snapshots.

The real profile cannot replace the synthetic first-prefix worker unchanged.
The following are implementation gaps, not proposals to shrink the worker,
enlarge paid timber silently, or grant movement from an INSTALL posture.

| Selection | Published support or contact |
|---|---|
| STAND 0 / WALK 1 | Foot support `[-406,-1,-406 .. 406,0,406]`, 812 by 812 units; held-tool/recovery air reaches `[-1256,355,-1256 .. 1256,1036,1256]`. |
| Down 14, yaw 49152 | Foot support `[-454,-1,-274 .. 305,0,328]`. |
| Down 6, yaw 16384 | Foot support `[-305,-1,-328 .. 454,0,274]`. |
| INSTALL 5, yaw 0 | Foot support `[-274,-1,-169 .. 299,0,174]`, 573 by 343 units; contact patch `[127,128,-449 ..129,128,-447]`. |

Sources: `godot/data/underground/mole-worker/evidence/contact-qualification/`
`source-gates-v2/ground-closure.json:63`, `cardinal-proof-v1/down.json:27` and
`cardinal-proof-v1/install.json:27`.

1. **High — support and air clearance are conflated.**
   `underground_entry_bindings.gd:1401` copies the occupied-air footprint into
   `Record.support`; `underground_locations.gd:1543` requires support beneath
   that footprint. The 2512-unit held-tool box therefore becomes a floor
   requirement larger than the 2048-unit landing. Separate source-authored foot
   support from body/tool air using the existing fields, retaining coverage,
   obstacles, full source identity and installed-datum proof. A WORK envelope
   may extend horizontally beyond its supporting deck only with independent
   proof of that surrounding air.

2. **High — the first tread cannot hold the ground stance.**
   `docs/design/underground-planning/first-entry-prefix-v1.json:144` gives T0
   only 512 units of depth. The 812-unit ground stance cannot fit at any root.
   The higher landing and unfinished next tread supply no same-plane support.
   Implement the separately qualified stair posture and source-phase motion,
   including entry, exit and cancellation. Do not end a stair action by
   switching to an unsupported ground stance. The 18 published profile rows
   currently contain no stair program; `underground_world_routes.gd:701`
   correctly refuses height-changing ground paths and fixed connectors.

3. **High — surface work stations use synthetic dimensions.**
   `test_underground_first_prefix.gd:318` supplies side strips 768 units wide.
   The real down-work stance exceeds their outside edges by 71 units; ground
   stance at X ±1408 extends 22 units into the future cut footprint. Other
   endpoints allow only 384 units of support and 900 units of air. Recovery
   reaches 1192 units and the productive tool 1422. Reauthor natural stations
   from the real boxes and prove approaches, target contact and retreat.

4. **High — INSTALL needs the actual raised workpiece.**
   Decision 1116's tool contacts Y128, while the fixture targets Y0 earth or
   prior timber. `underground_connector_contacts.gd:649` accepts only natural
   or prior installed targets, and `:949` requires the foot-root above the
   positive-Y target plane. A root at Y0 therefore rejects the raised target.
   Add a typed, paid workpiece lifecycle and source-based body/stroke/contact
   proof. Keep full target containment. The current union air box also covers
   the bearer even though the source's lower and upper body partitions avoid
   it; a broad collision exemption would be incorrect.

5. **High — identity and renderer closure must be composed.**
   `test_underground_world_routes.gd:270` initializes a mouse and eight
   profiles/64 boxes. The publication requires an adult mole, 18 profiles/194
   boxes, tool 54/BASIC, no cargo and the exact role map in
   `mole_profile_catalog.gd:89`. The actor's basis guard at
   `godot/demo/cast/underground_actor.gd:132` accepts OpenGL compatibility;
   `godot/project.godot:467` defaults to Forward+. Changed consumer hashes also
   correctly refuse the old publication. Close current consumers and the
   actual default backend in a new immutable publication, preserving v1.

Core paths above are relative to `godot/scripts/core/`; test paths are relative
to `godot/test/`. Ground turns additionally need the presentation driver's
completed recovery/ready handoff (`mole_profile_driver.gd:203`). Decisions 1132
and 1133 reserve the renderer and support/clearance follow-ons. Paid workpiece
handling and stair motion remain separately tracked work. The wood-only cost
decision remains unchanged.
