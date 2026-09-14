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
		offset: Tuple[int, int] = (256, 256)) -> Dict[str, Any]:
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
			"interpolation_error_bound_units": 0,
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
		"schema_version": 1,
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
	instance["schema_version"] = 2
	check("N18c an unimplemented schema version is refused",
		any("schema_version" in problem for problem in vme.file_semantic_problems(instance, GEOMETRY)))


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
		check("C01b there were four malformed fixtures to refuse",
			len(list(root.glob("malformed_*.json"))) == 4)
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
