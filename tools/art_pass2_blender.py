"""Blender half of tools/make_art_pass2.py's `post` steps (decision 0951). Headless; free; nothing wired in:

	blender --background --factory-startup --python tools/art_pass2_blender.py -- <job.json>

A job is {"step": ..., "library": <assets/library>, "out": <godot/demo/assets>}. Steps:

  hall_stage2  The stone hall's L0 (Meshy faces it down glTF +Z, long side across) turned +90 degrees about Y so
               its door gable faces +X like the timber hall's, scaled so its length along X equals the timber
               hall L0's, and centred on that L0's own X/Z centre with its bottom at y = 0. Drawn with the
               timber hall's scale (6.0686, 7.0 m / 1.1535) it covers the same footprint.
  hall_banner  The banner's L0 split into two surfaces by its baked albedo: 0 `banner_cloth` (the pale linen,
               to be dyed) and 1 `banner_wood` (the crossbar and cord, never dyed).
  pine_tint    The pine's teal needles turned pine green (the season system's leaf test needs green >= blue)
               and its orange bark calmed a little.
  wildlife     The wildlife bodies (songbird perched and on the wing, butterfly, frog, fish) at their approved game
               scale (metres), each with an authored armature and clips (Meshy's rig is a 24-joint humanoid and cannot take a bird, a butterfly, a frog
               or a fish: decision 0951). Origin: the feet (perched bird, frog), the body's centre (flying bird,
               butterfly, fish).
  windows      For each lit building's L0 (hall, hall_stage2, residence, kitchen), a window GLOW MASK in its UV0 space: the
               dark, cool glass texels of its own albedo that lie under a WALL face's UVs (within WALL_UP of
               vertical) and under no roof's -- rasterised from the UVs, since Meshy's atlas packs slate and glass
               alike -- and a copy of the L0 carrying that mask as glTF emissiveTexture.
  oak_bare     The mature oak's BARE BOUGHS, authored once instead of cut at runtime: decision 0551's own
               bark test, then its stray islands and slivers removed, and its leaf texels filled with bark so
               no shader discard leaves jagged holes. Its own albedo; one surface.

A job with "kind": "prop" is instead demo_props_blender.py's own prop job, run with a tight unwrap (TIGHT_MARGIN):
make_art_pass2.py sends the tree and building keys here.

Coordinates in comments are glTF's (Y up, +Z front); Blender's are (x, -z, y). Prints "RESULT <json>".
"""

import json
import math
import os
import shutil
import sys
import time

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

## Game sizes (metres) for the wildlife, against the 1.00 m mouse: Brendan's ruling, 2026-10-02 (decision 0951).
## The dimension each is fitted by: the bird's and frog's and fish's length (glTF Z), the butterfly's span (X).
WILD_SIZE = {"wild_songbird": ("length", 0.45), "wild_songbird_flight": ("length", 0.45), "wild_butterfly": ("span", 0.36), "wild_frog": ("length", 0.40),
	"wild_trout_leaping": ("length", 0.80)}
FPS = 30
## A wall face is one whose normal is within this of horizontal (|up| below it).
WALL_UP = 0.35
## A window texel (the albedo's stored sRGB values, as Blender's image.pixels gives an 8-bit PNG's): darker than
## GLASS_MAX at its brightest channel (0.44 sRGB is ~0.16 linear), and not warm (blue at least GLASS_COOL of red)
## -- slate is excluded by the wall test, timber by the warmth test.
GLASS_MAX = 0.44
GLASS_COOL = 0.92
MASK_PX = 1024
EAVES_PERCENTILE = 5
PLINTH_SHARE = 0.1
## The mask is CLOSED by this many texels (the lead cames between panes fill), then OPENED by as many again
## (mortar lines between dark stones go, a window stays), then grown by one and feathered.
OPEN_PX = 2
LIT = ["hall", "hall_stage2", "residence", "kitchen"]
## The warm lamp colour the mask is multiplied by (glTF emissiveFactor): I11 Ember, ART-LOCK-001.
EMBER = [0.851, 0.592, 0.263]
## bare_boughs.gd's constants (decision 0551), copied so this file's cut is the runtime's.
LEAF_RATIO = 1.2
SAMPLE_PX = 512
ROOTS_SHARE = 0.12
## The oak's cleaned cut: a texel is leaf from the shader's ramp START (CUT_RATIO, season_leaves.gdshaderinc's
## 1.08), not bare_boughs' midpoint 1.2 -- the yellow-green leaf texels between the two are what the runtime cut
## keeps and the shader then half-discards, leaving the shards. A triangle goes when half its sampled texels are
## leaf; then any island under ISLAND_SHARE of the kept area goes, and any triangle thinner than SLIVER (inradius
## over longest edge). Every texel at or over CUT_RATIO is then filled with bark, so the shader discards nothing.
CUT_RATIO = 1.08
ISLAND_SHARE = 0.02
SLIVER = 0.035


def log(message):
	"""Progress to stdout."""
	print(f"art_pass2: {message}", flush=True)


def load(path):
	"""Import a GLB into an empty scene; join its meshes; apply transforms; return the object."""
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=path)
	meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
	bpy.ops.object.select_all(action="DESELECT")
	for obj in meshes:
		obj.select_set(True)
	bpy.context.view_layer.objects.active = meshes[0]
	if len(meshes) > 1:
		bpy.ops.object.join()
	obj = bpy.context.view_layer.objects.active
	obj.parent = None
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	for other in [o for o in bpy.context.scene.objects if o != obj]:
		bpy.data.objects.remove(other)
	return obj


def co_array(obj):
	"""Vertex positions (Blender xyz), (n, 3)."""
	co = np.empty(len(obj.data.vertices) * 3, dtype=np.float64)
	obj.data.vertices.foreach_get("co", co)
	return co.reshape(-1, 3)


def set_co(obj, co):
	"""Write vertex positions back."""
	obj.data.vertices.foreach_set("co", co.astype(np.float32).ravel())
	obj.data.update()


def gltf_bounds(obj):
	"""glTF-space (min, max) of the object's vertices."""
	co = co_array(obj)
	return ([float(co[:, 0].min()), float(co[:, 2].min()), float(-co[:, 1].max())],
		[float(co[:, 0].max()), float(co[:, 2].max()), float(-co[:, 1].min())])


