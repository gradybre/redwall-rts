# 1123 — Source-qualified cardinal mole profiles

Date: 2026-10-04
Status: implementation in progress; no newly qualified runtime profile yet.

## Decision and scope

The accepted version3 source program has fourteen clips and six immutable
roles: stand0, ground-walk1, downward-work2, high-wall3, planted-front4 and
INSTALL5. Its native replay is a presentation witness with synthetic profile
flags. First-prefix composition needs an actual source-certified UGPROF01
artifact; fixture certificate bits cannot supply this missing content.

The artifact keeps the existing all-yaw stand/walk rows0/1. Four exact work
headings use the fixed order0,16384,32768,49152; each heading owns down/high/
front/INSTALL in that order. Row IDs are2+4*heading_ordinal+work_role_ordinal,
so the accepted yaw0 row IDs2–5 are preserved. The complete18-row map reaches,
but does not enlarge, Profiles'16-variant per-physical-key limit. Work kind is
actual BUILD, equipped item is the existing generic tool with BASIC manufacture,
source is adult mole/rig_mole_v1, and cargo is absent. No carried timber, climb
state, other manufacture or additional species is inferred from these rows.

Actual native WorldBasis coefficients, every original primitive, source timing,
loop edge, shared ready hub, exact recovery, numerical residual and source-bound
contact witness remain required. Cardinal labels never round the native basis
into a mathematical quarter turn. Every published role is already oriented;
world owners translate it without rotating it again. Exact point/planar patch
semantics remain unchanged. The source compiler must refuse any missing proof,
unknown source or unclosed finite operation bound before publishing certificate
bits. Qualified source geometry still grants no World support, paid target,
work credit, pace, route, loose bearer or finished installation permission.

## Driver protocol4

The new explicit protocol4 consumes the same14 source clips with18 immutable
(profile,revision,content) tuples. Protocols1–3 retain their original behavior.
`step_profile_into(profile_id, job, delta_q16, request_ready, out)` selects an
exact admitted catalog row and maps it back to one of the six source roles.
Ordinary logical-role `step_into` refuses productive protocol4 calls; it cannot
silently choose a heading. Cold binding checks the exact row/role/heading map,
source digest and actual species/stage/rig/tool identity. Actual Job/Work/Gear,
cargo and yaw are still read on every update. The existing retained role/root/
yaw observation forbids a productive heading change before the proved return
through ready. No new phase column, movement write or economic timer is added.

The18 tuples add288 packed bytes: maximum driver payload720 rather than432.
This is presentation storage; no simulation reserve or per-client peak is
silently enlarged. Caller Frame,400+18-byte cold descriptor/hash scratch and
native object/frame costs remain separately accounted. The source image and
shared WorldBasis stay borrowed once rather than copied per actor.

## Artifact and ownership

The initial18 descriptors,194 role boxes and one32-byte actor-image digest
would use7,268 wire bytes (40+32+18*98+194*28) and14,520 paired-bank bytes
(2*(32+32+18*98+194*28)). Existing Profiles caps, two-bank loader, replacement
rules and262,144-byte reservation remain unchanged. A source-derived widening
or partition may change this census only after review; it cannot exceed12
boxes per selected row or silently drop a primitive. No third decoded image
is retained. The source manifest additionally pins program, role map, engine/
backend, WorldBasis, finite Domain roots and actual consumers.

Owned implementation paths are new `mole-worker/compile_profile_publication.py`,
its Python test, `mole-worker/profile-publication-v1/`, the already leased
`test_mole_qualified_profiles.gd`, and the existing mole driver/test pair.
Additional uniquely named proof/native helpers stay under its existing
`evidence/contact-qualification/` subtree. Existing accepted source/evidence
remains immutable. Runtime World/Routes/Contacts/Frontier and material-handling
owners remain other lanes; their synthetic first-prefix fixtures must not be
relabelled as physical qualification by this content publication.

## Reviewed driver increment

The protocol4 driver and tests were independently accepted on 2026-10-04
at source523aaad9… and testcd07f7f9…. The normal clean-import CI singleton
shard reported15 tests,472 assertions,0 failures; strict and raw unexpected
diagnostics and leaks were all zero. The changed-file analyzer reported
0 warnings in0 of2 files. Source pins and raw logs live in
`mole-worker/evidence/contact-qualification/review-cardinal-driver-v1/` and
`driver-cardinal-check-v1/`. This accepts only the driver contract; the actual
cardinal source artifact and first-prefix activation remain in progress.
