#!/usr/bin/env python3
"""Executable enforcement of docs/planning/movement_profile_readiness.json's own validator_rules.

The register declares a `validator_rules` block in prose. Prose does not fail a
build. This file turns each rule into a predicate over the real document and
then, for every rule, breaks the document on purpose and requires the predicate
to refuse.

NEGATIVE TESTS COME FIRST AND OUTNUMBER THE POSITIVE ONES. A validator with no
negative test is indistinguishable from one that returns "valid"
unconditionally, and that is not a hypothetical here: this register's whole
purpose is to keep three distinct meanings apart -- an authored prohibition, a
missing profile, and a presentation gap -- and a checker that silently passes
everything would let any of the three be filed as another.

The rules enforced, in the register's own numbering:

  R01  288 leaves: exactly 16 species, each with exactly 3 life stages, each
       with exactly 6 modes.
  R02  Every leaf resolves to a key of row_classes.
  R03  row_classes[*].state is one of the three declared states. There is no
       fourth state meaning "policy-approved therefore ready".
  R04  No row_class sets admission_qualified true while a blocking_q2_slot is
       unfilled.
  R05  No q2_slot carries a value. MOVE-C3-R01 7 replaced PR123's
       proposal-lane all-null invariant with "a supplied policy or binding value
       must cite an adopted ruling", and in this revision nothing was supplied,
       so both forms hold: every value is null and q2_slots_with_values is 0.
  R06  A row's blocking_contract is an admission-kind contract. A presentation
       gap gating admission is a FAILURE (MOVE-DEP-R03).
  R07  No presentation_gaps id appears in any blocking_contract or
       evidence_absent.
  R08  totals equal a recount over rows, recomputed here independently of the
       script that wrote the file.
  R09  Exactly six modes, ids 0..5. Climb protection variants live beneath a
       CLIMB row class, never as a seventh mode.
  R10  explicitly_disabled names an authored_prohibition that exists and records
       conditions_that_can_change_it.
  R11  Every cycle3_disposition cites an adopted ruling and introduces no
       numeric value.
  R12  admission_qualified is false everywhere and totals.admission_qualified is
       0.
  R13  Every cited q2 slot exists, and no slot is both blocking and resolved for
       the same row.

Plus the arithmetic MOVE-C3-R01 states outright, recounted rather than read:
32 prohibited CHILD water rows, 16 conditional CHILD climb rows, 32 + 16 = the
48 rows the ruling forbids marking wholly disabled, 8 adopted rows, 144
ordinary-access rows, and zero qualified rows.

THIS FILE MEASURES NOTHING AND AUTHORS NOTHING. Every integer in it is a count
of register rows or a structural bound. There is no body dimension, margin,
speed, cost, air budget, depth or clearance class here.

    python3 tools/test_movement_profile_policy.py
"""

from __future__ import annotations

import collections
import copy
import json
import pathlib
import sys
from typing import Any, Callable, Dict, Iterator, List, Tuple

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
REGISTER_PATH = REPO_ROOT / "docs" / "planning" / "movement_profile_readiness.json"

EXPECTED_SPECIES = 16
EXPECTED_STAGES = 3
EXPECTED_MODES = 6
EXPECTED_LEAVES = EXPECTED_SPECIES * EXPECTED_STAGES * EXPECTED_MODES

ADOPTED_RULINGS = ("MOVE-C3-R01", "MOVE-C2-R01", "DEC-032", "HAZ-001", "SET-MOVE-001")

FAILURES: List[str] = []
CASES: List[str] = []


def check(name: str, condition: bool, note: str = "") -> None:
	"""Record one assertion, keeping every failure rather than stopping at the first."""
	CASES.append(name)
	if not condition:
		FAILURES.append("%s%s" % (name, (" -- " + note) if note else ""))


# --------------------------------------------------------------- the checker --


def iter_leaves(doc: Dict[str, Any]) -> Iterator[Tuple[str, str, str, str]]:
	"""Yield (species, life_stage, mode, row_class_key) for every leaf of `rows`."""
	for species in sorted(doc.get("rows", {})):
		stages = doc["rows"][species]
		if not isinstance(stages, dict):
			continue
		for stage in sorted(stages):
			modes = stages[stage]
			if not isinstance(modes, dict):
				continue
			for mode in sorted(modes):
				yield species, stage, mode, modes[mode]


