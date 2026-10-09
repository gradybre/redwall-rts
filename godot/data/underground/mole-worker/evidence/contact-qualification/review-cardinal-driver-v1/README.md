# Cardinal source-role driver review

Bounded source scope: driver protocol4 and its actual-owner tests, against
commit3f819752. The same14 source clips map to18 explicit immutable catalog
rows. Existing protocols1–3 are unchanged. Rows0/1 remain all-yaw stand/walk;
rows2–17 are down/high/front/INSTALL for yaw0,16384,32768,49152 respectively.
The fixed row and heading checks reject whole-tuple substitution. Logical
WORK calls require the new explicit `step_profile_into` path, which still
uses the actual assigned Job, Work/Gear claim, cargo and Transform heading.
A productive heading change refuses until exact recovery reaches ready.

Validation uses the normal CI singleton shard, after moving this worktree's
assets outside Godot, deleting its cache and running the editor import.
The isolated user directory and override creation/removal are pinned. The
source pair is unchanged before and after the import, suite and analyzer:

```text
15 test(s),472 assertion(s),0 failure(s)
diagnostics:0 unexpected errors,0 unexpected warnings,0 expected,0 tolerated;0 leaked objects/resources
log:0 unexpected errors,0 unexpected warnings;0 leaked objects/resources
0 GDScript warning(s) in 0 of 2 file(s)
```

Raw logs contain the exact runner footers. The four new tests cover all16
WORK row selections, wrong/swapped heading metadata, interrupted work and
external yaw change, unsupported yaw, real claim release, catalog replacement
and unchanged ground selection. Their source geometry/certificate flags are
explicitly synthetic; no cardinal source or first-prefix permission follows.

Retained tuple bytes rise144→432 (+288), total driver packed payload432→720.
No new scalar control, live phase field, authoritative state or copied source
palette is added. Caller Frame and cold400+18-byte descriptor/hash scratch
remain separate. Native/presentation whole-client peak remains unqualified.

Independent root source review accepted this frozen pair on 2026-10-04.
The reviewer read the full delta and original transition logic, all four new
regressions and retained raw evidence, and independently matched both hashes.
No high/medium finding remained in this presentation-driver scope. Cardinal
primitive/contact proof and native source witnesses remain a separate artifact
increment under1123.
