# Authoritative resident spawn — native macOS captures (INIT-POSE-R01)

Captured 2026-09-14 from the **native macOS game**, not a headless render and not an editor
preview. `--headless` cannot produce these: Godot's dummy renderer returns `null` from
`Viewport.get_texture().get_image()`, and the harness below prints that rather than writing a
file. `save_png` also needs an **ABSOLUTE** path; a `res://` or relative path fails with a
non-zero error code and no file, so the harness prints the code.

These supersede nothing in `../screenshots/`. Those captures showed the same twelve mice standing
on the same apron row from a **presentation-private** pose store (decision 0130's scaffold). What
is new here is the *ownership*: the poses are now authoritative state written by
`settlement_system.gd` inside the generation transaction, and the renderer reads that exact store.
The picture is meant to look the same. The report lines are the evidence.

| Field | Value |
| --- | --- |
| Branch / base revision | `feat/render-spawn`, branched from `127c8e4` (`origin/master` at branch time) |
| Engine | Godot 4.7.2 stable (official, ed1daf0bf), Metal Forward+, macOS (Darwin 25.6.0) |
| Scene | `res://scenes/main.tscn` — the project's own `run/main_scene`, instantiated unmodified |
| World seed | 20260905 (GDD §5.1's fixed tutorial seed, `WorldInit.TUTORIAL_WORLD_SEED`) |
| Fixture | `SettlementSystem.create_generated_settlement()` — GDD §5.1's **real twelve-resident cohort**, placed by INIT-POSE-R01 |
| Clock state | **Paused: PLAYER** (UI-SET-103's opening inspection pause), so sub-tick debt is 0 and alpha is 0 |
| Crowd mesh | `res://assets/units/species_mouse_body_a_lod0.glb` — the **authored GLB**, not the fallback box |
| Headless suite at capture time | `4353 test(s), 155505 assertion(s), 0 failure(s)` |
| Mutation testing | 17 mutations, **one Godot invocation each**, file restored and SHA-256 byte-compared after every run |

## The exact commands

```bash
E=/abs/path/docs/validation/evidence/resident-render-path/authoritative-spawn/screenshots

# 01 — 1920x1080, the committed camera
godot --path godot --script capture_spawn_scratch.gd --resolution 1920x1080 \
  -- "$E/01_authoritative_cohort_wide_1920x1080.png" 45

# 02 — the same boot, camera overridden to orthographic size 4 for the close-up
godot --path godot --script capture_spawn_scratch.gd --resolution 1920x1080 \
  -- "$E/02_authoritative_cohort_closeup_1920x1080.png" 45 4

# 03 — 1280x720, the supported floor
godot --path godot --script capture_spawn_scratch.gd --resolution 1280x720 \
  -- "$E/03_authoritative_cohort_standard_1280x720.png" 45

# 04 — the committed camera, with ONE authoritative pose changed 15 frames before the capture
godot --path godot --script capture_spawn_scratch.gd --resolution 1920x1080 \
  -- "$E/04_controlled_pose_change_1920x1080.png" 60 0 2048
```

`capture_spawn_scratch.gd` is a scratch file, **deleted before the commit**, and reproduced in
full here. It instantiates the project's own main scene and touches nothing else; the close-up
camera and the controlled pose change are applied only when their arguments are given.

```gdscript
extends SceneTree

var _main: Node = null
var _frames: int = 0
var _wait: int = 45
var _out: String = ""
var _zoom: float = 0.0
var _move: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0]
	if args.size() > 1:
		_wait = int(args[1])
	if args.size() > 2:
		_zoom = float(args[2])
	if args.size() > 3:
		_move = int(args[3])
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	_main = packed.instantiate()
	root.add_child(_main)
	if _zoom > 0.0:
		var cam: Camera3D = _main.get_node("World/Camera3D") as Camera3D
		cam.size = _zoom
		cam.position = Vector3(117.0, 3.5, 142.5)


func _process(_delta: float) -> bool:
	_frames += 1
	if _move != 0 and _frames == _wait - 15:
		_teleport_first_resident()
	if _frames < _wait:
		return false
	_report()
	var image: Image = root.get_texture().get_image()
	if image == null:
		printerr("CAPTURE: get_image() returned null (dummy renderer?)")
		return true
	var err: int = image.save_png(_out)
	print("CAPTURE: %s -> %d (%dx%d)" % [_out, err, image.get_width(), image.get_height()])
	return true


func _teleport_first_resident() -> void:
	var settlement: Node = root.get_node_or_null("/root/SettlementSystem")
	var slot: int = _slot_of(settlement, 1)
	var ref: Vector2i = settlement.residents().ref_of(slot)
	var ok: bool = settlement.transforms().place(ref, 119808, 512 + _move, 142336, 0)
	print("REPORT: controlled authoritative pose change y+=%d ok=%s" % [_move, ok])
	_main.get_node("World/Entities/ResidentStage")._process(0.0)


func _report() -> void:
	var stage: Node = _main.get_node_or_null("World/Entities/ResidentStage")
	var crowd: MultiMeshInstance3D = stage.get_node_or_null("ResidentCrowd")
	var settlement: Node = root.get_node_or_null("/root/SettlementSystem")
	print("REPORT: attached=%s mesh=%s drawn=%d visible=%d skipped=%d" % [
		stage.is_attached(), stage.mesh_source(), crowd.drawn_count(),
		crowd.visible_instance_count(), crowd.skipped_unplaced_count()])
	print("REPORT: residents living=%d population=%d" % [
		settlement.living_count(), settlement.population()])
	var store: RefCounted = settlement.transforms()
	print("REPORT: store settlement==stage %s  settlement==crowd %s  bound=%d" % [
		store == stage.transforms(), store == crowd.transforms(), store.bound_count()])
	var pose: RefCounted = load("res://scripts/core/transforms.gd").Pose.new()
	for id: int in [1, 2, 12]:
		var slot: int = _slot_of(settlement, id)
		var ref: Vector2i = settlement.residents().ref_of(slot)
		var ok: bool = store.read_into(ref, pose)
		print("REPORT: id %d slot %d authoritative (%d,%d,%d) yaw %d prev_equal=%s ok=%s" % [
			id, slot, pose.x, pose.y, pose.z, pose.yaw, pose.matches_previous(), ok])
	for i: int in 3:
		print("REPORT: instance %d origin %s" % [i, crowd.instance_origin(i)])
	print("REPORT: instance 11 origin %s" % crowd.instance_origin(11))
	print("REPORT: aabb=%s" % crowd.get_aabb())
	print("REPORT: window=%s" % DisplayServer.window_get_size())


func _slot_of(settlement: Node, persistent_id: int) -> int:
	for slot: int in 512:
		if not settlement.residents().is_alive(slot):
			continue
		if settlement.residents().persistent_id_of(slot).value == persistent_id:
			return slot
	return -1
```

## What the harness printed

Verbatim, from the 1920×1080 run (capture 01):

```
[Main] resident crowd attached: mesh species_mouse_body_a_lod0.glb
[Main] boot complete: PAUSED  food-days 5.48  ready 408000 NP  fuel-days --
REPORT: attached=true mesh=species_mouse_body_a_lod0.glb drawn=12 visible=12 skipped=0
REPORT: residents living=12 population=12
REPORT: store settlement==stage true  settlement==crowd true  bound=12
REPORT: id 1 slot 0 authoritative (119808,512,142336) yaw 0 prev_equal=true ok=true
REPORT: id 2 slot 1 authoritative (121856,512,142336) yaw 0 prev_equal=true ok=true
REPORT: id 12 slot 11 authoritative (142336,512,142336) yaw 0 prev_equal=true ok=true
REPORT: instance 0 origin (117.0, 0.5, 139.0)
REPORT: instance 1 origin (119.0, 0.5, 139.0)
REPORT: instance 2 origin (121.0, 0.5, 139.0)
REPORT: instance 11 origin (139.0, 0.5, 139.0)
REPORT: aabb=[P: (-0.427271, 0.0, -0.204294), S: (139.8546, 1.5, 139.4086)]
REPORT: window=(1920, 1080)
CAPTURE: .../01_authoritative_cohort_wide_1920x1080.png -> 0 (1920x1080)
```

`store settlement==stage true  settlement==crowd true` is the ownership line: `==` on two
`RefCounted`s is **reference identity**, so the settlement, the stage and the crowd are holding
ONE object, not three stores that happen to agree. `bound=12` is that store's own placed-row
count. No renderer allocates a `transforms.gd`; `resident_pose_scaffold.gd` no longer exists.

Every number is hand-checkable against INIT-POSE-R01 §1 and the inherited geometry:

* Persistent id 1 is `i = 0`: root x `119808 + 2048*0 = 119808`, y `512`, z `142336`.
* Persistent id 2 is `i = 1`: `119808 + 2048 = 121856`. Id 12 is `i = 11`:
  `119808 + 2048*11 = 142336`.
* Those are tile centres: GDD §5.1 puts a centre at `2048*t + 1024`, so tile x=58 is
  `2048*58 + 1024 = 119808` and tile z=69 is `2048*69 + 1024 = 142336`. Tile index
  `69*128 + 58 = 8890`.
* z=69 is one row south of §5.9's refuge hall at (58,59) extent 12×10, which occupies z=59..68.
* Metres are units/1024: `119808/1024 = 117.0`, `512/1024 = 0.5`, `142336/1024 = 139.0` — which
  is exactly `instance 0 origin (117.0, 0.5, 139.0)`, and instance 11 is `142336/1024 = 139.0`.
* `yaw 0` is the neutral authored model orientation and `prev_equal=true` is previous = current,
  which is what stops a spawned resident being interpolated out of somewhere it has never been.
* `skipped=0` means not one of the twelve was drawn from an unplaced pose.

## The captures

| # | File | Window | Shows |
| --- | --- | --- | --- |
| 01 | `screenshots/01_authoritative_cohort_wide_1920x1080.png` | 1920×1080 | GDD §5.1's twelve residents on §5.9's hall apron, drawn from the **settlement's own** Transform store |
| 02 | `screenshots/02_authoritative_cohort_closeup_1920x1080.png` | 1920×1080 | The same boot at orthographic size 4, for anatomy, scale and **facing** inspection |
| 03 | `screenshots/03_authoritative_cohort_standard_1280x720.png` | 1280×720 | The same twelve at the supported resolution floor |
| 04 | `screenshots/04_controlled_pose_change_1920x1080.png` | 1920×1080 | **A controlled authoritative pose change moves the rendered origin.** `transforms.place()` raises persistent id 1 by 2048 units (2 m) fifteen frames before the capture; it is visibly lifted above the row with its shadow on the ground, and the report reads `id 1 authoritative (119808,2560,142336)` / `instance 0 origin (117.0, 2.5, 139.0)` |

## Read these captures honestly

1. **THIS IS NOT VISUAL ACCEPTANCE.** Species, material, rig and facing validation is a separate
   presentation lane. The whole cohort draws as one untextured white bind-pose mouse mesh, and the
   arms-out silhouette is the model's rest pose, not a wrong transform.
2. **The facing still needs a human eye.** The renderer applies **no rotation at all** —
   `transforms.gd` names the yaw zero reference and handedness as MOVE-G01/G04 blockers, so
   deriving a basis from yaw would invent the convention. In capture 02 the model faces the
   camera, which sits on the **+Z** side looking toward −Z. This project's convention is **−Z
   forward** while glTF conventionally puts the front at +Z. No automated check can settle it.
   **Do not read the initial yaw of 0 as a rotation convention for moving actors.**
3. **They are standing still, deliberately.** Nothing moves them: `place()` writes previous =
   current and no mover exists. Capture 04 is a *controlled* pose change made by the harness, not
   gameplay movement.
4. **The HUD still reads `Residents --`, `Food --` and `No world generated`.** That is the UI
   lane's binding, unchanged by this work and present in the previous lane's captures too.
5. **No performance claim.** Task 10.4's qualification needs measurement that was not taken.

Design, blockers and what a later lane inherits:
[decision 0138](../../../decisions/0138-the-settlement-owns-one-pose-store-and-places-the-cohort-on-the-hall-apron.md),
and the contract it implements,
[INIT-POSE-R01](../../../rulings/2026-09-14_initial_resident_positions.md).
