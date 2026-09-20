# Injury owner 6 — independent final contract review

2026-09-20. Read-only review of `docs/planning/injury_component_validation_contract.md`
draft1 before author dispatch. Nothing here was run, applied or tested; every figure below
was re-derived by hand from the supplied `injury.gd`, `needs.gd`, `entity_directory.gd` and
`save_component_columns_schema.gd` text. **No blocker found. The draft is fit to dispatch**
once the five observations below are carried into it.

## Confirmed against source

* Field order matches the declaration order of `injury.gd`: `_present`, `_kind`,
  `_airless_episode`, `_exhaustion_latch`, `_care_context_blocked` (u8); `_severity`,
  `_rescuer_slot`, `_rescuer_generation` (i32); `_untreated_ticks`, `_care_progress_mwu`,
  `_last_incident_ordinal` (i64). Global ordinals 122–132 are compiled-table positions; the
  local ordinals are 0–10, and the draft states both without conflating them.
* 5·512 + 3·512·4 + 3·512·8 = 20992; +4 child word +88 count words = 21084; +24 wrapper
  +6 key = 21114; 8539433 + 21114 = 8560547, the recorded Jobs offset.
* Retained history is stated as the source behaves. `set_rescuer()` requires only a live
  patient and a valid non-self resident, so a healthy bound rescuer is legal;
  `complete_treatment()` clears kind, severity, ticks, care and the rescuer but keeps the
  ordinal and both latches; stale references survive by design. Clause 11 therefore
  constrains only the airless and exhaustion flags, not the blocked-care byte, which
  `set_care_context_blocked()` admits on an uninjured row. Correct.
* Clause 12 is stronger than the ResourceNodes analogue and is right to be: both
  `_write_empty_row()` and `clear()` zero every column and write the null pair, so an
  inactive row has no numeric residue.
* Clause 13 mirrors `_rescuer_patient_count()`: present rows only, both members compared,
  distinct generations on one slot left legal, bounded scans with no scratch.
* Scalar domains are the store's: care and ordinal reach i64 extrema through existing public
  writers, so no ceiling below INT64_MAX is authorised, and no recipe figure (60000/120000)
  is a saved-accumulator bound.
* Probe evidence matches the logs: 47/0 public history, 12/0 injected boundary
  characterization observing success, 7→8 on the earlier row, MAX→MIN wrap and
  `last_refused_slot() == -1`. The draft claims neither public reachability nor restoration.

## Metadata faults

All eight re-derive. `injurz` keeps six bytes and stays sorted between `forage` and `jobs`;
513/8191 preserves 193184 and touches no offset, because primary counts do not enter the
payload arithmetic; the child move costs one 8-byte extent with `child_begin[7] = 4` and
owner 8 onward unchanged; the Jobs `u8[8192]` transfer is 8192 values + one 8-byte count word
= 8200, with counts 12/37 and `field_begin[7] = 134`; the u8→i32 retype is 512·3 = 1536 and
the extent bump is 1, both shifting offsets 7..17 and both section totals. Renaming global
field 122 changes no length, since field keys are not framed.

## Runtime repair and bridge

The two-pass preflight is the correct shape: it sits after the existing `_last_refused_slot`
reset and null-`Needs` refusal, selects exactly the rows the current sweep advances
(present ∧ injured ∧ `needs.is_alive`), and refuses before any increment, so both canonical
images stay byte-identical and no lower-index row advances. MAX-1 advancing once and the next
sweep refusing follows. The bridge's seven gates and source pins read as constant chains and
construct nothing; the three self-preloads in the closure are existing and supported, not new
cycles. The corrected disposition — bridges validate, they do not restore — is carried.

## Observations to carry (none blocking)

1. Each zero-accessor mutant needs its **own** out-of-domain witness in that column.
   `_care_context_blocked` is unconstrained by every other clause, so zeroing it is only
   observable against a row whose byte is 2 expecting `COLUMN_FLAGS`. State this per column.
2. The inactive-behind-duplicate order mutant needs an image violating **both** gates on
   distinct rows — duplicates are scanned over present rows only, so a non-canonical inactive
   row alone cannot distinguish the orders.
3. Say explicitly that the overflow refusal writes `_last_refused_slot` while the null-`Needs`
   path continues to leave it at -1; today no `tick_all()` path writes it.
4. Fault 5 isolates the count guard only while all eleven pinned fields stay first and
   unchanged; keep that sentence adjacent to the bypass description.
5. Keep the note that `state_bytes()` orders its eleven values differently from the canonical
   column order (slot, kind, severity, ticks, care, ordinal, rescuer pair, three bytes).

## Disposition

Dispatch. Full saved `Needs`/`Directory`/context identity binding, self-rescue, and bulk
capture/restore with continuation evidence remain explicit follow-ups outside this packet.