def accessor_bounds(path):
	"""glTF POSITION bounds of a GLB's first primitive, read from its JSON chunk."""
	with open(path, "rb") as handle:
		handle.read(12)
		length = int.from_bytes(handle.read(4), "little")
		handle.read(4)
		gltf = json.loads(handle.read(length))
	accessor = gltf["accessors"][gltf["meshes"][0]["primitives"][0]["attributes"]["POSITION"]]
	return accessor["min"], accessor["max"]


def export(objects, path, animations=False):
	"""Export the given objects as a Y-up GLB."""
	bpy.ops.object.select_all(action="DESELECT")
	for obj in objects:
		obj.select_set(True)
	options = {"filepath": path, "export_format": "GLB", "use_selection": True, "export_yup": True,
		"export_apply": not animations, "export_animations": animations}
	if animations:
		options["export_animation_mode"] = "NLA_TRACKS"
		options["export_frame_range"] = False
	bpy.ops.export_scene.gltf(**options)
	return os.path.getsize(path)


def base_image(material):
	"""The image wired into a material's Base Color."""
	bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	link = bsdf.inputs["Base Color"].links[0]
	node = link.from_node
	while node.type != "TEX_IMAGE":
		node = node.inputs[0].links[0].from_node
	return node.image


def pixels_of(image, size=None):
	"""An image's linear RGBA as a float array (h, w, 4), optionally resampled to size x size."""
	if size is not None and tuple(image.size) != (size, size):
		image = image.copy()
		image.scale(size, size)
	w, h = image.size
	buf = np.empty(w * h * 4, dtype=np.float32)
	image.pixels.foreach_get(buf)
	return buf.reshape(h, w, 4)


def sample(pixels, uv):
	"""Nearest texels at UVs (n, 2), wrapped."""
	h, w, _ = pixels.shape
	at = uv % 1.0
	return pixels[(at[:, 1] * (h - 1)).astype(int), (at[:, 0] * (w - 1)).astype(int)]


def loop_uvs(obj):
	"""Per-loop UVs (n_loops, 2) of the active layer."""
	mesh = obj.data
	uv = np.empty(len(mesh.loops) * 2, dtype=np.float32)
	mesh.uv_layers.active.data.foreach_get("uv", uv)
	return uv.reshape(-1, 2)


def triangles_of(obj):
	"""(n, 3) loop indices of a triangulated mesh, and (n, 3) vertex indices."""
	mesh = obj.data
	starts = np.empty(len(mesh.polygons), dtype=np.int32)
	mesh.polygons.foreach_get("loop_start", starts)
	loops = starts[:, None] + np.arange(3)[None, :]
	verts = np.empty(len(mesh.loops), dtype=np.int32)
	mesh.loops.foreach_get("vertex_index", verts)
	return loops, verts[loops]


def triangulate(obj):
	"""Make every face a triangle."""
	bm = bmesh.new()
	bm.from_mesh(obj.data)
	bmesh.ops.triangulate(bm, faces=bm.faces[:])
	bm.to_mesh(obj.data)
	bm.free()


def keep_faces(obj, keep):
	"""Delete every face not flagged in `keep`, and loose vertices."""
	bm = bmesh.new()
	bm.from_mesh(obj.data)
	bm.faces.ensure_lookup_table()
	doomed = [f for f, k in zip(bm.faces, keep) if not k]
	bmesh.ops.delete(bm, geom=doomed, context="FACES")
	loose = [v for v in bm.verts if not v.link_faces]
	bmesh.ops.delete(bm, geom=loose, context="VERTS")
	bm.to_mesh(obj.data)
	bm.free()


# --- hall stage 2 ------------------------------------------------------------------------------

def step_hall_stage2(lib, out):
	"""Turn, fit and centre the stone hall on the timber hall's L0."""
	obj = load(os.path.join(lib, "building/hall_stage2/l0_raw.glb"))
	obj.data.transform(Matrix.Rotation(math.radians(90.0), 4, "Z"))
	hall_lo, hall_hi = accessor_bounds(os.path.join(lib, "building/hall/l0.glb"))
	lo, hi = gltf_bounds(obj)
	scale = (hall_hi[0] - hall_lo[0]) / (hi[0] - lo[0])
	co = co_array(obj) * scale
	set_co(obj, co)
	lo, hi = gltf_bounds(obj)
	centre_x = (hall_lo[0] + hall_hi[0]) / 2 - (lo[0] + hi[0]) / 2
	centre_z = (hall_lo[2] + hall_hi[2]) / 2 - (lo[2] + hi[2]) / 2
	co = co_array(obj)
	co[:, 0] += centre_x
	co[:, 1] -= centre_z
	co[:, 2] -= co[:, 2].min()
	set_co(obj, co)
	path = os.path.join(lib, "building/hall_stage2/l0.glb")
	export([obj], path)
	shutil.copy2(path, os.path.join(out, "world/hall_stage2.glb"))
	lo, hi = gltf_bounds(obj)
	return {"glb": path, "scale_to_hall": round(scale, 5), "aabb_min": [round(v, 4) for v in lo],
		"aabb_max": [round(v, 4) for v in hi], "hall_aabb": [hall_lo, hall_hi],
		"drawn_height_m_at_hall_scale": round(hi[1] * 7.0 / hall_hi[1], 3)}


# --- banner --------------------------------------------------------------------------------------

def step_hall_banner(lib, out):
	"""Split the banner into its dyeable cloth (surface 0) and its wood (surface 1)."""
	obj = load(os.path.join(lib, "prop/hall_banner/l0_raw.glb"))
	triangulate(obj)
	cloth = obj.data.materials[0]
	cloth.name = "banner_cloth"
	wood = cloth.copy()
	wood.name = "banner_wood"
	obj.data.materials.append(wood)
	pixels = pixels_of(base_image(cloth))
	loops, _ = triangles_of(obj)
	uv = loop_uvs(obj)
	rgb = np.mean([sample(pixels, uv[loops[:, k]])[:, :3] for k in range(3)], axis=0)
	luma = rgb @ np.array([0.2126, 0.7152, 0.0722])
	warmth = rgb[:, 0] - rgb[:, 2]
	is_wood = (luma < 0.30) | ((warmth > 0.12) & (luma < 0.45))
	index = is_wood.astype(np.int32)
	obj.data.polygons.foreach_set("material_index", index)
	obj.data.update()
	path = os.path.join(lib, "prop/hall_banner/l0.glb")
	export([obj], path)
	shutil.copy2(path, os.path.join(out, "props/hall_banner.glb"))
	lo, hi = gltf_bounds(obj)
	return {"glb": path, "cloth_triangles": int((index == 0).sum()), "wood_triangles": int(index.sum()),
		"aabb_min": [round(v, 4) for v in lo], "aabb_max": [round(v, 4) for v in hi]}


