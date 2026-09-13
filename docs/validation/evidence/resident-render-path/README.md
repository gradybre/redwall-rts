# Resident render path — native macOS captures

Captured 2026-09-12 from the **native macOS game**, not a headless render and not an editor
preview. `--headless` cannot produce these: Godot's dummy renderer returns `null` from
`Viewport.get_texture().get_image()`, so a headless capture writes nothing and says so.

| Field | Value |
| --- | --- |
| Branch / base revision | `feat/resident-render-path`, branched from `914444b` (`origin/master` at branch time) |
| Engine | Godot 4.7.2 stable (official), Metal 4.0 Forward+, Apple M5 Pro |
| Scene | `res://scenes/main.tscn` — the project's own `run/main_scene`, instantiated unmodified |
| World seed | 20260905 (GDD §5.1's fixed tutorial seed, `WorldInit.TUTORIAL_WORLD_SEED`) |
| Fixture | `SettlementSystem.create_generated_settlement()` — GDD §5.1's **real twelve-resident cohort** |
| Clock state | **Paused: PLAYER** (UI-SET-103's opening inspection pause), so sub-tick debt is 0 and alpha is 0 |
| Crowd mesh | `res://assets/units/species_mouse_body_a_lod0.glb` — the **authored GLB**, not the fallback box. The boot log prints which, and `test_the_authored_crowd_mesh_is_the_one_that_ships` fails if it is ever the box |
| Headless suite at capture time | `3959 test(s), 135031 assertion(s), 0 failure(s)` |
| Mutation testing | 15 mutations, **one Godot invocation each**, restored and SHA-256 byte-compared after every run. 15 killed, 0 survivors |

## The exact command

`save_png` needs an **absolute** path; a `res://` or relative path silently fails with a non-zero
error code and no file. The harness below prints that code, so a failed write cannot be mistaken
for a successful one.

```bash
# 1920x1080, the committed camera
godot --path godot --script capture_residents_scratch.gd --resolution 1920x1080 \
  -- /abs/path/01_cohort_wide_1920x1080.png 45

# the same boot, with the camera overridden to orthographic size 4 for the close-up
godot --path godot --script capture_residents_scratch.gd --resolution 1920x1080 \
  -- /abs/path/02_cohort_closeup_1920x1080.png 45 4

# 1280x720
godot --path godot --script capture_residents_scratch.gd --resolution 1280x720 \
  -- /abs/path/03_cohort_standard_1280x720.png 45

# the before capture, from a worktree detached at 914444b
godot --path godot --script capture_before_scratch.gd --resolution 1920x1080 \
  -- /abs/path/before_01_empty_entities_1920x1080.png 45
```

`capture_residents_scratch.gd` is a scratch file and is **deleted before the commit**, so it is
reproduced in full here. It instantiates the project's own main scene and touches nothing else;
the only override is the close-up camera, which is applied only when a third argument is given.

```gdscript
extends SceneTree

var _main: Node = null
var _frames: int = 0
var _wait: int = 45
var _out: String = ""
var _zoom: float = 0.0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0]
	if args.size() > 1:
		_wait = int(args[1])
	if args.size() > 2:
		_zoom = float(args[2])
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	_main = packed.instantiate()
	root.add_child(_main)
	if _zoom > 0.0:
		var cam: Camera3D = _main.get_node("World/Camera3D") as Camera3D
		cam.size = _zoom
		cam.position = Vector3(117.0, 3.5, 142.5)


func _process(_delta: float) -> bool:
	_frames += 1
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


func _report() -> void:
	var stage: Node = _main.get_node_or_null("World/Entities/ResidentStage")
	if stage == null:
		printerr("REPORT: no ResidentStage")
		return
	var crowd: MultiMeshInstance3D = stage.get_node_or_null("ResidentCrowd")
	print("REPORT: attached=%s mesh=%s drawn=%d visible=%d skipped=%d" % [
		stage.is_attached(), stage.mesh_source(), crowd.drawn_count(),
		crowd.visible_instance_count(), crowd.skipped_unplaced_count()])
	var settlement: Node = root.get_node_or_null("/root/SettlementSystem")
	print("REPORT: residents living=%d population=%d" % [
		settlement.living_count(), settlement.population()])
	for i: int in 3:
		print("REPORT: instance %d origin %s" % [i, crowd.instance_origin(i)])
	print("REPORT: aabb=%s" % crowd.get_aabb())
	print("REPORT: window=%s" % DisplayServer.window_get_size())
```

`capture_before_scratch.gd` is the same file with `_report()` replaced by a single print, because
no `ResidentStage` exists at `914444b`.

## What the harness printed

Verbatim, from the 1920×1080 run:

```
[Main] resident crowd attached: mesh species_mouse_body_a_lod0.glb
[Main] boot complete: PAUSED  food-days 5.48  ready 408000 NP  fuel-days --
REPORT: attached=true mesh=species_mouse_body_a_lod0.glb drawn=12 visible=12 skipped=0
REPORT: residents living=12 population=12
REPORT: instance 0 origin (117.0, 0.5, 139.0)
REPORT: instance 1 origin (119.0, 0.5, 139.0)
REPORT: instance 2 origin (121.0, 0.5, 139.0)
REPORT: aabb=[P: (-0.427271, 0.0, -0.204294), S: (139.8546, 1.5, 139.4086)]
REPORT: window=(1920, 1080)
CAPTURE: .../01_cohort_wide_1920x1080.png -> 0 (1920x1080)
```

Those coordinates are checkable by hand. GDD §5.9 places the refuge hall at tile (58,59) with a
12×10 extent, so the first apron row south of it is z=69; GDD §5.1 puts a tile centre at
`2048*t+1024` simulation units with 1024 units to the metre, and land at y=512. Tile (58,69) is
therefore `(2048*58+1024)/1024 = 117.0 m` by `(2048*69+1024)/1024 = 139.0 m` at `512/1024 = 0.5 m`,
and each neighbour is one 2 m tile along. `drawn=12` and `visible=12` are §5.1's twelve residents,
and `skipped=0` means none of them was drawn from an unplaced pose.

## The captures

| # | File | Window | Shows |
| --- | --- | --- | --- |
| — | `before/before_01_empty_entities_1920x1080.png` | 1920×1080 | **Before**, at `914444b`: the HUD over an empty ground plane. `World/Entities` has no children and nothing is drawn in 3D |
| 01 | `screenshots/01_cohort_wide_1920x1080.png` | 1920×1080 | **After**: GDD §5.1's twelve residents, one `MultiMesh` instance each, standing on §5.9's hall apron in the committed camera framing |
| 02 | `screenshots/02_cohort_closeup_1920x1080.png` | 1920×1080 | The same boot with the camera overridden to orthographic size 4, for anatomy, scale and **facing** inspection |
| 03 | `screenshots/03_cohort_standard_1280x720.png` | 1280×720 | The same twelve in the smaller window |

## Read these captures honestly

Four things are visible in them and none is a defect in the render path, but none should be
mistaken for finished work either.

1. **The mice are probably facing backwards, and a human has to decide.** The renderer applies
   **no rotation at all** — `transforms.gd` records the yaw zero reference and handedness as
   MOVE-G01/G04 blockers, so deriving a basis from yaw would be inventing the convention. In
   capture 02 the model faces the camera, which sits on the **+Z** side of the cohort looking
   toward −Z. This project's stated convention is **−Z forward** while glTF conventionally puts
   the front at +Z, so the asset most likely arrived front-to-back. No automated check can settle
   this; it needs an eye.
2. **They are untextured white, in the bind pose.** No material, lighting or animation work was in
   scope, and the crowd tier draws the mesh as imported. The arms-out silhouette is the model's
   rest pose, not a wrong transform: the GLB's own AABB is 0.855 × 1.000 × 0.409 m, i.e. wide
   because the arms are out, and exactly 1.000 m tall — crowd doc §9.1's mouse scale anchor.
3. **They are standing still, deliberately.** Nothing in this repository may decide that a
   resident walks. `place()` writes previous = current, so interpolation draws a standing resident
   exactly where it stands. The interpolation itself is proven in `test_resident_crowd.gd`, which
   pins four alphas between two committed poses; it cannot be proven by a still frame.
4. **The HUD still reads `Residents --` and `No world generated`.** That is the UI lane's
   binding, unchanged by this work and present in the before capture too.

Design, blockers and what a later lane inherits:
[decision 0130](../../../decisions/0130-the-resident-render-path-is-a-multimesh-over-a-borrowed-pose-store.md).

**No performance claim is made.** Task 10.4's qualification needs measurement that was not taken.
