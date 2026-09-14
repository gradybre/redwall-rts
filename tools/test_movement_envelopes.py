#!/usr/bin/env python3
"""Self-test for the movement-envelope schema, validator and anchored fit arithmetic.

NEGATIVE TESTS COME FIRST AND OUTNUMBER THE POSITIVE ONES, deliberately. A
validator with no negative test is indistinguishable from one that returns
"valid" unconditionally, and a fit function with no refusal test is
indistinguishable from one that returns class 1 for everything.

The case this file exists for is CASE N01-N05: a swept body whose translated
minimum is negative at the baseline +256/+256 root offset. The clearance square
is anchored at its NORTH-WEST corner, so class k grows it south and east only.
`ox + xlo >= 0` never mentions k. The tests below therefore do three separate
things with that record:

  * assert the reported outcome is PLACEMENT_INCOMPATIBLE_AT_OFFSET and NOT the
    class-domain refusal, because "needs a bigger class" is false here and would
    send a reader hunting for a k that does not exist;
  * brute-force EVERY class in the published 1..512 domain with a containment
    predicate written out longhand in this file -- not the module's helper --
    and require that exactly zero of them admit the body;
  * show the same body fits at a different declared offset, which proves the
    refusal is about the placement and not about the measurements.

Re-centring is not tested as a remedy because it is not one: MOVE-C2-R01 5
requires a separately reviewed MOVE-G02 position/anchor/save contract.

CASE T1-T4 is the schema 2 repair (MOVE-C3-R01 6). Schema 1 required
`interpolation_error_bound_units` and then never applied it, so a record could
declare a residual interpolation error, carry zero margins, and still be handed
FIT_OK class 1. The T tests refuse that record on every axis independently,
prove that covering the residual is what exposes the placement refusal it was
hiding, refuse an unevidenced zero and an inward micrometre export, and refuse
a schema 1 document that would otherwise satisfy every schema 2 rule.

EVERY DIMENSION IN THIS FILE IS SYNTHETIC. There is no measured body width,
height, gear extent or load bound here or anywhere in this lane's output. The
numbers were chosen to sit on the arithmetic's boundaries, and the species key
is not a Redwall species so that a search for a real one cannot find them.

    python3 tools/test_movement_envelopes.py
"""

from __future__ import annotations

import copy
import json
import math
import pathlib
import subprocess
import sys
import tempfile
from fractions import Fraction
from typing import Any, Dict, List, Optional, Tuple

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import validate_movement_envelopes as vme  # noqa: E402

FAILURES: List[str] = []
CASES: List[str] = []

SCHEMA = json.loads(vme.SCHEMA_PATH.read_text(encoding="utf-8"))
GEOMETRY = vme.load_source_geometry()
TOOL = pathlib.Path(__file__).resolve().parent / "validate_movement_envelopes.py"


def check(name: str, condition: bool, note: str = "") -> None:
	"""Record one assertion, keeping every failure rather than stopping at the first."""
	CASES.append(name)
	if not condition:
		FAILURES.append("%s%s" % (name, (" -- " + note) if note else ""))


# --- synthetic record construction, written independently of the module's fixture helper ---------


def synthetic_record(x_min: int, x_max: int, z_min: int, z_max: int, margin: int = 4,
		offset: Tuple[int, int] = (256, 256), residual: int = 0) -> Dict[str, Any]:
	"""One well-formed synthetic record with the given INVENTED micrometre extrema."""
	margin_block: Dict[str, Any] = {"x": margin, "y": margin, "z": margin,
		"provenance": "synthetic fixture constant"}
	if margin == 0:
		margin_block["zero_margin_justification"] = (
			"synthetic fixture; there is no measurement owner and no real allowance to declare")
	return {
		"data_class": "synthetic_fixture",
		"synthetic_note": "SYNTHETIC -- tooling test only, not a measurement, not a profile.",
		"identity": {
			"species_key": "synthetic_specimen_alpha", "life_stage": "ADULT", "life_stage_id": 0,
			"mode": "GROUND_WALK", "mode_id": 0, "posture": "SYNTHETIC_TEST_POSTURE",
			"profile_revision": 1,
		},
		"variant": {
			"variant_key": "SYNTHETIC", "equipment": [], "cargo": [], "support_attachments": [],
			"all_listed_items_included_in_sweep": True,
		},
		"measurement": {
			"method": "synthetic constant",
			"states_covered": ["ENTRY", "TRAVEL", "HOLD", "TURN", "REVERSAL", "RETREAT", "EXIT"],
			"orientations_covered": ["SYNTHETIC_ALL_YAW"],
			"pose_interpolation_covered": True,
			"interpolation_error_bound_units": residual,
			"zero_residual_evidence": (
				"synthetic fixture; the invented extrema ARE the whole sweep, so nothing continuous "
				"lies outside them. This states nothing about any measured body."),
			"micrometre_export_rounding": "minima_floor_maxima_ceil",
			"bounds_micrometres": {
				"x_min": x_min, "x_max": x_max, "y_min": 0, "y_max": 100000,
				"z_min": z_min, "z_max": z_max,
			},
		},
		"margin_units": margin_block,
		"anchor_to_root_offset_units": {"x": offset[0], "z": offset[1]},
	}


def document(records: List[Dict[str, Any]]) -> Dict[str, Any]:
	"""Wrap records in a file whose convention block matches the owning GDScript sources."""
	convention = {"up_axis": "+Y", "forward_axis": "-Z", "cell_anchor": "north_west"}
	convention.update(GEOMETRY.convention_fields())
	return {
		"schema_version": 2,
		"units": {"simulation_units_per_metre": 1024,
			"measured_input_unit": "signed_integer_micrometres"},
		"convention": convention,
		"records": records,
	}


