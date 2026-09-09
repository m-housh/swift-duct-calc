// Requires Playwright and a disposable running application; creates a test account.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
(async () => {
  const base = process.env.FITTING_APP_URL || 'http://localhost:8081';
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  try {
    const seed = await browser.newContext();
    const email = `reference-merge-${Date.now()}@example.test`, password = 'Aa1!' + require('node:crypto').randomUUID();
    const signup = await seed.request.post(base + '/signup', { form: { email, password, confirmPassword: password } });
    const signupHTML = await signup.text();
    const userID = signupHTML.match(/name="userID" value="([^"]+)"/)[1];
    await seed.request.post(base + '/signup/profile', { form: { userID, firstName: 'Reference', lastName: 'Review', companyName: 'QA', streetAddress: '1 Test Street', city: 'Cincinnati', state: 'OH', zipCode: '45202', theme: 'nord' } });
    await seed.close();
    const context = await browser.newContext({ viewport: { width: 1440, height: 1000 }, acceptDownloads: true });
    const page = await context.newPage(), errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(base + '/fittings?system=return&group=8&fitting=8A-smooth&type=conditional&data=csv');
    await page.locator('[data-select="8A-smooth"]').waitFor();
    assert.equal(await page.locator('a[href*=".pdf"], a[href*="manifest.json"]').count(), 0);
    await page.locator('.detail .artboard img').evaluate(image => image.decode());
    assert.equal(await page.locator('#fittings-page').getAttribute('data-tools'), 'disabled');
    assert.equal(await page.locator('[data-action="toggle-data"]').count(), 0);
    assert.equal(await page.locator('#combined-data').isVisible(), false);
    const next = new URL(await page.locator('[data-login]').getAttribute('href'), base).searchParams.get('next');
    assert.equal(new URL(next, base).searchParams.get('data'), 'csv');
    await page.locator('[data-login]').click();
    await page.locator('[name=email]').fill(email); await page.locator('[name=password]').fill(password);
    await page.getByRole('button', { name: 'Login', exact: true }).click();
    await page.locator('#fittings-page[data-tools="enabled"]').waitFor();
    await page.locator('[data-format="csv"][aria-pressed="true"]').waitFor();
    const query = new URL(page.url()).searchParams;
    for (const [key, value] of Object.entries({ system: 'return', group: '8', fitting: '8A-smooth', type: 'conditional', data: 'csv' })) assert.equal(query.get(key), value);
    assert.equal(await page.locator('[data-theme="nord"]').count(), 1);
    assert(await page.locator('link[href="/fittings/styles.css"]').count());
    assert(await page.evaluate(() => {
      const root = document.querySelector('#fittings-page'), probe = document.createElement('span');
      probe.style.backgroundColor = 'var(--color-base-100)'; root.append(probe);
      const same = getComputedStyle(root).backgroundColor === getComputedStyle(probe).backgroundColor;
      probe.remove(); return same;
    }));
    async function download() {
      const pending = page.waitForEvent('download');
      await page.locator('[data-action="download-data"]').click();
      const file = await pending; return fs.readFileSync(await file.path(), 'utf8');
    }
    const csv = await download(); assert(csv.includes('8A-smooth')); assert(csv.includes('reference_json'));
    await page.locator('[data-format="json"]').click();
    const record = JSON.parse(await download()); assert.equal(record.fittings.length, 1); assert.equal(record.fittings[0].id, '8A-smooth');
    assert.deepEqual(record.fittings[0].source, { document: 'ACCA Manual D', printed_page: '176' });
    await page.locator('#scope').selectOption('filtered');
    const all = JSON.parse(await download());
    assert.equal(all.fittings.length, await page.locator('[data-select]').count()); assert(all.fittings.length > 1);
    await page.locator('[data-format="path"]').click();
    assert((await page.locator('.code-panel pre').innerText()).includes('duct-calc.path-example.prototype.v1'));
    await page.locator('[data-format="json"]').click();
    await page.screenshot({ path: '/tmp/fitting-reference-integrated-desktop.png', animations: 'disabled' });
    await page.setViewportSize({ width: 390, height: 844 });
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
    assert.equal(await page.locator('#filters > .system-toggle').count(), 1);
    await page.screenshot({ path: '/tmp/fitting-reference-integrated-mobile.png', animations: 'disabled' });
    await page.goto(base + '/logout');
    await page.goto(base + '/fittings?data=json');
    await page.locator('#fittings-page[data-tools="disabled"]').waitFor();
    assert.equal(await page.locator('[data-action="download-data"]').count(), 0);
    assert.deepEqual(errors, []);
    console.log('PASS: guest reference, actual login/HTMX return state, saved theme, CSV/JSON downloads, filtered export, path example, mobile layout, and logout.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
