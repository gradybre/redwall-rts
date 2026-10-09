# 1072 — Joint underground state and allocation pack

2026-10-03. Engineering reconciliation of the reviewed 1064, 1065, 1073,
1075–1079 components. The player's approved room workflow is unchanged.
These are finite technical allocations, not new room-count gameplay rules.
Runtime memory, actual movement and composed save/load remain qualification
work; this record does not permit activation by itself.

## Mandatory state, existing owner identity

The registry advances to `RWL-CANONICAL-REGISTRY-2026-10-03-UG4`, version11.
Section1 becomes4, section6 becomes5 and section7 becomes6. Five owner blocks
add67 persistent packed fields and14 scalar records:61 owners,764 declared
fields,756 hashed records and671 persistent packed source fields in total.
All old field ordinals remain unchanged.

| Owner | Section/schema | Added records | Contract |
|---|---|---:|---|
| `underground_space_owner` | 1/1 | 33 | Two capacity scalars,18-I64 domain/header,19 region columns and11 external-source columns. Header and scalar capacities must agree. Only the live bank is canonical. |
| `modular_projects` | 6/1 | 4 | Accepted full Job and Construction identities, keyed by actual Job row; mutable requester refs cannot reconstruct these bindings. |
| `spoil_tips` | 6/1 | 20 | Full World, capacity/count and lifetime compacted/reclaimed counters;14 packed lifecycle, quantity, claim and retained-work columns. |
| `inventory` extension | 6/1 | 8 | Configured capacity, full spatial World and five sparse full endpoint/payload-revision columns. Same actual Inventory instance as section7. |
| `room_layout` | 6/1 | 16 | Exact three configured capacities and13 retained Room binding/mode/draft/accepted-receipt columns. Receipts never grant installed service. |

The existing section6 Funding block becomes schema2. Its `_lost_milli` keeps
its ordinal and grows from256 to768 I64 entries: three protected purpose
domains, in purpose-then-item order. The existing section7 Inventory block
becomes schema5 because `_c_anchor_tile=-2-row` requires its mandatory section6
endpoint counterpart. Legacy Inventory owner4 remains frozen and refuses live
spatial state; changing this declaration does not rename an old codec into a
new working implementation.

Sparse Space, Tips and endpoint arrays have explicit dynamic count records.
Tips work/retained-q columns additionally have protected strides4 and2.
These records describe full allocated arrays, including inactive retained
generations. They are not used-prefix lists and cannot be truncated to live
count. Capacities are immutable per world, source constructor bounds remain
in force, and the decoder must also satisfy the joint allocation pack. The
capacity audit lists these dynamic shapes separately rather than falsely
claiming that a caller parameter is a source-proved fixed maximum. Existing
capacity proof grammar and all previous membership/type gates remain strict.

RoomLayout's earlier unresolved classification is settled as persistent
section6 state. UG16 must implement its actual codec, reject stale Room/project
refs and incompatible purpose/geometry, preserve per-room mode and drafts, and
rebind callbacks only after the full world validates. All new codecs remain
explicit release blockers; no subset digest or helper round-trip closes them.

The declaration occupies23573 logical bytes:61×16 +764×15 +11137 key bytes.
Its2388-byte increase is shared once. Source snapshot hashes identify the
reviewed inputs; unrelated inherited hashes retain their historical meaning.

## One simultaneous allocation pack

Use R=6144 spatial regions, O=2048 source rows, P=256 cached physical proofs,
K=8192 combined cold phase volumes/fragments,256 physical tips,256 retained
layout Rooms,1024 draft/receipt placements,1024 static Locations and1024 sparse
Inventory endpoints. These limits fit together; their independent constructor
maxima do not. An exhausted technical arena must refuse atomically before paid
work, identity allocation or geometry publication.

| Additional allocation or reserved envelope | Bytes |
|---|---:|
| Sparse owner, both banks/heaps/change scratch:149R+92O+288 | 1104160 |
| Phase proof cache and prepared row:69P+60 | 17724 |
| Shared geometry cold peak:120K+32O+384 | 1048960 |
| Known numeric Space/Authority/source/cold controls | 686 |
| Tips live/indexes and conservative cold image:107T+65536+48+119T | 123440 |
| RoomLayout retained packed rows:13L+33F | 37120 |
| Shared Router/Funding/three quotes and cold copies | 271003 |
| Actual Locations, support/topology and their staging envelope | 1048576 |
| Inventory endpoint live/image/conversion/control envelope | 131072 |
| Actual source-bound profile catalog and loader envelope | 262144 |
| Authored terrain content and staging envelope | 131072 |
| RoomLayout snapshot/validation/draft cold envelope | 262144 |
| Bindings, new controls, native growth and pending composition envelope | 524288 |
| Total new mutable payload and reserved obligations | 4962389 |

