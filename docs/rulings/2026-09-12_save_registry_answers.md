# Executor blocker reconciliation — 2026-09-12

This is the implementation handoff for the seven-item request. Read AGENTS.md,
then this document, [SAVE-R09](2026-09-11_save_codec_contract.md), and
[SAVE-LAYOUT-R01 / RESTORE-R01](2026-09-12_clock_restore_and_layout_followup.md).
The preserved [executor request](requests/2026-09-12_save_registry_request.md)
is evidence, not an instruction that overrides a ruling.

The main planning checkout is `3e094e9`; the inspected executor save worktree is
`197472b9d7f2385ba5eb173aef0ebb0e29511c3e`. The latter contains section codecs and
the life-stage column absent from the former. Do not replace executor code with
older main-checkout files. This handoff changes documentation/schema declarations,
not runtime code, and claims no new Godot test or save-parity pass.

## Disposition

| Item | Answer | What remains |
|---|---|---|
| 1 provenance | PROV-R01 below freezes the complete six-member protected domain | Catalog/compiler, lot validation and producer integration |
| 2 registry | REG-R01 publishes exact keys, types and ordinals for the inspected snapshot, plus required EventSchedule/Chronicle declarations | Changed-branch reconciliation, value adapters, complete bodies, full rules/lookup manifests and parity; the artifact is not release-save certification |
| 3 names | NAME-R02 explicitly permits live anonymous empty names; corrects SAVE-R09-002 | Shared owner validation and transactional §4/§14 load integration |
| 4 S1/S2 | u32 LE byte prefixes; names128 bytes and2–32 scalars; keys256; rules strings4096 | Field-specific caps for any new strings, never a universal allocation permission |
| 5 H1–H4 | Existing SAVE-R09-001/003/004 plus REG-R01's new owner composition | Enforce versions, complete producers/bodies, reject gaps and incompatible state |
| 6 envelopes | Still an engineering measurement gate | Actual body/gear/pose envelope assets and placement/sweep fixtures |
| 7 visual verdict | Astra requests further NARROW evidence/refinement; Brendan's formal verdict remains PENDING | Current-build top/bottom/unbroken-name captures and user review |

## PROV-R01 — complete InventoryProvenance domain

New explicit numbering adopted here, now listed in GDD §4.3. This is a protected
enum, NOT a lexicographically assigned domain. Domain name: **InventoryProvenance**.
All six values are signed-int32 lot values; COUNT is not a member.

| Key | ID | Meaning / producer |
|---|---:|---|
| ORDINARY | 0 | Ordinary harvest, freshwater, crafted/processed output or other explicitly ordinary source; grants no special provenance privilege |
| STARTER | 1 | GDD §5.1 scenario-granted starting inventory |
| COASTAL_BRINE | 2 | Brine taken from an eligible coastal source |
| EXCAVATION | 3 | First excavation of virgin material under ECON-002 |
| BACKFILL_RECLAIM | 4 | Re-excavation of previously embedded backfill |
| SPOIL_RECLAIM | 5 | Recovery from a spoil tip's embedded stock |

The old `UNSET_PROVENANCE=0` is a compatibility spelling for ORDINARY, not a
seventh member and not an unknown numeric wildcard. The default does not prove
coastal collection or a virgin source. Update the catalog's protected-domain
registry, artifact producer, validation, catalog fixture and callers together.
Do not silently retain a three-member ECON-only domain or sort these values.

Salt input requires BOTH the `brine` item and COASTAL_BRINE. Ordinary river/well
water cannot gain eligibility merely by being delivered to a saltpan. All three
earth labels require `excavated_earth`. Source/embedded ledgers, not the label
alone, prove that a corresponding withdrawal/output may occur exactly once.
Ordinary new recipe output is ORDINARY unless its owning contract explicitly
specifies another listed origin; consuming brine does not make salt itself brine.
Transfers, splits, gear moves and input refunds preserve their lot attributes.
Spoilage preserves origin as history, but the new item's identity still controls
eligibility; it never manufactures coastal/virgin-source entitlement. Merging
continues to require identical attributes, including provenance.

This freezes the full domain for the currently specified mechanics. Future new
origins require an explicit amendment, new protected table/catalog identity and
compatibility handling. Existing arbitrary-int test fixtures are not valid saves
under this domain. Refuse old unmatched catalog/rules identities; any development
conversion must be an explicit versioned tool, never reinterpret old1..5 blindly.

Acceptance: exact six-key mapping; missing/extra/renumbered domain fails; -1/6 and
other arbitrary values fail; ORDINARY0 remains ordinary; both brine checks; each
earth producer/withdrawal chain; cancellation/transfer preserves provenance;
new catalog changes compatibility identity. No paid asset calls are needed.

