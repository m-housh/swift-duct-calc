/* Run with: node scripts/check_fitting_reference.cjs */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const root = path.resolve(__dirname, '..');
const context = vm.createContext({window: {}});
const files = ['fittings/catalog-data.js', 'fittings/catalog-rules.js', 'fittings/reference-core.js'];
for (const file of files) {
  vm.runInContext(fs.readFileSync(path.join(root, 'Public', file), 'utf8'), context);
}
const R = context.window.FittingReference;
assert.equal(R.items.length, 231);
assert.equal(new Set(R.items.map(f => f.id)).size, 231);
assert.equal(R.groups.length, 12);
assert.equal(R.items.filter(f => !f.concept).length, 230);
assert.equal(R.filter({group:'13'}).length, 0);
assert.equal(R.filter({group:'2'}).length, 17);
assert.equal(R.filter({group:'all', query:'8a smooth'}).length, 2);
assert.equal(R.filter({group:'1', query:'8a'}).length, 0);
assert.equal(R.filter({query:'no-such-fitting'}).length, 0);
for (const f of R.filter({type:'fixed'})) assert.equal(typeof f.fixed, 'number');
for (const f of R.filter({type:'conditional'})) assert.equal(f.fixed, undefined);

function parseCSV(text) {
  const rows = []; let row = [], cell = '', quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === '"') {
      if (quoted && text[i + 1] === '"') {cell += '"'; i++;}
      else quoted = !quoted;
    } else if (c === ',' && !quoted) {row.push(cell); cell = '';}
    else if (c === '\r' && text[i + 1] === '\n' && !quoted) {row.push(cell); rows.push(row); row = []; cell = ''; i++;}
    else cell += c;
  }
  assert.equal(quoted, false, 'CSV quotes balance');
  return rows;
}
const exported = JSON.parse(R.json(R.items));
const [columns, ...csvRows] = parseCSV(R.csv(R.items));
assert.equal(exported.fittings.length, 231);
assert.equal(csvRows.length, 231);
for (let i = 0; i < R.items.length; i++) {
  const f = R.items[i], record = exported.fittings[i];
  const csv = Object.fromEntries(columns.map((k,j) => [k,csvRows[i][j]]));
  assert.equal(csv.id, f.id);
  assert.equal(csv.name, f.name);
  assert.equal(csv.source_fitting_code, f.code);
  assert.deepEqual(JSON.parse(csv.reference_json), record.reference, f.id + ' complete reference survives CSV round trip');
  assert.deepEqual(JSON.parse(csv.source_json), record.source);
  assert.deepEqual(JSON.parse(csv.conditions_json), record.reference.conditions);
  assert.equal(record.reference.fixed_equivalent_length_ft, f.fixed ?? null);
  assert.equal(csv.fixed_equivalent_length_ft, f.fixed === undefined ? '' : String(f.fixed));
  assert.ok(fs.existsSync(path.join(root, 'Public', R.imageURL(f).split('#')[0])));
  if (f.viewport) assert.match(fs.readFileSync(path.join(root, 'Public', f.image), 'utf8'), /width="640" height="520"/, f.id + ' sheet framing dimensions');
  assert.deepEqual(record.source, {document: 'ACCA Manual D', printed_page: f.page});
  assert.match(f.page, /^\d+(?:–\d+)?$/);
  for (const row of record.reference.table.rows) {
    assert.equal(row.keys.length, record.reference.table.labels.length);
    assert.equal(typeof row.value, 'number');
    assert.ok(Number.isFinite(row.value));
  }
}
const branch = exported.fittings.find(f => f.id === '2A');
assert.equal(branch.reference.table.rows.length, 6);
assert.equal(branch.reference.table.rows[5].keys[0], '5+');
assert.equal(branch.reference.table.rows[5].value, 80);
assert.equal(exported.fittings.find(f => f.id === '1M-2-vanes').source_fitting_code, '1M');
assert.equal(exported.fittings.find(f => f.id === '11-junction-box').artwork_status, 'concept');
const fixture = {...R.items[0], name: 'Test, "quoted"\nmultiline name', notes:['First line\nSecond line']};
const fixtureRows = parseCSV(R.csv([fixture]));
assert.equal(fixtureRows[1][columns.indexOf('name')], fixture.name);
assert.deepEqual(JSON.parse(fixtureRows[1][columns.indexOf('reference_json')]).notes, fixture.notes);
// Both catalogs must work using only the finished, self-contained artwork.
const runtime = JSON.parse(fs.readFileSync(path.join(root, 'Sources/FittingClient/Resources/catalog.json'), 'utf8'));
const drawings = new Set([
  ...R.items.map(f => R.imageURL(f).split('#')[0]),
  ...runtime.fittings.flatMap(f => [f.artwork, ...(f.alternateArtwork || [])].map(art => art.publicPath)),
]);
assert.equal(runtime.fittings.length, 227);
assert.equal(drawings.size, 234);
for (const url of drawings) {
  const svg = fs.readFileSync(path.join(root, 'Public', url), 'utf8');
  assert.match(svg, /<svg\b/, url);
  for (const [, href] of svg.matchAll(/\b(?:xlink:)?href=["']([^"']*)["']/g)) {
    assert.ok(href.startsWith('data:') || href.startsWith('#'), url + ' must not load an external asset: ' + href);
  }
}
assert.doesNotMatch(R.json(R.items), /\.pdf|\/source-art\/|\/references\/|manifest\.json/i);
console.log('PASS: 231 reference records; 227 runtime definitions; 234 standalone SVGs; 12 groups; citations; variant IDs; conditional tables; lossless JSON/CSV exports.');