def recount(doc: Dict[str, Any]) -> Dict[str, int]:
	"""Recount every totals figure from rows and row_classes, ignoring `totals` entirely."""
	classes = doc.get("row_classes", {})
	by_state: collections.Counter = collections.Counter()
	per_stage: collections.Counter = collections.Counter()
	per_stage_state: collections.Counter = collections.Counter()
	counts = collections.Counter()
	connected = ("SWIM_SURFACE", "DIVE", "CLIMB", "TUNNEL_WALK")
	ordinary_modes = ("GROUND_WALK", "FORD_WALK", "TUNNEL_WALK")
	for _species, stage, mode, key in iter_leaves(doc):
		row = classes.get(key)
		if not isinstance(row, dict):
			counts["unresolvable_leaves"] += 1
			continue
		state = row.get("state")
		counts["rows"] += 1
		by_state[state] += 1
		per_stage[stage] += 1
		per_stage_state[(stage, state)] += 1
		if row.get("admission_qualified"):
			counts["admission_qualified"] += 1
		if "ordinary_access_policy" in row:
			counts["ordinary_access_policy_rows"] += 1
		if stage == "ADULT" and mode in connected and state != "adopted":
			counts["adult_connected_rows_not_ready"] += 1
		if stage == "ADULT" and mode in ("GROUND_WALK", "FORD_WALK"):
			counts["adult_ground_ford_rows"] += 1
			if state == "adopted":
				counts["adult_ground_ford_adopted"] += 1
			elif state == "unresolved_q2":
				counts["adult_ground_ford_unresolved"] += 1
		if stage == "CHILD" and mode == "CLIMB" and "climb_action_variants" in row:
			counts["child_climb_conditional"] += 1
		if mode not in ordinary_modes and "ordinary_access_policy" in row:
			counts["ordinary_access_on_connected_mode"] += 1
	result = {
		"rows": counts["rows"],
		"adopted": by_state["adopted"],
		"explicitly_disabled": by_state["explicitly_disabled"],
		"unresolved_q2": by_state["unresolved_q2"],
		"admission_qualified": counts["admission_qualified"],
		"adult_rows": per_stage["ADULT"],
		"adult_connected_rows_not_ready": counts["adult_connected_rows_not_ready"],
		"adult_ground_ford_rows": counts["adult_ground_ford_rows"],
		"adult_ground_ford_adopted": counts["adult_ground_ford_adopted"],
		"adult_ground_ford_unresolved": counts["adult_ground_ford_unresolved"],
		"child_rows": per_stage["CHILD"],
		"child_explicitly_disabled": per_stage_state[("CHILD", "explicitly_disabled")],
		"child_unresolved_q2": per_stage_state[("CHILD", "unresolved_q2")],
		"child_climb_conditional": counts["child_climb_conditional"],
		"elder_rows": per_stage["ELDER"],
		"elder_explicitly_disabled": per_stage_state[("ELDER", "explicitly_disabled")],
		"ordinary_access_policy_rows": counts["ordinary_access_policy_rows"],
	}
	result["_unresolvable_leaves"] = counts["unresolvable_leaves"]
	result["_ordinary_access_on_connected_mode"] = counts["ordinary_access_on_connected_mode"]
	return result


def _r01(doc: Dict[str, Any], out: List[str]) -> None:
	"""R01 -- the shape: 16 species x 3 life stages x 6 modes, exactly 288 leaves."""
	stage_keys = [s["key"] for s in doc.get("life_stages", [])]
	mode_keys = [m["key"] for m in doc.get("modes", [])]
	species_keys = sorted(s["key"] for s in doc.get("species", []))
	rows = doc.get("rows", {})
	if sorted(rows) != species_keys or len(species_keys) != EXPECTED_SPECIES:
		out.append("R01 rows species keys do not match the %d declared species" % EXPECTED_SPECIES)
	leaves = 0
	for species, stages in rows.items():
		if sorted(stages) != sorted(stage_keys):
			out.append("R01 %s does not carry exactly the declared life stages" % species)
			continue
		for stage, modes in stages.items():
			if sorted(modes) != sorted(mode_keys):
				out.append("R01 %s/%s does not carry exactly the six modes" % (species, stage))
				continue
			leaves += len(modes)
	if leaves != EXPECTED_LEAVES:
		out.append("R01 %d leaf entries, expected exactly %d" % (leaves, EXPECTED_LEAVES))


def _r02(doc: Dict[str, Any], out: List[str]) -> None:
	"""R02 -- every leaf value resolves to a key of row_classes."""
	classes = doc.get("row_classes", {})
	for species, stage, mode, key in iter_leaves(doc):
		if key not in classes:
			out.append("R02 %s/%s/%s names unknown row class %r" % (species, stage, mode, key))


def _r03(doc: Dict[str, Any], out: List[str]) -> None:
	"""R03 -- every row_class state is one of the three declared catalog states."""
	declared = set(doc.get("states", {}))
	for key, row in doc.get("row_classes", {}).items():
		if row.get("state") not in declared:
			out.append("R03 %s state %r is not one of the three declared states"
				% (key, row.get("state")))


def _r04(doc: Dict[str, Any], out: List[str]) -> None:
	"""R04 -- admission_qualified is never true while a blocking_q2_slot is unfilled."""
	values = {slot["id"]: slot.get("value") for slot in doc.get("q2_slots", [])}
	for key, row in doc.get("row_classes", {}).items():
		if not row.get("admission_qualified"):
			continue
		unfilled = [s for s in row.get("blocking_q2_slots", []) if values.get(s) is None]
		if unfilled:
			out.append("R04 %s claims admission_qualified with unfilled %s" % (key, unfilled))