# --- pine tint ---------------------------------------------------------------------------------

## Meshy painted the pine's needles teal: blue above green in 86% of its crown's texels, so decision 0551's leaf
## test (green over red at 1.08-1.35, AND green at least blue) reads them as bark, and the canopy fade would
## miss them. Each texel whose blue tops its green is turned to pine green (green and blue swapped, then the blue
## held under NEEDLE_BLUE of the green); the orange bark is pulled BARK_CALM of the way to its own grey.
NEEDLE_BLUE = 0.8
BARK_CALM = 0.3


def step_pine_tint(lib, out):
	"""The pine's L0 with its needles green enough for the season system's leaf test."""
	obj = load(os.path.join(lib, "environment/pine_scots/l0_raw.glb"))
	image = base_image(obj.data.materials[0])
	px = pixels_of(image)
	rgb = px[:, :, :3].copy()
	teal = rgb[:, :, 2] > rgb[:, :, 1]
	g, b = rgb[:, :, 1].copy(), rgb[:, :, 2].copy()
	rgb[teal, 1] = b[teal]
	rgb[teal, 2] = np.minimum(g[teal], b[teal] * NEEDLE_BLUE)
	orange = (rgb[:, :, 0] > rgb[:, :, 1] * 1.3) & ~teal
	grey = rgb.mean(axis=2, keepdims=True)
	rgb[orange] = rgb[orange] * (1 - BARK_CALM) + grey[orange] * BARK_CALM
	px[:, :, :3] = rgb
	image.pixels.foreach_set(px.astype(np.float32).ravel())
	image.pack()
	leaf = (rgb[:, :, 1] >= rgb[:, :, 0] * 1.08) & (rgb[:, :, 1] >= rgb[:, :, 2])
	path = os.path.join(lib, "environment/pine_scots/l0.glb")
	export([obj], path)
	shutil.copy2(path, os.path.join(out, "world/pine_scots.glb"))
	return {"glb": path, "teal_texels_turned": int(teal.sum()), "orange_texels_calmed": int(orange.sum()),
		"leaf_texel_share_after": round(float(leaf.mean()), 4)}


# --- wildlife ----------------------------------------------------------------------------------

def smooth(values, lo, hi):
	"""0 below lo, 1 above hi, smoothstep between (works either way round)."""
	t = np.clip((values - lo) / (hi - lo), 0.0, 1.0)
	return t * t * (3 - 2 * t)


def fit_size(obj, key):
	"""Scale to the approved size; return (length along glTF Z, span X, height Y) after."""
	co = co_array(obj)
	extent = co.max(axis=0) - co.min(axis=0)
	axis, metres = WILD_SIZE[key]
	scale = metres / (extent[1] if axis == "length" else extent[0])
	co *= scale
	return co, scale


def rig(obj, bones, weights):
	"""An armature with `bones` {name: (head, tail, parent)} (Blender xyz) skinning `obj` by `weights`
	{bone: per-vertex weight array}."""
	data = bpy.data.armatures.new("rig")
	arm = bpy.data.objects.new("rig", data)
	bpy.context.scene.collection.objects.link(arm)
	bpy.context.view_layer.objects.active = arm
	bpy.ops.object.mode_set(mode="EDIT")
	for name, (head, tail, parent) in bones.items():
		bone = data.edit_bones.new(name)
		bone.head, bone.tail = Vector(head), Vector(tail)
		if parent:
			bone.parent = data.edit_bones[parent]
	bpy.ops.object.mode_set(mode="OBJECT")
	total = sum(weights.values())
	for name, w in weights.items():
		group = obj.vertex_groups.new(name=name)
		share = w / np.maximum(total, 1e-6)
		for i in np.nonzero(share > 0.001)[0]:
			group.add([int(i)], float(share[i]), "REPLACE")
	obj.parent = arm
	modifier = obj.modifiers.new("skin", "ARMATURE")
	modifier.object = arm
	return arm


def clip(arm, name, frames, keys):
	"""One action on `arm`: keys is {frame: {bone: {"loc"|"rot"|"scale": (x, y, z)}}}; pushed to its own NLA
	track so the exporter writes it as an animation named `name`."""
	arm.animation_data_create()
	action = bpy.data.actions.new(name)
	arm.animation_data.action = action
	for frame, poses in sorted(keys.items()):
		for bone, channels in poses.items():
			pb = arm.pose.bones[bone]
			pb.rotation_mode = "XYZ"
			for channel, value in channels.items():
				if channel == "loc":
					pb.location = value
					pb.keyframe_insert("location", frame=frame)
				elif channel == "rot":
					pb.rotation_euler = [math.radians(v) for v in value]
					pb.keyframe_insert("rotation_euler", frame=frame)
				else:
					pb.scale = value
					pb.keyframe_insert("scale", frame=frame)
	track = arm.animation_data.nla_tracks.new()
	track.name = name
	strip = track.strips.new(name, 1, action)
	strip.name = name
	arm.animation_data.action = None
	for pb in arm.pose.bones:
		pb.location, pb.rotation_euler, pb.scale = (0, 0, 0), (0, 0, 0), (1, 1, 1)
	return {"name": name, "frames": frames, "seconds": round((frames - 1) / FPS, 3)}


