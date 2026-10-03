# High-wall runtime dependency refresh

The accepted exact WORK selection API changes only the borrowed Profiles script.
This separate native runtime spec changes that one source pin to reviewed commit
`d714e889`, as enumerated in `runtime_closure_refresh`; every asset/import, mesh,
material and matrix source pin stays identical. The original bake spec and raw
image remain unchanged and are still checked by offline geometry extraction.

The retained first attempt refused before creating output because the historical
spec correctly did not match the newer runtime script. The new native witness
pins both executable sources before import and the complete imported closure
before/after rendering. This grants no new source geometry or gameplay clearance.
