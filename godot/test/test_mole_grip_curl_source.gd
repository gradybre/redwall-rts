extends "res://test/framework/test_case.gd"
## ADR 1216: the curled pick paw's deformation and refusals on synthetic inputs. The derivative of the real staged
## body is checked natively (curl-native-v1, capture_curled_paw.gd) and pinned by DERIVED_DIGEST.

const Curl := preload("res://data/underground/mole-worker/mole_grip_curl_source.gd")
const Accepted := preload("res://data/underground/mole-worker/mole_grip_source.gd")
const STEP: float = 1.0e-4  # Vector3 is single precision; a larger step keeps rounding below the tolerance


func _numeric(point: Vector3, share: float, axis: int) -> Vector2:
	"""Central difference of the curled (y, z) along hand-local y (axis 1) or z (axis 2)."""
	var delta: Vector3 = Vector3.ZERO
	delta[axis] = STEP
	var high: PackedFloat64Array = Curl.local_curl(point + delta, share)
	var low: PackedFloat64Array = Curl.local_curl(point - delta, share)
	return Vector2(high[1] - low[1], high[2] - low[2]) / (2.0 * STEP)


func test_missing_source_refuses_with_no_partial_mesh_or_fit() -> void:
	var result: Curl.Result = Curl.create(null, null, null, Transform3D.IDENTITY)
	assert_equal(result.error, &"MOLE_GRIP_SOURCE_IDENTITY", "the accepted source identity check runs first")
	assert_null(result.mesh, "no partial mesh")
	assert_equal(result.fit, Transform3D.IDENTITY, "no partial fit")
	assert_equal(result.changed_vertices, 0, "no partial count")


func test_palm_and_wrist_stay_and_the_curl_is_continuous_at_the_shaft_line() -> void:
	var wrist: PackedFloat64Array = Curl.local_curl(Vector3(0.01, 0.02, 0.03), 1.0)
	assert_true(is_equal_approx(wrist[1], 0.02) and is_equal_approx(wrist[2], 0.03), "below the profile nothing moves")
	var below: PackedFloat64Array = Curl.local_curl(Vector3(0.0, Curl.AXIS_Y_M - 1.0e-9, 0.01), 1.0)
	var above: PackedFloat64Array = Curl.local_curl(Vector3(0.0, Curl.AXIS_Y_M + 1.0e-9, 0.01), 1.0)
	assert_true(absf(below[1] - above[1]) < 1.0e-6 and absf(below[2] - above[2]) < 1.0e-6, "continuous at the shaft line")


func test_fingers_wrap_toward_the_palm_around_the_shaft() -> void:
	var quarter: float = Curl.AXIS_Y_M + Curl.RHO_M * PI / 2.0
	var tip: PackedFloat64Array = Curl.local_curl(Vector3(0.0, quarter, 0.0), 1.0)
	assert_true(tip[2] > 0.0, "a quarter turn brings the finger to the palm side")
	var radial: float = Vector2(tip[1] - Curl.AXIS_Y_M, tip[2] - Curl.AXIS_Z_M).length()
	assert_true(radial > 0.03, "the finger stays outside the shaft's own radius")
	var unweighted: PackedFloat64Array = Curl.local_curl(Vector3(0.0, quarter, 0.0), 0.0)
	assert_true(is_equal_approx(unweighted[1], quarter) and is_equal_approx(unweighted[2], 0.0), "no hand weight, no change")


func test_analytic_jacobian_matches_the_deformation() -> void:
	for point: Vector3 in [Vector3(0.0, 0.05, 0.02), Vector3(0.0, 0.12, -0.01), Vector3(0.0, 0.16, 0.03)]:
		for share: float in [1.0, 0.6]:
			var analytic: PackedFloat64Array = Curl.local_curl(point, share)
			var along_y: Vector2 = _numeric(point, share, 1)
			var along_z: Vector2 = _numeric(point, share, 2)
			assert_true(absf(along_y.x - analytic[3]) < 2.0e-3 and absf(along_z.x - analytic[4]) < 2.0e-3
				and absf(along_y.y - analytic[5]) < 2.0e-3 and absf(along_z.y - analytic[6]) < 2.0e-3,
				"Jacobian at %s share %s" % [point, share])


func test_held_fit_is_the_approved_lateral_two_transform() -> void:
	var fit: Transform3D = Curl.held_fit()
	assert_true(is_equal_approx(fit.basis.x.x, Curl.FIT_SCALE) and is_equal_approx(fit.basis.y.z, -Curl.FIT_SCALE)
		and is_equal_approx(fit.basis.z.y, Curl.FIT_SCALE), "the shaft runs across the paw, the head along +Y")
	assert_true(is_equal_approx(fit.basis.determinant(), pow(Curl.FIT_SCALE, 3.0)), "a proper scaled rotation")
	assert_true(fit.origin.is_equal_approx(Curl.FIT_ORIGIN_M), "resting on the palm")
	assert_equal(Curl.CHANGED_VERTICES, Accepted.CHANGED_VERTICES, "the same 845 grip vertices as the accepted paw")
