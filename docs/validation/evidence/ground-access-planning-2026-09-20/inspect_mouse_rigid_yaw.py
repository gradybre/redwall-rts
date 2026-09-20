"""Extract actual GLB float32 vertex bounds; static source diagnostic only."""
from pathlib import Path
import struct,json,hashlib,math
r=Path(__file__).resolve().parents[4];rel='godot/assets/units/species_mouse_body_a_lod0.glb';b=(r/rel).read_bytes();magic,ver,length=struct.unpack_from('<4sII',b);assert magic==b'glTF' and ver==2 and length==len(b);offset=12;chunks={}
while offset<len(b):
 size,kind=struct.unpack_from('<I4s',b,offset);offset+=8;chunks[kind]=b[offset:offset+size];offset+=size
j=json.loads(chunks[b'JSON']);assert len(j['nodes'])==1 and j['nodes'][0].get('mesh')==0;assert not any(k in j['nodes'][0] for k in ['matrix','translation','rotation','scale','children']);assert not j.get('skins') and not j.get('animations');verts=[]
for primitive in j['meshes'][0]['primitives']:
 a=j['accessors'][primitive['attributes']['POSITION']];assert a['componentType']==5126 and a['type']=='VEC3' and 'sparse' not in a;v=j['bufferViews'][a['bufferView']];assert v['buffer']==0;start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',12);assert stride>=12
 for n in range(a['count']):verts.append(struct.unpack_from('<fff',chunks[b'BIN\x00'],start+n*stride))

# For this rigid, unskinned source pose, the maximum radius over actual vertices
# encloses every point of each triangle and all continuous root-yaw rotations.
# This establishes no deformation/gear/load or animated-state envelope.
from fractions import Fraction
squares=[(Fraction.from_float(v[0])**2+Fraction.from_float(v[2])**2)*1024**2 for v in verts]
maximum=max(squares);radius=math.isqrt(maximum.numerator//maximum.denominator)
if radius*radius*maximum.denominator<maximum.numerator:radius+=1
assert radius*radius*maximum.denominator>=maximum.numerator
assert (radius-1)*(radius-1)*maximum.denominator<maximum.numerator
trials=[]
for ox,oz in [(256,256),(768,256),(768,768)]:
 minimum=[ox-radius,oz-radius];maximums=[ox+radius,oz+radius]
 k=max(1,*[(x+511)//512 for x in maximums])
 trials.append({'offset_units_xz':[ox,oz],'translated_min_units_xz':minimum,'translated_max_units_xz':maximums,'static_rigid_yaw_containment_class':k if min(minimum)>=0 and k<=512 else None,'production_qualified':False})
record={'scope':'Diagnostic of continuous rigid yaw of the existing static mesh ONLY; not the seven-state body/gear/cargo sweep, no approved margin, profile, support, doorway or movement admission','source':rel,'sha256':hashlib.sha256(b).hexdigest(),'vertices':len(verts),'maximum_squared_horizontal_radius_units':{'numerator':maximum.numerator,'denominator':maximum.denominator},'outward_integer_radius_units':radius,'method':'Decode exact float32 vertex values; compute rational squared XZ distances; integer sqrt with exact outward check. Convex triangle interiors cannot exceed the maximum vertex radius. Rotations about the root preserve radius.','trials':trials,'finding':'A placement that contains the original static pose on X but retains +256 on Z cannot contain its full rigid yaw. Choosing both offsets +768 is a diagnostic containment alternative, not production policy.','omissions':['art approval of source anatomy','deformation and articulated poses','clothing/gear/cargo changes','authored margins','support and continuous translation','contact and doorway admission','save/anchor semantic changes']}
e=r/'docs/validation/evidence/ground-access-planning-2026-09-20';(e/'mouse-rigid-yaw-diagnostic.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps({'radius':radius,'trials':trials}))
