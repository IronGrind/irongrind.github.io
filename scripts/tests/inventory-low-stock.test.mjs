import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import test from 'node:test';

const source = fs.readFileSync('assets/js/admin.js', 'utf8');
const context = vm.createContext({});
vm.runInContext(source.slice(source.indexOf('const INVENTORY_UNIT_TO_BASE'), source.indexOf('function formatProductStock(')), context);

test('low-stock defaults use supplement type for powder and units for other forms', () => {
    for (const [supplementType, threshold] of Object.entries({ protein: 1000, creatine: 250, pre_workout: 250, amino_acids: 250, vitamins: 250, other: 500 })) {
        assert.equal(context.lowStockThreshold({ category: 'Supplement', inventoryUnit: 'gram', supplementType }), threshold);
    }
    for (const [inventoryUnit, threshold] of Object.entries({ milliliter: 1000, piece: 30, box: 4, item: 10 })) {
        assert.equal(context.lowStockThreshold({ category: 'Supplement', inventoryUnit, supplementType: 'protein' }), threshold);
    }
    for (const merchType of ['apparel', 'accessories', 'drinkware', 'gym_gear', 'other']) {
        assert.equal(context.lowStockThreshold({ category: 'Merch', inventoryUnit: 'item', merchType }), 4);
    }
});

test('alerts include the threshold and convert stock units before comparison', () => {
    const powder = { category: 'Supplement', supplementType: 'creatine', inventoryUnit: 'gram', stockUnit: 'kilogram' };
    assert.equal(context.productIsLowStock({ ...powder, stock: 0.25 }), true);
    assert.equal(context.productIsLowStock({ ...powder, stock: 0.251 }), false);
    assert.equal(context.productIsLowStock({ ...powder, stock: 0 }), true);
    const liquid = { category: 'Supplement', inventoryUnit: 'milliliter', stockUnit: 'liter' };
    assert.equal(context.productIsLowStock({ ...liquid, stock: 1 }), true);
    assert.equal(context.productIsLowStock({ ...liquid, stock: 1.1 }), false);
    assert.equal(context.productIsLowStock({ category: 'Merch', stock: 4 }), true);
    assert.equal(context.productIsLowStock({ category: 'Merch', stock: 5 }), false);
});

test('pounds and ounces trigger the same powder alerts as equivalent metric stock', () => {
    for (const [supplementType, grams] of [['protein', 1000], ['creatine', 250], ['other', 500]]) {
        for (const [stockUnit, factor] of [['pound', 453.59237], ['ounce', 28.349523125]]) {
            const product = { category: 'Supplement', supplementType, inventoryUnit: 'gram', stockUnit };
            assert.equal(context.productIsLowStock({ ...product, stock: (grams - 1) / factor }), true);
            assert.equal(context.productIsLowStock({ ...product, stock: (grams + 1) / factor }), false);
        }
    }
});