## REG-R01 — ordered registry and block ownership

The machine-readable artifact is
[`planning/canonical_state_registry.json`](../planning/canonical_state_registry.json).
It declares **49 (section,owner) groups and564 canonical records**, including
**512 persisted packed fields** in the inspected executor registry. It includes
explicit scalar declarations and the already specified forward EventSchedule
and Chronicle owners. These numbers apply to the named snapshot, not every
concurrent worktree. A source module/hash inventory is embedded for comparison.

`owner_key`, `field_key`, `ordinal`, type/type_code and owner_schema_version in
this artifact are now adopted declarations. Keep underscores in field keys.
Do not regenerate order from GDScript declaration order, dictionaries, display
labels, directory iteration or this document at runtime. The authoring process
used the classified registry and explicit scalar/ordering choices; runtime uses
the checked-in declaration. The Python validator is read-only.

Each owner has at most ONE block per section. One module may own blocks in
several sections; section1/entity_directory and section3/entity_directory are
distinct blocks with different fields. §3's fixed ordered keys are:
`_active:u8, _generation:i32, _retired:u8, _persistent_id:i32, _kind:i32,
_typed_row:i32`. No duplicate allocator in §3.

The artifact defines the logical field-record stream. It is not itself the
`rules_identity.bin` stream, and its JSON SHA-256 is not a replacement rules
digest. Compile its semantic schemas and all other required owner constants into
SAVE-R09-003's rules manifest; audit the remaining rules/lookup tables separately.
The artifact's provenance comments and source hashes do not enter gameplay hashes.

### Registry growth / absent owners

Register unimplemented stores **on arrival**, except the explicit EventSchedule
and Chronicle declarations already provided by SAVE-R09-005. This is an adopted
development compatibility policy, not permission to omit implemented state.
Change the rules identity and all affected owner/section versions when adding,
removing or changing registered fields, semantics, extents or normalization.
Refuse incompatible development saves until an explicit migration is implemented.
Do not promise old development-save compatibility or fabricate zero-valued
progression/community/hazard stores merely to hold record_count constant.

`release_save_ready=false` is intentional. Final release certification requires
all first-release state, full adapters, source/registry reconciliation, bounded
validation and continuation parity. §15 can now be implemented against exact
keys/types/order; it cannot be passed off as a complete release digest while a
required adapter or live state owner is omitted. The scoped 564-record declaration
must be updated when EH03/EH04 or other concurrent state lands.

### §1 WORLD composition and D2

Retain the **44-byte map provenance prefix** from SAVE-R09-003. Follow it with
`store_count:u32` and owner blocks in ASCII key order, using SAVE-LAYOUT-R01's
wrapper (`owner_key`, owner_schema_version:u32, primary_count:u64,
payload_byte_length:u64). Blocks tile the section remainder with no gaps.

Register `world_runtime` schema1, primary_count1: preserve the executor's exact
80-byte payload and offsets from save_section_world_runtime.gd. Its internal
three reserved bytes remain zero. It binds clock/RNG fields as listed in the
artifact. Do not add directory state to its payload.

Register `entity_directory` schema1, primary_count1, payload **4 bytes**:
`_next_persistent_id:u32 LE`. Valid range1..2147483648 inclusive; 2147483648 is
the exhausted cursor after issuance of the final signed-int32 identity. Live
persistent-ID columns remain i32 and never contain that exhausted cursor.
This changes the allocator's ledger signedness, not its4-byte size.

Directory capture/restore exposes and assigns this cursor explicitly. Validate
it against all positive stored directory IDs: cursor must exceed every one.
Do not derive max(live IDs)+1, including when all entities are dead. Restore §3
and this scalar under the same unpublished barrier. A stale cursor is refusal,
not automatic repair. New-world `clear()` is not a load step.

Required D2 fixtures: create1/2/3, destroy3, save/load, next=4; destroy all then
save/load still next=4; MAX_INT32 issuance survives load as exhausted; invalid0,
2147483649 and cursor≤stored ID fail before publication. Pin exhausted bytes
`00000080`. No generation/retirement or bare-row namespace is merged with it.

The completed tick appears once in the canonical prefix, not again as a typed
record. Debt and six clock counters persist in the80-byte body but contribute
no canonical field record. Do not concatenate the helper's old21-byte
`canonical_bytes_of()` contribution as an extra header or silently hash debt.
RESTORE-R01 supersedes old helper comments about transient LOAD-bit mutation
and a debt ceiling of INT64_MAX/4: validate representability as ruled, then use
checked arithmetic in the scheduler; do not quietly reduce stored debt.

