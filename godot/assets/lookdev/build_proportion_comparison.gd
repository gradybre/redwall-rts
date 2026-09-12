extends SceneTree
## Build the proportion-comparison scene, measure it, write its manifest, capture its views.
##
## Run for scene + manifest only (works headless):
##   godot --headless --path godot --script assets/lookdev/build_proportion_comparison.gd
## Run for the review captures as well (needs a real rendering device -- a `--headless` run
## uses Godot's dummy renderer, whose `ViewportTexture.get_image()` returns null):
##   godot --path godot --script assets/lookdev/build_proportion_comparison.gd
##
## Every number in the manifest is MEASURED from the assembled scene, not copied from the
## specification it is checked against. The declared candidate heights appear beside the
## measured crowns so a reader can see that they agree, and the capture rows carry the
## SHA-256 of files that actually exist -- a capture that could not be rendered is absent
## and says why, rather than being listed as if it were on disk.
##
## The frame budget is bounded. An unbounded `_process` in a `--script` SceneTree hangs
## forever when a step never completes, so this one quits after MAX_FRAMES whatever happens.

const Comparison := preload("res://assets/lookdev/proportion_comparison.gd")
const Dimensions := preload("res://assets/lookdev/lookdev_dimensions.gd")

const SCENE_PATH: String = "res://assets/lookdev/proportion_comparison.tscn"
const MANIFEST_PATH: String = "res://assets/lookdev/proportion_comparison_manifest.json"
const CAPTURE_DIRECTORY: String = "res://assets/lookdev/captures"

const WARMUP_FRAMES: int = 8
const MAX_FRAMES: int = 400

## `docs/ui_ux_controls.md` §6: perspective, vertical FOV 55, yaw 45, pitch 48 below the
## horizon, orbit 8-120 m. The three orbit rows are the legal minimum, the shipped default
## and the legal maximum, which is the set the look-development brief §2.2 fixed.
const VIEW_NAME: Array[String] = [
	"rts_orbit_008m_pitch48_yaw225", "rts_orbit_040m_pitch48_yaw045",
	"rts_orbit_120m_pitch48_yaw045", "rts_orbit_008m_pitch35_yaw225_work_contact",
	"rts_orbit_040m_pitch65_yaw045", "elevation_front",
]
const VIEW_ORBIT_M: Array[float] = [8.0, 40.0, 120.0, 8.0, 40.0, 0.0]
const VIEW_PITCH_DEGREES: Array[float] = [48.0, 48.0, 48.0, 35.0, 65.0, 0.0]
## Residents face -Z, so the shipped INITIAL yaw of 45 shows their backs. Orbit yaw is
## unrestricted in `ui_ux_controls.md` §6, so 225 is an equally legal camera and is used
## where the review needs to see a face. Both are captured; the pair is also the facing check.
const VIEW_YAW_DEGREES: Array[float] = [225.0, 45.0, 45.0, 225.0, 45.0, 0.0]
const VIEW_WIDTH: Array[int] = [1920, 1920, 1920, 1920, 1920, 3200]
const VIEW_HEIGHT: Array[int] = [1080, 1080, 1080, 1080, 1080, 800]

## Which station each view looks at. `TARGET_WHOLE_SHEET` is a station index past the last
## pose, not a failure value: it names "frame the entire comparison" as its own choice.
const TARGET_WHOLE_SHEET: int = 4
const VIEW_TARGET: Array[int] = [0, TARGET_WHOLE_SHEET, TARGET_WHOLE_SHEET, 2,
	TARGET_WHOLE_SHEET, 0]

