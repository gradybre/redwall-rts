import bpy, mathutils, math, sys
out=sys.argv[sys.argv.index("--")+1]; clip=sys.argv[sys.argv.index("--")+2]
lib="/Users/brendan/Developer/redwall-rts/assets/library/creature"
keys=["mole_digger","mole_mason","mouse_keeper","mouse_fieldworker","squirrel_forester","squirrel_gatherer","otter_fisher","otter_boatwright","badger_cellarer","badger_quarryman"]
for o in list(bpy.data.objects): bpy.data.objects.remove(o, do_unlink=True)
sc=bpy.context.scene
for eng in ("BLENDER_EEVEE_NEXT","BLENDER_EEVEE"):
    try: sc.render.engine=eng; break
    except TypeError: pass
sc.render.resolution_x, sc.render.resolution_y = 1280, 560
sc.render.fps=24
x=0.0; maxlen=0; tallest=0
for k in keys:
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f"{lib}/{k}/anim_{clip}.glb")
    new=[o for o in bpy.data.objects if o not in before]
    for o in new:
        if o.type=="MESH" and o.name.startswith("Icosphere"): bpy.data.objects.remove(o, do_unlink=True)
    new=[o for o in bpy.data.objects if o not in before]
    arm=next(o for o in new if o.type=="ARMATURE")
    mesh=next(o for o in new if o.type=="MESH")
    w=max(mesh.dimensions.x,0.5); tallest=max(tallest,mesh.dimensions.z)
    arm.location.x = x + w/2
    x += w + 0.35
    act=arm.animation_data.action
    maxlen=max(maxlen,int(round(act.frame_range[1]-act.frame_range[0])))
span=x-0.35
# ground
bpy.ops.mesh.primitive_plane_add(size=1, location=(span/2,0,0)); g=bpy.context.object; g.scale=(span+6,8,1)
gm=bpy.data.materials.new("g"); gm.use_nodes=True
next(n for n in gm.node_tree.nodes if n.type=="BSDF_PRINCIPLED").inputs[0].default_value=(0.30,0.36,0.22,1)
g.data.materials.append(gm)
world=bpy.data.worlds.new("w"); sc.world=world; world.use_nodes=True
bg=next(n for n in world.node_tree.nodes if n.type=="BACKGROUND"); bg.inputs[0].default_value=(0.62,0.66,0.72,1); bg.inputs[1].default_value=1.0
sun=bpy.data.lights.new("s","SUN"); sun.energy=3.5; so=bpy.data.objects.new("s",sun); so.rotation_euler=(math.radians(55),0,math.radians(-35)); sc.collection.objects.link(so)
cam=bpy.data.cameras.new("c"); cam.type="ORTHO"; cam.ortho_scale=span+1.4
co=bpy.data.objects.new("c",cam); sc.collection.objects.link(co); sc.camera=co
target=mathutils.Vector((span/2,0,tallest*0.46))
el=math.radians(12); d=40
co.location=target+mathutils.Vector((0,-d*math.cos(el),d*math.sin(el)))
cam.clip_end=200
co.rotation_euler=(target-co.location).to_track_quat('-Z','Y').to_euler()
sc.frame_start=1; sc.frame_end=maxlen
sc.render.image_settings.file_format="PNG"
sc.render.filepath=out+"/f_"
bpy.ops.render.render(animation=True)
print("RENDERED",maxlen,"frames span",round(span,2),"tallest",round(tallest,2))
