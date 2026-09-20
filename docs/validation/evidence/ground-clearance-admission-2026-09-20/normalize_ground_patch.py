from pathlib import Path
import re,json,hashlib,difflib,subprocess,shutil
r=Path('/Users/brendan/Developer/redwall-rts-loop-2026-09-19');w=Path(__file__).resolve().parent;e=r/'docs/validation/evidence/ground-clearance-admission-2026-09-20';p=e/'implementation.patch';s=p.read_text();changes={};proof=[]
for block in re.split(r'(?=^diff --git )',s,flags=re.M):
 if not block:continue
 lines=block.splitlines(keepends=True);path=lines[0].split()[3][2:];f=r/path;before=f.read_text() if f.exists() else '';after=before;new='--- /dev/null\n' in lines
 hunks=re.split(r'^@@.*@@.*\n',block,flags=re.M)[1:]
 if new:
  assert len(hunks)==1 and not f.exists();after=''.join(x[1:] for x in hunks[0].splitlines(keepends=True) if x.startswith('+'))
 else:
  for hunk in hunks:
   ls=hunk.splitlines(keepends=True);assert all(x[:1] in ' +-' for x in ls)
   old=''.join(x[1:] for x in ls if x.startswith((' ','-')));replacement=''.join(x[1:] for x in ls if x.startswith((' ','+')))
   assert old and after.count(old)==1,(path,after.count(old));proof.append({'path':path,'old_sha256':hashlib.sha256(old.encode()).hexdigest(),'new_sha256':hashlib.sha256(replacement.encode()).hexdigest(),'matches':1});after=after.replace(old,replacement,1)
 changes[path]=(before,after,new)
normalized=''
for path,(before,after,new) in changes.items():
 normalized+='diff --git a/'+path+' b/'+path+'\n'+('new file mode 100644\n' if new else '')+''.join(difflib.unified_diff(before.splitlines(keepends=True),after.splitlines(keepends=True),fromfile='/dev/null' if new else 'a/'+path,tofile='b/'+path,n=3))
np=e/'implementation-normalized.patch';assert not np.exists();np.write_text(normalized);subprocess.run(['git','apply','--check',str(np)],cwd=r,check=True);subprocess.run(['git','apply',str(np)],cwd=r,check=True)
for path,(_,after,_) in changes.items():assert (r/path).read_text()==after
record={'reason':'Original diff omitted trailing context in an interior test hunk; git apply --recount --check refused. No source was partially changed.','method':'All existing-file old hunks uniquely match exact frozen content; apply exact provider replacements without semantic edits, regenerate standard context/hunk positions with difflib, git apply --check and apply; verify resulting full bytes.','original_sha256':hashlib.sha256(s.encode()).hexdigest(),'normalized_sha256':hashlib.sha256(normalized.encode()).hexdigest(),'hunks':proof,'final_sha256':{p:hashlib.sha256(v[1].encode()).hexdigest() for p,v in changes.items()}};(e/'patch-normalization.json').write_text(json.dumps(record,indent=2)+'\n')
a='ground-clearance-admission-author-a1'
for suffix in ['packet.json','spec.json','input.json','provider.json','context.json','result.json','delivery-check.json','events.jsonl']:
 f=w/(a+'.'+suffix)
 if f.exists():shutil.copy2(f,e/f.name)
print('Applied exact provider replacement bytes with framing normalization:',len(changes),'files')