const CAMERA_FOV_DEGREES: float = 55.0
const ELEVATION_ORTHO_SIZE: float = 5.6
const ELEVATION_CENTRE_Y_M: float = 2.0
const ELEVATION_STANDOFF_M: float = 14.0
## The elevation clips just behind the doorway panel so the stations further back do not
## stack horizontal bars across the measured sheet.
const ELEVATION_FAR_MARGIN_M: float = 1.5
const WHOLE_SHEET_CENTRE: Vector3 = Vector3(0.0, 1.2, 5.0)
## The key lights the -Z side, which is the side residents face and the side the elevation
## sheet is taken from; the fill keeps the +Z side off pure silhouette at the shipped yaw.
const KEY_LIGHT_PITCH_DEGREES: float = -46.0
const KEY_LIGHT_YAW_DEGREES: float = 218.0
const KEY_LIGHT_ENERGY: float = 1.3
const FILL_LIGHT_PITCH_DEGREES: float = -32.0
const FILL_LIGHT_YAW_DEGREES: float = 28.0
const FILL_LIGHT_ENERGY: float = 0.55

var _viewport: SubViewport = null
var _camera: Camera3D = null
var _scene_root: Node3D = null
var _total_frames: int = 0
var _view_frames: int = 0
var _view: int = 0
var _captures: Array = []
var _refusals: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	"""Assemble the scene inside a SubViewport and prepare the first view."""
	_scene_root = Comparison.build_scene()
	_viewport = SubViewport.new()
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.add_child(_scene_root)
	_viewport.add_child(_make_light("key_light", KEY_LIGHT_PITCH_DEGREES,
		KEY_LIGHT_YAW_DEGREES, KEY_LIGHT_ENERGY))
	_viewport.add_child(_make_light("fill_light", FILL_LIGHT_PITCH_DEGREES,
		FILL_LIGHT_YAW_DEGREES, FILL_LIGHT_ENERGY))
	_viewport.add_child(_make_environment())
	_camera = Camera3D.new()
	_viewport.add_child(_camera)
	_camera.current = true
	root.add_child(_viewport)
	_apply_view(0)


func _process(_delta: float) -> bool:
	"""Warm the renderer, capture one view, move to the next, then write scene and manifest."""
	_total_frames += 1
	_view_frames += 1
	if _total_frames > MAX_FRAMES:
		_refusals.append("frame budget %d exhausted with %d view(s) left"
			% [MAX_FRAMES, VIEW_NAME.size() - _view])
		return _finish()
	if _view >= VIEW_NAME.size():
		return _finish()
	if _view_frames < WARMUP_FRAMES:
		return false
	_capture_current_view()
	_view += 1
	_view_frames = 0
	if _view < VIEW_NAME.size():
		_apply_view(_view)
	return false


func _finish() -> bool:
	"""Write the packed scene and the manifest, report, and end the run."""
	var packed_status: int = _write_scene()
	var manifest_status: int = _write_manifest()
	for refusal: String in _refusals:
		print("proportion-comparison: REFUSED %s" % refusal)
	print("proportion-comparison: scene=%s (%d) manifest=%s (%d) captures=%d/%d"
		% [SCENE_PATH, packed_status, MANIFEST_PATH, manifest_status,
			_captures.size(), VIEW_NAME.size()])
	quit(0 if packed_status == OK and manifest_status == OK else 1)
	return true


func _apply_view(view: int) -> void:
	"""Resize the viewport and place the camera for one prescribed view."""
	_viewport.size = Vector2i(VIEW_WIDTH[view], VIEW_HEIGHT[view])
	var target: Vector3 = _target_for(view)
	if VIEW_ORBIT_M[view] == 0.0:
		_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_camera.size = ELEVATION_ORTHO_SIZE
		_camera.position = target + Vector3(0.0, 0.0, -ELEVATION_STANDOFF_M)
		_camera.rotation = Vector3(0.0, PI, 0.0)
		_camera.near = 1.0
		_camera.far = ELEVATION_STANDOFF_M + ELEVATION_FAR_MARGIN_M
		return
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.near = 0.05
	_camera.far = 4000.0
	_camera.fov = CAMERA_FOV_DEGREES
	var pitch: float = deg_to_rad(VIEW_PITCH_DEGREES[view])
	var yaw: float = deg_to_rad(VIEW_YAW_DEGREES[view])
	var flat: float = cos(pitch) * VIEW_ORBIT_M[view]
	_camera.position = target + Vector3(flat * sin(yaw), sin(pitch) * VIEW_ORBIT_M[view],
		flat * cos(yaw))
	_camera.look_at_from_position(_camera.position, target, Vector3.UP)


