# Ordinary Room phase refresh and live Location read

The 1153 component extends the existing single Placement-owned PhaseContext to
an ordinary Room operation captured by the same actual Authority/Sites owners.
An ordinary Room has no Placement ref. Every retained Placement/opening,
Location and Route is refreshed through the existing inactive banks, under the
original full Site/Project/Room, stage, operation, Space and cold tuple. The
existing entry path remains distinct. A painted ordinary Corridor is classified
by the absence of live Placement ownership, not by its Room purpose.

The accompanying narrow 1154 iterator copies a complete current live Location
into fixed caller buffers. It proves metadata/source/full-handle identity only;
the UI must still perform its separate actual Approach proof. It adds no
retained state or physical/traversal permission.

The worktree baseline is `b03fbc2b0322381248998bfc57ce0a89ee3e76c0`. Owned
production files are SpaceAuthority, ConnectorPlacements and Locations. There
are no changes to Routes, WorldRoutes, SpaceOwner, WorkFace, Orders, Sites,
shared registry, memory checker or host sources in this packet.

## Frozen sources and independent review

`source-review-1/source-sha256.json` preserves the first six source/test/UID
pins and non-executable snapshots. Root's review found that the public ordinary
prepare entry could dereference unbound companions before checking readiness;
the pre-existing entry prepare method shared the exposure. That packet is
retained unchanged. It is not the accepted correction.

`source-review-2/source-sha256.json` pins the correction. Both prepare methods
keep reentry poisoning first, then reject unconfigured/not-ready and missing
Space/Locations/Routes/WorldRoutes/Budget owners before companion reads. The
new test covers fresh and configure-only owners, each missing collaborator,
unchanged real banks/candidates/lease, and successful actual BRACE after
restoration. `review-1-to-2.patch` is the narrow production correction. Full
tracked changes are in `changes.patch`; the new test has a complete `.gd.txt`
snapshot because untracked files are not emitted by `git diff`.

Root independently accepted the corrected component, verified all six pins
and reproduced the census exactly. Byte-exact original review records and
their source locators are in `independent-review/`. The reviewer did not repeat
the engine runs. No executable changed after this source freeze.

## Executed validation

`candidate-9` passes the corrected focused suite: 12 tests / 736 assertions /
0 failures, all strict/raw diagnostics and leaks zero, analyzer 0 warnings in
5 files. Source/project/registry/assets restoration is recorded in its
`invocation.json`. `final-1` is the paired final run against the same corrected
source pins; its exact commands, strict singleton summaries and restoration
record are retained alongside the focused result. It passed all seven suites:

| Suite | Tests | Assertions |
| --- | ---: | ---: |
| Ordinary Room phase refresh | 12 | 736 |
| Locations | 61 | 1,875 |
| Existing phase companions | 13 | 234 |
| Ordinary phase structure | 19 | 240 |
| World structure | 6 | 64 |
| EntryWorld paid composition | 33 | 10,790 |
| Connector Placements | 29 | 4,004 |
| **Total** | **173** | **17,943** |

Every suite has zero failures, strict/raw errors, warnings, expected/tolerated
diagnostics and leaks. The final analyzer reports zero warnings in all five
selected source/test files; clean-import diagnostics are also zero. The exact
final source pins and all project/registry/assets restoration checks pass.
`final-summary.json` derives the totals from the seven official shard reports.

The dedicated phase suite uses actual full Room identities, Sites, Project,
Funding, Inventory, worker labor and the real spatial companions. It covers
the paid BRACE/CUT/FINISH sequence, opening source revision refresh, zero-live-
Placement operation, ordinary versus entry Corridor, original tuple and cold
replacement, discarded-companion publication attempts, mutable borrowed
context cleanup, and worker-free COMMIT/CANCEL retry. Body, contact, terrain
extent and structural qualification in this component fixture remain explicitly
synthetic. This is not an actual 1152 provider or production source acceptance.

The existing Locations suite covers complete payload copies and unchanged
outputs for absent/range/shape/stale source/full generation/prepared/budget
refusal, with no observing source callback or cold lease.

Earlier runs remain separate: candidates 1–2 retain test parser failures;
candidate 3 retains omitted fixture Region metadata; candidate 4 retains the
iterator caller-buffer shape correction. Candidates 5–8 and `regression-1`
retain their exact earlier source pins and outcomes. They are not relabeled as
the final corrected source. `diagnostic-source-1` is the earlier explicit
consumer snapshot, not a separate reviewed implementation.

Run the isolated checks from the worktree root:

```sh
python3 -B docs/validation/evidence/underground-room-phase-refresh-2026-10-04/reproduce.py --out /absolute/fresh/output-directory --port 6343
python3 -B docs/validation/evidence/underground-room-phase-refresh-2026-10-04/census.py
```

The harness defaults to the new phase suite, existing phase companions,
ordinary phase/world structure and Locations. Repeat `--suite` to select the
exact additional EntryWorld and Placement suites recorded in `final-1`.
Each output directory must be new. It uses a unique Godot user directory,
parks only this checkout's optional demo assets, creates a clean import,
rejects raw import diagnostics, runs official strict singleton shards and the
zero-warning analyzer, then restores original project/import sidecars/assets.
No diagnostic registry allowance is added.

## Storage and work scope

Run the original `census.py` in this directory. Review-directory copies are
historical snapshots; `source-review-2/census.py.txt` is deliberately not a
second executable. The source census checks unchanged top-level members,
allocation call sites and all five shared Locations packet definitions.

- New retained bytes, packed columns, arrays, capacities and arenas: zero.
- The same 128-byte PhaseContext remains counted once. Placement controls stay
  1,895 / 2,048 bytes, including the existing 576-byte helper reservation.
- Complete ordinary preparation chain: 564 / 576 numeric bytes. Initial scope
  chain: 292 bytes. Final installed-source chain: 512 bytes.
- Iterator chain plus fixed caller Record/ref and expression allowance:
  308 / 512 bytes. Each returned live row precharges `256 + 4 * source_capacity`
  against the actual immutable Domain. It does not scan all Locations or
  Regions or retain a cursor/hint.
- Sequential cold peaks are 691,024 bytes for Locations with the existing two
  Authority Plans, then 526,800 for WorldRoutes. Both fit the original
  1,048,960-byte cold reserve; Locations drops its proof before WorldRoutes.

The existing 40-byte provider preparation and 56-byte final callback allowances
are counted once here. Additional 1152 provider frames and retained WorkFace
scratch must be accounted in that provider's joint contribution. Its large
WorkFace proof must be released before companion preparation. This packet
does not claim that integration's memory or source qualification. Engine
Variant/reference/allocator memory, target timing and production physical
permissions remain unqualified.
