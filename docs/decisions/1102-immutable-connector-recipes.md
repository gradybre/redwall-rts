# 1102 — Immutable connector installation recipes
Date: 2026-10-03 · Status: Accepted component; actual placement/content activation remains queued

## Decision and implemented scope

Append actual Construction purpose8, CONNECTOR_INSTALL, after the existing
spatial Furniture6 and spoil-tip7. Keep all existing numbers and the frozen
four-purpose legacy codec unchanged. Connector subjects will be local full
placement identities in the actual World, never invented Furniture/Building
refs. Generic entity-subject lookup excludes their namespace. Without the
exact typed purpose owner the real Router refuses every admission.

Use the existing ModularProjects/Construction/Jobs/Work/Gear/Inventory/
Reservations/Funding path, with no additional receipt or job arena. An
independently bound weak connector-purpose owner is the only Router wiring
change. No connector adapter or installed-prefix state is implemented here.
The composed tests use a clearly synthetic purpose owner to verify actual
payment, tool-required earned work, completion and refund boundaries.

Add an immutable source reader for one exact connector variant. It supplies
positive authored bills and work for exact fixed-part ordinals, not geometry,
placement, contact or installation permission. No active recipe file is
created. Missing part rows return CONNECTOR_RECIPE_UNAUTHORED. Frontier hash
and revision are source metadata only; a later actual frontier owner must
attest the geometry and installation dependency they identify.

## Reader contract

`configure(P, required_bytes(P))` admits one finite bank before allocation,
with1<=P<=ConnectorCatalog.MAX_PARTS256. Invalid/huge/short requests refuse,
never truncate. `bind_actual(catalog, items, inventory)` binds exact actual
owners once. `load_file(path, recipe_sha256, recipe_revision, frontier_sha256,
frontier_revision)` permits one successful load; failed first loads clear all
unpublished rows/pins and can retry. There is no replacement or staging bank.

`recipe_into(catalog_row, variant_revision, part_ordinal, recipe_revision,
quote)` verifies all exact pins and actual ownership on each read. Its success
resets the caller's bounded Quote, returns BUILD work with at most the existing
four workers, and leaves the subject null. The resulting price-only quote
cannot itself open an order. Refusal leaves every caller field unchanged.

The source pins include recipe/catalog/frontier revisions and all three
SHA256 hashes, plus actual Catalog variant row and variant revision. Real
Catalog reads validate current Profiles/Levels/World binding; equal variant
numbers in replacement bytes do not inherit an old recipe. Items must still
be registered into the exact Inventory. A post-source actual-registration
check closes late callback rewiring; reentrant loads/reads refuse. A final
static typed SourceFacts leaf then reads actual Catalog/Profile/Level bank
revisions/digests, exact Movement/Residents/Transforms/Level Directory wiring
and the full live World identity without invoking another observation callback.
It adds no bank, state or hash copy. Caller Quote shape is rechecked after all
callbacks and before any reset/write.

Version1 inputs are1..4 distinct lines using the already-frozen six
Construction material names: wood, stone, cloth, iron, rope, wax. Their key
indices are resolved through the actual Items/Inventory composition, not
accepted as arbitrary wire item IDs. Unregistered/missing keys, duplicate
lines, nonpositive work/quantities, hidden trailing values, and integer
mass/refund overflow refuse. This initial namespace is an explicit versioned
format constraint, not authority to treat earth/fill or another material as
free. Expanding it requires the actual material/embedding owner contract.

## Streamed wire and memory

Version1 has a116-byte header: ASCII UGRECP01; u32 version1; I64 recipe,
catalog and frontier revisions; I32 variant row; I64 variant revision; u32
part count; catalog and frontier32-byte digests. Each80-byte row is I32 part
ordinal, I32 input count, I64 positive work, then four slots of eight
zero-padded lowercase ASCII material-name bytes and I64 milli quantity. Part
ordinals are strictly increasing, unique and owned by the exact actual variant.
Unused slots are all zero. The exact8-byte UGREND01 trailer closes the source.
Complete file length and capacity are checked before the finite payload loop.
The same bounded bytes being decoded feed SHA256; no full file/JSON image is
loaded and no second read can hash a different file.