def problems_for(record: Dict[str, Any]) -> List[str]:
	"""Every structural and semantic problem one record produces inside a well-formed file."""
	instance = document([record])
	found = vme.validate_instance(instance, SCHEMA)
	found.extend(vme.file_semantic_problems(instance, GEOMETRY))
	found.extend(vme.record_semantic_problems(record, "$.records[0]", GEOMETRY))
	return found


def fit_for(record: Dict[str, Any]) -> vme.FitResult:
	"""The fit of one record, after asserting it is otherwise clean."""
	found = problems_for(record)
	check("precondition record is valid: %s" % record["variant"]["variant_key"], not found,
		"; ".join(found))
	return vme.compute_fit(record, GEOMETRY)


# --- independent oracles, written longhand so a mutation in the module cannot move them ----------


def independently_contained(low_x: int, low_z: int, high_x: int, high_z: int,
		clearance_class: int) -> bool:
	"""MOVE-C2-R01 4's four conditions, transcribed here so the module's helper is not the judge."""
	side = GEOMETRY.cell_size_units * clearance_class
	if low_x < 0:
		return False
	if low_z < 0:
		return False
	if high_x > side:
		return False
	if high_z > side:
		return False
	return True


def independently_least_class(low_x: int, low_z: int, high_x: int, high_z: int) -> Optional[int]:
	"""The smallest admitting class found by exhaustive search, or None when none admits."""
	for candidate in range(GEOMETRY.clearance_class_min, GEOMETRY.clearance_class_max + 1):
		if independently_contained(low_x, low_z, high_x, high_z, candidate):
			return candidate
	return None


def independently_quantized(min_um: int, max_um: int, margin: int) -> Tuple[int, int]:
	"""Outward quantization via exact rationals: floor the minimum, ceil the maximum, then widen."""
	low = math.floor(Fraction(1024 * min_um, vme.MICROMETRES_PER_METRE)) - margin
	high = math.ceil(Fraction(1024 * max_um, vme.MICROMETRES_PER_METRE)) + margin
	return low, high


# =================================================================================================
# NEGATIVE TESTS
# =================================================================================================


def test_negative_translated_minimum_is_not_a_class_problem() -> None:
	"""N01-N05: the case MOVE-C2-R01 5 and the Cycle 2 boundary require this tooling to reproduce."""
	wide = synthetic_record(-400000, 400000, -400000, 400000, margin=8)
	wide["variant"]["variant_key"] = "SYNTHETIC_WIDE"
	fit = fit_for(wide)
	check("N01 a negative translated minimum reports PLACEMENT_INCOMPATIBLE_AT_OFFSET",
		fit.outcome == vme.REFUSE_PLACEMENT, fit.outcome)
	check("N01b it is NOT reported as a class-domain problem",
		fit.outcome != vme.REFUSE_CLASS_DOMAIN)
	check("N01c the detail says no class repairs it, not that a larger class is needed",
		"no clearance class repairs this" in fit.detail and "larger-class" in fit.detail,
		fit.detail)
	translated = fit.translated_bounds
	check("N02 the translated minimum really is negative",
		translated["x_lo"] < 0 and translated["z_lo"] < 0, str(translated))
	admitting = [k for k in range(GEOMETRY.clearance_class_min, GEOMETRY.clearance_class_max + 1)
		if independently_contained(translated["x_lo"], translated["z_lo"],
			translated["x_hi"], translated["z_hi"], k)]
	check("N02b exhaustively, 0 of the %d published classes admit it"
		% (GEOMETRY.clearance_class_max - GEOMETRY.clearance_class_min + 1),
		admitting == [] and fit.admitting_class_count == 0,
		"module said %d, this file found %s" % (fit.admitting_class_count, admitting))
	check("N03 not even the largest published class admits it",
		not independently_contained(translated["x_lo"], translated["z_lo"],
			translated["x_hi"], translated["z_hi"], GEOMETRY.clearance_class_max))
	check("N03b a naive ceil(max(width,depth)/cell) would have answered a small class",
		fit.naive_lower_bound_class is not None
		and fit.naive_lower_bound_class <= GEOMETRY.clearance_class_max,
		str(fit.naive_lower_bound_class))
	check("N05 require_class() refuses instead of returning a sentinel class",
		_raises(fit.require_class, vme.EnvelopeRefusal))


def test_the_same_body_fits_at_a_different_declared_offset() -> None:
	"""N04: the refusal above is about the PLACEMENT, not about the measured extrema."""
	wide = synthetic_record(-400000, 400000, -400000, 400000, margin=8, offset=(418, 418))
	wide["variant"]["variant_key"] = "SYNTHETIC_WIDE_ALTERNATIVE_OFFSET"
	fit = fit_for(wide)
	check("N04 the identical body fits once the declared offset clears its own minimum",
		fit.outcome == vme.FIT_OK, fit.detail)
	check("N04b a non-baseline offset is flagged report-only, never adopted",
		not fit.offset_is_baseline)
	baseline = fit_for(synthetic_record(-400000, 400000, -400000, 400000, margin=8))
	check("N04c the baseline offset is recognised as the baseline", baseline.offset_is_baseline)


