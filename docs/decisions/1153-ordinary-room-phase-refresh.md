# 1153 — Ordinary Room phase refresh

Status: component source independently accepted and final regression passed,
2026-10-04. The concrete 1152 provider and host composition remain separate.

Ordinary Room excavation must publish the same complete refreshed Space,
Location and Route banks as entry excavation. A Room is not a connector
Placement. Its paid Site/Project/Room identity must not be replaced by a dummy
Placement, and an ordinary Room revision can also affect an existing connector
opening that names that Room.

Reuse the actual Placement owner's single existing 128-byte `PhaseContext`,
its existing mode byte, inactive banks and synchronous cold lease. The issuer
and reciprocal Authority/Sites/Space/Locations binding remain permanent.
`prepare_phase_refresh` continues to require its real non-null Placement.
The separate `prepare_room_phase_refresh` permits only the exact null Placement
sentinel after validating the original actual Authority's captured ordinary
underground Room, full Site/Project identity, operation/stage and original
cold/Space tokens. It refreshes all retained Placement/opening source pins as
well as every old endpoint/edge. It changes no prefix, payload, active order,
worker or economic receipt. No second context or context binding is allocated.

The concrete provider calls the already-bound
`Placements.prepare_room_phase_refresh` directly. The actual Authority exposes
`room_phase_context`, `room_phase_observation_refusal`, static
`room_phase_leaf_refusal` and `discard_room_phase_refresh` through that same
issuer. This avoids a second prepare forwarding frame. Provider
qualification remains the ordinary provider's exact source proof; context
metadata alone grants no work or terrain permission. START and terminal
COMMIT/CANCEL retain the original full tuple. Terminal retries need no released
worker. Publication uses the existing concrete Sites window and static
Space → Locations → Routes/certificates → Placement-source bank sequence,
followed by original cleanup. The original Authority-owned Space token remains
protected against generic publication even after companion discard.

Ordinary classification follows actual live Placement ownership, not the
Room purpose: a painted ordinary Corridor is allowed, while a real entry
Corridor must still use its non-null Placement path and actual entry provider.
Both public prepare methods reject a fresh, unbound or partially disconnected
owner before reading companion fields. Reentry still poisons the original
observation. Cleanup selects the independently pinned original branch, even
when a borrowed context's operation fields have been changed.

The narrow UI 1154 read seam is `Locations.location_capacity()` and
`live_location_at_into(slot, expected_geometry_revision, out_ref, out_record)`.
It copies one current complete live endpoint into caller-owned fixed buffers
only after its actual owner, full generation, source, section and current
geometry receipt have been proved. Absent, stale, prepared, malformed and
insufficient-work cases leave both outputs unchanged. This callback-free read
grants metadata only; a consumer must still run the complete actual Approach
proof for support, body/tool air, contacts and path permission. No source
observer, retained iterator cache, image or lease is added.

No retained field, packed column, buffer, capacity, global reserve or per-job
ledger is added. The existing context is counted once in Placement controls;
the ordinary provider borrows it. The source census retains 1,895 / 2,048
Placement control bytes, including the existing 576-byte helper allowance.
The complete ordinary preparation chain is 564 / 576 bytes; the iterator's
numeric chain plus caller Record/ref and expression allowance is 308 / 512.
Existing Authority Plans coexist with Locations preparation at 691,024 bytes;
the subsequent WorldRoutes phase is 526,800 bytes, both within the original
1,048,960-byte cold reservation. Locations releases its proof before the latter
phase. The existing 40-byte prepare and 56-byte final callback allowances are
counted here once. Additional 1152 provider locals and retained WorkFace state
need their own combined census; its large WorkFace survey must end before
companion preparation. No combined provider or native-memory admission is
claimed by this component.

Owned production changes are SpaceAuthority, ConnectorPlacements and Locations.
SpaceOwner's existing Authority-token guard needs no change. The dedicated
`test_underground_room_phase_refresh.gd` uses actual Room/Sites/Project/Funding
and companion stores, with explicitly synthetic source/body/structural
qualification. Iterator coverage is in the existing Locations test. These are
component tests, not production source or gameplay qualification. Root owns
shared ledgers and host composition. Construction owns the new ordinary
provider under 1152. Routes, WorldRoutes, WorkFace and all other consumers
remain unchanged here.

Source pins, rejected attempts, exact strict/analyzer commands, restoration and
source-counted lifetimes are retained in
`docs/validation/evidence/underground-room-phase-refresh-2026-10-04/`.
Root's independent review accepted all six corrected source/test/UID pins and
reproduced the census. The final unchanged-source run passed seven strict
suites, 173 tests and 17,943 assertions, with zero failures, diagnostics or
leaks, and analyzer 0/5. This accepts the bounded component, not the later
concrete provider or playable host integration.
