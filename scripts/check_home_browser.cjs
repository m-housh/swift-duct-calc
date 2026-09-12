const assert = require('node:assert/strict');
const { chromium } = require('playwright');

const origin = process.env.DUCTCALC_HOME_ORIGIN || 'http://127.0.0.1:8080';
assert(['localhost', '127.0.0.1'].includes(new URL(origin).hostname), 'Use a local app');

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.DUCTCALC_BROWSER_EXECUTABLE });
  const page = await browser.newPage({ viewport: { width: 1440, height: 1100 }, colorScheme: 'light' });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  try {
    const home = await page.goto(origin, { waitUntil: 'networkidle' });
    assert.equal(home.status(), 200);
    const preview = page.locator('.workspace-demo');
    await preview.scrollIntoViewIfNeeded();
    await page.waitForFunction(() => document.querySelector('.workspace-demo').dataset.playing === 'true');
    await preview.hover();
    // Watch a complete cycle, including the return to the first sidebar step.
    for (const index of [1, 2, 3, 4, 0]) {
      await page.waitForFunction(index =>
        document.querySelector('[data-preview-panel][aria-hidden=false]').dataset.previewPanel === String(index),
      index, { timeout: 5000 });
      const frame = page.frameLocator(`[data-preview-panel="${index}"] iframe`);
      await frame.locator('.project-workspace').waitFor();
      assert.equal(await frame.locator('#project-sidebar a').nth(index + 1).getAttribute('aria-current'), 'page');
      assert.equal(await frame.locator('.app-navbar').evaluate(el => getComputedStyle(el).display), 'none');
    }
    await page.getByRole('button', { name: 'Pause preview', exact: true }).click();
    await page.waitForTimeout(3200);
    assert.equal(await page.locator('[data-preview-panel][aria-hidden=false]').getAttribute('data-preview-panel'), '0');
    await page.locator('[data-preview-step="2"]').click();
    assert.equal(await preview.getAttribute('data-playing'), 'false');

    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.reload({ waitUntil: 'networkidle' });
    assert.equal(await preview.getAttribute('data-playing'), 'false');
    for (const scheme of ['light', 'dark']) {
      await page.emulateMedia({ colorScheme: scheme });
      const logo = page.locator('.dc-wordmark-icon img');
      await page.waitForFunction(scheme =>
        document.querySelector('.dc-wordmark-icon img').currentSrc.endsWith(`ductcalc-mark-${scheme}.webp`), scheme);
      assert(await logo.evaluate(el => el.complete && el.naturalWidth > 0));
      await preview.scrollIntoViewIfNeeded();
      const frame = page.frameLocator('[data-preview-panel="0"] iframe');
      await frame.locator('.project-workspace').waitFor();
      await page.waitForFunction(scheme =>
        document.querySelector('.demo-app-frame').contentDocument.documentElement.dataset.theme === scheme, scheme);
      assert.equal(await frame.locator('input').first().evaluate(el => {
        el.focus();
        return el.ownerDocument.activeElement === el;
      }), false, 'Sample inputs must stay inert');

      for (const width of [320, 375, 768, 1440]) {
        await page.setViewportSize({ width, height: 1100 });
        await page.waitForTimeout(100);
        assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `${scheme}: overflow at ${width}px`);
      }
      await page.addScriptTag({ path: require.resolve('axe-core/axe.min.js') });
      const violations = await page.evaluate(async () => (await axe.run(document, {
        runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'] },
      })).violations.map(rule => ({ rule: rule.id, targets: rule.nodes.map(node => node.target) })));
      assert.deepEqual(violations, [], `${scheme}: accessibility violations`);
      await page.evaluate(() => scrollTo(0, 0));
      await page.screenshot({ path: `/tmp/ductcalc-home-${scheme}.png`, fullPage: true });
    }
    for (const [label, destination] of [
      ['Start a project', '/signup'], ['Log in ↗', '/login'],
      ['Just need a duct size? Try the ductulator →', '/ductulator'], ['Fitting reference', '/fittings'],
    ]) {
      await page.goto(origin);
      await page.getByRole('link', { name: label, exact: true }).click();
      await page.waitForURL(url => url.pathname === destination);
    }
    assert.deepEqual(errors, []);
    console.log('Home browser checks passed: autoplay, sidebar order, pause, reduced motion, responsive layouts, themes, accessibility, and navigation.');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
