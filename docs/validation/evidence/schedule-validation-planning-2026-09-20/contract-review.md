# Schedule validation contract — independent pre-author review

Review of `docs/planning/schedule_component_validation_contract.md`
(SCHEDULE-S4-VALIDATE-R01 draft1). Reading only: nothing here was executed, no
production, test or contract file is edited, and this note authorizes no merge.
Read for this review: `godot/scripts/core/schedule.gd`, `godot/test/test_schedule.gd`,
`godot/scripts/core/save_component_columns_schema.gd`,
`godot/scripts/core/save_owner_priorities.gd`, the three planning notes in this
directory, and the recorded public-history probe and its log.

## 1. The strict present-row gates: no reachable counterexample

The adoption of `sleep1 -> current == ANYTHING` as a hard refusal was the one
disputed call. Re-derived from the writers rather than from either note:

- `_sleep_satisfied` is written in `clear()`, `despawn()`, `_write_template_hours()`
  (all 0) and `_resolve_activity()`. Only `_resolve_activity` can raise it.
- `_resolve_activity` raises it on exactly one branch: `scheduled == ACTIVITY_SLEEP`
  with `_rest_scratch >= 9000`. That branch then returns
  `ACTIVITY_ANYTHING if _sleep_satisfied[slot] == 1 else ACTIVITY_SLEEP`, and the
  latch is 1 whenever it is returned from, so the returned value is ANYTHING.
- The collapse branch and the non-SLEEP branch both write the latch to 0 before
  returning, so neither can leave latch 1 beside a non-ANYTHING value.
- `_current_activity` is written only in `clear()`, `spawn()`, `despawn()` (all
  ANYTHING) and `resolve_into()`, which stores exactly what `_resolve_activity`
  just returned. So current cannot move away from ANYTHING while the latch stays 1:
  any later write goes through `_resolve_activity`, which either lowers the latch
  or returns ANYTHING.
- `assign_template` lowers the latch and leaves current alone (antecedent falsified,
  not violated); `set_hour_activity` touches neither column.

`resolved == 0` on a present row is equally tight: `_resolved` is raised only in
`resolve_into`, and `spawn` seeds current ANYTHING, resolved 0, latch 0 via
`_write_template_hours`. Gate 9 therefore also yields `sleep1 -> resolved1` by
contraposition, exactly as the contract's gate 10 note claims.

I found no valid public history, and no higher-authority case in GDD §5.3, the
amendment or the registry, that these gates wrongly reject. GDD §4.2 lists only
hourly/template/current for this component and states no rule these gates contradict.
A future producer change would need a contract revision; it is not a counterexample.
The earlier warning-level recommendation is correctly not adopted, and introducing a
warning channel into a refusal API would have been the larger defect.

## 2. Probe histories stay accepted

Traced against the stated gates, the recorded probe outcomes all accept:
edited-after-latch (`hour22=WORK`, current ANYTHING, sleep 1) passes gate 10 and
never meets a timetable comparison; reassigned-after-resolve (current SOCIAL,
hour18 ANYTHING, sleep 0, resolved 1) trips neither gate 9 nor gate 10; the refused
out-of-range resolve preserves current SOCIAL, which likewise accepts. The contract's
explicit ban on comparing current against timetable, template, clock, hunger/rest or
Needs is what keeps these legal, and it is stated plainly enough to bind the author.

## 3. Mechanical checks

- **Gate order.** Every gate is declared complete over all 512 physical rows before
  the next, including the row-state gates, so first refusal is deterministic across
  different rows. Shape precedes every domain or index read; flags precede the
  free-row and state gates, so "inactive" is only ever decided by a present byte
  already proven to be 0 or 1.
- **Six arguments and mutants.** Distinct codes for present, sleep and resolved kill
  the same-type argument swaps; distinct template and current codes kill the
  i32 swap. Using per-field invalid values rather than the empty control is the right
  call, since the all-zero control is itself refused by gate 8.
- **Helper and presence.** One shared `_free_row_is_clear` with no presence argument,
  with `inactive_row_is_clear` keeping its address and present guards, preserves the
  existing reader's contract (still false for a present or out-of-range row) while
  removing the drift risk. Live reader guards after sharing are correctly required.
- **Templates.** Local `0..TEMPLATE_COUNT-1` is the only bound available offline:
  `_check_template` also consults `_catalog_error`, which needs a constructed owner,
  and construction allocates a private Needs. `catalog_ids.gd` preloads
  `ScheduleScript`, so the forbidden `Schedule -> CatalogIds` preload would indeed
  cycle; deferring identity to `CatalogIds.verify_embedded` is correct and is not a
  scope expansion.
- **Memory.** 512 + 12288 + 2048 + 2048 + 512 + 512 = 17920 checks out, and
  `OWNER_PAYLOAD_BYTES[14] = 17972 = 17920 + 4 + 6*8` corroborates it from the
  generated table without assuming the widths. No projection or scratch is added.
- **All-zero.** An all-zero frame passes shape, flags and both activity domains
  (0 = SLEEP is in range) and template (0 is in range), then fails gate 8 on hourly
  bytes. `COLUMN_FREE_ROW` is the correct expected code.
- **Metadata and acceptance.** Gate ordering, the forwarded schema and section
  refusals, the `Schedule owner14 metadata:` prefix and the raw column code both
  follow the owner 11 bridge precedent. Assigning the registry `_resolved` wording
  fix to the parent is right; it is a doc edit, not an author file.

## 4. Unresolved author ambiguity, with a bounded fix

**The contract requires "six explicit typed accessors" but names none of them.**
The only worked precedent in scope uses `record.u8_column(FIELD_*)` for four u8
fields. Owner 14 needs i32 reads for ordinals 2 and 3, and no accessor name for that
type appears anywhere in the contract or in the material supplied here. The author
must not invent one. Bounded fix: pin both accessor method names and the six field
ordinal constants literally in the contract; if `Section.FramedOwner` publishes no
i32 accessor, that is a parent-owned prerequisite and this packet cannot proceed on it.

Two smaller items in the same file, each fixable in one sentence:

1. `_free_row_is_clear` is given a `slot` but no stated address-check duty. Say
   explicitly that it performs no bounds check and assumes a caller-validated slot,
   so the existing reader keeps its guard and the validator's bounded loop does not
   pay for a second one.
2. For an inactive row whose hourly byte is both out of domain and non-ANYTHING, the
   expected first-refusal code follows from complete-gate ordering
   (`COLUMN_HOURLY_ACTIVITY`, not `COLUMN_FREE_ROW`), but the acceptance list never
   pins it. Name it, so the test matrix cannot encode the opposite expectation.

## 5. Non-findings

The disposition's own note that the review says "three places" while listing four
sleep-column writers is a wording slip already recorded; the enumerated sites are
correct and the derived implications are unaffected. Bulk capture/apply,
`_present_count` rebuild, Needs agreement, section 2 catalog matching, lifecycle and
barrier publication, migration, the remaining owners and full save/load are correctly
left downstream, and I recommend no addition to this packet's scope.
