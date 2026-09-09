// Requires Playwright and a disposable application; creates an isolated user and path.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const { saveAndReopen } = require('./fitting_browser_helpers.cjs');
(async () => {
  const base = process.env.FITTING_APP_URL || 'http://localhost:8081';
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  try {
    const context = await browser.newContext({ viewport: { width: 1440, height: 1000 } });
    const password = require('node:crypto').randomUUID(), suffix = Date.now();
    await context.request.post(base + '/signup', { form: { email: `radius-default-${suffix}@example.test`, password, confirmPassword: password } });
    const project = await context.request.post(base + '/projects', { form: { name: `Radius default ${suffix}`, streetAddress: '1 Test Street', city: 'Cincinnati', state: 'OH', zipCode: '45202' } });
    const id = (await project.text()).match(/projects\/([0-9A-Fa-f-]{36})/)[1];
    const page = await context.newPage(), errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('dialog', dialog => dialog.accept());
    await page.goto(`${base}/projects/${id}/effective-lengths/editor`);
    await page.locator('#path-name').fill('Round radius defaults');
    async function group8() {
      await page.locator('[data-open-picker]').click();
      const carousel = page.locator('[data-path-carousel="supply"]');
      await carousel.getByRole('button', { name: /^Show Group 8:/ }).click();
      await carousel.locator('.is-current [data-choose-group]').click();
      await page.locator('#catalog-grid').waitFor();
    }
    await group8();
    const card = id => page.locator(`[data-catalog-id="${id}"]`);
    for (const [id, feet] of [['8A-smooth', 15], ['8A-4-or-5-piece', 20], ['8A-3-piece', 25]]) {
      assert.equal(await card(id).locator('[name=radiusRatio]').inputValue(), '1.0');
      assert((await card(id).locator('.fp-result').innerText()).includes(`${feet} ft`));
      for (const pair of ['8L-round', '8M-round']) {
        await card(pair).locator('[name=baseFitting]').selectOption(id);
        await page.waitForFunction(({pair, expected}) =>
          document.querySelector(`[data-catalog-id="${pair}"] .fp-result`).textContent.includes(`${expected} ft`),
          { pair, expected: feet * (pair === '8L-round' ? 1.7 : 2) });
        assert.equal(await card(pair).locator('[name="base.radiusRatio"]').inputValue(), '1.0');
      }
    }
    assert.equal(await card('8O').locator('[name=insideCornerRadius]').inputValue(), 'mitered');
    await card('8A-smooth').locator('[data-favorite]').click();
    await page.locator('[data-favorite-copy="8A-smooth"]').waitFor();
    assert.equal(await page.locator('[data-favorite-copy="8A-smooth"] [name=radiusRatio]').inputValue(), '1.0');
    await card('8A-smooth').locator('[name=radiusRatio]').selectOption('0.75');
    await page.waitForFunction(() => document.querySelector('[data-catalog-id="8A-smooth"] .fp-result').textContent.includes('20 ft'));
    await card('8A-smooth').locator('[data-row]').click();
    await page.locator('#path-rows [data-row-id]').waitFor();
    await saveAndReopen(page);
    await page.locator('[data-edit-row]').click();
    assert.equal(await page.locator('#edit-fitting [name=radiusRatio]').inputValue(), '0.75');
    await page.locator('[data-close-dialog="edit-dialog"]').click();
    await group8();
    assert.equal(await card('8A-smooth').locator('[name=radiusRatio]').inputValue(), '1.0');
    assert.deepEqual(errors, []);
    console.log('PASS: R/D 1.0 defaults and results for three elbow variants, both round pairs, favorite copies, preserved saved radius, and unchanged 8O default.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