func _target_for(view: int) -> Vector3:
	"""Where each view looks: one station, or the whole sheet."""
	if VIEW_TARGET[view] == TARGET_WHOLE_SHEET:
		return WHOLE_SHEET_CENTRE
	var station_z: float = Comparison.station_z_mm(VIEW_TARGET[view]) / 1000.0
	if VIEW_ORBIT_M[view] == 0.0:
		return Vector3(0.0, ELEVATION_CENTRE_Y_M, station_z)
	return Vector3(0.0, 1.0, station_z)


func _capture_current_view() -> void:
	"""Save one view to PNG, or record why it could not be saved. Never both."""
	var view_name: String = VIEW_NAME[_view]
	var texture: ViewportTexture = _viewport.get_texture()
	var image: Image = texture.get_image() if texture != null else null
	if image == null:
		_refusals.append("%s: the rendering device produced no image (dummy renderer?)" % view_name)
		return
	DirAccess.make_dir_recursive_absolute(CAPTURE_DIRECTORY)
	var path: String = "%s/%s.png" % [CAPTURE_DIRECTORY, view_name]
	var status: int = image.save_png(path)
	if status != OK:
		_refusals.append("%s: save_png returned %d" % [view_name, status])
		return
	_captures.append({
		"view": view_name,
		"path": path,
		"pixels": [image.get_width(), image.get_height()],
		"orbit_metres": VIEW_ORBIT_M[_view],
		"sha256": FileAccess.get_sha256(path),
	})


func _make_light(light_name: String, pitch: float, yaw: float,
		energy: float) -> DirectionalLight3D:
	"""One neutral directional light. Not ART-LOCK-001's fixed UI light angle; this is world art."""
	var light := DirectionalLight3D.new()
	light.name = light_name
	light.rotation_degrees = Vector3(pitch, yaw, 0.0)
	light.light_energy = energy
	# Shadows off: an orthographic elevation of a blockout reads by silhouette, and a long
	# cast shadow across the measured sheet obscures exactly what is being measured.
	light.shadow_enabled = false
	return light


func _make_environment() -> WorldEnvironment:
	"""Flat ambient fill so a blockout reads by volume rather than by a dramatic key."""
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.24, 0.26, 0.29)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.58, 0.62, 0.68)
	environment.ambient_light_energy = 0.35
	var node := WorldEnvironment.new()
	node.name = "environment"
	node.environment = environment
	return node


func _write_scene() -> int:
	"""Pack the assembled scene to disk so it can be reopened and re-rendered unchanged."""
	var packed := PackedScene.new()
	var packed_status: int = packed.pack(_scene_root)
	if packed_status != OK:
		return packed_status
	return ResourceSaver.save(packed, SCENE_PATH)


func _write_manifest() -> int:
	"""Write the measured manifest: species rows, prop rows, captures and the honest status."""
	var document: Dictionary = {
		"schema": "redwall.lookdev.proportion_comparison/1",
		"owner": "SET-ART-LOOKDEV-001 §3 and decision 0082; ruling ART-GAP-R01/R02",
		"status": String(Comparison.HEIGHT_STATUS),
		"purpose": "Decision 0002's required side-by-side review. Stature comparison only;"
			+ " anatomy approval needs the per-species construction sheets.",
		"origin": "Hand-authored blockout volumes built by this script. No asset generation"
			+ " was called and no credit was spent.",
		"references": _reference_rows(),
		"scene": SCENE_PATH,
		"camera": _camera_rows(),
		"species": _species_rows(),
		"props": _prop_rows(),
		"captures": _captures,
		"capture_refusals": Array(_refusals),
	}
	return _write_json(document)


