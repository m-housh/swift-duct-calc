// Exercises the actual template modal against an isolated local app.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { randomUUID } = require('node:crypto');
const { chromium } = require('playwright');
const origin = process.env.DUCT_TEMPLATE_QA_ORIGIN || `http://127.0.0.1:${fs.readFileSync('.dev-port', 'utf8').trim()}`;
assert(['127.0.0.1', 'localhost'].includes(new URL(origin).hostname));

(async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    const context = await browser.newContext({ baseURL: origin, viewport: { width: 1466, height: 1100 } });
    const password = randomUUID();
    const signup = await context.request.post('/signup', { form: {
      email: `review-${randomUUID()}@example.test`, password, confirmPassword: password,
    } });
    const userID = (await signup.text()).match(/name="userID" value="([^"]+)"/)[1];
    await context.request.post('/signup/profile', { form: {
      userID, firstName: 'Path', lastName: 'Review', companyName: 'QA', theme: 'dark',
      streetAddress: '1 Test Street', city: 'Cincinnati', state: 'OH', zipCode: '45202',
    } });
    const project = await context.request.post('/projects', { form: {
      name: 'Path template review', streetAddress: '1 Test Street', city: 'Cincinnati', state: 'OH', zipCode: '45202',
    } });
    const projectID = (await project.text()).match(/projects\/([0-9A-Fa-f-]{36})/)[1];
    const page = await context.newPage(), errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('dialog', dialog => dialog.accept());
    await page.goto(`/projects/${projectID}/effective-lengths/editor`);
    await page.locator('#path-from-template').click();
    const templateLink = page.locator('[data-template-type="supply"]').getByRole('link', { name: 'Use template', exact: true });
    const startURL = await templateLink.getAttribute('href');
    await templateLink.click();
    const root = page.locator('#path-template-workspace');
    const heading = name => root.getByRole('heading', { name, exact: true }).waitFor();
    const choose = id => root.locator(`[data-action="choose"][data-id="${id}"]`).click();
    const idle = () => page.waitForFunction(() => document.getElementById('path-template-workspace')?.getAttribute('aria-busy') !== 'true');
    const cards = root.locator('#path-step-form [data-fitting-choice]');
    const focused = async index => assert(await cards.nth(index).evaluate(node => node === document.activeElement));

    // Exercise the actual arrival focus, without tabbing or focusing a test-selected element.
    assert(await root.locator('h1').evaluate(node => node === document.activeElement));
    await page.keyboard.press('ArrowRight');
    await focused(0);
    await page.goto(`/projects/${projectID}/effective-lengths/editor`);
    await page.locator('#path-from-template').click();
    await templateLink.click();
    assert(await root.locator('h1').evaluate(node => node === document.activeElement));
    await page.keyboard.press('Control+Alt+l');
    await focused(0);

    // Enter from the heading follows validation, and holding it cannot skip sections.
    await root.locator('#section-heading').focus();
    await page.keyboard.press('Enter');
    await idle();
    assert.match(await root.locator('#workspace-status').innerText(), /Complete/);
    await heading('Equipment connection');
    for (const [width, columns] of [[1466, 3], [1024, 2], [390, 1]]) {
      await page.setViewportSize({ width, height: 1100 });
      await root.locator('#section-heading').focus();
      await page.keyboard.press('ArrowDown');
      await focused(0);
      await page.keyboard.press('ArrowUp');
      await focused(0);
      await page.keyboard.press('ArrowRight');
      await focused(1);
      await page.keyboard.press('ArrowLeft');
      await focused(0);
      await page.keyboard.press('ArrowDown');
      await focused(columns);
      await page.keyboard.press('ArrowUp');
      await focused(0);
      assert.equal(await cards.first().evaluate(node => getComputedStyle(node.closest('article')).outlineStyle), 'solid');
      await root.locator('#section-heading').focus();
      await page.keyboard.press('Control+Alt+j');
      await focused(0);
      await page.keyboard.press('Control+Alt+l');
      await focused(1);
      await page.keyboard.press('Control+Alt+h');
      await focused(0);
      await page.keyboard.press('Control+Alt+j');
      await focused(columns);
      await page.keyboard.press('Control+Alt+k');
      await focused(0);
      await page.keyboard.press('j');
      await page.keyboard.press('l');
      await focused(0);
      await page.screenshot({ path: `/tmp/ductcalc-fitting-keyboard-${width}.png`, fullPage: true, animations: 'disabled' });
      // Arrow keys move focus without adding a fitting or advancing the section.
      assert.equal(await root.locator('#step-fitting-rows [data-action="edit-row"]').count(), 0);
      await cards.last().focus();
      await page.keyboard.press('ArrowRight');
      await focused(await cards.count() - 1);
      await cards.first().focus();
      await page.keyboard.press('Tab');
      assert(await root.locator('article summary').first().evaluate(node => node === document.activeElement));
      await page.keyboard.press('ArrowDown');
      assert(await root.locator('article summary').first().evaluate(node => node === document.activeElement));
    }
    await page.setViewportSize({ width: 1466, height: 1100 });
    // Modifier bindings still work when another listener consumes plain arrow keys.
    await page.evaluate(() => {
      window.consumeArrows = event => {
        if (event.key.startsWith('Arrow')) { event.preventDefault(); event.stopImmediatePropagation(); }
      };
      document.addEventListener('keydown', window.consumeArrows, true);
    });
    await cards.first().focus();
    await page.keyboard.press('ArrowRight');
    await focused(0);
    await page.keyboard.press('Control+Alt+l');
    await focused(1);
    await page.evaluate(() => document.removeEventListener('keydown', window.consumeArrows, true));
    await cards.nth(1).evaluate(node => node.disabled = true);
    await cards.first().focus();
    await page.keyboard.press('ArrowRight');
    await focused(2);
    await cards.nth(1).evaluate(node => node.disabled = false);
    await cards.first().focus();
    await page.keyboard.press('ArrowRight');
    await page.keyboard.press('Enter');
    await heading('Supply trunk branch takeoff');
    await page.keyboard.press('Shift+Enter');
    await heading('Equipment connection');
    await page.keyboard.press('Control+Alt+Enter');
    await heading('Supply trunk branch takeoff');
    await page.keyboard.down('Enter');
    await heading('Boot');
    await page.keyboard.down('Enter');
    await idle();
    await heading('Boot');
    await page.keyboard.up('Enter');
    await page.keyboard.press('ArrowDown');
    await page.keyboard.press('ArrowRight');
    await page.keyboard.press('Space');
    await heading('Elbows');

    // Submit directly from an unblurred quantity. Delay evaluation to exercise the queue.
    await page.route('**/path-templates/evaluate', async route => {
      await new Promise(resolve => setTimeout(resolve, 150));
      await route.continue();
    });
    await root.locator('[data-quantity="8A-4-or-5-piece"]').fill('2');
    await page.keyboard.press('ArrowDown');
    assert.equal(await root.locator('[data-quantity="8A-4-or-5-piece"]').inputValue(), '1');
    await page.keyboard.press('ArrowUp');
    await page.keyboard.press('Enter');
    await heading('Transitions');
    await page.keyboard.press('Shift+Enter');
    await heading('Elbows');
    assert.equal(await root.locator('[data-quantity="8A-4-or-5-piece"]').inputValue(), '2');
    assert.match(await root.locator('#step-fitting-rows').innerText(), /40 ft/);
    await root.locator('[data-quantity="8A-4-or-5-piece"]').fill('-1');
    await page.keyboard.press('Enter');
    await idle();
    await heading('Elbows');
    assert.match(await root.locator('#workspace-status').innerText(), /Complete|quantity/);
    await root.locator('[data-quantity="8A-4-or-5-piece"]').fill('2');
    await page.keyboard.press('Enter');
    await heading('Transitions');

    // The form stays intact while fitting details are open. Enter applies those details.
    await root.locator('[data-action="browse"]').click();
    const browseCards = root.locator('#browse-choices [data-fitting-choice]:not(:disabled)');
    await browseCards.first().focus();
    await page.keyboard.press('ArrowRight');
    assert(await browseCards.nth(1).evaluate(node => node === document.activeElement));
    await page.keyboard.press('ArrowDown');
    assert(await browseCards.nth(3).evaluate(node => node === document.activeElement));
    await page.keyboard.press('Control+Alt+k');
    assert(await browseCards.nth(1).evaluate(node => node === document.activeElement));
    await page.keyboard.press('Control+Alt+h');
    assert(await browseCards.first().evaluate(node => node === document.activeElement));
    await page.keyboard.press('Escape');
    await root.locator('[data-action="choose"][data-id="12J"]').focus();
    await page.keyboard.press('Enter');
    const details = root.locator('#fitting-details');
    await details.waitFor();
    await page.keyboard.press('Control+Alt+Enter');
    await heading('Transitions');
    assert.equal(await details.count(), 1);
    await details.locator('[data-field="0"]').selectOption('2:1');
    await details.locator('[data-field="1"]').selectOption('2');
    await details.locator('[data-detail-quantity]').fill('1');
    await page.keyboard.press('Enter');
    await details.waitFor({ state: 'detached' });
    await heading('Transitions');

    // Saved shortcut overrides must work inside the template modal, too.
    await page.evaluate(() => {
      const node = document.querySelector('[data-keybindings]');
      const bindings = JSON.parse(node.dataset.keybindings);
      bindings.nextStep = 'Control+Shift+N';
      bindings.previousStep = 'Control+Shift+B';
      node.dataset.keybindings = JSON.stringify(bindings);
    });
    await page.keyboard.press('Control+Shift+N');
    await heading('Review path');
    await root.locator('[data-path="name"]').fill('Upstairs supply');
    await root.locator('[data-path="straight"]').fill('10, 12');
    await page.keyboard.press('Control+Shift+B');
    await heading('Transitions');
    await page.keyboard.press('Control+Alt+A');
    await heading('Review path');
    assert.equal(await root.locator('[data-path="name"]').inputValue(), 'Upstairs supply');
    assert.equal(await root.locator('[data-path="straight"]').inputValue(), '10, 12');
    assert.equal(await root.locator('.path-review-table tbody tr').count(), 4);
    assert.match(await root.locator('.path-review-total').innerText(), /105\s*ft/);

    // Editing and removing rows update the total and retain the review form's draft.
    await root.locator('.path-review-table [data-action="edit-row"]').first().click();
    await details.locator('[data-detail-quantity]').fill('2');
    await page.keyboard.press('Enter');
    await details.waitFor({ state: 'detached' });
    await heading('Review path');
    assert.match(await root.locator('.path-review-total').innerText(), /115\s*ft/);
    await root.locator('.path-review-table [data-action="remove-row"]').last().click();
    await idle();
    assert.equal(await root.locator('.path-review-table tbody tr').count(), 3);
    assert.match(await root.locator('.path-review-total').innerText(), /110\s*ft/);
    assert.equal(await root.locator('[data-path="name"]').inputValue(), 'Upstairs supply');

    // Check both themes and narrow layouts, including actual button alignment.
    await page.addScriptTag({ path: require.resolve('axe-core/axe.min.js') });
    for (const theme of ['dark', 'light']) {
      await page.evaluate(theme => document.querySelector('[data-theme]').dataset.theme = theme, theme);
      for (const width of [1466, 1024, 768, 390, 320]) {
        await page.setViewportSize({ width, height: 1100 });
        await root.locator('.path-review').scrollIntoViewIfNeeded();
        assert(await root.evaluate(node => node.scrollWidth <= node.clientWidth), 'Review must fit the viewport');
        const edits = await root.locator('.path-review-actions [data-action="edit-row"]').evaluateAll(nodes => nodes.map(n => n.getBoundingClientRect().x));
        assert(edits.every(x => Math.abs(x - edits[0]) < 1), 'Edit buttons must align');
        const removes = await root.locator('.path-review-actions [data-action="remove-row"]').evaluateAll(nodes => nodes.map(n => n.getBoundingClientRect().x));
        assert(removes.every(x => Math.abs(x - removes[0]) < 1), 'Remove buttons must align');
        if ([1466, 390].includes(width)) {
          const violations = await page.evaluate(async () => (await axe.run('#path-step-form', {
            runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21aa'] },
          })).violations.map(v => ({ id: v.id, nodes: v.nodes.map(n => n.html) })));
          assert.deepEqual(violations, [], `${theme} review accessibility at ${width}px`);
        }
        await page.screenshot({ path: `/tmp/ductcalc-path-review-${theme}-${width}.png`, fullPage: true });
      }
    }
    await page.setViewportSize({ width: 1466, height: 1100 });
    await root.locator('[data-path="straight"]').fill('10, nope');
    await page.keyboard.press('Enter');
    await idle();
    await heading('Review path');
    assert.match(await root.locator('#workspace-status').innerText(), /positive whole-foot/);
    await root.locator('[data-path="straight"]').fill('10, 12');
    await page.keyboard.press('Enter');
    await page.locator('#fitting-path').waitFor({ state: 'hidden' });
    const savedRow = page.locator('tr').filter({ hasText: 'Upstairs supply' });
    await savedRow.waitFor();
    assert.match(await savedRow.innerText(), /132/);

    // Standalone workspaces load the same styles and retain validation after every row is removed.
    const customization = await context.request.post('/keybindings', { form: {
      bindings: JSON.stringify({ overrides: { fittingRight: 'Control+Shift+L' } }),
    } });
    assert.equal(customization.status(), 200);
    await page.goto(startURL);
    assert.match(await root.locator('.path-flow-key-help').innerText(), /Ctrl\+Shift\+L/);
    await page.keyboard.press('Control+Shift+l');
    await focused(0);
    await page.keyboard.press('Control+Alt+l');
    await focused(0);
    await page.keyboard.press('Control+Shift+l');
    await focused(1);
    await page.keyboard.press('Enter');
    await heading('Supply trunk branch takeoff');
    await page.keyboard.press('Enter');
    await heading('Boot');
    await choose('4G');
    await heading('Elbows');
    await page.keyboard.press('Enter');
    await heading('Transitions');
    await page.keyboard.press('Enter');
    await heading('Review path');
    while (await root.locator('[data-action="remove-row"]').count()) {
      await root.locator('[data-action="remove-row"]').first().click();
      await idle();
    }
    assert.match(await root.locator('.path-review-empty').innerText(), /No fittings/);
    assert.match(await root.locator('.path-review-total').innerText(), /0\s*ft/);
    assert.equal(await root.locator('.path-review-fields').evaluate(node => getComputedStyle(node).display), 'grid');
    await root.locator('[data-path="name"]').fill('Incomplete path');
    await page.keyboard.press('Enter');
    await idle();
    await heading('Review path');
    assert.match(await root.locator('#workspace-status').innerText(), /Complete every required section/);
    const templateID = new URL(startURL, origin).pathname.split('/').at(-1);
    await page.goto(`/path-templates/${templateID}`);
    await root.locator('[data-action="try"]').click();
    await heading('Equipment connection');
    await idle();
    await page.keyboard.press('ArrowRight');
    await focused(0);
    assert.deepEqual(errors, []);
    console.log('PASS: fitting arrow navigation, focus, Enter/Space selection, template Enter/Back/custom shortcuts, quantity commit and validation, nested dialogs, review edits/totals, desktop/mobile themes, and Enter save.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
