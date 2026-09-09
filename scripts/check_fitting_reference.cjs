/* Run with: node scripts/check_fitting_reference.cjs */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const reference = JSON.parse(fs.readFileSync(path.join(root, 'Sources/FittingClient/Resources/reference.json'), 'utf8'));
const {entries, groups} = reference;
assert.equal(reference.schemaVersion, 1);
assert.equal(entries.length, 231);
assert.equal(new Set(entries.map(f => f.record.id)).size, 231);
assert.equal(groups.length, 12);
assert.equal(entries.filter(f => f.record.artwork_status !== 'concept').length, 230);
for (const {record, viewport} of entries) {
  assert.match(record.source.printed_page, /^\d+(?:–\d+)?$/);
  assert.equal(record.source.document, 'ACCA Manual D');
  if (viewport) {
    assert.equal(viewport.length, 4);
    assert.match(fs.readFileSync(path.join(root, 'Public', record.image_url.split('#')[0]), 'utf8'), /width="640" height="520"/, record.id + ' sheet framing dimensions');
  }
  for (const row of record.reference.table.rows) {
    assert.equal(row.keys.length, record.reference.table.labels.length);
    assert.ok(Number.isFinite(row.value));
  }
}
// Both catalogs must work using only the finished, self-contained artwork.
const runtime = JSON.parse(fs.readFileSync(path.join(root, 'Sources/FittingClient/Resources/catalog.json'), 'utf8'));
const drawings = new Set([
  ...entries.map(({record}) => record.image_url.split('#')[0]),
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
assert.doesNotMatch(JSON.stringify(reference), /\.pdf|\/source-art\/|\/references\/|manifest\.json/i);
console.log('PASS: 231 reference records; 227 runtime definitions; 234 standalone SVGs; 12 groups; citations; variant IDs; conditional tables. Swift tests cover filtering and JSON/CSV exports.');
