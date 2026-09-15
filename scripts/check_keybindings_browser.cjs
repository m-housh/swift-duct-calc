const assert = require('node:assert/strict');
const fs = require('node:fs');
const {randomUUID} = require('node:crypto');
const {chromium} = require('playwright');
const origin = process.env.DUCTCALC_KEYBINDINGS_ORIGIN || `http://127.0.0.1:${fs.readFileSync('.dev-port','utf8').trim()}`;
(async () => {
  const browser = await chromium.launch();
  try {
    const context = await browser.newContext({baseURL:origin, viewport:{width:1440,height:1000}});
    const page = await context.newPage();
    const errors = []; page.on('pageerror', error => errors.push(error.message));
    const signup = await context.request.post('/signup',{form:{email:`keybindings-${randomUUID()}@example.test`,password:'TestPassword123!',confirmPassword:'TestPassword123!'}});
    assert.equal(signup.status(),200);
    await page.goto('/keybindings');
    await page.keyboard.press('Control+k');
    assert.equal(await page.evaluate(() => document.activeElement.id), 'keybinding-search');
    await page.keyboard.press('Control+Alt+P');
    await page.waitForURL(origin+'/projects');
    await page.goto('/keybindings');
    const created = await context.request.post('/projects', {form:{
      name:'Keybinding steps', streetAddress:'1 Test', city:'Test', state:'OH', zipCode:'45050'
    }});
    const id = (await created.text()).match(/data-project-id="([^"]+)"/)[1];
    await page.goto('/projects/' + id);
    const stepURLs = await page.locator('#project-sidebar a').evaluateAll(links => links.map(link => link.href));
    await page.keyboard.press('Control+Alt+/');
    await page.locator('#shortcut-hints').waitFor();
    assert.equal(await page.locator('#projectShortcuts').getAttribute('open'), null);
    assert(await page.locator('#shortcut-hints').textContent().then(text => text.includes('Ctrl+Alt+A')));
    for (const binding of ['Ctrl+Alt+1', 'Ctrl+Alt+2', 'Ctrl+Alt+3', 'Ctrl+Alt+Shift+Enter']) {
      assert(!await page.locator('#shortcut-hints').textContent().then(text => text.includes(binding)));
    }
    assert(!await page.locator('#shortcut-hints').textContent().then(text => text.includes('Ctrl+Alt+U')));
    await page.locator('nav .account-menu > summary').click();
    await page.locator('nav .account-menu[open]').waitFor();
    await page.evaluate(() => new Promise(resolve => requestAnimationFrame(resolve)));
    const revealedKeys = await page.locator('.shortcut-hint').allTextContents();
    for (const binding of ['Ctrl+Alt+U', 'Ctrl+Alt+P', 'Ctrl+Alt+D', 'Ctrl+Alt+F', 'Ctrl+Alt+Shift+/']) {
      assert(!revealedKeys.some(text => text.includes(binding)), binding + ' should not be revealed in the navbar');
    }
    await page.locator('nav .account-menu > summary').click();
    await page.waitForFunction(() => !document.getElementById('shortcut-hints').textContent.includes('Ctrl+Alt+U'));


    for (let index = 0; index < stepURLs.length; index++) {
      assert.equal(page.url(), stepURLs[index]);
      await page.locator('#shortcut-hints').waitFor();
      assert.equal(await page.locator('.shortcut-hints-note').textContent().then(text => text.includes('Ctrl+Alt+Enter for next step')), index < stepURLs.length - 1);
      if (index === 2) {
        assert.equal(await page.getByRole('button', {name:'Edit all',exact:true}).getAttribute('aria-keyshortcuts'), 'Control+Alt+A');
        await page.keyboard.press('Control+Alt+E');
        assert.equal(await page.locator('#equipmentForm-all').getAttribute('open'), null);
        await page.screenshot({path:'/tmp/ductcalc-reveal.png', animations:'disabled'});
        for (const width of [390,320]) {
          await page.setViewportSize({width,height:900});
          await page.waitForFunction(() => {
            const note = document.querySelector('.shortcut-hints-note').getBoundingClientRect();
            const boxes = [...document.querySelectorAll('.shortcut-hint')].map(hint => hint.getBoundingClientRect());
            return note.left >= 0 && note.right <= innerWidth && boxes.every((box, index) => box.left >= 0 && box.right <= innerWidth && boxes.slice(index + 1).every(other =>
              box.right <= other.left || box.left >= other.right || box.bottom <= other.top || box.top >= other.bottom));
          });
        }
        await page.screenshot({path:'/tmp/ductcalc-reveal-mobile.png',animations:'disabled'});
        await page.setViewportSize({width:1440,height:1000});
      }

      await page.keyboard.press('Control+Alt+Shift+/');
      const help = page.locator('#projectShortcuts');
      await help.locator(':scope[open]').waitFor();
      const captions = await help.locator('.modal-box > table > caption').allTextContents();
      const names = ['Project', 'Rooms', 'Equipment', 'Total effective length', 'Friction rate'];
      assert.equal(captions[0], index < 5 ? 'On this page · ' + names[index] : 'Project navigation');
      assert.equal(await help.locator('details').getAttribute('open'), null);
      if (index === 2) {
        assert.deepEqual(await help.locator('.modal-box > table').first().locator('th').allTextContents(),
          ['Edit all', 'Heating airflow', 'Cooling airflow', 'Static pressure']);
        await page.screenshot({path:'/tmp/ductcalc-context-help.png',animations:'disabled'});
        for (const width of [390, 320]) {
          await page.setViewportSize({width, height:900});
          assert(await help.evaluate(dialog => dialog.scrollWidth <= dialog.clientWidth));
          await page.addScriptTag({path:require.resolve('axe-core/axe.min.js')});
          const violations = await page.evaluate(async () => (await axe.run('#projectShortcuts',
            {runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21aa']}})).violations);
          assert.deepEqual(violations.map(v => v.id), []);
        }
        await page.screenshot({path:'/tmp/ductcalc-context-help-mobile.png',animations:'disabled'});
        await page.setViewportSize({width:1440,height:1000});
      }
      await help.locator('summary').click();
      assert.equal(await help.locator('details table').count(), 5);
      await help.locator('details table').first().waitFor({state:'visible'});
      await page.keyboard.press('Escape');

      if (index < stepURLs.length - 1) {
        await page.keyboard.press('Control+Alt+Enter');
        await page.waitForURL(stepURLs[index + 1]);
      }
    }
    await page.keyboard.press('Control+Alt+Enter');
    assert.equal(page.url(), stepURLs.at(-1));
    for (let index = stepURLs.length - 2; index >= 0; index--) {
      await page.keyboard.press('Control+Alt+Shift+Enter');
      await page.waitForURL(stepURLs[index]);
    }
    await page.keyboard.press('Control+Alt+Shift+Enter');
    assert.equal(page.url(), stepURLs[0]);
    await page.keyboard.press('Escape');
    await page.locator('#shortcut-hints').waitFor({state:'detached'});
    for (let index = 0; index < 5; index++) {
      await page.goto(stepURLs[index]);
      const control = page.locator('#project-content [data-project-primary]');
      assert.equal(await control.count(), 1);
      const dialog = await control.getAttribute('data-open-dialog');
      const href = await control.getAttribute('href');
      await page.keyboard.press('Control+Alt+A');
      if (dialog) {
        await page.locator('#' + dialog + '[open]').waitFor();
        await page.keyboard.press('Escape');
      } else await page.waitForURL(origin + href);
    }


    await page.goto(stepURLs[1]);
    assert.equal(await page.locator('.room-inspector, [data-room-inspector]').count(), 0);
    assert.equal(await page.locator('.page-title-row [data-project-primary]').count(), 0);
    assert.equal(await page.locator('.project-toolbar #room-search').count(), 1);
    assert.equal(await page.locator('.project-toolbar [data-project-primary]').count(), 1);
    await page.keyboard.press('Control+Alt+I');
    await page.locator('#uploadRooms[open]').waitFor();
    await page.keyboard.press('Escape');
    await page.getByRole('button', {name:'Add room',exact:true}).click();
    await page.locator('#roomForm[open]').waitFor();
    await page.keyboard.press('Escape');
    for (const [name, level] of [['Kitchen','1'],['Bedroom','2']]) {
      const response = await context.request.post(stepURLs[1], {form:{
        name, level, heatingLoad:'4000', coolingTotal:'3000', coolingSensible:'2500', registerCount:'1'
      }});
      assert.equal(response.status(),200);
    }
    await page.reload();
    assert.equal(await page.locator('#roomsTable tbody > tr').count(), 2);
    await page.keyboard.press('Control+Alt+J');
    assert(await page.locator('#roomsTable .selected-row').textContent().then(text => text.includes('Bedroom')));
    await page.keyboard.press('Control+K');
    await page.locator('#room-search').fill('Kitchen');
    assert.equal(await page.locator('#roomsTable tbody > tr:visible').count(),1);
    await page.getByRole('button',{name:'Edit Kitchen',exact:true}).click();
    await page.locator('dialog[open] input[name="name"]').waitFor();
    assert.equal(await page.locator('dialog[open] input[name="name"]').inputValue(),'Kitchen');
    await page.keyboard.press('Escape');
    await page.locator('#room-search').fill('');
    await page.locator('h1').click();
    await page.keyboard.press('Control+Alt+/');
    await page.waitForFunction(() => {
      const add = document.querySelector('.project-toolbar [data-project-primary]').getBoundingClientRect();
      const hint = [...document.querySelectorAll('.shortcut-hint')].find(hint => hint.textContent.includes('Next row'))?.getBoundingClientRect();
      return hint && (hint.top >= add.bottom || hint.bottom <= add.top || hint.right <= add.left || hint.left >= add.right);
    });
    await page.screenshot({path:'/tmp/ductcalc-rooms-table.png',animations:'disabled'});
    await page.keyboard.press('Escape');
    for (const width of [390,320]) {
      await page.setViewportSize({width,height:1000});
      assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
    }
    await page.screenshot({path:'/tmp/ductcalc-rooms-table-mobile.png',animations:'disabled'});
    await page.setViewportSize({width:1440,height:1000});
    await page.goto(stepURLs[3]);
    assert.equal(await page.locator('.page-title-row [data-project-primary]').count(), 0);
    assert.equal(await page.locator('.path-schedule-heading [data-project-primary]').count(), 1);
    for (const [combo, type] of [['Control+Alt+R', 'return'], ['Control+Alt+S', 'supply']]) {
      await page.goto(stepURLs[3]);
      await page.keyboard.press(combo);
      await page.locator('#path-type').waitFor();
      assert.equal(await page.locator('#path-type').inputValue(), type);
    }
    await page.goto(stepURLs[3]);
    await page.keyboard.press('Control+Alt+/');
    await page.locator('#shortcut-hints').waitFor();
    const pathKeys = await page.locator('.shortcut-hint').allTextContents();
    assert(pathKeys.includes('Ctrl+Alt+R'));
    assert(pathKeys.includes('Ctrl+Alt+S'));
    await page.screenshot({path:'/tmp/ductcalc-path-controls.png',animations:'disabled'});
    await page.locator('.path-schedule-heading').scrollIntoViewIfNeeded();
    await page.screenshot({path:'/tmp/ductcalc-path-table-controls.png',animations:'disabled'});
    await page.keyboard.press('Escape');
    await page.setViewportSize({width:390,height:1000});
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
    await page.setViewportSize({width:1440,height:1000});
    await page.goto('/keybindings');
    const record = action => page.locator(`[data-keybinding-action="${action}"] [data-binding]`);
    const status = page.locator('#keybinding-status');
    await record('projects').click();
    await page.keyboard.press('Control+Alt+2');
    await status.filter({hasText:'Already used by Rooms'}).waitFor();
    await page.keyboard.press('Escape');
    assert.equal(await record('projects').getAttribute('data-binding'),'Control+Alt+P');
    await record('projects').click(); await page.keyboard.press('Control+Shift+P');
    await record('search').click(); await page.keyboard.press('Alt+K');
    await record('nextStep').click(); await page.keyboard.press('Alt+ArrowRight');
    await record('previousStep').click(); await page.keyboard.press('Alt+ArrowLeft');
    await record('primaryAction').click(); await page.keyboard.press('Alt+Enter');
    await record('reveal').click(); await page.keyboard.press('Alt+R');
    await record('help').click(); await page.keyboard.press('Control+Shift+/');
    await record('addReturn').click(); await page.keyboard.press('Alt+T');
    await record('addSupply').click(); await page.keyboard.press('Alt+S');
    await record('importLoads').click(); await page.keyboard.press('Alt+I');
    const reference = await context.newPage(); await reference.goto('/fittings');
    await page.getByRole('button',{name:'Save changes',exact:true}).click();
    await status.filter({hasText:'Keybindings saved.'}).waitFor();
    await page.reload();
    assert.equal(await record('projects').getAttribute('data-binding'),'Control+Shift+P');
    assert.equal(await record('search').getAttribute('data-binding'),'Alt+K');
    await page.goto(stepURLs[0]);
    await page.keyboard.press('Alt+R');
    await page.locator('#shortcut-hints').waitFor();
    assert(await page.locator('#shortcut-hints').textContent().then(text => text.includes('Alt+Enter')));
    await page.keyboard.press('Escape');
    await page.keyboard.press('Alt+ArrowRight'); await page.waitForURL(stepURLs[1]);
    await page.keyboard.press('Alt+ArrowLeft'); await page.waitForURL(stepURLs[0]);
    await page.keyboard.press('Alt+Enter'); await page.locator('#projectForm[open]').waitFor();
    await page.keyboard.press('Escape');
    await page.keyboard.press('Control+Shift+/');
    const currentKeys = page.locator('#projectShortcuts .modal-box > table').first().locator('kbd');
    assert.deepEqual(await currentKeys.allTextContents(), ['Alt', 'Enter']);
    await page.keyboard.press('Escape');
    await page.goto('/keybindings');
    await page.locator('h1').click(); await page.keyboard.press('Alt+K');
    assert.equal(await page.evaluate(() => document.activeElement.id),'keybinding-search');
    await page.keyboard.press('Control+Shift+P');
    await page.waitForURL(origin+'/projects');
    await page.goto(stepURLs[1]);
    await page.keyboard.press('Alt+I');
    await page.locator('#uploadRooms[open]').waitFor();
    await page.keyboard.press('Escape');
    for (const [combo, type] of [['Alt+T', 'return'], ['Alt+S', 'supply']]) {
      await page.goto(stepURLs[3]);
      await page.keyboard.press(combo);
      await page.locator('#path-type').waitFor();
      assert.equal(await page.locator('#path-type').inputValue(), type);
    }

    await page.goto('/keybindings');
    await reference.locator('a[data-group="2"]').click();
    await reference.waitForFunction(() => JSON.parse(document.querySelector('[data-keybindings]').dataset.keybindings).projects === 'Control+Shift+P');
    await reference.close();
    await page.getByRole('searchbox',{name:'Find a keybinding'}).fill('heating');
    assert.equal(await page.locator('[data-keybinding-action]:visible').count(),1);
    await page.getByRole('searchbox',{name:'Find a keybinding'}).fill('');
    for (const width of [1440,390,320]) {
      await page.setViewportSize({width,height:1000});
      assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
      await page.addScriptTag({path:require.resolve('axe-core/axe.min.js')});
      const violations = await page.evaluate(async () => (await axe.run('.account-workspace',{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21aa']}})).violations);
      assert.deepEqual(violations.map(v => ({id:v.id,nodes:v.nodes.map(n=>n.target)})),[]);
    }
    await page.setViewportSize({width:1440,height:1000});
    await page.screenshot({path:'/tmp/ductcalc-keybindings.png'});
    // A failed request keeps the recorded draft available.
    await page.route('**/keybindings', route => route.request().method() === 'POST'
      ? route.fulfill({status:422,contentType:'application/vnd.ductcalc.error+json',body:JSON.stringify({title:'Could not save keybindings',message:'Please retry.',fields:[]})}) : route.continue());
    await record('profile').click(); await page.keyboard.press('Control+Shift+U');
    await page.getByRole('button',{name:'Save changes',exact:true}).click();
    await page.getByRole('alert').filter({hasText:'Please retry.'}).waitFor();
    assert.equal(await record('profile').getAttribute('data-binding'),'Control+Shift+U');
    await page.unroute('**/keybindings');
    await page.getByRole('button',{name:'Reset all',exact:true}).click();
    await page.getByRole('button',{name:'Save changes',exact:true}).click();
    await status.filter({hasText:'Keybindings saved.'}).waitFor();
    await page.reload();
    assert.equal(await record('projects').getAttribute('data-binding'),'Control+Alt+P');
    // Use a complete design snapshot and a stub PDF to exercise the browser download flow.
    const exportPage = await context.newPage();
    exportPage.on('pageerror', error => errors.push(error.message));
    await exportPage.route('**/export-shortcut-test', route => route.fulfill({contentType:'text/html',
      body:fs.readFileSync('Tests/ViewControllerTests/__Snapshots__/ViewControllerTests/projectDetail.6.html','utf8')}));
    await exportPage.route('**/pdf', route => route.fulfill({contentType:'application/pdf',
      headers:{'content-disposition':'attachment; filename="design.pdf"'}, body:'%PDF-1.4\n%%EOF'}));
    await exportPage.goto('/export-shortcut-test');
    await exportPage.keyboard.press('Control+Alt+/');
    assert(await exportPage.locator('.shortcut-hint').allTextContents().then(labels => labels.includes('Ctrl+Alt+E')));
    const download = exportPage.waitForEvent('download');
    await exportPage.keyboard.press('Control+Alt+E');
    assert.equal((await download).suggestedFilename(), 'design.pdf');
    await exportPage.close();
    assert.deepEqual(errors,[]);
    console.log('Project step navigation and actions, key recording, conflicts, cancel, save, reload, cross-tab navigation, reset, errors, mobile layout and accessibility passed.');
  } finally { await browser.close(); }
})().catch(error => {console.error(error);process.exitCode=1;});
