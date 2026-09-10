#!/usr/bin/env node
// Exercises the shipped UI with disposable data in an isolated local app.
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { chromium } = require('playwright');
const origin = process.env.DUCTCALC_A11Y_ORIGIN || 'http://127.0.0.1:58681';
assert(['localhost', '127.0.0.1'].includes(new URL(origin).hostname), 'Use an isolated local app');
const themes = ['light', 'dark', 'aqua', 'cupcake', 'cyberpunk', 'dracula', 'night', 'nord', 'retro', 'synthwave'];

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.DUCTCALC_BROWSER_EXECUTABLE });
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 }, colorScheme: 'light' });
  page.setDefaultTimeout(15000);
  const failures = [];
  async function audit(label, allThemes = false) {
    await page.addScriptTag({ path: require.resolve('axe-core/axe.min.js') });
    for (const theme of allThemes ? themes : [null]) {
      if (theme) await page.locator('[data-theme]').first().evaluate((node, theme) => { node.dataset.theme = theme; }, theme);
      const violations = await page.evaluate(async () => {
        const result = await axe.run(document, {
          runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'] },
        });
        return result.violations.map(rule => ({
          rule: rule.id,
          nodes: rule.nodes.map(node => ({ target: node.target, message: node.failureSummary })),
        }));
      });
      if (violations.length) {
        failures.push({ label, theme, violations });
        console.error(JSON.stringify({ label, theme, violations }));
      }
    }
    console.log(`Checked ${label}${allThemes ? ' in all themes' : ''}`);
  }
  async function focused(locator) { assert(await locator.evaluate(node => node === document.activeElement), 'Expected keyboard focus'); }
  async function fill(fields, container = page) {
    for (const [name, value] of Object.entries(fields)) await container.locator(`[name="${name}"]:visible`).fill(String(value));
  }
  async function post(path, form, method = 'POST') {
    const response = await page.request.fetch(origin + path, { method, form });
    assert(response.ok(), `${path}: ${response.status()}`);
    const text = await response.text();
    assert(!text.includes('data-error-message'), `${path}: ${text}`);
    return text;
  }
  try {
    for (const path of ['/', '/login', '/signup', '/ductulator', '/fittings']) {
      await page.goto(origin + path);
      await audit(path, path === '/' || path === '/signup' || path === '/fittings');
    }
    await page.goto(origin + '/ductulator');
    await fill({ cfm: 1000 });
    await page.getByRole('button', { name: 'Submit', exact: true }).click();
    await page.locator('#app-status').filter({ hasText: 'Final round size' }).waitFor();
    await audit('Ductulator result', true);
    await focused(page.getByRole('button', { name: 'Submit', exact: true }));
    await page.setViewportSize({ width: 320, height: 800 });
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'Ductulator must reflow at 320px');
    await page.setViewportSize({ width: 1280, height: 900 });

    await page.goto(origin + '/signup');
    await fill({ email: `accessibility-${randomUUID()}@example.com`, password: 'Accessible-123', confirmPassword: 'Accessible-123' });
    await page.getByRole('button', { name: 'Sign Up', exact: true }).click();
    await page.locator('#userProfileForm').waitFor();
    await fill({ firstName: 'Accessibility', lastName: 'Test', companyName: 'Local test', streetAddress: '123 Test St', city: 'Test', state: 'OH', zipCode: '45040' });
    await page.locator('select[name=theme]').selectOption('light');
    await page.locator('#userProfileForm button[type=submit]').click();
    await page.getByRole('heading', { name: 'Projects', exact: true }).waitFor();
    await audit('Projects');
    await page.goto(origin + '/profile');
    await audit('Account', true);
    await page.goto(origin + '/projects');

    const account = page.locator('.account-menu > summary');
    await account.focus();
    await page.keyboard.press('Enter');
    for (const name of ['Profile', 'Projects', 'Logout']) {
      await page.keyboard.press('Tab');
      assert.equal(await page.evaluate(() => document.activeElement.textContent.trim()), name);
    }
    await page.keyboard.press('Escape');
    await focused(account);

    const addProject = page.getByRole('button', { name: 'Add project', exact: true });
    await addProject.click();
    let dialog = page.getByRole('dialog', { name: 'Project', exact: true });
    await dialog.waitFor();
    await audit('Project dialog', true);
    for (let tab = 0; tab < 12; tab++) {
      await page.keyboard.press('Tab');
      assert(await dialog.evaluate(node => node.contains(document.activeElement) || !document.hasFocus()), 'Tab must not reach background page controls');
    }
    await page.keyboard.press('Escape');
    await focused(addProject);
    await addProject.click();
    await fill({ name: 'Accessibility test', streetAddress: '123 Test St', city: 'Test', state: 'OH', zipCode: '45040' }, dialog);
    await dialog.getByRole('button', { name: 'Submit', exact: true }).click();
    await page.getByRole('heading', { name: 'Room Loads', exact: true }).waitFor();
    const projectPath = await page.getByRole('navigation', { name: 'Project', exact: true }).getByRole('link', { name: 'Project', exact: true }).getAttribute('href');
    const projectID = projectPath.split('/').at(-1);
    const sidebar = page.locator('.project-navigation > summary');
    await sidebar.focus();
    await page.keyboard.press('Enter');
    assert.equal(await page.getByRole('navigation', { name: 'Project', exact: true }).isVisible(), false);
    await page.keyboard.press('Enter');
    assert.equal(await page.getByRole('navigation', { name: 'Project', exact: true }).isVisible(), true);

    await page.getByRole('button', { name: 'Add room', exact: true }).click();
    dialog = page.getByRole('dialog', { name: 'Room', exact: true });
    await audit('Room dialog', true);
    await fill({ name: 'Kitchen', heatingLoad: 12000, coolingTotal: 10000, registerCount: 2 }, dialog);
    await page.route(origin + projectPath + '/rooms', route => route.fulfill({ status: 500, body: 'Test failure' }));
    await dialog.getByRole('button', { name: 'Submit', exact: true }).click();
    await dialog.getByRole('alert').filter({ hasText: 'could not be completed' }).waitFor();
    assert.equal(await dialog.locator('[name=name]').inputValue(), 'Kitchen');
    await page.unroute(origin + projectPath + '/rooms');
    await fill({ name: 'Kitchen', heatingLoad: 12000, coolingTotal: 10000, registerCount: 2 }, dialog);
    await dialog.getByRole('button', { name: 'Submit', exact: true }).click();
    await page.getByRole('button', { name: 'Edit Kitchen', exact: true }).waitFor();
    await page.locator('#app-status').filter({ hasText: 'Changes saved.' }).waitFor();
    await focused(page.getByRole('button', { name: 'Add room', exact: true }));
    await audit('Room loads', true);
    await post(`${projectPath}/rooms/update-shr`, { projectID, sensibleHeatRatio: '0.83' }, 'PATCH');
    await post(`${projectPath}/equipment`, { projectID, staticPressure: '0.5', heatingCFM: '1000', coolingCFM: '1200' });
    await post(`${projectPath}/component-loss`, { projectID, name: 'Filter', value: '0.1' });
    for (const type of ['supply', 'return']) {
      await post(`${projectPath}/effective-lengths/stepThree`, { name: `${type} path`, type, straightLengths: '100' });
    }
    for (const path of ['', '/rooms', '/equipment', '/effective-lengths', '/friction-rate', '/duct-sizing']) {
      await page.goto(origin + projectPath + path);
      await audit(`Project ${path || 'details'}`, true);
      await page.setViewportSize({ width: 320, height: 800 });
      const overflow = await page.evaluate(() => ({
        width: innerWidth, scrollWidth: document.documentElement.scrollWidth,
        elements: [...document.querySelectorAll('main *')].filter(node => node.checkVisibility({ checkVisibilityCSS: true }) && node.getBoundingClientRect().right > innerWidth && !node.closest('.table-scroll')).map(node => node.outerHTML.slice(0,160)).slice(0,8),
      }));
      if (overflow.scrollWidth > overflow.width) {
        failures.push({ path, overflow });
        console.error(JSON.stringify({ path, overflow }));
      }
      await page.setViewportSize({ width: 1280, height: 900 });
    }
    const editors = page.getByRole('button', { name: /Edit rectangular size for Kitchen/ });
    assert.equal(await editors.count(), 2);
    const ids = await editors.evaluateAll(nodes => nodes.map(node => node.dataset.openDialog));
    assert.equal(new Set(ids).size, 2, 'Each register needs a separate dialog');
    await editors.nth(1).click();
    dialog = page.getByRole('dialog', { name: 'Rectangular Size', exact: true });
    await fill({ height: 8 }, dialog);
    await dialog.getByRole('button', { name: 'Submit', exact: true }).click();
    await page.locator('#app-status').filter({ hasText: 'Changes saved.' }).waitFor();
    await focused(editors.nth(1));

    await page.getByRole('button', { name: 'Add trunk or runout', exact: true }).click();
    dialog = page.getByRole('dialog', { name: 'Trunk / Runout Size', exact: true });
    await audit('Trunk checkbox group', true);
    const options = dialog.locator('input[name=rooms]');
    assert.equal(await options.count(), 2);
    await options.first().focus();
    await page.keyboard.press('Space');
    assert(await options.first().isChecked());
    await dialog.getByRole('button', { name: 'Select all', exact: true }).click();
    assert.equal(await dialog.locator('input[name=rooms]:checked').count(), 2);
    await dialog.getByRole('button', { name: 'Clear selection', exact: true }).click();
    assert.equal(await dialog.locator('input[name=rooms]:checked').count(), 0);
    await options.first().check();
    await fill({ name: 'Kitchen trunk' }, dialog);
    await dialog.getByRole('button', { name: 'Submit', exact: true }).click();
    await page.getByRole('button', { name: 'Edit Kitchen trunk', exact: true }).click();
    assert.equal(await page.getByRole('dialog').locator('input[name=rooms]:checked').count(), 1, 'Checkbox values must persist');
    await page.keyboard.press('Escape');
    await focused(page.getByRole('button', { name: 'Edit Kitchen trunk', exact: true }));
    await page.locator('.skip-link').focus();
    await page.keyboard.press('Enter');
    await focused(page.getByRole('heading', { name: 'Duct Sizes', exact: true }));
    await page.goto(origin + projectPath + '/rooms');
    page.once('dialog', confirmation => confirmation.accept());
    await page.getByRole('button', { name: 'Delete Kitchen', exact: true }).click();
    await page.locator('#app-status').filter({ hasText: 'Item deleted.' }).waitFor();
    await focused(page.getByRole('heading', { name: 'Room Loads', exact: true }));
    assert.deepEqual(failures, [], JSON.stringify(failures, null, 2));
    console.log('Accessibility and keyboard checks passed.');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