Router/Funding's271003 bytes are8192 for the widened loss array live/cold,
552 for three112-packed+72-numeric Quotes,262144 for four accepted Job/project
columns and one cold image,32 delivery scratch,67 Router numeric controls and
16 Work pending/publication identity bytes. It borrows the existing one paid
receipt arena and existing Inventory/Reservations journals. No second arena
is silently charged at zero.

The wider live loss array contributes4096 through the existing §3 Funding row.
The other4958293 bytes have one explicit §2.3 allocation row. No byte is charged
twice. Existing8388608 allocator reserve remains unchanged. The new logical
payload is91566546; with that reserve,99955154, leaving44846 below decimal100MB.
The already rejected two-world design grows to185272007 bytes including the
same reserve. Disk-backed rollback remains required.

The envelopes are obligations, not observations. Inventory's1024 endpoints
require24576 live,24576 image and8192 conversion bytes before controls/native
headers. Locations' reviewed proposed schema needs228N+256 for both banks and
106N+128 for one wire. The profile proposal is226944 bytes before independently
verified bounds. All further arrays, container growth, callback frames, object
headers and coexisting load state must be charged to the relevant remaining
envelope before composition. Known examples inside the bindings envelope are
SpoilWork's82 numeric bytes, the shared cold lease's32, Inventory's extra
spatial controls, retained Tips/Layout numeric controls,1079's at-most90 helper
frame bytes and1081's proposed91 controls. Their native cost is not asserted.

## Cold lifetimes and admission

`underground_budget.gd` contains the pack and one shared cold lease per actual
world. `acquire` refuses a second operation; `extend` charges nested simultaneous
images before allocation; `covers` attests the active token and retained bytes;
`release` accepts only the exact token after every charged object is discarded.
Zero, negative, oversized and overflow requests change no reservation. Tokens
never wrap. The exact arena instance must be part of actual owner binding; a
matching integer from another world is not authority. No lease grants gameplay
permission, body clearance or a save/load certificate.

At this pack a Space wire is503952 bytes. Three generic RoomSpace surveys are
983040 bytes before any Plan/contacts; neither is the old provisional482448 or
958464 estimate. Physical phase validation, generic editing and wire capture
share the1048960 cold ceiling. Their independent maxima cannot coexist.
Nested Location/furniture companions must extend the same operation's charge,
or the whole operation refuses unchanged. The actual world binding must call
this gate before constructing snapshots; merely having this helper available
does not prove that integration has happened.

`tools/underground_memory_budget.py` derives real packed widths and resize
expressions at this explicit pack, retains source pins and refuses unpriced
columns or an over-budget combined pack. It does not measure native allocation
or treat unfinished providers as zero. The exact ledger, shared admission
consumers and final measured high-water mark remain separate checks.

## Verification

Independent review accepted this component/allocation-helper scope with no
high/medium blocker, reproduced the source census, and ran all13 new Python
pack tests. The existing190 capacity-audit checks and all32 spec commands pass.
New pack artifact and refusal checks are also included in CI's contracts job.
A historical validator now selects the exact section7 Inventory owner instead
of an ambiguous owner name; none of its frozen field-prefix checks changed.

Clean focused strict runs reported:

```text
6 test(s), 58 assertion(s), 0 failure(s)
60 test(s), 4724 assertion(s), 0 failure(s)
diagnostics: 0 unexpected error(s), 0 unexpected warning(s), 0 expected, 0 tolerated; leaked at exit: 0 object(s), 0 resource(s)
log: 0 unexpected error(s), 0 unexpected warning(s); leaked at exit: 0 object(s), 0 resource(s).
0 GDScript warning(s) in 0 of 4 file(s)
```

Both suites emitted the same strict/raw zero footers. [Raw attempts, accepted
checks, exact commands and source pins](../validation/evidence/underground-joint-budget-2026-10-03/README.md)
retain the initial historical-validator failure and one corrected new test
expectation. No full-suite, playable, composed-save or native-RAM acceptance is
claimed from these focused checks.
