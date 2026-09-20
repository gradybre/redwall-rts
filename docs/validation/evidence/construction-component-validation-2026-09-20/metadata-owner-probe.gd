extends SceneTree
## CONSTRUCTION-S4-VALIDATE-R01v2 -- cold metadata probe for the Construction owner's static
## local-validation surface. DIAGNOSTIC ONLY: this is not a test suite, not evidence of a passing
## run, and not an acceptance or release claim. Nothing here has been executed by its author.
##
## Usage, in an isolated no-autoload clone of the project:
##     godot --headless --script res://<path>/metadata-owner-probe.gd
##     godot --headless --script res://<path>/metadata-owner-probe.gd -- --fault
##
## Baseline (no --fault) expects an intact immutable source. --fault expects a deterministically
## injected source fault in that clone. Expected codes are FROZEN STRING LITERALS, never the
## production REFUSE_* aliases, so a renamed production constant cannot make a mismatch read as a
## pass. Only static Owner APIs are exercised: no Construction instance, no Buildings, no
## Directory, no Definitions instance, no autoload, no warning suppression, no source mutation.
##
## Frozen expectations, both modes:
##   null image and unallocated Columns(false)  -> COLUMN_SHAPE, before any metadata result
## Baseline: direct metadata "", clear image "", invalid-flag image COLUMN_FLAG
## Fault:    direct metadata, clear image and invalid-flag image all COLUMN_SOURCE_METADATA

const Owner := preload("res://scripts/core/construction.gd")

const CODE_NONE: StringName = &""
const CODE_SHAPE: StringName = &"COLUMN_SHAPE"
const CODE_SOURCE_METADATA: StringName = &"COLUMN_SOURCE_METADATA"
const CODE_FLAG: StringName = &"COLUMN_FLAG"

const FAULT_ARG: String = "--fault"
const INVALID_FLAG_ROW: int = 0
const INVALID_FLAG_VALUE: int = 2

var _checks: int = 0
var _mismatches: int = 0


func _initialize() -> void:
	"""Take the five frozen observations, print an exact summary, exit 1 on any mismatch."""
	var fault: bool = OS.get_cmdline_user_args().has(FAULT_ARG)
	var expect_source: StringName = CODE_SOURCE_METADATA if fault else CODE_NONE
	var expect_flag: StringName = CODE_SOURCE_METADATA if fault else CODE_FLAG
	print("probe=metadata-owner contract=CONSTRUCTION-S4-VALIDATE-R01v2 mode=%s"
		% ("fault" if fault else "baseline"))
	_check("direct_metadata", Owner.column_source_metadata_refusal(), expect_source)
	_check("null_image", Owner.columns_refusal(null), CODE_SHAPE)
	_check("unallocated_image", Owner.columns_refusal(Owner.Columns.new(false)), CODE_SHAPE)
	_check("clear_image", Owner.columns_refusal(Owner.Columns.new()), expect_source)
	_check("invalid_flag_image", Owner.columns_refusal(_invalid_flag_image()), expect_flag)
	var ok: bool = _mismatches == 0
	print("checks=%d mismatches=%d ok=%s" % [_checks, _mismatches, str(ok).to_lower()])
	print("claim=none: diagnostic observation only; no test pass, acceptance or release claim")
	quit(0 if ok else 1)


func _check(label: String, actual: StringName, expected: StringName) -> void:
	"""Record one observation and print its label, actual code, expected code and match flag."""
	_checks += 1
	var matched: bool = actual == expected
	if not matched:
		_mismatches += 1
	print("check=%s actual=\"%s\" expected=\"%s\" match=%s"
		% [label, String(actual), String(expected), str(matched).to_lower()])


func _invalid_flag_image() -> Owner.Columns:
	"""A full-sized clear image whose first `present` byte carries a non-canonical flag value.

	Caller-owned and discarded here; the predicate is read-only, so this image is only ever an
	input. Nothing else on the row is touched, so the observation isolates the flag scan.
	"""
	var image: Owner.Columns = Owner.Columns.new()
	image.present[INVALID_FLAG_ROW] = INVALID_FLAG_VALUE
	return image
