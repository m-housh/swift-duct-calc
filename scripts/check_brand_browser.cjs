const assert = require('node:assert/strict');

module.exports = async function checkBrand(page, origin) {
  for (const path of ['/', '/ductulator']) {
    await page.goto(`${origin}${path}`, { waitUntil: 'networkidle' });
    assert.equal(await page.locator('link[rel="icon"][type="image/svg+xml"]').getAttribute('href'), '/images/brand/favicon.svg?v=white-3');
    const assets = await page.locator('link[rel="icon"], link[rel="apple-touch-icon"], link[rel="manifest"]').evaluateAll(links => links.map(link => link.href));
    for (const url of assets) assert.equal((await page.request.get(url)).status(), 200, url);
  }
  const manifest = await (await page.request.get(`${origin}/site.webmanifest`)).json();
  assert.equal(manifest.name, 'DuctCalc');
  for (const icon of manifest.icons) {
    assert.equal((await page.request.get(`${origin}${icon.src}`)).status(), 200);
  }
  for (const scheme of ['light', 'dark']) {
    const logo = await page.request.get(`${origin}/images/brand/ductcalc-mark-${scheme}.webp`);
    assert.equal(logo.status(), 200);
    assert((await logo.body()).length < 20_000, `${scheme}: oversized wordmark asset`);
  }
  for (const scheme of ['light', 'dark']) {
    await page.emulateMedia({ colorScheme: scheme });
    await page.goto(`${origin}/images/brand/favicon.svg`);
    assert.equal(await page.locator('g').evaluate(el => getComputedStyle(el).stroke), 'rgb(255, 255, 255)');
  }

  await page.goto(`${origin}/fittings`, { waitUntil: 'networkidle' });
  const navbar = page.locator('.app-navbar');
  const themes = {
    light: 'light', cupcake: 'light', cyberpunk: 'light', nord: 'light', retro: 'light',
    dark: 'dark', aqua: 'dark', dracula: 'dark', night: 'dark', synthwave: 'dark',
  };
  for (const [theme, scheme] of Object.entries(themes)) {
    await page.emulateMedia({ colorScheme: scheme === 'light' ? 'dark' : 'light' });
    // Simulate the saved profile theme on the same wrapper used by MainPage.
    await page.locator('body > div').first().evaluate((el, theme) => el.dataset.theme = theme, theme);
    const logo = navbar.locator('.dc-wordmark-icon img:visible');
    assert.equal(await logo.count(), 1, theme);
    assert((await logo.getAttribute('src')).endsWith(`ductcalc-mark-${scheme}.webp`), theme);
    assert(await logo.evaluate(el => el.complete && el.naturalWidth > 0));
    assert.equal(await navbar.evaluate(el => getComputedStyle(el).backgroundColor), scheme === 'dark' ? 'rgb(17, 25, 35)' : 'rgb(245, 246, 248)');
    for (const width of [320, 375, 768, 1440]) {
      await page.setViewportSize({ width, height: 1000 });
      assert(await navbar.evaluate(el => el.scrollWidth <= el.clientWidth), `${theme}: navbar overflow at ${width}`);
    }
    await page.addScriptTag({ path: require.resolve('axe-core/axe.min.js') });
    const violations = await page.evaluate(async () => (await axe.run('.app-navbar', {
      runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'] },
    })).violations.map(rule => rule.id));
    assert.deepEqual(violations, [], `${theme}: navbar accessibility`);
    if (theme === 'light' || theme === 'dark') {
      await navbar.screenshot({ path: `/tmp/ductcalc-navbar-${theme}.png` });
      await page.setViewportSize({ width: 375, height: 1000 });
      await navbar.screenshot({ path: `/tmp/ductcalc-navbar-mobile-${theme}.png` });
    }
  }
  await navbar.getByRole('link', { name: 'DuctCalc, residential duct design' }).click();
  await page.waitForURL(url => url.pathname === '/');
  console.log('Brand checks passed: white favicon, icon assets, navbar themes, mobile layouts, accessibility, and home link.');
};