def test_a_class_beyond_the_published_domain_is_refused() -> None:
	"""N06-N07: the domain bound is 512, and it is enforced at exactly 512, not 511 or 513."""
	cell = GEOMETRY.cell_size_units
	top = GEOMETRY.clearance_class_max
	exact_um = ((cell * top) - 256) * vme.MICROMETRES_PER_METRE // 1024
	exact = fit_for(synthetic_record(-200000, exact_um, -200000, exact_um, margin=0))
	check("N06 a body whose translated maximum lands exactly on the domain top fits at %d" % top,
		exact.outcome == vme.FIT_OK and exact.clearance_class == top,
		"%s %s" % (exact.outcome, exact.clearance_class))
	over = copy.deepcopy(synthetic_record(-200000, exact_um, -200000, exact_um, margin=1))
	result = fit_for(over)
	check("N07 one unit of margin past it refuses as CLEARANCE_CLASS_EXCEEDS_DOMAIN",
		result.outcome == vme.REFUSE_CLASS_DOMAIN, result.outcome)
	check("N07b and that refusal is not confused with the placement refusal",
		result.outcome != vme.REFUSE_PLACEMENT)


def test_quantized_bounds_outside_int32_are_refused() -> None:
	"""N08: the position columns are int32, so an unbounded margin must refuse, not wrap."""
	huge = synthetic_record(-200000, 200000, -200000, 200000, margin=vme.INT32_MAX)
	fit = fit_for(huge)
	check("N08 an int32 overflow in the quantized bound refuses explicitly",
		fit.outcome == vme.REFUSE_INT32, fit.outcome)
	check("N08b the overflowing value is named in the refusal", "x_hi=" in fit.detail, fit.detail)


def test_inverted_and_malformed_records_are_refused() -> None:
	"""N09-N16: one malformed shape per case, each broken in exactly one way."""
	for name, mutate, fragment in _malformed_cases():
		record = synthetic_record(-200000, 200000, -200000, 200000)
		mutate(record)
		found = problems_for(record)
		check("N %s is refused" % name, bool(found), "accepted a malformed record")
		check("N %s names the reason" % name,
			any(fragment in problem for problem in found), "; ".join(found) or "(no problems)")


def _malformed_cases() -> List[Tuple[str, Any, str]]:
	"""Each entry breaks a well-formed record in one way and names the expected message fragment."""
	return [
		("inverted bounds", _set(["measurement", "bounds_micrometres", "x_max"], -300000),
			"is below"),
		("missing required property", _drop(["identity", "posture"]), "required property"),
		("unknown property", _set(["clearance_class"], 3), "is not allowed"),
		("wrong type", _set(["identity", "profile_revision"], "one"), "expected integer"),
		("boolean where an integer is required",
			_set(["margin_units", "x"], True), "expected integer"),
		("string below minLength", _set(["identity", "posture"], ""), "minLength"),
		("species key failing its pattern",
			_set(["identity", "species_key"], "Synthetic Alpha"), "does not match"),
		("a mode name outside movement.gd's enum",
			_set(["identity", "mode"], "GLIDE"), "is not in movement.gd's enum"),
		("a life stage outside residents.gd's enum",
			_set(["identity", "life_stage"], "JUVENILE"), "is not in residents.gd's enum"),
		("a hand-numbered mode id", _set(["identity", "mode_id"], 5), "never hand-numbered"),
		("a zero margin with no justification",
			_set(["margin_units", "y"], 0), "zero_margin_justification"),
		("a negative margin", _set(["margin_units", "y"], -1), "below the minimum"),
		("gear declared but excluded from the sweep",
			_set(["variant", "all_listed_items_included_in_sweep"], False), "must be True"),
		("interpolation not covered",
			_set(["measurement", "pose_interpolation_covered"], False), "must be True"),
		("a sweep missing one of the seven states",
			_set(["measurement", "states_covered"],
				["ENTRY", "TRAVEL", "HOLD", "TURN", "REVERSAL", "RETREAT"]), "minItems"),
		("a state outside the seven",
			_set(["measurement", "states_covered"],
				["ENTRY", "TRAVEL", "HOLD", "TURN", "REVERSAL", "RETREAT", "FLY"]), "is not one of"),
		("duplicated equipment", _set(["variant", "equipment"], ["rope", "rope"]), "must be unique"),
		("a synthetic fixture carrying provenance", _add_provenance, "may not carry provenance"),
		("a synthetic fixture with no note", _drop(["synthetic_note"]), "requires synthetic_note"),
		("a measurement with no provenance",
			_set(["data_class"], "measurement"), "requires provenance"),
	]


def _set(path: List[str], value: Any) -> Any:
	"""Return a mutator that assigns `value` at `path` inside a record."""
	def mutate(record: Dict[str, Any]) -> None:
		node = record
		for key in path[:-1]:
			node = node[key]
		node[path[-1]] = value
	return mutate


def _drop(path: List[str]) -> Any:
	"""Return a mutator that deletes the key at `path` inside a record."""
	def mutate(record: Dict[str, Any]) -> None:
		node = record
		for key in path[:-1]:
			node = node[key]
		node.pop(path[-1], None)
	return mutate


def _add_provenance(record: Dict[str, Any]) -> None:
	"""Give a synthetic fixture the provenance block only a real measurement may carry."""
	record["provenance"] = {
		"source_mesh": "none", "source_content_sha256": "0" * 64, "proportion_revision": 1,
		"measured_by": "nobody", "measured_on": "2026-09-14"}


def test_a_measurement_needs_complete_provenance() -> None:
	"""N17: data_class measurement is the only class that may claim a source, and must."""
	record = synthetic_record(-200000, 200000, -200000, 200000)
	record["data_class"] = "measurement"
	record.pop("synthetic_note")
	_add_provenance(record)
	check("N17 a complete measurement record validates", not problems_for(record),
		"; ".join(problems_for(record)))
	record["provenance"]["source_content_sha256"] = "0" * 63
	check("N17b a truncated source hash is refused",
		any("does not match" in problem for problem in problems_for(record)))
	record["provenance"]["source_content_sha256"] = "0" * 64
	record["provenance"].pop("measured_by")
	check("N17c a measurement missing its measurer is refused",
		any("measured_by" in problem for problem in problems_for(record)))


