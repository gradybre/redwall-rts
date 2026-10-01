"""Blender half of tools/make_demo_derived_props.py. Decision 0371 (the underground revamp's P7). Runs headless:

	blender --background --factory-startup --python tools/demo_derived_blender.py -- <job.json>

Do not run this directly; make_demo_derived_props.py writes the job and reads the result. A job names ONE high-poly
library source (only ever read) and the edits that fix what its plain L0 (make_demo_props.py) gets wrong, then makes
each resulting PART's game-budget mesh the way make_demo_props.py makes a prop's -- the same decimation, UV unwrap and
bake (demo_props_blender.py `make_low`, `bake_maps`), so a derived prop looks like its siblings:

  "drop":    faces removed first, by region (see REGIONS) -- the tunnel arch's black slab filling its doorway.
  "stretch": the model lengthened along glTF x and z by `[dx, dz]` units WITHOUT stretching its texture: it is cut at
             the middle, the halves moved apart, and the gap filled with a copy of the middle slab -- the large bed's
             longer quilt is the bed's own quilt, repeated, its head- and footboards untouched.
  "parts":   the model split by region into named parts, in order, each face to the first part whose region holds its
             centre (the last part, `{}`, takes the rest) -- the burrow door's leaf from its frame, the hanging stores'
             five strings from their bar. A part may be THINNED (its faces behind `thin.at` moved forward by
             `thin.by`: the door's back face brought up to make the leaf a door's thickness, not the wall's) and given a
             RIM (`rim`: a band round the axis of its cylinder region, closing the edge a split leaves open), and its
             own triangle budget and texture size.
  "glow":    faces of the made mesh whose baked albedo is pale (the candle lantern's horn panes and candle) moved to a
             second material named `glow`, which the demo lights from within.

Every part is rebased by the WHOLE model's bounds (lowest point y = 0, centred on x/z) before export, so placing every
part with one transform puts the model back together. Coordinates in the job are glTF's (y up, +z front); the script
converts to Blender's z up. It prints one line "RESULT <json>" for the caller.

REGIONS. A dict, every key it has must hold (empty: everything):
  "box":       [[x0, y0, z0], [x1, y1, z1]], glTF units;
  "cylinder":  [x, y, r] -- within r of the axis through (x, y) along z;
  "dark":      the face's mean base-colour texel is darker than this (max channel).
"""

import json
import math
import os
import sys
import time

import bmesh
import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import demo_props_blender as props  # noqa: E402  (its main() is guarded)

## The rim band round a split part: this many sides, its colour (a dark worn timber, baked like any surface).
RIM_SIDES = 40
RIM_COLOUR = (0.16, 0.1, 0.055, 1.0)
## A face whose baked albedo is at least this bright and at most this saturated is a lantern's pane or candle.
GLOW_BRIGHT = 0.62
GLOW_SATURATION = 0.45


def log(message):
	"""Progress to stdout, flushed."""
	print(f"demo_derived: {message}", flush=True)


# --- regions --------------------------------------------------------------------------------------

def gltf_centres(obj):
	"""Every face's centre in glTF coordinates (x, y up, z front) as an (n, 3) array."""
	mesh = obj.data
	centres = np.empty(len(mesh.polygons) * 3, dtype=np.float32)
	mesh.polygons.foreach_get("center", centres)
	centres = centres.reshape(-1, 3)
	return np.c_[centres[:, 0], centres[:, 2], -centres[:, 1]]


def in_region(obj, region, centres=None):
	"""Per face: whether its centre lies in `region` (see REGIONS)."""
	g = gltf_centres(obj) if centres is None else centres
	hit = np.ones(len(g), dtype=bool)
	if "box" in region:
		lo, hi = np.array(region["box"][0]), np.array(region["box"][1])
		hit &= np.all((g >= lo) & (g <= hi), axis=1)
	if "cylinder" in region:
		x, y, r = region["cylinder"]
		hit &= np.hypot(g[:, 0] - x, g[:, 1] - y) <= r
	if "dark" in region:
		_, rgb = props.face_texels(obj)
		hit &= rgb.max(axis=1) < region["dark"]
	return hit


