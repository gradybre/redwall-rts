import {readFileSync,writeFileSync,appendFileSync,existsSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {startClaude,discoverClaude} from '/Users/brendan/Documents/Codex/2026-09-18/help-me-build-out-and-define/dist/src/adapters/claude/index.js';
const [id,model,packetPath]=process.argv.slice(2);
if(!/^[a-z0-9-]+$/.test(id))throw Error('Invalid bounded task ID');
const prefix=new URL('./'+id,import.meta.url).pathname;
if(existsSync(prefix+'.result.json'))throw Error('Attempt already has result; reconcile before retry');
const p=JSON.parse(readFileSync(packetPath,'utf8'));
const input=p.paths.map(path=>{const content=readFileSync(p.root+'/'+path,'utf8');return {path,content,sha256:createHash('sha256').update(content).digest('hex')};});
const started=Date.now(); let last=started;let handle;
const record=x=>appendFileSync(prefix+'.events.jsonl',JSON.stringify({at:new Date().toISOString(),...x})+'\n');
writeFileSync(prefix+'.input.json',JSON.stringify({...p,model,input},null,2));
record({event:'start',owner:'Astra foreground task',externalSessionReservation:3,deadlineMs:started+900000,noProgressMs:180000,maxAttempts:1});
try {
 handle=await startClaude({executable:discoverClaude('/Users/brendan'),cwd:'/Users/brendan/Developer/redwall-rts',model,expectedModels:[model],prompt:JSON.stringify({instructions:p.instructions,inputs:input}),deadlineMs:started+900000,maxOutputBytes:8*1024*1024,onProcess:info=>record({event:'process',...info}),onSession:sessionId=>record({event:'session',sessionId}),onProgress:info=>{if(info.kind!=='heartbeat')last=Date.now();record({event:'progress',...info});}});
 const watchdog=setInterval(()=>{if(Date.now()-last>180000)handle.cancel('bounded no-progress deadline').catch(()=>{});},15000);
 const status=setInterval(()=>console.log(JSON.stringify({id,elapsedSeconds:Math.round((Date.now()-started)/1000),lastContentSeconds:Math.round((Date.now()-last)/1000)})),30000);
 process.on('SIGTERM',()=>handle.cancel('foreground owner stopped'));
 const result=await handle.completion;clearInterval(watchdog);clearInterval(status);
 writeFileSync(prefix+'.result.json',JSON.stringify(result,null,2));
 record({event:'terminal',state:result.state,ownerStopped:result.ownerStopped,model:result.model,sessionId:result.sessionId});
 console.log(JSON.stringify({id,state:result.state,ownerStopped:result.ownerStopped,model:result.model,summary:result.result?.summary,code:result.code}));
}catch(e){record({event:'failure',code:e.code,message:e.message});console.error(e.message);process.exitCode=1;}
