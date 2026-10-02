"""Blender half of tools/make_art_pass3.py's kit steps (decision 0971). Headless; free; nothing wired in:

	blender --background --factory-startup --python tools/art_pass3_blender.py -- <job.json>

A job is {"step": ..., ...}. Steps:

  split_kit     The timber kit's L0 (one Meshy mesh of TWO pieces generated apart: an upright prop post and a
                lintel cap beam lying on the ground) cut into its pieces by connected parts. The two largest parts
                are the pieces; any crumb the decimator left loose joins the piece whose bounds are nearest. The
                taller-than-wide piece is the POST, the other the LINTEL. Meshy joined a second, thinner beam to the
                post's foot, lying along the ground (it is in no concept): `trim_post` keeps only the post's own
                column and closes its foot. Each piece is turned about the vertical so its long horizontal axis lies
                along glTF X (principal axes of its footprint), centred on X/Z with its bottom at y = 0. The lintel
                is sized here, at game scale: `lintel_length_m` across and `lintel_section_m` high (Meshy's beam is
                twice as deep as a cap over a 0.6 m post reads; its cross-section is squashed, its length is not).
                Both are exported with the kit's one baked material: `post_glb`, `lintel_glb`.
  assemble_set  One timber SET for the standard bore from the staged (game-scale) post and lintel: two posts,
                their outer faces on the bore floor's edges (+-`floor_half_m`), and the lintel across them seated on
                their shoulders (`shoulder_share` of the post's height: each tenon enters a housing), turned over
                (`flip_lintel`) if asked. One mesh, one material, its
                bottom at y = 0 and centred: the shape tunnel_marks.gd's `frame_fit` squeezes a brace into.

Coordinates in comments are glTF's (Y up, +Z front); Blender's are (x, -z, y). Prints "RESULT <json>".
"""

import json
import math
import os
import sys
import time

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import demo_props_blender as props  # noqa: E402  (its main() is guarded)


## Vertices this close (native glTF units) are one position when finding the kit's pieces.
WELD_M = 1e-5
## The post's own column: the footprint of its faces above this share of its height, grown by this share of its width.
COLUMN_FROM = 0.4
COLUMN_MARGIN = 0.12
## The shoulder search: slices of the post's height, and how wide (of the column) a slice must be to be shoulder.
SHOULDER_SLICES = 60
SHOULDER_WIDTH = 0.85


def log(message):
	"""Progress to stdout, flushed."""
	print(f"art_pass3: {message}", flush=True)


def parts_of(obj):
	"""Face indices of each connected part of `obj`'s mesh, largest first. Faces are connected through shared vertex
	POSITIONS, not shared vertices: the baked L0 splits its vertices at every UV seam (as glTF must), so linking
	through edges would find UV charts, not pieces."""
	co = props.vertex_array(obj)
	_, position = np.unique(np.round(co / WELD_M).astype(np.int64), axis=0, return_inverse=True)
	position = position.ravel()
	parent = np.arange(len(obj.data.polygons))
	def root(face):
		while parent[face] != face:
			parent[face] = parent[parent[face]]
			face = parent[face]
		return face
	first_face = {}
	for face in obj.data.polygons:
		for vertex in face.vertices:
			key = int(position[vertex])
			if key in first_face:
				a, b = root(face.index), root(first_face[key])
				if a != b:
					parent[a] = b
			else:
				first_face[key] = face.index
	groups = {}
	for face in range(len(parent)):
		groups.setdefault(root(face), []).append(face)
	return sorted(groups.values(), key=len, reverse=True)


def face_centres(obj):
	"""Every face's centre (Blender xyz) as an (n, 3) array."""
	count = len(obj.data.polygons)
	centres = np.empty(count * 3, dtype=np.float32)
	obj.data.polygons.foreach_get("center", centres)
	return centres.reshape(-1, 3)


def two_pieces(obj):
	"""Per face, 0 or 1: which of the two largest parts it belongs to (loose crumbs go to the nearer one)."""
	parts = parts_of(obj)
	if len(parts) < 2:
		raise SystemExit(f"the kit is one connected part ({len(parts[0])} faces): its pieces fused")
	centres = face_centres(obj)
	owner = np.full(len(centres), -1, dtype=np.int32)
	bounds = []
	for piece in (0, 1):
		owner[parts[piece]] = piece
		at = centres[parts[piece]]
		bounds.append((at.min(axis=0), at.max(axis=0)))
	for crumb in parts[2:]:
		middle = centres[crumb].mean(axis=0)
		gaps = [np.linalg.norm(np.maximum(0.0, np.maximum(lo - middle, middle - hi))) for lo, hi in bounds]
		owner[crumb] = int(np.argmin(gaps))
	log(f"{len(parts)} parts: pieces of {len(parts[0])} and {len(parts[1])} faces, {len(parts) - 2} crumbs")
	return owner


