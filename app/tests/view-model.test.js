'use strict';

const test = require('node:test');
const assert = require('node:assert');

const viewModel = require('../src/view-model.js');

const VIEWS = {
  inventar: { list: true, filter: 'all' },
  warnungen: { list: true, filter: 'upgrade' },
  dashboard: { list: false }
};

const devices = [
  { host: 'WS-OK-02', user: 'Ada Admin', cpu: 'Ryzen 7', dept: 'IT', status: 'ok', ramGB: 32, ageYears: 1 },
  { host: 'WS-UP-01', user: 'Ben Bauer', cpu: 'Core i5', dept: 'Sales', status: 'upgrade', ramGB: 8, ageYears: 6 },
  { host: 'WS-ST-01', user: 'Clara Chen', cpu: 'Core i3', dept: 'Ops', status: 'stale', upgradeReasons: ['Win 10'], ramGB: 8, ageYears: 5 },
  { host: 'WS-ST-02', user: 'Dana Diaz', cpu: 'Core i7', dept: 'Ops', status: 'stale', upgradeReasons: [], ramGB: 16, ageYears: 3 },
  { host: 'WS-MI-01', user: 'Eli Event', cpu: 'Core i5', dept: 'Logistics', status: 'missing', ramGB: 0, ageYears: null }
];

test('applyViewChange keeps segment filter when view does not change', () => {
  const state = { view: 'inventar', filter: 'ok', selected: 'WS-OK-02' };

  viewModel.applyViewChange(state, VIEWS, 'inventar');

  assert.strictEqual(state.filter, 'ok');
  assert.strictEqual(state.selected, null);
});

test('applyViewChange applies defaults only on actual view changes', () => {
  const state = { view: 'inventar', filter: 'veraltet', selected: null };

  viewModel.applyViewChange(state, VIEWS, 'warnungen');
  assert.strictEqual(state.filter, 'upgrade');

  state.filter = 'veraltet';
  viewModel.applyViewChange(state, VIEWS, 'warnungen');
  assert.strictEqual(state.filter, 'veraltet');

  viewModel.applyViewChange(state, VIEWS, 'dashboard');
  assert.strictEqual(state.filter, 'veraltet');

  viewModel.applyViewChange(state, VIEWS, 'inventar');
  assert.strictEqual(state.filter, 'all');
});

test('visibleDevices filters upgrade and stale buckets correctly', () => {
  assert.deepStrictEqual(
    viewModel.visibleDevices(devices, { filter: 'upgrade', sort: 'host', dir: 'asc', q: '' }).map((d) => d.host),
    ['WS-ST-01', 'WS-UP-01']
  );

  assert.deepStrictEqual(
    viewModel.visibleDevices(devices, { filter: 'veraltet', sort: 'host', dir: 'asc', q: '' }).map((d) => d.host),
    ['WS-MI-01', 'WS-ST-01', 'WS-ST-02']
  );

  assert.deepStrictEqual(
    viewModel.visibleDevices(devices, { filter: 'ok', sort: 'host', dir: 'asc', q: '' }).map((d) => d.host),
    ['WS-OK-02']
  );
});

test('visibleDevices searches and sorts the already filtered list', () => {
  assert.deepStrictEqual(
    viewModel.visibleDevices(devices, { filter: 'all', sort: 'ram', dir: 'desc', q: 'ops' }).map((d) => d.host),
    ['WS-ST-02', 'WS-ST-01']
  );
});
