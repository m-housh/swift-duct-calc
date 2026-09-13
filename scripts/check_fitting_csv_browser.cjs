// Requires an isolated app; creates its own account, project, and path.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');

const origin = process.env.FITTING_APP_URL;
assert(origin && ['localhost', '127.0.0.1'].includes(new URL(origin).hostname), 'Set FITTING_APP_URL to an isolated local app.');

(async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    const context = await browser.newContext();
    const password = randomUUID();
    const signup = await context.request.post(origin + '/signup', { form: {
      email: `fitting-csv-${randomUUID()}@example.test`, password, confirmPassword: password,
    } });
    const userID = (await signup.text()).match(/name="userID" value="([^"]+)"/)[1];
    await context.request.post(origin + '/signup/profile', { form: {
      userID, firstName: 'CSV', lastName: 'QA', companyName: 'QA',
      streetAddress: '1 Test Street', city: 'Test', state: 'OH', zipCode: '45040', theme: 'default',
    } });
    const project = await context.request.post(origin + '/projects', { form: {
      name: 'Fitting CSV QA', streetAddress: '1 Test Street', city: 'Test', state: 'OH', zipCode: '45040',
    } });
    const projectID = (await project.text()).match(/projects\/([A-Fa-f0-9-]{36})/)[1];
    const endpoint = `${origin}/projects/${projectID}/effective-lengths`;
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('dialog', dialog => dialog.accept());
    await page.goto(endpoint + '/editor');
    await page.locator('#path-name').fill('CSV supply');
    await page.locator('#path-straight').fill('10, 25');
    await page.locator('#quick-entry-open').click();
    await page.locator('#reference-form [name=code]').fill('1A');
    await page.locator('#reference-form [name=length]').fill('20');
    await page.locator('#reference-form [type=submit]').click();
    await page.locator('#reference-result [data-row]').click();
    await page.waitForFunction(() => document.querySelectorAll('#path-rows .path-row').length === 1);

    const csv = page.locator('#reference-import-csv');
    const result = page.locator('#reference-import-result');
    const previewButton = page.locator('#reference-import-form [type=submit]');
    async function preview(text) {
      await csv.fill(text);
      await previewButton.click();
      await page.waitForFunction(() => !document.querySelector('#reference-import-form [type=submit]').disabled);
    }
    const rowCount = () => page.locator('#path-rows .path-row').count();
    await page.locator('#reference-import-open').click();
    await preview('code,length_ft\n4AG,30.5\n5B,12\nunknown,10\n11-junction-box,25\n1A,nan');
    assert.match(await result.innerText(), /Line 3, code:.*different path type/);
    assert.match(await result.innerText(), /Line 4, code:.*Unrecognized/);
    assert.match(await result.innerText(), /Line 5, code:.*Group 11/);
    assert.match(await result.innerText(), /Line 6, length_ft:/);
    assert.equal(await result.locator('[data-import-rows]').count(), 0);
    assert.equal(await rowCount(), 1);
    await preview('code,length_ft\n"1A,35');
    assert.match(await result.innerText(), /Line 2, CSV: Unclosed/);

    await preview('code,length_ft,quantity\n8a-SMOOTH,12.25,\n1a,35,2\n8A,6,1');
    assert.deepEqual(await result.locator('tbody tr td:nth-child(2)').allTextContents(), ['8A', '1A', '8A']);
    assert.match(await result.innerText(), /Proposed path total including straight duct: 143.25 ft/);
    assert.match(await result.innerText(), /Group 1: check repeated use/);
    // Cancelling a valid preview must leave the existing draft unchanged.
    await page.keyboard.press('Escape');
    assert.equal(await rowCount(), 1);
    assert.equal(await page.locator('#path-total').innerText(), '55 ft');
    await page.locator('#reference-import-open').click();
    assert.equal(await result.innerText(), '');
    await previewButton.click();
    await result.locator('[data-import-rows]').waitFor();
    // Dispatch both clicks in the same task to exercise the submission guard.
    await result.locator('[data-import-rows]').evaluate(button => { button.click(); button.click(); });
    await page.waitForFunction(() => document.querySelectorAll('#path-rows .path-row').length === 4);
    assert.deepEqual(await page.locator('#path-rows .code').allTextContents(), ['1A', '1A', '8A', '8A']);
    assert.equal(await page.locator('#path-total').innerText(), '143.25 ft');

    await page.locator('#reference-import-open').click();
    await page.locator('#reference-import-file').setInputFiles({
      name: 'fittings.csv', mimeType: 'text/csv', buffer: Buffer.from('\ufeffcode,length_ft\r\n\r\n"4ag",30.5\r\n'),
    });
    await page.waitForFunction(() => document.querySelector('#reference-import-result').textContent.includes('File loaded'));
    assert.match(await csv.inputValue(), /"4ag",30.5/);
    await previewButton.click();
    await result.locator('[data-import-rows]').waitFor();
    assert.deepEqual(await result.locator('tbody tr td').allTextContents(), ['3', '4AG', '30.5', '1', '30.5']);
    // Editing the source invalidates the old Add button immediately.
    await csv.fill('code,length_ft\n4AG,31.75');
    assert.equal(await result.locator('[data-import-rows]').count(), 0);
    await previewButton.click();
    await result.locator('[data-import-rows]').click();
    await page.waitForFunction(() => document.querySelectorAll('#path-rows .path-row').length === 5);
    await page.locator('#save-path').click();
    await page.waitForURL(endpoint);
    await page.getByRole('region', { name: 'Equivalent lengths', exact: true })
      .getByRole('link', { name: 'Edit CSV supply', exact: true }).click();
    await page.locator('#fitting-path').waitFor({ state: 'visible' });
    const saved = JSON.parse(await page.locator('#fitting-path').getAttribute('data-baseline'));
    assert.deepEqual(saved.groups.map(row => [row.group + row.letter, row.value, row.quantity]), [
      ['1A', 20, 1], ['1A', 35, 2], ['4AG', 31.75, 1], ['8A', 12.25, 1], ['8A', 6, 1],
    ]);
    assert(saved.groups.every(row => row.fitting.origin === 'referenceEntry' && !row.fitting.calculation));
    assert.equal(await page.locator('#path-total').innerText(), '175 ft');

    await page.locator('#reference-import-open').click();
    const fileInput = page.locator('#reference-import-file');
    await fileInput.setInputFiles({ name: 'large.csv', mimeType: 'text/csv', buffer: Buffer.alloc(65537) });
    await page.waitForFunction(() => document.querySelector('#reference-import-result').textContent.includes('64 KiB'));
    await fileInput.setInputFiles({ name: 'invalid.csv', mimeType: 'text/csv', buffer: Buffer.from([0xff]) });
    await page.waitForFunction(() => document.querySelector('#reference-import-result').textContent.includes('UTF-8'));
    await preview('code,length_ft\n' + '1A,1\n'.repeat(496));
    assert.match(await result.innerText(), /combined path can contain at most 500/);
    assert.equal(await result.locator('[data-import-rows]').count(), 0);

    // A response arriving after cancellation must not restore a stale preview.
    let release, entered;
    const pending = new Promise(resolve => { release = resolve; });
    const requested = new Promise(resolve => { entered = resolve; });
    await page.route('**/fittings/import-references', async route => {
      entered(); await pending; await route.continue().catch(() => {});
    });
    await csv.fill('code,length_ft\n1A,1');
    await previewButton.click(); await requested;
    await page.keyboard.press('Escape');
    await page.locator('#reference-import-open').click();
    release();
    await page.unrouteAll({ behavior: 'wait' });
    assert.equal(await result.innerText(), '');
    assert.equal(await rowCount(), 5);
    // Fit the form and preview on a phone, with scrolling confined to the table.
    await page.setViewportSize({ width: 390, height: 844 });
    await preview('code,length_ft\n4AG,1');
    assert(await page.locator('#reference-import-dialog').evaluate(dialog => dialog.scrollWidth <= dialog.clientWidth));
    assert.equal(await page.getByRole('textbox', { name: 'Paste or edit CSV', exact: true }).count(), 1);
    await page.addScriptTag({ path: require.resolve('axe-core/axe.min.js') });
    const accessibility = await page.evaluate(() => axe.run('#reference-import-dialog'));
    assert.deepEqual(accessibility.violations.map(violation => ({ id: violation.id, nodes: violation.nodes.map(node => node.target) })), []);
    assert.deepEqual(errors, []);
    console.log('PASS: CSV paste/upload, errors, warnings, limits, cancellation, stale responses, duplicate apply, mobile, save/reopen.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
