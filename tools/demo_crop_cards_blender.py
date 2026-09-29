"""Blender half of tools/make_demo_crop_cards.py. Decision 0196 (live demo). Runs headless:

	blender --background --factory-startup --python tools/demo_crop_cards_blender.py -- <job.json>

Do not run this directly; make_demo_crop_cards.py writes the job and reads the result. The job
names ONE high-poly source and asks for any of:

  "cards": a list of atlases. Each renders regions of the source's plants, each into one cell of
	an RGBA atlas, from the "front" (standing cards) or from the "top" (the canopy seen from an
	RTS camera, which standing cards cannot show). The render is orthographic, through a transparent film, with the source's own base-colour map
	wired straight to emission and the Standard view transform -- so every pixel is the
	authored albedo, unlit, and the engine lights the card. A region is isolated by copying the
	source's leaves and stalks (separate loose shells in Meshy's output) whose centres fall in its
	box, so no leaf is cut; a plant region first snaps its box onto the nearest crown. Anything
	below the soil cut is shaded transparent. Transparent pixels are then filled with the nearest
	opaque colour so mipmaps and filtering never pull a dark fringe into the edges.
  "bed": cut every face above a height off the source (the plants), decimate what is left
	(the wooden frame and the soil), set its base at y = 0, and export it as a GLB with the
	source's own maps.

Coordinates in the job are glTF's (Y up, +Z front), as the manifest and Godot use; the script
converts to Blender's Z-up internally. It prints one line "RESULT <json>" for the caller.
"""

import json
import sys
import time

import bpy
import numpy as np

CARD_SAMPLES = 24
DILATE_PASSES = 24


def log(message):
	"""Progress to stdout, flushed, so a long run is visibly alive."""
	print(f"demo_crop_cards: {message}", flush=True)


def load_source(path):
	"""Import the glTF into an empty scene; return its single mesh object."""
	bpy.ops.wm.read_factory_settings(use_empty=True)
	started = time.time()
	bpy.ops.import_scene.gltf(filepath=path)
	meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
	if len(meshes) != 1:
		raise SystemExit(f"expected one mesh in {path}, found {len(meshes)}")
	obj = meshes[0]
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	log(f"imported {path} in {time.time() - started:.1f}s")
	return obj


def restore_material(material):
	"""Undo box_mask_material: the Principled BSDF drives the output again."""
	nt = material.node_tree
	for node in [n for n in nt.nodes if n.name.startswith("card_")]:
		nt.nodes.remove(node)
	bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
	output = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
	nt.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])


def base_colour_node(material):
	"""The image node feeding the Principled BSDF's base colour."""
	bsdf = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
	links = bsdf.inputs["Base Color"].links
	if not links:
		raise SystemExit(f"material {material.name} has no base-colour map")
	return links[0].from_node


def soil_mask_material(material, soil_y):
	"""Rewire `material` to unlit albedo above `soil_y` (glTF y), fully transparent below."""
	nt = material.node_tree
	image = base_colour_node(material)
	for node in [n for n in nt.nodes if n.name.startswith("card_")]:
		nt.nodes.remove(node)
	geometry = nt.nodes.new("ShaderNodeNewGeometry")
	geometry.name = "card_geometry"
	split = nt.nodes.new("ShaderNodeSeparateXYZ")
	split.name = "card_split"
	nt.links.new(geometry.outputs["Position"], split.inputs["Vector"])
	above = _math(nt, "GREATER_THAN", split.outputs["Z"], float(soil_y), "soil")
	emission = nt.nodes.new("ShaderNodeEmission")
	emission.name = "card_emission"
	nt.links.new(image.outputs["Color"], emission.inputs["Color"])
	clear = nt.nodes.new("ShaderNodeBsdfTransparent")
	clear.name = "card_clear"
	mix = nt.nodes.new("ShaderNodeMixShader")
	mix.name = "card_mix"
	nt.links.new(above, mix.inputs["Fac"])
	nt.links.new(clear.outputs["BSDF"], mix.inputs[1])
	nt.links.new(emission.outputs["Emission"], mix.inputs[2])
	output = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
	nt.links.new(mix.outputs["Shader"], output.inputs["Surface"])


