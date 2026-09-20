extends "res://scripts/core/movement.gd"
## Test-only Movement subclass exercising GROUND-CLEARANCE-R01v1's admission gate.
##
## Production `profile_clearance_class_into()` refuses for every starter profile, because no
## starter profile has an authored body-plus-gear clearance envelope yet (see movement.gd's own
## header). Real admission motion therefore cannot be exercised against production at all. This
## fixture overrides ONLY that one reader, to return an explicit, test-configured clearance class
## for an otherwise-valid profile id; every other Movement method -- including `begin_travel()`
## itself and the whole admission gate order -- runs completely unmodified, so a test using this
## fixture still exercises real production admission logic, refusal ordering and attachment.
##
## Invalid profile ids retain the parent's REFUSE_PROFILE_ID behaviour: this override substitutes
## the ONE missing envelope value, never the identity check that precedes it. No production
## source references this fixture; it lives only under `godot/test`.

## The class this fixture answers with for any valid profile id until reconfigured. A test-only
## value, never read from production and never assigned any body-dimension meaning.
const DEFAULT_SYNTHETIC_CLASS: int = 1

var _synthetic_class: int = DEFAULT_SYNTHETIC_CLASS


func set_synthetic_clearance_class(clearance_class: int) -> void:
	"""Change the class this fixture answers with for every subsequent valid-profile call.

	Test-only configuration, not a production API: nothing outside `godot/test` may call this.
	"""
	_synthetic_class = clearance_class


func profile_clearance_class_into(profile_id: int, out: IntMath.IntResult) -> bool:
	"""Answer the configured synthetic class for a valid profile id; refuse exactly as the
	parent does for an invalid one.
	"""
	if not is_profile(profile_id):
		_last_refusal = REFUSE_PROFILE_ID
		return out.refuse(REFUSE_PROFILE_ID)
	_last_refusal = REFUSE_NONE
	return out.succeed(_synthetic_class)
