// Use only with a disposable review source and database; this intentionally edits its catalog.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
(async () => {
  const base = process.env.FITTING_REVIEW_URL || 'http://localhost:8082';
  const source = process.env.FITTING_REVIEW_CATALOG;
  assert(source, 'Set FITTING_REVIEW_CATALOG to the disposable host catalog path');
  assert(!source.includes('/Sources/'), 'Use a disposable catalog, not the checked-out source');
  // Seed pending review status only in this disposable test catalog.
  const initial = fs.readFileSync(source, 'utf8').replaceAll('"ductShapeReviewed": true', '"ductShapeReviewed": false');
  fs.writeFileSync(source, initial);
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  try {
    const anonymous = await browser.newContext();
    const blockedRead = await anonymous.request.get(base + '/fittings/review?group=4', { maxRedirects: 0 });
    assert([302, 303].includes(blockedRead.status())); assert(blockedRead.headers().location.includes('/login'));
    const blockedWrite = await anonymous.request.post(base + '/fittings/review', { form: { payload: '{}' }, maxRedirects: 0 });
    assert([302, 303].includes(blockedWrite.status())); assert.equal(fs.readFileSync(source, 'utf8'), initial);
    const context = await browser.newContext({ viewport: { width: 1440, height: 1000 } });
    const password = require('node:crypto').randomUUID();
    await context.request.post(base + '/signup', { form: { email: `catalog-review-${Date.now()}@example.test`, password, confirmPassword: password } });
    const page = await context.newPage(), errors = [];
    page.on('pageerror', error => errors.push(error.message)); page.on('dialog', dialog => dialog.accept());
    await page.goto(base + '/fittings/review?group=4');
    await page.locator('#catalog-review').waitFor();
    assert.equal(await page.locator('[data-review-id]').count(), 44);
    const card = id => page.locator(`[data-review-id="${id}"]`);
    assert.equal(await card('4A').locator('[name=ductShape]').inputValue(), 'rectangular');
    assert.equal(await card('4G').locator('[name=ductShape]').inputValue(), 'round');
    assert.equal(await card('4A').locator('[name=reviewed]').isChecked(), false);
    // A second page holds a stale baseline before the first save.
    const stale = await context.newPage(); await stale.goto(page.url());
    stale.on('dialog', dialog => dialog.accept());
    await card('4A').locator('[name=ductShape]').selectOption('round');
    assert(await card('4A').locator('[name=reviewed]').isChecked());
    await page.locator('#save-catalog-review').click();
    await page.locator('#review-status').filter({ hasText: 'Saved to catalog.json' }).waitFor();
    const changed = JSON.parse(fs.readFileSync(source, 'utf8'));
    const record = changed.fittings.find(item => item.id === '4A');
    assert.equal(record.ductShape, 'round'); assert.equal(record.ductShapeReviewed, true);
    const expected = JSON.parse(initial); const expectedRecord = expected.fittings.find(item => item.id === '4A');
    expectedRecord.ductShape = 'round'; expectedRecord.ductShapeReviewed = true;
    assert.deepEqual(changed, expected, 'Only requested metadata may change');
    assert.equal(await page.locator('[data-review-group="4"]').innerText(), 'Group 4 · 1/44');
    // The actual picker fragment must use the new classification without a restart.
    const fragment = await context.request.post(base + '/fittings/group', { form: { payload: JSON.stringify({ pathType: 'supply', groupID: 4 }) } });
    const fragmentHTML = await fragment.text();
    assert.match(fragmentHTML, /data-catalog-id="4A"[^>]*data-duct-shape="round"/);
    await page.reload(); assert.equal(await card('4A').locator('[name=ductShape]').inputValue(), 'round');
    assert(await card('4A').locator('[name=reviewed]').isChecked());
    await stale.locator('[data-review-id="4B"] [name=reviewed]').check();
    await stale.locator('#save-catalog-review').click();
    await stale.locator('#review-status').filter({ hasText: 'catalog changed' }).waitFor();
    assert(await stale.locator('[data-review-id="4B"] [name=reviewed]').isChecked());
    assert.deepEqual(JSON.parse(fs.readFileSync(source, 'utf8')), expected);
    await stale.close();
    // Unknown IDs and invalid choices cannot write; use the current page's version.
    const version = await page.locator('#catalog-review').getAttribute('data-version');
    for (const change of [{ id: 'missing', ductShape: 'round', reviewed: true }, { id: '4A', ductShape: 'invented', reviewed: true }]) {
      const response = await context.request.post(base + '/fittings/review', { form: { payload: JSON.stringify({ version, changes: [change] }) } });
      assert(!(await response.text()).includes('data-review-saved'));
      assert.deepEqual(JSON.parse(fs.readFileSync(source, 'utf8')), expected);
    }
    // Return the disposable catalog to its original values via the real editor.
    await card('4A').locator('[name=ductShape]').selectOption('rectangular');
    await card('4A').locator('[name=reviewed]').uncheck();
    await page.locator('#save-catalog-review').click();
    await page.locator('#review-status').filter({ hasText: 'Saved to catalog.json' }).waitFor();
    assert.equal(fs.readFileSync(source, 'utf8'), initial, 'Round trip preserves exact source formatting');
    // Row selection alone never changes the catalog or enables Save.
    assert.equal(await page.locator('tbody tr[data-review-id]').count(), 44);
    assert(await page.locator('#review-apply-shape').isDisabled());
    await card('4A').locator('[name=selected]').click();
    await card('4C').locator('[name=selected]').click({ modifiers: ['Shift'] });
    assert.equal(await page.locator('#review-selection-count').innerText(), '3 selected');
    assert(await page.locator('#review-select-all').evaluate(input => input.indeterminate));
    assert(await page.locator('#save-catalog-review').isDisabled());
    await page.locator('#review-bulk-shape').selectOption('oval');
    await page.locator('#review-apply-shape').click();
    for (const id of ['4A', '4B', '4C']) {
      assert.equal(await card(id).locator('[name=ductShape]').inputValue(), 'oval');
      assert(await card(id).locator('[name=reviewed]').isChecked());
    }
    assert.equal(await card('4D').locator('[name=ductShape]').inputValue(), 'rectangular');
    assert.equal(await card('4D').locator('[name=reviewed]').isChecked(), false);
    assert.equal(fs.readFileSync(source, 'utf8'), initial, 'Bulk actions remain drafts until Save');
    // Failed bulk saves retain both choices and selection for retry.
    await page.route('**/fittings/review', route => route.abort());
    await page.locator('#save-catalog-review').click();
    await page.waitForFunction(() => !document.querySelector('#catalog-review').inert);
    assert(await page.locator('#save-catalog-review').isEnabled());
    assert.equal(await page.locator('#review-selection-count').innerText(), '3 selected');
    assert.equal(fs.readFileSync(source, 'utf8'), initial);
    await page.unroute('**/fittings/review');
    await page.locator('#save-catalog-review').click();
    await page.locator('#review-status').filter({ hasText: 'Saved to catalog.json' }).waitFor();
    const bulkExpected = JSON.parse(initial);
    for (const item of bulkExpected.fittings.filter(item => ['4A', '4B', '4C'].includes(item.id))) {
      item.ductShape = 'oval'; item.ductShapeReviewed = true;
    }
    assert.deepEqual(JSON.parse(fs.readFileSync(source, 'utf8')), bulkExpected);
    await page.reload();
    assert.equal(await page.locator('#review-selection-count').innerText(), '0 selected');
    assert.equal(await card('4C').locator('[name=ductShape]').inputValue(), 'oval');
    await page.locator('#review-select-all').check();
    assert.equal(await page.locator('#review-selection-count').innerText(), '44 selected');
    await page.locator('#review-mark-reviewed').click();
    assert.equal(await page.locator('[name=reviewed]:checked').count(), 44);
    assert.equal(await card('4G').locator('[name=ductShape]').inputValue(), 'round');
    await page.locator('#review-mark-pending').click();
    assert.equal(await page.locator('[name=reviewed]:checked').count(), 0);
    await page.locator('#review-clear-selection').click();
    assert.equal(await page.locator('#review-selection-count').innerText(), '0 selected');
    assert(await page.locator('#review-mark-reviewed').isDisabled());
    for (const id of ['4A', '4B', '4C']) await card(id).locator('[name=selected]').check();
    await page.locator('#review-bulk-shape').selectOption('rectangular');
    await page.locator('#review-apply-shape').click();
    await page.locator('#review-mark-pending').click();
    await page.locator('#save-catalog-review').click();
    await page.locator('#review-status').filter({ hasText: 'Saved to catalog.json' }).waitFor();
    assert.equal(fs.readFileSync(source, 'utf8'), initial, 'Bulk round trip preserves exact file');
    await page.locator('#review-clear-selection').click();
    // Capture the table with a representative range selected, ready for bulk editing.
    await card('4A').locator('[name=selected]').click();
    await card('4F').locator('[name=selected]').click({ modifiers: ['Shift'] });
    assert.equal(await page.locator('[name=selected]:checked').count(), 6);
    await page.evaluate(() => { window.scrollTo(0, 0); document.querySelector('.review-table-scroll').scrollTop = 0; });
    await page.screenshot({ path: '/tmp/catalog-review-desktop.png', fullPage: false, animations: 'disabled' });
    await page.setViewportSize({ width: 390, height: 844 });
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
    await page.locator('.review-save-bar').scrollIntoViewIfNeeded();
    await page.screenshot({ path: '/tmp/catalog-review-mobile.png', animations: 'disabled' });
    await page.locator('[data-review-group="2"]').click();
    assert.equal(await card('2A').locator('[name=ductShape]').inputValue(), 'rectangular');
    assert.equal(await card('2N').locator('[name=ductShape]').inputValue(), 'round');
    assert.deepEqual(errors, []);
    console.log('PASS: authenticated review, persisted source edits, live picker metadata, reload, stale/invalid rejection, exact formatting round trip, groups, bulk/range selection, failed bulk save retry, and mobile.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