def songbird(obj, co):
	"""Root, body, head, tail; idle, hop (in place), peck."""
	L = co[:, 1].max() - co[:, 1].min()
	H = co[:, 2].max()
	front, back = co[:, 1].min(), co[:, 1].max()
	head_w = smooth(-co[:, 1], -(front + 0.30 * L), -(front + 0.18 * L)) * smooth(co[:, 2], 0.45 * H, 0.6 * H)
	tail_w = smooth(co[:, 1], back - 0.38 * L, back - 0.25 * L)
	legs_w = smooth(-co[:, 2], -0.28 * H, -0.18 * H)
	body_w = np.clip(1.0 - head_w - tail_w - legs_w, 0.0, 1.0)
	## The root lies along the body, pointing forward, so its local Z is world up: a hop's lift is (0, 0, h).
	bones = {"root": ((0, 0, 0), (0, -0.15 * L, 0), None),
		"body": ((0, 0, 0.3 * H), (0, 0, 0.6 * H), "root"),
		"head": ((0, front + 0.3 * L, 0.6 * H), (0, front + 0.3 * L, 0.9 * H), "body"),
		"tail": ((0, back - 0.3 * L, 0.5 * H), (0, back, 0.6 * H), "body")}
	arm = rig(obj, bones, {"root": legs_w, "body": body_w, "head": head_w, "tail": tail_w})
	clips = [clip(arm, "idle", 61, {1: {"body": {"scale": (1, 1, 1)}, "head": {"rot": (0, 0, 0)}},
			16: {"head": {"rot": (0, 0, 28)}}, 22: {"body": {"scale": (1.025, 1.025, 1.025)}},
			31: {"head": {"rot": (0, 0, 28)}}, 40: {"head": {"rot": (0, 0, -22)}}, 44: {"body": {"scale": (1, 1, 1)}},
			52: {"head": {"rot": (0, 0, -22)}}, 61: {"head": {"rot": (0, 0, 0)}, "body": {"scale": (1, 1, 1)}}}),
		clip(arm, "hop", 16, {1: {"root": {"loc": (0, 0, 0)}, "body": {"rot": (0, 0, 0)}, "tail": {"rot": (0, 0, 0)}},
			4: {"root": {"loc": (0, 0, 0)}, "body": {"rot": (-10, 0, 0)}},
			8: {"root": {"loc": (0, 0, 0.12 * H + 0.04)}, "tail": {"rot": (18, 0, 0)}},
			13: {"root": {"loc": (0, 0, 0)}, "body": {"rot": (6, 0, 0)}, "tail": {"rot": (-6, 0, 0)}},
			16: {"root": {"loc": (0, 0, 0)}, "body": {"rot": (0, 0, 0)}, "tail": {"rot": (0, 0, 0)}}}),
		clip(arm, "peck", 31, {1: {"body": {"rot": (0, 0, 0)}, "head": {"rot": (0, 0, 0)}, "tail": {"rot": (0, 0, 0)}},
			9: {"body": {"rot": (22, 0, 0)}, "head": {"rot": (40, 0, 0)}, "tail": {"rot": (-15, 0, 0)}},
			12: {"head": {"rot": (52, 0, 0)}}, 15: {"head": {"rot": (38, 0, 0)}},
			23: {"body": {"rot": (0, 0, 0)}, "head": {"rot": (0, 0, 0)}, "tail": {"rot": (0, 0, 0)}},
			31: {"body": {"rot": (0, 0, 0)}, "head": {"rot": (0, 0, 0)}, "tail": {"rot": (0, 0, 0)}}})]
	return arm, clips


def butterfly(obj, co):
	"""Root (body) and two wings hinged on the body's axis; flap (flying), rest (perched, slow)."""
	span = co[:, 0].max() - co[:, 0].min()
	core = 0.06 * span
	left = smooth(-co[:, 0], core, 2.2 * core)
	right = smooth(co[:, 0], core, 2.2 * core)
	body = np.clip(1.0 - left - right, 0.0, 1.0)
	z = float(np.median(co[np.abs(co[:, 0]) < core, 2]))
	front, back = co[:, 1].min(), co[:, 1].max()
	bones = {"root": ((0, back, z), (0, front, z), None),
		"wing_l": ((0, 0, z), (-0.5 * span, 0, z), "root"), "wing_r": ((0, 0, z), (0.5 * span, 0, z), "root")}
	arm = rig(obj, bones, {"root": body, "wing_l": left, "wing_r": right})
	## A wing bone points out along X; with no roll its local X lies along the body axis (Blender Y), so a flap is a
	## rotation about local X -- and +a lifts BOTH tips (worked through for +X and -X bones alike).
	flap = {1: 0, 4: 58, 7: 0, 9: -30, 11: 0}
	keys = {f: {"wing_l": {"rot": (a, 0, 0)}, "wing_r": {"rot": (a, 0, 0)}, "root": {"loc": (0, 0, 0.02 * (f == 4))}}
		for f, a in flap.items()}
	rest = {1: 0, 30: 35, 45: 35, 75: 0, 91: 0}
	rest_keys = {f: {"wing_l": {"rot": (a, 0, 0)}, "wing_r": {"rot": (a, 0, 0)}} for f, a in rest.items()}
	return arm, [clip(arm, "flap", 11, keys), clip(arm, "rest", 91, rest_keys)]


def songbird_flight(obj, co):
	"""The robin on the wing: root (body), wings hinged at the shoulders, tail; flap (loop), glide (loop)."""
	span = co[:, 0].max() - co[:, 0].min()
	front, back = co[:, 1].min(), co[:, 1].max()
	L = back - front
	core = 0.14 * span
	left = smooth(-co[:, 0], core, 1.8 * core)
	right = smooth(co[:, 0], core, 1.8 * core)
	tail = smooth(co[:, 1], back - 0.35 * L, back - 0.2 * L) * (1 - left - right).clip(0, 1)
	body = np.clip(1.0 - left - right - tail, 0.0, 1.0)
	z = float(np.median(co[np.abs(co[:, 0]) < core, 2]))
	bones = {"root": ((0, 0, z), (0, -0.2 * L, z), None),
		"wing_l": ((-core, 0, z), (-0.5 * span, 0, z), "root"), "wing_r": ((core, 0, z), (0.5 * span, 0, z), "root"),
		"tail": ((0, back - 0.3 * L, z), (0, back, z), "root")}
	arm = rig(obj, bones, {"root": body, "wing_l": left, "wing_r": right, "tail": tail})
	flap = {1: 0, 3: 50, 5: 0, 6: -35, 7: 0}
	flap_keys = {f: {"wing_l": {"rot": (a, 0, 0)}, "wing_r": {"rot": (a, 0, 0)},
		"root": {"loc": (0, 0, -0.015 * a / 50)}} for f, a in flap.items()}
	glide = {1: 6, 16: -4, 31: 6}
	glide_keys = {f: {"wing_l": {"rot": (a, 0, 0)}, "wing_r": {"rot": (a, 0, 0)}, "tail": {"rot": (a * 0.5, 0, 0)}}
		for f, a in glide.items()}
	return arm, [clip(arm, "flap", 7, flap_keys), clip(arm, "glide", 31, glide_keys)]


