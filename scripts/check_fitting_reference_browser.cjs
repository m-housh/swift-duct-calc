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
    await page.locator('[data-format="csv"][aria-current="true"]').waitFor();
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
    await page.locator('[data-format="json"][aria-current="true"]').waitFor();
    const record = JSON.parse(await download()); assert.equal(record.fittings.length, 1); assert.equal(record.fittings[0].id, '8A-smooth');
    assert.deepEqual(record.fittings[0].source, { document: 'ACCA Manual D', printed_page: '176' });
    await page.locator('#scope').selectOption('filtered');
    const all = JSON.parse(await download());
    assert.equal(all.fittings.length, await page.locator('[data-select]').count()); assert(all.fittings.length > 1);
    await page.locator('[data-format="path"]').click();
    await page.locator('[data-format="path"][aria-current="true"]').waitFor();
    assert((await page.locator('.code-panel pre').innerText()).includes('duct-calc.path-example.prototype.v1'));
    await page.locator('[data-format="json"]').click();
    await page.locator('[data-format="json"][aria-current="true"]').waitFor();
    // Swift's downloadable JSON must preserve every migrated record, including nulls.
    const exportedAll = await context.request.get(base + '/fittings?group=all&data=json&scope=filtered&download=1');
    assert.equal(exportedAll.status(), 200);
    const expected = JSON.parse(fs.readFileSync(require('node:path').join(__dirname, '../Sources/FittingClient/Resources/reference.json'), 'utf8')).entries.map(entry => entry.record);
    assert.deepEqual((await exportedAll.json()).fittings, expected);

    // Server navigation preserves focus, search state, and browser history.
    await page.locator('[data-group="6"]').click();
    await page.locator('[data-group="6"][aria-current="true"]').waitFor();
    await page.goBack();
    await page.locator('[data-select="8A-smooth"][aria-current="true"]').waitFor();
    await page.locator('#search').fill('no-such-fitting');
    await page.getByRole('heading', { name: 'No matching fittings' }).waitFor();
    assert.equal(await page.locator('#search').evaluate(el => el === document.activeElement), true);
    await page.locator('#search').fill('8a smooth');
    await page.waitForFunction(() => document.querySelectorAll('[data-select]').length === 1);
    assert.equal(await page.locator('#search').inputValue(), '8a smooth');
    await page.locator('[data-select="8A-smooth"]').click();
    await page.locator('[data-select="8A-smooth"][aria-current="true"]').waitFor();
    await page.waitForFunction(() => !document.getElementById('fittings-page').hasAttribute('aria-busy'));
    await page.screenshot({ path: '/tmp/fitting-reference-integrated-desktop.png', animations: 'disabled' });
    await page.setViewportSize({ width: 390, height: 844 });
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
    await page.locator('#filters > .system-toggle').waitFor();
    await page.screenshot({ path: '/tmp/fitting-reference-integrated-mobile.png', animations: 'disabled' });
    // The same reference, filtering, inspector, and downloads work without JavaScript.
    const plain = await browser.newContext({ javaScriptEnabled: false, storageState: await context.storageState(), acceptDownloads: true });
    const plainPage = await plain.newPage();
    await plainPage.goto(base + '/fittings?group=8&fitting=8A-smooth&data=json');
    assert.equal(await plainPage.locator('.source-table').count(), 1);
    assert.equal(await plainPage.locator('[data-select="8A-smooth"][aria-current="true"]').count(), 1);
    await plainPage.locator('[data-group="2"]').click();
    await plainPage.locator('[data-group="2"][aria-current="true"]').waitFor();
    await plainPage.locator('#group-filter').selectOption('all');
    await plainPage.locator('#search').fill('8a smooth');
    await plainPage.locator('#filters button[type="submit"]').click();
    await plainPage.waitForURL(url => url.searchParams.get('q') === '8a smooth');
    assert.equal(await plainPage.locator('[data-select]').count(), 2);
    const plainDownload = plainPage.waitForEvent('download');
    await plainPage.locator('[data-action="download-data"]').click();
    assert.equal(JSON.parse(fs.readFileSync(await (await plainDownload).path(), 'utf8')).fittings.length, 1);
    await plain.close();
    await page.goto(base + '/logout');
    await page.goto(base + '/fittings?data=json');
    await page.locator('#fittings-page[data-tools="disabled"]').waitFor();
    assert.equal(await page.locator('[data-action="download-data"]').count(), 0);
    assert.deepEqual(errors, []);
    console.log('PASS: guest reference, actual login/HTMX return state, saved theme, CSV/JSON downloads, filtered export, path example, navigation/history, search focus, no-JavaScript browsing/downloads, mobile layout, and logout.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
