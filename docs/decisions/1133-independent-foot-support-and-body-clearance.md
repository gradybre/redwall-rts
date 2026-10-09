# 1133 — Prove foot support independently from body clearance

Date: 2026-10-04 · Status: accepted for the bounded geometry component

The existing Location record already has distinct `support` and `envelope`
boxes. Support describes the real footing under the source's stance; the
envelope describes the independently proved body, held tool, approach and
recovery air. Requiring support to contain the whole horizontal air envelope
incorrectly turns an overhanging tool into a demand for additional floor.

EntryBindings forms support from the selected immutable `STANCE_SUPPORT`
rows, preserving their complete bounds. It retains the conservative union
of every above-plane `BODY_HELD_LOAD`, `TURN_RECOVERY` and `WORK_APPROACH` row
for air. Every below-plane occupied residual must still be covered by the exact
authored stance union; this is not permission to clip a motion or ignore dirt.
The representable contact has one horizontal root plane. Other stance shapes
refuse rather than acquire a new gait or support rule.

Locations requires the root on the support's top plane and inside its
horizontal footprint. It will separately prove the entire support box against
actual SUPPORT and the entire air box against actual SUPPORTED_VOID, retaining
all physical blockers, exact full section/owner identity and paid installed
datum witnesses. WORK/STORAGE section containment uses the support footprint;
TRANSIT retains its existing exact point containment. A section grants no air
outside itself: that air still needs its own complete physical coverage.
Refresh, restore and the decision1130 prepared-observation bracket keep these
same proofs and original transaction identities.

SurfaceAnchor uses the same independent root/foot/air rule. Shared surface
metadata contains the support footprint. Actual exterior, natural footing,
exclusions and retained-source checks remain mandatory before the original
Space/Location publication window. No body-only gap becomes natural support.

The implementation reuses existing six-I32 Record fields and fixed Entry
scratch. There are no new retained fields, banks, source flags or wire schema.
Every source-row loop keeps a finite comparison charge, including24 comparisons
per immutable profile box. The reproducible source census records zero retained
or variable-cold delta; the complete own/helper chains remain within the
unchanged Entry2048, nested-reader512 and SurfaceAnchor2048 allowances.

The geometry fixture loads the exact historical published mole wire
`profile-publication-v1/mole-worker.ugprof`, SHA-256
`b8033048f55d38ff477388bc6be528a096fd847d040c24faaf374a5e8cfea0ac`,
through the real Profiles reader at 18 profiles/194 boxes/content revision 1.
It changes no certificate or box. This fixture is deliberately separate from
production `MoleCatalog.load_into`: its historical consumer hashes no longer
match the current runtime, and the production source-closure refusal must
remain tested. Source-derived 812u ground stance still cannot fit the 512u T0
tread. Raised paid WIP contact, source-phase stair motion, current backend
qualification and actual world activation remain separate work.

Ownership is limited to EntryBindings, Locations, SurfaceAnchor, their existing
tests, a dedicated support/clearance test and this evidence. Routes, Contacts,
the decision1130 prepared-observation test and all published source artifacts
remain unchanged. Baseline is freshly fetched `origin/master`, accepted
integration `7c03d2aa`, then decision1130 `b7f09915` (local `4b30ef4a`)
and accepted1119 `d5ec6a39`/`2974934e` (local HEAD `1a754780`).

The source facts come from decision1123's published roles and the retained
first-entry fit assessment. The parent approved this separation and the narrow
SurfaceAnchor lease on 2026-10-04; numerical recipes and gameplay dimensions
are unchanged.

The exact final six-suite run passed184 tests/16,646 assertions/zero failures,
with every strict/raw diagnostic and leak count zero and analyzer0/5. The
[evidence packet](../validation/evidence/underground-support-clearance-2026-10-04/README.md)
retains exact pins, rejected fixture/analyzer attempts and the reproducible
logical census. These checks do not qualify a complete real-profile stair route.
Construction independently accepted all five exact source/test pins after
reviewing the complete delta and reproducing the census; no high or medium
finding remained. Native/runtime activation and the explicit follow-on gates
above are unchanged.