def _r05(doc: Dict[str, Any], out: List[str]) -> None:
	"""R05 -- no q2_slot carries a value, and any supplied value would have to cite a ruling."""
	slots = doc.get("q2_slots", [])
	if len(slots) != doc.get("q2_slot_count"):
		out.append("R05 q2_slot_count %r does not match %d slots"
			% (doc.get("q2_slot_count"), len(slots)))
	with_values = 0
	for slot in slots:
		if slot.get("value") is None:
			continue
		with_values += 1
		source = slot.get("cycle3_disposition", {}).get("decision_source", "")
		out.append("R05 %s carries a value %r; unresolved numeric and measurement fields must "
			"remain explicitly empty%s" % (slot.get("id"), slot.get("value"),
			"" if source else " and no adopted ruling is cited"))
	if doc.get("q2_slots_with_values") != with_values:
		out.append("R05 q2_slots_with_values says %r, recount says %d"
			% (doc.get("q2_slots_with_values"), with_values))


def _r06(doc: Dict[str, Any], out: List[str]) -> None:
	"""R06 -- a blocker is an admission contract. A presentation gap gating admission fails."""
	contracts = doc.get("blocking_contracts", {})
	if contracts.get("BC-RIG", {}).get("kind") != "presentation":
		out.append("R06 BC-RIG must stay kind 'presentation'; it is the invariant's control case")
	for key, row in doc.get("row_classes", {}).items():
		named = [row.get("blocking_contract")] + list(row.get("additional_blocking_contracts", []))
		for contract_id in named:
			contract = contracts.get(contract_id)
			if contract is None:
				out.append("R06 %s names unknown blocking contract %r" % (key, contract_id))
			elif contract.get("kind") != "admission":
				out.append("R06 %s is gated by %s of kind %r; MOVE-DEP-R03 forbids a presentation "
					"gap gating admission" % (key, contract_id, contract.get("kind")))


def _r07(doc: Dict[str, Any], out: List[str]) -> None:
	"""R07 -- no presentation_gaps id appears as a blocker or as absent admission evidence."""
	gap_ids = {gap["id"] for gap in doc.get("presentation_gaps", [])}
	for key, row in doc.get("row_classes", {}).items():
		named = set([row.get("blocking_contract")])
		named |= set(row.get("additional_blocking_contracts", []))
		named |= set(row.get("evidence_absent", []))
		leaked = sorted(gap_ids & named)
		if leaked:
			out.append("R07 %s records presentation gap(s) %s as an admission blocker"
				% (key, leaked))


def _r08(doc: Dict[str, Any], out: List[str]) -> None:
	"""R08 -- totals equal a recount over rows, computed here and not read from the file."""
	counted = recount(doc)
	declared = doc.get("totals", {})
	for name, value in sorted(counted.items()):
		if name.startswith("_"):
			continue
		if declared.get(name) != value:
			out.append("R08 totals.%s is %r, recount says %d" % (name, declared.get(name), value))
	extra = sorted(set(declared) - set(counted) - {"cross_check"})
	if extra:
		out.append("R08 totals carries %s which no recount produces" % extra)


def _r09(doc: Dict[str, Any], out: List[str]) -> None:
	"""R09 -- exactly six modes with ids 0..5; climb variants never become a seventh mode."""
	modes = doc.get("modes", [])
	if len(modes) != EXPECTED_MODES or sorted(m["id"] for m in modes) != list(range(EXPECTED_MODES)):
		out.append("R09 modes must be exactly %d entries with ids 0..%d, found %d with ids %s"
			% (EXPECTED_MODES, EXPECTED_MODES - 1, len(modes), sorted(m.get("id") for m in modes)))
	mode_keys = {m["key"] for m in modes}
	for _species, _stage, mode, _key in iter_leaves(doc):
		if mode not in mode_keys:
			out.append("R09 rows carry mode %r which is not a declared mode" % mode)
	classes = doc.get("row_classes", {})
	carriers = {k for k, row in classes.items() if "climb_action_variants" in row}
	used_on = {mode for _s, _st, mode, key in iter_leaves(doc) if key in carriers}
	if used_on - {"CLIMB"}:
		out.append("R09 climb_action_variants reached non-CLIMB mode(s) %s" % sorted(used_on - {"CLIMB"}))


def _r10(doc: Dict[str, Any], out: List[str]) -> None:
	"""R10 -- explicitly_disabled names a real authored prohibition with its escape conditions."""
	prohibitions = {p["id"]: p for p in doc.get("authored_prohibitions", [])}
	for key, row in doc.get("row_classes", {}).items():
		if row.get("state") != "explicitly_disabled":
			if "authored_prohibition" in row:
				out.append("R10 %s names an authored_prohibition but is not explicitly_disabled"
					% key)
			continue
		named = row.get("authored_prohibition")
		if named not in prohibitions:
			out.append("R10 %s is explicitly_disabled naming prohibition %r, which does not exist"
				% (key, named))
			continue
		if not prohibitions[named].get("conditions_that_can_change_it"):
			out.append("R10 prohibition %s records no conditions_that_can_change_it" % named)
		if not row.get("decision_source"):
			out.append("R10 %s is explicitly_disabled with no decision_source" % key)
	for pid, prohibition in prohibitions.items():
		if not prohibition.get("conditions_that_can_change_it"):
			out.append("R10 authored prohibition %s records no conditions_that_can_change_it" % pid)


