import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const elements = new Map();
const context = vm.createContext({ console, setTimeout, MutationObserver: class { observe() {} }, document: { body: {}, querySelectorAll: () => [], addEventListener() {}, getElementById: id => elements.get(id) } });
context.window = context;
vm.runInContext(fs.readFileSync('assets/js/ui-improvements.js', 'utf8'), context);
const midnightInManila = '2026-11-07T16:00:00Z';
assert.equal(context.attendanceVisitIncomplete('2026-11-07T15:59:00Z', null, midnightInManila), true);
assert.equal(context.attendanceVisitIncomplete('2026-11-07T16:00:00Z', null, midnightInManila), false);
assert.equal(context.attendanceVisitIncomplete('2026-11-05', null, midnightInManila), true);
assert.equal(context.attendanceVisitIncomplete('2026-11-05', '2026-11-05T12:00:00Z', midnightInManila), false);
assert.equal(context.attendanceVisitIncomplete('invalid', null, midnightInManila), false);
for (const [name, file] of [['BCAA Fruit Punch', 'bcaa-fruit-punch'], ['BCAA Peach Mango', 'bcaa-peach-mango'], ['ROAR (Fruitpunch)', 'roar-fruit-punch'], ['ROAR — Peach Mango', 'roar-peach-mango'], ['Whey Core Protein Strawberry', 'whey-strawberry']]) {
    const path = context.catalogProductPhoto({ name, image: 'old-photo.jpg' });
    assert.equal(path, `assets/images/products/transparent/${file}.png`);
    assert.ok(fs.existsSync(path), `Missing catalog asset: ${path}`);
}
assert.equal(context.catalogProductPhoto({ name: 'BCAA Lemon', image: 'lemon.jpg' }), 'lemon.jpg');
assert.equal(context.catalogProductPhoto({ name: 'ISO Strawberry Whey', image_path: 'isolate.png' }), 'isolate.png');
assert.equal(context.catalogProductPhoto({ name: 'Shirt', image: 'shirt.jpg' }), 'shirt.jpg');
assert.equal(context.productUnitPrice(80, 10), 8);
assert.equal(context.productPriceQuote(8, 'gram').amount, 80);
assert.equal(context.productPriceQuote(8, 'gram').quantity, 10);
assert.equal(context.productPriceQuote(12, 'milliliter').unit, 'ml');
for (const pair of [[0, 10], [80, 0], [-1, 10], [80, 3], [Infinity, 1]]) assert.equal(context.productUnitPrice(...pair), null);
assert.equal(context.productUnitPrice(80, 2.5, true), null);
assert.equal(context.newPasswordValid('letters', 6), false);
assert.equal(context.newPasswordValid('123456', 6), false);
assert.equal(context.newPasswordValid('Member123', 8), false);
assert.equal(context.newPasswordValid('Member123!', 8), true);
for (const password of ['Ab1!', 'lowercase1!', 'UPPERCASE1!', 'NoDigits!!', 'NoSymbols123', `Aa1!${'x'.repeat(125)}`]) assert.equal(context.newPasswordValid(password), false);
assert.equal(context.passwordStrength('abc').label, 'Weak');
assert.equal(context.passwordStrength('Member123').label, 'Fair');
assert.equal(context.passwordStrength('Member123!').label, 'Strong');
assert.equal(context.newPasswordValid('Member123', 12), false);
assert.equal(context.newPasswordValid(`a1${'x'.repeat(127)}`, 6), false);

const source = fs.readFileSync('assets/js/admin.js', 'utf8');
function loadFunction(name) {
    const start = source.search(new RegExp(`(?:async )?function ${name}\\(`));
    assert.ok(start >= 0, `Missing ${name}`);
    const next = source.slice(start + 1).search(/\n(?:async )?function /);
    vm.runInContext(next < 0 ? source.slice(start) : source.slice(start, start + 1 + next), context);
}
vm.runInContext("const DISCRETE_UNITS = new Set(['item', 'piece', 'box']);", context);
for (const fn of ['isDiscreteUnit', 'supplementSaleUnit', 'submitAddProduct', 'submitEditProduct']) loadFunction(fn);
let saved;
const messages = [];
Object.assign(context, {
    products: [], isUUID: () => true, mapSupabaseProduct: row => ({ id: row.id, name: row.name, price: row.price_per_unit, category: row.category === 'supplement' ? 'Supplement' : 'Merch', stock: row.stock, inventoryUnit: row.unit, size: row.size }),
    getProductPhoto: async () => '', closeModal() {}, renderStore() {}, renderDashboard() {}, toast: message => messages.push(message),
    ironGrindSupabase: { from: () => ({ insert: row => { saved = row; return { select: () => ({ single: async () => ({ data: { id: 'test-product', ...row } }) }) }; }, update: row => { saved = row; return { eq: () => ({ select: () => ({ single: async () => ({ data: { id: 'test-product', ...row } }) }) }) }; } }) }
});
function fields(values) { for (const [id, value] of Object.entries(values)) elements.set(id, { value: String(value), checked: false }); }
fields({ apName: 'Protein', apCat: 'Supplement', apMerchType: 'apparel', apSupplementType: 'protein', apSupplementForm: 'powder', apSize: '', apPrice: 80, apPriceQuantity: 10, apStock: 1000, apStockUnit: 'gram' });
await context.submitAddProduct();
assert.equal(saved.price_per_unit, 8);
assert.equal(saved.stock, 1000);
assert.equal(saved.unit, 'gram');
assert.equal(context.products[0].price, 8);
saved = undefined;
elements.get('apPriceQuantity').value = '0';
await context.submitAddProduct();
assert.equal(saved, undefined, 'Invalid price must not reach database');
fields({ apName: 'Shirt', apCat: 'Merch', apMerchType: 'apparel', apSize: 'XL Tall', apPrice: 350, apPriceQuantity: 1, apStock: 3, apStockUnit: 'item' });
await context.submitAddProduct();
assert.equal(saved.size, 'XL Tall');
assert.equal(saved.stock, 3);
fields({ epName: 'Protein', epPrice: 120, epPriceQuantity: 10, epStock: 850, epStockUnit: 'gram', epSupplementType: 'protein', epSupplementForm: 'powder' });
elements.set('epRemoveImage', { checked: false });
await context.submitEditProduct('test-product');
assert.equal(saved.price_per_unit, 12);
assert.equal(saved.stock, 850);

for (const page of ['admin.html', 'customer.html', 'staff.html', 'register.html', 'reset-password.html']) {
    const html = fs.readFileSync(page, 'utf8');
    assert.ok(html.indexOf('ui-improvements.js') < html.indexOf('supabase-js@2'), `Shared helpers load early on ${page}`);
    const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map(match => match[1]);
    assert.equal(ids.length, new Set(ids).size, `Duplicate IDs on ${page}`);
}
assert.ok(fs.readFileSync('staff.html', 'utf8').includes('id="walkinConfirmPassword"'));
assert.ok(fs.readFileSync('admin.html', 'utf8').includes('id="staffConfirmPassword"'));
console.log('Passed: password rules, pricing conversions, add/edit product saves, custom sizes, invalid-input rejection, script loading, and unique page IDs.');
