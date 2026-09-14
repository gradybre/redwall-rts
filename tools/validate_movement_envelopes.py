#!/usr/bin/env python3
"""Validate MEASURED movement-envelope records and derive their anchored clearance fit.

MOVE-C2-R01 adopted a measurement/placement convention and explicitly did NOT
adopt any body dimension. This tool is the convention, executable. It contains
no width, height, gear extent or load bound, and it cannot produce one: every
number it reports comes from a record file a measurement owner wrote, or from
the geometry constants it parses out of the GDScript that owns them.

WHAT IT DOES

  1. Structural validation against docs/planning/movement_envelope_schema.json.
     The schema is the only statement of the record shape; this file interprets
     a small, closed subset of JSON Schema and REFUSES a schema that grows a
     keyword the subset does not enforce -- otherwise a later constraint could
     be added to the schema and quietly never checked.

  2. Semantic validation the schema cannot express: stage/mode names and ids
     must match residents.gd and movement.gd; the declared cell geometry must
     match spatial_world.gd; a zero margin needs a written justification; a
     synthetic fixture may not carry provenance and a measurement must.

  3. Residual interpolation error coverage (MOVE-C3-R01 6, schema 2):
     `interpolation_error_bound_units` is the conservative interpolation error the
     submitted extrema do NOT enclose, and it bounds every axis. Each axis margin
     must be at least that residual, or the record is refused -- recorded and then
     never applied is the accounting gap this version closes. A zero residual needs
     written evidence that the extrema already enclose the whole sweep, so the same
     error is never counted twice. The record also declares how its micrometres were
     rounded at export; only outward, or a certified positive residual, is accepted.
     Schema 1 records are refused by name as historical, never silently reread.

  4. The anchored fit, in exact integer arithmetic (MOVE-C2-R01 3-5):

       lo_u = floor(1024 * measured_min) - margin_u      (outward)
       hi_u = ceil (1024 * measured_max) + margin_u      (outward)
       translate by the declared anchor-to-root offset o
       require ox+xlo >= 0, oz+zlo >= 0, ox+xhi <= 512k, oz+zhi <= 512k
       k = max(1, ceil_div(ox+xhi, 512), ceil_div(oz+zhi, 512)), reject k > 512

THE RESULT THIS TOOL EXISTS TO REPORT

A ground anchor is the NORTH-WEST corner of the k-square, and the baseline root
offset is +256/+256. So a swept body wide enough to reach behind its own root
translates to a NEGATIVE minimum, and `ox+xlo >= 0` fails. That condition does
not mention k. Increasing the clearance class grows the square to the south and
east only; it never moves the north-west edge. Such a record is therefore
reported as PLACEMENT_INCOMPATIBLE_AT_OFFSET -- never as "needs a larger class",
which is false and sends a reader hunting for a k that does not exist. The tool
proves it rather than asserting it: it scans the entire 1..512 class domain and
reports how many classes admit the body, which for this case is zero.

Re-centring the square, clamping the bounds or relocating the resident is NOT a
remedy this tool offers. MOVE-C2-R01 5 requires a separately reviewed MOVE-G02
position/anchor/save contract for any other placement. A non-baseline offset in
a record is accepted for MEASUREMENT AND REPORT ONLY and labelled as such.

WHAT A PASS IS NOT. A FIT_OK record is not an authored profile, not an enabled
mode, and not permission for a species to travel. Q2's per-species policy/cost
rows are OPEN. A missing record refuses as a missing contract; it is never
evidence that an animal cannot do something.

    python3 tools/validate_movement_envelopes.py RECORDS.json [...]
    python3 tools/validate_movement_envelopes.py --emit-synthetic-fixtures DIR

Exit status: 0 every record valid and fitting; 1 a file, schema or record was
refused; 2 every record was valid but at least one does not fit as placed.
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
from dataclasses import dataclass
from typing import Any, Dict, List, Optional, Tuple

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCHEMA_PATH = ROOT / "docs/planning/movement_envelope_schema.json"
SPATIAL_SOURCE = ROOT / "godot/scripts/core/spatial_world.gd"
MOVEMENT_SOURCE = ROOT / "godot/scripts/core/movement.gd"
RESIDENT_SOURCE = ROOT / "godot/scripts/core/residents.gd"

SUPPORTED_SCHEMA_VERSION = 2
HISTORICAL_SCHEMA_VERSIONS = (1,)
MICROMETRES_PER_METRE = 1000000
INT32_MIN = -2147483648
INT32_MAX = 2147483647

EXPORT_ROUNDING_OUTWARD = "minima_floor_maxima_ceil"
EXPORT_ROUNDING_CERTIFIED = "certified_residual_allowance"

FIT_OK = "FIT_OK"
REFUSE_PLACEMENT = "PLACEMENT_INCOMPATIBLE_AT_OFFSET"
REFUSE_CLASS_DOMAIN = "CLEARANCE_CLASS_EXCEEDS_DOMAIN"
REFUSE_INT32 = "QUANTIZED_BOUND_OUT_OF_INT32"
REFUSE_INVERTED = "MEASURED_BOUNDS_INVERTED"
REFUSE_INCONSISTENT = "FIT_INTERNAL_INCONSISTENCY"
REFUSE_UNCOVERED_ERROR = "UNCOVERED_INTERPOLATION_ERROR"

EXIT_OK = 0
EXIT_REFUSED = 1
EXIT_DOES_NOT_FIT = 2

SCHEMA_ANNOTATIONS = frozenset({"$schema", "$id", "title", "description"})
SCHEMA_CONSTRAINTS = frozenset({
	"type", "required", "properties", "additionalProperties", "enum", "const",
	"minimum", "maximum", "minLength", "pattern", "items", "minItems",
	"uniqueItems", "$ref", "$defs",
})


class EnvelopeRefusal(Exception):
	"""An explicit refusal. This tool never returns a sentinel number for failure."""


# --- geometry parsed from the GDScript that owns it ----------------------------------------------

GDSCRIPT_INT_CONST = re.compile(r"^const\s+([A-Z][A-Z0-9_]*)\s*:\s*int\s*=\s*([^#\n]+)", re.M)


def _resolve_int_expression(expression: str, known: Dict[str, int]) -> Optional[int]:
	"""Resolve a literal, a known identifier, or a product/quotient of those. Else None."""
	text = expression.strip()
	if not text:
		return None
	terms = re.split(r"\s*([*/])\s*", text)
	if len(terms) % 2 == 0:
		return None
	value: Optional[int] = _resolve_int_term(terms[0], known)
	index = 1
	while value is not None and index + 1 < len(terms):
		right = _resolve_int_term(terms[index + 1], known)
		if right is None or (terms[index] == "/" and right == 0):
			return None
		value = value * right if terms[index] == "*" else value // right
		index += 2
	return value


def _resolve_int_term(term: str, known: Dict[str, int]) -> Optional[int]:
	"""One operand: a decimal literal or an already-resolved constant name."""
	text = term.strip()
	if re.fullmatch(r"-?\d+", text):
		return int(text)
	return known.get(text)


def read_int_constants(path: pathlib.Path) -> Dict[str, int]:
	"""Every `const NAME: int = ...` in one GDScript file whose value resolves to an integer."""
	if not path.is_file():
		raise EnvelopeRefusal("SOURCE_FILE_MISSING: %s" % path)
	known: Dict[str, int] = {}
	for name, expression in GDSCRIPT_INT_CONST.findall(path.read_text(encoding="utf-8")):
		value = _resolve_int_expression(expression, known)
		if value is not None:
			known[name] = value
	return known


@dataclass(frozen=True)
class SourceGeometry:
	"""The map geometry and enums this tool proves against, read from their owning sources."""

	cell_size_units: int
	cell_centre_offset_units: int
	clearance_class_min: int
	clearance_class_max: int
	cells_x: int
	cells_z: int
	modes: Dict[str, int]
	life_stages: Dict[str, int]

	def convention_fields(self) -> Dict[str, int]:
		"""The `convention` values a record file must declare identically."""
		return {
			"cell_size_units": self.cell_size_units,
			"cell_centre_offset_units": self.cell_centre_offset_units,
			"clearance_class_min": self.clearance_class_min,
			"clearance_class_max": self.clearance_class_max,
			"cells_x": self.cells_x,
			"cells_z": self.cells_z,
		}


def _named_enum(constants: Dict[str, int], prefix: str) -> Dict[str, int]:
	"""The `PREFIX_MEMBER` constants of one GDScript enum block, without its COUNT bound."""
	members: Dict[str, int] = {}
	for name, value in constants.items():
		if name.startswith(prefix) and name != prefix + "COUNT":
			members[name[len(prefix):]] = value
	return members


def load_source_geometry(root: pathlib.Path = ROOT) -> SourceGeometry:
	"""Parse spatial_world.gd, movement.gd and residents.gd. Refuses if a constant is absent."""
	spatial = read_int_constants(root / "godot/scripts/core/spatial_world.gd")
	modes = _named_enum(read_int_constants(root / "godot/scripts/core/movement.gd"), "MODE_")
	stages = _named_enum(read_int_constants(root / "godot/scripts/core/residents.gd"), "LIFE_STAGE_")
	required = (
		"CELL_SIZE_UNITS", "CELL_CENTRE_OFFSET_UNITS",
		"MIN_CLEARANCE_CLASS", "MAX_CLEARANCE_CLASS", "CELLS_X", "CELLS_Z",
	)
	missing = [name for name in required if name not in spatial]
	if missing or not modes or not stages:
		raise EnvelopeRefusal(
			"SOURCE_CONSTANTS_UNREADABLE: missing %s; %d mode(s), %d life stage(s). "
			"No default is substituted." % (missing or "none", len(modes), len(stages)))
	return SourceGeometry(
		cell_size_units=spatial["CELL_SIZE_UNITS"],
		cell_centre_offset_units=spatial["CELL_CENTRE_OFFSET_UNITS"],
		clearance_class_min=spatial["MIN_CLEARANCE_CLASS"],
		clearance_class_max=spatial["MAX_CLEARANCE_CLASS"],
		cells_x=spatial["CELLS_X"],
		cells_z=spatial["CELLS_Z"],
		modes=modes,
		life_stages=stages)


# --- the closed JSON Schema subset ---------------------------------------------------------------


def schema_support_problems(schema: Dict[str, Any]) -> List[str]:
	"""Refuse a schema using a keyword this validator does not enforce, rather than ignoring it."""
	problems: List[str] = []
	_schema_support_node(schema, "#", problems)
	return problems


def _schema_support_node(node: Any, where: str, problems: List[str]) -> None:
	"""Walk only the structural positions of a schema; property NAMES are data, not keywords."""
	if not isinstance(node, dict):
		problems.append("%s: schema node is not an object" % where)
		return
	for key in node:
		if key not in SCHEMA_ANNOTATIONS and key not in SCHEMA_CONSTRAINTS:
			problems.append("%s: schema keyword %r is not enforced by this validator" % (where, key))
	if "additionalProperties" in node and node["additionalProperties"] is not False:
		problems.append("%s: additionalProperties must be false when present" % where)
	for name, child in (node.get("properties") or {}).items():
		_schema_support_node(child, "%s/properties/%s" % (where, name), problems)
	for name, child in (node.get("$defs") or {}).items():
		_schema_support_node(child, "%s/$defs/%s" % (where, name), problems)
	if "items" in node:
		_schema_support_node(node["items"], "%s/items" % where, problems)


def validate_instance(instance: Any, schema: Dict[str, Any]) -> List[str]:
	"""Every structural violation of `schema`, as one message per problem."""
	problems: List[str] = []
	_check(instance, schema, "$", schema.get("$defs") or {}, problems)
	return problems


def _check(value: Any, schema: Dict[str, Any], where: str, defs: Dict[str, Any],
		problems: List[str]) -> None:
	"""Dispatch one node against one subschema, resolving a local `$ref` first."""
	if "$ref" in schema:
		name = str(schema["$ref"]).rsplit("/", 1)[-1]
		if name not in defs:
			problems.append("%s: unresolved $ref %r" % (where, schema["$ref"]))
			return
		schema = defs[name]
	if not _check_type(value, schema, where, problems):
		return
	_check_scalar(value, schema, where, problems)
	if isinstance(value, dict):
		_check_object(value, schema, where, defs, problems)
	elif isinstance(value, list):
		_check_array(value, schema, where, defs, problems)


def _check_type(value: Any, schema: Dict[str, Any], where: str, problems: List[str]) -> bool:
	"""True when `value` has the declared JSON type. Booleans are never integers here."""
	expected = schema.get("type")
	if expected is None:
		return True
	matched = {
		"object": isinstance(value, dict),
		"array": isinstance(value, list),
		"string": isinstance(value, str),
		"boolean": isinstance(value, bool),
		"integer": isinstance(value, int) and not isinstance(value, bool),
	}.get(expected)
	if matched is None:
		problems.append("%s: schema declares unsupported type %r" % (where, expected))
		return False
	if not matched:
		problems.append("%s: expected %s, got %s" % (where, expected, type(value).__name__))
	return matched


def _check_scalar(value: Any, schema: Dict[str, Any], where: str, problems: List[str]) -> None:
	"""const, enum, numeric range, string length and pattern."""
	if "const" in schema and value != schema["const"]:
		problems.append("%s: must be %r, got %r" % (where, schema["const"], value))
	if "enum" in schema and value not in schema["enum"]:
		problems.append("%s: %r is not one of %r" % (where, value, schema["enum"]))
	if isinstance(value, int) and not isinstance(value, bool):
		if "minimum" in schema and value < schema["minimum"]:
			problems.append("%s: %d is below the minimum %d" % (where, value, schema["minimum"]))
		if "maximum" in schema and value > schema["maximum"]:
			problems.append("%s: %d is above the maximum %d" % (where, value, schema["maximum"]))
	if isinstance(value, str):
		if len(value) < int(schema.get("minLength", 0)):
			problems.append("%s: shorter than minLength %d" % (where, schema["minLength"]))
		if "pattern" in schema and re.search(schema["pattern"], value) is None:
			problems.append("%s: %r does not match %s" % (where, value, schema["pattern"]))


def _check_object(value: Dict[str, Any], schema: Dict[str, Any], where: str,
		defs: Dict[str, Any], problems: List[str]) -> None:
	"""required, additionalProperties and each declared property."""
	properties = schema.get("properties") or {}
	for name in schema.get("required") or []:
		if name not in value:
			problems.append("%s: required property %r is missing" % (where, name))
	if schema.get("additionalProperties") is False:
		for name in value:
			if name not in properties:
				problems.append("%s: property %r is not allowed" % (where, name))
	for name, child in value.items():
		if name in properties:
			_check(child, properties[name], "%s.%s" % (where, name), defs, problems)


def _check_array(value: List[Any], schema: Dict[str, Any], where: str,
		defs: Dict[str, Any], problems: List[str]) -> None:
	"""minItems, uniqueItems and each element."""
	if len(value) < int(schema.get("minItems", 0)):
		problems.append("%s: %d item(s), fewer than minItems %d"
			% (where, len(value), schema["minItems"]))
	if schema.get("uniqueItems") is True:
		seen = [json.dumps(item, sort_keys=True) for item in value]
		if len(set(seen)) != len(seen):
			problems.append("%s: items must be unique" % where)
	if "items" in schema:
		for index, item in enumerate(value):
			_check(item, schema["items"], "%s[%d]" % (where, index), defs, problems)


# --- semantics the schema cannot express ---------------------------------------------------------


def schema_version_problems(document: Dict[str, Any]) -> List[str]:
	"""MOVE-C3-R01 6: refuse any version but 2, and name version 1 as historical, never migrated."""
	version = document.get("schema_version")
	if version == SUPPORTED_SCHEMA_VERSION:
		return []
	if version in HISTORICAL_SCHEMA_VERSIONS:
		return ["$.schema_version: %r is a historical record. Version %d re-means "
			"measurement.interpolation_error_bound_units as the RESIDUAL error the extrema do not "
			"enclose and requires every axis margin to cover it, so a version %r record cannot be "
			"reinterpreted under those rules and cannot qualify. It may be READ as history; its "
			"owner must reassert error coverage and source evidence as version %d. No automatic "
			"migration is performed here."
			% (version, SUPPORTED_SCHEMA_VERSION, version, SUPPORTED_SCHEMA_VERSION)]
	return ["$.schema_version: %r is not implemented by this validator (%d)"
		% (version, SUPPORTED_SCHEMA_VERSION)]


def file_semantic_problems(document: Dict[str, Any], geometry: SourceGeometry) -> List[str]:
	"""Version support and agreement between the declared convention and the owning sources."""
	problems: List[str] = schema_version_problems(document)
	declared = document.get("convention") or {}
	for name, expected in geometry.convention_fields().items():
		if declared.get(name) != expected:
			problems.append(
				"$.convention.%s: declared %r but the owning GDScript source says %d -- refusing "
				"rather than proving fit against a stale domain" % (name, declared.get(name), expected))
	return problems


def record_semantic_problems(record: Dict[str, Any], where: str,
		geometry: SourceGeometry) -> List[str]:
	"""Cross-field rules: the data-class discriminator, enum agreement, margins and bounds."""
	problems: List[str] = []
	problems.extend(_data_class_problems(record, where))
	problems.extend(_identity_problems(record, where, geometry))
	problems.extend(_margin_problems(record, where))
	problems.extend(residual_error_problems(record, where))
	problems.extend(export_rounding_problems(record, where))
	problems.extend(_bounds_problems(record, where))
	return problems


def _data_class_problems(record: Dict[str, Any], where: str) -> List[str]:
	"""A measurement must carry provenance; a synthetic fixture must not, and must say so."""
	problems: List[str] = []
	data_class = record.get("data_class")
	if data_class == "measurement":
		if "provenance" not in record:
			problems.append("%s: data_class 'measurement' requires provenance "
				"(source mesh, content hash, proportion revision, measurer, date)" % where)
		if "synthetic_note" in record:
			problems.append("%s: a measurement may not carry synthetic_note" % where)
	elif data_class == "synthetic_fixture":
		if "provenance" in record:
			problems.append("%s: a synthetic_fixture may not carry provenance -- invented numbers "
				"must never be readable as a measured body dimension" % where)
		if not record.get("synthetic_note"):
			problems.append("%s: data_class 'synthetic_fixture' requires synthetic_note" % where)
	return problems


def _identity_problems(record: Dict[str, Any], where: str, geometry: SourceGeometry) -> List[str]:
	"""Stage and mode names must exist in their compiled enum, with the enum's own id."""
	problems: List[str] = []
	identity = record.get("identity") or {}
	for field, table, source in (
			("life_stage", geometry.life_stages, "residents.gd"),
			("mode", geometry.modes, "movement.gd")):
		name = identity.get(field)
		if name not in table:
			problems.append("%s.identity.%s: %r is not in %s's enum (%s)"
				% (where, field, name, source, ", ".join(sorted(table))))
			continue
		declared_id = identity.get(field + "_id")
		if declared_id != table[name]:
			problems.append("%s.identity.%s_id: declared %r but %s compiles %s as %d -- ids are "
				"read from the source, never hand-numbered"
				% (where, field, declared_id, source, name, table[name]))
	return problems