def _numeric_leaves(value: Any, path: str = "") -> List[str]:
	"""Every JSON path under `value` holding a number. A policy disposition may hold none."""
	found: List[str] = []
	if isinstance(value, bool):
		return found
	if isinstance(value, (int, float)):
		return [path or "<root>"]
	if isinstance(value, dict):
		for key, item in value.items():
			found += _numeric_leaves(item, "%s.%s" % (path, key))
	elif isinstance(value, list):
		for index, item in enumerate(value):
			found += _numeric_leaves(item, "%s[%d]" % (path, index))
	return found


def _r11(doc: Dict[str, Any], out: List[str]) -> None:
	"""R11 -- a cycle3_disposition cites an adopted ruling and introduces no numeric value."""
	for slot in doc.get("q2_slots", []):
		disposition = slot.get("cycle3_disposition")
		if disposition is None:
			continue
		source = disposition.get("decision_source", "")
		if not any(ruling in source for ruling in ADOPTED_RULINGS):
			out.append("R11 %s cycle3_disposition decision_source %r names no adopted ruling"
				% (slot.get("id"), source))
		if not disposition.get("status"):
			out.append("R11 %s cycle3_disposition records no status" % slot.get("id"))
		numbers = _numeric_leaves(disposition, slot.get("id", "?"))
		if numbers:
			out.append("R11 %s cycle3_disposition introduces value(s) at %s; a policy ruling "
				"supplies no dimension, cost, speed, air budget, depth or clearance"
				% (slot.get("id"), numbers))


def _r12(doc: Dict[str, Any], out: List[str]) -> None:
	"""R12 -- nothing is admission_qualified. No measured envelope exists."""
	for key, row in doc.get("row_classes", {}).items():
		if row.get("admission_qualified") is not False:
			out.append("R12 %s admission_qualified is %r; no measured envelope exists"
				% (key, row.get("admission_qualified")))
	if doc.get("totals", {}).get("admission_qualified") != 0:
		out.append("R12 totals.admission_qualified is %r, must be 0"
			% doc.get("totals", {}).get("admission_qualified"))
	if doc.get("answers_q2") is not False:
		out.append("R12 answers_q2 is %r; MOVE-C3-R01 7 forbids marking Q2 fully answered"
			% doc.get("answers_q2"))
	if doc.get("closes_gates"):
		out.append("R12 closes_gates is %r; no movement gate is closed" % doc.get("closes_gates"))


def _r13(doc: Dict[str, Any], out: List[str]) -> None:
	"""R13 -- every q2 slot id a row cites exists, and no slot is both blocking and resolved."""
	known = {slot["id"] for slot in doc.get("q2_slots", [])}
	for key, row in doc.get("row_classes", {}).items():
		blocking = set(row.get("blocking_q2_slots", []))
		resolved = set(row.get("resolved_q2_slots", []))
		unknown = sorted((blocking | resolved) - known)
		if unknown:
			out.append("R13 %s cites unknown q2 slot(s) %s" % (key, unknown))
		both = sorted(blocking & resolved)
		if both:
			out.append("R13 %s lists %s as both blocking and resolved" % (key, both))


RULES: Tuple[Callable[[Dict[str, Any], List[str]], None], ...] = (
	_r01, _r02, _r03, _r04, _r05, _r06, _r07, _r08, _r09, _r10, _r11, _r12, _r13,
)


def validate(doc: Dict[str, Any]) -> List[str]:
	"""Every rule violation in `doc`, as human-readable strings. Empty means the register holds."""
	problems: List[str] = []
	for rule in RULES:
		rule(doc, problems)
	return problems


# ------------------------------------------------------- NEGATIVE TESTS FIRST --


REGISTER: Dict[str, Any] = json.loads(REGISTER_PATH.read_text(encoding="utf-8"))


def broken(mutate: Callable[[Dict[str, Any]], None]) -> List[str]:
	"""Apply `mutate` to a private deep copy of the register and return what validate refuses."""
	doc = copy.deepcopy(REGISTER)
	mutate(doc)
	return validate(doc)


def _refused(name: str, rule: str, mutate: Callable[[Dict[str, Any]], None]) -> None:
	"""Require that `mutate` produces at least one problem, and that `rule` is among them."""
	problems = broken(mutate)
	check("%s refused" % name, bool(problems), "the mutated register passed")
	check("%s refused by %s" % (name, rule), any(p.startswith(rule) for p in problems),
		"problems were %s" % problems[:3])


