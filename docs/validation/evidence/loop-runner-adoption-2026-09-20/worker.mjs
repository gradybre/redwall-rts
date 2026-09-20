import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {spawn,execFileSync} from 'node:child_process';
const [id,model,packetPath,mode]=process.argv.slice(2);
if(!/^[a-z0-9-]+$/.test(id||''))throw Error('Invalid attempt id');
const state=path.dirname(fileURLToPath(import.meta.url));
const p=JSON.parse(fs.readFileSync(packetPath,'utf8'));
if(!p.scope||p.scope.project!=='redwall-rts'||p.scope.model!==model)throw Error('Explicit Redwall scope and matching model required');
if(!['author','review'].includes(p.scope.role)||!p.scope.task||!p.scope.contractEpoch)throw Error('Stable task, role and epoch required');
if(p.resume_attempt)throw Error('Legacy resume forbidden after migration; new-runner previousPrefix only');
if(!p.allowedWrites||Object.keys(p.allowedWrites).length===0)throw Error('Explicit allowedWrites/base hashes required');
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const currentBase=execFileSync('git',['rev-parse','HEAD'],{cwd:p.root,encoding:'utf8'}).trim();
if(currentBase!==p.base_commit)throw Error('Dispatch base_commit mismatch');
for(const [name,base] of Object.entries(p.allowedWrites)){
 if(path.isAbsolute(name)||name.split('/').some(x=>!x||x==='.'||x==='..'||x==='.git')||name.includes('\\'))throw Error('Unsafe output path');
 const target=path.join(p.root,name);let ancestor=path.dirname(target);
 while(!fs.existsSync(ancestor))ancestor=path.dirname(ancestor);
 const relative=path.relative(fs.realpathSync(p.root),fs.realpathSync(ancestor));
 if(relative.startsWith('..')||path.isAbsolute(relative))throw Error('Output escapes root');
 const actual=fs.existsSync(target)?hash(fs.readFileSync(target)):null;
 if(actual!==base)throw Error('Output base hash mismatch '+name);
}
if(p.scope.role==='review'&&(!p.reviewTarget||Object.keys(p.allowedWrites).length!==1||p.allowedWrites[p.reviewTarget.path]!==p.reviewTarget.baseSha256))throw Error('Review target must be the sole declared output');
const spec={id,root:p.root,cwd:'/Users/brendan/Developer/redwall-rts',outputPrefix:path.join(state,id),scope:p.scope,paths:p.paths,instructions:p.instructions+'\n\nDispatch audit: '+JSON.stringify({base_commit:p.base_commit,task:p.task,allowedWrites:p.allowedWrites})+'\nOnly declared file paths/base hashes may be returned. No automatic source application or acceptance is authorized.'};
if(p.previousPrefix)spec.previousPrefix=p.previousPrefix;
if(p.reviewTarget)spec.reviewTarget=p.reviewTarget;
if(p.providedInputs)spec.providedInputs=p.providedInputs;
if(p.imagePaths)spec.imagePaths=p.imagePaths;
if(mode==='--validate-only'){console.log(JSON.stringify({valid:true,id,scope:p.scope,base_commit:currentBase,paths:p.paths.length,allowedWrites:p.allowedWrites}));process.exit(0);}
fs.writeFileSync(path.join(state,id+'.spec.json'),JSON.stringify(spec,null,2)+'\n',{flag:'wx'});
const child=spawn('/Users/brendan/.local/bin/loop-worker',[path.join(state,id+'.spec.json')],{stdio:'inherit'});
for(const sig of ['SIGINT','SIGTERM'])process.on(sig,()=>child.kill(sig));
const code=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('close',resolve);});
process.exitCode=code??1;
if(code===0){
 const result=JSON.parse(fs.readFileSync(path.join(state,id+'.result.json'),'utf8'));
 if(!result.ownerStopped||result.quarantine||result.quarantined)throw Error('Owner not safely stopped');
 const seen=new Set();
 for(const f of result.result?.files||[]){if(seen.has(f.path)||!Object.hasOwn(p.allowedWrites,f.path)||f.baseSha256!==p.allowedWrites[f.path])throw Error('Returned output violates declared allowlist/base');seen.add(f.path);}
 fs.writeFileSync(path.join(state,id+'.delivery-check.json'),JSON.stringify({scope:p.scope,base_commit:p.base_commit,allowedWrites:p.allowedWrites,returnedPaths:[...seen],sourceApplied:false,approval:'not_granted'},null,2)+'\n',{flag:'wx'});
}
