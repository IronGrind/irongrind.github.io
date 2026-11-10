import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
const [pglite,sdk]=process.argv.slice(2);
if(!pglite||!sdk||!fs.existsSync(pglite)||!fs.existsSync(sdk))throw new Error('Usage: node scripts/run-regression-checks.mjs <PGlite dist/index.js> <cached Supabase browser SDK.js>');
const results=[];
function run(name,args){
 const output=spawnSync(process.execPath,args,{encoding:'utf8',timeout:45000,windowsHide:true});
 const passed=output.status===0&&!output.error;
 results.push({name,passed,output:`${output.stdout||''}${output.stderr||''}${output.error?.message||''}`.trim()});
 console.log(`${passed?'PASS':'FAIL'} ${name}`);
}
for(const file of fs.readdirSync('assets/js').filter(file=>file.endsWith('.js')))run(`Syntax: ${file}`,['--check',`assets/js/${file}`]);
try{
 for(const file of fs.readdirSync('.').filter(file=>file.endsWith('.html'))){
  const html=fs.readFileSync(file,'utf8');
  const ids=[...html.matchAll(/\bid="([^"]+)"/g)].map(match=>match[1]);
  assert.equal(ids.length,new Set(ids).size,`Duplicate element IDs in ${file}`);
  for(const match of html.matchAll(/(?:src|href)="([^"#]+\.(?:js|css)(?:\?[^" ]*)?)"/g)){
   if(/^(https?:)?\/\//.test(match[1]))continue;
   assert.ok(fs.existsSync(path.resolve(match[1].split('?')[0])),`Missing asset in ${file}: ${match[1]}`);
  }
 }
 results.push({name:'HTML local script/style references and unique IDs',passed:true});
 console.log('PASS HTML local script/style references and unique IDs');
}catch(error){results.push({name:'HTML local script/style references and unique IDs',passed:false,output:error.message});console.log(`FAIL ${error.message}`);}
run('Browser unit tests',['--test',...fs.readdirSync('scripts/tests').filter(file=>file.endsWith('.test.mjs')).map(file=>`scripts/tests/${file}`)]);
for(const file of ['check-ui-improvements','check-session-monitor','check-pairing-summary','check-form-validation'])run(file,[`scripts/${file}.mjs`]);
for(const file of ['registration_submission','admin_membership_sync','admin_login_form'])run(file,[`supabase/tests/${file}.mjs`]);
run('Registration SDK isolation',['supabase/tests/registration_session.mjs',sdk]);
for(const file of ['activity_logs','admin_username_login','admin_login_profile_access','members_inactive_status','phone_pairing_repair','membership_paid_compatibility','reliable_attendance_scanning','unique_usernames','unique_registration_emails','staff_service_profile_access','staff_request_reviews','single_account_session','shared_pairing_capacity','monthly_phone_pairing','admin_membership_validation'])run(file,[`supabase/tests/${file}.mjs`,pglite]);
const folder='Documentations/Review Evidence';fs.mkdirSync(folder,{recursive:true});
for (const file of ['security_activity_events','admin_mfa']) run(file,[`supabase/tests/${file}.mjs`,pglite]);
const report={completedAt:new Date().toISOString(),passed:results.filter(test=>test.passed).length,failed:results.filter(test=>!test.passed).length,checks:results};
fs.writeFileSync(`${folder}/System Regression Results.json`,JSON.stringify(report,null,2)+'\n');
console.log(`${report.passed} checks passed; ${report.failed} failed.`);
if(report.failed){for(const test of results.filter(test=>!test.passed))console.error(`${test.name}\n${test.output}`);process.exitCode=1;}
