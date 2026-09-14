const assert = require('node:assert/strict');
const fs = require('node:fs');
const { randomUUID } = require('node:crypto');
const { chromium } = require('playwright');
const origin = process.env.DUCTCALC_ERROR_ORIGIN || `http://127.0.0.1:${fs.readFileSync('.dev-port', 'utf8').trim()}`;
assert(['localhost', '127.0.0.1'].includes(new URL(origin).hostname), 'Use an isolated local app');

(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  try {
    const context = await browser.newContext({ baseURL: origin, viewport: { width: 1280, height: 900 } });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('dialog', dialog => dialog.accept());
    const account = { email: `errors-${randomUUID()}@example.test`, password: 'TestPassword123!' };
    await page.goto('/signup');
    const signup = page.locator('#loginForm form');
    await signup.locator('[name=email]').fill(account.email);
    await signup.locator('[name=password]').fill(account.password);
    await signup.locator('[name=confirmPassword]').fill('DifferentPassword123!');
    await signup.getByRole('button', { name: 'Sign Up', exact: true }).click();
    await signup.getByRole('alert').filter({ hasText: 'passwords do not match' }).waitFor();
    assert.equal(await signup.locator('[name=password]').inputValue(), account.password);
    await signup.locator('[name=confirmPassword]').fill(account.password);
    await signup.getByRole('button', { name: 'Sign Up', exact: true }).click();
    await page.locator('#userProfileForm').waitFor();
    const created = await context.request.post('/projects', { form: { name: 'Error behavior', streetAddress: '1 Test St', city: 'Test', state: 'OH', zipCode: '45050' } });
    assert.equal(created.status(), 200);
    const projectID = (await created.text()).match(/data-project-id="([^"]+)"/)[1];
    const project = `/projects/${projectID}`;

    await context.clearCookies();
    await page.goto(`/login?next=${encodeURIComponent(`${project}/equipment`)}`);
    const login = page.locator('#loginForm form');
    await login.locator('[name=email]').fill(account.email);
    await login.locator('[name=password]').fill('incorrect');
    await login.getByRole('button', { name: 'Login', exact: true }).click();
    await login.getByRole('alert').filter({ hasText: 'email address or password is incorrect' }).waitFor();
    assert.equal(await login.locator('[name=email]').inputValue(), account.email);
    await login.locator('[name=password]').fill(account.password);
    await login.getByRole('button', { name: 'Login', exact: true }).click();
    await page.waitForURL(`**${project}/equipment`);
    await page.getByRole('button', { name: 'Edit equipment', exact: true }).click();
    const equipment = page.locator('#equipmentForm-all[open]');
    await equipment.locator('[name=heatingCFM]').fill('900');
    await equipment.locator('[name=coolingCFM]').fill('1200');
    await equipment.locator('[name=staticPressure]').fill('1');
    // Exercise server validation even though the browser normally rejects this number first.
    await equipment.locator('form').evaluate(form => { form.noValidate = true; });
    const invalidResponse = page.waitForResponse(response => response.url().endsWith('/equipment') && response.request().method() === 'POST');
    await equipment.getByRole('button', { name: 'Save equipment', exact: true }).click();
    assert.equal((await invalidResponse).status(), 422);
    await equipment.getByRole('alert').filter({ hasText: 'External static pressure' }).waitFor();
    assert.equal(await equipment.locator('[name=heatingCFM]').inputValue(), '900');
    assert.equal(await equipment.locator('[name=staticPressure]').getAttribute('aria-invalid'), 'true');
    assert(await equipment.getByRole('alert').evaluate(alert => alert === document.activeElement));
    assert(await page.locator('#project-sidebar').count());
    assert.equal(await page.locator('#app-status').textContent(), '');
    await equipment.locator('[name=staticPressure]').fill('0.5');
    await equipment.getByRole('button', { name: 'Save equipment', exact: true }).click();
    await page.locator('.heating .airflow-value').waitFor();
    await page.locator('#app-status').filter({ hasText: 'Equipment saved.' }).waitFor();

    await page.goto(`${project}/rooms`);
    await page.getByRole('button', { name: 'Import loads', exact: true }).click();
    const importer = page.getByRole('dialog', { name: 'Import room loads', exact: true });
    await importer.locator('input[type=file]').setInputFiles({ name: 'invalid.csv', mimeType: 'text/csv', buffer: Buffer.from([0xff]) });
    await importer.getByRole('button', { name: 'Import rooms', exact: true }).click();
    await importer.getByRole('alert').filter({ hasText: 'UTF-8' }).waitFor();
    assert.equal(await importer.locator('input[type=file]').evaluate(input => input.files[0].name), 'invalid.csv');
    assert(await page.locator('#project-sidebar').count());
    await page.screenshot({ path: '/tmp/ductcalc-errors-import.png' });
    await page.setViewportSize({ width: 390, height: 844 });
    assert(await importer.evaluate(dialog => dialog.scrollWidth <= dialog.clientWidth));
    await page.screenshot({ path: '/tmp/ductcalc-errors-import-mobile.png' });
    await page.setViewportSize({ width: 1280, height: 900 });
    await page.keyboard.press('Escape');

    await page.getByRole('button', { name: 'Add room', exact: true }).click();
    const room = page.getByRole('dialog', { name: 'Room', exact: true });
    for (const [name, value] of Object.entries({ name: 'Kitchen draft', heatingLoad: '12000', coolingTotal: '10000', registerCount: '2' })) {
      await room.locator(`[name="${name}"]`).fill(value);
    }
    await page.route(`**${project}/rooms`, route => route.fulfill({ status: 500, body: '<html>private SQL</html>' }));
    await room.getByRole('button', { name: 'Submit', exact: true }).click();
    await room.getByRole('alert').filter({ hasText: 'could not be completed' }).waitFor();
    assert.equal(await room.locator('[name=name]').inputValue(), 'Kitchen draft');
    assert(!(await room.textContent()).includes('private SQL'));
    await page.unroute(`**${project}/rooms`);

    // Expired sessions keep the same form and offer login in another tab.
    await context.clearCookies();
    await room.getByRole('button', { name: 'Submit', exact: true }).click();
    await room.getByRole('alert').filter({ hasText: 'session has ended' }).waitFor();
    assert.equal(await room.locator('[name=name]').inputValue(), 'Kitchen draft');
    assert.equal(await room.getByRole('link', { name: 'Sign in in another tab', exact: true }).getAttribute('target'), '_blank');
    await page.setViewportSize({ width: 390, height: 844 });
    assert(await room.evaluate(dialog => dialog.scrollWidth <= dialog.clientWidth));
    await page.setViewportSize({ width: 1280, height: 900 });
    await context.request.post('/login', { form: account });
    await room.getByRole('button', { name: 'Submit', exact: true }).click();
    await page.getByRole('button', { name: 'Edit Kitchen draft', exact: true }).waitFor();
    await page.locator('#app-status').filter({ hasText: 'Changes saved.' }).waitFor();

    // Fetch-based fitting errors use the same response contract and preserve their editor.
    await page.goto(`${project}/effective-lengths/editor`);
    const editor = page.locator('#fitting-path[open]');
    await editor.waitFor();
    await page.locator('#path-name').fill('Preserved fitting draft');
    await page.route('**/save-path', route => route.fulfill({ status: 409,
      contentType: 'application/vnd.ductcalc.error+json',
      body: JSON.stringify({ title: 'Could not save path', message: 'This path changed in another tab.', fields: [], actions: [], status: 409 }) }));
    await page.locator('#save-path').click();
    await page.locator('#path-status').filter({ hasText: 'changed in another tab' }).waitFor();
    assert.equal(await page.locator('#path-name').inputValue(), 'Preserved fitting draft');
    assert(await editor.evaluate(dialog => dialog.open && !dialog.inert));

    await page.unroute('**/save-path');
    await context.clearCookies();
    await page.locator('#save-path').click();
    const fittingLogin = page.locator('#path-status').getByRole('link', { name: 'Sign in in another tab', exact: true });
    await fittingLogin.waitFor();
    assert.equal(await fittingLogin.getAttribute('target'), '_blank');
    assert.equal(await page.locator('#path-name').inputValue(), 'Preserved fitting draft');
    await context.request.post('/login', { form: account });

    await page.goto('/path-templates');
    await page.getByRole('button', { name: 'Add path template', exact: true }).click();
    await page.getByRole('link', { name: 'New supply template', exact: true }).click();
    await page.locator('[data-config=name]').fill('Preserved template draft');
    await context.clearCookies();
    await page.locator('[data-action=save-template]').click();
    const templateLogin = page.locator('#workspace-status').getByRole('link', { name: 'Sign in in another tab', exact: true });
    await templateLogin.waitFor();
    assert.equal(await templateLogin.getAttribute('target'), '_blank');
    assert.equal(await page.locator('[data-config=name]').inputValue(), 'Preserved template draft');

    const missing = await page.goto('/missing-page');
    assert.equal(missing.status(), 404);
    await page.getByRole('link', { name: 'Back to projects', exact: true }).waitFor();
    assert(await page.getByRole('navigation', { name: 'Main', exact: true }).isVisible());
    assert.deepEqual(errors, []);
    console.log('PASS: signup/login retry and return URL, server validation, retained drafts/files, retry, expired session, fitting conflict, and navigable 404.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
