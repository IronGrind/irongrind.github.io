import fs from 'node:fs';
const base='https://irongrind-github-io.vercel.app';
const report=JSON.parse(fs.readFileSync('Documentations/Review Evidence/Hosted Readiness Results.json','utf8'));
const normalize=s=>s.replace(/^\uFEFF/,'').replaceAll('\r\n','\n').trimEnd();
for(const entry of report.assets.filter(a=>!a.matchesLocal)){
 const remote=await (await fetch(`${base}/${entry.file}`,{signal:AbortSignal.timeout(20000)})).text();
 const local=fs.readFileSync(entry.file,'utf8');
 entry.matchesNormalized=normalize(remote)===normalize(local);
 if(!entry.matchesNormalized){const a=normalize(remote).split('\n'),b=normalize(local).split('\n');let i=0;while(i<Math.min(a.length,b.length)&&a[i]===b[i])i++;
  entry.firstDifference={line:i+1,hosted:a[i]?.slice(0,220),local:b[i]?.slice(0,220)};
 }
 console.log(JSON.stringify(entry));
}
const config=fs.readFileSync('assets/js/supabase-client.js','utf8');
const url=config.match(/IRON_GRIND_SUPABASE_URL = '([^']+)'/)[1],key=config.match(/IRON_GRIND_SUPABASE_PUBLISHABLE_KEY = '([^']+)'/)[1];
for(const name of ['admin-create-member','verify-store-password']){
 const r=await fetch(`${url}/functions/v1/${name}`,{method:'POST',headers:{apikey:key,Authorization:'Bearer invalid-readiness-token','Content-Type':'application/json'},body:'{}',signal:AbortSignal.timeout(20000)});
 report.api.push({name:`${name} invalid bearer`,status:r.status,body:await r.text(),unauthenticatedDenied:[401,403].includes(r.status)});
 console.log(JSON.stringify(report.api.at(-1)));
}
report.followupAt=new Date().toISOString();
fs.writeFileSync('Documentations/Review Evidence/Hosted Readiness Results.json',JSON.stringify(report,null,2)+'\n');
