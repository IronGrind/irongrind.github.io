import fs from 'node:fs';
const source=fs.readFileSync('assets/js/supabase-client.js','utf8');
const base=source.match(/IRON_GRIND_SUPABASE_URL = '([^']+)'/)[1],key=source.match(/IRON_GRIND_SUPABASE_PUBLISHABLE_KEY = '([^']+)'/)[1];
const results=[];
for(const table of ['profiles','members','membership_applications','attendance','products','sales','sale_items','membership_history','activity_logs','mobile_attendance_scan_sessions','mobile_attendance_scan_events']){
 const r=await fetch(`${base}/rest/v1/${table}?select=id&limit=1`,{headers:{apikey:key},signal:AbortSignal.timeout(20000)});
 const data=await r.json();
 const exposedRows=Array.isArray(data)?data.length:0;
 // Do not retain record identifiers if an access problem is found.
 results.push({table,status:r.status,exposedRows,passed:[401,403].includes(r.status)||(r.ok&&Array.isArray(data)&&data.length===0)});
}
fs.writeFileSync('Documentations/Review Evidence/Anonymous Access Results.json',JSON.stringify({completedAt:new Date().toISOString(),scope:'Anonymous GET of id only, limit one. Empty results do not prove absence of all possible access-policy gaps. No identifiers or personal data retained.',results},null,2)+'\n');
console.log(JSON.stringify(results));
if(results.some(r=>!r.passed))process.exitCode=1;
