// Run after check_fitting_path.cjs against the same disposable application.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  try {
    const context = await browser.newContext({ storageState: '/tmp/fitting-review-auth.json', viewport: { width: 1440, height: 1000 } });
    const page = await context.newPage(), errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('dialog', dialog => dialog.accept());
    await page.goto(fs.readFileSync('/tmp/fitting-review-path.txt', 'utf8').trim());
    async function snapshot() {
      const value = JSON.parse(await page.locator('#fitting-path').getAttribute('data-baseline'));
      delete value.updatedAt; return value;
    }
    const baseline = await snapshot();
    const total = await page.locator('#path-total').innerText();
    const prefer = value => page.locator(`[name="shape-preference"][value="${value}"]`);
    const cards = page.locator('.fitting-grid [data-catalog-id]');
    async function group(id) {
      await page.locator('#choose-groups').click();
      const carousel = page.locator('[data-path-carousel="supply"]');
      await carousel.getByRole('button', { name: new RegExp(`^Show Group ${id}:`) }).click();
      await carousel.locator('.is-current [data-choose-group]').click();
      await page.locator('.fitting-grid').waitFor();
    }
    async function select(value) { await page.locator('.picker-segment-options label').filter({ has: prefer(value) }).click(); }
    await page.locator('[data-open-picker]').click();
    assert(await prefer('none').isChecked());
    // Native radio keys move the preference without losing keyboard focus.
    await prefer('none').focus(); await prefer('none').press('ArrowRight');
    assert(await prefer('round').isChecked());
    await group(1);
    assert.equal(await cards.first().getAttribute('data-catalog-id'), '1A');
    const count = await cards.count();
    if (await page.locator('[data-favorite="1D"]').getAttribute('aria-pressed') !== 'true') await page.locator('[data-favorite="1D"]').click();
    await page.waitForFunction(() => document.querySelector('[data-favorite="1D"]').getAttribute('aria-pressed') === 'true');
    assert.equal(await cards.first().getAttribute('data-catalog-id'), '1A', 'Nonmatching favorite must stay below preferred shapes');
    await select('rectangular');
    assert.equal(await cards.first().getAttribute('data-catalog-id'), '1D');
    assert.equal(await cards.count(), count);
    await select('none');
    assert.equal(await cards.first().getAttribute('data-catalog-id'), '1D', 'No preference restores favorite-first ordering');
    await select('round');
    await page.locator('#catalog-search').fill('1D');
    assert(await page.locator('[data-catalog-id="1D"]').isVisible(), 'Search must include other shapes');
    assert.equal(await page.locator('.shape-section-heading:visible').innerText(), 'Other shapes');
    await page.locator('#catalog-search').fill('nothing matches');
    assert(await page.locator('#catalog-empty').isVisible());
    assert.equal(await page.locator('.shape-section-heading:visible').count(), 0);
    await page.locator('#catalog-search').fill('');
    await group(2);
    assert(await prefer('round').isChecked());
    assert.equal(await page.locator('[data-catalog-id="2A"]').getAttribute('data-shape-section'), '0', 'Mixed round takeoff is shared');
    assert.equal(await page.locator('[data-catalog-id="2D"]').getAttribute('data-shape-section'), '1');
    await group(4);
    assert.equal(await page.locator('[data-catalog-id="4A"]').getAttribute('data-shape-section'), '0', 'Round boot with rectangular outlet is shared');
    await group(8);
    const offset = page.locator('[data-catalog-id="8O"]');
    await offset.locator('[name="insideCornerRadius"]').selectOption('oneQuarter');
    await page.waitForFunction(() => document.querySelector('[data-catalog-id="8O"] .fp-result').textContent.includes('90 ft'));
    await select('rectangular');
    assert.equal(await offset.locator('[name="insideCornerRadius"]').inputValue(), 'oneQuarter');
    assert((await offset.locator('.fp-result').innerText()).includes('90 ft'));
    assert.equal(await cards.first().getAttribute('data-catalog-id'), '8O', 'Matching favorite first');
    await select('round');
    await page.screenshot({ path: '/tmp/fitting-preference-desktop.png' });
    await page.setViewportSize({ width: 390, height: 844 });
    await page.locator('#picker-dialog').evaluate(dialog => { dialog.scrollTop = 0; });
    assert(await page.locator('#picker-dialog').evaluate(dialog => dialog.scrollWidth <= dialog.clientWidth));
    await page.screenshot({ path: '/tmp/fitting-preference-mobile.png' });
    await page.locator('[data-close-dialog="picker-dialog"]').click();
    assert.deepEqual(await snapshot(), baseline);
    assert.equal(await page.locator('#path-total').innerText(), total);
    await Promise.all([page.waitForEvent('domcontentloaded'), page.locator('#save-path').click()]);
    await page.locator('[data-open-picker]').click();
    assert(await prefer('round').isChecked(), 'Preference survives save/reload');
    assert.deepEqual(await snapshot(), baseline);
    assert.equal(await page.locator('#path-total').innerText(), total);
    // Blocked storage still allows sorting for the current editor session.
    await page.addInitScript(() => Object.defineProperty(window, 'localStorage', { get() { throw Error('Storage disabled'); } }));
    await page.reload(); await page.locator('[data-open-picker]').click();
    assert(await prefer('none').isChecked());
    await select('rectangular'); await group(1);
    assert.equal(await cards.first().getAttribute('data-catalog-id'), '1D');
    assert.deepEqual(errors, []);
    console.log('PASS: preference ordering, favorites, mixed connections, search, preserved inputs/path, keyboard, mobile, reload, and blocked storage.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
