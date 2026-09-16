const assert = require('node:assert/strict');
const { chromium } = require('playwright');

const origin = process.env.DUCTCALC_HOME_ORIGIN || 'http://127.0.0.1:8080';
assert(['localhost', '127.0.0.1'].includes(new URL(origin).hostname), 'Use a local app');

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.DUCTCALC_BROWSER_EXECUTABLE });
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 }, reducedMotion: 'reduce' });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  try {
    const response = await page.goto(origin, { waitUntil: 'networkidle' });
    assert.equal(response.status(), 200);
    assert.equal(await page.title(), 'Residential HVAC Duct Design Software | DuctCalc');
    assert.equal(await page.locator('link[rel=canonical]').getAttribute('href'), 'https://ductcalc.pro/');
    assert.equal(await page.locator('meta[property="og:url"]').getAttribute('content'), 'https://ductcalc.pro/');
    assert.equal(await page.locator('h1').count(), 1);
    assert.equal(await page.locator('.feature').count(), 7);
    assert.equal(await page.locator('iframe, .concept-picker, .theme-picker').count(), 0);
    assert.equal(await page.locator('.hero-art img').getAttribute('loading'), 'eager');
    assert.equal(await page.locator('.hero-art img').getAttribute('fetchpriority'), 'high');
    assert(await page.locator('#quick-tools').evaluate(el => el.offsetTop < document.querySelector('#chapters').offsetTop));

    await page.keyboard.press('Tab');
    assert.equal(await page.locator('.skip-link').evaluate(el => el === document.activeElement), true);
    await page.keyboard.press('Enter');
    assert.equal(await page.locator('main').evaluate(el => el === document.activeElement), true);
    await page.locator('main').evaluate(el => el.blur());

    // System changes must update the existing page, including its real app screenshots.
    for (const scheme of ['light', 'dark']) {
      await page.emulateMedia({ colorScheme: scheme });
      await page.waitForFunction(scheme => document.querySelector('.hero-art img').currentSrc.endsWith('sizes-' + scheme + '.jpg'), scheme);
      for (const image of await page.locator('.screen-frame img, .dc-wordmark-icon img').all()) {
        await image.evaluate(async img => { img.loading = 'eager'; await img.decode(); });
        assert(await image.evaluate((img, scheme) => img.currentSrc.includes('-' + scheme + '.'), scheme));
      }
      assert.equal(await page.locator('.landing').evaluate(el => getComputedStyle(el).backgroundColor),
        scheme === 'light' ? 'rgb(245, 246, 248)' : 'rgb(17, 25, 35)');

      for (const width of [320, 375, 768, 1000, 1001, 1024, 1280, 1440, 1680, 1920, 2560]) {
        await page.setViewportSize({ width, height: 1000 });
        const layout = await page.evaluate(() => {
          const image = document.querySelector('.hero-art .screen-frame').getBoundingClientRect();
          const tools = document.querySelector('#quick-tools').getBoundingClientRect();
          const copy = document.querySelector('.hero-copy').getBoundingClientRect();
          return {
            overflow: document.documentElement.scrollWidth > innerWidth,
            rightMargin: innerWidth - image.right,
            aligned: Math.abs(image.right - tools.right) < 1,
            contained: image.left >= tools.left - 1,
            separated: image.left >= copy.right || image.top >= copy.bottom,
          };
        });
        assert(!layout.overflow && layout.rightMargin >= 19, scheme + ': hero padding at ' + width);
        assert(layout.aligned && layout.contained && layout.separated, scheme + ': hero alignment at ' + width);
        for (const feature of await page.locator('.feature').all()) {
          await feature.scrollIntoViewIfNeeded();
          assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
            scheme + ': feature overflow at ' + width);
        }
      }

      for (const width of [375, 1440]) {
        await page.setViewportSize({ width, height: 1000 });
        await page.addScriptTag({ path: require.resolve('axe-core/axe.min.js') });
        const violations = await page.evaluate(async () => (await axe.run(document, {
          runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'] },
        })).violations.map(rule => ({ rule: rule.id, targets: rule.nodes.map(node => node.target) })));
        assert.deepEqual(violations, [], scheme + ': accessibility at ' + width);
        await page.evaluate(() => scrollTo(0, 0));
        await page.screenshot({ path: '/tmp/ductcalc-home-' + scheme + '-' + width + '.png' });
        await page.screenshot({ path: '/tmp/ductcalc-home-' + scheme + '-' + width + '-full.png', fullPage: true });
      }
    }

    await page.emulateMedia({ reducedMotion: 'no-preference' });
    await page.reload({ waitUntil: 'networkidle' });
    assert(await page.locator('html').evaluate(el => el.classList.contains('motion-enabled')));
    for (const feature of await page.locator('.feature').all()) {
      await feature.scrollIntoViewIfNeeded();
      await page.waitForFunction(id => [...document.getElementById(id).querySelectorAll('.reveal')]
        .every(el => !el.classList.contains('is-waiting')), await feature.getAttribute('id'));
    }
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.waitForFunction(() => document.documentElement.classList.contains('motion-paused'));
    assert.equal(await page.locator('.hero-art .screen-frame').evaluate(el => getComputedStyle(el).animationName), 'none');

    // Every internal destination remains reachable from the production homepage.
    for (const [selector, path] of [
      ['.hero .primary-link', '/signup'],
      ['.site-header a[href="/login"]', '/login'],
      ['#quick-tools a[href="/ductulator"]', '/ductulator'],
      ['#quick-tools a[href="/fittings"]', '/fittings'],
      ['.site-footer a[href="/privacy-policy"]', '/privacy-policy'],
    ]) {
      await page.goto(origin);
      await page.locator(selector).click();
      await page.waitForURL(url => url.pathname === path);
    }
    for (const path of ['/home-concepts/editorial', '/home-concepts/studio', '/home-concepts/walkthrough']) {
      assert.equal((await page.request.get(origin + path)).status(), 404);
    }

    const noJS = await browser.newPage({ javaScriptEnabled: false, reducedMotion: 'reduce' });
    await noJS.goto(origin, { waitUntil: 'networkidle' });
    for (const width of [320, 1440]) {
      await noJS.setViewportSize({ width, height: 1000 });
      assert.equal(await noJS.locator('.feature-visual:visible').count(), 7);
      assert(await noJS.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
      for (const element of await noJS.locator('.reveal').all()) {
        assert.equal(await element.evaluate(el => getComputedStyle(el).opacity), '1');
      }
    }
    await noJS.close();
    assert.deepEqual(errors, []);
    console.log('Home browser checks passed: SEO, system themes, images, 320–2560px layouts, navigation, keyboard access, reduced motion, accessibility, and no-JavaScript fallback.');
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