def _math(nt, operation, a, b, tag):
	"""One Math node; each input is a socket or a constant."""
	node = nt.nodes.new("ShaderNodeMath")
	node.name = f"card_{tag}_{operation}_{len(nt.nodes)}"
	node.operation = operation
	for index, value in enumerate((a, b)):
		if isinstance(value, float):
			node.inputs[index].default_value = value
		else:
			nt.links.new(value, node.inputs[index])
	return node.outputs["Value"]


class Source:
	"""The source mesh as flat arrays, read once: triangles, vertex ids, UVs, centres."""

	def __init__(self, obj):
		mesh = obj.data
		mesh.calc_loop_triangles()
		count = len(mesh.loop_triangles)
		self.tri_verts = _read(mesh.loop_triangles, "vertices", count * 3, np.int32).reshape(-1, 3)
		self.tri_loops = _read(mesh.loop_triangles, "loops", count * 3, np.int32).reshape(-1, 3)
		self.co = _read(mesh.vertices, "co", len(mesh.vertices) * 3, np.float32).reshape(-1, 3)
		self.uv = _read(mesh.uv_layers.active.data, "uv", len(mesh.loops) * 2, np.float32).reshape(-1, 2)
		self.centre = self.co[self.tri_verts].mean(axis=1)
		# Components follow the file's own vertex sharing. Welding by position was tried and is
		# wrong: leaves touch the soil, and welding joins the whole bed into one component.
		self.material = mesh.materials[0]


def _read(collection, attribute, size, dtype):
	"""foreach_get into a new flat array."""
	data = np.empty(size, dtype=dtype)
	collection.foreach_get(attribute, data)
	return data


def components(tris):
	"""Connected-component label per triangle, for triangles given as welded vertex ids."""
	ids, local = np.unique(tris.ravel(), return_inverse=True)
	local = local.reshape(-1, 3)
	label = np.arange(len(ids), dtype=np.int64)
	edges = np.concatenate([local[:, [0, 1]], local[:, [1, 2]], local[:, [2, 0]]])
	while True:
		lowest = np.minimum(label[edges[:, 0]], label[edges[:, 1]])
		updated = label.copy()
		np.minimum.at(updated, edges[:, 0], lowest)
		np.minimum.at(updated, edges[:, 1], lowest)
		while True:
			jumped = updated[updated]
			if np.array_equal(jumped, updated):
				break
			updated = jumped
		if np.array_equal(updated, label):
			break
		label = updated
	return label[local[:, 0]]


def _pick(src, near, region):
	"""Of the triangles in `near`, the ones whose whole leaf or stalk is centred in the box."""
	tris = np.flatnonzero(near)
	part = components(src.tri_verts[tris])
	_, part = np.unique(part, return_inverse=True)
	weight = np.bincount(part)
	centre_x = np.bincount(part, src.centre[tris, 0]) / weight
	centre_z = np.bincount(part, -src.centre[tris, 1]) / weight
	top = np.full(weight.shape, -np.inf)
	np.maximum.at(top, part, src.centre[tris, 2])
	bottom = np.full(weight.shape, np.inf)
	np.minimum.at(bottom, part, src.centre[tris, 2])
	cx, cz = region["centre"]
	if region.get("snap"):
		cx, cz = _snap_to_crown(centre_x, centre_z, bottom, top, weight, region)
	hx, hz = region["half"]
	keep = (np.abs(centre_x - cx) < hx) & (np.abs(centre_z - cz) < hz) & (top > region["soil_y"] + 0.02)
	return tris[keep[part]], (float(cx), float(cz)), int(keep.sum())


def _snap_to_crown(centre_x, centre_z, bottom, top, weight, region):
	"""The nearest crown -- a sizeable part that crosses the soil -- within `snap` of the guess."""
	soil = region["soil_y"]
	crown = (bottom < soil - 0.005) & (top > soil + 0.02) & (weight > 200)
	distance = np.hypot(centre_x - region["centre"][0], centre_z - region["centre"][1])
	distance[~crown] = np.inf
	best = int(np.argmin(distance))
	if distance[best] > region["snap"]:
		return tuple(region["centre"])
	return centre_x[best], centre_z[best]


