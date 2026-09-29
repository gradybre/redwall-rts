"""Blender half of tools/make_demo_props.py. Decision 0196 (live demo). Runs headless:

	blender --background --factory-startup --python tools/demo_props_blender.py -- <job.json>

Do not run this directly; make_demo_props.py writes the job and reads the result. A job names ONE
high-poly library source and asks for:

  "prop":  decimate the whole model to a triangle budget, centre it on X/Z with its lowest point at
	y = 0 (bottom origin), keep its facing (+Z, glTF front), shrink every texture to at most
	`texture_px`, and export a GLB with its own maps.
  "plant": the same for the part of a single plant above its soil line (the soil clump the
	concepts stand the plant on is cut away: every face below the line, and the soil-coloured
	faces of the clump above it), with the soil line at y = 0 -- plus ALPHA CARDS of the plant:
	an RGBA atlas of four cells (full from the front, full from the side, thinned, sparse) and,
	when asked, an atlas of the same three from straight above. THINNING drops whole UV charts by
	the angle their centre makes round the crown: the high-poly welds into one connected piece, so
	its leaves are not separate shells, but Meshy's charts each lie on one leaf or stalk, so a
	chart-by-sector cut follows the charts' own ragged borders instead of a straight line.
  "icon":  optional, with either: a transparent square render of the decimated model, from the
	same three-quarter camera and the same three lights for every item, for the pantry.

The cards are rendered as tools/demo_crop_cards_blender.py renders the crop beds' (imported from
it): orthographic, through a transparent film, the base-colour map wired straight to emission, so
every pixel is the authored albedo, then dilated so mipmaps pull no dark fringe into the edges.

Coordinates in the job are glTF's (Y up, +Z front); the script converts to Blender's Z up. It
prints one line "RESULT <json>" for the caller.
"""

import json
import math
import os
import sys
import tempfile
import time

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import demo_crop_cards_blender as cards  # noqa: E402  (its main() is guarded)

ICON_SAMPLES = 48
ICON_ELEVATION_DEG = 28.0
ICON_AZIMUTH_DEG = 32.0
ICON_MARGIN = 1.08
## Decimation stops once within this fraction over budget; it never ends over it.
DECIMATE_PASSES = 8
## Soil-coloured faces this far above the soil line (glTF units) are the clump, and go.
CLUMP_REACH = 0.14
## The brightest a soil texel is (crumbs on the clump's top catch the light).
SOIL_BRIGHTEST = 0.45
## Thinning: the crown is split into this many sectors; a chart centred within CORE of the
## crown's axis (a fraction of the plant's half-width) is the stem, and is always kept.
SECTORS = 6
THINNED_SECTORS = (0, 1, 3, 4)
SPARSE_SECTORS = (0, 3)
CORE = 0.14
## The crown is found in this share of the plant's height just above the soil.
CROWN_BAND = 0.08
CARD_MARGIN = 1.04
## Baking: Smart UV Project's angle and island gap; Cycles samples; the cage pushed out, and the
## farthest a ray may search, as fractions of the model's largest extent; the bleed past each chart.
## (At 1.2% / 4% a plant's decimated leaves, which stand well off the source's, baked black patches
## where no ray reached it; 2.5% / 10% reach them.)
UV_ANGLE_DEG = 66.0
UV_MARGIN = 0.01
BAKE_SAMPLES = 4
CAGE_FRACTION = 0.025
RAY_FRACTION = 0.1
BAKE_MARGIN_PX = 6
## A voxel remesh's cell, as fractions of the model's largest extent, finest first (~6 mm on a
## 1.9-unit source): a coarser cell merges the small loose pieces a fine one leaves (lettuce leaves
## cut at the soil stop the decimator at 4,602 of 580 after the finest; a basket of loose berries
## needs the coarsest).
VOXEL_FRACTIONS = (1.0 / 320.0, 1.0 / 160.0, 1.0 / 80.0, 1.0 / 40.0)


def log(message):
	"""Progress to stdout, flushed, so a long run is visibly alive."""
	print(f"demo_props: {message}", flush=True)


# --- loading and cleaning -------------------------------------------------------------------

