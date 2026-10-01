"""Blender half of tools/make_demo_weir.py. Decision 0301 (review F41). Runs headless:

	blender --background --factory-startup --python tools/demo_weir_blender.py -- <job.json>

Do not run this directly; make_demo_weir.py writes the job and reads the result. The job names the
library weir's L0 (a diorama: a timber weir wall with its sluice gate and stone piers, standing in its
own earth slab with its own baked pool and tail water) and asks for the STRUCTURE alone:

  * every face whose base-colour texel is water-blue (blue over red by WATER_BLUE_OVER_RED) goes: the
    pool, the tail water and the sluice's white water;
  * of the rest, a face is kept only if every corner lies in the structure's own region -- the wall's
    band across the model (WALL_BAND_Z, the gate and its wheel included) or one of the three downstream
    stone piers (PIERS) -- so the slab's long side and bottom triangles, which cross that region, go too;
  * the slab's bottom (every corner below BOTTOM_Y) and the pool's fringe on the upstream side (every
    corner upstream of POOL_SIDE_Z and below POOL_TOP_Y) go;
  * the mesh is then CUT through at each of CUTS (planes of constant x), so that no triangle straddles
    one: godot/demo/water/weir_fit.gd moves the parts beyond the outer cuts out to the banks and fills
    the gaps with copies of the plain wall between the inner two.

Nothing is decimated, re-UVed or rebaked: the kept faces keep the L0's own UVs and maps. One stone texel
patch is measured for the sill weir_fit.gd builds under the wall (`stone_uv`: [u0, v0, u1, v1] in glTF's
UV convention, about the UV centre of the largest grey, upward face on the middle pier). Coordinates in the job and the result are glTF's (Y up,
+Z the model's front: downstream). It prints one line "RESULT <json>" for the caller.
"""

import json
import os
import sys
import time

import bmesh
import bpy
from mathutils import Vector

## A texel is water when its blue exceeds its red by this much (the slab's earths and the timber are
## red over blue; the stones are grey, red at or over blue).
WATER_BLUE_OVER_RED = 0.02
## The structure's region, glTF units: the wall's band across the whole model, and three piers (x range,
## z range) downstream of it. A face is kept only with every corner inside, PAD included.
WALL_BAND_Z = (-0.095, 0.085)
WALL_SPAN_X = (-0.96, 0.96)
PIERS = (((-0.76, -0.50), (0.04, 0.48)), ((-0.07, 0.15), (0.04, 0.74)), ((0.57, 0.77), (0.08, 0.64)))
PAD = 0.03
## The slab's bottom, and the pool's fringe upstream (-z) of the wall below the pool's surface.
BOTTOM_Y = 0.03
POOL_SIDE_Z = -0.02
POOL_TOP_Y = 0.47
## A stone patch for the sill: grey (channels within this of each other, at least this bright) and up.
STONE_SPREAD = 0.07
STONE_BRIGHT = 0.42
STONE_UV_HALF = 0.008


def log(message):
	"""Progress to stdout, flushed."""
	print(f"demo_weir: {message}", flush=True)


def gltf(co):
	"""A Blender (Z up, -Y front) point in glTF axes (Y up, +Z front)."""
	return Vector((co.x, co.z, -co.y))


def load(path):
	"""Import the L0 into an empty scene: its one mesh object, transforms applied."""
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=path)
	meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
	if len(meshes) != 1:
		raise SystemExit(f"expected one mesh in {path}, found {len(meshes)}")
	obj = meshes[0]
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	return obj


def base_colour(obj):
	"""The base-colour image's size and pixels (flat RGBA floats)."""
	tree = obj.data.materials[0].node_tree
	principled = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
	image = principled.inputs["Base Color"].links[0].from_node.image
	return image.size[0], image.size[1], image.pixels[:]


def texel(width, height, pixels, uv):
	"""The RGB texel under a UV."""
	x = min(width - 1, max(0, int((uv.x % 1.0) * width)))
	y = min(height - 1, max(0, int((uv.y % 1.0) * height)))
	i = (y * width + x) * 4
	return Vector(pixels[i:i + 3])


def face_colour(face, uv_layer, image):
	"""The mean texel over a face: its corners pulled 40% toward its UV centre, and the centre."""
	corners = [loop[uv_layer].uv.copy() for loop in face.loops]
	centre = sum(corners, Vector((0.0, 0.0))) / len(corners)
	total = Vector((0.0, 0.0, 0.0))
	for uv in corners + [centre]:
		total += texel(*image, centre.lerp(uv, 0.6))
	return total / (len(corners) + 1)