def test_n01_leaf_count() -> None:
	"""A register with 287 leaves, or 289, must be refused by R01."""
	def drop(doc: Dict[str, Any]) -> None:
		del doc["rows"]["mouse"]["ADULT"]["DIVE"]
	_refused("N01a a deleted mode leaf", "R01", drop)

	def add(doc: Dict[str, Any]) -> None:
		doc["rows"]["mouse"]["ADULT"]["FLIGHT"] = "RC_ADULT_SWIM"
	_refused("N01b a seventh mode leaf", "R01", add)

	def drop_species(doc: Dict[str, Any]) -> None:
		del doc["rows"]["badger"]
	_refused("N01c a deleted species", "R01", drop_species)

	def drop_stage(doc: Dict[str, Any]) -> None:
		del doc["rows"]["shrew"]["ELDER"]
	_refused("N01d a deleted life stage", "R01", drop_stage)


def test_n02_unknown_row_class() -> None:
	"""A leaf naming a row class that does not exist must be refused by R02."""
	def rename(doc: Dict[str, Any]) -> None:
		doc["rows"]["otter"]["CHILD"]["CLIMB"] = "RC_CHILD_HAZ"
	_refused("N02a a leaf naming the retired RC_CHILD_HAZ", "R02", rename)

	def typo(doc: Dict[str, Any]) -> None:
		doc["rows"]["fox"]["ADULT"]["TUNNEL_WALK"] = "RC_ADULT_TUNNELL"
	_refused("N02b a mistyped row class", "R02", typo)


def test_n03_fourth_state() -> None:
	"""A fourth catalog state meaning 'policy-approved therefore ready' must be refused."""
	def invent(doc: Dict[str, Any]) -> None:
		doc["row_classes"]["RC_ADULT_TUNNEL"]["state"] = "policy_approved"
	_refused("N03a a fourth state", "R03", invent)

	def enable(doc: Dict[str, Any]) -> None:
		doc["row_classes"]["RC_ADULT_GROUND_STARTER"]["state"] = "ENABLED"
	_refused("N03b a row promoted to ENABLED", "R03", enable)


def test_n04_qualified_while_blocked() -> None:
	"""admission_qualified true with an unfilled blocking slot must be refused by R04."""
	def qualify(doc: Dict[str, Any]) -> None:
		doc["row_classes"]["RC_ADULT_GROUND_STARTER"]["admission_qualified"] = True
	_refused("N04 a starter row marked admission_qualified", "R04", qualify)


def test_n05_slot_carrying_a_value() -> None:
	"""A slot carrying an invented depth, and a miscounted q2_slots_with_values, must be refused."""
	def depth(doc: Dict[str, Any]) -> None:
		for slot in doc["q2_slots"]:
			if slot["id"] == "Q2-24":
				slot["value"] = 128
	_refused("N05a an invented max wading depth in Q2-24", "R05", depth)

	def speed(doc: Dict[str, Any]) -> None:
		for slot in doc["q2_slots"]:
			if slot["id"] == "Q2-06":
				slot["value"] = {"swim_u_per_s": 2048}
	_refused("N05b an invented swim speed in Q2-06", "R05", speed)

	def miscount(doc: Dict[str, Any]) -> None:
		doc["q2_slots_with_values"] = 3
	_refused("N05c a q2_slots_with_values that no recount produces", "R05", miscount)

	def shrink(doc: Dict[str, Any]) -> None:
		doc["q2_slots"] = doc["q2_slots"][:30]
	_refused("N05d a slot list shorter than q2_slot_count", "R05", shrink)


def test_n06_presentation_gap_as_blocker() -> None:
	"""A row blocked by BC-RIG, and a BC-RIG downgraded to admission, must both be refused."""
	def gate(doc: Dict[str, Any]) -> None:
		doc["row_classes"]["RC_CHILD_NONHAZ"]["blocking_contract"] = "BC-RIG"
	_refused("N06a a CHILD row gated by the rig contract", "R06", gate)

	def gate_extra(doc: Dict[str, Any]) -> None:
		doc["row_classes"]["RC_ADULT_SWIM"]["additional_blocking_contracts"].append("BC-RIG")
	_refused("N06b a rig contract added to the secondary blockers", "R06", gate_extra)

	def relabel(doc: Dict[str, Any]) -> None:
		doc["blocking_contracts"]["BC-RIG"]["kind"] = "admission"
	_refused("N06c BC-RIG relabelled as an admission contract", "R06", relabel)

	def unknown(doc: Dict[str, Any]) -> None:
		doc["row_classes"]["RC_ADULT_DIVE"]["blocking_contract"] = "BC-INVENTED"
	_refused("N06d a blocker naming no declared contract", "R06", unknown)


def test_n07_presentation_gap_leak() -> None:
	"""A presentation gap id recorded as absent admission evidence must be refused by R07."""
	def leak(doc: Dict[str, Any]) -> None:
		doc["row_classes"]["RC_CHILD_NONHAZ"]["evidence_absent"].append("PG-RIG-STAGE-VARIANT")
	_refused("N07a a missing child rig recorded as absent admission evidence", "R07", leak)

	def leak_blocker(doc: Dict[str, Any]) -> None:
		doc["row_classes"]["RC_ELDER_NONHAZ"]["additional_blocking_contracts"].append("PG-CLIPS")
	_refused("N07b missing clips recorded as a blocker", "R07", leak_blocker)


