# FieldPolicy component validation — independent contract review

Reviewer: independent, read-only. Subject: FIELD-POLICY-S4-VALIDATE-R01 v1.
Disposition: **ACCEPTED SUBJECT TO CONDITIONS (B1–B3).** No implementation performed and
nothing was executed for this review.

## Verified against actual source

- Owner 3 `field_policy`, version 1, primary 128, one child extent 4096, field begin 60,
  count 20, offset 8458852 — all match `save_component_columns_schema.gd`.
- The 20 ordinals, keys, types and counts match `FIELD_KEYS/TYPES/COUNTS[60..79]` exactly;
  buckets are 7 u8 and 13 i32 as claimed; rotation_ids 384, three plot columns 4096.
- Byte arithmetic re-derived: 4864 u8 + 39424 i32 = 44288 values; 4 + 8 + 160 + 44288 =
  44460 payload; 24 + 12 + 44460 = 44496 block. The contract's figures are correct.
- Memory: 44288 + 44288 + 1536 = 90112 logical packed bytes, scratch 3×128×4 = 1536.
  Arithmetic correct; RSS/native allocation remains unmeasured, as the contract says.
- `Columns.new` defaults match `clear()` exactly (−1 for zone_slot, rotation_ids,
  requested_crop, plot_field_slot; seed_reserve 1; all else 0), and a default image is
  accepted by the predicate as written, including the no-OPEN fast path.
- Crop domain: Farming 0..4 with `CROP_NONE` −1; `FIELD_CAPACITY` 128 (HarvestZone),
  `PLOT_CAPACITY` 4096 (FarmPlot). All readable as constants, needing no live instance.
- OPEN exact-count rule is sound against the writers: enrol +participants, withdraw
  −participants/+withdrawn, resolve +resolved, and `is_plot_enrolled` refuses cross-field
  theft while a cycle is OPEN. Declining CLOSED reconstruction is right — the probe's
  "closed plot ledger overwritten by another field" is the witness.
- Retained history matches the writers: `destroy_policy` clears only present/state/request/
  crop/participants/resolved, so withdrawn, completed, cancelled, close_reason, ordinal,
  rotation and flags legitimately persist on inactive rows. `_reclaim_stale_policy` is
  immediately followed by `_write_default_policy`, so it exposes no inactive row with a
  nonzero participant count or standing request. Present-IDLE with a positive ordinal is
  reachable; the contract accepts it correctly.
- Request rules hold: non-NONE ⇒ present, CLOSED, close COMPLETED, crop == rotation[cursor];
  `ENTRY_NOT_CONFIGURED` ⟺ crop −1; `open_cycle` consumes a request; `set_auto_rotation(false)`
  does not clear one, so not requiring auto=1 is correct.
- OPEN shape: participants 0 ⇒ resolved/withdrawn 0 (withdrawing the last participant closes
  ABANDONED); participants > 0 ⇒ resolved < participants. COMPLETED/CANCELLED/ABANDONED
  shapes match `_close_cycle`. `participants + withdrawn ≤ 4096` holds because one plot can
  hold only one live enrolment per cycle.
- Public probe: 76 assertions / 0 failures, observable histories only; the MAX case is the
  `can_open_cycle` boundary predicate, not a reached ordinal. Already stated; not re-argued.

## Blockers

**B1 — wrong Directory constant (must fix before author).** `EntityDirectory.TOTAL_CAPACITY`
does not exist, and 87552 is not the directory bound: `entity_directory.gd` declares
`DIRECTORY_CAPACITY = 352418`, while 87552 is section 4's `transforms` primary count.
Repair: pin `EntityDirectory.DIRECTORY_CAPACITY` and bound a present zone slot
`0..DIRECTORY_CAPACITY-1`. `NULL_SLOT` −1 and `NULL_GENERATION` 0 are correct as pinned.

**B2 — metadata fault matrix not yet coherent (gate, satisfiable).**
`save_component_columns_schema.gd` validates itself from compiled constants pinned by
`EXPECTED_*`, so a naive fault is refused by `schema_refusal()` before the bridge pin is
reached and the bypass is never exercised. Each of the 9 coherent faults must recompute
payload, block, every subsequent owner offset, `SECTION_BYTES`, `DESCRIPTOR_ROW_COUNT` and
the matching `EXPECTED_*`, and the plan must record per fault which guard refuses. State
whether fieldkey/type/extent faults are representative or per-ordinal; the child-count fault
(0 or 2) shifts payload by ±8 bytes and must be made coherent too.

**B3 — witnesses not frozen (gate, satisfiable, not impossible).** Freezing concrete mutation
witnesses and the exact metadata arithmetic before dispatch is a pending precondition, not an
unsatisfiable requirement: every named family (20 projection omissions, 7 byte scans, each
state/request/ledger/count clause, shape-before-domain and per-row priority) has a
constructible synthetic `Columns` witness. Dispatch is blocked only until the table exists.

## Lesser findings

- Pin `MAX_CYCLE` by comparison to `IntMath.INT32_MAX`; `int_math.gd` is not in this packet,
  so the literal 2147483647 is unverified here.
- Pin the crop domain as `FarmingScript.CROP_COUNT` / `CROP_NONE`, not literals 0..4 / −1.
- `_is_rotation_entry` uses `_farming.is_crop` (an instance); the new predicate must not.
- `plot_cycle <= linked field ordinal` is safe: ordinals are monotonic and are reset by
  neither `create_policy` nor `destroy_policy`.

## Conditions for acceptance

Fix B1; freeze B2's coherent tables and B3's witness list. Everything else stands as written.
Cross-owner zone/plot identity, bulk capture/apply and REQ-SET-088 correctly remain out of scope.
