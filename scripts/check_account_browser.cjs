const assert = require('node:assert/strict');
const fs = require('node:fs');
const { randomUUID } = require('node:crypto');
const { chromium } = require('playwright');
const origin = process.env.DUCTCALC_ACCOUNT_ORIGIN || `http://127.0.0.1:${fs.readFileSync('.dev-port', 'utf8').trim()}`;
assert(['localhost', '127.0.0.1'].includes(new URL(origin).hostname), 'Use an isolated local app');

(async () => {
  const browser = await chromium.launch();
  try {
    const context = await browser.newContext({ baseURL: origin, viewport: { width: 1280, height: 900 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    const signup = await context.request.post('/signup', { form: {
      email: `account-${randomUUID()}@example.test`, password: 'TestPassword123!', confirmPassword: 'TestPassword123!'
    } });
    assert.equal(signup.status(), 200);
    await page.goto('/profile');
    const form = page.locator('#profile-form');
    const nav = page.getByRole('navigation', { name: 'Account sections' });
    assert.equal(await form.getAttribute('hx-post'), '/profile');
    // A missing profile can be completed here, including native required-field validation.
    await form.getByRole('button', { name: 'Save changes' }).click();
    assert.equal(await form.evaluate(form => form.checkValidity()), false);
    const fields = { firstName: 'Alex', lastName: 'Morgan', companyName: 'Morgan Heating & Air',
      streetAddress: '123 Main Street', city: 'Monroe', state: 'OH', zipCode: '45050' };
    for (const [name, value] of Object.entries(fields)) await form.locator(`[name=${name}]`).fill(value);
    await form.locator('[name=theme]').selectOption('dark');
    await form.getByRole('button', { name: 'Save changes' }).click();
    await page.waitForFunction(() => document.querySelector('#profile-form')?.hasAttribute('hx-patch'));
    await page.reload();
    assert.equal(await form.locator('[name=companyName]').inputValue(), fields.companyName);
    assert.equal(await form.evaluate(form => form.closest('[data-theme]').dataset.theme), 'dark');
    await form.locator('[name=firstName]').fill('Unsaved');
    await form.getByRole('button', { name: 'Reset', exact: true }).click();
    assert.equal(await form.locator('[name=firstName]').inputValue(), 'Alex');

    // A rejected save must keep both the draft and account navigation available.
    await page.route('**/profile/*', route => route.fulfill({ status: 422,
      contentType: 'application/vnd.ductcalc.error+json',
      body: JSON.stringify({ title: 'Could not save profile', message: 'Please retry.', fields: [] })
    }));
    await form.locator('[name=firstName]').fill('Jamie');
    await form.getByRole('button', { name: 'Save changes' }).click();
    await form.getByRole('alert').filter({ hasText: 'Please retry.' }).waitFor();
    assert.equal(await form.locator('[name=firstName]').inputValue(), 'Jamie');
    assert.equal(await nav.locator('[aria-current=page]').textContent(), 'Profile');
    await page.unroute('**/profile/*');
    await form.locator('[name=theme]').selectOption('light');
    await form.getByRole('button', { name: 'Save changes' }).click();
    await page.waitForFunction(() => document.querySelector('#profile-form')?.closest('[data-theme]').dataset.theme === 'light');
    await page.reload();
    assert.equal(await form.locator('[name=firstName]').inputValue(), 'Jamie');

    for (const width of [1280, 390, 320]) {
      await page.setViewportSize({ width, height: 900 });
      for (const [name, path] of [['Profile', '/profile'], ['Path templates', '/path-templates'],
        ['Filter library', '/filters'], ['Design preferences', '/filters?tab=preferences']]) {
        await nav.getByRole('link', { name, exact: true }).click();
        await page.waitForURL(origin + path);
        assert.equal(await nav.locator('[aria-current=page]').textContent(), name);
        assert.equal(await page.locator('.app-navbar').count(), 1);
        assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `${name} overflows at ${width}px`);
        await page.addScriptTag({ path: require.resolve('axe-core/axe.min.js') });
        const violations = await page.evaluate(async () => (await axe.run('.account-workspace', {
          runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21aa'] }
        })).violations);
        assert.deepEqual(violations.map(v => ({ id: v.id, nodes: v.nodes.map(n => n.target) })), [], `${name} accessibility at ${width}px`);
      }
    }
    await page.goto('/profile');
    const themes = await form.locator('select[name=theme] option').evaluateAll(options =>
      options.map(option => option.value).filter(value => value !== 'default'));
    for (const theme of themes) {
      await form.evaluate((form, theme) => form.closest('[data-theme]').dataset.theme = theme, theme);
      await page.addScriptTag({ path: require.resolve('axe-core/axe.min.js') });
      const violations = await page.evaluate(async () => (await axe.run('.account-workspace', {
        runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21aa'] }
      })).violations);
      assert.deepEqual(violations.map(v => ({ id: v.id, nodes: v.nodes.map(n => n.target) })), [], `Profile accessibility in ${theme}`);
    }
    assert.deepEqual(errors, []);
    console.log('Account profile creation, saves, errors, reset, themes, navigation, mobile layout, and accessibility passed.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
