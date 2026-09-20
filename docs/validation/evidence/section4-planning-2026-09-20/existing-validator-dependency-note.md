# Existing section4 validators: dependency observations

Source observations for the next semantic contract; no validator extraction or owner binding is accepted by this note.

- Needs1977: supplied Columns plus constants through shape, byte/value domains, inactive-row checks and living count. Appears suitable for a pure shared validator without constructing a live Needs store. Preserve departure_days0..INT32MAX and retained inactive size/environment inputs; do not replace with blanket zeroing.
- Residents2028: first checks live `_catalog_error`; live rows compare species size via `_species_size` and self-reference against live `_directory`. Skill validation calls skill_level_for_xp; unused rows retain species, size, arrival, home/bed and skill pairs. The comment in `_column_reference_refusal` says live home/bed references are resolved in `_column_live_row_refusal`, but actual function2144 resolves only self-reference. Treat this discrepancy as a planning question against the owning contract, not authority to silently strengthen or weaken restore. Section14 name occupancy stays coupled.
- Jobs2796: validation depends on live `_directory` and `_residents`, includes agents, both directions of worker binding, and section5 coordinator/member chains. Existing bulk restore is not a section4-only pure validator. The live-definition and agent-reserved rules must be reconciled with the accepted movement migration; comments that no pathfinder exists are not a current implementation census.

A future offline validator must either extract context-free rules with source parity tests or receive explicit saved projections/catalog facts. Instantiating duplicate live stores merely to call the old instance functions would violate the one-world memory design. File origin and saved-reference consistency remain coordinator obligations; a set of individually valid arrays does not establish common origin.

Source pins:

```json
[
  {
    "owner": "needs",
    "path": "godot/scripts/core/needs.gd",
    "sha256": "31fc6a56d294154024f39ff4f04924d9c2148fc4f08acee388fd6ea94595d553",
    "restore_refusal_line": 1977
  },
  {
    "owner": "residents",
    "path": "godot/scripts/core/residents.gd",
    "sha256": "7ce35ffc7e14ff9e8ba86d70d54a1401e0814751d0b71779d92ba476cd89655c",
    "restore_refusal_line": 2028
  },
  {
    "owner": "jobs",
    "path": "godot/scripts/core/jobs.gd",
    "sha256": "bf74583b409dd22da8b9100318e224b63bede5ed01c66be09f4ed0ab38809f3c",
    "restore_refusal_line": 2796
  }
]
```
