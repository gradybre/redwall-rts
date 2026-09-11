# 0062 — The future-affecting-state registry

Date: 2026-09-11 · Status: **Accepted** (executor; task 09.1)

## What was built

[`docs/persistence_state_registry.md`](../persistence_state_registry.md) — one
row per store per column group, covering all 36 modules under
`godot/scripts/core/`: 275 rows over 541 declared packed columns.

[`docs/validation/state_registry_coverage.py`](../validation/state_registry_coverage.py)
— a standalone check that reads those columns out of the GDScript and fails when
the document and the code disagree. `tools/run_tests.sh` runs it before the Godot
suite.

Task 09.1 says the registry is to be *maintained as every store arrives*. It was
not: roughly thirty stores landed without one. Writing it once would leave it in
exactly the state that produced this task, so the enforcing script is the
deliverable and the document is its subject.

## Why the script exists, and what it can actually check

A registry is a claim about code. The claims that rot first are membership,
width and count, and all three are mechanically derivable from the source:

- **C1/C2** every module has a section and every section names a live module —
  so a new store cannot land unclassified;
- **C3/C4** every declared packed column is claimed by exactly one row, and
  every named member exists;
- **C5** the stated width is the width of the declared packed type;
- **C6** the count cell quotes the module's own `resize()` argument *verbatim*,
  plus its value where that resolves from `const` declarations — the same
  constant-reading pattern `docs/validation/ready07_arithmetic.py` uses for the
  scheduler queue, which this script deliberately does not modify;
- **C7** a category is 1, 2, 3 or UNRESOLVED, and an UNRESOLVED row must state
  its question;
- **C8/C9** every cited save section is one of ARCH-SAVE-002's fifteen, parsed
  out of `docs/systems_architecture.md` rather than transcribed, and a category 3
  row cites none.

Eleven mutations were run against an isolated mirror of the tree and all eleven
were caught: a member swapped for a duplicate, a wrong width, a wrong count
value, a wrong count *expression*, a new packed column added to a module, a whole
new module added, a section renamed to a dead module, an invented ARCH-SAVE-002
section name, a category 3 row claiming a section, an UNRESOLVED row with its
question removed, and a `QUEUE_CAPACITY` changed in GDScript with the registry
left alone. Breaking the registry in the real tree makes `./tools/run_tests.sh`
exit 1 before Godot is invoked; the file was restored and byte-compared.

**What it cannot check.** Category is a judgement about whether omitting a value
makes a reloaded world diverge, and no static reader can make it — the script
only enforces that a category was chosen from a fixed set and that the section
column agrees with it. Scalar rows (`Members` is `--`) are prose: their contents
are unverified, so a `var _last_day` deleted from `ecology.gd` would not fail the
build. ARCH-SAVE-006's next-tick parity test is the real arbiter for category
1 versus 2, and it does not exist yet.

## Why category 2 is not saved

A derived value written to disk is a second source of truth. On load the file
carries one answer and the rebuild produces another, and nothing forces them to
agree — the disagreement surfaces as a divergence whose first symptom is in the
consumer, not in the loader. ARCH-SAVE-002 already legislates this for two cases:
"active lists are rebuilt ascending", and allocator heaps may be saved *or*
"rebuild[t] deterministically from occupancy and retired masks". ARCH-HASH-001
excludes "derived spatial/active indexes" from the canonical hash for the same
reason.

The rebuild has to be *deterministic*, not merely correct. `entity_directory.gd`
qualifies because `_pop_min()` returns the window minimum, so allocation order
depends on the free **set** and not on the heap's permutation — which is exactly
what task 09's "restored lowest-free allocation" check tests.
`inventory.gd` does **not** qualify: line 259 says its free lists are "A stack,
not the directory's min-heap", so pop order is last-freed-first and depends on
the array contents. Two allocators, one rule, opposite answers. The registry
records both.

One rule was needed for columns that are derivable *and* named by §2's memory
ledger as stored fields (`WorldTileMaps.zone_link_head`, `.resource_slot`,
`residents._skill_level`): **the ledger wins, the loader cross-checks the column
against its source, and it is category 1.** Choosing "rebuild" for a ledgered
field would silently contradict the memory budget.

## Every UNRESOLVED row

Three rows carrying two questions, and each is a contract question rather than a
missing measurement.

1. **`command_dispatch.gd`, command result ledger (two rows, eight columns).**
   `docs/planning/ready07_scheduler_contract.md:135-136` says "Command result/
   source-intent ledgers keep their own canonical auxiliary-state owners", which
   reads as §6 AUXILIARY_STATE. But nothing outside `command_dispatch.gd` reads a
   result row — the only callers of `result_into()`/`last_result_into()` anywhere
   in `godot/` are tests — so by the
   divergence test it is category 3. *Question: does §6 carry the eight result
   columns and the ring position `_result_write`, or is the result half UI-only
   output that ARCH-HASH-001 must exclude?* Resolved by whoever owns §6's
   contents in 09.2, or by the first UI consumer that reads a result row.
   The **source-intent** half is not in doubt: it suppresses duplicate
   designations and is category 1.

2. **`inventory.gd`, `_c_reachable`.** Set only by `set_reachable()` from
   outside; no module in this repository computes container reachability.
   *Question: with no topology or room system to recompute it on load, does §7
   write this byte, or does the loader require a reachability pass that does not
   exist?* Writing it now creates a second source of truth the moment that pass
   lands. Resolved by task 05/06's room-topology owner, or by 09.2 deciding to
   write it and accepting the cross-check obligation.

Nothing else was left open. Where a document settles a question it is cited in
the row; where this registry had to read between sections it says so in the
preamble rather than in a row.

## What this does not do

- **It writes no save module.** 09.2 and 09.3 own the codec and the
  transactional load. The registry supplies the inventory, the null
  representations and the section assignment; it fixes no byte layout.
- **It adds no ledger row and changes no allocation.**
  `docs/systems_architecture.md` is untouched and
  `docs/validation/ready07_arithmetic.py` still passes unchanged.
- **It does not close the two BLOCKED items**, and says so per row:
  `scheduler_events.gd`'s `SCHQ0001` subsection is encode plus decode plus
  validation with no caller, and `resource_catalog_binding.gd`'s save/reload
  round trip cannot be exercised. Both need 09.2's writer, not new state.
- **It does not settle expanded movement.** `movement.gd`'s reserved zero columns
  (`_correction_*`, `_radius_u`, `_desired_yaw`, `_next_yaw`), `jobs.gd`'s
  reserved agent path and lease columns, `spatial_world.gd`'s constant `_layer`
  and `world_init.gd`'s empty `FaunaStockReserved` rows are all recorded as
  written-as-zeros with an explicit do-not-repurpose note, which is task 09.1's
  "Do not silently repurpose v1 bytes". The version and migration/rejection
  matrix stays with MOVE-G02.
- **It asserts no performance or memory result.** No figure here was measured.

## One thing found while writing it

`item_definitions.gd`'s `_commit()` calls `resize()` on six packed columns with
`items.size()`, outside `_init()` and with no bound at that call site. The 256
cap is real but lives in `catalog.gd`'s `compile_domain()`
(`ITEM_DEFINITION_MAX_KEYS`), two modules away. This is a catalog-load
allocation rather than a per-tick one, so ARCH-MEM-001 is not violated; the
registry records the count honestly as `runtime` rather than implying a constant
the module does not state.
