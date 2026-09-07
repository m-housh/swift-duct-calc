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
    const url = fs.readFileSync('/tmp/fitting-review-path.txt', 'utf8').trim();
    const endpoint = new URL(url).pathname.split('/editor')[0];
    await page.goto(url);
    const editor = page.locator('#fitting-path');
    await editor.waitFor({ state: 'visible' });
    const size = await editor.boundingBox();
    assert(Math.abs(size.width / 1440 - .88) < .01);
    assert(Math.abs(size.height / 1000 - .88) < .01);
    assert(await editor.evaluate(dialog => dialog.matches(':modal')));
    assert(await page.getByRole('heading', { name: 'Equivalent Lengths', exact: true, includeHidden: true }).count());
    const original = await page.locator('#path-name').inputValue();
    await page.screenshot({ path: '/tmp/fitting-modal-desktop.png' });
    // The child picker closes independently and returns focus to Add fitting.
    await page.locator('[data-open-picker]').click();
    await page.keyboard.press('Escape');
    assert.equal(await page.locator('#picker-dialog').evaluate(dialog => dialog.open), false);
    assert(await editor.evaluate(dialog => dialog.matches(':modal')));
    assert(await page.locator('[data-open-picker]').evaluate(button => button === document.activeElement));
    await page.locator('#path-rows [data-edit-row]').first().click();
    await page.locator('#edit-fitting [data-row]').waitFor();
    await page.keyboard.press('Escape');
    assert.equal(await page.locator('#edit-dialog').evaluate(dialog => dialog.open), false);
    assert(await editor.evaluate(dialog => dialog.open));
    // Declining discard leaves the draft intact; accepting Escape returns to the list.
    await page.locator('#path-name').fill('Unsaved modal edit');
    page.once('dialog', async dialog => { assert.equal(dialog.type(), 'confirm'); await dialog.dismiss(); });
    await page.locator('#close-path').click();
    assert(await editor.evaluate(dialog => dialog.open));
    assert.equal(await page.locator('#path-name').inputValue(), 'Unsaved modal edit');
    page.once('dialog', async dialog => { assert.equal(dialog.type(), 'confirm'); await dialog.accept(); });
    await page.keyboard.press('Escape');
    await page.waitForURL(value => value.pathname === endpoint && !value.search);
    await page.goto(url); assert.equal(await page.locator('#path-name').inputValue(), original);
    // Failed saves preserve the open editor and draft.
    await page.route('**/save-path', route => route.fulfill({ status: 500, body: 'Test failure' }));
    await page.locator('#path-name').fill('Retained after failure');
    await page.locator('#save-path').click();
    await page.locator('#path-status').filter({ hasText: 'Request failed' }).waitFor();
    assert(await editor.evaluate(dialog => dialog.open && !dialog.inert));
    assert.equal(await page.locator('#path-name').inputValue(), 'Retained after failure');
    await page.unroute('**/save-path');
    await page.locator('#path-name').fill(original);
    await page.setViewportSize({ width: 390, height: 844 });
    await editor.evaluate(dialog => { dialog.scrollTop = 0; });
    assert(await editor.evaluate(dialog => dialog.scrollWidth <= dialog.clientWidth));
    await page.screenshot({ path: '/tmp/fitting-modal-mobile.png' });
    page.once('dialog', dialog => dialog.accept()); await page.locator('#close-path').click();
    await page.waitForURL(value => value.pathname === endpoint);
    // A clean cancel does not ask for confirmation or save anything.
    await page.goto(url); let prompts = 0;
    page.on('dialog', dialog => { prompts++; dialog.dismiss(); });
    await page.locator('#close-path').click(); await page.waitForURL(value => value.pathname === endpoint);
    assert.equal(prompts, 0); assert.deepEqual(errors, []);
    console.log('PASS: 88% desktop modal, mobile overflow, nested dialogs and focus, cancel/Escape discard, failed-save retention, and clean cancel.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