Other §1 owners retain the artifact's separate keys and bounded field schemas.
Their value adapters must explicitly validate full extents/unused rules; source
registry prose such as “free row” does not stand in for that validator.

### §14 NAME_POOL wrapper and §3 field keys

Register **residents**, owner schema1, primary_count512. Section14 is
`store_count:u32=1`, the standard owner wrapper, then the existing payload:
`row_count:u32=512` followed by512 `utf8_u32` strings in physical slot order.
Retain its existing inner count; validate both counts. Payload length is
`4 + sum(4 + utf8_byte_length(name[slot]))`; cap it at67588 bytes. Owner-key
length9 makes wrapper33 bytes; total section cap67625 bytes including store_count.
The canonical record is `(14,"residents","_name_key",type5,count512,values)`;
neither the two framing counts nor owner wrapper become extra canonical records.

Section14 schema becomes2 because its previously exercised unwrapped payload
was different. §3 retains schema1 and its six source keys, now binding, not a
labelled proposal. Name/occupancy agreement is validated before any setter can
rewrite the incoming `_named` flag; “apply names last” must not conceal corruption.

### Other framing, versions and remaining work

Use the standard owner wrapper for §§4/5/6/7/8/9. Explicit field extents come
from the owning schema, not the descriptor's row_count. Module owners containing
several differently sized logical tables need an explicitly validated primary
count and child extents before their wire body is frozen; the logical registry
does not authorize guessing these from the first column. Finish those adapters
with each store owner rather than seeking a new gameplay preference.

Preserve the distinct existing forms of §10, §11, §12, §13 and §15 in SAVE-R09 /
SAVE-LAYOUT-R01. §10 is112 bytes, including its leading stream-count u32; an older
108-byte helper comment is not the current contract. EventSchedule owns §11;
Chronicle owns §13, with canonical count and rolling digest; canonical_state_hash
owns §15 and never includes itself. Missing producers cannot be waved through
by feeding a digest of a subset or arbitrary empty bytes.

**Additional reconciliation found:** movement._profile_revision is mutable
category1 state assigned to §2 in the inspected registry. An opaque catalog JSON
alone cannot carry it. For §2 schema2 retain the u32-length-prefixed exact catalog
artifact, then append a standard owner-block list: one `movement` schema1 block,
primary_count4, payload `element_count:u64=4` then four `_profile_revision:i32`.
The immutable artifact and its catalog digest are unchanged by a live revision;
the separate typed canonical record includes that revision. Reject a reader
claiming the JSON alone restores §2. Do not serialize immutable catalog tables
a second time. Future movement profile layouts require another version bump.

Baseline section versions for this composition, by IDs1..15:
**[2,2,1,2,1,1,2,1,2,1,1,2,1,2,1]**.
Reasons: §1 composition/allocator, §2 mutable extension, §4 LifeStage, §7 protected
provenance, §9 exact-start navigation semantics, §14 wrapper; §12 was already2.
Owning versions in JSON distinguish resident2, inventory2 and navigation2.
Other versions start1. Compare later landed schemas before reuse: this vector
is a baseline, never permission to reuse2 for a different future layout.

Inventory free-stack counts occur before their used prefixes; preserve stack
order, validate counts against occupancy/retirement, rebuild other derived
counts. Navigation partial search, arena used-prefix and queue progress remain
required. All directory/container/lot/route generation spaces stay distinct;
gear and reservations have no invented generation and cannot be compacted.

## NAME-R02 — live anonymity and validation

This corrects SAVE-R09-002, under REQ-SET-040/041:

| Resident row | named | name |
|---|---:|---|
| Free | 0 | empty |
| Present anonymous (including live residents) | 0 | empty |
| Present named | 1 | nonempty valid personal name |

Retained dead/departed rows follow their owning occupancy/lifecycle rule; do not
erase their identity merely because is_alive() is false. A named row cannot
have an empty name; an anonymous row cannot hide a nonempty name.

One resident-owned validator is shared by set_name(), naming commands, automatic
name assignment, save capture and restore. Nonempty names: strict UTF-8, at most
128 bytes,2–32 Unicode scalar values; reject C0 U+0000..001F and DEL/C1
U+007F..009F. Do not count bytes or grapheme clusters as scalar length. Do not
normalize, truncate or replace invalid input. This is an explicit control-code
predicate, not an unversioned call to an engine Unicode category database.
Empty remains legal for creation/restore of anonymous rows; player alias entry
does not gain a “clear personal identity” action. Restore may install an earlier
valid anonymous snapshot without operational naming triggers.