def test_n08_totals_not_a_recount() -> None:
	"""Any totals figure that disagrees with a recount over rows must be refused by R08."""
	for name in ("rows", "adopted", "explicitly_disabled", "unresolved_q2", "child_rows",
			"child_explicitly_disabled", "child_climb_conditional",
			"ordinary_access_policy_rows", "adult_connected_rows_not_ready"):
		def bump(doc: Dict[str, Any], key: str = name) -> None:
			doc["totals"][key] = doc["totals"][key] + 1
		_refused("N08 totals.%s off by one" % name, "R08", bump)

	def stale(doc: Dict[str, Any]) -> None:
		# The PR123 figures, left behind while the rows moved under them.
		doc["totals"]["explicitly_disabled"] = 0
		doc["totals"]["unresolved_q2"] = 280
	_refused("N08 the pre-Cycle-3 totals left on Cycle-3 rows", "R08", stale)

	def row_moved(doc: Dict[str, Any]) -> None:
		# Rows change, totals do not: the recount must catch the drift, not the label.
		doc["rows"]["hare"]["CHILD"]["DIVE"] = "RC_CHILD_NONHAZ"
	_refused("N08 a prohibited child dive quietly reclassified", "R08", row_moved)


def test_n09_seventh_mode() -> None:
	"""An added or renumbered mode, and climb variants on another mode, must be refused by R09."""
	def seventh(doc: Dict[str, Any]) -> None:
		doc["modes"].append({"key": "PROTECTED_CLIMB", "id": 6, "system_scope": "adopted",
			"profiled_in_code": False, "source": "invented"})
	_refused("N09a a seventh mode id", "R09", seventh)

	def renumber(doc: Dict[str, Any]) -> None:
		doc["modes"][4]["id"] = 9
	_refused("N09b a renumbered mode", "R09", renumber)

	def spread(doc: Dict[str, Any]) -> None:
		doc["rows"]["mole"]["CHILD"]["TUNNEL_WALK"] = "RC_CHILD_CLIMB_CONDITIONAL"
	_refused("N09c climb variants reaching a tunnel row", "R09", spread)


def test_n10_disabled_without_a_prohibition() -> None:
	"""A disabled row with no authored prohibition, or no escape conditions, must be refused."""
	def orphan(doc: Dict[str, Any]) -> None:
		del doc["row_classes"]["RC_CHILD_WATER_PROHIBITED"]["authored_prohibition"]
	_refused("N10a a disabled row naming no prohibition", "R10", orphan)

	def dangling(doc: Dict[str, Any]) -> None:
		doc["row_classes"]["RC_CHILD_WATER_PROHIBITED"]["authored_prohibition"] = "PROHIB-INVENTED"
	_refused("N10b a disabled row naming a prohibition that does not exist", "R10", dangling)

	def no_conditions(doc: Dict[str, Any]) -> None:
		for prohibition in doc["authored_prohibitions"]:
			if prohibition["id"] == "PROHIB-CHILD-HAZARDOUS-ENTRY":
				prohibition["conditions_that_can_change_it"] = ""
	_refused("N10c a prohibition with its escape conditions erased", "R10", no_conditions)

	def missing_profile_as_prohibition(doc: Dict[str, Any]) -> None:
		# MOVE-C3-R01 5: a missing profile is never an authored inability.
		doc["row_classes"]["RC_ADULT_SWIM"]["state"] = "explicitly_disabled"
	_refused("N10d an unprofiled adult swim relabelled as prohibited", "R10",
		missing_profile_as_prohibition)


def test_n11_disposition_carrying_a_value() -> None:
	"""A disposition that cites no ruling, or smuggles a number, must be refused by R11."""
	def uncited(doc: Dict[str, Any]) -> None:
		for slot in doc["q2_slots"]:
			if slot["id"] == "Q2-32":
				slot["cycle3_disposition"]["decision_source"] = "seemed reasonable"
	_refused("N11a a disposition citing no adopted ruling", "R11", uncited)

	def smuggled(doc: Dict[str, Any]) -> None:
		for slot in doc["q2_slots"]:
			if slot["id"] == "Q2-24":
				slot["cycle3_disposition"]["max_water_depth_u"] = 128
	_refused("N11b a depth smuggled into a disposition", "R11", smuggled)

	def smuggled_list(doc: Dict[str, Any]) -> None:
		for slot in doc["q2_slots"]:
			if slot["id"] == "Q2-35":
				slot["cycle3_disposition"]["connected_speeds_u_per_s"] = [3277, 4096, 3072]
	_refused("N11c speeds smuggled into a disposition as a list", "R11", smuggled_list)


def test_n12_qualification_creep() -> None:
	"""Any claim that Q2 is answered or a gate closed must be refused by R12."""
	def answered(doc: Dict[str, Any]) -> None:
		doc["answers_q2"] = True
	_refused("N12a answers_q2 set true", "R12", answered)

	def closed(doc: Dict[str, Any]) -> None:
		doc["closes_gates"] = ["MOVE-G01"]
	_refused("N12b a movement gate claimed closed", "R12", closed)

	def qualified(doc: Dict[str, Any]) -> None:
		doc["row_classes"]["RC_ADULT_FORD_STARTER"]["admission_qualified"] = True
		doc["totals"]["admission_qualified"] = 1
	_refused("N12c a ford row marked production qualified", "R12", qualified)


