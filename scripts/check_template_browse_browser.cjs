// Run against an isolated local application. Creates a disposable account and project.
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { chromium } = require('playwright');
const base = process.env.DUCT_TEMPLATE_QA_ORIGIN || 'http://127.0.0.1:18093';
assert(['127.0.0.1', 'localhost'].includes(new URL(base).hostname));

(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  try {
    const context = await browser.newContext({ viewport: { width: 1440, height: 1000 } });
    const password = randomUUID();
    const signup = await context.request.post(base + '/signup', { form: {
      email: `browse-${randomUUID()}@example.test`, password, confirmPassword: password,
    } });
    const userID = (await signup.text()).match(/name="userID" value="([^"]+)"/)[1];
    await context.request.post(base + '/signup/profile', { form: {
      userID, firstName: 'Browse', lastName: 'Review', companyName: 'QA',
      streetAddress: '1 Test Street', city: 'Cincinnati', state: 'OH', zipCode: '45202', theme: 'dark',
    } });
    const project = await context.request.post(base + '/projects', { form: {
      name: 'Browse fittings review', streetAddress: '1 Test Street', city: 'Cincinnati', state: 'OH', zipCode: '45202',
    } });
    const projectID = (await project.text()).match(/projects\/([0-9A-Fa-f-]{36})/)[1];
    const page = await context.newPage(), errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('dialog', dialog => dialog.accept());
    for (const type of ['supply', 'return']) {
      await page.goto(`${base}/projects/${projectID}/effective-lengths/editor`);
      await page.locator('#path-from-template').click();
      await page.locator(`[data-template-type="${type}"]`).getByRole('link', { name: 'Use template', exact: true }).click();
      const choose = id => page.locator(`[data-action="choose"][data-id="${id}"]`).click();
      const extra = id => page.locator(`[data-action="extra"][data-id="${id}"]`).click();
      await choose(type === 'supply' ? '1B' : '5A-round');
      const heading = type === 'supply' ? 'Supply trunk branch takeoff' : 'Return branch / boot';
      await page.getByRole('heading', { name: heading, exact: true }).waitFor();
      await page.locator('[data-action="browse"]').click();
      const dialog = page.locator('#browse-fittings'), select = page.getByLabel('Fitting group', { exact: true });
      assert.equal(await select.inputValue(), type === 'supply' ? '2' : '6');
      for (const width of [1440, 390]) {
        await page.setViewportSize({ width, height: 1000 });
        await select.scrollIntoViewIfNeeded();
        const bounds = await select.boundingBox();
        const firstCard = await dialog.locator('article').first().boundingBox();
        assert(firstCard.y >= bounds.y + bounds.height + 8, 'Fitting cards must clear the group selector');
        assert(await dialog.evaluate(node => node.scrollWidth <= node.clientWidth), 'Browse must fit the viewport');
        assert.equal(await select.evaluate(node => getComputedStyle(node).appearance), 'auto');
        assert.equal(await select.evaluate(node => getComputedStyle(node).backgroundImage), 'none');
        await page.screenshot({ path: `/tmp/issue41-${type}-${width}.png`, animations: 'disabled' });
      }
      // Escape must remove the nested dialog, so reopening uses the current group.
      await page.keyboard.press('Escape');
      assert.equal(await dialog.count(), 0);
      assert(await page.locator('#fitting-path').evaluate(node => node.matches(':modal')));
      await page.locator('[data-action="browse"]').click();
      await select.selectOption('8');
      await dialog.locator('[data-id="8A-2-piece-45"]').waitFor();
      await select.selectOption(type === 'supply' ? '2' : '6');
      const id = type === 'supply' ? '2C' : '6G';
      await extra(id);
      const fields = page.locator('#fitting-details [data-field]');
      for (let i = 0; i < await fields.count(); i++) {
        const field = fields.nth(i);
        if (await field.evaluate(node => node.tagName === 'SELECT')) {
          const value = await field.locator('option').nth(1).getAttribute('value');
          await field.selectOption(value);
        } else await field.fill('10');
      }
      if (await page.locator('#fitting-details').count())
        await page.getByRole('button', { name: 'Apply', exact: true }).click();
      await page.getByRole('heading', { name: type === 'supply' ? 'Boot' : 'Elbows', exact: true }).waitFor();
      await page.locator('[data-action="back"]').click();
      await page.locator(`[data-action="choose"][data-id="${id}"]`).waitFor();
      assert.equal(await page.locator('#step-fitting-rows [data-action="edit-row"]').count(), 1);
      await choose(id);
      await page.getByRole('heading', { name: type === 'supply' ? 'Boot' : 'Elbows', exact: true }).waitFor();
    }
    assert.deepEqual(errors, []);
    console.log('PASS: supply/return browse, current group, visible selector, desktop/mobile spacing, switching groups, nested Escape/reopen, retained fitting inputs, and auto-advance.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