N3 acceptance includes direct setter calls (not only commands),40 ASCII chars,
C0/DEL/C1,1/2/32/33 scalars, multibyte and supplementary-plane strings, anonymous
starter roundtrip and both flag/string mismatches. Refusal changes no state.

## S1/S2 and H1–H4 — answers already owned

S1: u32 little-endian **UTF-8 byte length**, not character count. S2: name cap128;
owner/field/rules/lookup keys256 nonempty ASCII; rules-manifest string values4096;
name-pool arena131072 independently. Newly freeze the engine identity line cap
at256 UTF-8 bytes, including its final LF. Fixed binary tags and embedded JSON
retain their own formats. A new string field requires its own bounded schema.

H1: RWLSET01 outer format1,256-byte header,15×64-byte descriptors. Follow the
section vector and semantic-version policy above; unknown/incompatible versions
refuse. The outer format changes only if header/descriptor interpretation changes.

H2: five compatibility hashes are **rules, catalog, map, lookup, engine**. The
sixth header digest is **body SHA-256**, not a sixth compatibility domain. §15's
canonical logical-state digest is separate again. SAVE-R09-003 defines each
producer exactly; complete explicit rules/lookup owner inventories are still
required implementation artifacts. Neither test-fixture hashes nor the JSON
registry's file hash substitute for those artifacts.

H3: every section body requires its owning complete payload and compatible
version; this registry resolves record identity but does not certify missing
body encoders. H4: descriptors are ordered1..15, first body offset1216, every
next offset equals prior end, final end equals file length. No gaps, overlap,
unknown sections, alignment padding or trailing bytes. Body digest covers bytes
[256,EOF), including descriptors and §15. Bounds are checked before allocation.

## Engineering work may proceed

1. **Load owner:** wire the existing begin_load grant into one orchestrator.
   Prevalidate/checkpoint, hold the out-of-band barrier, restore WORLD/directory
   before dependent components, cross-check §4/§14, install names only after
   component validation, rebuild derived indexes, verify §15, then publish once.
   Rebind callbacks and seed/equipment authorities before audits/consumers, but
   never pump during restore. Roll back under the same barrier on failure.
   No second full mutable world; use RESTORE-R01's bounded staging/disk rollback.
2. **Inventory/StockAge owner:** wire the seed-expiry authority already built in
   the executor branch, after collaborators exist and before consumers run.
   Exercise exact expiry at reserve AND commit, existing claims, conversion
   failure and critical-pause recovery. The planning checkout's absence is not
   evidence that Claude's API must be rebuilt.
3. **UI owner:** cache generation-checked resident reference and persistent ID
   with each roster row. A stale click must never select the replacement at the
   same bare slot. Test despawn/reuse/click/refreshed selection.
4. **Work/logistics owner:** the existing planner already delivers forage demand
   through DESIGNATE_ZONE/SET_POLICY. First-plant command delivery, harvest cargo
   commit, sowing performer and physical water supply remain distinct unfinished
   seams. Keep real refusals; do not mark the whole planner wired from one callback.
   Harvest collection needs one preflight/commit spanning claim, source/quota and
   cargo; failure leaves all unchanged. Seed250 milli-U consumption and SOWN
   transition are atomic once at productive start; retain4-WU work across workers.
   Dry tending needs the inherited0.25 U water delivered/consumed before inputs
   become satisfied. No water supplier means GATE_UNAVAILABLE, not free water.
5. **Danger owner:** adopt the maximum effective tile band over a designation's
   finite tile set. Effective tile danger follows existing hall/lookout rules;
   natural basin danger remains separate for yield/work. Derive it at command
   commit; never trust a lower client-supplied band. Invalidate/revalidate affected
   queued and assigned work when staffed coverage changes. Route exposure remains
   a separate movement/consent obligation; a safe destination does not prove safe
   travel. Test forged0 over danger3 and loss of staffed lookout coverage.

Do not give several agents ownership of the shared registry, catalog artifact or
dispatcher at once. Suggested independent lanes: save/registry coder; inventory
and name owner; logistics/planner coder; UI reviewer/fixer. Integration lead owns
cross-store ordering and shared-file reconciliation. Test-runner runs focused
fixtures after each change; independent reviewer checks namespace/atomicity and
then full repository checks. The existing optimized subagent roles still apply.

### PLAN-CMD-R01 — first planting has an explicit command

Adopt this new payload contract within existing `SET_FIELD_ROTATION`; do not add
a25th command kind. Target is a generation-checked FARM-zone EntityRef.
`arg0=0` edits rotation; `arg0=1` confirms first planting. `arg1=1` is payload
schema1. Flags, reserved_zero and unused goal coordinates are0.