def in_region(p):
	"""Whether a glTF point lies in the structure's region (see WALL_BAND_Z, PIERS)."""
	if WALL_BAND_Z[0] - PAD <= p.z <= WALL_BAND_Z[1] + PAD and WALL_SPAN_X[0] <= p.x <= WALL_SPAN_X[1]:
		return True
	return any(x[0] - PAD <= p.x <= x[1] + PAD and z[0] - PAD <= p.z <= z[1] + PAD for x, z in PIERS)


def verdict(face, colour):
	"""Why a face goes ("water", "slab"), or "" to keep it."""
	if colour.z > colour.x + WATER_BLUE_OVER_RED:
		return "water"
	corners = [gltf(v.co) for v in face.verts]
	if all(p.y < BOTTOM_Y for p in corners):
		return "slab"
	if all(p.z < POOL_SIDE_Z and p.y < POOL_TOP_Y for p in corners):
		return "slab"
	return "" if all(in_region(p) for p in corners) else "slab"


def stone_uv(bm, uv_layer, image):
	"""The UV centre of the largest grey, upward face on the middle pier (the sill's stone patch)."""
	best, best_area = None, 0.0
	pier_x, pier_z = PIERS[1]
	for face in bm.faces:
		p = gltf(face.calc_center_median())
		n = gltf(face.normal)
		if not (pier_x[0] <= p.x <= pier_x[1] and pier_z[0] <= p.z <= pier_z[1]) or n.y < 0.7:
			continue
		c = face_colour(face, uv_layer, image)
		if max(c) - min(c) > STONE_SPREAD or max(c) < STONE_BRIGHT or face.calc_area() <= best_area:
			continue
		best, best_area = face, face.calc_area()
	if best is None:
		raise SystemExit("no stone face found on the middle pier")
	centre = sum((loop[uv_layer].uv for loop in best.loops), Vector((0.0, 0.0))) / len(best.loops)
	## Blender's V runs up, glTF's (and Godot's) down: the patch is reported in glTF's convention.
	v = 1.0 - centre.y
	return [round(centre.x - STONE_UV_HALF, 5), round(v - STONE_UV_HALF, 5),
		round(centre.x + STONE_UV_HALF, 5), round(v + STONE_UV_HALF, 5)]


def strip(obj, cuts):
	"""Delete the water and the slab, cut through at each x in `cuts`; return the counts and the stone
	patch."""
	bm = bmesh.new()
	bm.from_mesh(obj.data)
	bm.faces.ensure_lookup_table()
	uv_layer = bm.loops.layers.uv.active
	image = base_colour(obj)
	counts = {"water": 0, "slab": 0}
	doomed = []
	for face in bm.faces:
		why = verdict(face, face_colour(face, uv_layer, image))
		if why:
			counts[why] += 1
			doomed.append(face)
	patch = stone_uv(bm, uv_layer, image)
	bmesh.ops.delete(bm, geom=doomed, context="FACES")
	for x in cuts:
		geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
		bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector((x, 0.0, 0.0)), plane_no=Vector((1.0, 0.0, 0.0)))
	bmesh.ops.triangulate(bm, faces=bm.faces[:])
	bm.to_mesh(obj.data)
	obj.data.update()
	bm.free()
	return counts, patch


def export(obj, path):
	"""Export `obj` alone as a Y-up GLB with its maps; return its glTF bounds and triangle count."""
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True)
	corners = [gltf(v.co) for v in obj.data.vertices]
	lo = [min(p[i] for p in corners) for i in range(3)]
	hi = [max(p[i] for p in corners) for i in range(3)]
	return {"aabb_min": [round(v, 4) for v in lo], "aabb_max": [round(v, 4) for v in hi],
		"triangles": len(obj.data.polygons), "bytes": os.path.getsize(path)}


def main():
	"""Read the job, strip and cut the weir, export it, print the result."""
	job = json.loads(open(sys.argv[sys.argv.index("--") + 1]).read())
	started = time.time()
	obj = load(job["source"])
	before = len(obj.data.polygons)
	counts, patch = strip(obj, job["cuts"])
	log(f"{before} faces: {counts['water']} water, {counts['slab']} slab removed")
	result = export(obj, job["glb"])
	result.update({"source_faces": before, "removed": counts, "stone_uv": patch, "cuts": job["cuts"],
		"seconds": round(time.time() - started, 1)})
	print("RESULT " + json.dumps(result), flush=True)


if __name__ == "__main__":
	main()