def test_n13_dangling_slot_reference() -> None:
	"""A row citing a slot that does not exist, or citing one twice, must be refused by R13."""
	def dangling(doc: Dict[str, Any]) -> None:
		doc["row_classes"]["RC_ELDER_NONHAZ"]["blocking_q2_slots"].append("Q2-99")
	_refused("N13a a row blocked on a slot that does not exist", "R13", dangling)

	def both(doc: Dict[str, Any]) -> None:
		doc["row_classes"]["RC_ELDER_HAZ"]["blocking_q2_slots"].append("Q2-33")
	_refused("N13b a slot listed as both blocking and resolved", "R13", both)


def test_n14_the_checker_is_not_a_tautology() -> None:
	"""An empty document and a gutted one must both be refused, or `validate` proves nothing."""
	check("N14a an empty document is refused", bool(validate({})))
	check("N14b a document with no rows is refused",
		bool(validate({"rows": {}, "row_classes": {}, "totals": {"rows": 288}})))
	gutted = copy.deepcopy(REGISTER)
	gutted["row_classes"] = {}
	check("N14c a document with no row classes is refused", bool(validate(gutted)))


# ------------------------------------------------------------ POSITIVE TESTS --


def test_p01_the_real_register_holds() -> None:
	"""The committed register satisfies every rule it declares."""
	problems = validate(REGISTER)
	check("P01 the committed register satisfies its own validator_rules",
		not problems, "; ".join(problems[:6]))


def test_p02_the_ruling_arithmetic_is_recounted() -> None:
	"""MOVE-C3-R01's stated row arithmetic, recounted from rows rather than read from totals."""
	counted = recount(REGISTER)
	check("P02a 288 leaves", counted["rows"] == EXPECTED_LEAVES, str(counted["rows"]))
	check("P02b 32 CHILD species/mode rows carry a definite prohibition",
		counted["explicitly_disabled"] == 32 and counted["child_explicitly_disabled"] == 32,
		str(counted["explicitly_disabled"]))
	check("P02c 16 CHILD CLIMB rows are conditional, not disabled",
		counted["child_climb_conditional"] == 16, str(counted["child_climb_conditional"]))
	check("P02d 32 + 16 = the 48 rows the ruling forbids marking wholly disabled",
		counted["explicitly_disabled"] + counted["child_climb_conditional"] == 48)
	check("P02e the 8 adopted starter rows are unchanged", counted["adopted"] == 8,
		str(counted["adopted"]))
	check("P02f 64 adult connected rows remain not ready",
		counted["adult_connected_rows_not_ready"] == 64)
	check("P02g 248 rows remain unresolved_q2", counted["unresolved_q2"] == 248,
		str(counted["unresolved_q2"]))
	check("P02h 144 rows carry the ordinary-access policy permission",
		counted["ordinary_access_policy_rows"] == 144,
		str(counted["ordinary_access_policy_rows"]))
	check("P02i the ordinary-access permission never reaches a connected mode",
		counted["_ordinary_access_on_connected_mode"] == 0)
	check("P02j every leaf resolves", counted["_unresolvable_leaves"] == 0)
	check("P02k the three stages each hold 96 rows",
		counted["adult_rows"] == counted["child_rows"] == counted["elder_rows"] == 96)
	check("P02l no ELDER row is disabled: no blanket age veto",
		counted["elder_explicitly_disabled"] == 0)


def test_p03_child_water_is_disabled_and_child_climb_is_not() -> None:
	"""Every species: CHILD swim and dive disabled, CHILD climb conditional, CHILD ground open."""
	disabled = 0
	conditional = 0
	ordinary = 0
	classes = REGISTER["row_classes"]
	for species, stage, mode, key in iter_leaves(REGISTER):
		if stage != "CHILD":
			continue
		state = classes[key]["state"]
		if mode in ("SWIM_SURFACE", "DIVE"):
			disabled += int(state == "explicitly_disabled")
		elif mode == "CLIMB":
			conditional += int(state == "unresolved_q2" and "climb_action_variants" in classes[key])
		else:
			ordinary += int(state == "unresolved_q2" and "ordinary_access_policy" in classes[key])
		del species
	check("P03a all 32 CHILD water rows are explicitly_disabled", disabled == 32, str(disabled))
	check("P03b all 16 CHILD climb rows are conditional and still unresolved",
		conditional == 16, str(conditional))
	check("P03c all 48 CHILD ordinary rows are permitted-but-unprofiled", ordinary == 48,
		str(ordinary))