def frog(obj, co):
	"""Root, body (hips pivot), head; idle (throat breathing), hop (in place, stretch and land)."""
	L = co[:, 1].max() - co[:, 1].min()
	H = co[:, 2].max()
	front, back = co[:, 1].min(), co[:, 1].max()
	head_w = smooth(-co[:, 1], -(front + 0.42 * L), -(front + 0.28 * L)) * smooth(co[:, 2], 0.30 * H, 0.45 * H)
	feet_w = smooth(-co[:, 2], -0.14 * H, -0.06 * H)
	body_w = np.clip(1.0 - head_w - feet_w, 0.0, 1.0)
	hips = back - 0.25 * L
	bones = {"root": ((0, 0, 0), (0, -0.15 * L, 0), None),
		"body": ((0, hips, 0.25 * H), (0, front + 0.4 * L, 0.55 * H), "root"),
		"head": ((0, front + 0.35 * L, 0.5 * H), (0, front, 0.7 * H), "body")}
	arm = rig(obj, bones, {"root": feet_w, "body": body_w, "head": head_w})
	idle = {1: 1.0, 10: 1.04, 20: 1.0, 30: 1.04, 40: 1.0, 61: 1.0}
	idle_keys = {f: {"body": {"scale": (s, 1, s)}} for f, s in idle.items()}
	idle_keys[1]["head"] = {"rot": (0, 0, 0)}
	idle_keys[35] = {"head": {"rot": (-6, 0, 0)}}
	idle_keys[61]["head"] = {"rot": (0, 0, 0)}
	hop = {1: {"root": {"loc": (0, 0, 0)}, "body": {"rot": (0, 0, 0), "scale": (1, 1, 1)}},
		5: {"root": {"loc": (0, 0, 0)}, "body": {"rot": (8, 0, 0), "scale": (1.04, 0.94, 1.04)}},
		9: {"root": {"loc": (0, 0, 0.55 * H)}, "body": {"rot": (-24, 0, 0), "scale": (0.96, 1.18, 0.96)}},
		13: {"root": {"loc": (0, 0, 0.62 * H)}, "body": {"rot": (6, 0, 0), "scale": (1, 1.05, 1)}},
		17: {"root": {"loc": (0, 0, 0)}, "body": {"rot": (12, 0, 0), "scale": (1.06, 0.92, 1.06)}},
		22: {"root": {"loc": (0, 0, 0)}, "body": {"rot": (0, 0, 0), "scale": (1, 1, 1)}}}
	return arm, [clip(arm, "idle", 61, idle_keys), clip(arm, "hop", 22, hop)]


def trout(obj, co):
	"""A four-bone spine from the head (front) to the tail; swim (in place), leap (travelling, root motion)."""
	front, back = co[:, 1].min(), co[:, 1].max()
	L = back - front
	cuts = [front + L * f for f in (0.0, 0.3, 0.55, 0.78, 1.0)]
	names = ["root", "spine_1", "spine_2", "tail"]
	weights = {}
	for k, name in enumerate(names):
		lo, hi = cuts[k], cuts[k + 1]
		pad = 0.08 * L
		w = smooth(co[:, 1], lo - pad, lo + pad) * (1 - smooth(co[:, 1], hi - pad, hi + pad))
		if k == 0:
			w = 1 - smooth(co[:, 1], hi - pad, hi + pad)
		if k == len(names) - 1:
			w = smooth(co[:, 1], lo - pad, lo + pad)
		weights[name] = w
	bones = {}
	for k, name in enumerate(names):
		bones[name] = ((0, cuts[k], 0), (0, cuts[k + 1], 0), names[k - 1] if k else None)
	arm = rig(obj, bones, weights)
	swim = {}
	for f in range(1, 32, 3):
		phase = 2 * math.pi * (f - 1) / 30
		swim[f] = {name: {"rot": (0, 0, amp * math.sin(phase - k * 0.9))}
			for k, (name, amp) in enumerate(zip(names, (3, 8, 14, 22)))}
	leap = {}
	for f in range(1, 44, 3):
		t = (f - 1) / 42
		height = 0.75 * 4 * t * (1 - t) - 0.25
		pitch = -55 * (1 - 2 * t)
		bend = 18 * math.sin(math.pi * t)
		leap[f] = {"root": {"loc": (0, -1.2 * t, height), "rot": (pitch, 0, 0)},
			"spine_1": {"rot": (-bend * 0.4, 0, 6 * math.sin(6 * t))},
			"spine_2": {"rot": (-bend * 0.6, 0, 10 * math.sin(6 * t + 1))},
			"tail": {"rot": (-bend, 0, 16 * math.sin(6 * t + 2))}}
	return arm, [clip(arm, "swim", 31, swim), clip(arm, "leap", 43, leap)]


def step_wildlife(lib, out):
	"""Every wildlife key: fit, centre, rig, clips, export with its animations."""
	rows = {}
	makers = {"wild_songbird": songbird, "wild_songbird_flight": songbird_flight, "wild_butterfly": butterfly, "wild_frog": frog, "wild_trout_leaping": trout}
	os.makedirs(os.path.join(out, "wildlife"), exist_ok=True)
	for key, maker in makers.items():
		obj = load(os.path.join(lib, "wildlife", key, "l0.glb"))
		co, scale = fit_size(obj, key)
		co[:, 0] -= (co[:, 0].min() + co[:, 0].max()) / 2
		co[:, 1] -= (co[:, 1].min() + co[:, 1].max()) / 2
		centred = key in ("wild_butterfly", "wild_trout_leaping", "wild_songbird_flight")
		co[:, 2] -= (co[:, 2].min() + co[:, 2].max()) / 2 if centred else co[:, 2].min()
		set_co(obj, co)
		obj.name = key
		arm, clips = maker(obj, co)
		bpy.context.scene.render.fps = FPS
		path = os.path.join(lib, "wildlife", key, "animated.glb")
		size = export([obj, arm], path, animations=True)
		shutil.copy2(path, os.path.join(out, "wildlife", f"{key}.glb"))
		lo, hi = gltf_bounds(obj)
		rows[key] = {"glb": path, "bytes": size, "scale_from_l0": round(scale, 5), "fitted": WILD_SIZE[key],
			"origin": "body centre" if centred else "feet", "aabb_min": [round(v, 4) for v in lo],
			"aabb_max": [round(v, 4) for v in hi], "clips": clips, "bones": [b.name for b in arm.data.bones]}
	return rows


