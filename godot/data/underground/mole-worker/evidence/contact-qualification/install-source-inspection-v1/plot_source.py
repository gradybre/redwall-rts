from pathlib import Path
import importlib.util, hashlib
import numpy as np
from PIL import Image, ImageDraw
here=Path(__file__).resolve().parent
source=here.parent/'author_install_source.py'
raw=source.read_bytes()
(here/'executed-author.py').write_bytes(raw)
spec=importlib.util.spec_from_file_location('install_author',source); I=importlib.util.module_from_spec(spec);spec.loader.exec_module(I)
cases,parts,rig,topology,roots,_,_=I.M.read_actual_source()
p=parts[1]['geometry'][0]['points']; t=topology[1][0]
image=Image.new('RGB',(1560,540),'#f4f0e8');draw=ImageDraw.Draw(image)
for panel,(x,y) in enumerate([(0,2),(0,1),(2,1)]):
 def screen(point):
  return (int(panel*520+260+point[x]*230),int(300-point[y]*230))
 other=({0,1,2}-{x,y}).pop()
 for row in sorted(t,key=lambda row:float(p[row,other].mean())):
  draw.polygon([screen(p[v]) for v in row],fill='#989a92',outline='#57594e')
 for v in [148,149,155,157,478,652,1153]:
  sx,sy=screen(p[v]);draw.ellipse((sx-2,sy-2,sx+2,sy+2),fill='red');draw.text((sx+3,sy-12),str(v),fill='#ae1212')
 draw.text((panel*520+25,30),'actual source '+'XYZ'[x]+'/'+ 'XYZ'[y]+' view',fill='black')
image.save(here/'source-pick-orthographic.png')
assert source.read_bytes()==raw
print(hashlib.sha256(raw).hexdigest())
