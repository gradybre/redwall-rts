# Source review — Movement owner 8 validator and save bridge

Independent static review, 2026-09-20, of the exact unapplied candidates
`candidate-movement.gd` (152951b4…) and `candidate-save_owner_movement.gd` (e85eef0c…) against
`movement_component_validation_contract.md` v1 and ADR 0182. The two supplied patches reconstruct
those bodies: the owner hunks add 13/5/228 lines over 4/6/3 context lines, the bridge patch is a
single `+1,316` new-file hunk, and the hashes in `owner-candidate-probe.json` and `metadata.log`
agree with the candidate files. Nothing here was applied, imported, executed or measured, and no
outcome is asserted for the running 50-unit campaign.

## Verdict

No must-fix defect was found in either candidate. The predicate, the bridge gates and the
readmission repair match the frozen contract as written. Findings below are ordered by severity;
all are latent, evidentiary or confirmation items, not corrections to the candidate logic.

## Findings

**F1 (Medium) — the Z centre domain is pinned only on the bridge path.** `_is_centre_coordinate()`
bounds both axes with `SpatialWorld.CELLS_X`, correct only while `CELLS_X == CELLS_Z`. The bridge
pins both counts (`SOURCE_CELLS_X`/`SOURCE_CELLS_Z`) before projecting, so the framed path refuses
on drift; a direct `Movement.columns_refusal()` caller does not, and a nonsquare map would silently
widen or narrow the Z target domain. Under the pinned 512×512 constants this is not a live defect.
Record it as a source-drift obligation on the pure entry point rather than widening this milestone.

**F2 (Medium) — `metadata.log` provenance.** Its `source_sha256` records
`godot/scripts/core/movement.gd` as `152951b4…` and `save_owner_movement.gd` as `e85eef0c…`, i.e.
the candidate bodies, while the harness reads from and asserts equality against its repository
root. That run therefore executed in a workspace where the candidates were already present, not in
the unmodified production tree whose intake waits on PR 172. The evidence is self-consistent, but
the producing workspace should be named in the log before the metadata result is quoted as
production-tree evidence.

**F3 (Low) — kill records are labelled as failures.** Eight `*-gate-bypassed` cases carry
`killed_bypass: true` with `passed: false`. `execute()` asserts `killed if expect_failure else
passed`, so the accounting is right, but a reader scanning `passed` reads eight failures inside a
`"status": "PASS"` document. A per-case expected/observed pair would remove the ambiguity.

**F4 (Low) — unverifiable collaborator surface.** `Section.FramedOwner`, `owner_shape_refusal()`,
`i32_column()`, `set_i32()`, the `REFUSE_SHAPE/OWNER/METADATA` codes and `SaveHeader.Refusal(code,
detail)`/`is_ok()` are not in the supplied inputs. Gate 6's freedom from out-of-range column reads
depends entirely on gate 5 guaranteeing sixteen 512-element i32 buckets; that guarantee is assumed,
not confirmed here.

**F5 (Low) — two import-time confirmations.** `class Columns` resolves `MOTION_CAPACITY` and
`NO_REQUEST` from the enclosing script scope, and `parent-test-draft.gd` asserts
`Schema.field_type(8, field) == 2` as a literal where the bridge uses `Schema.TYPE_I32`. Both are
expected to hold; both are only settled by the pending actual import.

**F6 (Informational) — memory arithmetic.** `Movement.Columns.new()` sizes sixteen 512-row columns
(32768 B) that `_project_columns()` immediately replaces by assignment, so 65536 B is a peak
logical figure, correctly documented as allocation arithmetic and not resident set. Projection
shares the caller's buffers; the predicate writes nothing, so no copy-on-write duplication occurs.
Native and transitive-preload cost remains unmeasured, as claimed.

**F7 (Informational) — clone isolation.** The metadata tool disables autoloads only in its own
temporary clone, restores nothing in the repository and asserts every source byte unchanged in
`finally`. It symlinks `docs/` and `assets/` writably into the real tree; the probe never writes
there, but the link is the one production-touching surface in the harness.

## Conformance checked line by line

Predicate: shape (null or any non-512 extent) refuses before any index; rows ascend physically;
per-row order is phase, reserved six, both remainders, speed, velocity, both cells, target pair,
then state, exactly as contracted. Velocity uses `(speed + 29) / 30` integer division, giving
0/110/137/103 for 0/3277/4096/3072, two-sided. Target accepts both-zero or both exact centres in
256…261888 on a 512 stride; a mixed pair refuses. IDLE zeroes velocity, remainders, target and
`grid_next` while retaining speed and `grid_cell`; TRAVELLING requires positive speed, both cells
and the centre of `grid_next`; ARRIVED retains bounded velocity and accepts an all-zero target;
phases 3–5 require zero velocity and retain fractions and abandoned target. No float, clock,
callback, allocation or write appears on any path, and the centre helpers run only after the cell
gate. All sixteen projections match the contract ordinal table and the `Columns` declaration order.

Bridge: gates run null → owner ≠ 8 → schema (forwarded unchanged) → metadata → owner shape
(forwarded unchanged) → projection → raw column code. Field parity loops only after `field_count`
and the three pinned declaration arrays are length-checked; the speed table's length is pinned
before any entry is indexed. The metadata prefix is exactly `Movement owner8 metadata:`, the column
detail contains `Movement owner 8 ` plus the exact code and no row identity, and success carries an
empty code and detail.

Repair: the single conditional decrement sits after the last refusal in `_attach_route` and before
`_reset_motion`, which does not touch the phase, so it removes the old TRAVELLING contribution
exactly once. A non-travelling row contributes nothing; the later single increment plus a possible
`_settle(ARRIVED)` nets zero for a one-cell route; other rows, `stop()`, `revalidate_destination()`
and the persistent-owner deferred cleanup are byte-unchanged. No clamp, recount, new field, new API
or navigation change appears in the diff.

Campaign mechanics: the 34 owner variants are distinct and asserted so; the ARRIVED and 3–5 group
variants disable one shared guard per group only, the TRAVELLING target variant also disables the
nonnegative `grid_next` guard so no centre helper is reached on a sentinel, and both priority
inversions are guarded against empty or short columns. Each is killed by a frozen case through an
assertion mismatch, not a parse or runtime error. The sixteen omitted projections fall back to
constructor defaults that every corresponding frozen case distinguishes.

## Claim maturity

Reconstruction and candidate evidence only. Intake identity against production, actual import,
focused and full suite, the 50 required code units, the 17 static checks and exact-head CI and
merge remain open, as do MOVEMENT-SAVED-BINDINGS, bulk capture/apply and MOVE-G01–05.