def test_a_stale_convention_block_is_refused() -> None:
	"""N18: a file may not prove fit against a cell size the map no longer uses."""
	instance = document([synthetic_record(-200000, 200000, -200000, 200000)])
	instance["convention"]["cell_size_units"] = GEOMETRY.cell_size_units // 2
	found = vme.file_semantic_problems(instance, GEOMETRY)
	check("N18 a convention disagreeing with spatial_world.gd is refused", bool(found))
	check("N18b the refusal names the source's value",
		any("stale domain" in problem for problem in found), "; ".join(found))
	instance["convention"]["cell_size_units"] = GEOMETRY.cell_size_units
	instance["schema_version"] = 3
	check("N18c an unimplemented schema version is refused",
		any("schema_version" in problem for problem in vme.file_semantic_problems(instance, GEOMETRY)))
	instance["schema_version"] = 2
	check("N18d the implemented version 2 is accepted",
		vme.file_semantic_problems(instance, GEOMETRY) == [],
		"; ".join(vme.file_semantic_problems(instance, GEOMETRY)))


def test_the_schema_subset_is_closed() -> None:
	"""N19: a schema keyword the validator does not enforce must refuse, never be ignored."""
	check("N19 the shipped schema uses only enforced keywords",
		vme.schema_support_problems(SCHEMA) == [],
		"; ".join(vme.schema_support_problems(SCHEMA)))
	grown = copy.deepcopy(SCHEMA)
	grown["properties"]["schema_version"]["multipleOf"] = 2
	check("N19b an unenforced keyword refuses the whole schema",
		any("multipleOf" in problem for problem in vme.schema_support_problems(grown)))
	loosened = copy.deepcopy(SCHEMA)
	loosened["$defs"]["record"]["additionalProperties"] = True
	check("N19c additionalProperties true refuses, because the validator only enforces false",
		any("additionalProperties" in problem for problem in vme.schema_support_problems(loosened)))


def test_missing_sources_refuse_rather_than_defaulting() -> None:
	"""N20: no constant is ever invented; an unreadable source is an explicit refusal."""
	with tempfile.TemporaryDirectory() as directory:
		check("N20 a root with no GDScript sources refuses",
			_raises(lambda: vme.load_source_geometry(pathlib.Path(directory)),
				vme.EnvelopeRefusal))
	check("N21 a negative numerator is refused by the nonnegative ceiling division",
		_raises(lambda: vme.ceil_div_nonnegative(-1, GEOMETRY.cell_size_units),
			vme.EnvelopeRefusal))


def test_a_square_leaving_the_map_is_refused() -> None:
	"""N22: class k at an anchor near the east or south edge does not fit on the grid."""
	last = GEOMETRY.cells_x - 1
	check("N22 class 1 at the last cell stays on the map",
		vme.anchor_square_within_map(last, last, 1, GEOMETRY))
	check("N22b class 2 at the last cell leaves the map",
		not vme.anchor_square_within_map(last, last, 2, GEOMETRY))
	check("N22c the full-domain square fits only from the north-west corner",
		vme.anchor_square_within_map(0, 0, GEOMETRY.clearance_class_max, GEOMETRY)
		and not vme.anchor_square_within_map(1, 0, GEOMETRY.clearance_class_max, GEOMETRY))
	check("N22d a negative anchor is refused",
		not vme.anchor_square_within_map(-1, 0, 1, GEOMETRY))


# =================================================================================================
# MOVE-C3-R01 6: RESIDUAL INTERPOLATION ERROR, ITS COVERAGE, AND THE EXPORT BOUNDARY
#
# The defect these tests exist for: schema 1 REQUIRED interpolation_error_bound_units and then
# never used it. A synthetic box with a declared 1u residual and zero margins passed schema and
# semantic validation and returned FIT_OK class 1. Applying that same 1u makes its translated
# minimum -1 and its maximum 513, which correctly refuses placement. So FIT_OK was not a complete
# measurement-bound check. EVERY NUMBER BELOW IS STILL SYNTHETIC.
# =================================================================================================


def test_a_declared_residual_error_must_be_covered_on_every_axis() -> None:
	"""T1: the reproduced defect. A residual recorded and never applied is the accounting gap."""
	probe = synthetic_record(-250000, 250000, -250000, 250000, margin=0, residual=1)
	probe["margin_units"]["zero_margin_justification"] = (
		"synthetic boundary probe; present deliberately to show prose cannot cover a residual")
	found = problems_for(probe)
	check("T1 the 1u-residual zero-margin record is refused instead of fitted", bool(found),
		"accepted the record the Cycle 3 probe reproduces")
	joined = " | ".join(found)
	check("T1b all three axes are named as uncovered",
		all("margin_units.%s" % axis in joined for axis in ("x", "y", "z")), joined)
	check("T1c the refusal says the justification does not move a bound",
		any("does not move a bound" in problem for problem in found), joined)
	fit = vme.compute_fit(probe, GEOMETRY)
	check("T1d compute_fit refuses it too, rather than returning FIT_OK class 1",
		fit.outcome == vme.REFUSE_UNCOVERED_ERROR and not fit.ok and fit.clearance_class is None,
		"%s %s" % (fit.outcome, fit.clearance_class))
	check("T1e require_class() still raises instead of returning a sentinel class",
		_raises(fit.require_class, vme.EnvelopeRefusal))