def _margin_problems(record: Dict[str, Any], where: str) -> List[str]:
	"""MOVE-C2-R01 3: an explicit zero margin is acceptable only with a written justification."""
	margin = record.get("margin_units") or {}
	zeroed = [axis for axis in ("x", "y", "z") if margin.get(axis) == 0]
	if zeroed and not margin.get("zero_margin_justification"):
		return ["%s.margin_units: axis %s declared zero with no zero_margin_justification -- a zero "
			"allowance needs the measurement owner's statement that none is required"
			% (where, "/".join(zeroed))]
	return []


def residual_error_problems(record: Dict[str, Any], where: str) -> List[str]:
	"""MOVE-C3-R01 6: every axis margin must cover the declared residual interpolation error.

	The error field is the conservative interpolation error the submitted extrema do NOT already
	enclose. Recording it and never applying it is the accounting gap schema 2 exists to close.
	"""
	measurement = record.get("measurement") or {}
	residual = measurement.get("interpolation_error_bound_units")
	if not isinstance(residual, int) or isinstance(residual, bool) or residual < 0:
		return ["%s.measurement.interpolation_error_bound_units: %r is not a declared nonnegative "
			"residual interpolation error -- an unstated error is never read as zero"
			% (where, residual)]
	if residual == 0:
		return _zero_residual_problems(measurement, where)
	margin = record.get("margin_units") or {}
	problems: List[str] = []
	for axis in ("x", "y", "z"):
		allowance = margin.get(axis)
		if not isinstance(allowance, int) or isinstance(allowance, bool) or allowance < residual:
			problems.append(_uncovered_axis_message(where, axis, allowance, residual))
	return problems


