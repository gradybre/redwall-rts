# Independent Room memory integration review, first candidate

Review is read-only in the root integration worktree. Only this evidence tree
was written by the reviewer; no engine, source overlay, registry or generator
write was used. `review-inputs.json` pins the four tooling files, manifest and
generated pack read for this candidate. Complete tool snapshots are retained
with nonexecuting `.txt` suffixes.

The new adapter's current implementation is
`b02631720ec6a936a6a5a93670e76fe829a055998753bd863a950acb9e5a57e7`;
its manifest is
`c84b0a1dec81c909d6057ee5242362d3a08d4dc09834a4dd979e4577d217070a`.

## Verification

The reviewer independently ran all 10 new tests: zero failures, 0.969 seconds.
`independent_probe.py` then verified 50 actual source pins, 29 immutable witness
pins and all 17 predecessor files against their exact Git commits. It exercised
96 additional refusal probes: one injected allocation in each pinned current
source and one changed byte sequence in each witness/predecessor. Every one
refused before a producer executed. The complete normal budget build also
succeeded with subprocess access disabled and serialized byte-identically to
the current generated pack.

The first review harness compared Python tuples directly to JSON arrays and
therefore failed after all refusal probes. `probe-harness-rejected.py.txt` and
its log retain that reviewer-only error. The corrected harness compares JSON
semantics and exact serialized bytes; neither production tooling nor input
source changed to obtain the pass.

## Source and lifetime findings

The current source-text and original owner identities close before historical
projection or producer execution. Caller-injected `Module.text` is checked and
reparsed, not replaced by disk text or its cached hash. The producer and its
transitive evidence closure are pinned; assertions run at optimization level0.

The projection is explicit: old 1152/1156/1158/1160 sub-slices remain labelled
historical, while current 1161 publication, 1163 construction/retirement, 1165
itinerary and 1166 Catalog are replayed. The changed Locations constructor
roots and their original class/member initializers are compared directly; the
new null frontier reference belongs to the separate publication census.
Provider changes outside the one itinerary dispatch are forbidden by the
reviewed 1165 comparison. The actual Session constructor excludes a live
retirement Scope and blocks reentrant Scope creation, supporting sequential
reuse without a second owner bank.

Current UI lifecycle controls6,019 + helpers1,903 =7,922/8,192. Constructor
Scope/private-Owners absence removes2,065 bytes from that conservative control
base, leaving3,954 + actual constructor stack/heap3,539 =7,493/8,192. The new
Session16 and Scope8 numeric bytes are charged once inside the existing
lifecycle reserve. Publication uses8,050/8,192, and the corrected ground
Catalog fixed peak is1,468/2,048. The global declared total remains99,999,806
with194 bytes of headroom. Native allowances remain provisional and runtime
qualification remains false.

## R1 — unpinned reached Movement reader (MEDIUM, correction requested)

The new manifest omits `movement.gd`. However, Catalog's
`_movement_pace_refusal` calls the actual `Movement.profile_speed_into` while
the replayed ground census assumes an unchanged512-byte foreign-reader
allowance. A fully reparsed injected Movement module can add4,096 bytes of
local packed scratch to this reached method and the complete budget build
still passes at the unchanged1,468-byte Catalog fixed peak and global total.

`movement-unpinned-callee-probe.json` records the exact original and mutant
source hashes, inserted statements, returned figures and unchanged on-disk
source. This is a source-checker enforcement gap, not a defect or allocation
in the currently reviewed runtime implementation. Root accepted the finding
and is pinning the exact Movement reader closure plus a negative test before
final acceptance. No other high/medium finding remains in this candidate.