def test_covering_the_residual_exposes_the_placement_refusal_it_was_hiding() -> None:
	"""T1f-T1h: the declared 1u is exactly what puts this box behind its own north-west anchor."""
	covered = synthetic_record(-250000, 250000, -250000, 250000, margin=1, residual=1)
	covered["variant"]["variant_key"] = "SYNTHETIC_RESIDUAL_COVERED"
	fit = fit_for(covered)
	check("T1f once the residual is covered the box refuses as PLACEMENT_INCOMPATIBLE_AT_OFFSET",
		fit.outcome == vme.REFUSE_PLACEMENT, fit.outcome)
	check("T1g with the translated bounds the Cycle 3 probe computed by hand",
		fit.translated_bounds == {"x_lo": -1, "x_hi": 513, "z_lo": -1, "z_hi": 513},
		str(fit.translated_bounds))
	check("T1h and exhaustively no class in the published domain repairs it",
		fit.admitting_class_count == 0 and independently_least_class(-1, -1, 513, 513) is None)
	check("T1h2 that refusal is still distinct from the class-domain one",
		fit.outcome != vme.REFUSE_CLASS_DOMAIN and "no clearance class repairs this" in fit.detail)


def test_each_axis_margin_is_checked_independently() -> None:
	"""T1i-T1k: one short axis refuses on its own, and the rule is >=, not >."""
	for axis in ("x", "y", "z"):
		record = synthetic_record(-200000, 200000, -200000, 200000, margin=3, residual=3)
		record["margin_units"][axis] = 2
		found = problems_for(record)
		joined = " | ".join(found)
		check("T1i a %s margin one unit short of the residual is refused on its own" % axis,
			bool(found), "accepted an uncovered %s axis" % axis)
		check("T1j only the %s axis is named; the covering neighbours do not excuse it" % axis,
			sum("margin_units.%s" % other in joined for other in ("x", "y", "z")) == 1, joined)
	exact = synthetic_record(-200000, 200000, -200000, 200000, margin=3, residual=3)
	check("T1k a margin exactly equal to the residual covers it", not problems_for(exact),
		"; ".join(problems_for(exact)))


def test_an_absent_or_negative_residual_is_never_read_as_zero() -> None:
	"""T1l-T1o: an unstated error is a refusal. MOVE-C3-R01 6 supplies no default."""
	record = synthetic_record(-200000, 200000, -200000, 200000, margin=4)
	record["measurement"].pop("interpolation_error_bound_units")
	found = problems_for(record)
	check("T1l a record with no interpolation_error_bound_units is refused", bool(found))
	check("T1m the schema names the missing required field",
		any("interpolation_error_bound_units" in problem and "required property" in problem
			for problem in found), "; ".join(found))
	check("T1n the semantic check refuses it independently of the schema",
		vme.residual_error_problems(record, "$") != [])
	negative = synthetic_record(-200000, 200000, -200000, 200000, margin=4, residual=-1)
	check("T1o a negative residual is refused, never clamped to zero",
		bool(problems_for(negative)) and vme.residual_error_problems(negative, "$") != [])


def test_a_zero_residual_needs_written_evidence_and_is_not_counted_twice() -> None:
	"""T3: zero is legal only when the extrema already enclose the whole continuous sweep."""
	record = synthetic_record(-200000, 200000, -200000, 200000, margin=4)
	check("T3 a zero residual carrying its evidence is accepted", not problems_for(record),
		"; ".join(problems_for(record)))
	record["measurement"].pop("zero_residual_evidence")
	check("T3b a zero residual with no evidence is refused",
		any("zero_residual_evidence" in problem for problem in problems_for(record)),
		"; ".join(problems_for(record)))
	record["measurement"]["zero_residual_evidence"] = ""
	check("T3c an empty evidence string is refused too", bool(problems_for(record)))
	both_zero = synthetic_record(-200000, 200000, -200000, 200000, margin=0)
	check("T3d an evidenced zero residual with a justified zero margin is accepted -- the same "
		"error is not counted a second time", not problems_for(both_zero),
		"; ".join(problems_for(both_zero)))


def test_the_micrometre_export_direction_is_declared_and_never_inward() -> None:
	"""T2a-T2d: an inward export is not repaired by the later outward u-quantization."""
	for value in ("nearest", "truncate", "toward_zero", "minima_ceil_maxima_floor", ""):
		record = synthetic_record(-200000, 200000, -200000, 200000, margin=4)
		record["measurement"]["micrometre_export_rounding"] = value
		check("T2a export rounding %r is refused" % value, bool(problems_for(record)),
			"accepted an inward or unknown export direction")
	undeclared = synthetic_record(-200000, 200000, -200000, 200000, margin=4)
	undeclared["measurement"].pop("micrometre_export_rounding")
	check("T2b an undeclared export direction is refused", bool(problems_for(undeclared)))
	certified = synthetic_record(-200000, 200000, -200000, 200000, margin=4)
	certified["measurement"]["micrometre_export_rounding"] = "certified_residual_allowance"
	check("T2c a non-outward export declaring a zero residual is refused; that is the loophole",
		any("carries none" in problem for problem in problems_for(certified)),
		"; ".join(problems_for(certified)))
	allowed = synthetic_record(-200000, 200000, -200000, 200000, margin=4, residual=4)
	allowed["measurement"]["micrometre_export_rounding"] = "certified_residual_allowance"
	check("T2d a non-outward export carrying a covered positive residual is accepted",
		not problems_for(allowed), "; ".join(problems_for(allowed)))