def isolate_region(src, region):
	"""Whole leaves and stalks whose centre lies in the region's box, as a new object.

	A mask would cut every leaf that crosses the box edge into a straight line. Selecting whole
	connected shells (Meshy's plants are many separate leaf and stalk shells) by where their
	centre falls keeps each leaf intact, so the card's silhouette is the plants' own.
	"""
	reach = max(region["half"]) + region["reach"]
	cx, cz = region["centre"]
	near = (np.abs(src.centre[:, 0] - cx) < reach) & (np.abs(-src.centre[:, 1] - cz) < reach)
	tris, centre, pieces = _pick(src, near, region)
	used, local = np.unique(src.tri_verts[tris].ravel(), return_inverse=True)
	mesh = bpy.data.meshes.new("card_plant")
	mesh.vertices.add(len(used))
	mesh.vertices.foreach_set("co", src.co[used].ravel())
	mesh.loops.add(len(tris) * 3)
	mesh.loops.foreach_set("vertex_index", local.astype(np.int32))
	mesh.polygons.add(len(tris))
	mesh.polygons.foreach_set("loop_start", np.arange(0, len(tris) * 3, 3, dtype=np.int32))
	mesh.polygons.foreach_set("loop_total", np.full(len(tris), 3, dtype=np.int32))
	layer = mesh.uv_layers.new(name="UVMap")
	layer.data.foreach_set("uv", src.uv[src.tri_loops[tris].ravel()].ravel())
	mesh.materials.append(src.material)
	mesh.update()
	plant = bpy.data.objects.new("card_plant", mesh)
	bpy.context.scene.collection.objects.link(plant)
	return plant, centre, pieces


def setup_render():
	"""Cycles on the CPU, transparent film, Standard view: the pixels are the albedo."""
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	scene.cycles.device = "CPU"
	scene.cycles.samples = CARD_SAMPLES
	scene.cycles.use_denoising = False
	scene.cycles.transparent_max_bounces = 256
	scene.cycles.max_bounces = 0
	scene.render.film_transparent = True
	scene.render.resolution_percentage = 100
	scene.view_settings.view_transform = "Standard"
	scene.view_settings.look = "None"
	scene.render.image_settings.file_format = "PNG"
	scene.render.image_settings.color_mode = "RGBA"
	camera = bpy.data.objects.new("card_camera", bpy.data.cameras.new("card_camera"))
	camera.data.type = "ORTHO"
	camera.data.sensor_fit = "AUTO"
	camera.data.clip_start = 0.001
	camera.data.clip_end = 100.0
	scene.collection.objects.link(camera)
	scene.camera = camera
	return camera


def aim_camera(camera, view, centre, soil_y, cell_m):
	"""Orthographic. "front": along glTF -Z, the cell standing on the soil. "top": straight down.

	A top cell's image has glTF -Z at its top edge and +X to the right.
	"""
	camera.data.ortho_scale = max(cell_m)
	if view == "top":
		camera.rotation_euler = (0.0, 0.0, 0.0)
		camera.location = (centre[0], -centre[1], 10.0)
		return
	# Blender: camera at -y looks along +y with rotation (90deg, 0, 0); glTF front is Blender -y.
	camera.rotation_euler = (np.pi / 2.0, 0.0, 0.0)
	camera.location = (centre[0], -10.0, soil_y + cell_m[1] * 0.5)


def read_pixels(path, size):
	"""A rendered PNG as a float array (h, w, 4), straight alpha, as stored."""
	image = bpy.data.images.load(path)
	data = np.empty(size[0] * size[1] * 4, dtype=np.float32)
	image.pixels.foreach_get(data)
	bpy.data.images.remove(image)
	return data.reshape(size[1], size[0], 4)


def dilate(rgba):
	"""Fill every transparent pixel's colour from its opaque neighbours (alpha untouched)."""
	colour = rgba[..., :3].copy()
	known = rgba[..., 3] > 0.5
	for _ in range(DILATE_PASSES):
		total = np.zeros_like(colour)
		count = np.zeros(known.shape, dtype=np.float32)
		for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
			shifted_known = _shift(known, dy, dx)
			total += _shift(colour, dy, dx) * shifted_known[..., None]
			count += shifted_known
		grow = (~known) & (count > 0)
		colour[grow] = total[grow] / count[grow][:, None]
		known = known | grow
	out = rgba.copy()
	out[..., :3] = colour
	return out