Edit payload: `count:i32=3, crop_id:i32[3]`,16 bytes, rotation order. Validate
all three compiled CropDefinition IDs, then call FieldPolicy.set_rotation();
this neither opens a cycle nor starts sowing.

Confirm payload: `plot_count:i32, crop_id:i32, (plot_slot:i32,
plot_generation:i32)[plot_count]`, length8+8×count, maximum32776 bytes.
Require1..4096 unique refs sorted by directory slot, live EMPTY FarmPlots belonging
to the target field, with a live FieldPolicy and valid explicit crop. Preflight
the complete command's references, membership, cycle/request state and required
record capacity before mutation. Bind the per-field cycle ordinal to each
planner plot request; the rotation cursor is not a cycle identifier. Apply
REQ-SET-070's per-plot eligibility gates before publishing productive sowing jobs;
unavailable seed/window/access remains an explicit unmet request, never free
progress. Invalid payload or inability to record the complete request refuses
atomically without creating a partial cycle.

Do not change existing SET_POLICY selectors0/1 or hide planting confirmation in
a policy toggle. Queue identity remains `(execute_tick,player_id,unsigned
sequence)`; work identity is `(plot EntityRef,SOW,field cycle)`. Duplicate delivery
of a still-open request cannot open a second cycle. Replay progress must be
persisted before closed-cycle replays can be considered supported; the existing
forage source-intent ledger is not a planting-history ledger. The planner owner
must add that necessary future-affecting state to REG-R01 with explicit bounds
and version changes, or retain an explicit unsupported-replay refusal. This
payload ruling does not pretend that replay mechanism is already implemented.

Accept: edit never plants; confirm creates one identified cycle/request set;
stale or cross-field refs and duplicates refuse; failed seed reservation consumes
nothing; repeated command never duplicates a cycle or completed harvest.

## MOVE-G01 and ART-UI-12

A clearance domain does not supply a measured envelope. G01 still needs each
supported species/stage/profile, body pose, clothing/gear/cargo envelope,
anchor convention, directional transitions and conservative integer bound,
with asset provenance and placement/swept-contact fixtures. A height scale or
four starter profiles alone cannot close full release coverage. Independent
schema, inventory and load work can continue. Four levels/4 m remain candidates;
this handoff does not close G02–G05 or authorize arbitrary collision dimensions.

Actual runtime captures from UI commit ea531d3 (merged e127f63), inspected here:
[short name](../validation/evidence/astra-review-2026-09-12/28_identity_narrow_1280x720_150_short.png)
and [32-character name](../validation/evidence/astra-review-2026-09-12/29_identity_narrow_1280x720_150_name32.png).
They are runtime UI fixtures with “No world generated”, not screenshots of a
complete colony or evidence of terrain contrast. Both show the side-by-side
medallion/name correction; the three-line name leaves only Health and Fullness
visible before scrolling. Those observations do not prove body usability.

**Astra review: CHANGES_REQUESTED / additional evidence required. Brendan's
formal ART-UI-12 verdict: PENDING.** Composition: the identity is readable, but
Overview and the fixed header consume a large fraction of the NARROW pane.
Material craft: edges/binding exist; assess at current native resolution rather
than this capture alone. Illustration: a mouse medallion is visible; this does
not establish four-species/family coherence. Typography: short and wrapped long
names fit visibly; no pass yet for an unbroken32-scalar name. Setting identity:
forest/oak/journal cues are present, but no terrain-context verdict is established.

Capture the CURRENT build at1280×720/150% with32-character spaced and unbroken
names, body at top and bottom, keyboard focus on the final reachable action,
plus STANDARD/WIDE over actual terrain. Record commit, viewport, UI scale and
profile. Keep full names, font minima and fixed Close/Center targets; do not
solve body height by shrinking text or silently changing the header contract.
Demonstrate usable scroll/focus first; propose any necessary layout amendment
with before/after captures. Functional tests remain separate from visual approval.

## Evidence and exact next step

Run `python3 docs/validation/validate_save_registry_handoff.py` for artifact and
independent name/cursor fixtures. `--source-root PATH` additionally compares
packed membership/types to that checkout; use the named executor snapshot or a
reconciled successor. `--require-release-ready` must refuse this incomplete
release state. These checks are not Godot codec, load, or performance tests.

**Next implementation increment:** reconcile the registry against the executor
integration HEAD; implement PROV-R01 catalog binding and NAME-R02 setter checks
in parallel with §1 directory-cursor / §14 wrapper integration. Then implement
the canonical field walker and complete missing owner adapters/bodies before
load orchestration and cross-process parity. Log actual failures and evidence.