def test_p04_recovery_is_recorded_separately_from_entry() -> None:
	"""Rescue of a child already in danger is a different state and is not a row."""
	recovery = REGISTER.get("recovery_is_not_entry", {})
	check("P04a recovery is recorded", bool(recovery))
	check("P04b recovery is not a mode row", recovery.get("recorded_as_mode_row") is False)
	check("P04c recovery grants no voluntary mode", bool(recovery.get("grants_nothing")))
	prohibition = {p["id"]: p for p in REGISTER["authored_prohibitions"]}
	entry = prohibition.get("PROHIB-CHILD-HAZARDOUS-ENTRY", {})
	check("P04d the prohibition is a new-entry restriction only",
		entry.get("is_new_entry_restriction_only") is True)
	check("P04e no escort or consent overrides it", len(entry.get("cannot_be_overridden_by", [])) >= 3)
	water = REGISTER["row_classes"]["RC_CHILD_WATER_PROHIBITED"]
	check("P04f the disabled water row points at the recovery record",
		"recovery_is_not_entry" in water.get("not_covered_by_this_row", ""))


def test_p05_climb_protection_is_a_connection_property() -> None:
	"""CHILD climb carries both variants: unprotected prohibited, protected permitted."""
	variants = REGISTER["row_classes"]["RC_CHILD_CLIMB_CONDITIONAL"]["climb_action_variants"]
	check("P05a both protection cases are recorded",
		sorted(variants) == ["protected", "unprotected"])
	check("P05b unprotected child entry is prohibited",
		variants["unprotected"]["policy"] == "PROHIBITED")
	check("P05c protected child access is permitted only as nonproductive and only with a profile",
		variants["protected"]["policy"].startswith("PERMITTED_NONPRODUCTIVE"))
	check("P05d protected access authorizes no productive job",
		"does_not_authorize" in variants["protected"])
	check("P05e no seventh mode was created",
		len(REGISTER["modes"]) == EXPECTED_MODES)


def test_p06_open_slots_stay_open() -> None:
	"""The 22 slots MOVE-C3-R01 did not touch keep their units, owners and emptiness."""
	touched = {s["id"] for s in REGISTER["q2_slots"] if "cycle3_disposition" in s}
	untouched = [s for s in REGISTER["q2_slots"] if "cycle3_disposition" not in s]
	check("P06a 13 slots carry a Cycle 3 disposition", len(touched) == 13, str(sorted(touched)))
	check("P06b 22 slots remain untouched", len(untouched) == 22, str(len(untouched)))
	check("P06c q2_slots_with_cycle3_disposition agrees with the recount",
		REGISTER.get("q2_slots_with_cycle3_disposition") == len(touched))
	check("P06d every untouched slot still names its units and owner",
		all(slot.get("units") and slot.get("owner") for slot in untouched))
	check("P06e every slot in the register is still empty",
		all(slot["value"] is None for slot in REGISTER["q2_slots"]))
	for required in ("Q2-32", "Q2-33", "Q2-34", "Q2-35", "Q2-24", "Q2-31"):
		check("P06f %s carries the Cycle 3 disposition" % required, required in touched)
	for still_open in ("Q2-01", "Q2-06", "Q2-12", "Q2-26", "Q2-30"):
		check("P06g %s is still open with no disposition" % still_open, still_open not in touched)


def test_p07_missing_definitions_are_not_prohibitions() -> None:
	"""MOVE-C3-R01 5's split: an unauthored definition is not an authored inability."""
	block = REGISTER.get("missing_definitions_not_prohibitions", {})
	check("P07a the split is recorded", bool(block.get("items")))
	check("P07b it carries the not-ready state, not the disabled one",
		block.get("state") == "unresolved_q2")
	known = {slot["id"] for slot in REGISTER["q2_slots"]}
	cited = {s for item in block.get("items", []) for s in item.get("q2_slots", [])}
	check("P07c every cited slot exists", cited and cited <= known, str(sorted(cited - known)))
	check("P07d no species-wide prohibition was created",
		REGISTER["species_wide_prohibition_count"] == 0
		and REGISTER["species_wide_prohibitions"] == [])


def test_p08_the_register_declares_the_rules_this_file_enforces() -> None:
	"""Each rule this file implements is still declared in the register's own validator_rules."""
	rules = REGISTER["validator_rules"]
	check("P08a the register declares at least one rule per implemented check",
		len(rules) >= len(RULES), "%d rules, %d checks" % (len(rules), len(RULES)))
	joined = " ".join(rules)
	for phrase in ("288 leaf entries", "row_classes", "admission_qualified", "presentation",
			"totals MUST equal the recomputed counts", "explicitly_disabled",
			"cycle3_disposition"):
		check("P08b validator_rules still states %r" % phrase, phrase in joined)


def main() -> int:
	"""Run every test and print the summary line this lane reports verbatim."""
	for name, test in sorted(globals().items()):
		if name.startswith("test_") and callable(test):
			try:
				test()
			except Exception as error:  # noqa: BLE001 -- a crash is a failure, not a lost run
				check("%s raised %s: %s" % (name, type(error).__name__, error), False)
	for failure in FAILURES:
		print("FAIL %s" % failure)
	print("test_movement_profile_policy: %s -- %d check(s), %d failure(s)"
		% ("FAIL" if FAILURES else "PASS", len(CASES), len(FAILURES)))
	return 1 if FAILURES else 0


if __name__ == "__main__":
	sys.exit(main())