def _shift(array, dy, dx):
	"""`array` moved by (dy, dx) pixels, zero-filled at the edges (no wrap-around)."""
	out = np.zeros_like(array)
	height, width = array.shape[:2]
	out[max(dy, 0):height + min(dy, 0), max(dx, 0):width + min(dx, 0)] = \
		array[max(-dy, 0):height + min(-dy, 0), max(-dx, 0):width + min(-dx, 0)]
	return out


def save_atlas(cells, path):
	"""Cells side by side, left to right, as one RGBA PNG."""
	atlas = np.concatenate(cells, axis=1)
	height, width = atlas.shape[:2]
	image = bpy.data.images.new("card_atlas", width, height, alpha=True)
	image.pixels.foreach_set(atlas.ravel())
	image.filepath_raw = path
	image.file_format = "PNG"
	image.save()


def make_cards(obj, job):
	"""Render every atlas the job asks for; return each atlas's metadata."""
	camera = setup_render()
	obj.hide_render = True
	src = Source(obj)
	for material in obj.data.materials:
		soil_mask_material(material, job["cards"][0]["regions"][0]["soil_y"])
	results = [make_atlas(src, camera, spec) for spec in job["cards"]]
	obj.hide_render = False
	return results


def make_atlas(src, camera, spec):
	"""Render every region of one atlas into its own cell, left to right."""
	scene = bpy.context.scene
	scene.render.resolution_x, scene.render.resolution_y = spec["cell_px"]
	cells, centres = [], []
	for index, region in enumerate(spec["regions"]):
		plant, centre, pieces = isolate_region(src, region)
		aim_camera(camera, spec["view"], centre, region["soil_y"], spec["cell_m"])
		frame = f"{spec['atlas']}.cell{index}.png"
		scene.render.filepath = frame
		started = time.time()
		bpy.ops.render.render(write_still=True)
		log(f"{spec['view']} card {index} ({region.get('kind', '')}): {pieces} parts, "
			f"{len(plant.data.polygons)} faces at {centre[0]:.3f}, {centre[1]:.3f}, {time.time() - started:.1f}s")
		cells.append(dilate(read_pixels(frame, spec["cell_px"])))
		centres.append([round(centre[0], 4), round(centre[1], 4)])
		bpy.data.meshes.remove(plant.data)
	save_atlas(cells, spec["atlas"])
	return {"atlas": spec["atlas"], "variants": len(cells), "centres": centres}


def make_bed(obj, job):
	"""Cut the plants off, decimate the frame and soil, base it at y = 0, export a GLB.

	Two cuts. Everything above `cut_y` (the frame's top) goes. Below it, what is left of the
	plants -- carrot shoulders, leaves lying on the soil -- is found by COLOUR: inside the frame,
	a face whose base-colour texel is a saturated leaf green, carrot orange or turnip purple is a
	plant, not soil. (Meshy's mesh is split at every UV island, so its connected parts say
	nothing about which faces are plants.) The holes this leaves are filled by the dark soil
	underlay the demo lays at the soil height.
	"""
	spec = job["bed"]
	for material in obj.data.materials:
		restore_material(material)
	centres, plant = _face_colours(obj)
	inside = np.maximum(np.abs(centres[:, 0]), np.abs(centres[:, 1])) < spec["inner_half"]
	doomed = (centres[:, 2] > spec["cut_y"]) | (inside & plant)
	_delete_faces(obj, doomed)
	log(f"bed: cut {int(doomed.sum())} of {len(doomed)} faces ({int((inside & plant).sum())} plant-coloured)")
	_decimate(obj, spec["target_triangles"])
	lifted_by = _rebase(obj)
	result = _export_bed(obj, spec["glb"])
	result["lifted_by"] = round(lifted_by, 4)
	return result