def test_the_schema_and_the_semantic_layer_each_refuse_on_their_own() -> None:
	"""T5: two layers cover these rules, so each is exercised ALONE. A union test hides a hole."""
	inward = synthetic_record(-200000, 200000, -200000, 200000, margin=4)
	inward["measurement"]["micrometre_export_rounding"] = "nearest"
	check("T5 the semantic layer alone refuses an inward export direction",
		vme.export_rounding_problems(inward, "$") != [], "semantic layer accepted 'nearest'")
	check("T5b the schema layer alone refuses it as well",
		vme.validate_instance(document([inward]), SCHEMA) != [], "schema accepted 'nearest'")
	undeclared = synthetic_record(-200000, 200000, -200000, 200000, margin=4)
	undeclared["measurement"].pop("micrometre_export_rounding")
	check("T5c the schema layer alone requires micrometre_export_rounding",
		any("micrometre_export_rounding" in problem and "required property" in problem
			for problem in vme.validate_instance(document([undeclared]), SCHEMA)),
		"; ".join(vme.validate_instance(document([undeclared]), SCHEMA)))
	check("T5d the semantic layer alone also refuses the undeclared direction",
		vme.export_rounding_problems(undeclared, "$") != [])
	negative = synthetic_record(-200000, 200000, -200000, 200000, margin=4, residual=-1)
	check("T5e the schema layer alone refuses a negative residual as below its minimum",
		any("below the minimum" in problem
			for problem in vme.validate_instance(document([negative]), SCHEMA)),
		"; ".join(vme.validate_instance(document([negative]), SCHEMA)))
	check("T5f the semantic layer alone refuses it too",
		vme.residual_error_problems(negative, "$") != [])
	uncovered = synthetic_record(-200000, 200000, -200000, 200000, margin=0, residual=1)
	check("T5g the semantic layer alone refuses an uncovered residual, which no schema keyword "
		"can express", vme.residual_error_problems(uncovered, "$") != [])
	check("T5h and the schema alone does NOT catch it -- which is why the semantic rule exists",
		vme.validate_instance(document([uncovered]), SCHEMA) == [],
		"; ".join(vme.validate_instance(document([uncovered]), SCHEMA)))


def test_the_export_boundary_rounds_outward_in_exact_rationals() -> None:
	"""T2e-T2j: MOVE-C3-R01 6's +-250000.25um case, with no float anywhere in the computation."""
	high = vme.export_maximum_micrometres(1000001, 4)
	low = vme.export_minimum_micrometres(-1000001, 4)
	check("T2e a maximum of 250000.25um exports UP to 250001um", high == 250001, str(high))
	check("T2f a minimum of -250000.25um exports DOWN to -250001um", low == -250001, str(low))
	check("T2g the outward export then quantizes to the 257u and -257u the extremum needs",
		vme.quantize_axis_units(low, high, 0) == (-257, 257),
		str(vme.quantize_axis_units(low, high, 0)))
	check("T2h truncating at export would instead have answered 256u and -256u, and falsely fitted",
		vme.quantize_axis_units(-250000, 250000, 0) == (-256, 256),
		str(vme.quantize_axis_units(-250000, 250000, 0)))
	check("T2i a nonpositive denominator refuses instead of flipping the rounding direction",
		_raises(lambda: vme.export_maximum_micrometres(1, 0), vme.EnvelopeRefusal)
		and _raises(lambda: vme.export_minimum_micrometres(1, -4), vme.EnvelopeRefusal))
	for numerator, denominator in ((7, 2), (-7, 2), (1000001, 4), (-1000001, 4), (8, 4), (-8, 4)):
		exact = Fraction(numerator, denominator)
		check("T2j the export helpers match the exact-rational oracle at %d/%d"
			% (numerator, denominator),
			(vme.export_minimum_micrometres(numerator, denominator),
				vme.export_maximum_micrometres(numerator, denominator))
			== (math.floor(exact), math.ceil(exact)),
			"%s vs %s" % ((vme.export_minimum_micrometres(numerator, denominator),
				vme.export_maximum_micrometres(numerator, denominator)),
				(math.floor(exact), math.ceil(exact))))


def test_a_schema_1_record_meeting_schema_2_rules_is_still_refused() -> None:
	"""T4: a version bump is not a relabelling. An old record is refused, never quietly reread."""
	instance = document([synthetic_record(-200000, 200000, -200000, 200000, margin=4, residual=4)])
	check("T4 precondition: this content satisfies every schema 2 rule at version 2",
		vme.validate_instance(instance, SCHEMA) == []
		and vme.file_semantic_problems(instance, GEOMETRY) == [],
		"; ".join(vme.validate_instance(instance, SCHEMA)
			+ vme.file_semantic_problems(instance, GEOMETRY)))
	instance["schema_version"] = 1
	check("T4b the identical content at version 1 is refused structurally",
		bool(vme.validate_instance(instance, SCHEMA)))
	semantic = vme.file_semantic_problems(instance, GEOMETRY)
	check("T4c and is named as historical, explicitly not migrated",
		any("historical record" in problem and "No automatic migration" in problem
			for problem in semantic), "; ".join(semantic))
	check("T4d the version 2 rules are named as the reason it cannot be reinterpreted",
		any("RESIDUAL" in problem for problem in semantic), "; ".join(semantic))
	_check_version_1_file_is_refused(instance)
	check("T4f the implemented input-record version is 2, with 1 as its only predecessor",
		vme.SUPPORTED_SCHEMA_VERSION == 2 and vme.HISTORICAL_SCHEMA_VERSIONS == (1,),
		"%s %s" % (vme.SUPPORTED_SCHEMA_VERSION, vme.HISTORICAL_SCHEMA_VERSIONS))


def _check_version_1_file_is_refused(instance: Dict[str, Any]) -> None:
	"""T4e: end to end through validate_file, so no fit is derived from a version 1 document."""
	with tempfile.TemporaryDirectory() as directory:
		path = pathlib.Path(directory) / "historical_version_1.json"
		path.write_text(json.dumps(instance), encoding="utf-8")
		report = vme.validate_file(path, SCHEMA, GEOMETRY)
		check("T4e a version 1 file is refused whole, with no fit derived from it",
			report.refused() and report.fits == [], str(report.fits))