The immutable bank has4 I64 header fields32 bytes plus96 digest bytes, two
P-length I32 columns8P, four-key I32 indices16P, P I64 work8P and four-line
I64 quantities32P. Total64P+128; P256 allocates16512 bytes. The strict test
reflects every actual packed column independently, including the maximum.
One fixed digest32 and actual-part facts36 add68 reusable packed bytes.
Four I64 controls32, three flags3 and one IntResult9 add44 numeric bytes.
Thus112 persistent/reused logical controls precede decoding. Conservatively
count the maximum header116, key slice8, final digest32 and up to224 bytes of
nested reader/decoder/SourceFacts numeric frames even though these peaks are sequential:
492<=512. The constructor's one9-byte IntResult exists before configure; all variable packed allocations require that admission. The admitted logical total is64P+128+512, maximum17024. The longest decode-header/final-leaf stack stays within28 numeric I64-equivalent
slots (224 bytes); source digest and identity helpers are sequential, not an
unaccounted second observer. Existing
Catalog and caller Quote allocations are separate already-owned lifetimes,
not hidden inside this reader. Native packed/Variant headers, source path and
material strings, SHA context and RefCounted/WeakRef overhead remain explicit
unmeasured additions under joint binding/native admission. This is not a native
RAM qualification or permission to allocate an independent maximum in game.

Funding's historical per-item `_lost_milli` grows from768 to1024 I64 entries.
The fourth domain is connector installation: +2048 live bytes and +2048 for
each simultaneous cold image. No old domain changes identity or summation.
The weak Router owner adds no packed authoritative state. The actual immutable
recipe source/hash must join composed save/content validation; canonical memory
and UG16 codec reconciliation remain mandatory before production activation.
Legacy capture already refuses modular purposes and is tested for purpose8.

## Payment, cancellation and future publication

Delivered actual claims fund the same consumed-input WIP owner at WORK start.
No new quantities are deducted at designation. A blocked refund retains the
real receipt; retry returns and records each quantity once. Before WORK the
existing100% return applies; after WORK, REQ-SET-126 returns80%, floored to
milli-U. The fourth loss domain persists after the Project retires. There is
no newly adopted stair earned-work retention across cancellation; ECON's
excavation/tip exception is not silently extended. Installed removal remains
a separate authored operation.

The queued actual adapter must read this bank through the real placement's
immutable variant/frontier/recipe pins; validate actual World/local placement
generation/current Project; and stage all contacts, sources and geometry
companions before payment. The exact Router COMMIT window is required for
non-failing installation/prefix publication after earned work and committed
Funding. Lasting geometry is Corridor-owned, never tied to a retired Project.
Physical Site cuts and brace salvage remain their existing exclusive ledger.

## Source survey and authoring decision

ECON-001 in `docs/underground_economy_hazard_amendment.md` explicitly requires
separate paid stairs/entrance shells and names missing recipes as dependencies.
Its adopted protected-CLIMB assistance recipe is wood1000/rope2000/cloth1000
milli-U and40000mWU per started4096u authored arc. That is rescue equipment,
not this timber stair. GDD analogues are door wood2U/12WU, shelf wood2U/16WU,
fence wood1U/12WU and gate wood6U+iron1U/90WU.

The demo's tunnel_jobs brace charge is wood250/stone250 milli-U per demo
quantum. tunnel_rules uses16 risers,1250-permille stair work and500-permille
walk speed, one-quantum entrance/exit shafts and started slope-metres for link
quanta. It has no separate installed timber stair or entrance-shell bill.
Its presentation ticks and geometry do not price the adopted physical system.