def piece_object(obj, owner, piece, name):
	"""A copy of `obj` holding only the faces of `piece`."""
	copy = obj.copy()
	copy.data = obj.data.copy()
	copy.name = name
	bpy.context.scene.collection.objects.link(copy)
	props.delete_faces(copy, owner != piece)
	return copy


def footprint_angle(obj):
	"""The angle (radians, about Blender Z) of the footprint's major principal axis."""
	co = props.vertex_array(obj)[:, :2]
	co = co - co.mean(axis=0)
	values, vectors = np.linalg.eigh(np.cov(co.T))
	major = vectors[:, int(np.argmax(values))]
	return math.atan2(float(major[1]), float(major[0]))


def lay_along_x(obj):
	"""Turn `obj` about the vertical so its footprint's long axis lies along X; bottom to 0, centred."""
	angle = footprint_angle(obj)
	obj.data.transform(Matrix.Rotation(-angle, 4, "Z"))
	obj.data.update()
	co = props.vertex_array(obj)
	props.rebase(obj, float(co[:, 2].min()))
	return math.degrees(angle)


def tallness(obj):
	"""Height over the longer side of the footprint: above 1 for the post, well under it for the lintel."""
	size = np.ptp(props.vertex_array(obj), axis=0)
	return size[2] / max(size[0], size[1])


def trim_post(obj):
	"""Cut away what Meshy grew out of the post's foot (a beam lying along the ground, joined to it): keep the faces
	whose centre stands within the post's own column -- the footprint of its faces above COLUMN_FROM of its
	height, grown by COLUMN_MARGIN of the column's width -- and close the hole left at its foot."""
	centres = face_centres(obj)
	z = centres[:, 2]
	upper = centres[z > z.min() + COLUMN_FROM * np.ptp(z)]
	lo, hi = upper[:, :2].min(axis=0), upper[:, :2].max(axis=0)
	margin = (hi - lo).max() * COLUMN_MARGIN
	inside = np.all((centres[:, :2] >= lo - margin) & (centres[:, :2] <= hi + margin), axis=1)
	props.delete_faces(obj, ~inside)
	mesh = bmesh.new()
	mesh.from_mesh(obj.data)
	filled = bmesh.ops.holes_fill(mesh, edges=mesh.edges, sides=0)
	mesh.to_mesh(obj.data)
	mesh.free()
	obj.data.update()
	log(f"post: cut {int((~inside).sum())} of {len(inside)} faces outside its column, filled {len(filled['faces'])}")
	return int((~inside).sum())


def stand_post(obj):
	"""Stand the post plumb: turn its major principal axis (it leans a few degrees as generated) onto the vertical."""
	co = props.vertex_array(obj)
	values, vectors = np.linalg.eigh(np.cov((co - co.mean(axis=0)).T))
	axis = Vector(vectors[:, int(np.argmax(values))].tolist())
	if axis.z < 0.0:
		axis.negate()
	lean = math.degrees(axis.angle(Vector((0.0, 0.0, 1.0))))
	obj.data.transform(axis.rotation_difference(Vector((0.0, 0.0, 1.0))).to_matrix().to_4x4())
	obj.data.update()
	return round(lean, 2)


def shoulder_share(obj):
	"""Where the post's shoulder is, as a share of its height: the highest SHOULDER_SLICES slice whose footprint is
	at least SHOULDER_WIDTH of the column's (its middle third's) -- the tenon above it is narrower. The set's lintel
	sits on the shoulder, so the tenon enters its housing."""
	co = props.vertex_array(obj)
	low, high = float(co[:, 2].min()), float(co[:, 2].max())
	height = high - low
	middle = co[(co[:, 2] > low + height / 3.0) & (co[:, 2] < low + 2.0 * height / 3.0)]
	column = np.ptp(middle[:, :2], axis=0).max()
	step = height / SHOULDER_SLICES
	for k in range(SHOULDER_SLICES, 0, -1):
		band = co[(co[:, 2] >= low + (k - 1) * step) & (co[:, 2] <= low + k * step)]
		if len(band) > 2 and np.ptp(band[:, :2], axis=0).max() >= SHOULDER_WIDTH * column:
			return round((k * step) / height, 4)
	return 1.0