# =================================================================================================
# POSITIVE AND ARITHMETIC TESTS
# =================================================================================================


def test_quantization_rounds_outward_on_both_signs() -> None:
	"""P01-P02: floor the minimum, ceil the maximum. Inward rounding would shrink the body."""
	check("P01 a negative minimum floors away from zero",
		vme.quantize_axis_units(-1000, 0, 0)[0] == -2,
		str(vme.quantize_axis_units(-1000, 0, 0)))
	check("P01b a positive maximum ceils away from zero",
		vme.quantize_axis_units(0, 1000, 0)[1] == 2,
		str(vme.quantize_axis_units(0, 1000, 0)))
	check("P01c an exact unit boundary is not widened",
		vme.quantize_axis_units(vme.MICROMETRES_PER_METRE, vme.MICROMETRES_PER_METRE, 0)
		== (1024, 1024))
	check("P01d a wholly positive minimum still floors DOWN",
		vme.quantize_axis_units(1500, 2000, 0)[0] == 1, str(vme.quantize_axis_units(1500, 2000, 0)))
	check("P01e a wholly negative maximum still ceils UP",
		vme.quantize_axis_units(-2000, -1500, 0)[1] == -1,
		str(vme.quantize_axis_units(-2000, -1500, 0)))
	for low_um, high_um, margin in ((-987654, 123456, 0), (-1, 1, 3), (7, 999999, 11),
			(-500000, -400000, 2), (0, 0, 0), (999999999, 1000000000, 1)):
		check("P02 quantization matches the exact-rational oracle at (%d,%d,+%d)"
			% (low_um, high_um, margin),
			vme.quantize_axis_units(low_um, high_um, margin)
			== independently_quantized(low_um, high_um, margin),
			"%s vs %s" % (vme.quantize_axis_units(low_um, high_um, margin),
				independently_quantized(low_um, high_um, margin)))


def test_the_derived_class_matches_an_exhaustive_search() -> None:
	"""P03: the closed-form k is checked against brute force over the whole published domain."""
	agreed = 0
	for half_um in range(1000, 260000, 3571):
		for margin in (0, 3, 64):
			record = synthetic_record(-half_um, half_um, -half_um, half_um, margin=margin)
			fit = vme.compute_fit(record, GEOMETRY)
			translated = fit.translated_bounds
			expected = independently_least_class(translated["x_lo"], translated["z_lo"],
				translated["x_hi"], translated["z_hi"])
			actual = fit.clearance_class if fit.ok else None
			if expected != actual:
				check("P03 brute force and the formula agree at half=%d margin=%d"
					% (half_um, margin), False, "brute force %s, formula %s (%s)"
					% (expected, actual, fit.outcome))
				return
			agreed += 1
	check("P03 brute force and the closed-form class agree on all %d synthetic cases" % agreed,
		agreed > 100, "only %d cases ran" % agreed)


def test_tangency_fits_and_one_unit_more_does_not() -> None:
	"""P04-P06: the boundary is inclusive, k-1 is genuinely rejected, and the floor is class 1."""
	cell = GEOMETRY.cell_size_units
	exact_um = (cell - 256) * vme.MICROMETRES_PER_METRE // 1024
	exact = fit_for(synthetic_record(-200000, exact_um, -200000, exact_um, margin=0))
	check("P04 a maximum landing exactly on the class boundary fits",
		exact.outcome == vme.FIT_OK and exact.clearance_class == 1,
		"%s %s" % (exact.outcome, exact.clearance_class))
	check("P04b tangency means the translated maximum equals the square side exactly",
		exact.translated_bounds["x_hi"] == cell * 1, str(exact.translated_bounds))
	grown = fit_for(synthetic_record(-200000, exact_um, -200000, exact_um, margin=1))
	check("P05 one unit past the boundary needs the next class up",
		grown.outcome == vme.FIT_OK and grown.clearance_class == 2,
		"%s %s" % (grown.outcome, grown.clearance_class))
	check("P05b the class below the derived one genuinely fails containment",
		not independently_contained(grown.translated_bounds["x_lo"],
			grown.translated_bounds["z_lo"], grown.translated_bounds["x_hi"],
			grown.translated_bounds["z_hi"], grown.clearance_class - 1))
	tiny = fit_for(synthetic_record(-1, 1, -1, 1, margin=0))
	check("P06 the smallest synthetic body still derives class 1, never class 0",
		tiny.outcome == vme.FIT_OK and tiny.clearance_class == GEOMETRY.clearance_class_min,
		"%s %s" % (tiny.outcome, tiny.clearance_class))
	flush_um = -256 * vme.MICROMETRES_PER_METRE // 1024
	flush = fit_for(synthetic_record(flush_um, flush_um, flush_um, flush_um, margin=0))
	check("P06b a degenerate body sitting exactly on the anchor corner is class 1, not class 0",
		flush.outcome == vme.FIT_OK and flush.clearance_class == GEOMETRY.clearance_class_min,
		"%s %s translated %s" % (flush.outcome, flush.clearance_class, flush.translated_bounds))
	check("P06c and it really does translate onto the corner",
		flush.translated_bounds["x_lo"] == 0 and flush.translated_bounds["x_hi"] == 0,
		str(flush.translated_bounds))


