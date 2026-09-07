// Run after check_fitting_path.cjs against the same disposable application.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  try {
    const context = await browser.newContext({ storageState: '/tmp/fitting-review-auth.json', viewport: { width: 1440, height: 1000 } });
    const page = await context.newPage(), errors = [];
    page.on('pageerror', error => errors.push(error.message)); page.on('dialog', dialog => dialog.accept());
    await page.goto(fs.readFileSync('/tmp/fitting-review-path.txt', 'utf8').trim());
    async function group(id) {
      if (!await page.locator('#picker-dialog').evaluate(dialog => dialog.open)) await page.locator('[data-open-picker]').click();
      await page.locator('#choose-groups').click();
      const carousel = page.locator('[data-path-carousel="supply"]');
      await carousel.getByRole('button', { name: new RegExp(`^Show Group ${id}:`) }).click();
      await carousel.locator('.is-current [data-choose-group]').click();
      await page.locator('#catalog-grid').waitFor();
    }
    const original = id => page.locator(`[data-catalog-id="${id}"]`);
    const copy = id => page.locator(`[data-favorite-copy="${id}"]`);
    const order = () => page.locator('#catalog-grid > *').evaluateAll(cards => cards.map(card => card.dataset.catalogId));
    async function favorite(id, selected) {
      const star = original(id).locator('[data-favorite]');
      if ((await star.getAttribute('aria-pressed') === 'true') !== selected) await star.click();
      await page.waitForFunction(({ id, selected }) => {
        const button = document.querySelector(`[data-catalog-id="${id}"] [data-favorite]`);
        return button.getAttribute('aria-pressed') === String(selected) && !button.disabled;
      }, { id, selected });
    }
    const rows = await page.locator('#path-rows [data-row-id]').count();
    await group(4); await favorite('4AR', false);
    const beforeOrder = await order();
    const star = original('4AR').locator('[data-favorite]'); await star.scrollIntoViewIfNeeded();
    const before = await original('4AR').boundingBox();
    await favorite('4AR', true);
    assert.deepEqual(await order(), beforeOrder);
    assert(Math.abs((await original('4AR').boundingBox()).y - before.y) < 2, 'Favoriting must preserve the source card screen position');
    assert.equal(await copy('4AR').count(), 1);
    assert.equal(await page.locator('#catalog-favorites').getAttribute('open'), null);
    await original('4AR').locator('[data-row]').click();
    await page.waitForFunction(count => document.querySelectorAll('#path-rows [data-row-id]').length === count, rows + 1);
    assert((await page.locator('#path-rows [data-row-id]').last().innerText()).includes('4AR'));
    // Favorite copies can add fittings and leave the full catalog intact.
    await group(4); await page.locator('#catalog-favorites > summary').click();
    assert(await copy('4AR').isVisible());
    await copy('4AR').locator('.fp-active-art').press('Enter');
    await page.waitForFunction(count => document.querySelectorAll('#path-rows [data-row-id]').length === count, rows + 2);
    // Conditional originals retain their inputs while copies have independent drafts.
    await group(8); await favorite('8O', false);
    await original('8O').locator('[name=insideCornerRadius]').selectOption('oneQuarter');
    await page.waitForFunction(() => document.querySelector('[data-catalog-id="8O"] .fp-result').textContent.includes('90 ft'));
    await favorite('8O', true);
    assert.equal(await original('8O').locator('[name=insideCornerRadius]').inputValue(), 'oneQuarter');
    assert((await original('8O').locator('.fp-result').innerText()).includes('90 ft'));
    await page.locator('#catalog-favorites > summary').click();
    await copy('8O').locator('[name=insideCornerRadius]').selectOption('greaterThanOneHalf');
    await page.waitForFunction(() => document.querySelector('[data-favorite-copy="8O"] .fp-result').textContent.includes('45 ft'));
    assert.equal(await original('8O').locator('[name=insideCornerRadius]').inputValue(), 'oneQuarter');
    await page.screenshot({ path: '/tmp/fitting-favorites.png' });
    await copy('8O').locator('[data-row]').click();
    await page.waitForFunction(count => document.querySelectorAll('#path-rows [data-row-id]').length === count, rows + 3);
    assert((await page.locator('#path-rows [data-row-id]').last().innerText()).includes('45 ft'));
    // Even with Favorites expanded, adding a copy above the catalog keeps the source under the pointer.
    await group(4); await favorite('4AQ', false); await page.locator('#catalog-favorites > summary').click();
    await original('4AQ').locator('[data-favorite]').scrollIntoViewIfNeeded();
    const expandedBefore = await original('4AQ').boundingBox(); const expandedOrder = await order();
    await favorite('4AQ', true);
    assert.deepEqual(await order(), expandedOrder);
    assert(Math.abs((await original('4AQ').boundingBox()).y - expandedBefore.y) < 2);
    // Search applies to both lists without removing the source copy.
    await page.locator('#catalog-search').fill('4AQ');
    assert(await copy('4AQ').isVisible()); assert(await original('4AQ').isVisible());
    await page.locator('#catalog-search').fill('');
    await page.setViewportSize({ width: 390, height: 844 });
    await page.locator('#catalog-favorites > summary').scrollIntoViewIfNeeded();
    assert(await page.locator('#picker-dialog').evaluate(dialog => dialog.scrollWidth <= dialog.clientWidth));
    await page.screenshot({ path: '/tmp/fitting-favorites-mobile.png' });
    // Failed favorite writes leave both membership and catalog order unchanged.
    await favorite('4AQ', false);
    const failedOrder = await order();
    await page.route('**/favorite', route => route.fulfill({ status: 500 }));
    await original('4AQ').locator('[data-favorite]').click();
    await page.locator('#picker-status').filter({ hasText: 'Request failed' }).waitFor();
    assert.equal(await original('4AQ').locator('[data-favorite]').getAttribute('aria-pressed'), 'false');
    assert.equal(await copy('4AQ').count(), 0); assert.deepEqual(await order(), failedOrder);
    await page.unroute('**/favorite');
    // The junction-box copy keeps the wide desktop layout and independent bend controls.
    await page.setViewportSize({ width: 1440, height: 1000 });
    await group(11); await favorite('11-junction-box', true); await page.locator('#catalog-favorites > summary').click();
    const flex = copy('11-junction-box');
    assert((await flex.boundingBox()).width > 1000);
    await flex.locator('[name=suppliedBend]').check(); await flex.locator('[name=bendVelocity]').selectOption('900');
    await page.waitForFunction(() => document.querySelector('[data-favorite-copy="11-junction-box"] .fp-result').textContent.includes('80 ft'));
    assert.equal(await original('11-junction-box').locator('[name=suppliedBend]').isChecked(), false);
    await page.setViewportSize({ width: 390, height: 844 });
    assert(await page.locator('#picker-dialog').evaluate(dialog => dialog.scrollWidth <= dialog.clientWidth));
    await flex.locator('[data-favorite]').click();
    await flex.waitFor({ state: 'detached' });
    assert.equal(await original('11-junction-box').locator('[data-favorite]').getAttribute('aria-pressed'), 'false');
    assert(await page.locator('#catalog-favorites > summary').evaluate(node => node === document.activeElement));
    assert.deepEqual(errors, []);
    console.log('PASS: stable catalog order and scroll, collapsed/expanded favorites, add from original/copy, independent conditional inputs, search, mobile, and failed writes.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