def _face_colours(obj):
	"""Per face: its centre (Blender xyz) and whether its texel reads as plant, not soil or wood."""
	mesh = obj.data
	count = len(mesh.polygons)
	centres = _read(mesh.polygons, "center", count * 3, np.float32).reshape(-1, 3)
	starts = _read(mesh.polygons, "loop_start", count, np.int32)
	uv = _read(mesh.uv_layers.active.data, "uv", len(mesh.loops) * 2, np.float32).reshape(-1, 2)
	image = base_colour_node(mesh.materials[0]).image
	width, height = image.size
	pixels = np.empty(width * height * 4, dtype=np.float32)
	image.pixels.foreach_get(pixels)
	pixels = pixels.reshape(height, width, 4)
	at = uv[starts] % 1.0
	rgb = pixels[(at[:, 1] * (height - 1)).astype(int), (at[:, 0] * (width - 1)).astype(int), :3]
	return centres, _plant_coloured(rgb)


def _plant_coloured(rgb):
	"""Leaf green, carrot orange or turnip purple, saturated enough that it is not soil or wood."""
	high = rgb.max(axis=1)
	low = rgb.min(axis=1)
	saturation = (high - low) / np.maximum(high, 1e-4)
	r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
	green = (g >= r) & (g >= b)
	orange = (r > g * 1.5) & (r > b * 2.0)
	purple = (b > g * 1.2) & (r > g * 1.2)
	return (saturation > 0.3) & (high > 0.08) & (green | orange | purple)


def _delete_faces(obj, doomed):
	"""Delete the faces flagged in `doomed`."""
	bpy.context.view_layer.objects.active = obj
	obj.select_set(True)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="DESELECT")
	bpy.ops.object.mode_set(mode="OBJECT")
	obj.data.polygons.foreach_set("select", doomed)
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.delete(type="FACE")
	bpy.ops.object.mode_set(mode="OBJECT")


def _decimate(obj, target):
	"""Collapse-decimate to about `target` triangles, keeping UVs."""
	triangles = sum(len(p.vertices) - 2 for p in obj.data.polygons)
	modifier = obj.modifiers.new("decimate", "DECIMATE")
	modifier.decimate_type = "COLLAPSE"
	modifier.ratio = min(1.0, target / max(triangles, 1))
	modifier.use_collapse_triangulate = True
	bpy.ops.object.modifier_apply(modifier=modifier.name)
	log(f"bed: decimated {triangles} -> {len(obj.data.polygons)} faces")


def _rebase(obj):
	"""Move the mesh so its lowest point is at height 0; return how far it moved up."""
	count = len(obj.data.vertices)
	co = np.empty(count * 3, dtype=np.float32)
	obj.data.vertices.foreach_get("co", co)
	co = co.reshape(-1, 3)
	lowest = float(co[:, 2].min())
	co[:, 2] -= lowest
	obj.data.vertices.foreach_set("co", co.ravel())
	obj.data.update()
	return -lowest


def _export_bed(obj, path):
	"""Export only the bed, Y-up glTF binary with its maps; return its glTF-space bounds."""
	bpy.ops.object.select_all(action="DESELECT")
	obj.select_set(True)
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
		export_yup=True, export_apply=True)
	count = len(obj.data.vertices)
	co = np.empty(count * 3, dtype=np.float32)
	obj.data.vertices.foreach_get("co", co)
	co = co.reshape(-1, 3)
	lo = [float(co[:, 0].min()), float(co[:, 2].min()), float(-co[:, 1].max())]
	hi = [float(co[:, 0].max()), float(co[:, 2].max()), float(-co[:, 1].min())]
	return {"glb": path, "aabb_min": [round(v, 4) for v in lo], "aabb_max": [round(v, 4) for v in hi],
		"triangles": len(obj.data.polygons)}


def main():
	"""Read the job, do what it asks, print the result."""
	job = json.loads(open(sys.argv[sys.argv.index("--") + 1]).read())
	obj = load_source(job["source"])
	result = {}
	if "cards" in job:
		result["cards"] = make_cards(obj, job)
	if "bed" in job:
		result["bed"] = make_bed(obj, job)
	print("RESULT " + json.dumps(result), flush=True)


# Guarded so tools/demo_props_blender.py can import the card helpers without running a job.
if __name__ == "__main__":
	main()
