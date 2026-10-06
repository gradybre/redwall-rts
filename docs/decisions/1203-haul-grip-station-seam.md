# 1203 — The haul-grip certificate and Delivery's stand seam

Date: 2026-10-06 · Status: Accepted (ADR 1198 steps 5, 6 and the Delivery part of 8)

## Decision

### Certificate

`godot/data/underground/mole-worker/qualified-haul-v6/grip_certificate.gd` follows row 29's assembly-palm
precedent (`qualified-assembly-v1/source_program.gd`). It is static and holds no state. It sits beside the content
it certifies.

- **Exact match.** Rows 32–36 must match exactly: every descriptor word, revision, quantity, policy, box and the
  haul image digest (`HAUL_SOURCE_SHA`). The yaw-0 boxes, R−S = (0,0,576) and both hand-contact cells are copied
  from `haul-rows-v1/rows.json`. A test compares them word for word. Rows 34 and 36 are checked as the quarter turn
  `(x0,y0,z0,x1,y1,z1) → (z0,y0,−x1,z1,y1,−x0)`.
- **`station_refusal(row, root, yaw, stock)`** proves three things:
  - the heading is the row's own;
  - `stock − root` equals the certified S − R at that heading;
  - each witnessed contact cell (turned, at S) lies in both a BODY_HELD_LOAD box and a WORK_STROKE box, and S
    lies in the stroke.

  The offline witnesses put both hand vertices exactly on wood-mesh edges. They hold only for that geometry and
  that transform, and this check confirms the runtime has exactly that transform.

### Delivery seam

The seam is in `underground_connector_delivery.gd`.

- **Grip mode belongs to the content, not to the call.** When `Grip.uses(profiles)` holds (content 5), every
  haul is a grip haul. Content 5 has no ANCHOR_AND_PATCH HAUL rows. The synthetic fixtures that do have them keep
  the original path unchanged.
- **The stand is derived, never mapped.** `stand_of(storage)` is the single live ROLE_WORK Location in the storage
  endpoint's section, level and room whose point is S minus a certified S−R. If there is none, or more than one,
  Delivery refuses with `CONNECTOR_DELIVERY_NO_HAUL_STAND`.
- **Admission** reaches the source stand with the worker's current WALK selection. It then reaches the destination
  stand with CARRY row 32.
- **Final leaf.** `_worker_leaf` requires the worker to be on the stand beside the expected storage endpoint, and
  `station_refusal` to pass at the worker's exact pose. Without that, Delivery refuses with
  `CONNECTOR_DELIVERY_NOT_ARRIVED`. This runs on every Work tick and inside the Inventory journal.
- **Roles.** A grip row needs roles 0–4 (mask 31) and no contact boxes. Its WORK_STROKE boxes are the stock:
  - The part above the floor must lie in the stand's air.
  - The floor contact must lie on the stand's surveyed footing. This is floor support at S.
  - No stance region is asked to cover the stock, because it is not a foot.
- **Quantity.** A request above 1,000 milli becomes one 1,000-milli trip. A trip below 1,000 is refused with
  `CONNECTOR_DELIVERY_TRANSFER`, as is any cargo other than row 32's (wood, id 60). The grip rows also require
  claim quantity 1,000, and row 36 selects only a 1,000-milli satchel, so a partial-remainder unload cannot be
  selected.

### Work area

- **Three haul edges only:** WALK R→stand R, CARRY stand R→stand M, WALK stand M→M. See the check-budget finding
  in ADR 1198, step 5.
- **The CARRY edge arrives on the grip heading.** Ground turns admit only STAND and WALK, and no loaded turn is
  authored. So the CARRY polyline steps out by the stand offset on +X, runs along, and enters stand M moving −X
  (yaw 16384). The empty worker turns in place at stand R.

## Why

- Deriving the stand from the certificate leaves nothing that can drift between the work area and Delivery.
- Content-level grip mode avoids a caller flag.
- Capping a larger request to one trip keeps the existing "a request may be shipped in parts" semantics while
  honouring whole-unit trips.

## Rejected

- **A caller-supplied stand handle**: Delivery would then trust a caller for a physical fact.
- **Geometric stand detection without the content gate**: in the synthetic first-prefix fixture, endpoint 0 sits
  exactly 576 u on +X of endpoint 2.
- **Widening `STORAGE_FOOT`** to carry the stock at M (z 2460 against 2454): this would change the ADR 1191 layout.
  The stand carries its own footing instead.

## Open (for the foreman, which this work did not edit)

1. **Hook sequence for one trip:**
   1. Stage surface wood as a 1,000-milli lot in R's container, which is real `create_spatial_ground_staging`
      storage.
   2. Create a HAUL Job sourced by the phase Project, and call `Delivery.admit`.
   3. Set TRAVEL. Route to stand R with WALK, then `WorldRoutes.turn_actor(…, 16384)`.
   4. Call `refresh_work_actor(34)` and `begin_load`, tick Work, then `load_payload`.
   5. Call `refresh_actor(CARRY)` and route to stand M, which arrives at 16384.
   6. Call `refresh_work_actor(36)`, tick Work, then `unload_payload`.
   7. Walk stand M→M to rejoin the graph.

   The worker must hold no tool for the whole trip.
2. **R's container is also the spoil output in the runtime.** Staging wood there mixes inputs with spoil in one
   container. The alternative is a dedicated staging endpoint with its own stand and edges, which competes for the
   check budget.
3. **Stone cannot be hauled.** Content 5 authors wood only (cargo 60). Brace stone inputs need their own authored
   rows; until then the G4 alert stays for stone.
4. **No loaded turn and no stand↔stand return walk.** The return trip walks M→H→R.
