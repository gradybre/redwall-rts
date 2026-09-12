# Executor → Astra: the canonical owner/field registry, and one contradiction

2026-09-12. A request, not a ruling. It proposes no key, no ordinal and no schema
version.

Four separate blockers reported by four separate implementation lanes turned out
to be **one missing artifact**. This document asks for that artifact, and for a
ruling on one genuine contradiction between two authorities.

## The grammar is settled. The registry it refers to does not exist.

[SAVE-R09](2026-09-11_save_codec_contract.md) and
[SAVE-LAYOUT-R01](2026-09-12_clock_restore_and_layout_followup.md) define the
owner/field grammar thoroughly, and **none of it is being re-asked**:

- `owner_key` is unique within its section, nonempty ASCII, at most 256 bytes.
- Registry order is section ID, then ASCII owner key; fields keep their declared ordinal.
- Each field record is `section_id:u32, owner_key:string, field_key:string, type:u8, value_count:u64, values`.
- `(section_id, owner_key, field_key)` is unique; `owner_key` intentionally repeats across its fields.
- Records appear by section 1–14, then ASCII `owner_key`, then **the declared field ordinal in that owner's versioned canonical schema — not alphabetically by display label**.

Then: *"The canonical registry supplies the finite `record_count` and ordered
declarations; missing/duplicate/unregistered fields or an order mismatch fail
verification."*

**That registry is not in the repository.** The grammar says how to spell a key
correctly; nothing says which keys exist.

## Why this is four blockers rather than one nuisance

| Reported as | Lane | Actual cause |
| --- | --- | --- |
| `_next_persistent_id` has nowhere to live | §3 ENTITY_DIRECTORY (D2) | §1 has no registered owner block for the directory |
| No owner-block wrapper (N1) | §14 NAME_POOL | no `owner_key` spelling or schema version to use |
| `FIELD_KEYS` ships as "a labelled proposal" | §3 ENTITY_DIRECTORY | field-key registry not frozen |
| **§15 STATE_DIGEST cannot be built at all** | unowned | the digest is *defined over* ordered field records |

§3 was buildable only because one sentence in SAVE-LAYOUT-R01 happens to name its
block: *"for section 3 there is exactly one entity_directory block, primary_count
equal to the compiled directory capacity."* Nothing comparable exists for any
other section, so every later lane stops at the same wall.

**§15 is the load-bearing one.** It is the save format's integrity check, and it
cannot be written — not partially, not as a proposal — until the ordered
declarations exist.

## The scale of the collision this prevents

Section ownership as the state registry actually assigns it today:

| Section | Owning modules |
| ---: | ---: |
| §1 WORLD | **11** |
| §2 CATALOG_IDS | 8 |
| §3 ENTITY_DIRECTORY | 1 |
| §4 COMPONENT_COLUMNS | **16** |
| §5 CHILD_ARENAS | 4 |
| §6 AUXILIARY_STATE | 3 |
| §7 INVENTORIES_AND_LEASE_INDEXES | 6 |
| §8 JOB_INDEXES | 2 |
| §9 NAVIGATION | 2 |
| §10 RNG | 1 |
| §11 EVENT_SCHEDULE | 1 |
| §12 PENDING_COMMANDS | 2 |
| §13 CHRONICLE | **0 — no owning module exists** |
| §14 NAME_POOL | 1 |
| §15 STATE_DIGEST | **0 — no owning module exists** |

Sixteen modules write §4 and eleven write §1. Without registered keys, sixteen
independent lanes would each invent an `owner_key`, and the first collision would
be found by a corrupt save rather than by a test. This is why the executor stopped
rather than picking plausible strings.

## What is being asked for

An artifact — machine-readable preferred, to sit beside
`asset_dimensions_and_budgets.json` — that declares, for every `(section, owner)`:

1. the exact ASCII `owner_key`;
2. its `owner_schema_version`, and what a version bump obliges;
3. the **ordered** field declarations: `field_key`, type, and the ordinal that
   fixes record order;
4. `record_count`, finite, so verification has something to check against.

Plus three rulings the artifact implies:

- **Whether an owner may hold more than one block in a section.** §1's clock block
  is a fixed 80 bytes with ten offsets, all clock and world scalars, and no room
  for `next_persistent_id`. Either the directory gets its own §1 block, or that
  block grows and its version moves. **The executor will not choose**; either is
  a format decision.
- **What §13 CHRONICLE and §15 STATE_DIGEST are owned by**, given that no module
  exists for either. §15 in particular cannot be an afterthought: it validates
  everything else.
- **Whether unimplemented owners are declared now or on arrival.** Declaring all
  of them fixes `record_count` immediately and lets §15 be built against a
  complete registry; declaring incrementally means `record_count` moves and every
  earlier save fails verification against a later build. The second is a migration
  policy question, not an omission to be discovered later.

## A separate contradiction, in the same area

SAVE-R09-002 and the GDD disagree, and the disagreement refuses the starter
settlement when read literally.

> **SAVE-R09-002:** "Empty names are allowed only where the owning unused-row
> schema permits them. **A live resident cannot load an empty name.**"

> **REQ-SET-040/041:** naming is trigger-based — player pin, skill 8, first rescue,
> lead cook of a third feast, appointment as Warden. "Where a resident is anonymous,
> the system shall **retain full persistent state** and display species plus role
> and ID rather than a personal name."

So an anonymous **live** resident holding `""` is required by REQ-SET-041 and
forbidden by SAVE-R09-002. At world generation eleven of the twelve founders are
anonymous, so a literal reading refuses the first save of every new game.

§14 shipped an interpretation, **labelled as an interpretation and not a
quotation**: the sentence governs a row the schema has flagged *named*, so
`_named == 1` with an empty key refuses at capture, while `_named == 0` with `""`
is the registry's own declared unused value. That reading is consistent with the
preceding sentence about unused-row schemas, but "unused row" more naturally means
a row with no resident at all than a live resident with no name — which is why it
needs confirming rather than assuming.

Confirm, or supply the reading you intended. If the intended rule is stricter —
that anonymity must be represented by something other than an empty string — that
is a `residents.gd` schema change and should say so explicitly.

## What the executor will do with the answers

With the registry: §15 becomes buildable, §14's wrapper lands and increments its
section version, §3 promotes `FIELD_KEYS` from proposal to binding, and
`_next_persistent_id` gets a home — which closes the live defect that **a reloaded
world currently reissues persistent IDs and fails ARCH-SAVE-004's uniqueness
validation**.

Nothing here asks for save parity, full-colony acceptance, or any movement or
qualification gate, and no answer authorizes paid asset generation.
