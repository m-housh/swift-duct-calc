// Run after check_fitting_path.cjs and check_template_modal.cjs against the same test app.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  try {
    const context = await browser.newContext({ storageState: '/tmp/fitting-review-auth.json' });
    let obsoleteRequests = 0;
    // Simulate obsolete cached scripts still being available at their original URLs.
    await context.route(/\/js\/(fitting-path|path-templates|template-modal)\.js$/, route => {
      obsoleteRequests++;
      return route.fulfill({ contentType: 'application/javascript', body: 'throw Error("Obsolete template asset loaded");' });
    });
    const editorURL = new URL(fs.readFileSync('/tmp/fitting-review-path.txt', 'utf8').trim());
    editorURL.search = '';
    for (const [name, lengths, expected] of [
      ['Bar', '', []], ['', '10, 15', [10, 15]], ['Bar', '10, 15', [10, 15]],
    ]) {
      const page = await context.newPage(), prompts = [], errors = [];
      page.on('dialog', async dialog => { prompts.push(dialog.type()); await dialog.dismiss(); });
      page.on('pageerror', error => errors.push(error.message));
      await page.goto(editorURL.href);
      await page.locator('#path-name').fill(name);
      await page.locator('#path-straight').fill(lengths);
      const action = page.getByRole('button', { name: 'From template', exact: true });
      assert.equal(await action.getAttribute('type'), 'button');
      assert.equal(await action.getAttribute('href'), null);
      await action.click();
      const modal = page.locator('#fitting-path');
      await modal.getByRole('heading', { name: 'Choose a path template', exact: true }).waitFor();
      assert.equal(page.url(), editorURL.href);
      await modal.getByRole('link', { name: 'Use template', exact: true }).first().click();
      await modal.locator('#path-template-data').waitFor({ state: 'attached' });
      assert.deepEqual(JSON.parse(await modal.locator('#path-template-data').textContent()).initialValues, { name, straightLengths: expected });
      assert(await modal.evaluate(dialog => dialog.matches(':modal')));
      assert.equal(page.url(), editorURL.href);
      await modal.getByRole('button', { name: 'Back to path', exact: true }).click();
      assert.equal(await page.locator('#path-name').inputValue(), name);
      assert.equal(await page.locator('#path-straight').inputValue(), lengths);
      assert.deepEqual(prompts, []);
      assert.deepEqual(errors, []);
      await page.close();
    }
    assert.equal(obsoleteRequests, 0, 'All template assets must bypass the old script URLs');
    console.log('PASS: name only, lengths only, and both carry into the same modal without prompts, including with obsolete scripts cached at the original URLs.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