def _uncovered_axis_message(where: str, axis: str, allowance: Any, residual: int) -> str:
	"""The refusal text for one axis whose authored allowance does not cover the residual error."""
	return ("%s.margin_units.%s: allowance %r does not cover the declared residual interpolation "
		"error of %d unit(s). MOVE-C3-R01 6 requires each axis margin to be at least the residual "
		"the submitted extrema do not enclose. A zero_margin_justification cannot cover a positive "
		"uncovered residual: prose does not move a bound." % (where, axis, allowance, residual))


def _zero_residual_problems(measurement: Dict[str, Any], where: str) -> List[str]:
	"""A zero residual is legal only with written evidence that the extrema enclose the whole sweep."""
	if measurement.get("zero_residual_evidence"):
		return []
	return ["%s.measurement: interpolation_error_bound_units 0 requires zero_residual_evidence -- "
		"MOVE-C3-R01 6 permits a zero residual only when the owner establishes that the submitted "
		"extrema already enclose the full continuous sweep, so that the same error is not then "
		"counted a second time as a margin" % where]


def export_rounding_problems(record: Dict[str, Any], where: str) -> List[str]:
	"""MOVE-C3-R01 6: an export that did not round outward must carry a positive residual instead."""
	measurement = record.get("measurement") or {}
	rounding = measurement.get("micrometre_export_rounding")
	if rounding not in (EXPORT_ROUNDING_OUTWARD, EXPORT_ROUNDING_CERTIFIED):
		return ["%s.measurement.micrometre_export_rounding: %r is not a declared export direction "
			"(%s or %s). Nearest and truncation are refused: this tool consumes integers and cannot "
			"reconstruct precision discarded before its input, and outward u-quantization does not "
			"repair an inward export." % (where, rounding, EXPORT_ROUNDING_OUTWARD,
				EXPORT_ROUNDING_CERTIFIED)]
	if rounding != EXPORT_ROUNDING_CERTIFIED:
		return []
	residual = measurement.get("interpolation_error_bound_units")
	if isinstance(residual, int) and not isinstance(residual, bool) and residual > 0:
		return []
	return ["%s.measurement: micrometre_export_rounding %r declares that the export did not round "
		"outward, so it must carry a strictly positive interpolation_error_bound_units for the "
		"precision discarded there; %r carries none" % (where, rounding, residual)]


