# Parent integration notes

Author produced855lines versus requested850 ceiling, a five-line presentation
overrun with no scope expansion. Kept bounded two-file implementation. Parent
replaced newfragment range(R) loops with integer iteration to avoid temporary
range arrays and corrected the identity-predicate summary comment. All existing
Gear source remains an identical prefix; no old mutator/legacy API changed.

Packed accounting matches contract:12canonicalarrays42R plus oldheap4R, local
lot bitmap16384, captureheapbitmapR, restoreprivateheap4R and12duplicates42R.
No full source-view GearColumns; validation takes typed arrays and native tally.
Owner capture131R+16384, restore134R+16384; adapter capture215R+16384, apply176R+16384,
plus192existingseedbytes. These conservative complete-call allocations include
disjoint constructor buffers and are not measured peaks/RSS. Object/native
metadata, external snapshots, unrelated worlds and stream buffers are excluded.

Independent literalgoldens were generated before author integration. Existing
codec suite complements the owner-column framing probes; no fullworld encoder
or disk rollback result is claimed. Parent19newtests include public realgear
continuation and legal loaded-catalog missingkeys.
