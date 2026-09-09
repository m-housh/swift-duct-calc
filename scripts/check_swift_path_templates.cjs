#!/usr/bin/env node
/* Runs the real production UI against an isolated local Swift app. Never target production. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { randomUUID } = require('node:crypto');
const { JSDOM, VirtualConsole } = require('jsdom');
const origin = process.env.DUCT_TEMPLATE_QA_ORIGIN || 'http://127.0.0.1:18093';
assert(
  ['127.0.0.1', 'localhost'].includes(new URL(origin).hostname),
  'QA must use an isolated local app'
);
const script = fs.readFileSync('Public/js/path-templates.js', 'utf8');
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

function session() {
  const cookies = new Map();
  return async function http(path, init = {}) {
    const response = await fetch(new URL(path, origin), {
      ...init,
      headers: {
        ...init.headers,
        Cookie: [...cookies].map(([key, value]) => `${key}=${value}`).join('; '),
      },
    });
    for (const cookie of response.headers.getSetCookie()) {
      const first = cookie.split(';')[0],
        equals = first.indexOf('=');
      cookies.set(first.slice(0, equals), first.slice(equals + 1));
    }
    return response;
  };
}
function form(values) {
  return {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(values),
  };
}
function payload(html) {
  const document = new JSDOM(html).window.document;
  const node = document.querySelector('#path-template-data');
  assert(
    node,
    document.querySelector('[data-workspace-error]')?.textContent || 'Workspace missing'
  );
  return JSON.parse(node.textContent);
}
async function register(http, theme = 'dark') {
  const password = randomUUID();
  const response = await http(
    '/signup',
    form({ email: `templates-${randomUUID()}@example.com`, password, confirmPassword: password })
  );
  const html = await response.text(),
    document = new JSDOM(html).window.document;
  const userID = document.querySelector('[name="userID"]')?.value;
  assert(userID, 'Signup should return the new account profile');
  const profile = await http(
    '/signup/profile',
    form({
      userID,
      firstName: 'Template',
      lastName: 'QA',
      companyName: 'Local QA',
      streetAddress: '123 Test St',
      city: 'Test',
      state: 'OH',
      zipCode: '45040',
      theme,
    })
  );
  assert.equal(profile.status, 200);
}
async function mount(html, http) {
  const errors = [],
    redirects = [];
  const virtualConsole = new VirtualConsole();
  virtualConsole.on('jsdomError', (error) => {
    if (!error.message.includes('navigation')) errors.push(error);
  });
  const dom = new JSDOM(html, {
    url: origin,
    runScripts: 'outside-only',
    pretendToBeVisual: true,
    virtualConsole,
  });
  const { window } = dom;
  // Run with DUCT_TEMPLATE_QA_HTTP=1 to exercise HTTP hostname/IP access, where
  // browsers expose getRandomValues but do not expose randomUUID.
  window.crypto.randomUUID = process.env.DUCT_TEMPLATE_QA_HTTP === '1' ? undefined : randomUUID;
  window.HTMLDialogElement.prototype.showModal = function () {
    this.open = true;
  };
  window.HTMLDialogElement.prototype.close = function () {
    this.open = false;
  };
  window.confirm = () => true;
  window.fetch = async (url, init) => {
    const response = await http(url, init);
    const body = await response.clone().text();
    const redirect = new JSDOM(body).window.document.querySelector('[data-redirect]')?.dataset
      .redirect;
    if (redirect) redirects.push(redirect);
    return response;
  };
  window.eval(script);
  window.document.dispatchEvent(new window.Event('DOMContentLoaded'));
  const root = window.document.querySelector('#path-template-workspace');
  async function settled() {
    for (let i = 0; i < 500; i++) {
      if (root.getAttribute('aria-busy') !== 'true') break;
      await sleep(10);
    }
    assert.notEqual(root.getAttribute('aria-busy'), 'true', 'UI request timed out');
    assert.deepEqual(errors, []);
  }
  async function click(action, extra = '') {
    const target = root.querySelector(`[data-action="${action}"]${extra}`);
    assert(target, `Missing action ${action} ${extra}`);
    target.click();
    await settled();
  }
  async function set(selector, value, checked) {
    const target = root.querySelector(selector);
    assert(target, `Missing field ${selector}`);
    if (checked !== undefined) target.checked = checked;
    else target.value = value;
    target.dispatchEvent(new window.Event('input', { bubbles: true }));
    target.dispatchEvent(new window.Event('change', { bubbles: true }));
    await settled();
  }
  return {
    dom,
    root,
    redirects,
    click,
    set,
    submitDetails: async () => {
      const form = root.querySelector('#fitting-details-form');
      assert(form, 'Fitting details must use a form for Return submission');
      assert.equal(form.querySelector('[data-action="apply-details"]').type, 'submit');
      form.requestSubmit();
      await settled();
    },
    upload: async (file) => {
      const input = root.querySelector('#import-template-file');
      Object.defineProperty(input, 'files', {
        configurable: true,
        value: [
          {
            size: JSON.stringify(file).length,
            text: async () => JSON.stringify(file),
          },
        ],
      });
      input.dispatchEvent(new window.Event('change', { bubbles: true }));
      await settled();
    },
    heading: () => root.querySelector('#section-heading')?.textContent,
  };
}

(async () => {
  const http = session();
  await register(http);
  const projectResponse = await http(
    '/projects',
    form({
      name: `Template QA ${randomUUID()}`,
      streetAddress: '123 Test St',
      city: 'Test',
      state: 'OH',
      zipCode: '45040',
    })
  );
  const projectHtml = await projectResponse.text();
  const projectID = projectHtml.match(/\/projects\/([A-Fa-f0-9-]{36})/)?.[1];
  assert(projectID, 'New project should be linked');
  const base = `/projects/${projectID}/effective-lengths/guided`;
  const start = await http(`${base}/starter/supply`, { method: 'POST' });
  const html = await start.text(),
    data = payload(html);
  assert(
    new JSDOM(html).window.document.querySelector('[data-theme="dark"]'),
    'Workspace must inherit account theme'
  );
  const race = await mount(html, http);
  await race.click('choose', '[data-id="1B"]');
  await race.click('skip');
  await race.click('choose', '[data-id="4Q"]');
  const quantity = race.root.querySelector('[data-quantity="8A-4-or-5-piece"]');
  quantity.value = '2';
  quantity.dispatchEvent(new race.dom.window.Event('change', { bubbles: true }));
  // Mouse blur starts this update before Done's click. Do not wait between them.
  await race.click('done');
  assert.equal(race.heading(), 'Transitions', 'Done must wait for the blur update and advance');
  await race.click('back');
  assert.equal(race.root.querySelector('[data-quantity="8A-4-or-5-piece"]').value, '2');
  assert.equal(race.root.querySelectorAll('[data-action="edit-row"]').length, 1);
  assert(race.root.querySelector('#step-fitting-rows').textContent.includes('40 ft'));
  race.dom.window.close();

  const ui = await mount(html, http);
  ui.root.querySelector('article summary').click();
  assert.equal(ui.heading(), 'Equipment connection', 'Reference details must not select a fitting');
  await ui.click('choose', '[data-id="1B"] img');
  assert.equal(ui.heading(), 'Supply trunk branch takeoff');
  assert.equal(ui.dom.window.document.activeElement.id, 'section-heading');
  assert.equal(
    ui.root.querySelectorAll('dialog').length,
    0,
    'Resolved selections should not open a popup'
  );
  await ui.click('skip');
  assert.equal(ui.heading(), 'Boot');
  await ui.click('choose', '[data-id="4Q"]');
  assert.equal(ui.heading(), 'Elbows');
  await ui.set('[data-quantity="8A-4-or-5-piece"]', '1');
  await ui.set('[data-quantity="8A-3-piece-45"]', '2');
  assert.equal(ui.heading(), 'Elbows', 'Quantity input must not advance');
  await ui.click('quantity-details', '[data-id="8A-4-or-5-piece"]');
  await ui.set('[data-scope="details"][data-field="0"]', '');
  await ui.set('[data-detail-quantity]', '0');
  await ui.click('apply-details');
  await ui.set('[data-quantity="8A-4-or-5-piece"]', '1');
  assert(
    ui.root.querySelector('dialog'),
    'Cleared R/D must ask for input when quantity becomes positive'
  );
  assert.equal(
    ui.root.querySelector('[data-scope="details"][data-field="0"]').value,
    '',
    'Revisit must not restore R/D default'
  );
  await ui.set('[data-scope="details"][data-field="0"]', '1');
  await ui.click('apply-details');
  await ui.click('done');
  assert.equal(ui.heading(), 'Transitions');
  const skip = ui.root.querySelector('[data-action="skip"]');
  assert(skip.parentElement.querySelector('[data-action="back"]'));
  assert(skip.parentElement.querySelector('[data-action="done"]'));
  await ui.click('choose', '[data-id="12J"]');
  await ui.set('[data-scope="details"][data-field="0"]', '2:1');
  await ui.set('[data-scope="details"][data-field="1"]', '2');
  await ui.click('apply-details');
  await ui.click('choose', '[data-id="12S"]');
  assert.equal(ui.heading(), 'Transitions');
  await ui.click('edit-row');
  await ui.click('apply-details');
  assert.equal(ui.heading(), 'Transitions', 'Explicit row editing should stay in the section');
  assert.equal(ui.dom.window.document.activeElement.id, 'section-heading');
  assert.equal(ui.root.querySelector('[data-action="skip"]').textContent, 'Clear and skip');
  await ui.click('skip');
  await ui.click('back');
  assert.equal(
    ui.root.querySelectorAll('[data-action="edit-row"]').length,
    0,
    'Clear and skip must remove all section rows'
  );
  await ui.click('choose', '[data-id="12J"]');
  assert.equal(
    ui.root.querySelectorAll('dialog').length,
    0,
    'Previously supplied fitting inputs should be retained'
  );
  await ui.click('choose', '[data-id="12S"]');
  await ui.click('done');
  assert.equal(ui.heading(), 'Review path');
  await ui.click('browse');
  await ui.set('#browse-group', '8');
  await ui.click('extra', '[data-id="8A-3-piece-45"] img');
  await ui.click('visit', '[data-index="3"]');
  await ui.click('done');
  await ui.click('done');
  await ui.set('[data-path="name"]', 'QA supply');
  await ui.set('[data-path="straight"]', '10, 25');
  await ui.click('save-path');
  assert.equal(ui.redirects.at(-1), `/projects/${projectID}/effective-lengths`);
  const list = await (await http(ui.redirects.at(-1))).text();
  const listDocument = new JSDOM(list).window.document;
  assert.equal(listDocument.querySelector(`a[href="${base}"]`), null);
  const addURL = listDocument.querySelector('a[aria-label="Add equivalent length"]').getAttribute('href');
  const addPage = await (await http(addURL)).text();
  assert.equal(new JSDOM(addPage).window.document.querySelector(`#fitting-path button[data-template-url="${base}"]`)?.textContent, 'From template');
  const editURL = list.match(/\/projects\/[^" ]+\/guided\/edit\/[A-Fa-f0-9-]{36}/)?.[0];
  assert(editURL, 'Saved guided path should reopen in the guided editor');
  assert.equal(
    new JSDOM(list).window.document
      .querySelector(`a[href="${editURL}"]`)
      .closest('tr')
      .querySelector('dialog'),
    null,
    'Guided paths should not render an unused manual editor'
  );
  const saved = payload(await (await http(editURL)).text()).path;
  assert.equal(
    saved.groups.reduce((sum, g) => sum + g.value * g.quantity, 35),
    180
  );
  assert(
    saved.groups.some((g) => !g.stepID && g.calculation.fittingID === '8A-3-piece-45'),
    'Exception should survive section revisits and save'
  );
  assert.equal(saved.templateSnapshot.configuration.steps.length, 5);

  const returnHtml = await (await http(`${base}/starter/return`, { method: 'POST' })).text();
  const returns = await mount(returnHtml, http);
  await returns.click('choose', '[data-id="5A-round"]');
  await returns.click('choose', '[data-id="6F"]');
  await returns.click('done');
  await returns.click('choose', '[data-id="12T"]');
  await returns.click('done');
  await returns.set('[data-path="name"]', 'QA return');
  await returns.click('save-path');
  assert.equal(returns.redirects.at(-1), `/projects/${projectID}/effective-lengths`);

  const editorHtml = await (await http(`/path-templates/${data.template.id}`)).text();
  const editor = await mount(editorHtml, http),
    stale = await mount(editorHtml, http);
  assert.equal(editor.root.querySelector('#new-group').options.length, 8);
  await editor.set('#new-group', '3');
  await editor.click('add-step');
  await editor.set('[data-choice="3A"]', null, true);
  await editor.set('[data-step="behavior"]', 'chooseMultiple');
  await editor.set('[data-step="allowsSkipping"]', null, true);
  await editor.click('move-up', '[data-index="5"]');
  await editor.set('[data-config="name"]', 'Customized supply');
  await editor.click('try');
  await editor.click('choose', '[data-id="1B"]');
  await editor.click('choose', '[data-id="2O"]');
  assert.equal(
    editor.root.querySelector('[data-field="count"]').value,
    '',
    'Branch count should start unanswered'
  );
  await editor.set('[data-field="count"]', '0');
  await editor.submitDetails();
  assert.equal(editor.heading(), 'Boot');
  await editor.click('exit-trial');
  assert.equal(editor.root.querySelector('[data-config="name"]').value, 'Customized supply');
  assert.equal(editor.redirects.length, 0, 'Try should not save the template or a project path');
  const sectionName = editor.root.querySelector('[data-step="title"]');
  const saveButton = editor.root.querySelector('[data-action="save-template"]');
  sectionName.value = 'Optional reducing takeoff';
  sectionName.dispatchEvent(new editor.dom.window.Event('change', { bubbles: true }));
  assert(saveButton.isConnected, 'Renaming a section must not replace the pending Save target');
  await editor.click('save-template');
  assert(editor.redirects.at(-1), 'Updated template should save');
  const updated = payload(await (await http(`/path-templates/${data.template.id}`)).text());
  assert.equal(updated.configuration.steps[4].group, 3);
  assert.equal(updated.configuration.steps[4].behavior, 'chooseMultiple');
  assert.equal(updated.configuration.steps[4].allowsSkipping, true);
  const unchanged = payload(await (await http(editURL)).text()).path;
  assert.deepEqual(unchanged, saved, 'Template edits must not affect saved paths');
  await stale.set('[data-config="name"]', 'Stale overwrite');
  await stale.click('save-template');
  assert(stale.root.textContent.includes('changed in another tab'));
  assert.equal(stale.redirects.length, 0);
  assert.equal(stale.root.querySelector('[data-config="name"]').value, 'Stale overwrite');

  const other = session();
  await register(other, 'light');
  const forbidden = await (await other(`/path-templates/${data.template.id}`)).text();
  assert(new JSDOM(forbidden).window.document.querySelector('[data-workspace-error]'));
  assert(!forbidden.includes('Customized supply'));
  const transfer = {
    format: 'duct-calc-path-template',
    version: 1,
    name: data.configuration.name,
    type: data.configuration.type,
    steps: data.configuration.steps.map(({ id, ...section }) => section),
  };
  const importer = await mount(await (await other('/path-templates/import')).text(), other);
  await importer.upload({ ...transfer, version: 99 });
  assert(importer.root.textContent.includes('version is not supported'));
  assert.equal(importer.root.querySelector('[data-action="import-template"]'), null);
  const missing = structuredClone(transfer);
  missing.steps[0].choices[0].fittingID = 'missing-fitting';
  await importer.upload(missing);
  assert(importer.root.textContent.includes('missing-fitting is missing or incompatible'));
  const invalid = structuredClone(transfer);
  invalid.steps[0].choices[0].defaults = { downstreamBranches: { _0: 0 } };
  await importer.upload(invalid);
  assert(importer.root.textContent.includes('defaults for 1A are no longer supported'));
  await importer.upload({ format: transfer.format, version: 1 });
  assert(importer.root.textContent.includes('not a supported template file'));
  await importer.upload(transfer);
  assert(importer.root.querySelector('[data-action="import-template"]'));
  assert.equal(importer.redirects.length, 0, 'Preview must not save');
  await importer.click('import-template');
  const imported = payload(await (await other(importer.redirects.at(-1))).text()).template;
  assert.notEqual(imported.id, data.template.id);
  assert.notEqual(imported.userID, data.template.userID);
  assert.notEqual(imported.revision, data.template.revision);
  assert.deepEqual(
    imported.configuration.steps.map(({ id, ...section }) => section),
    transfer.steps
  );
  assert(
    imported.configuration.steps.every(
      (s) => !data.configuration.steps.some((old) => old.id === s.id)
    )
  );
  const large = {
    ...transfer,
    steps: Array.from({ length: 50 }, (_, index) => ({
      title: `Elbows ${index}`,
      group: 8,
      behavior: 'chooseMultiple',
      allowsSkipping: true,
      choices: data.definitions
        .filter((d) => d.group === 8)
        .map((d) => ({ fittingID: d.id, defaults: null })),
    })),
  };
  const largeBody = JSON.stringify(large);
  assert(largeBody.length > 16384, 'Exercise templates larger than the default request limit');
  const largePreview = await other('/path-templates/import-preview', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: largeBody,
  });
  assert.equal(largePreview.status, 200);
  const largeNode = new JSDOM(await largePreview.text()).window.document.querySelector(
    '#import-preview-data'
  );
  assert(largeNode, 'Large valid templates must preview without losing choices');
  const largeConfiguration = JSON.parse(largeNode.textContent);
  assert.equal(largeConfiguration.steps.length, 50);
  const largeSave = await other('/path-templates', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ configuration: largeConfiguration }),
  });
  const largeURL = new JSDOM(await largeSave.text()).window.document.querySelector(
    '[data-redirect]'
  )?.dataset.redirect;
  assert(largeURL, 'Large import must save');
  // Navigate away before large HTML responses finish. Every stream must terminate
  // cleanly even when its client disconnects, rather than asserting in Vapor.
  await Promise.all(
    Array.from({ length: 12 }, async () => {
      const controller = new AbortController();
      const response = await other(largeURL, { signal: controller.signal });
      assert.equal(response.status, 200);
      const reader = response.body.getReader();
      await reader.read();
      controller.abort();
      await reader.cancel().catch(() => {});
    })
  );
  await sleep(100);
  const afterDisconnect = await other('/path-templates', { signal: AbortSignal.timeout(5000) });
  assert.equal(afterDisconnect.status, 200, 'Server must survive interrupted HTML streams');
  assert((await afterDisconnect.text()).includes('Path templates'));
  const tooLarge = await other('/path-templates/import-preview', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: ' '.repeat(1024 * 1024) + largeBody,
  });
  assert.equal(tooLarge.status, 413, 'Uploads over 1 MB must be rejected');
  const denied = await (await other(`/path-templates?project=${projectID}`)).text();
  assert(new JSDOM(denied).window.document.querySelector('[data-workspace-error]'));
  const contextual = await (await http(`/path-templates?project=${projectID}`)).text();
  assert(
    new JSDOM(contextual).window.document.querySelector(
      `a[href="/projects/${projectID}/effective-lengths"]`
    )
  );
  for (const fixture of [ui, returns, editor, stale, importer]) fixture.dom.window.close();
  console.log(
    'Production UI checks passed: supply/return save, theme inheritance, default clearing, auto-advance, bottom Skip, all-group configuration, snapshot independence, stale revisions, independent JSON imports, import validation, project return links, ownership, and interrupted page responses.'
  );
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
