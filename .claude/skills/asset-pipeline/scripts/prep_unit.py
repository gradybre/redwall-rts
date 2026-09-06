"""Normalise a Meshy-generated GLB into a Godot-ready unit asset.

Run headless, no Blender MCP connection required:

    blender --background --python prep_unit.py -- IN.glb OUT.glb --height 0.55

What it fixes, and why each step exists:

1. Axis. Meshy writes its GLB Z-up, which violates the glTF spec's Y-up
   convention. Blender's importer applies its standard Y-up -> Z-up rotation
   regardless, so the model arrives lying on its back. We rotate +90 deg about
   X and APPLY it, baking the fix into the mesh data.
2. Scale. Meshy returns arbitrary sizes (~2.0 units for a mouse). Units must be
   normalised per size tier or squads will not read correctly beside each other.
3. Origin. Meshy's origin_at="bottom" is silently ignored unless auto_size is
   true, so the pivot lands on the centroid. RTS units need the pivot at the
   feet or they sink into terrain.
4. Export. Blender's exporter with export_yup=True performs the spec-correct
   Z-up -> Y-up conversion on the way out.

Exit code is 0 on success, 1 on any failed verification.
"""

import argparse
import os
import sys

import bpy
import mathutils


def parse_args() -> argparse.Namespace:
    """Read args appearing after the `--` separator Blender uses."""
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(prog="prep_unit.py")
    parser.add_argument("input")
    parser.add_argument("output")
    parser.add_argument("--height", type=float, required=True,
                        help="Target height in metres (see the tier table in SKILL.md)")
    parser.add_argument("--no-rotate", action="store_true",
                        help="Skip the Z-up correction (for an input already Y-up)")
    return parser.parse_args(argv)


def clear_scene() -> None:
    """Empty the startup scene so only the imported unit remains."""
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def import_and_join(path: str) -> bpy.types.Object:
    """Import the GLB and return a single joined mesh object."""
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        raise SystemExit("FAIL: no mesh found in %s" % path)
    bpy.ops.object.select_all(action="DESELECT")
    for mesh in meshes:
        mesh.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    return bpy.context.view_layer.objects.active


def stand_upright(obj: bpy.types.Object) -> None:
    """Rotate the Z-up import onto Blender's Z axis and bake the rotation in."""
    import math
    obj.rotation_euler = (math.radians(90), 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)


def scale_to_height(obj: bpy.types.Object, target: float) -> float:
    """Uniformly scale so the object stands `target` metres tall. Returns the factor."""
    current = obj.dimensions.z
    if current <= 0.0:
        raise SystemExit("FAIL: model has zero height; cannot scale")
    factor = target / current
    obj.scale = (factor, factor, factor)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return factor


def origin_to_feet(obj: bpy.types.Object) -> None:
    """Move the pivot to the bottom centre and place it at the world origin."""
    corners = [obj.matrix_world @ mathutils.Vector(c) for c in obj.bound_box]
    cursor = bpy.context.scene.cursor
    cursor.location = (
        sum(v.x for v in corners) / 8.0,
        sum(v.y for v in corners) / 8.0,
        min(v.z for v in corners),
    )
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    obj.location = (0.0, 0.0, 0.0)
    cursor.location = (0.0, 0.0, 0.0)
    # matrix_world is stale until the depsgraph catches up; without this the
    # verification below reads pre-move values and reports a false failure.
    bpy.context.view_layer.update()


def export_glb(obj: bpy.types.Object, path: str) -> None:
    """Export the single object as a Y-up GLB for Godot."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
    )


def verify(obj: bpy.types.Object, target: float) -> bool:
    """Report the finished state and whether it meets the pipeline contract."""
    bpy.context.view_layer.update()
    corners = [obj.matrix_world @ mathutils.Vector(c) for c in obj.bound_box]
    min_z = min(v.z for v in corners)
    height = max(v.z for v in corners) - min_z
    dims = obj.dimensions

    upright = dims.z >= dims.y
    at_height = abs(height - target) < 0.001
    at_origin = abs(min_z) < 0.0001

    print("  dimensions X/Y/Z: %.4f %.4f %.4f" % (dims.x, dims.y, dims.z))
    print("  height: %.4f m (target %.4f)  %s" % (height, target, "OK" if at_height else "MISMATCH"))
    print("  feet at Z=0: %s  (min_z %.6f)" % ("OK" if at_origin else "NO", min_z))
    print("  upright (Z >= Y): %s" % ("OK" if upright else "NO"))
    print("  triangles: %d" % len(obj.data.polygons))
    return at_height and at_origin and upright


def main() -> None:
    """Run the full normalisation and exit non-zero if verification fails."""
    args = parse_args()
    if not os.path.exists(args.input):
        raise SystemExit("FAIL: input not found: %s" % args.input)

    clear_scene()
    obj = import_and_join(args.input)
    print("imported: %s (%d tris)" % (os.path.basename(args.input), len(obj.data.polygons)))
    print("  raw dimensions X/Y/Z: %.4f %.4f %.4f" % tuple(obj.dimensions))

    if not args.no_rotate:
        stand_upright(obj)
    factor = scale_to_height(obj, args.height)
    print("  scale factor: %.5f" % factor)
    origin_to_feet(obj)

    ok = verify(obj, args.height)
    export_glb(obj, args.output)
    print("exported: %s (%d bytes)" % (args.output, os.path.getsize(args.output)))
    if not ok:
        raise SystemExit("FAIL: verification did not pass")
    print("OK")


main()