def load_source(path):
	"""Import the glTF into an empty scene; join its meshes into one object with transforms applied."""
	bpy.ops.wm.read_factory_settings(use_empty=True)
	started = time.time()
	bpy.ops.import_scene.gltf(filepath=path)
	meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
	if not meshes:
		raise SystemExit(f"no mesh in {path}")
	bpy.ops.object.select_all(action="DESELECT")
	for obj in meshes:
		obj.select_set(True)
	bpy.context.view_layer.objects.active = meshes[0]
	if len(meshes) > 1:
		bpy.ops.object.join()
	obj = bpy.context.view_layer.objects.active
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	for other in [o for o in bpy.context.scene.objects if o != obj]:
		bpy.data.objects.remove(other)
	log(f"imported {path}: {triangles(obj)} triangles in {time.time() - started:.1f}s")
	return obj


def triangles(obj):
	"""Triangle count of a mesh object."""
	return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def face_texels(obj):
	"""Per face: centre (Blender xyz) and the mean base-colour texel under its first three corners."""
	mesh = obj.data
	count = len(mesh.polygons)
	centres = cards._read(mesh.polygons, "center", count * 3, np.float32).reshape(-1, 3)
	starts = cards._read(mesh.polygons, "loop_start", count, np.int32)
	uv = cards._read(mesh.uv_layers.active.data, "uv", len(mesh.loops) * 2, np.float32).reshape(-1, 2)
	image = cards.base_colour_node(mesh.materials[0]).image
	width, height = image.size
	pixels = np.empty(width * height * 4, dtype=np.float32)
	image.pixels.foreach_get(pixels)
	pixels = pixels.reshape(height, width, 4)
	rgb = np.zeros((count, 3), dtype=np.float32)
	for corner in range(3):
		at = uv[starts + corner] % 1.0
		rgb += pixels[(at[:, 1] * (height - 1)).astype(int), (at[:, 0] * (width - 1)).astype(int), :3]
	return centres, rgb / 3.0


def soil_coloured(rgb):
	"""Dark, earthy, not green: the soil clump's texels (leaves are green, roots saturated or pale)."""
	high = rgb.max(axis=1)
	low = rgb.min(axis=1)
	saturation = (high - low) / np.maximum(high, 1e-4)
	r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
	return (high < SOIL_BRIGHTEST) & (saturation < 0.65) & (r >= b) & (g <= r * 1.05)


def clump_faces(obj, soil_y):
	"""Faces of the soil clump: below the soil line, or soil-coloured just above it."""
	centres, rgb = face_texels(obj)
	z = centres[:, 2]
	return (z < soil_y) | (soil_coloured(rgb) & (z < soil_y + CLUMP_REACH))


def decimate(obj, target):
	"""Collapse-decimate toward `target` triangles (a few passes: one ratio lands near, not under).
	Whether it got there: on thin, self-intersecting shells the decimator stops short, refusing
	collapses that would fold the surface."""
	before = triangles(obj)
	for _ in range(DECIMATE_PASSES):
		count = triangles(obj)
		if count <= target:
			break
		modifier = obj.modifiers.new("decimate", "DECIMATE")
		modifier.decimate_type = "COLLAPSE"
		modifier.use_collapse_triangulate = True
		modifier.ratio = min(1.0, target / count * (0.985 if count < target * 1.2 else 1.0))
		bpy.context.view_layer.objects.active = obj
		bpy.ops.object.modifier_apply(modifier=modifier.name)
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.mesh.quads_convert_to_tris()
	bpy.ops.object.mode_set(mode="OBJECT")
	log(f"decimated {before} -> {triangles(obj)} triangles (budget {target})")
	return triangles(obj) <= target


def vertex_array(obj):
	"""Every vertex position (Blender xyz) as an (n, 3) array."""
	co = np.empty(len(obj.data.vertices) * 3, dtype=np.float32)
	obj.data.vertices.foreach_get("co", co)
	return co.reshape(-1, 3)


def rebase(obj, base_z, centre_xy=None):
	"""Move the mesh so `base_z` is at 0 and its X/Y centre (bounds, or `centre_xy`) at the origin."""
	co = vertex_array(obj)
	if centre_xy is None:
		centre_xy = (co[:, :2].min(axis=0) + co[:, :2].max(axis=0)) * 0.5
	co[:, 0] -= centre_xy[0]
	co[:, 1] -= centre_xy[1]
	co[:, 2] -= base_z
	obj.data.vertices.foreach_set("co", co.ravel())
	obj.data.update()


