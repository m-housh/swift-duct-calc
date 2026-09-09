// Requires Playwright and a running application. Uses public pages only.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');

(async () => {
  const base = process.env.FITTING_APP_URL || 'http://localhost:8081';
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  try {
    const page = await browser.newPage({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    const group = page.locator('#group-filter');
    async function settled(value) {
      await page.waitForFunction(value => {
        const root = document.querySelector('#fittings-page');
        return root && !root.hasAttribute('aria-busy') && root.querySelector('#group-filter').value === value
          && new URL(root.dataset.url, location.origin).searchParams.get('group') === value;
      }, value);
    }
    await page.goto(base + '/fittings?group=8');
    for (const width of [320, 390, 700]) {
      await page.setViewportSize({ width, height: 844 });
      assert(await page.locator('.mobile-group-navigation #group-filter').isVisible());
      assert(await page.locator('.group-control > span').isVisible());
      const bounds = await group.boundingBox();
      assert(bounds.height >= 47.9 && bounds.width >= width - 60);
      assert(await page.locator('#fittings-page').evaluate(el => el.scrollWidth <= el.clientWidth));
    }
    await page.setViewportSize({ width: 390, height: 844 });
    await page.evaluate(() => window.scrollTo(0, 600));
    const sticky = await page.locator('.mobile-group-navigation').boundingBox();
    assert(Math.abs(sticky.y) <= 1, 'Group control stays at the top while reading details');
    await page.locator('.fitting-sidebar').evaluate(el => { el.scrollLeft = el.scrollWidth; });
    await group.focus();
    await group.selectOption('12');
    await settled('12');
    assert.equal(new URL(page.url()).searchParams.get('group'), '12');
    assert.equal(await group.evaluate(el => el === document.activeElement), true);
    assert.equal(await page.locator('.fitting-sidebar').evaluate(el => el.scrollLeft), 0);
    assert(await page.locator('[data-select][aria-current]').isVisible());
    await page.goBack();
    await settled('8');
    await page.goForward();
    await settled('12');
    await page.locator('[data-system="return"]').click();
    await page.waitForSelector('[data-system="return"][aria-current="true"]');
    assert.equal(await group.locator('option[value="1"]').count(), 0);
    await group.selectOption('6');
    await settled('6');
    await page.locator('#search').fill('8a smooth');
    await settled('all');
    assert.equal(await page.locator('[data-select]').count(), 2);
    assert.equal(await page.locator('#search').inputValue(), '8a smooth');
    await page.locator('[data-action="reset"]').click();
    await page.waitForSelector('[data-system="all"][aria-current="true"]');
    await group.selectOption('12');
    await settled('12');
    await page.screenshot({ path: '/tmp/fitting-reference-mobile-group.png', fullPage: true });
    await page.setViewportSize({ width: 1440, height: 1000 });
    assert(await page.locator('#filters #group-filter').isVisible());
    assert(await page.locator('.group-sidebar .system-toggle').isVisible());
    await group.selectOption('8');
    await settled('8');
    assert.equal(await page.locator('[data-group="8"][aria-current]').count(), 1);

    const plain = await browser.newPage({ javaScriptEnabled: false, viewport: { width: 320, height: 740 } });
    await plain.goto(base + '/fittings?group=8');
    assert(await plain.locator('.group-control > span').isVisible());
    await plain.locator('#group-filter').selectOption('12');
    await plain.locator('#filters button[type="submit"]').click();
    await plain.waitForURL(url => url.searchParams.get('group') === '12');
    assert.equal(await plain.locator('#group-filter').inputValue(), '12');
    assert(await plain.locator('#fittings-page').evaluate(el => el.scrollWidth <= el.clientWidth));
    assert.deepEqual(errors, []);
    console.log('PASS: mobile sizing, sticky group selector, group changes, scroll reset, focus, history, air-path filtering, search, desktop resize, and no-JavaScript submission.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