func _write_json(document: Dictionary) -> int:
	"""Serialise the manifest with sorted keys so a rebuild produces a reviewable diff."""
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(document, "\t", true) + "\n")
	file.close()
	return OK


func _species_rows() -> Array:
	"""One row per species: declared candidate, measured blockout bounds, landmark permilles."""
	var rows: Array = []
	for row: int in Comparison.species_count():
		var poses: Dictionary = {}
		for pose: int in Comparison.POSE_COUNT:
			poses[String(Comparison.POSE_KEY[pose])] = _measured_pose_row(row, pose)
		rows.append({
			"key": String(Dimensions.SPECIES_KEY[row]),
			"candidate_height_u": Dimensions.SPECIES_HEIGHT_U[row],
			"candidate_height_mm": Dimensions.SPECIES_HEIGHT_MM[row],
			"height_status": String(Dimensions.SPECIES_STATUS[row]),
			"landmark_status": String(Comparison.LANDMARK_STATUS),
			"landmarks_permille": _landmark_row(row),
			"poses": poses,
		})
	return rows


func _landmark_row(row: int) -> Dictionary:
	"""The proposed landmark permilles for one species, as the measurement convention requires."""
	return {
		"crown": Comparison.PERMILLE,
		"skull_top": Comparison.SKULL_TOP_PERMILLE[row],
		"eye": Comparison.EYE_PERMILLE[row],
		"neck": Comparison.NECK_PERMILLE[row],
		"shoulder": Comparison.SHOULDER_PERMILLE[row],
		"hip": Comparison.HIP_PERMILLE[row],
		"torso_width": Comparison.TORSO_WIDTH_PERMILLE[row],
		"torso_depth": Comparison.TORSO_DEPTH_PERMILLE[row],
		"muzzle_projection": Comparison.MUZZLE_PERMILLE[row],
		"tail_length": Comparison.TAIL_PERMILLE[row],
		"ear_defines_crown": Comparison.EAR_DEFINES_CROWN[row] == 1,
	}


func _measured_pose_row(row: int, pose: int) -> Dictionary:
	"""Measured AABB of one species blockout in one pose, in millimetres, read off the scene."""
	var cell: Node3D = _find_cell(row, pose)
	var bounds: AABB = AABB() if cell == null else Comparison.measured_bounds_mm(cell)
	return {
		"station": String(Comparison.POSE_STATION[pose]),
		"declared_crown_mm": Comparison.crown_mm(row, pose),
		"measured_min_mm": _to_mm(bounds.position),
		"measured_max_mm": _to_mm(bounds.position + bounds.size),
	}


func _find_cell(row: int, pose: int) -> Node3D:
	"""The blockout node for one species in one pose. Pushes an error if the scene lacks it."""
	var cell: Node3D = Comparison.blockout_of(_scene_root, row, pose)
	if cell == null:
		push_error("proportion-comparison: %s %s is missing from the built scene"
			% [Dimensions.SPECIES_KEY[row], Comparison.POSE_KEY[pose]])
	return cell


func _to_mm(point: Vector3) -> Array:
	"""Round a measured millimetre point to the integer millimetres it was authored in."""
	return [roundi(point.x), roundi(point.y), roundi(point.z)]