Decision1101 records Brendan's answer, "Make it cost wood only." The first
2m-wide by0.5m tread with its authored bearer/joinery is wood1000milli-U and
12000mWU; a2x2m timber landing assembly is wood4000milli-U and32000mWU.
The candidate20 treads plus6 landings total wood44000milli-U and432000mWU.
The proposed rope was removed with no wood surcharge; timber joinery replaces
lashings. These adopted values are not emitted as active content in this packet.
They cover those assemblies only. Excavation, entrance roof/portal/shell,
edge protection and additional structural pieces remain separate explicit rows.
One priced assembly may contain several Catalog solid parts: the subsequent
immutable frontier/grouping contract must identify the complete unique included
part set and exactly one bill anchor. Pricing every visual prism independently
would charge the included bearer twice and is forbidden. This reader's exact
part ordinal is a source pin, not permission to infer assembly grouping.
The top landing's thickness cannot overlap natural solid silently; its actual
paid cut/support dependencies must be authored. A natural first-work anchor is
outside the excavation and distinct from that paid landing.

Exact solid parts/bearings, opening targets, streamed cut/frontier dependencies,
source-qualified work/contact patches, authored motion and installed-prefix
publication remain required. No synthetic price, source fixture or passed
component test supplies those production permissions.

## Verification

Two own-worktree CI-style clean imports, the unchanged six strict regressions,
and final corrected recipe/catalog suites produce126 unique tests,8679
assertions,0 failures. Every strict/raw unexpected diagnostic and object/resource
leak count is0. Final complete analyzer:0 warnings in0 of10 files. The tests
cover complete source pins, all256 parts, bad wire/overflow/duplicates,
actual foreign/recycled owners, late source callback rewiring, reentry,
unchanged caller output, exact purpose numbering, real paid Work/Gear and
Inventory refund retry with purpose-separated retained loss. Full integration and
actual grouped recipe-source publication remain separate gates. Independent
root review accepted all ten exact final source pins with no remaining
high/medium finding; review and full raw evidence are retained under
`docs/validation/evidence/underground-ug1102-recipes-2026-10-03/`.


### Independent review correction: last-observer freshness

Root identified a valid same-hash race in the initial candidate: the final
Catalog hash observation could replace actual Profiles or retire/reuse actual
World, while the Catalog's own hash/revision stayed unchanged. Five direct
regressions reproduced the bad accepted quote/load/binding/digest paths:
20 tests,869 assertions,5 failures, with zero unexpected diagnostics/leaks.
That rejected result is retained separately; it is never counted as acceptance.

The stateless typed final-source helper closes the race after the last
observation. It reads current immutable banks and exact source owners directly;
it does not try to fix callback ordering by invoking another observer. Catalog
production source stays unchanged. Direct tests pin zero observer calls,
unchanged actual bank bytes, full tuple/digest/identity refusals, foreign actual
pace ownership, Profile replacement and World generation reuse. There is no
new packed field, control member or arena. The fixed nested-frame allowance
already includes these bounded static helper frames. Final corrected clean
checks are recipes20/869 and Catalog18/332, all strict/raw
diagnostics/leaks/failures0. Root independently accepted the exact corrected
ten-source packet after reading the complete narrow delta and tests; analyzer
reports0 warnings in0 of10 files.


## Joint integration census and canonical shape

The integrated source census charges the fourth loss domain twice:2048 live
bytes and2048 for the simultaneous cold image. The new/reserved increment is
4966485 bytes; declarations23573 bytes; the unchanged aggregate logical pack
is99959250 bytes with40750 bytes remaining below100000000. This remains
source arithmetic, not native RAM or256-resident runtime qualification.

The immutable recipe bank16512 plus its512 fixed allowance is counted within
the existing524288 binding reserve, not charged twice. Known consumers are
Catalog190448, WorldRoutes163840 and Recipes17024, total371312, leaving152976
for other bindings, Placement and native/control growth. That remainder is not
permission to allocate each new subsystem independently. All nine actual
recipe packed columns and their68-byte scratch are independently enumerated.

Canonical excavation_inventory field17 now declares1024 entries and four
ordered domains. Existing offsets0,256,512 remain; connector installation
starts at768. The owner schema changes2→3 and the generated declaration table
follows. An old768-entry state is not complete current state. No composed
codec/migration is claimed. The integration audit caught and corrected the
stale768 declaration before checkpoint acceptance.

