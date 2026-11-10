import assert from 'node:assert/strict';
import fs from 'node:fs';
import { pathToFileURL } from 'node:url';

const { PGlite } = await import(pathToFileURL(process.argv[2]).href);
const db = new PGlite();
const member = '11111111-1111-4111-8111-111111111111';
const nonmember = '22222222-2222-4222-8222-222222222222';
const sessions = {
  first: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  second: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  denied: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  expired: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  noMembership: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
};
const devices = {
  first: '11111111-aaaa-4aaa-8aaa-111111111111',
  second: '22222222-bbbb-4bbb-8bbb-222222222222',
  denied: '33333333-cccc-4ccc-8ccc-333333333333',
  expired: '44444444-dddd-4ddd-8ddd-444444444444',
};
const key = marker => ({ kty: 'EC', crv: 'P-256', x: marker.repeat(43), y: 'z'.repeat(43) });

try {
  await db.exec(`
    create role anon; create role authenticated; create role service_role; create role authenticator;
    create schema auth; create schema private;
    grant usage on schema auth, private to authenticated;
    create function auth.jwt() returns jsonb language sql as $$
      select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb
    $$;
    create function auth.uid() returns uuid language sql as $$ select (auth.jwt()->>'sub')::uuid $$;
    create function auth.role() returns text language sql as $$ select auth.jwt()->>'role' $$;
    create table auth.users(id uuid primary key);
    insert into auth.users values('${member}'),('${nonmember}');
    create table auth.sessions(id uuid primary key, user_id uuid, created_at timestamptz, not_after timestamptz, aal text);
    insert into auth.sessions values
      ('${sessions.first}','${member}',now()-interval '5 minutes',null,'aal1'),
      ('${sessions.second}','${member}',now()-interval '4 minutes',null,'aal1'),
      ('${sessions.denied}','${member}',now()-interval '3 minutes',null,'aal1'),
      ('${sessions.expired}','${member}',now()-interval '2 minutes',null,'aal1'),
      ('${sessions.noMembership}','${nonmember}',now()-interval '1 minute',null,'aal1');
    create table public.profiles(id uuid primary key, role text, is_active boolean, full_name text);
    insert into public.profiles values('${member}','member',true,'Test Member'),('${nonmember}','member',true,'Pending Applicant');
    create table public.members(id uuid primary key default gen_random_uuid(), auth_user_id uuid unique);
    insert into public.members(auth_user_id) values('${member}');
    create table public.activity_logs(actor_id uuid, actor_name text, actor_role text, action text, entity_type text, entity_id text, details text);
    create table public.protected_records(id int primary key);
    insert into public.protected_records values(1);
    alter table public.protected_records enable row level security;
    grant select on public.protected_records to authenticated;
    create policy allowed on public.protected_records to authenticated using(true);
  `);

  for (const file of [
    '20261108000003_single_account_session.sql',
    '20261108000004_anonymous_session_guard.sql',
    '20261108000006_separate_attendance_sessions.sql',
    '20261110000002_admin_mfa.sql',
    '20261110000006_member_device_approval.sql',
  ]) await db.exec(fs.readFileSync(`supabase/migrations/${file}`, 'utf8'));

  async function setRole(role, sessionId = null) {
    await db.exec('reset role');
    const claims = role === 'service_role' ? { role } : { role, sub: member, session_id: sessionId, aal: 'aal1' };
    await db.query("select set_config('request.jwt.claims', $1, false)", [JSON.stringify(claims)]);
    await db.exec(`set role ${role}`);
  }
  async function challenge(sessionId, deviceId, publicKey) {
    await setRole('service_role');
    return (await db.query('select public.create_member_device_challenge($1,$2,$3,$4) result', [member, sessionId, deviceId, publicKey])).rows[0].result;
  }
  async function complete(sessionId, message, label = 'Test browser') {
    await setRole('service_role');
    return (await db.query('select public.finish_member_device_login($1,$2,$3,$4) result', [member, sessionId, message, label])).rows[0].result;
  }

  const firstChallenge = await challenge(sessions.first, devices.first, key('a'));
  assert.equal(typeof firstChallenge.message, 'string');
  assert.equal((await complete(sessions.first, firstChallenge.message)).status, 'authorized', 'Initial device can register after password sign-in');
  await setRole('authenticated', sessions.first);
  await db.query('select public.activate_account_session()');
  assert.equal((await db.query('select * from public.protected_records')).rows.length, 1);
  await assert.rejects(db.query('select public.create_member_device_challenge($1,$2,$3,$4)', [member, sessions.first, devices.first, key('a')]), /permission denied/);
  await assert.rejects(db.query('select * from private.member_trusted_devices'), /permission denied/);

  await setRole('authenticated', sessions.second);
  await assert.rejects(db.query('select public.activate_account_session()'), /MEMBER_DEVICE_REQUIRED/);
  const secondChallenge = await challenge(sessions.second, devices.second, key('b'));
  assert.equal((await complete(sessions.second, secondChallenge.message)).status, 'pending', 'Unrecognized device waits for trusted-device approval');
  await setRole('authenticated', sessions.first);
  const pending = (await db.query('select * from public.list_member_device_approvals()')).rows[0];
  assert.ok(pending?.id);
  await db.query('select public.decide_member_device_approval($1, true)', [pending.id]);
  await setRole('service_role');
  assert.equal((await db.query('select public.get_member_device_approval_status($1,$2) result', [member, sessions.second])).rows[0].result.status, 'approved');
  assert.equal((await complete(sessions.second, secondChallenge.message)).status, 'authorized');
  await setRole('authenticated', sessions.second);
  await db.query('select public.activate_account_session()');
  assert.equal((await db.query('select * from public.protected_records')).rows.length, 1);
  await setRole('authenticated', sessions.first);
  assert.equal((await db.query('select * from public.protected_records')).rows.length, 0, 'Trust transfer invalidates the previous application session');

  const deniedChallenge = await challenge(sessions.denied, devices.denied, key('c'));
  assert.equal((await complete(sessions.denied, deniedChallenge.message)).status, 'pending');
  await setRole('authenticated', sessions.second);
  const deniedRequest = (await db.query('select * from public.list_member_device_approvals()')).rows[0];
  await db.query('select public.decide_member_device_approval($1, false)', [deniedRequest.id]);
  await setRole('service_role');
  assert.equal((await db.query('select public.get_member_device_approval_status($1,$2) result', [member, sessions.denied])).rows[0].result.status, 'denied');
  assert.equal((await complete(sessions.denied, deniedChallenge.message)).status, 'denied');
  await setRole('authenticated', sessions.second);
  assert.equal((await db.query('select * from public.protected_records')).rows.length, 1, 'Denied request leaves the existing trusted session intact');

  const expiredChallenge = await challenge(sessions.expired, devices.expired, key('d'));
  assert.equal((await complete(sessions.expired, expiredChallenge.message)).status, 'pending');
  await db.exec('reset role');
  await db.query("update private.member_device_approvals set expires_at=now()-interval '1 second' where requesting_session_id=$1", [sessions.expired]);
  await setRole('service_role');
  assert.equal((await db.query('select public.get_member_device_approval_status($1,$2) result', [member, sessions.expired])).rows[0].result.status, 'expired');
  assert.equal((await complete(sessions.expired, expiredChallenge.message)).status, 'expired');
  await db.exec('reset role');
  assert.equal((await db.query('select count(*)::int count from private.member_trusted_devices')).rows[0].count, 1, 'Expired request does not replace trusted device');

  await setRole('service_role');
  assert.equal((await db.query('select public.create_member_device_challenge($1,$2,$3,$4) result', [nonmember, sessions.noMembership, devices.expired, key('e')])).rows[0].result.skip, true, 'Unapproved applicant without a member row does not enroll a device');
  await assert.rejects(db.query('select public.finish_member_device_login($1,$2,$3,$4)', [member, sessions.first, 'wrong-challenge', 'Browser']), /challenge expired or consumed/);
  await db.exec('reset role');
  await db.exec(fs.readFileSync('supabase/migrations/20261110000006_member_device_approval.sql', 'utf8'));
  console.log('Passed: initial device enrollment, untrusted-session guard, service-only APIs/private-table isolation, trusted-device approval and transfer, previous-session revocation, denial and expiry preservation, unapproved applicant handling, challenge binding, and migration rerun.');
} finally {
  await db.close();
}
