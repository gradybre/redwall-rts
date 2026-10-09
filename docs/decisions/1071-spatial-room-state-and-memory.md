# 1071 — Spatial Room state, mandatory extension and memory

Date: 2026-10-03 · Status: Engineering reconciliation; verification recorded below

Decision1069 adds two actual authoritative columns: Room spatial domain and
Furniture installation status. A pending Furniture identity is not installed
service capacity, and an underground Room has no exterior parent or flat tile
run. Losing either distinction changes gameplay after restore.

Register these as a mandatory section6 `buildings` extension, schema1, alongside
the existing section4/5 Buildings owners. This explicitly amends the provisional
section4 assignment in the source registry. The fixed legacy section4 surface
format is preserved; the whole registry identity changes to
`RWL-CANONICAL-REGISTRY-2026-10-03-UG3`, version10, section6schema4. The extension
must load and validate atomically with the existing Room/Furniture data in UG16.
It is never an optional section, derived flag, independent owner instance or
permission to omit unknown state. Legacy capture already refuses spatial,
pending and retained non-surface identities. This declaration does not supply a
composed codec or change `release_save_ready=false`.

Exact extension order is `_r_spatial_kind:u8[16384]`, then
`_f_installed:u8[81920]`. Existing keys and ordinals remain unchanged. All free
flags are zero; live surface furniture is installed. The domain permits only
SURFACE=0 and UNDERGROUND=1. Installation flags permit only 0/1 and must agree
with paid project state and the actual service/membership rules.

The independent census becomes56 owners,683 declared fields,675 hashed records
and604 persistent packed source fields. New key text is36 bytes, owner metadata
16 bytes and field metadata30 bytes:82 additional shared declaration bytes.
The sparse spatial owner, tips and the shared modular receipt-domain increment
are separate pending reconciliations, not implied by this census.

The registry refreshes the source pins for this reviewed Buildings increment,
the Sites publication callback and the integrated Gear index. Other inherited
`source_module_sha256` entries remain their historical contract-source snapshots,
as the registry policy states; they do not claim to identify every current file.
This checkpoint retains a separate exact changed-source manifest with its evidence.

## Logical allocation delta

No existing allocation is removed. The exact positive addition is98304
live flag bytes (16384+81920), another98304 for one conservatively simultaneous
cold diagnostic/versioned staging image, and one byte for decision1069's
synchronous Sites publication guard. The separate82 shared declaration bytes
are counted once. The total addition is196691 bytes.

| Quantity | Previous | This increment |
|---|---:|---:|
| Auxiliary payload |39654241|39752545|
| Planned allocated payload |86405078|86601769|
| One world plus8388608 reserve |94793686|94990377|
| Headroom below100000000 |5206314|5009623|
| Additional candidate mutable state |80157855|80354464|
| Rejected two-world peak plus reserve |174951541|175344841|

The source audit must prove both real allocations and the bool guard; the
canonical tests must pin the exact extension fields independently of generated
metadata. Every existing specification and diagnostics gate remains in force.
The whole underground composition remains unqualified: sparse banks, physical
validation snapshots, tips, drafts, profiles, support/contact/topology staging
and restore lifetimes still require joint budget admission and measurement.
Independent constructor maxima must not be treated as one fitting production
allocation pack, and an unimplemented allocation obligation is not zero.

## Verification

Independent review found and corrected a mistaken replacement of the historical
decision0127 reconciliation-trail row. Its original increment and running totals
are restored. The review also exposed a real gate hole: `merge_gate.py` stopped
at a malformed row and silently skipped the remaining history. The gate now
reports malformed rows inside the trail table; negative fixtures cover both a
misplaced allocation row and an unreadable total. A blank line still ends the
Markdown table, so unrelated later tables remain separate.

The focused canonical suite reports55 tests,4100 assertions,zero failures; both
strict diagnostics and raw-log checks report zero unexpected errors/warnings
and zero leaked objects/resources. The analyzer reports zero warnings in two
files. All32 specification commands passed before the review correction; the
changed gates and final provenance are rechecked in the retained evidence. This
is a focused registry result, not whole-world save/load or runtime qualification.

Existing A/source evidence is under
`docs/validation/evidence/underground-ug07-buildings-a-2026-10-03/` and the Sites
publication-window evidence. Those component results do not validate this new
registry declaration or composed save behavior.
