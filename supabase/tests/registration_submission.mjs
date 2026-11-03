import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const source = await readFile(new URL('../../assets/js/register.js', import.meta.url), 'utf8');
const start = source.indexOf('async function insertSupabaseApplication(');
const end = source.indexOf('async function completeConfirmedRegistration(', start);
assert.ok(start >= 0 && end > start);

let response;
let inserted;
let selected;
let removedDraft = false;
let displayedError = '';
const context = vm.createContext({
    window: { ironGrindSupabase: { from(table) {
        assert.equal(table, 'membership_applications');
        return { insert(row) {
            inserted = row;
            return { select(columns) {
                selected = columns;
                return { single: async () => response };
            } };
        } };
    } } },
    localStorage: { removeItem(key) {
        assert.equal(key, 'ig_registration_draft');
        removedDraft = true;
    } },
    showError(message) { displayedError = message; },
    console: { error() {} }
});
vm.runInContext(source.slice(start, end), context);

for (const result of [
    { data: null, error: { message: 'Permission denied' } },
    { data: null, error: null },
    { data: {}, error: null },
    { data: { id: 'application', auth_user_id: 'another-user', status: 'pending' }, error: null },
    { data: { id: 'application', auth_user_id: 'new-user', status: 'approved' }, error: null }
]) {
    response = result;
    removedDraft = false;
    displayedError = '';
    const draft = { userId: 'new-user', application: { username: 'test-member' } };
    assert.equal(await context.insertSupabaseApplication(draft), false);
    assert.equal(removedDraft, false, 'An unverified submission must preserve the saved form');
    assert.equal(draft.application.id, undefined);
    assert.ok(displayedError.includes('could not submit'));
}

response = { data: { id: 'saved-application', auth_user_id: 'new-user', status: 'pending' }, error: null };
const draft = { userId: 'new-user', application: { username: 'test-member' } };
assert.equal(await context.insertSupabaseApplication(draft), true);
assert.equal(inserted.auth_user_id, 'new-user');
assert.equal(inserted.application_type, 'registration');
assert.equal(inserted.status, 'pending');
assert.equal(selected, 'id, status, auth_user_id');
assert.equal(draft.application.id, 'saved-application');
assert.equal(removedDraft, true);
console.log('Passed: submission succeeds only for a saved pending application linked to the registering account; failures preserve the draft.');
