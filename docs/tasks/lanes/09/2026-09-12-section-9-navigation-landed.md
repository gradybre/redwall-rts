# §9 NAVIGATION landed — 2026-09-12

Task: 09_persistence_replay_reliability.md
Date: 2026-09-12


`godot/scripts/core/save_section_navigation.gd` and
`godot/test/test_save_section_navigation.gd`, under REG-R01 and SAVE-LAYOUT-R01.
Reasoning in
[decision 0121](../decisions/0121-section-9-navigation-persists-used-prefixes-and-declares-its-own-primary-count.md).

- [x] Two owner blocks behind `store_count:u32 = 2`, in ASCII key order `movement`
      (schema 1, primary 512) then `navigation` (schema 2, primary 8192), each with the
      standard wrapper, tiling the section with no gaps. Column-major bytes; field order
      is the declared ordinal from `canonical_state_registry.json`, which differs from
      GDScript declaration order in **both** blocks.
- [x] `_heap` and `_arena` persist their **used prefixes**; the tails are zeroed at
      capture, absent from the wire and refused in a Record. `_stamp`, `_g`, `_parent`,
      `_heap_position` and `_state` are written at the registry's declared full capacity;
      sparsifying them is a later schema version's change and is flagged as needing a
      ruling, not taken here.
- [x] Owner schema version 2 doubles as PATH-R02's route-semantics gate, compared against
      `navigation.gd::route_semantics_version()` and run through
      `refuse_route_semantics()`. `_r_start_cell` must equal `_r_exact_start`, and
      `PHASE_SEARCHING_LOCAL` is refused outright.
- [x] Queue progress validated as state: the free list and the pending queue each thread
      exactly their own rows with no cycle, and the queue must be in `_enqueue()`'s
      service order. Descriptor refcounts are rebuilt from the READY requests that hold
      them; every in-use route window must lie inside the arena used prefix and not
      overlap another.
- [x] Real byte vectors: an empty navigator is 5180042 bytes, the ceiling is 10422922,
      and `4 + 32 + 18504 + 34 + 5161468 + 4*(heap_size + arena_used)` is pinned by both
      the framing hex vector and the section arithmetic test. Capture → encode → decode →
      re-encode is byte-identical, including from a live serviced navigator holding a
      READY request, a quota-interrupted search and a queued request at once.
- [x] Ten mutants killed, one per Godot invocation, the production file `shasum -a 256`
      byte-compared against a pristine copy after each restore.

- [ ] **BLOCKER N1 — neither owner publishes bulk columns.** `navigation.gd` and
      `movement.gd` have no `copy_columns_into()` / `restore_columns()` pair, so §9 has no
      `capture_into(store)` and no `apply(record, store)` — the same wall §3 hit as its
      BLOCKER D1 before decision 0105. The exact signatures needed are in the module
      header. `agrees_with_navigation()` cross-checks a Record against a live navigator as
      far as the public readers allow, which is every published scalar, every descriptor's
      generation/variant/refcount and every request phase.
- [ ] **Registry row owed, reported and not applied** (the file is another owner's): a
      `### godot/scripts/core/save_section_navigation.gd` section in
      `docs/persistence_state_registry.md` with one **category 3** row citing no save
      section. `state_registry_coverage.py` reports exactly one C1 failure until it lands.
      `Record` (10422324 bytes), `Derived` (10240 bytes) and the transient `GroupBuffers`
      are bounded codec scratch, not authoritative columns, so nothing is owed in
      `docs/systems_architecture.md`.
- [ ] **`navigation`'s primary count is this owner's declaration**, not a published one:
      `PATH_REQUEST_CAPACITY` = 8192, with every child extent validated separately. A
      ruling naming a different value changes one constant and the schema version.
- [ ] §9 persisting closes no MOVE gate and certifies no release save. PATH-R02's
      readiness-latency work is untouched.