func _prop_rows() -> Array:
	"""The shared props every species is compared against, with their authored millimetres."""
	return [
		{
			"key": "doorway",
			"source": "GAP-03 common-access opening 1536 x 3072 u",
			"opening_mm": [Comparison.DOOR_OPENING_WIDTH_MM, Comparison.DOOR_OPENING_HEIGHT_MM],
			"panel_mm": [Comparison.DOOR_PANEL_WIDTH_MM, Comparison.DOOR_PANEL_HEIGHT_MM,
				Comparison.DOOR_PANEL_DEPTH_MM],
			"status": "AUTHORING_BRIEF_NOT_A_CLEARANCE_QUALIFICATION",
		},
		{
			"key": "table",
			"source": "GDD §5.9 furniture 1x1 tile; GAP-03 640 u top height candidate",
			"footprint_mm": [Comparison.TABLE_SIZE_MM, Comparison.TABLE_SIZE_MM],
			"top_height_mm": Comparison.WORK_SURFACE_TOP_MM,
			"status": "EXPLICIT_CANDIDATE_NOT_A_UNIVERSAL_WORK_CONTACT_POLICY",
		},
		{
			"key": "work_surface",
			"source": "GAP-03 640 u top height candidate",
			"footprint_mm": [Comparison.WORK_SURFACE_LENGTH_MM, Comparison.WORK_SURFACE_DEPTH_MM],
			"top_height_mm": Comparison.WORK_SURFACE_TOP_MM,
			"status": "EXPLICIT_CANDIDATE_NOT_A_UNIVERSAL_WORK_CONTACT_POLICY",
		},
		{
			"key": "building_workbench_reference",
			"source": "GAP-03 workbench envelope 3584 u; GDD §5.9 footprint 3x3 tiles",
			"footprint_mm": [Comparison.SHELTER_FOOTPRINT_MM, Comparison.SHELTER_FOOTPRINT_MM],
			"max_local_y_mm": Comparison.SHELTER_HEIGHT_MM,
			"status": "ENVELOPE_REFERENCE_NOT_A_PRODUCTION_MODEL",
		},
	]


func _camera_rows() -> Array:
	"""The camera contract each capture was taken under, so a rerun is comparable."""
	var rows: Array = []
	for view: int in VIEW_NAME.size():
		var orthogonal: bool = VIEW_ORBIT_M[view] == 0.0
		rows.append({
			"view": VIEW_NAME[view],
			"pixels": [VIEW_WIDTH[view], VIEW_HEIGHT[view]],
			"projection": "orthogonal" if orthogonal else "perspective",
			"orbit_metres": VIEW_ORBIT_M[view],
			"ortho_size_metres": ELEVATION_ORTHO_SIZE if orthogonal else 0.0,
			"fov_degrees": 0.0 if orthogonal else CAMERA_FOV_DEGREES,
			"yaw_degrees": 0.0 if orthogonal else VIEW_YAW_DEGREES[view],
			"pitch_degrees": VIEW_PITCH_DEGREES[view],
			"target_station": "whole_sheet" if VIEW_TARGET[view] == TARGET_WHOLE_SHEET
				else String(Comparison.POSE_STATION[VIEW_TARGET[view]]),
		})
	return rows


func _reference_rows() -> Array:
	"""Provenance for every supplied reference this blockout set was read from (DEC-036)."""
	return [
		{"id": "DEC-038", "file": "docs/art-reference/visuals/grounded_expressive_rts_example_v1.png",
			"region": "both panels, full", "used_for": "mouse and mole mass, material intent"},
		{"id": "IMG-25", "file": "ImageReference/Screenshot 2026-09-06 at 2.26.38 PM.png",
			"region": "[413,247,1304,565) of 1366x1026",
			"used_for": "silhouette rank only; its bands are squad model counts, not heights"},
		{"id": "IMG-08", "file": "ImageReference/Screenshot 2026-09-06 at 2.21.25 PM.png",
			"region": "[12,415,744,1066)", "used_for": "mole compact mass and snout"},
		{"id": "IMG-07", "file": "ImageReference/Screenshot 2026-09-06 at 2.20.59 PM.png",
			"region": "[775,4,1408,976)", "used_for": "squirrel tail root and ear tufts"},
		{"id": "IMG-18", "file": "ImageReference/Screenshot 2026-09-06 at 2.24.20 PM.png",
			"region": "[771,157,1284,932)", "used_for": "otter torso length and tail taper"},
		{"id": "IMG-12", "file": "ImageReference/Screenshot 2026-09-06 at 2.23.01 PM.png",
			"region": "[1019,383,1432,956)", "used_for": "mouse ear rise and muzzle projection"},
	]