# --- windows -------------------------------------------------------------------------------------

def rasterise(tri_uv, px):
	"""A px x px boolean coverage of UV triangles (n, 3, 2): each triangle's texels by barycentric test."""
	cover = np.zeros((px, px), dtype=bool)
	pts = tri_uv * (px - 1)
	for t in pts:
		x0, y0 = np.floor(t.min(axis=0)).astype(int)
		x1, y1 = np.ceil(t.max(axis=0)).astype(int)
		x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, px - 1), min(y1, px - 1)
		if x1 < x0 or y1 < y0:
			continue
		gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
		(ax, ay), (bx, by), (cx, cy) = t
		det = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
		if abs(det) < 1e-12:
			continue
		l1 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / det
		l2 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / det
		inside = (l1 >= -0.02) & (l2 >= -0.02) & (1 - l1 - l2 >= -0.02)
		cover[y0:y1 + 1, x0:x1 + 1] |= inside
	return cover


def window_mask(obj):
	"""Glass texels (dark, not warm) that lie under a wall face's UVs and under no roof or floor face's."""
	triangulate(obj)
	loops, _ = triangles_of(obj)
	tri_uv = loop_uvs(obj)[loops] % 1.0
	normals = np.empty(len(obj.data.polygons) * 3)
	obj.data.polygons.foreach_get("normal", normals)
	up = np.abs(normals.reshape(-1, 3)[:, 2])
	centres = np.empty(len(obj.data.polygons) * 3)
	obj.data.polygons.foreach_get("center", centres)
	z = centres.reshape(-1, 3)[:, 2]
	## The eaves: where the roof (faces facing up) begins. The slate's tile edges are vertical too, so a
	## "wall" face above the eaves is roof; the dormers' windows are lost with them.
	height = z.max() - z.min()
	roof = (normals.reshape(-1, 3)[:, 2] >= 0.5) & (z > z.min() + 0.3 * height)
	eaves = float(np.percentile(z[roof], EAVES_PERCENTILE))
	## And no window sits in the plinth: the bottom PLINTH_SHARE of the height is dark footing stones.
	walls = rasterise(tri_uv[(up < WALL_UP) & (z < eaves) & (z > z.min() + PLINTH_SHARE * height)], MASK_PX)
	others = rasterise(tri_uv[up >= WALL_UP], MASK_PX)
	albedo = pixels_of(base_image(obj.data.materials[0]), MASK_PX)[:, :, :3]
	glass = (albedo.max(axis=2) < GLASS_MAX) & (albedo[:, :, 2] >= albedo[:, :, 0] * GLASS_COOL)
	return glass & walls & ~others, walls, others


def clean_mask(raw):
	"""Threshold; close (fill the lead cames), open (drop mortar lines); grow by one; feather."""
	m = (raw > 0.5).astype(np.float32)

	def spread(a, op):
		out = a.copy()
		for axis in (0, 1):
			for step in (1, -1):
				out = op(out, np.roll(a, step, axis))
		return out

	for _ in range(OPEN_PX):
		m = spread(m, np.maximum)
	for _ in range(2 * OPEN_PX):
		m = spread(m, np.minimum)
	for _ in range(OPEN_PX):
		m = spread(m, np.maximum)
	for _ in range(1):
		grown = m.copy()
		grown[1:, :] = np.maximum(grown[1:, :], m[:-1, :])
		grown[:-1, :] = np.maximum(grown[:-1, :], m[1:, :])
		grown[:, 1:] = np.maximum(grown[:, 1:], m[:, :-1])
		grown[:, :-1] = np.maximum(grown[:, :-1], m[:, 1:])
		m = grown
	blur = (m + np.roll(m, 1, 0) + np.roll(m, -1, 0) + np.roll(m, 1, 1) + np.roll(m, -1, 1)) / 5.0
	return blur


