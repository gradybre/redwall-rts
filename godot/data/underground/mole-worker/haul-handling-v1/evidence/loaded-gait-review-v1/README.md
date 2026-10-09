# Exact-one-unit loaded source checkpoint

This additive source packet keeps the current complete mole and wood meshes. It
does not activate a Profile, Route, Delivery, driver, movement rate or runtime
allocation. The source variant is exactly 1,000 quantity-milli of wood, reusing
the actual Catalog's 5,000 g/unit. The inherited 2,000 mWU loading and 2,000 mWU
unloading remain unchanged. A requested quantity of 1,000 is not enough: later
runtime admission must prove the actual admitted and carried quantities are
exactly 1,000. Other payloads refuse this source. Generic partial Inventory
transfers and retained cargo remain unchanged.

## Geometry and joins

The held upper-body local joints and complete stock transform come from the
reviewed four-phase lift's final hub. Hips and legs come from every original key
of the supplied `carry_heavy_object_walk`. Hold, entry, loop and reverse entry
contain 2, 65, 219 and 65 source keys, respectively. Their 347 rendered intervals
include the actual penultimate-to-first loop wrap. Exact source bytes join
lift → hold → entry → loop → recovery → place; repost can retain the same loaded
hub without pretending that another pickup happened. These source joins do not
prove arbitrary interrupted world-root movement or authorize a runtime repost.

All 10,209 body/clothing and 768 stock triangles remain present. The 9,283
non-grip body triangles, including mixed anatomical boundary triangles, must
remain separated from the stock. Only the already-reviewed actual hand groups
(478 left / 448 right triangles) can contact their own stock. The two independent
hand-edge / curved-stock-triangle witnesses remain real contacts throughout each
source interval; no planar patch or storage metadata point is substituted.

The whole carry-loop body bounds are `[-433,0,-446 .. 509,932,241]u`, and the
whole stock bounds are `[-425,473,-503 .. 504,704,-217]u`. Its overhang stays in
the occupied/cargo envelope. Floor checks include every body and stock vertex;
each source interval retains at least one actual sole vertex in the admitted
one-unit floor cell throughout the interval. Native error is not included.

## Proof and rejected evidence

`prove_carried_grip.py` derives exact rational plane-distance polynomials of
degree at most three and triangle-interior polynomials of degree at most seven.
Bounded Bernstein subdivision proves the required signs for every interpolation
time. A strictly positive denominator excludes a degenerate stock triangle or
unresolved hand-plane crossing. Unresolved signs or capacity exhaustion refuse.
Complete triangle separation uses the existing bounded integer hull proof.

The first gait candidate kept both grips, non-grip clearance and the floor, but
failed six actual foot-transfer intervals. Its full output remains in
`../loaded-gait-v1/carry-proof-v1.json`. The accepted candidate is not obtained by
loosening that test: it adds measured lower-envelope switch keys to the source,
retains every original gait key, then re-proves every complete primitive. The
regression still rejects the original `[20,21]` unsupported transition.

The first fourteen-case test run had two negative-fixture slice-duration errors
and one list/tuple expectation mismatch. Those tests and the raw log remain in
`../loaded-gait-v2/tests-rejected-1/` and `../loaded-gait-v2/tests-1.log`. The source
geometry and proof predicates were unchanged. The final invocation and test log
record the corrected full replay, including interior-only loss of hand contact,
stock degeneracy, late hand departure, floor penetration, complete stock crossing
the body between clear endpoints, shape/capacity refusal and exact source joins.

## Reproduction and remaining gates

Run `reproduce_loaded_gait.py` with the same `--palette` and `--grip-palette`
paths shown in `invocation.json`, and a new `--out` directory. The runner hashes
all 32 source inputs, authors a fresh candidate, proves all four clips, renders
three views and runs all fifteen tests. It refuses any failed proof and verifies
input pins after execution. It does not run or modify the settlement project.

The new four clips contain 351 stored palettes of 25 transforms plus grounding:
422,604 raw F32 bytes. Combined with the previous four-phase source's 244 stored
palettes, that is 595 palettes / 716,380 raw F32 bytes before source headers,
mesh/rig tables, compiled proof data, decode, replacement coexistence and native
presentation. This is offline source arithmetic, not an admitted runtime memory
contribution or a claim that a new image fits the 100 MB gate.

Native replay/error bounds, world-root progression, loaded turns, empty-ground
approach/recovery joins, BUILD set-down, the measured station/contact runtime
seam and joint source allocation remain open. No HAUL speed has been adopted.
The entire `haul-handling-v1/` subtree is ignored by the game importer; eventual
runtime publication must be explicitly staged outside it.
