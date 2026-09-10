// Requires Playwright with Chromium installed. Uses rendered view snapshots, no running app.
// Optionally set HTMX_SCRIPT_PATH to a local copy of the HTMX version used by MainPage.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const snapshot = fs.readFileSync(path.join(root,
  'Tests/ViewControllerTests/__Snapshots__/ViewControllerTests/projectDetail.6.html'), 'utf8');
const component = fs.readFileSync(path.join(root, 'Public/js/daisy-multiselect.js'), 'utf8');
const htmxURL = snapshot.match(/<script src="(https:[^"]*htmx\.org[^"]*)"/)[1];
// Keep the production script order, excluding unrelated scripts and external styling.
const html = snapshot.replace(/<script\b[^>]*>[\s\S]*?<\/script>/g, tag =>
  tag.includes('htmx.org') || tag.includes('/js/daisy-multiselect.js') ? tag : '');
const origin = 'http://trunk-test.local';
const start = `<!doctype html><html>${html.match(/<head>[\s\S]*?<\/head>/)[0]}
  <body><button hx-get="/duct-sizes" hx-target="body" hx-swap="outerHTML"
    hx-push-url="true">Duct Sizes</button></body></html>`;

(async () => {
  const htmx = process.env.HTMX_SCRIPT_PATH
    ? fs.readFileSync(process.env.HTMX_SCRIPT_PATH, 'utf8')
    : await fetch(htmxURL).then(response => {
      assert(response.ok, 'Could not fetch the application HTMX script');
      return response.text();
    });
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 1600 } });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.route('**/*', route => {
      const url = new URL(route.request().url());
      if (url.href === htmxURL) {
        return route.fulfill({ contentType: 'application/javascript', body: htmx });
      }
      if (url.pathname === '/js/daisy-multiselect.js') {
        return route.fulfill({ contentType: 'application/javascript', body: component });
      }
      if (url.pathname === '/css/output.css') {
        return route.fulfill({ contentType: 'text/css',
          body: fs.readFileSync(path.join(root, 'Public/css/output.css'), 'utf8') });
      }
      if (url.pathname === '/start' || url.pathname === '/duct-sizes') {
        return route.fulfill({ contentType: 'text/html', body: url.pathname === '/start' ? start : html });
      }
      return route.fulfill({ status: 404, body: '' });
    });

    async function checkOptions() {
      await page.waitForFunction(() => document.querySelectorAll('.multiselect-trigger').length === 3);
      const counts = await page.locator('daisy-multiselect').evaluateAll(elements => elements.map(el => ({
        native: el.querySelector('select').options.length,
        rendered: el.querySelectorAll('.multiselect-option').length,
        stray: el.querySelectorAll(':scope > option').length,
        selected: el.getSelectedValues().length,
      })));
      assert.deepEqual(counts, [
        { native: 12, rendered: 12, stray: 0, selected: 12 },
        { native: 12, rendered: 12, stray: 0, selected: 12 },
        { native: 12, rendered: 12, stray: 0, selected: 0 },
      ]);
    }

    // Direct loading must wait until the parser has supplied each component's options.
    await page.goto(origin + '/duct-sizes');
    await checkOptions();
    const modal = page.locator('#trunkSizeForm');
    await modal.evaluate(dialog => dialog.showModal());
    await modal.locator('.multiselect-trigger').click();
    await modal.locator('.multiselect-select-all-btn').click();
    assert.equal(await modal.locator('select[multiple]').evaluate(select => select.selectedOptions.length), 12);
    await modal.locator('.multiselect-deselect-all-btn').click();
    await modal.locator('.multiselect-option').first().click();
    const selected = await modal.locator('form').evaluate(form => new FormData(form).getAll('rooms'));
    assert.deepEqual(selected, ['00000000-0000-0000-0000-000000000001_1']);
    await modal.evaluate(dialog => dialog.close());
    await modal.evaluate(dialog => dialog.showModal());
    assert.deepEqual(await modal.locator('daisy-multiselect').evaluate(el => el.getSelectedValues()), selected);

    // A second script load must preserve registration and the existing selection.
    await page.evaluate(() => { window.originalMultiSelect = customElements.get('daisy-multiselect'); });
    await page.addScriptTag({ url: origin + '/js/daisy-multiselect.js' });
    assert(await page.evaluate(() => customElements.get('daisy-multiselect') === window.originalMultiSelect));
    assert.equal(await page.locator('#daisy-multiselect-styles').count(), 1);
    assert.deepEqual(await modal.locator('form').evaluate(form => new FormData(form).getAll('rooms')), selected);

    // Enter from a page without selectors, swap again, then refresh the pushed URL.
    await page.goto(origin + '/start');
    await page.getByRole('button', { name: 'Duct Sizes', exact: true }).click();
    await checkOptions();
    await page.evaluate(() => htmx.ajax('GET', '/duct-sizes', { target: 'body', swap: 'outerHTML' }));
    await checkOptions();
    await page.reload();
    await checkOptions();
    assert.deepEqual(errors, []);
    console.log('PASS: full load, selection and form values, modal reopening, repeated script load, HTMX swaps, and refresh.');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exit(1); });