def test_the_naive_width_bound_is_reported_as_insufficient() -> None:
	"""P07: ceil(max(width,depth)/cell) understates the answer, which is why it is not the test."""
	half_um = 200000 * 1
	record = synthetic_record(-half_um, half_um, -half_um, half_um, margin=0,
		offset=(GEOMETRY.cell_size_units, GEOMETRY.cell_size_units))
	fit = fit_for(record)
	width = fit.translated_bounds["x_hi"] - fit.translated_bounds["x_lo"]
	check("P07 the body is narrower than one cell", width <= GEOMETRY.cell_size_units, str(width))
	check("P07b yet containment at the declared offset needs a larger class than the naive bound",
		fit.ok and fit.clearance_class is not None
		and fit.naive_lower_bound_class is not None
		and fit.clearance_class > fit.naive_lower_bound_class,
		"class %s vs naive %s" % (fit.clearance_class, fit.naive_lower_bound_class))


def test_a_zero_margin_is_accepted_only_with_its_justification() -> None:
	"""P08: MOVE-C2-R01 3's explicit zero, which is legal but never silent."""
	record = synthetic_record(-200000, 200000, -200000, 200000, margin=0)
	record["margin_units"].pop("zero_margin_justification")
	check("P08 a zero margin alone is refused", bool(problems_for(record)))
	record["margin_units"]["zero_margin_justification"] = (
		"synthetic fixture; no measurement owner exists for this record")
	check("P08b a zero margin with its written justification is accepted",
		not problems_for(record), "; ".join(problems_for(record)))
	widened = synthetic_record(-200000, 200000, -200000, 200000, margin=7)
	zero = synthetic_record(-200000, 200000, -200000, 200000, margin=0)
	check("P08c a positive margin widens the bounds in both directions",
		fit_for(widened).local_bounds["x_lo"] == fit_for(zero).local_bounds["x_lo"] - 7
		and fit_for(widened).local_bounds["x_hi"] == fit_for(zero).local_bounds["x_hi"] + 7)


def test_the_parsed_geometry_is_the_published_geometry() -> None:
	"""P09: pin the constants the whole fit rests on, so a broken parser cannot pass quietly."""
	check("P09 spatial_world.gd's cell size parsed as 512", GEOMETRY.cell_size_units == 512,
		str(GEOMETRY.cell_size_units))
	check("P09b its root/centre offset parsed as 256", GEOMETRY.cell_centre_offset_units == 256,
		str(GEOMETRY.cell_centre_offset_units))
	check("P09c the clearance domain parsed as 1..512",
		(GEOMETRY.clearance_class_min, GEOMETRY.clearance_class_max) == (1, 512),
		str((GEOMETRY.clearance_class_min, GEOMETRY.clearance_class_max)))
	check("P09d all six movement modes parsed with their compiled ids",
		GEOMETRY.modes == {"GROUND_WALK": 0, "FORD_WALK": 1, "SWIM_SURFACE": 2, "DIVE": 3,
			"CLIMB": 4, "TUNNEL_WALK": 5}, str(GEOMETRY.modes))
	check("P09e all three life stages parsed with their compiled ids",
		GEOMETRY.life_stages == {"ADULT": 0, "CHILD": 1, "ELDER": 2}, str(GEOMETRY.life_stages))


# =================================================================================================
# COMMAND LINE
# =================================================================================================


def test_the_command_line_exit_statuses() -> None:
	"""C01: the three statuses a caller can act on, exercised end to end through the real CLI."""
	with tempfile.TemporaryDirectory() as directory:
		root = pathlib.Path(directory)
		emitted = subprocess.run(
			[sys.executable, str(TOOL), "--emit-synthetic-fixtures", str(root)],
			capture_output=True, text=True)
		check("C01 emitting the synthetic fixture set succeeds", emitted.returncode == 0,
			emitted.stdout + emitted.stderr)
		_check_cli(root / "synthetic_fits_class_1.json", 0, "PASS")
		_check_cli(root / "synthetic_placement_incompatible.json", 2, "DOES_NOT_FIT")
		for name in sorted(path.name for path in root.glob("malformed_*.json")):
			_check_cli(root / name, 1, "REFUSE")
		check("C01b there were eight malformed fixtures to refuse, four of them MOVE-C3-R01's",
			len(list(root.glob("malformed_*.json"))) == 8,
			str(sorted(path.name for path in root.glob("malformed_*.json"))))
		for name in ("malformed_uncovered_interpolation_error.json",
				"malformed_zero_residual_without_evidence.json",
				"malformed_inward_micrometre_export.json", "malformed_schema_version_1.json"):
			check("C01c %s is emitted" % name, (root / name).is_file())
	empty = subprocess.run([sys.executable, str(TOOL)], capture_output=True, text=True)
	check("C02 naming no record file refuses rather than passing on an empty run",
		empty.returncode == 1 and "not a pass" in empty.stdout, empty.stdout)


def _check_cli(path: pathlib.Path, expected_status: int, expected_word: str) -> None:
	"""Run the real command line on one fixture and pin its status and summary word."""
	result = subprocess.run([sys.executable, str(TOOL), str(path)], capture_output=True, text=True)
	check("C01 %s exits %d with %s" % (path.name, expected_status, expected_word),
		result.returncode == expected_status and expected_word in result.stdout,
		"exit %d: %s" % (result.returncode, result.stdout.strip().splitlines()[-1:]))


def _raises(call: Any, exception: Any) -> bool:
	"""True when `call` raises `exception`. A refusal must be raised, never returned as a number."""
	try:
		call()
	except exception:
		return True
	except Exception:  # noqa: BLE001 -- a different exception is still a failed expectation
		return False
	return False


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
	print("test_movement_envelopes: %s -- %d check(s), %d failure(s)"
		% ("FAIL" if FAILURES else "PASS", len(CASES), len(FAILURES)))
	return 1 if FAILURES else 0


if __name__ == "__main__":
	sys.exit(main())