def export_glb(obj, path):
	"""Export only `obj`, Y-up glTF binary with its maps; return its glTF bounds and triangles."""
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
		export_apply=True)
	co = vertex_array(obj)
	lo = [float(co[:, 0].min()), float(co[:, 2].min()), float(-co[:, 1].max())]
	hi = [float(co[:, 0].max()), float(co[:, 2].max()), float(-co[:, 1].min())]
	return {"glb": path, "aabb_min": [round(v, 4) for v in lo], "aabb_max": [round(v, 4) for v in hi],
		"triangles": triangles(obj), "bytes": os.path.getsize(path)}


def delete_faces(obj, doomed):
	"""Delete the faces flagged in `doomed` (a no-op when none are)."""
	if doomed.any():
		cards._delete_faces(obj, doomed)


def weld(obj):
	"""Merge the vertices Meshy split at every UV seam, so the decimator sees one surface (UVs stay
	per corner, so the seams survive as seams)."""
	mesh = bmesh.new()
	mesh.from_mesh(obj.data)
	bmesh.ops.remove_doubles(mesh, verts=mesh.verts, dist=1e-5)
	mesh.to_mesh(obj.data)
	mesh.free()


# --- icons -----------------------------------------------------------------------------------

def _light(name, kind, energy, rotation, size=0.0):
	"""One light, aimed by an Euler rotation (degrees)."""
	light = bpy.data.lights.new(name, kind)
	light.energy = energy
	if kind == "AREA":
		light.size = size
	obj = bpy.data.objects.new(name, light)
	obj.rotation_euler = [math.radians(a) for a in rotation]
	bpy.context.scene.collection.objects.link(obj)
	return obj


def setup_icon_scene(px):
	"""Cycles, transparent film, Standard view, a soft grey world and three suns: the same for every
	icon, so a shelf of them reads as one set."""
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.device = "CPU"
	scene.cycles.samples = ICON_SAMPLES
	scene.cycles.use_denoising = False
	scene.render.film_transparent = True
	scene.render.resolution_x = scene.render.resolution_y = px
	scene.render.resolution_percentage = 100
	scene.view_settings.view_transform = "Standard"
	scene.view_settings.look = "None"
	scene.render.image_settings.file_format = "PNG"
	scene.render.image_settings.color_mode = "RGBA"
	world = bpy.data.worlds.new("icon_world")
	world.use_nodes = True
	background = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
	background.inputs[0].default_value = (0.62, 0.6, 0.56, 1.0)
	background.inputs[1].default_value = 0.55
	scene.world = world
	_light("key", "SUN", 3.2, (50.0, 0.0, -40.0))
	_light("fill", "SUN", 0.9, (60.0, 0.0, 70.0))
	_light("rim", "SUN", 1.6, (-60.0, 0.0, 160.0))


def render_icon(obj, path, px):
	"""A transparent square render of `obj` from the icon camera, framed on its bounds."""
	setup_icon_scene(px)
	camera = bpy.data.objects.new("icon_camera", bpy.data.cameras.new("icon_camera"))
	camera.data.type = "ORTHO"
	bpy.context.scene.collection.objects.link(camera)
	bpy.context.scene.camera = camera
	elevation = math.radians(ICON_ELEVATION_DEG)
	azimuth = math.radians(ICON_AZIMUTH_DEG)
	# glTF front (+Z) is Blender -Y: the camera stands in front, turned toward +X, above.
	direction = Vector((math.sin(azimuth) * math.cos(elevation), -math.cos(azimuth) * math.cos(elevation),
		math.sin(elevation)))
	co = vertex_array(obj)
	centre = Vector(((co.min(axis=0) + co.max(axis=0)) * 0.5).tolist())
	camera.location = centre + direction * 20.0
	camera.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
	camera.data.clip_end = 100.0
	camera.data.ortho_scale = _frame_extent(co, camera) * ICON_MARGIN
	bpy.context.scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	return {"icon": path, "px": px}


