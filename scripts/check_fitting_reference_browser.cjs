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
    page.setDefaultTimeout(30000);
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(base + '/fittings?group=all');
    async function assertThemeColors() {
      await page.waitForFunction(() => {
        // Themes and transitions can serialize the same color as oklch or oklab.
        const canvas = document.createElement('canvas').getContext('2d');
        const color = value => {
          canvas.fillStyle = value;
          canvas.fillRect(0, 0, 1, 1);
          return [...canvas.getImageData(0, 0, 1, 1).data].join(',');
        };
        const button = document.querySelector('nav a[href="/ductulator"]');
        const probe = document.createElement('span');
        probe.style.color = 'var(--color-primary)';
        probe.style.backgroundColor = 'var(--accent-content)';
        document.getElementById('fittings-page').append(probe);
        const primary = color(getComputedStyle(probe).color);
        const foreground = color(getComputedStyle(probe).backgroundColor);
        probe.style.color = 'var(--accent-text)';
        const accentText = color(getComputedStyle(probe).color);
        probe.remove();
        const controls = document.querySelectorAll('.system-toggle [aria-current="true"], .group-item.active .group-number, [data-action="toggle-data"][aria-expanded="true"], .format-tabs [aria-current="true"]');
        return color(getComputedStyle(button).color) === primary
          && [...document.querySelectorAll('.text-button')].every(control => color(getComputedStyle(control).color) === accentText)
          && [...controls].every(control =>
          color(getComputedStyle(control).backgroundColor) === primary && color(getComputedStyle(control).color) === foreground);
      });
    }
    for (const theme of ['light', 'dark', 'nord', 'dim', 'dracula']) {
      await page.locator('[data-theme]').evaluate((element, value) => element.dataset.theme = value, theme);
      await assertThemeColors();
    }
    await page.goto(base + '/fittings?group=all');
    async function shortcut(key) {
      await page.keyboard.press(`Control+Alt+${key}`);
      await page.waitForFunction(() => !document.getElementById('fittings-page').hasAttribute('aria-busy'));
    }
    await page.keyboard.press('/');
    assert.equal(await page.locator('#search').evaluate(el => el === document.activeElement), false);
    await page.keyboard.press('Control+k');
    assert.equal(await page.locator('#search').evaluate(el => el === document.activeElement), true);
    assert.equal(await page.locator('#search').getAttribute('aria-keyshortcuts'), 'Control+K');
    assert.equal(await page.locator('.search kbd').innerText(), 'Ctrl+K');
    assert(await page.evaluate(() => {
      const press = (target, options = {}) => {
        const event = new KeyboardEvent('keydown', {
          key: 'k', ctrlKey: true, bubbles: true, cancelable: true, composed: true, ...options,
        });
        target.dispatchEvent(event);
        return event.defaultPrevented;
      };
      const search = document.getElementById('search');
      if (press(search)) return false;
      search.blur();
      for (const options of [{ ctrlKey: false }, { shiftKey: true }, { metaKey: true }, { repeat: true }, { isComposing: true }]) {
        if (press(document.body, options)) return false;
      }
      const editor = document.createElement('div');
      editor.contentEditable = 'true';
      editor.innerHTML = '<span>Draft</span>';
      document.body.append(editor);
      const intercepted = press(editor.firstChild);
      editor.remove();
      return !intercepted;
    }));
    for (const [index, key] of [...'1234567890'].entries()) {
      await shortcut(key);
      assert.equal(new URL(page.url()).searchParams.get('group'), String(index + 1));
    }
    await page.goto(base + '/fittings?group=all');
    for (let index = 0; index < 12; index++) {
      await shortcut('n');
      assert.equal(await page.locator('[data-group][aria-current="true"]').getAttribute('data-group'), String(index + 1));
    }
    await shortcut('n');
    assert.equal(new URL(page.url()).searchParams.get('group'), '12');
    for (let index = 0; index < 4; index++) await shortcut('p');
    const fittingIDs = await page.locator('[data-select]').evaluateAll(links => links.map(link => link.dataset.select));
    await shortcut('k');
    assert.equal(await page.locator('[data-select][aria-current="true"]').getAttribute('data-select'), fittingIDs[0]);
    for (const id of fittingIDs.slice(1, 12)) {
      await shortcut('j');
      assert.equal(await page.locator('[data-select][aria-current="true"]').getAttribute('data-select'), id);
      assert.equal(await page.evaluate(() => document.activeElement.dataset.select), id);
    }
    assert(await page.locator('.fitting-sidebar').evaluate(sidebar => {
      const item = sidebar.querySelector('[aria-current="true"]').getBoundingClientRect();
      const bounds = sidebar.getBoundingClientRect();
      return sidebar.scrollTop > 0 && item.top >= bounds.top - 1 && item.bottom <= bounds.bottom + 1;
    }));
    await page.goBack();
    await page.locator(`[data-select="${fittingIDs[10]}"][aria-current="true"]`).waitFor();
    await page.getByRole('button', { name: 'Keyboard shortcuts', exact: true }).click();
    await page.locator('#fittingsShortcuts[open]').waitFor();
    const beforeDialogKey = page.url();
    await page.keyboard.press('Control+k');
    assert.equal(await page.locator('#search').evaluate(el => el === document.activeElement), false);
    await shortcut('n');
    assert.equal(page.url(), beforeDialogKey);
    await page.locator('#fittingsShortcuts').evaluate(dialog => {
      dialog.addEventListener('close', () => { dialog.dataset.closeObserved = 'true'; }, { once: true });
    });
    await page.keyboard.press('Escape');
    await page.locator('#fittingsShortcuts[data-close-observed="true"]').waitFor({ state: 'attached' });
    assert.equal(await page.getByRole('button', { name: 'Keyboard shortcuts', exact: true }).evaluate(el => el === document.activeElement), true);
    await page.locator('#search').focus();
    await shortcut('n');
    assert.equal(page.url(), beforeDialogKey);
    await page.goto(base + '/fittings?system=return&group=8&q=8a%20smooth');
    await shortcut('n');
    assert.equal(new URL(page.url()).searchParams.get('group'), '10');
    assert.equal(new URL(page.url()).searchParams.get('q'), '8a smooth');
    await page.getByRole('heading', { name: 'No matching fittings' }).waitFor();
    const emptyURL = page.url();
    await shortcut('j');
    assert.equal(page.url(), emptyURL);
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto(base + '/fittings?system=return&group=8');
    await shortcut('n');
    assert.equal(await page.locator('#group-filter').inputValue(), '10');
    await page.setViewportSize({ width: 1440, height: 1000 });
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
    await assertThemeColors();
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
    await page.goto(base + '/fittings?system=return&group=8');
    await shortcut('p');
    assert.equal(new URL(page.url()).pathname, '/fittings');
    assert.equal(new URL(page.url()).searchParams.get('group'), '7');
    assert.equal(await page.locator('nav [aria-keyshortcuts="Control+Alt+P"]').count(), 0);
    await page.goto(base + '/logout');
    await page.goto(base + '/fittings?data=json');
    await page.locator('#fittings-page[data-tools="disabled"]').waitFor();
    assert.equal(await page.locator('[data-action="download-data"]').count(), 0);
    assert.deepEqual(errors, []);
    console.log('PASS: guest reference, actual login/HTMX return state, saved theme, CSV/JSON downloads, filtered export, path example, navigation/history, search focus, no-JavaScript browsing/downloads, mobile layout, and logout.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
