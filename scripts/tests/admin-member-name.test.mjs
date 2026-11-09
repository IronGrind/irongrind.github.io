import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const source = fs.readFileSync('assets/js/admin.js', 'utf8');
const context = vm.createContext({});
const start = source.indexOf('function validPersonName(');
const end = source.indexOf('(function guardAdmin()', start);
vm.runInContext(source.slice(start, end), context);

test('admin member names preserve compound and accented names and normalize initials', () => {
    assert.equal(context.composeAdminMemberName(' Juan  Miguel ', 'm', ' Dela Cruz '), 'Juan Miguel M. Dela Cruz');
    assert.equal(context.composeAdminMemberName('José', '', "O’Neill-Santos"), 'José O’Neill-Santos');
    assert.equal(context.composeAdminMemberName('Ana', 'ñ.', 'Reyes'), 'Ana Ñ. Reyes');
});

test('admin member names reject missing names, numbers, invalid initials and overlong parts', () => {
    for (const args of [['', '', 'Cruz'], ['Juan', '', ''], ['Juan2', '', 'Cruz'], ['Juan', '', '123'], ['Juan', 'Mae', 'Cruz'], ['Juan', '1', 'Cruz'], ['A'.repeat(71), '', 'Cruz']]) {
        assert.throws(() => context.composeAdminMemberName(...args));
    }
});

test('admin modal and submission use the split fields and retain the fullName API contract', () => {
    for (const id of ['wiFirstName', 'wiMiddleInitial', 'wiLastName']) {
        assert.match(source, new RegExp(`id="${id}"`));
        assert.match(source, new RegExp(`getElementById\\('${id}'\\)\\.value`));
    }
    assert.doesNotMatch(source, /\bwiName\b/);
    assert.match(source, /fullName: name, mobile: contact/);
});