def _frame_extent(co, camera):
	"""The larger of the model's width and height as the camera sees it, and the centre offset folded
	into the camera's position so the model sits in the middle."""
	bpy.context.view_layer.update()
	inverse = camera.matrix_world.inverted()
	local = np.array([(inverse @ Vector(p.tolist()))[:2] for p in co[:: max(1, len(co) // 4000)]])
	lo, hi = local.min(axis=0), local.max(axis=0)
	middle = (lo + hi) * 0.5
	camera.location = camera.matrix_world @ Vector((middle[0], middle[1], 0.0))
	return float(max(hi - lo))


# --- plant cards -----------------------------------------------------------------------------

def crown(obj, soil_y):
	"""The plant's axis (Blender x, y) -- the median of what stands just above the soil, once the clump
	is gone -- and its half-width round that axis and its height above the soil (glTF units)."""
	co = vertex_array(obj)
	above = co[co[:, 2] > soil_y]
	low = above[above[:, 2] < soil_y + CROWN_BAND * (above[:, 2].max() - soil_y)]
	axis = np.median(low[:, :2], axis=0) if len(low) else (above[:, :2].min(axis=0) + above[:, :2].max(axis=0)) * 0.5
	half = float(np.abs(above[:, :2] - axis).max())
	return axis, half, float(above[:, 2].max() - soil_y)


def chart_sectors(obj, axis, half):
	"""Per face: the sector (0..SECTORS-1) its UV chart's centre lies in round the crown, or -1 for a
	chart in the stem core (always kept)."""
	src = cards.Source(obj)
	label = cards.components(src.tri_verts)
	_, chart = np.unique(label, return_inverse=True)
	weight = np.bincount(chart)
	cx = np.bincount(chart, src.centre[:, 0]) / weight - axis[0]
	cy = np.bincount(chart, src.centre[:, 1]) / weight - axis[1]
	sector = (np.floor((np.arctan2(cy, cx) + math.pi) / (2.0 * math.pi) * SECTORS).astype(int)) % SECTORS
	sector[np.hypot(cx, cy) < CORE * half] = -1
	mesh = obj.data
	per_tri = sector[chart]
	per_face = np.full(len(mesh.polygons), -1, dtype=int)
	polys = cards._read(mesh.loop_triangles, "polygon_index", len(mesh.loop_triangles), np.int32)
	per_face[polys] = per_tri
	return per_face


def _keep_only(obj, sectors, keep):
	"""A copy of `obj` without the faces whose sector is not in `keep` (the core always stays)."""
	copy = obj.copy()
	copy.data = obj.data.copy()
	bpy.context.scene.collection.objects.link(copy)
	if keep is not None:
		delete_faces(copy, ~((sectors == -1) | np.isin(sectors, keep)))
	return copy


def _orbit(copy, axis, degrees):
	"""Turn `copy` about the vertical through the crown."""
	pivot = Vector((axis[0], axis[1], 0.0))
	copy.matrix_world = Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(degrees), 4, "Z") \
		@ Matrix.Translation(-pivot)


def _render_cell(camera, frame, view, axis, soil_y, cell_m):
	"""One orthographic cell, into `frame`, of whatever is renderable."""
	camera.data.ortho_scale = max(cell_m)
	if view == "top":
		camera.rotation_euler = (0.0, 0.0, 0.0)
		camera.location = (axis[0], axis[1], 10.0)
	else:
		camera.rotation_euler = (math.pi / 2.0, 0.0, 0.0)
		camera.location = (axis[0], -10.0, soil_y + cell_m[1] * 0.5)
	bpy.context.scene.render.filepath = frame
	bpy.ops.render.render(write_still=True)


CELLS = (("full", None, 0.0), ("side", None, 90.0), ("thinned", THINNED_SECTORS, 0.0), ("sparse", SPARSE_SECTORS, 0.0))


def make_plant_cards(obj, job, axis, half, height):
	"""Render the standing atlas (and the top atlas if asked); return their metadata."""
	spec = job["cards"]
	soil_y = job["soil_y"]
	sectors = chart_sectors(obj, axis, half)
	for material in obj.data.materials:
		cards.soil_mask_material(material, soil_y)
	camera = cards.setup_render()
	cell_m = [round(2.0 * half * CARD_MARGIN, 4), round(height * CARD_MARGIN, 4)]
	obj.hide_render = True
	result = {"cell_m": cell_m, "cells": [c[0] for c in CELLS]}
	result["atlas"] = _atlas(obj, camera, spec["atlas"], "front", CELLS, sectors, axis, soil_y, cell_m, spec["px_per_unit"])
	if spec.get("tops"):
		top_m = [cell_m[0], cell_m[0]]
		result["tops"] = _atlas(obj, camera, spec["tops"], "top", [CELLS[0], CELLS[2], CELLS[3]], sectors, axis,
			soil_y, top_m, spec["px_per_unit"])
		result["top_cell_m"] = top_m
	obj.hide_render = False
	return result


def _atlas(obj, camera, path, view, cells, sectors, axis, soil_y, cell_m, px_per_unit):
	"""Render `cells` of the plant side by side into one RGBA atlas at `path`."""
	scene = bpy.context.scene
	px = [int(round(v * px_per_unit / 2.0)) * 2 for v in cell_m]
	scene.render.resolution_x, scene.render.resolution_y = px
	rendered = []
	for index, (name, keep, turn) in enumerate(cells):
		copy = _keep_only(obj, sectors, keep)
		copy.hide_render = False
		_orbit(copy, axis, turn)
		frame = f"{path}.cell{index}.png"
		_render_cell(camera, frame, view, axis, soil_y, cell_m)
		rendered.append(cards.dilate(cards.read_pixels(frame, px)))
		os.remove(frame)
		bpy.data.meshes.remove(copy.data)
		log(f"{view} cell {index} ({name}) rendered")
	cards.save_atlas(rendered, path)
	return {"path": path, "variants": len(rendered), "px": [px[0] * len(rendered), px[1]]}


# --- the low-poly and its bake -------------------------------------------------------------

def make_low(src, target):
	"""A copy of `src` with no UVs, at most `target` triangles, re-unwrapped; and how it was reduced.

	Meshy's high-poly is cut into ~600 UV charts, and the collapse decimator will not cross a chart
	border, so the copy drops its UVs (the texture comes back by baking, bake_maps). Welded, most
	models then decimate straight to budget. Thin self-intersecting shells (leafy tops, planks) stop
	short -- the carrot bunch at 1,812 of 1,150 -- and are rebuilt by a voxel remesh first, at
	VOXEL_FRACTIONS of the model's largest extent in turn, which closes the self-intersections."""
	low = _bare_copy(src)
	method = "decimate"
	extent = float(max(np.ptp(vertex_array(src), axis=0)))
	for attempt, fraction in enumerate((None, *VOXEL_FRACTIONS)):
		if attempt > 0:
			bpy.data.objects.remove(low)
			low = _bare_copy(src)
			_voxel_remesh(low, extent * fraction)
			method = f"voxel_remesh({fraction * extent:.4f})+decimate"
		if decimate(low, target):
			break
	else:
		raise SystemExit(f"{src.name}: still over {target} triangles after every voxel remesh")
	low.data.uv_layers.new(name="UVMap")
	bpy.ops.object.select_all(action="DESELECT")
	low.select_set(True)
	bpy.context.view_layer.objects.active = low
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.uv.smart_project(angle_limit=math.radians(UV_ANGLE_DEG), island_margin=UV_MARGIN)
	bpy.ops.object.mode_set(mode="OBJECT")
	return low, method


def _voxel_remesh(obj, size):
	"""Rebuild `obj` as a voxel remesh at this cell size (closes self-intersections)."""
	remesh = obj.modifiers.new("remesh", "REMESH")
	remesh.mode = "VOXEL"
	remesh.voxel_size = size
	bpy.context.view_layer.objects.active = obj
	bpy.ops.object.modifier_apply(modifier=remesh.name)


def _bare_copy(src):
	"""A welded copy of `src`'s mesh with no UVs and no materials, linked into the scene."""
	low = src.copy()
	low.data = src.data.copy()
	low.name = "low"
	bpy.context.scene.collection.objects.link(low)
	while low.data.uv_layers:
		low.data.uv_layers.remove(low.data.uv_layers[0])
	low.data.materials.clear()
	weld(low)
	return low


def _bake_image(name, px, colour):
	"""A blank bake target: sRGB for colour, Non-Color for data."""
	image = bpy.data.images.new(name, px, px, alpha=False)
	image.colorspace_settings.name = "sRGB" if colour else "Non-Color"
	return image


def low_material(px):
	"""The low-poly's material: a Principled BSDF over three blank bake targets."""
	material = bpy.data.materials.new("baked")
	material.use_nodes = True
	nt = material.node_tree
	bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
	bsdf.inputs["Metallic"].default_value = 0.0
	images = {}
	for key, colour, socket in (("base", True, "Base Color"), ("rough", False, "Roughness"), ("normal", False, None)):
		node = nt.nodes.new("ShaderNodeTexImage")
		node.name = f"bake_{key}"
		node.image = _bake_image(f"{key}", px, colour)
		images[key] = node
		if socket:
			nt.links.new(node.outputs["Color"], bsdf.inputs[socket])
	normal_map = nt.nodes.new("ShaderNodeNormalMap")
	nt.links.new(images["normal"].outputs["Color"], normal_map.inputs["Color"])
	nt.links.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])
	return material, images


def bake_maps(src, low, px):
	"""Bake the source's albedo, roughness and tangent normal onto the low-poly's new UVs."""
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.device = "CPU"
	scene.cycles.samples = BAKE_SAMPLES
	material, images = low_material(px)
	low.data.materials.append(material)
	size = float(max(np.ptp(vertex_array(src), axis=0)))
	bake = scene.render.bake
	bake.use_selected_to_active = True
	bake.cage_extrusion = size * CAGE_FRACTION
	bake.max_ray_distance = size * RAY_FRACTION
	bake.margin = BAKE_MARGIN_PX
	bpy.ops.object.select_all(action="DESELECT")
	src.select_set(True)
	low.select_set(True)
	bpy.context.view_layer.objects.active = low
	for key, kind in (("base", "DIFFUSE"), ("rough", "ROUGHNESS"), ("normal", "NORMAL")):
		material.node_tree.nodes.active = images[key]
		started = time.time()
		if kind == "DIFFUSE":
			bpy.ops.object.bake(type=kind, pass_filter={"COLOR"}, use_clear=True)
		else:
			bpy.ops.object.bake(type=kind, use_clear=True)
		images[key].image.pack()
		log(f"baked {key} ({px} px) in {time.time() - started:.1f}s")
	return px


# --- jobs ------------------------------------------------------------------------------------

def run_prop(job):
	"""Decimate, bake, rebase, export (and render the icon)."""
	src = load_source(job["source"])
	low, method = make_low(src, job["target_triangles"])
	result = {"texture_px": bake_maps(src, low, job["texture_px"]), "method": method}
	bpy.data.objects.remove(src)
	rebase(low, float(vertex_array(low)[:, 2].min()))
	result.update(export_glb(low, job["glb"]))
	if job.get("icon"):
		result["icon"] = render_icon(low, job["icon"]["path"], job["icon"]["px"])
	return result


def run_plant(job):
	"""Cards from the whole plant, then the L0 of what stands above the soil."""
	obj = load_source(job["source"])
	soil_y = job["soil_y"]
	delete_faces(obj, clump_faces(obj, soil_y) & ~below_line_only(obj, soil_y))
	axis, half, height = crown(obj, soil_y)
	result = {"axis": [round(float(axis[0]), 4), round(float(-axis[1]), 4)], "half_width": round(half, 4),
		"height": round(height, 4)}
	result["cards"] = make_plant_cards(obj, job, axis, half, height)
	for material in obj.data.materials:
		cards.restore_material(material)
	delete_faces(obj, below_line_only(obj, soil_y))
	low, result["method"] = make_low(obj, job["target_triangles"])
	result["texture_px"] = bake_maps(obj, low, job["texture_px"])
	bpy.data.objects.remove(obj)
	rebase(low, soil_y, axis)
	result.update(export_glb(low, job["glb"]))
	return result


def below_line_only(obj, soil_y):
	"""Faces below the soil line (the cards' shader hides them, so they are kept for its cut)."""
	centres = cards._read(obj.data.polygons, "center", len(obj.data.polygons) * 3, np.float32).reshape(-1, 3)
	return centres[:, 2] < soil_y


def main():
	"""Read the job, do what it asks, print the result."""
	job = json.loads(open(sys.argv[sys.argv.index("--") + 1]).read())
	started = time.time()
	result = run_plant(job) if job["kind"] == "plant" else run_prop(job)
	result["seconds"] = round(time.time() - started, 1)
	print("RESULT " + json.dumps(result), flush=True)


if __name__ == "__main__":
	main()