def add_emissive(src, dst, mask_png):
	"""Copy GLB `src` to `dst` with `mask_png` as its first material's emissiveTexture (factor EMBER)."""
	with open(src, "rb") as handle:
		data = handle.read()
	length = int.from_bytes(data[12:16], "little")
	gltf = json.loads(data[20:20 + length])
	binary_start = 20 + length
	bin_length = int.from_bytes(data[binary_start:binary_start + 4], "little")
	binary = bytearray(data[binary_start + 8:binary_start + 8 + bin_length])
	png = open(mask_png, "rb").read()
	offset = len(binary)
	binary += png + b"\0" * ((4 - len(png) % 4) % 4)
	gltf["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(png)})
	gltf["images"].append({"bufferView": len(gltf["bufferViews"]) - 1, "mimeType": "image/png", "name": "window_mask"})
	sampler = gltf["textures"][0].get("sampler")
	texture = {"source": len(gltf["images"]) - 1}
	if sampler is not None:
		texture["sampler"] = sampler
	gltf["textures"].append(texture)
	material = gltf["materials"][0]
	uv = material.get("pbrMetallicRoughness", {}).get("baseColorTexture", {}).get("texCoord", 0)
	material["emissiveTexture"] = {"index": len(gltf["textures"]) - 1, "texCoord": uv}
	material["emissiveFactor"] = EMBER
	gltf["buffers"][0]["byteLength"] = len(binary)
	body = json.dumps(gltf, separators=(",", ":")).encode()
	body += b" " * ((4 - len(body) % 4) % 4)
	total = 12 + 8 + len(body) + 8 + len(binary)
	with open(dst, "wb") as handle:
		handle.write(b"glTF" + (2).to_bytes(4, "little") + total.to_bytes(4, "little"))
		handle.write(len(body).to_bytes(4, "little") + b"JSON" + body)
		handle.write(len(binary).to_bytes(4, "little") + b"BIN\0" + bytes(binary))


def step_windows(lib, out):
	"""Each lit building's window mask (PNG, UV0 space) and the emissive copy of its L0."""
	rows = {}
	for key in LIT:
		src = os.path.join(lib, "building", key, "l0.glb")
		obj = load(src)
		raw, walls, others = window_mask(obj)
		mask = clean_mask(raw.astype(np.float32)) * walls
		image = bpy.data.images.new(f"{key}_mask", MASK_PX, MASK_PX, alpha=False)
		image.colorspace_settings.name = "Non-Color"
		rgba = np.dstack([mask, mask, mask, np.ones_like(mask)]).astype(np.float32)
		image.pixels.foreach_set(rgba.ravel())
		folder = os.path.join(lib, "building", key)
		mask_path = os.path.join(folder, "window_mask.png")
		image.filepath_raw = mask_path
		image.file_format = "PNG"
		image.save()
		lit = os.path.join(folder, "l0_windows.glb")
		add_emissive(src, lit, mask_path)
		shutil.copy2(mask_path, os.path.join(out, "world", f"{key}_window_mask.png"))
		shutil.copy2(lit, os.path.join(out, "world", f"{key}_windows.glb"))
		rows[key] = {"mask": mask_path, "lit_glb": lit, "mask_px": MASK_PX, "wall_texels": round(float(walls.mean()), 4),
			"shared_wall_and_roof_texels": round(float((walls & others).mean()), 4),
			"glass_texels": round(float(raw.mean()), 5), "mask_share": round(float((mask > 0.5).mean()), 5)}
	return rows


# --- the bare oak ------------------------------------------------------------------------------

def leafness(rgb, ratio=LEAF_RATIO):
	"""bare_boughs.gd's leaf test: green over red at `ratio` (its LEAF_RATIO by default) and green at least blue."""
	return (rgb[..., 1] >= rgb[..., 0] * ratio) & (rgb[..., 1] >= rgb[..., 2])


## The oak's trunk radius (world_layout.gd TRUNK_RADIUS_M 1.1) over its drawn scale (13.0 m / 1.8977), and how far
## it is sunk (world_sizes.gd SINK_M 1.2), in the L0's own units.
OAK_TRUNK_U = 1.1 / (13.0 / 1.8977)
OAK_SINK_U = 1.2 / (13.0 / 1.8977)
PEEL_PASSES = 4
CAP_EDGES = 12


def tidy_branch_ends(obj, roots_top):
	"""Above the roots: weld the seams, peel the flat flaps a cut branch ends in (a triangle with two or more
	open edges), then cap each small hole (a branch end, a gap in the trunk) with its neighbours' UVs (bark)."""
	bm = bmesh.new()
	bm.from_mesh(obj.data)
	bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
	peeled = 0
	for _ in range(PEEL_PASSES):
		flaps = [f for f in bm.faces if f.calc_center_median().z > roots_top
			and sum(1 for e in f.edges if e.is_boundary) >= 2]
		if not flaps:
			break
		peeled += len(flaps)
		bmesh.ops.delete(bm, geom=flaps, context="FACES")
		bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
	## Peeling can leave a branch's outer piece floating: drop every piece but the tree itself.
	seen, pieces = set(), []
	for face in bm.faces:
		if face in seen:
			continue
		stack, piece = [face], []
		seen.add(face)
		while stack:
			f = stack.pop()
			piece.append(f)
			for e in f.edges:
				for g in e.link_faces:
					if g not in seen:
						seen.add(g)
						stack.append(g)
		pieces.append(piece)
	largest = max(sum(f.calc_area() for f in p) for p in pieces)
	floating = [f for p in pieces if sum(g.calc_area() for g in p) < 0.05 * largest for f in p]
	bmesh.ops.delete(bm, geom=floating, context="FACES")
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
	uv_layer = bm.loops.layers.uv.active
	before = set(bm.faces)
	edges = [e for e in bm.edges if e.is_boundary]
	bmesh.ops.holes_fill(bm, edges=edges, sides=CAP_EDGES)
	caps = [f for f in bm.faces if f not in before]
	for face in caps:
		neighbour = next((g for e in face.edges for g in e.link_faces if g is not face and g in before), None)
		if neighbour is None:
			continue
		uv = sum((l[uv_layer].uv for l in neighbour.loops), Vector((0, 0))) / len(neighbour.loops)
		for loop in face.loops:
			loop[uv_layer].uv = uv
	bmesh.ops.triangulate(bm, faces=caps)
	bm.normal_update()
	bm.to_mesh(obj.data)
	bm.free()
	return {"flaps_peeled": peeled, "floating_dropped": len(floating), "ends_capped": len(caps)}


def settle_root_skirt(obj, roots_top):
	"""Lower the root mound's outer skirt below the ground line (the fins that snow whitens), easing from
	1.2 to 2.2 trunk radii, so a bare oak rises from the ground on its root flares."""
	co = co_array(obj)
	base = co[:, 2].min()
	ground = base + OAK_SINK_U
	radius = np.hypot(co[:, 0] - np.median(co[:, 0]), co[:, 1] - np.median(co[:, 1]))
	low = co[:, 2] < roots_top
	t = smooth(radius, 1.2 * OAK_TRUNK_U, 2.2 * OAK_TRUNK_U) * low
	target = np.minimum(co[:, 2], ground - 0.01)
	co[:, 2] = co[:, 2] * (1 - t) + target * t
	set_co(obj, co)
	return int((t > 0.01).sum())


def step_oak_bare(lib, out):
	"""Cut, clean and re-texture the mature oak's bare boughs."""
	obj = load(os.path.join(lib, "environment/oak_mature/l0.glb"))
	triangulate(obj)
	material = obj.data.materials[0]
	image = base_image(material)
	small = pixels_of(image, SAMPLE_PX)
	loops, verts = triangles_of(obj)
	uv = loop_uvs(obj)
	co = co_array(obj)
	height = co[:, 2].max() - co[:, 2].min()
	roots_top = co[:, 2].min() + ROOTS_SHARE * height
	tri_uv = uv[loops]
	weights = np.array([[1, 0, 0], [0, 1, 0], [0, 0, 1], [1 / 3] * 3, [0.6, 0.2, 0.2], [0.2, 0.6, 0.2], [0.2, 0.2, 0.6]])
	at = [np.einsum("k,nkj->nj", w, tri_uv) for w in weights]
	leafy = np.stack([leafness(sample(small, uv_k)[:, :3]) for uv_k in at], axis=1)
	strict = np.stack([leafness(sample(small, uv_k)[:, :3], CUT_RATIO) for uv_k in at], axis=1)
	top = co[verts][:, :, 2].max(axis=1)
	runtime_keep = (top <= roots_top) | (~leafy[:, 3] & (leafy[:, :3].sum(axis=1) <= 1))
	keep = (top <= roots_top) | (strict.mean(axis=1) < 0.5)
	keep &= runtime_keep
	keep_faces(obj, keep)
	## Islands and slivers. Meshy splits vertices at every UV seam, so islands join by POSITION, not by index.
	bm = bmesh.new()
	bm.from_mesh(obj.data)
	bm.faces.ensure_lookup_table()
	area = np.array([f.calc_area() for f in bm.faces])
	_, welded = np.unique(np.round(co_array(obj) / 1e-5).astype(np.int64), axis=0, return_inverse=True)
	welded = welded.ravel()
	parent = list(range(len(bm.faces)))

	def find(i):
		while parent[i] != i:
			parent[i] = parent[parent[i]]
			i = parent[i]
		return i

	owner = {}
	for f in bm.faces:
		for v in f.verts:
			key = int(welded[v.index])
			if key in owner:
				a, b = find(owner[key]), find(f.index)
				if a != b:
					parent[a] = b
			else:
				owner[key] = f.index
	island_of = np.array([find(i) for i in range(len(bm.faces))])
	island_area = {root: area[island_of == root].sum() for root in set(island_of.tolist())}
	small_island = np.array([island_area[r] < ISLAND_SHARE * area.sum() for r in island_of])
	thin = np.zeros(len(bm.faces), dtype=bool)
	for f in bm.faces:
		edges = [e.calc_length() for e in f.edges]
		perimeter = sum(edges)
		inradius = 2 * f.calc_area() / max(perimeter, 1e-9)
		thin[f.index] = inradius / max(max(edges), 1e-9) < SLIVER and (f.calc_center_median().z > roots_top)
	bm.free()
	keep2 = ~(small_island | thin)
	keep_faces(obj, keep2)
	ends = tidy_branch_ends(obj, roots_top)
	settled = settle_root_skirt(obj, roots_top)
	## The bark texture: every leaf texel replaced by the mean bark colour of its neighbourhood (iterated
	## spreads of the bark pixels into the leaf ones), so the leaf shader finds no leaf texel to discard.
	full = pixels_of(image)
	leaf = leafness(full[:, :, :3], CUT_RATIO)
	filled = full.copy()
	known = ~leaf
	for _ in range(64):
		if known.all():
			break
		total = np.zeros_like(filled[:, :, :3])
		count = np.zeros(known.shape, dtype=np.float32)
		for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			shifted = np.roll(np.roll(filled[:, :, :3] * known[:, :, None], dy, 0), dx, 1)
			total += shifted
			count += np.roll(np.roll(known.astype(np.float32), dy, 0), dx, 1)
		grow = (~known) & (count > 0)
		filled[grow, :3] = total[grow] / count[grow, None]
		known = known | grow
	filled[~known, :3] = np.array([0.18, 0.13, 0.09])
	bark = bpy.data.images.new("oak_bare_albedo", full.shape[1], full.shape[0], alpha=False)
	bark.pixels.foreach_set(filled.astype(np.float32).ravel())
	bark_path = os.path.join(lib, "environment/oak_mature/bare_albedo.png")
	bark.filepath_raw = bark_path
	bark.file_format = "PNG"
	bark.save()
	bark_material = material.copy()
	bark_material.name = "oak_bare"
	bsdf = next(n for n in bark_material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	node = bsdf.inputs["Base Color"].links[0].from_node
	node.image = bark
	obj.data.materials[0] = bark_material
	path = os.path.join(lib, "environment/oak_mature/bare.glb")
	export([obj], path)
	shutil.copy2(path, os.path.join(out, "world/oak_mature_bare.glb"))
	lo, hi = gltf_bounds(obj)
	return {"glb": path, "triangles_l0": int(len(keep)), "runtime_cut_kept": int(runtime_keep.sum()),
		"strict_kept": int(keep.sum()), "after_islands_and_slivers": int(keep2.sum()),
		"islands_dropped": int(len(set(island_of[small_island].tolist()))), "islands": len(island_area), "slivers_dropped": int(thin.sum()), "branch_ends": ends,
		"root_skirt_vertices_settled": settled,
		"leaf_texels_filled": int(leaf.sum()), "aabb_min": [round(v, 4) for v in lo], "aabb_max": [round(v, 4) for v in hi]}


# --- tight-UV L0 -------------------------------------------------------------------------------

## demo_props_blender's Smart UV Project leaves a 1% gap round every island. On a voxel-remeshed tree or a
## 30,000-triangle hall that is thousands of islands, and the gaps took ~98% of the texture (pine 1.8% used,
## stone hall 1.9%). These keys re-unwrap with a hairline gap and repack before the bake.
TIGHT_MARGIN = 0.0005
PACK_MARGIN = 0.001


def run_tight_low(job):
	"""demo_props_blender's prop job, with its unwrap tightened and repacked."""
	sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
	import demo_props_blender as props
	props.UV_MARGIN = TIGHT_MARGIN
	plain = props.make_low

	def make_low(src, target):
		low, method = plain(src, target)
		bpy.ops.object.select_all(action="DESELECT")
		low.select_set(True)
		bpy.context.view_layer.objects.active = low
		bpy.ops.object.mode_set(mode="EDIT")
		bpy.ops.mesh.select_all(action="SELECT")
		bpy.ops.uv.select_all(action="SELECT")
		bpy.ops.uv.pack_islands(margin=PACK_MARGIN, rotate=True)
		bpy.ops.object.mode_set(mode="OBJECT")
		return low, method + "+tight_uv"

	props.make_low = make_low
	return props.run_prop(job)


STEPS = {"hall_stage2": step_hall_stage2, "hall_banner": step_hall_banner, "pine_tint": step_pine_tint, "wildlife": step_wildlife,
	"windows": step_windows, "oak_bare": step_oak_bare}


def main():
	"""Read the job, run its step, print the result."""
	job = json.loads(open(sys.argv[sys.argv.index("--") + 1]).read())
	if job.get("kind") == "prop":
		started = time.time()
		result = run_tight_low(job)
		result["seconds"] = round(time.time() - started, 1)
		print("RESULT " + json.dumps(result), flush=True)
		return
	started = time.time()
	result = STEPS[job["step"]](job["library"], job["out"])
	print("RESULT " + json.dumps({"step": job["step"], "seconds": round(time.time() - started, 1), **{"result": result}}),
		flush=True)


if __name__ == "__main__":
	main()
