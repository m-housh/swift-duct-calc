// Run against an isolated local app. Creates its own account, project, and path.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const origin = process.env.DUCT_PATH_QA_ORIGIN || 'http://127.0.0.1:49843';
assert(['localhost', '127.0.0.1'].includes(new URL(origin).hostname));

(async () => {
  const browser = await chromium.launch();
  try {
    const context = await browser.newContext();
    const password = randomUUID();
    const signup = await context.request.post(origin + '/signup', { form: {
      email: `path-order-${randomUUID()}@example.test`, password, confirmPassword: password,
    } });
    const userID = (await signup.text()).match(/name="userID" value="([^"]+)"/)[1];
    await context.request.post(origin + '/signup/profile', { form: {
      userID, firstName: 'Path', lastName: 'QA', companyName: 'QA',
      streetAddress: '1 Test Street', city: 'Test', state: 'OH', zipCode: '45040', theme: 'dracula',
    } });
    const project = await context.request.post(origin + '/projects', { form: {
      name: 'Fitting order QA', streetAddress: '1 Test Street', city: 'Test', state: 'OH', zipCode: '45040',
    } });
    const projectID = (await project.text()).match(/projects\/([A-Fa-f0-9-]{36})/)[1];
    const endpoint = `${origin}/projects/${projectID}/effective-lengths`;
    // Deliberately save old insertion order, including two entries in the same group.
    const entries = ['8O', '1D', '12A', '2A', '8A'].map((code, index) => ({
      id: randomUUID(), quantity: 1, savedIndex: null,
      row: { name: 'Reference entry', sourceCode: code, groupID: parseInt(code),
        origin: 'referenceEntry', feet: index + 10, fields: {}, details: [] },
    }));
    const created = await context.request.post(endpoint + '/save-path', { form: {
      payload: JSON.stringify({ baseline: null, name: 'Unsorted saved path', pathType: 'supply', straightLengths: [25], entries }),
    } });
    const result = await created.text();
    assert.match(result, /data-saved-path=/);
    const editURL = endpoint + '/editor?id=' + result.match(/data-saved-path="([^"]+)"/)[1];
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('dialog', dialog => dialog.accept());
    await page.goto(editURL);
    const baseline = () => page.locator('#fitting-path').getAttribute('data-baseline').then(JSON.parse);
    const before = await baseline();
    const row = code => page.locator('#path-rows .path-row').filter({ has: page.locator('.code', { hasText: new RegExp(`^${code}$`) }) });
    async function expectOrder(codes) {
      await page.waitForFunction(expected => {
        const rows = [...document.querySelectorAll('#path-rows .code')].map(node => node.textContent);
        const numbers = [...document.querySelectorAll('#path-rows .row-number')].map(node => node.textContent);
        return JSON.stringify(rows) === JSON.stringify(expected)
          && JSON.stringify(numbers) === JSON.stringify(expected.map((_, index) => String(index + 1)));
      }, codes);
      assert.deepEqual(await page.locator('#path-rows .row-number').allTextContents(), codes.map((_, index) => String(index + 1)));
    }
    await expectOrder(['1D', '2A', '8O', '8A', '12A']);
    // Removing the first visible row must remove its original saved index, not index zero.
    await row('1D').locator('[data-remove-row]').click();
    await expectOrder(['2A', '8O', '8A', '12A']);
    async function reference(code, feet) {
      await page.locator('#reference-form [name=code]').fill(code);
      await page.locator('#reference-form [name=length]').fill(String(feet));
      await page.locator('#reference-form button[type=submit]').click();
      await page.locator('#reference-result [data-row]').click();
    }
    await page.locator('#quick-entry-open').click();
    await reference('1D', 30);
    await expectOrder(['1D', '2A', '8O', '8A', '12A']);
    // Editing a reference into an earlier group must move it without changing its identity.
    const editedID = await row('12A').getAttribute('data-row-id');
    await row('12A').locator('[data-edit-row]').click();
    await reference('4AG', 22);
    await expectOrder(['1D', '2A', '4AG', '8O', '8A']);
    assert.equal(await row('4AG').getAttribute('data-row-id'), editedID);
    await row('8A').locator('[data-quantity]').fill('3');
    await row('8A').locator('[data-quantity]').press('Tab');
    await page.locator('#save-path').click();
    await page.waitForURL(endpoint);
    await page.goto(editURL);
    await expectOrder(['1D', '2A', '4AG', '8O', '8A']);
    const after = await baseline();
    assert.deepEqual(after.groups.map(group => group.group), [1, 2, 4, 8, 8]);
    assert.equal(after.groups[0].value, 30);
    assert.deepEqual(after.groups[1], before.groups[3]);
    assert.equal(after.groups[2].fitting.id, before.groups[2].fitting.id);
    assert.equal(after.groups[2].value, 22);
    assert.deepEqual(after.groups[3], before.groups[0]);
    assert.deepEqual(after.groups[4], { ...before.groups[4], quantity: 3 });
    await page.goto(endpoint);
    const pathCount = await page.locator('.path-table tbody tr').count();
    await page.locator('.path-table').getByRole('link', { name: 'Duplicate Unsorted saved path', exact: true }).click();
    assert.equal(await page.locator('#path-name').inputValue(), '');
    assert.equal(await page.locator('#path-name').evaluate(node => node === document.activeElement), true);
    assert.equal(await page.locator('#path-type').inputValue(), 'supply');
    assert.equal(await page.locator('#path-straight').inputValue(), '25');
    await expectOrder(['1D', '2A', '4AG', '8O', '8A']);
    await page.locator('#save-path').click();
    assert.equal(await page.locator('#path-name').evaluate(node => node.validity.valueMissing), true);
    await page.locator('#close-path').click();
    await page.waitForURL(endpoint);
    assert.equal(await page.locator('.path-table tbody tr').count(), pathCount);
    await page.locator('.path-table').getByRole('link', { name: 'Duplicate Unsorted saved path', exact: true }).click();
    await page.locator('#path-name').fill('Copied supply');
    await row('1D').locator('[data-remove-row]').click();
    await expectOrder(['2A', '4AG', '8O', '8A']);
    await row('8A').locator('[data-quantity]').fill('2');
    await row('8A').locator('[data-quantity]').press('Tab');
    await page.locator('#save-path').click();
    await page.waitForURL(endpoint);
    assert.equal(await page.locator('.path-table tbody tr').count(), pathCount + 1);
    await page.locator('.path-table').getByRole('link', { name: 'Edit Copied supply', exact: true }).click();
    const copy = await baseline();
    assert.notEqual(copy.id, after.id);
    assert.deepEqual(copy.groups, [...after.groups.slice(1, 4), { ...after.groups[4], quantity: 2 }]);
    await page.goto(editURL);
    assert.deepEqual(await baseline(), after);
    assert.deepEqual(errors, []);
    console.log('PASS: group sorting, fitting edits, save/reopen, duplicate draft focus and validation, cancel without creating, independent copy.');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
