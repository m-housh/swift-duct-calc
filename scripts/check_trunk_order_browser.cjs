// Uses deterministic rendered view snapshots, no running app.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
const read = file => fs.readFileSync(path.join(root, file), 'utf8');
const fixture = read('Tests/ViewControllerTests/__Snapshots__/ProjectWorkspaceTests/oddTrunksStayInSeparateColumns.1.html');
const css = ['output', 'project-workspace', 'trunks'].map(name => read(`Public/css/${name}.css`)).join('\n');
const html = `<!doctype html><html data-theme="ductcalc"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><style>${css}</style></head>
  <body><main class="project-workspace"><section class="project-panel trunk-panel">${fixture}</section></main>
  <script>${read('Public/js/request-errors.js')}</script><script>${read('Public/js/trunk-order.js')}</script></body></html>`;

(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 1000 }, hasTouch: true });
    const errors = [];
    const saves = [];
    let rejectSave = false;
    page.on('pageerror', error => errors.push(error.message));
    await page.route('http://trunk-order.test/**', route => {
      if (route.request().method() !== 'POST') return route.fulfill({ contentType: 'text/html', body: html });
      saves.push(new URLSearchParams(route.request().postData()));
      return rejectSave
        ? route.fulfill({ status: 400, contentType: 'application/vnd.ductcalc.error+json', body: JSON.stringify({ message: 'The trunk list changed. Reload the page and try again.' }) })
        : route.fulfill({ contentType: 'text/html', body: '' });
    });
    const supply = page.locator('.trunk-column.supply');
    const returns = page.locator('.trunk-column.return');
    const names = list => list.locator('.trunk-card-main strong').allTextContents();
    const handle = name => page.getByRole('button', { name: `Reorder ${name}`, exact: true });
    const saved = () => page.waitForFunction(() => !document.querySelector('[data-saving-order]'));

    await page.goto('http://trunk-order.test/');
    assert.deepEqual(await names(supply), ['Trunk 0', 'Trunk 2', 'Trunk 4']);
    const bounds = await supply.locator('.trunk-card').first().boundingBox();
    assert(bounds.height <= 112, `Compact trunk is ${bounds.height}px tall`);
    // Shared headings and every row retain the same right edge for each measurement.
    const alignment = await supply.evaluate(list => ({
      headings: [...list.querySelectorAll('.trunk-column-head > span')].slice(2).map(el => el.getBoundingClientRect().right),
      rows: [...list.querySelectorAll('.trunk-card-sizes')].map(sizes => [...sizes.children].map(el => el.getBoundingClientRect().right)),
    }));
    for (const row of alignment.rows) row.forEach((right, index) => assert(Math.abs(right - alignment.headings[index]) < 1));
    await page.screenshot({ path: '/tmp/ductcalc-trunks-desktop.png', fullPage: true });

    // A script loaded again by HTMX must not duplicate listeners.
    await page.addScriptTag({ content: read('Public/js/trunk-order.js') });
    await handle('Trunk 0').focus();
    await page.keyboard.press('ArrowUp');
    assert.equal(saves.length, 0);
    await page.keyboard.press('ArrowDown');
    await saved();
    assert.equal(saves.length, 1);
    assert.deepEqual(await names(supply), ['Trunk 2', 'Trunk 0', 'Trunk 4']);
    assert.deepEqual(saves[0].getAll('trunks'), await supply.locator('.trunk-card').evaluateAll(cards => cards.map(card => card.dataset.trunkId)));
    assert.equal(saves[0].get('type'), 'supply');
    assert(await handle('Trunk 0').evaluate(element => element === document.activeElement));

    // A failed save restores the prior order and explains why.
    rejectSave = true;
    await page.keyboard.press('ArrowDown');
    await saved();
    assert.deepEqual(await names(supply), ['Trunk 2', 'Trunk 0', 'Trunk 4']);
    assert.match(await supply.getByRole('status').textContent(), /list changed/);
    rejectSave = false;

    // Pointer capture survives moving the card in the DOM.
    let from = await handle('Trunk 4').boundingBox();
    let to = await supply.locator('.trunk-card').first().boundingBox();
    await page.mouse.move(from.x + from.width / 2, from.y + from.height / 2);
    await page.mouse.down();
    await page.mouse.move(to.x + 60, to.y + 5, { steps: 8 });
    await page.mouse.up();
    await saved();
    assert.deepEqual(await names(supply), ['Trunk 4', 'Trunk 2', 'Trunk 0']);
    assert.deepEqual(await names(returns), ['Trunk 1', 'Trunk 3']);
    assert.equal(saves.length, 3);

    // Escape cancels a drag without saving it.
    from = await handle('Trunk 4').boundingBox();
    to = await supply.locator('.trunk-card').last().boundingBox();
    await page.mouse.move(from.x + 12, from.y + 16);
    await page.mouse.down();
    await page.mouse.move(to.x + 60, to.y + to.height - 5, { steps: 8 });
    await page.keyboard.press('Escape');
    await page.mouse.up();
    assert.deepEqual(await names(supply), ['Trunk 4', 'Trunk 2', 'Trunk 0']);
    assert.equal(saves.length, 3);

    await page.setViewportSize({ width: 390, height: 1000 });
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
    await supply.locator('.trunk-card-main strong').first().evaluate(el => {
      el.textContent = 'A very long trunk name serving the upstairs bedrooms and hallway';
    });
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
    await page.screenshot({ path: '/tmp/ductcalc-trunks-mobile.png', fullPage: true });

    // Touch dragging uses the same handle and keeps trunks in their own list.
    const cdp = await page.context().newCDPSession(page);
    from = await handle('Trunk 3').boundingBox();
    to = await returns.locator('.trunk-card').first().boundingBox();
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: from.x + 12, y: from.y + 16 }] });
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x: to.x + 60, y: to.y + 5 }] });
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
    await saved();
    assert.deepEqual(await names(returns), ['Trunk 3', 'Trunk 1']);
    assert.equal(saves.at(-1).get('type'), 'return');
    // The application adds page gutters, leaving less room than the viewport width alone.
    await page.setViewportSize({ width: 320, height: 1000 });
    await page.locator('.project-panel').evaluate(el => { el.style.margin = '0 28px'; });
    const clipped = await page.locator('.trunk-card-sizes > div').evaluateAll(cells =>
      cells.filter(cell => cell.scrollWidth > cell.clientWidth + 1).map(cell => cell.textContent));
    assert.deepEqual(clipped, [], 'Measurements must fit their cells on narrow cards');
    assert.deepEqual(errors, []);
    console.log(`PASS: compact layout (${bounds.height}px), keyboard, mouse, touch, cancellation, failed saves, and repeated script loading.`);
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exit(1); });