Independent construction review found a MEDIUM census-parser defect: replacing
a matching product subexpression without preserving surrounding multiplication
could undercount a changed route reserve. The final tool expands only the
complete exact authored constant declaration; leading and trailing multiplier
mutations both refuse. Review accepted tool SHA256
`c0f2a83f94005d1f5a094a88d891475d17a531aa77c68baa465b0658e9c36821`
and test `734ccde3fe59947b9b43b2d87a52e63f7899b7055849165d2c38c07a3722f862`.
All25 memory regressions pass. Capacity audit190 checks passes with501 equalities
and86 upper bounds; registry coverage129 modules644 rows990 packed columns;
save handoff31 fixtures and61 owners756 canonical records pass. Nine metadata
checks and exact pins are retained in the joint-integration evidence subdirectory.
Two initial wrong-path command launches are retained as invocation errors and
replaced by successful invocations of the actual docs/validation tools.


### Full-checkpoint expectation correction

The clean no-argument60f22f11 checkpoint ran10321 tests/956324 assertions and
found two stale expectations, with zero unexpected diagnostics or leaks. The
canonical test still required three domains/schema2, and the physical256-resident
microbenchmark still required2379776 Funding bytes. The independently reviewed
correction retains exact assertions but requires schema3,1024 entries and
2381824 reflected Funding bytes (+2048 live). No production behavior or diagnostic
allowance changed. Fresh focused strict tests pass110 tests/28650 assertions,
all strict/raw diagnostics and leaks0; the rejected complete run remains in
checkpoint-60f22f11. A new complete checkpoint is required after this correction.

### CI ledger reconciliation after checkpoint499bfd73

CI run37149792747 at499bfd73 failed the unchanged Specification contracts
step `Memory ledger arithmetic`: `ready07_arithmetic.py` still required the
three-domain Funding census. The actual26 packed columns total5220352 bytes,
not5218304. Further stale assumptions retained owner schema2, loss capacity768,
and the pre-1102 joint total. `systems_architecture.md` also omitted the fourth
domain from its actual auxiliary row and conservative cold-image allocation.
This was a ledger/checker omission, not a production or diagnostic failure.

The correction keeps the1066 and1072 historical trail and adds an explicit1102
step of4096 bytes:2048 live loss state and2048 simultaneous cold image. The
current source census subtracts6144 live growth before reconstructing1066;
it does not rewrite that historical baseline or count the growth twice. The
auxiliary row is39758689; the joint allocation row is4960341 after removing
6144 live growth already counted in that auxiliary row. Current payload is
91570642, live plus reserve99959250 and headroom40750. The rejected two-world
alternative is185280199 bytes. Canonical metadata, GDScript, workflows and
strict checks remain unchanged. Native memory and runtime qualification stay
open.

All34 commands from the CI Specification contracts job pass on the correction.
The source arithmetic reports145 field rows,45 allocation rows and131 checked
links; the merge gate reports0 problems. Nine added read-only regressions run
the real checker against current inputs and virtual stale inputs: three/five
loss domains, schema2, an internally balanced768-cell ledger, an omitted cold
image, duplicate live growth, stale headroom and an omitted final trail step.
All nine pass, including required assertion failures for every stale input.
The existing25 joint-memory,190 capacity-audit and58 component-schema checks
also pass. No Godot rerun is warranted for this arithmetic/documentation-only
correction; the parent recorded the independent499bfd73 clean full run as
10321 tests/956322 assertions/0 failures, all unexpected strict/raw diagnostics
and leaks0, and analyzer0/1148.

Evidence, exact commands and the failed remote logs are in
`docs/validation/evidence/underground-ug1102-ledger-2026-10-03/`. Remote shard
and Godot-gate jobs individually succeeded, but the aggregate correctly
refused the failed Specification contracts result. This correction does not
claim a subsequently successful remote run or aggregate coverage audit.
