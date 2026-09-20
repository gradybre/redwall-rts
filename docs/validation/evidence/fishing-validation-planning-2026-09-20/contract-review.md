# Fishing owner 4 contract review

Independent review of candidate FISHING-S4-VALIDATE-R01 version 1 against the current
source heads. Read-only: nothing below was executed, imported or applied. The public
lifecycle probe `public_history_probe.gd` is authored and WAITING for the single heavy-job
slot; it has not run, and no probe outcome is asserted here.

## Re-derived layout

Owner index 4 `fishing`: key bytes 7, owner version 1, primary 32, field count 22, field
begin 80, child count 0, child begin 3, offset 8503348, payload 5524, block 5555. Values
recomputed from the 22 declared types and counts: 352 u8 + 2432 i32 + 2560 i64 = 5344;
5344 + 22*8 + 4 = 5524; 5524 + 24 + 7 = 5555; 8503348 + 5555 = 8508903, the forage offset.
Stock fields are literal 96-length columns, not a declared child extent. The contract's
refusal to pin `CANONICAL_OWNER_SCHEMA_VERSION = 2` is correct: that constant is the
section-7 claim owner schema, and section 4's owner version is 1.

Ordered domains, ordered gates, the 10%..100% population band, the strict 30/40 latch with
an inclusive 30..40 band, the per-stock and summed quota bounds, broad inactive habitat
history against fully blank stock rows, same-owner stock presence/self-reference/capacity
and within-habitat species distinctness, self SLOT uniqueness against exact zone
SLOT+GENERATION uniqueness with stale generations legal, and 5344 + 5344 = 10688 logical
packed bytes all agree with the public writers. I found no contract contradiction against
the producer and no source counterexample. Cross-owner obligations are correctly excluded
from local validation: `effort_used` against saved section-7 claims, `species_id` against
the item catalog, and zone/basin identity against Forage and the Directory.

## Findings

1. **COLUMN_SHAPE is specified but unwitnessed and unmutated.** The frozen set counts 196
   cases and contains no shape refusal; the 63 units cover the bridge's 22 projections but
   no null-image or wrong-extent gate. The claimed "flags before shape" priority therefore
   has no killing witness, and a short array would fail by runtime error, which the plan
   rightly forbids counting. Add explicit cases pairing one wrong extent with a byte of 2
   (expect COLUMN_SHAPE) plus null, and either add the shape units or exclude them with a
   stated reason.
2. **The mutation-priority list reads as contract order but names inverted variants.**
   "flags before shape" and "habitat enum before global flags" are the opposite of contract
   steps 1-3 and of the fixtures `global-flag-before-habitat-enum` and
   `earlier-habitat-value-before-later-enum`. Relabel them as swapped-order mutations so a
   later reader cannot implement the inversion.
3. **Hysteresis form.** Use the producer's cross-multiplication (100*P vs 30*K and 40*K),
   not `floor(K*percent/100)`. The two coincide for all nine compiled capacities, so a
   percent-form rewrite is an equivalent mutation and must be excluded explicitly rather
   than reported killed; the two declared units are strictness units only.
4. **Bridge preload set.** The contract restricts preloads to Fishing, Schema, Section and
   SaveHeader while requiring EntityDirectory NULL_SLOT/NULL_GENERATION/DIRECTORY_CAPACITY
   pins. Confirm the indirect constant path through Fishing, or permit the EntityDirectory
   preload; this is wording, not scope.

## Checks that hold

The 27 metadata cases are coherent. The child counterfactual moves one extent from jobs to
fishing and reconciles child_begin, both payloads and every later offset; the type fault
gives +96 bytes and section 12947661; the extent fault +1 and 12947566; key order and the
primary swap preserve ASCII order and 193184 rows. Each is accepted by the section schema
and refused only by the owner pins, which is what makes them counterfactuals rather than
schema errors. The 243-assertion figure is a planning estimate, not a measurement.

Group units are conservative: the eight `free-stock-*` fixtures individually witness the
single inactive-stock blank unit, and the present self/zone reference groups retain their
boundary cases. The default `Columns` image is exactly `accept-clear`, so construction
defaults and the positive control share one witness.

FISHING-SAVED-BINDINGS, bulk capture/apply and the fishing gameplay loop remain outside
this milestone. Nothing here authorizes implementation; probe reconciliation is still
outstanding.