def keep_faces(obj, keep):
	"""A copy of `obj` with only the faces flagged in `keep`, linked into the scene."""
	copy = obj.copy()
	copy.data = obj.data.copy()
	bpy.context.scene.collection.objects.link(copy)
	props.delete_faces(copy, ~keep)
	return copy


# --- stretch ----------------------------------------------------------------------------------------

def _bisect_split(mesh, axis):
	"""Cut `mesh` (bmesh) at axis = 0 and separate the two sides along the cut."""
	normal = Vector((0.0, 0.0, 0.0))
	normal[axis] = 1.0
	geom = mesh.verts[:] + mesh.edges[:] + mesh.faces[:]
	cut = bmesh.ops.bisect_plane(mesh, geom=geom, plane_co=(0.0, 0.0, 0.0), plane_no=normal)
	edges = [e for e in cut["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
	if edges:
		bmesh.ops.split_edges(mesh, edges=edges)


def stretch(obj, gltf_axis, amount):
	"""Lengthen `obj` along glTF axis `gltf_axis` (0 x, 2 z) by `amount` (see the header's "stretch")."""
	if amount <= 0.0:
		return
	axis = 0 if gltf_axis == 0 else 1
	sign = 1.0 if gltf_axis == 0 else -1.0
	half = amount * 0.5
	slab = obj.copy()
	slab.data = obj.data.copy()
	bpy.context.scene.collection.objects.link(slab)
	mesh = bmesh.new()
	mesh.from_mesh(obj.data)
	_bisect_split(mesh, axis)
	for vert in mesh.verts:
		side = 1.0 if vert.co[axis] > 1e-6 else (-1.0 if vert.co[axis] < -1e-6 else 0.0)
		if side == 0.0:
			side = 1.0 if sum(f.calc_center_median()[axis] for f in vert.link_faces) > 0.0 else -1.0
		vert.co[axis] += side * half
	mesh.to_mesh(obj.data)
	mesh.free()
	inner = bmesh.new()
	inner.from_mesh(slab.data)
	for at in (-half, half):
		geom = inner.verts[:] + inner.edges[:] + inner.faces[:]
		plane = Vector((0.0, 0.0, 0.0))
		plane[axis] = at
		normal = Vector((0.0, 0.0, 0.0))
		normal[axis] = 1.0
		bmesh.ops.bisect_plane(inner, geom=geom, plane_co=plane, plane_no=normal, clear_outer=at > 0.0,
			clear_inner=at < 0.0)
	inner.to_mesh(slab.data)
	inner.free()
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	slab.select_set(True)
	bpy.context.view_layer.objects.active = obj
	bpy.ops.object.join()
	log(f"stretched glTF axis {gltf_axis} by {amount} (sign {sign})")


# --- parts ------------------------------------------------------------------------------------------

def thin(obj, spec):
	"""Move every vertex behind glTF z = `spec.at` forward by `spec.by` (the door's back face up to its front)."""
	co = props.vertex_array(obj)
	behind = -co[:, 1] < spec["at"]
	co[behind, 1] -= spec["by"]
	obj.data.vertices.foreach_set("co", co.ravel())
	obj.data.update()


def add_rim(obj, cylinder, z_range):
	"""A band of RIM_SIDES quads round the cylinder's axis (glTF x, y, r) from glTF z_range[0] to [1], facing out, in
	its own dark timber material: the edge a split leaf would show open."""
	x, y, r = cylinder
	mesh = bmesh.new()
	ring = []
	for k in range(RIM_SIDES):
		angle = 2.0 * math.pi * k / RIM_SIDES
		px, py = x + r * math.cos(angle), y + r * math.sin(angle)
		ring.append((mesh.verts.new((px, -z_range[0], py)), mesh.verts.new((px, -z_range[1], py))))
	for k in range(RIM_SIDES):
		a, b = ring[k], ring[(k + 1) % RIM_SIDES]
		mesh.faces.new((a[0], b[0], b[1], a[1]))
	bmesh.ops.recalc_face_normals(mesh, faces=mesh.faces[:])
	data = bpy.data.meshes.new("rim")
	mesh.to_mesh(data)
	mesh.free()
	material = bpy.data.materials.new("rim")
	material.use_nodes = True
	bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	bsdf.inputs["Base Color"].default_value = RIM_COLOUR
	bsdf.inputs["Roughness"].default_value = 0.85
	data.materials.append(material)
	data.uv_layers.new(name="UVMap")
	band = bpy.data.objects.new("rim", data)
	bpy.context.scene.collection.objects.link(band)
	bpy.ops.object.select_all(action="DESELECT")
	band.select_set(True)
	obj.select_set(True)
	bpy.context.view_layer.objects.active = obj
	bpy.ops.object.join()
	_outward(obj, cylinder)


def _outward(obj, cylinder):
	"""Turn the rim's faces (the joined material slot past the first) to face away from the axis."""
	x, y, _ = cylinder
	mesh = bmesh.new()
	mesh.from_mesh(obj.data)
	for face in mesh.faces:
		if face.material_index == 0:
			continue
		centre = face.calc_center_median()
		out = Vector((centre.x - x, 0.0, centre.z - y))
		if face.normal.dot(out) < 0.0:
			face.normal_flip()
	mesh.to_mesh(obj.data)
	mesh.free()


def part_masks(obj, specs):
	"""Per part (see the header's "parts"): which faces it takes -- each face the first part whose region holds it."""
	centres = gltf_centres(obj)
	taken = np.zeros(len(centres), dtype=bool)
	masks = []
	for spec in specs:
		hit = in_region(obj, spec.get("region", {}), centres) & ~taken
		taken |= hit
		masks.append(hit)
	return masks


def make_source(obj, spec, mask):
	"""Part `spec`'s high-poly: the faces `mask` holds, thinned and rimmed as it asks."""
	part = keep_faces(obj, mask)
	part.name = spec["name"]
	if "thin" in spec:
		thin(part, spec["thin"])
	if "rim" in spec:
		add_rim(part, spec["region"]["cylinder"], spec["rim"])
	log(f"part {spec['name']}: {props.triangles(part)} source triangles")
	return part


# --- glow -------------------------------------------------------------------------------------------

def split_glow(low, images):
	"""Move the faces whose baked albedo is pale (see GLOW_BRIGHT) to a second material `glow` sharing the maps."""
	base = images["base"].image
	width, height = base.size
	pixels = np.empty(width * height * 4, dtype=np.float32)
	base.pixels.foreach_get(pixels)
	pixels = pixels.reshape(height, width, 4)
	mesh = low.data
	uv = np.empty(len(mesh.loops) * 2, dtype=np.float32)
	mesh.uv_layers.active.data.foreach_get("uv", uv)
	uv = uv.reshape(-1, 2)
	glow = mesh.materials[0].copy()
	glow.name = "glow"
	mesh.materials[0].name = "lantern"
	mesh.materials.append(glow)
	count = 0
	for poly in mesh.polygons:
		at = uv[poly.loop_start:poly.loop_start + poly.loop_total].mean(axis=0) % 1.0
		rgb = pixels[int(at[1] * (height - 1)), int(at[0] * (width - 1)), :3]
		high, lowest = float(rgb.max()), float(rgb.min())
		if high >= GLOW_BRIGHT and (high - lowest) / max(high, 1e-4) <= GLOW_SATURATION:
			poly.material_index = 1
			count += 1
	log(f"glow: {count} of {len(mesh.polygons)} faces")
	return count


# --- making a part ----------------------------------------------------------------------------------

def make_part(source, budget, texture_px):
	"""A part's L0 from its high-poly (demo_props_blender.py `make_low`: decimated, from a voxel remesh where the
	decimator stops short), unwrapped and baked from the untouched high-poly. Returns (low, method, images)."""
	low, method = props.make_low(source, budget)
	material, images = props.low_material(texture_px)
	low.data.materials.append(material)
	_bake(source, low, material, images)
	return low, method, images


def _bake(src, low, material, images):
	"""demo_props_blender.py's bake (`bake_maps`) into an existing material and its images."""
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.device = "CPU"
	scene.cycles.samples = props.BAKE_SAMPLES
	size = float(max(np.ptp(props.vertex_array(src), axis=0)))
	bake = scene.render.bake
	bake.use_selected_to_active = True
	bake.cage_extrusion = size * props.CAGE_FRACTION
	bake.max_ray_distance = size * props.RAY_FRACTION
	bake.margin = props.BAKE_MARGIN_PX
	bpy.ops.object.select_all(action="DESELECT")
	src.select_set(True)
	low.select_set(True)
	bpy.context.view_layer.objects.active = low
	for key, kind in (("base", "DIFFUSE"), ("rough", "ROUGHNESS"), ("normal", "NORMAL")):
		material.node_tree.nodes.active = images[key]
		if kind == "DIFFUSE":
			bpy.ops.object.bake(type=kind, pass_filter={"COLOR"}, use_clear=True)
		else:
			bpy.ops.object.bake(type=kind, use_clear=True)
		images[key].image.pack()


def rename_images(images, prefix):
	"""Name a part's baked maps after it, so the GLB's extracted images do not collide."""
	for key, node in images.items():
		node.image.name = f"{prefix}_{key}"


# --- the job ----------------------------------------------------------------------------------------

def run(job):
	"""Load the source, edit it, make every part, rebase them together and export each."""
	src = props.load_source(job["source"])
	source_faces = len(src.data.polygons)
	dropped = 0
	for region in job.get("drop", []):
		doomed = in_region(src, region)
		dropped += int(doomed.sum())
		props.delete_faces(src, doomed)
	for axis, amount in zip((0, 2), job.get("stretch", [0.0, 0.0])):
		stretch(src, axis, float(amount))
	whole = props.vertex_array(src)
	base_z = float(whole[:, 2].min())
	centre_xy = (whole[:, :2].min(axis=0) + whole[:, :2].max(axis=0)) * 0.5
	specs = job["parts"]
	masks = part_masks(src, specs) if len(specs) > 1 else [None]
	result = {"source_faces": source_faces, "dropped": dropped, "parts": {}}
	for spec, mask in zip(specs, masks):
		high = make_source(src, spec, mask) if mask is not None else src
		low, method, images = make_part(high, spec["budget"], spec.get("texture_px", job["texture_px"]))
		rename_images(images, f"{job['key']}_{spec['name']}")
		row = {"method": method, "texture_px": spec.get("texture_px", job["texture_px"])}
		if job.get("glow"):
			row["glow_faces"] = split_glow(low, images)
		props.rebase(low, base_z, centre_xy)
		row.update(props.export_glb(low, spec["glb"]))
		result["parts"][spec["name"]] = row
		bpy.data.objects.remove(low)
		if high != src:
			bpy.data.objects.remove(high)
	rebased = whole.copy()
	rebased[:, 0] -= centre_xy[0]
	rebased[:, 1] -= centre_xy[1]
	rebased[:, 2] -= base_z
	result["aabb_min"] = [round(float(rebased[:, 0].min()), 4), 0.0, round(float(-rebased[:, 1].max()), 4)]
	result["aabb_max"] = [round(float(rebased[:, 0].max()), 4), round(float(rebased[:, 2].max()), 4),
		round(float(-rebased[:, 1].min()), 4)]
	result["offset"] = [round(float(-centre_xy[0]), 4), round(-base_z, 4), round(float(centre_xy[1]), 4)]
	return result


def main():
	"""Read the job, do it, print the result."""
	job = json.loads(open(sys.argv[sys.argv.index("--") + 1]).read())
	started = time.time()
	result = run(job)
	result["seconds"] = round(time.time() - started, 1)
	print("RESULT " + json.dumps(result), flush=True)


if __name__ == "__main__":
	main()
