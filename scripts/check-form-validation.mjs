import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
for(const file of fs.readdirSync('.').filter(file=>file.endsWith('.html'))){
 const html=fs.readFileSync(file,'utf8');
 for(const match of html.matchAll(/\bpattern="([^"]*)"/g)) {
  assert.doesNotThrow(()=>new RegExp(`^(?:${match[1]})$`,'v'),`Invalid HTML pattern in ${file}: ${match[1]}`);
 }
}
const html=fs.readFileSync('admin.html','utf8');
const input=id=>html.match(new RegExp(`<input\\b[^>]*\\bid="${id}"[^>]*>`))[0];
const pattern=id=>new RegExp(`^(?:${input(id).match(/pattern="([^"]+)"/)[1]})$`,'v');
for(const email of ['staff@gmail.com','staff.name+gym@gmail.com','staff-name@gmail.com','STAFF@GMAIL.COM'])assert.equal(pattern('staffEmail').test(email),true,`Valid Gmail rejected: ${email}`);
for(const email of ['staff@gmailXcom','staff@example.com','staff@gmail.com.evil'])assert.equal(pattern('staffEmail').test(email),false);
for(const initial of ['M','M.','ñ','Ñ.'])assert.equal(pattern('staffMiddleInitial').test(initial),true);
assert.equal(pattern('staffMiddleInitial').test('Mae'),false);
const source=fs.readFileSync('assets/js/staff-accounts.js','utf8');
const start=source.indexOf('function composeStaffName('),end=source.indexOf('\nfunction ',start+1);
const context=vm.createContext({});vm.runInContext(source.slice(start,end),context);
assert.equal(context.composeStaffName(' Glenerine ','m',' Castro '),'Glenerine M. Castro');
assert.equal(context.composeStaffName('Maria Clara','','Dela Cruz'),'Maria Clara Dela Cruz');
assert.throws(()=>context.composeStaffName('Maria','Mae','Cruz'),/one letter/);
assert.throws(()=>context.composeStaffName(' ','M','Cruz'),/first and last/);
console.log('Passed: HTML validation patterns compile in modern browsers; Gmail and split staff-name validation accept valid inputs and reject invalid ones.');
const staff=fs.readFileSync('assets/js/staff.js','utf8');
for(const name of ['localDateString','staffMembershipDates']){
 const start=staff.indexOf(`function ${name}(`),end=staff.slice(start+1).search(/\n(?:async )?function /);
 vm.runInContext(staff.slice(start,start+1+end),context);
}
const dates=context.staffMembershipDates(30,new Date('2026-11-08T16:05:00Z'));
assert.equal(dates.startDate,'2026-11-09');assert.equal(dates.expiryDate,'2026-12-09');
assert.equal(context.staffMembershipDates(1,new Date('2026-11-08T15:59:00Z')).startDate,'2026-11-08');
console.log('Passed: staff membership dates use Philippine time across midnight and month boundaries.');