def size_lintel(obj, length, section):
	"""Scale the lintel (already along X) to `length` across and its cross-section to `section` high, the depth by the
	same factor as the height; bottom to 0, centred."""
	size = np.ptp(props.vertex_array(obj), axis=0)
	across, up = length / size[0], section / size[2]
	obj.data.transform(Matrix.Diagonal((across, up, up, 1.0)))
	obj.data.update()
	props.rebase(obj, float(props.vertex_array(obj)[:, 2].min()))
	return round(float(up / across), 3)


def split_kit(job):
	"""The kit's L0 cut into its post and lintel (see the header)."""
	src = props.load_source(job["source"])
	owner = two_pieces(src)
	pieces = [piece_object(src, owner, piece, f"piece{piece}") for piece in (0, 1)]
	bpy.data.objects.remove(src)
	pieces.sort(key=tallness, reverse=True)
	result = {}
	for obj, role in zip(pieces, ("post", "lintel")):
		trimmed = trim_post(obj) if role == "post" and job.get("trim_post") else 0
		lean = stand_post(obj) if role == "post" else 0.0
		turned = lay_along_x(obj)
		squash = size_lintel(obj, job["lintel_length_m"], job["lintel_section_m"]) if role == "lintel" else 1.0
		row = props.export_glb(obj, job[f"{role}_glb"])
		row.update({"trimmed_faces": trimmed, "lean_deg": lean, "section_squash": squash})
		if role == "post":
			row["shoulder_share"] = shoulder_share(obj)
		row["turned_deg"] = round(turned, 2)
		row["tallness"] = round(float(tallness(obj)), 3)
		result[role] = row
	return result


def load_staged(path, name):
	"""Import a staged (already game-scale) GLB as one object named `name`."""
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=path)
	new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
	bpy.ops.object.select_all(action="DESELECT")
	for obj in new:
		obj.select_set(True)
	bpy.context.view_layer.objects.active = new[0]
	if len(new) > 1:
		bpy.ops.object.join()
	obj = bpy.context.view_layer.objects.active
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	for empty in [o for o in bpy.data.objects if o not in before and o.type != "MESH"]:
		bpy.data.objects.remove(empty)
	obj.name = name
	return obj


def assemble_set(job):
	"""Two posts and the lintel over them, joined into one mesh (see the header)."""
	bpy.ops.wm.read_factory_settings(use_empty=True)
	post = load_staged(job["post_glb"], "post_a")
	lintel = load_staged(job["lintel_glb"], "lintel")
	material = post.data.materials[0]
	lintel.data.materials.clear()
	lintel.data.materials.append(material)
	post_co = props.vertex_array(post)
	post_h = float(post_co[:, 2].max())
	post_half = float(np.ptp(post_co[:, 0])) * 0.5
	if job.get("flip_lintel"):
		lintel.data.transform(Matrix.Rotation(math.pi, 4, "X"))
		lintel_co = props.vertex_array(lintel)
		lintel.data.transform(Matrix.Translation((0.0, 0.0, -float(lintel_co[:, 2].min()))))
	lintel.data.transform(Matrix.Translation((0.0, 0.0, post_h * job["shoulder_share"])))
	other = post.copy()
	other.data = post.data.copy()
	bpy.context.scene.collection.objects.link(other)
	inset = job["floor_half_m"] - post_half
	post.data.transform(Matrix.Translation((-inset, 0.0, 0.0)))
	other.data.transform(Matrix.Translation((inset, 0.0, 0.0)))
	bpy.ops.object.select_all(action="DESELECT")
	for obj in (post, other, lintel):
		obj.select_set(True)
	bpy.context.view_layer.objects.active = post
	bpy.ops.object.join()
	joined = bpy.context.view_layer.objects.active
	props.rebase(joined, float(props.vertex_array(joined)[:, 2].min()))
	row = props.export_glb(joined, job["glb"])
	row.update({"post_height_m": round(post_h, 4), "post_centre_x_m": round(inset, 4)})
	return row


def main():
	"""Read the job, run its step, print the result."""
	job = json.loads(open(sys.argv[sys.argv.index("--") + 1]).read())
	started = time.time()
	steps = {"split_kit": split_kit, "assemble_set": assemble_set}
	result = steps[job["step"]](job)
	result["seconds"] = round(time.time() - started, 1)
	print("RESULT " + json.dumps(result), flush=True)


if __name__ == "__main__":
	main()