def _bounds_problems(record: Dict[str, Any], where: str) -> List[str]:
	"""A maximum below its minimum is not a sweep; it is a transcription error."""
	bounds = ((record.get("measurement") or {}).get("bounds_micrometres") or {})
	problems: List[str] = []
	for axis in ("x", "y", "z"):
		low, high = bounds.get(axis + "_min"), bounds.get(axis + "_max")
		if isinstance(low, int) and isinstance(high, int) and high < low:
			problems.append("%s.measurement.bounds_micrometres: %s_max %d is below %s_min %d"
				% (where, axis, high, axis, low))
	return problems


# --- the fit arithmetic --------------------------------------------------------------------------


def floor_div(numerator: int, denominator: int) -> int:
	"""Exact floored division for either sign. Python's // already floors; named for the callers."""
	return numerator // denominator


def ceil_div_signed(numerator: int, denominator: int) -> int:
	"""Exact ceiling division for either sign, without touching float."""
	return -((-numerator) // denominator)


def ceil_div_nonnegative(numerator: int, denominator: int) -> int:
	"""MOVE-C2-R01 4's `(n + 511) // 512`, defined for a NONNEGATIVE numerator only."""
	if numerator < 0:
		raise EnvelopeRefusal("CEIL_DIV_NEGATIVE_NUMERATOR: %d -- the placement test runs first"
			% numerator)
	return (numerator + denominator - 1) // denominator


def _checked_denominator(denominator: int) -> int:
	"""A measured rational's denominator must be positive; a nonpositive one refuses, never flips."""
	if denominator <= 0:
		raise EnvelopeRefusal("EXPORT_DENOMINATOR_NOT_POSITIVE: %r -- a measured coordinate reaches "
			"this boundary as an exact rational count of micrometres; no float is accepted and no "
			"denominator is assumed" % (denominator,))
	return denominator


def export_minimum_micrometres(numerator: int, denominator: int) -> int:
	"""MOVE-C3-R01 6: floor an exact measured MINIMUM into micrometres, away from the body.

	The export boundary is earlier than quantize_axis_units and is not repaired by it. Nearest or
	toward-zero rounding here shrinks the committed body: -250000.25um truncates to -250000um, which
	quantizes to -256u instead of the -257u the real extremum needs.
	"""
	return floor_div(numerator, _checked_denominator(denominator))


def export_maximum_micrometres(numerator: int, denominator: int) -> int:
	"""MOVE-C3-R01 6: ceil an exact measured MAXIMUM into micrometres, away from the body.

	+250000.25um truncates to +250000um, which quantizes to 256u and can falsely fit on the class
	boundary; rounding outward here keeps the 257u the extremum actually requires.
	"""
	return ceil_div_signed(numerator, _checked_denominator(denominator))


def quantize_axis_units(min_micrometres: int, max_micrometres: int, margin_units: int,
		units_per_metre: int = 1024) -> Tuple[int, int]:
	"""MOVE-C2-R01 3's outward quantization: floor the minimum, ceil the maximum, then widen."""
	low = floor_div(min_micrometres * units_per_metre, MICROMETRES_PER_METRE) - margin_units
	high = ceil_div_signed(max_micrometres * units_per_metre, MICROMETRES_PER_METRE) + margin_units
	return low, high


def containment_holds(low_x: int, low_z: int, high_x: int, high_z: int,
		clearance_class: int, cell_size_units: int) -> bool:
	"""MOVE-C2-R01 4's four conditions on ALREADY-TRANSLATED bounds. Tangency passes."""
	side = cell_size_units * clearance_class
	return low_x >= 0 and low_z >= 0 and high_x <= side and high_z <= side


def classes_admitting(low_x: int, low_z: int, high_x: int, high_z: int,
		geometry: SourceGeometry) -> List[int]:
	"""Every class in the published domain that actually contains these translated bounds.

	Exhaustive, not derived. This is what turns "no larger class repairs that placement" from a
	claim into a result: for a negative translated minimum the returned list is empty across the
	whole 1..512 domain, because the failing condition never mentions k.
	"""
	return [k for k in range(geometry.clearance_class_min, geometry.clearance_class_max + 1)
		if containment_holds(low_x, low_z, high_x, high_z, k, geometry.cell_size_units)]


@dataclass(frozen=True)
class FitResult:
	"""One record's anchored fit outcome. `clearance_class` exists only when `ok` is true."""

	outcome: str
	ok: bool
	detail: str
	local_bounds: Dict[str, int]
	translated_bounds: Dict[str, int]
	offset: Tuple[int, int]
	offset_is_baseline: bool
	admitting_class_count: int
	clearance_class: Optional[int] = None
	naive_lower_bound_class: Optional[int] = None

	def require_class(self) -> int:
		"""The derived class, or an explicit refusal. This never returns a sentinel number."""
		if not self.ok or self.clearance_class is None:
			raise EnvelopeRefusal("%s: %s" % (self.outcome, self.detail))
		return self.clearance_class


def _quantized_local_bounds(record: Dict[str, Any]) -> Dict[str, int]:
	"""The three axes quantized outward into simulation units, before any translation."""
	bounds = record["measurement"]["bounds_micrometres"]
	margin = record["margin_units"]
	out: Dict[str, int] = {}
	for axis in ("x", "y", "z"):
		low, high = quantize_axis_units(
			bounds[axis + "_min"], bounds[axis + "_max"], margin[axis])
		out[axis + "_lo"], out[axis + "_hi"] = low, high
	return out


def _int32_offenders(values: Dict[str, int]) -> List[str]:
	"""Names of any quantized value outside the int32 range the position columns commit to."""
	return ["%s=%d" % (name, value) for name, value in sorted(values.items())
		if value < INT32_MIN or value > INT32_MAX]


def compute_fit(record: Dict[str, Any], geometry: SourceGeometry) -> FitResult:
	"""Quantize outward, translate by the declared offset, and derive or refuse a clearance class."""
	local = _quantized_local_bounds(record)
	offset_x = record["anchor_to_root_offset_units"]["x"]
	offset_z = record["anchor_to_root_offset_units"]["z"]
	baseline = (offset_x == geometry.cell_centre_offset_units
		and offset_z == geometry.cell_centre_offset_units)
	translated = {
		"x_lo": offset_x + local["x_lo"], "x_hi": offset_x + local["x_hi"],
		"z_lo": offset_z + local["z_lo"], "z_hi": offset_z + local["z_hi"],
	}
	context = dict(local_bounds=local, translated_bounds=translated,
		offset=(offset_x, offset_z), offset_is_baseline=baseline)
	uncovered = residual_error_problems(record, "record") + export_rounding_problems(record, "record")
	if uncovered:
		return FitResult(REFUSE_UNCOVERED_ERROR, False, "; ".join(uncovered),
			admitting_class_count=0, **context)
	offenders = _int32_offenders(dict(local, **translated))
	if offenders:
		return FitResult(REFUSE_INT32, False,
			"quantized bound(s) outside int32: %s" % ", ".join(offenders),
			admitting_class_count=0, **context)
	return _derive_class(translated, geometry, context)


def _derive_class(translated: Dict[str, int], geometry: SourceGeometry,
		context: Dict[str, Any]) -> FitResult:
	"""The placement test, then the class derivation, then an independent containment recheck."""
	corners = (translated["x_lo"], translated["z_lo"], translated["x_hi"], translated["z_hi"])
	if translated["x_hi"] < translated["x_lo"] or translated["z_hi"] < translated["z_lo"]:
		return FitResult(REFUSE_INVERTED, False, "a maximum lies below its minimum",
			admitting_class_count=0, **context)
	admitting = classes_admitting(*corners, geometry=geometry)
	naive = _naive_lower_bound(translated, geometry)
	if translated["x_lo"] < 0 or translated["z_lo"] < 0:
		return FitResult(REFUSE_PLACEMENT, False,
			_placement_detail(translated, geometry, admitting, naive),
			admitting_class_count=len(admitting), naive_lower_bound_class=naive, **context)
	derived = max(geometry.clearance_class_min,
		ceil_div_nonnegative(translated["x_hi"], geometry.cell_size_units),
		ceil_div_nonnegative(translated["z_hi"], geometry.cell_size_units))
	if derived > geometry.clearance_class_max:
		return FitResult(REFUSE_CLASS_DOMAIN, False,
			"the least containing class is %d, beyond the published domain %d..%d"
			% (derived, geometry.clearance_class_min, geometry.clearance_class_max),
			admitting_class_count=len(admitting), naive_lower_bound_class=naive, **context)
	if not admitting or admitting[0] != derived:
		return FitResult(REFUSE_INCONSISTENT, False,
			"derived class %d disagrees with the exhaustive containment scan (%s)"
			% (derived, admitting[0] if admitting else "no class contains these bounds"),
			admitting_class_count=len(admitting), naive_lower_bound_class=naive, **context)
	return FitResult(FIT_OK, True, "contained by class %d at the declared offset" % derived,
		admitting_class_count=len(admitting), clearance_class=derived,
		naive_lower_bound_class=naive, **context)


def _naive_lower_bound(translated: Dict[str, int], geometry: SourceGeometry) -> int:
	"""`ceil(max(width, depth) / cell)`. Reported only to show it is NOT the containment answer."""
	width = translated["x_hi"] - translated["x_lo"]
	depth = translated["z_hi"] - translated["z_lo"]
	return max(geometry.clearance_class_min,
		ceil_div_nonnegative(max(width, depth), geometry.cell_size_units))


def _placement_detail(translated: Dict[str, int], geometry: SourceGeometry,
		admitting: List[int], naive: int) -> str:
	"""The message that must never read as 'needs a bigger class', because no such class exists."""
	negatives = ", ".join("%s=%d" % (name, translated[name])
		for name in ("x_lo", "z_lo") if translated[name] < 0)
	return ("translated minimum below the north-west anchor (%s). The clearance square grows "
		"SOUTH and EAST from its anchor, so no clearance class repairs this: %d of the %d published "
		"classes admit these bounds. This is a placement incompatibility at the declared offset, "
		"NOT a larger-class requirement. A naive ceil(max(width,depth)/cell) would have answered "
		"class %d, which is exactly the lower bound MOVE-C2-R01 4 says never replaces containment. "
		"Re-centring needs a reviewed MOVE-G02 position/anchor/save contract and is not applied "
		"here." % (
			negatives, len(admitting),
			geometry.clearance_class_max - geometry.clearance_class_min + 1, naive))


def anchor_square_within_map(anchor_x: int, anchor_z: int, clearance_class: int,
		geometry: SourceGeometry) -> bool:
	"""True when the whole k-square anchored at this cell stays inside the published grid."""
	if anchor_x < 0 or anchor_z < 0 or clearance_class < geometry.clearance_class_min:
		return False
	return (anchor_x + clearance_class <= geometry.cells_x
		and anchor_z + clearance_class <= geometry.cells_z)


# --- driving one file ----------------------------------------------------------------------------


@dataclass
class FileReport:
	"""One record file's outcome: its refusals, and one fit per record that survived validation."""

	path: pathlib.Path
	problems: List[str]
	fits: List[Tuple[str, FitResult]]

	def refused(self) -> bool:
		"""True when anything about the file, its schema conformance or its semantics was refused."""
		return bool(self.problems)


def validate_file(path: pathlib.Path, schema: Dict[str, Any],
		geometry: SourceGeometry) -> FileReport:
	"""Validate one record file structurally and semantically, then fit every accepted record."""
	try:
		document = json.loads(path.read_text(encoding="utf-8"))
	except (OSError, ValueError) as error:
		return FileReport(path, ["%s: unreadable record file -- %s" % (path, error)], [])
	problems = validate_instance(document, schema)
	if problems:
		return FileReport(path, problems, [])
	problems.extend(file_semantic_problems(document, geometry))
	fits: List[Tuple[str, FitResult]] = []
	for index, record in enumerate(document["records"]):
		where = "$.records[%d]" % index
		record_problems = record_semantic_problems(record, where, geometry)
		problems.extend(record_problems)
		if not record_problems:
			fits.append((_record_label(record, where), compute_fit(record, geometry)))
	return FileReport(path, problems, fits)


def _record_label(record: Dict[str, Any], where: str) -> str:
	"""A human-readable identity for one record, carrying its data class in plain sight."""
	identity = record["identity"]
	return "%s %s/%s/%s/%s [%s]" % (where, identity["species_key"], identity["life_stage"],
		identity["mode"], record["variant"]["variant_key"], record["data_class"])


def render_report(reports: List[FileReport]) -> str:
	"""The human-facing text report: every refusal, then every fit outcome."""
	lines: List[str] = []
	for report in reports:
		lines.append("== %s" % report.path)
		for problem in report.problems:
			lines.append("   REFUSED %s" % problem)
		for label, fit in report.fits:
			lines.append("   %-12s %s" % (fit.outcome, label))
			lines.append("      local x[%d..%d] z[%d..%d] y[%d..%d] -> translated x[%d..%d] "
				"z[%d..%d] at offset %s%s" % (
					fit.local_bounds["x_lo"], fit.local_bounds["x_hi"],
					fit.local_bounds["z_lo"], fit.local_bounds["z_hi"],
					fit.local_bounds["y_lo"], fit.local_bounds["y_hi"],
					fit.translated_bounds["x_lo"], fit.translated_bounds["x_hi"],
					fit.translated_bounds["z_lo"], fit.translated_bounds["z_hi"],
					fit.offset, "" if fit.offset_is_baseline else " (NOT baseline: report only)"))
			lines.append("      %s" % fit.detail)
			lines.append("      vertical fit y[%d..%d] is NOT proven by this square test; "
				"openings, support and turns need MOVE-C2-R01 6 evidence"
				% (fit.local_bounds["y_lo"], fit.local_bounds["y_hi"]))
	return "\n".join(lines)


# --- clearly synthetic fixtures ------------------------------------------------------------------
#
# EVERY NUMBER BELOW IS INVENTED. None of it is a measurement, a body dimension, a gear extent or a
# load bound, and none of it may be copied into a profile. The values were chosen only because they
# exercise the arithmetic: one set lands inside a single cell, and one set is deliberately wide
# enough that its translated minimum goes negative at the baseline +256/+256 root offset. The
# species key is not a Redwall species, so a grep for a real one cannot find these.

SYNTHETIC_NOTE = (
	"SYNTHETIC TEST DATA -- invented to exercise tools/validate_movement_envelopes.py. "
	"Not a measurement, not a body dimension, not an authored profile, not a mode permission.")


def _synthetic_record(variant_key: str, half_extent_micrometres: int, margin: int) -> Dict[str, Any]:
	"""One fully-formed synthetic record. The extent is an arbitrary test number, not a body."""
	return {
		"data_class": "synthetic_fixture",
		"synthetic_note": SYNTHETIC_NOTE,
		"identity": {
			"species_key": "synthetic_specimen_alpha", "life_stage": "ADULT", "life_stage_id": 0,
			"mode": "GROUND_WALK", "mode_id": 0, "posture": "SYNTHETIC_TEST_POSTURE",
			"profile_revision": 1,
		},
		"variant": {
			"variant_key": variant_key, "equipment": [], "cargo": [], "support_attachments": [],
			"all_listed_items_included_in_sweep": True,
		},
		"measurement": {
			"method": "synthetic constant, authored by hand for tooling tests only",
			"states_covered": ["ENTRY", "TRAVEL", "HOLD", "TURN", "REVERSAL", "RETREAT", "EXIT"],
			"orientations_covered": ["SYNTHETIC_ALL_YAW"],
			"pose_interpolation_covered": True,
			"interpolation_error_bound_units": 0,
			"zero_residual_evidence": "synthetic fixture: the extrema above ARE the fixture, so "
				"there is no continuous sweep outside them and no residual to carry. This is a "
				"statement about invented numbers, never about a measured body.",
			"micrometre_export_rounding": EXPORT_ROUNDING_OUTWARD,
			"bounds_micrometres": {
				"x_min": -half_extent_micrometres, "x_max": half_extent_micrometres,
				"y_min": 0, "y_max": half_extent_micrometres,
				"z_min": -half_extent_micrometres, "z_max": half_extent_micrometres,
			},
		},
		"margin_units": {
			"x": margin, "y": margin, "z": margin,
			"provenance": "synthetic fixture constant; no measurement owner and no real allowance",
		},
		"anchor_to_root_offset_units": {"x": 256, "z": 256},
	}


def synthetic_document(records: List[Dict[str, Any]], geometry: SourceGeometry) -> Dict[str, Any]:
	"""Wrap synthetic records in a file whose convention block mirrors the owning GDScript."""
	document: Dict[str, Any] = {
		"schema_version": SUPPORTED_SCHEMA_VERSION,
		"units": {
			"simulation_units_per_metre": 1024,
			"measured_input_unit": "signed_integer_micrometres",
			"note": SYNTHETIC_NOTE,
		},
		"convention": {"up_axis": "+Y", "forward_axis": "-Z", "cell_anchor": "north_west"},
		"records": records,
	}
	document["convention"].update(geometry.convention_fields())
	return document


def synthetic_fixtures(geometry: SourceGeometry) -> Dict[str, Dict[str, Any]]:
	"""The labelled synthetic fixture set: two well-formed files and four malformed ones."""
	narrow = _synthetic_record("SYNTHETIC_NARROW", 200000, 5)
	wide = _synthetic_record("SYNTHETIC_WIDE_NEGATIVE_TRANSLATED_MINIMUM", 400000, 8)
	fixtures = {
		"synthetic_fits_class_1.json": synthetic_document([narrow], geometry),
		"synthetic_placement_incompatible.json": synthetic_document([wide], geometry),
	}
	fixtures.update(_malformed_fixtures(narrow, geometry))
	return fixtures


def _malformed_fixtures(base: Dict[str, Any], geometry: SourceGeometry) -> Dict[str, Dict[str, Any]]:
	"""One file per malformed shape the validator must refuse, each broken in exactly one way."""
	zero_margin = json.loads(json.dumps(base))
	zero_margin["margin_units"].update({"x": 0, "y": 0, "z": 0})
	hand_numbered = json.loads(json.dumps(base))
	hand_numbered["identity"]["mode_id"] = 4
	with_provenance = json.loads(json.dumps(base))
	with_provenance["provenance"] = {
		"source_mesh": "none", "source_content_sha256": "0" * 64,
		"proportion_revision": 1, "measured_by": "nobody", "measured_on": "2026-09-14"}
	unknown_property = json.loads(json.dumps(base))
	unknown_property["clearance_class"] = 3
	fixtures = {
		"malformed_zero_margin_without_justification.json":
			synthetic_document([zero_margin], geometry),
		"malformed_hand_numbered_mode_id.json": synthetic_document([hand_numbered], geometry),
		"malformed_synthetic_carries_provenance.json":
			synthetic_document([with_provenance], geometry),
		"malformed_unknown_property.json": synthetic_document([unknown_property], geometry),
	}
	fixtures.update(_malformed_error_fixtures(base, geometry))
	return fixtures


def _malformed_error_fixtures(base: Dict[str, Any],
		geometry: SourceGeometry) -> Dict[str, Dict[str, Any]]:
	"""MOVE-C3-R01 6's four refusals: uncovered residual, unevidenced zero, inward export, schema 1."""
	uncovered = json.loads(json.dumps(base))
	uncovered["measurement"]["interpolation_error_bound_units"] = 1
	uncovered["margin_units"].update({"x": 0, "y": 0, "z": 0})
	uncovered["margin_units"]["zero_margin_justification"] = (
		"synthetic fixture: this prose is deliberately present to show it cannot cover a "
		"positive uncovered residual.")
	unevidenced = json.loads(json.dumps(base))
	unevidenced["measurement"].pop("zero_residual_evidence")
	inward = json.loads(json.dumps(base))
	inward["measurement"]["micrometre_export_rounding"] = "nearest"
	historical = synthetic_document([json.loads(json.dumps(base))], geometry)
	historical["schema_version"] = HISTORICAL_SCHEMA_VERSIONS[0]
	return {
		"malformed_uncovered_interpolation_error.json": synthetic_document([uncovered], geometry),
		"malformed_zero_residual_without_evidence.json": synthetic_document([unevidenced], geometry),
		"malformed_inward_micrometre_export.json": synthetic_document([inward], geometry),
		"malformed_schema_version_1.json": historical,
	}


def write_synthetic_fixtures(directory: pathlib.Path, geometry: SourceGeometry) -> List[pathlib.Path]:
	"""Write the synthetic fixture set so a reader can reproduce every outcome by hand."""
	directory.mkdir(parents=True, exist_ok=True)
	written: List[pathlib.Path] = []
	for name, document in sorted(synthetic_fixtures(geometry).items()):
		path = directory / name
		path.write_text(json.dumps(document, indent="\t") + "\n", encoding="utf-8")
		written.append(path)
	return written


# --- command line --------------------------------------------------------------------------------


def _report_as_json(reports: List[FileReport]) -> str:
	"""The machine-readable form of the same report, for a caller that wants to assert on it."""
	payload = [{
		"path": str(report.path),
		"problems": report.problems,
		"fits": [{
			"record": label, "outcome": fit.outcome, "ok": fit.ok, "detail": fit.detail,
			"clearance_class": fit.clearance_class,
			"naive_lower_bound_class": fit.naive_lower_bound_class,
			"admitting_class_count": fit.admitting_class_count,
			"offset": list(fit.offset), "offset_is_baseline": fit.offset_is_baseline,
			"local_bounds": fit.local_bounds, "translated_bounds": fit.translated_bounds,
		} for label, fit in report.fits],
	} for report in reports]
	return json.dumps(payload, indent="\t")


def _build_parser() -> argparse.ArgumentParser:
	"""The command line. Running with no record file is a refusal, not a silent success."""
	parser = argparse.ArgumentParser(description=__doc__.split("\n", 1)[0])
	parser.add_argument("paths", nargs="*", type=pathlib.Path, help="record files to validate")
	parser.add_argument("--schema", type=pathlib.Path, default=SCHEMA_PATH)
	parser.add_argument("--source-root", type=pathlib.Path, default=ROOT,
		help="repository root holding godot/scripts/core (default: this checkout)")
	parser.add_argument("--json", action="store_true", help="emit the report as JSON")
	parser.add_argument("--emit-synthetic-fixtures", type=pathlib.Path, metavar="DIR",
		help="write the labelled synthetic fixture set and exit")
	return parser


def main(argv: Optional[List[str]] = None) -> int:
	"""Validate every named record file. See the module docstring for the exit statuses."""
	args = _build_parser().parse_args(argv)
	try:
		geometry = load_source_geometry(args.source_root)
		schema = json.loads(args.schema.read_text(encoding="utf-8"))
	except (EnvelopeRefusal, OSError, ValueError) as error:
		print("validate_movement_envelopes: REFUSE -- %s" % error)
		return EXIT_REFUSED
	if args.emit_synthetic_fixtures is not None:
		for path in write_synthetic_fixtures(args.emit_synthetic_fixtures, geometry):
			print("wrote %s" % path)
		return EXIT_OK
	unsupported = schema_support_problems(schema)
	for problem in unsupported:
		print("validate_movement_envelopes: SCHEMA %s" % problem)
	if unsupported or not args.paths:
		print("validate_movement_envelopes: REFUSE -- %s" % (
			"the schema uses keywords this validator does not enforce" if unsupported
			else "no record file was named; validating nothing is not a pass"))
		return EXIT_REFUSED
	return _run(args, schema, geometry)


def _run(args: argparse.Namespace, schema: Dict[str, Any], geometry: SourceGeometry) -> int:
	"""Validate the named files and choose the exit status from the outcomes."""
	reports = [validate_file(path, schema, geometry) for path in args.paths]
	print(_report_as_json(reports) if args.json else render_report(reports))
	refusals = sum(len(report.problems) for report in reports)
	fits = [fit for report in reports for _, fit in report.fits]
	unfit = [fit for fit in fits if not fit.ok]
	if refusals or not fits:
		print("validate_movement_envelopes: REFUSE -- %d file(s), %d record(s), %d refusal(s)"
			% (len(reports), len(fits), refusals or 1))
		return EXIT_REFUSED
	status = "DOES_NOT_FIT" if unfit else "PASS"
	print("validate_movement_envelopes: %s -- %d file(s), %d record(s), %d refusal(s), "
		"%d not fitting as placed" % (status, len(reports), len(fits), refusals, len(unfit)))
	return EXIT_DOES_NOT_FIT if unfit else EXIT_OK


if __name__ == "__main__":
	sys.exit(main())
