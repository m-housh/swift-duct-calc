const assert = require('node:assert/strict');
const fs = require('node:fs');
const { test } = require('node:test');
const { JSDOM } = require('jsdom');
const scripts = ['Public/js/file-import.js', 'Public/js/project-import.js'].map(path => fs.readFileSync(path, 'utf8'));
const snapshots = {
  project: fs.readFileSync('Tests/ViewControllerTests/__Snapshots__/ProjectWorkspaceTests/emptyProjectDirectoryAndSearch.1.html', 'utf8'),
  rooms: fs.readFileSync('Tests/ViewControllerTests/__Snapshots__/ViewControllerTests/projectDetail.2.html', 'utf8'),
};

function setup(t, page, selector) {
  const dom = new JSDOM(snapshots[page], { runScripts: 'outside-only', pretendToBeVisual: true });
  t.after(() => dom.window.close());
  const { window } = dom;
  const doc = window.document;
  window.DataTransfer = class {
    constructor() { this.files = []; this.items = { add: file => this.files.push(file) }; }
  };
  for (const script of scripts) window.eval(script);
  const form = doc.querySelector(selector);
  const input = form.querySelector('input[type=file]');
  let files = [];
  Object.defineProperty(input, 'files', { get: () => files, set: value => { files = value; } });
  const part = name => form.querySelector(`[data-${name}]`);
  const when = state => form.querySelector(`[data-import-when="${state}"]`);
  const file = (name = 'ExampleHouse_ManJ.pdf', size = 600_000, type = 'application/pdf') =>
    new window.File([new Uint8Array(size)], name, { type });
  const pick = chosen => {
    files = [chosen];
    input.dispatchEvent(new window.Event('change', { bubbles: true }));
  };
  const htmx = (name, detail) => {
    const event = new window.CustomEvent(name, { bubbles: true, cancelable: true, detail: { elt: form, ...detail } });
    form.dispatchEvent(event);
    return event;
  };
  const respond = html => htmx('htmx:beforeOnLoad', { xhr: { status: 200, responseText: html } });
  const alert = () => form.querySelector(':scope > [role=alert]');
  return { window, doc, form, input, part, when, file, pick, htmx, respond, alert };
}
const projectPage = t => setup(t, 'project', '[data-project-import]');
const roomsPage = t => setup(t, 'rooms', '#uploadRooms [data-file-import]');

test('project tabs switch between import and manual entry with the keyboard', t => {
  const { window, doc } = projectPage(t);
  const importTab = doc.getElementById('projectImportTab');
  const manualTab = doc.getElementById('projectManualTab');
  assert.equal(doc.getElementById('projectDetailsForm').hidden, true);
  manualTab.click();
  assert.equal(manualTab.getAttribute('aria-selected'), 'true');
  assert.equal(doc.getElementById('projectDetailsForm').hidden, false);
  assert.equal(doc.getElementById('projectImportPanel').hidden, true);
  manualTab.dispatchEvent(new window.KeyboardEvent('keydown', { key: 'ArrowLeft', bubbles: true }));
  assert.equal(doc.activeElement, importTab);
  assert.equal(importTab.tabIndex, 0);
  assert.equal(manualTab.tabIndex, -1);
  assert.equal(doc.getElementById('projectImportPanel').hidden, false);
});

test('a chosen report replaces the drop zone; other files are rejected', t => {
  const { part, when, file, pick, alert } = projectPage(t);
  pick(file('notes.txt', 20, 'text/plain'));
  assert.equal(part('import-dropzone').hidden, false);
  assert.match(alert().textContent, /can't be imported here\. Choose a Cool Calc MJ8 report PDF/);
  pick(file('huge.pdf', 11 * 1024 * 1024));
  assert.match(alert().textContent, /smaller than 10 MB/);
  pick(file());
  assert.equal(alert().hidden, true);
  assert.equal(part('import-dropzone').hidden, true);
  assert.equal(part('import-file-name').textContent, 'ExampleHouse_ManJ.pdf');
  assert.equal(part('import-file-size').textContent, '586 KB');
  assert.equal(when('chosen missing-zip').hidden, false);
  part('import-remove').click();
  assert.equal(part('import-dropzone').hidden, false);
  assert.equal(when('chosen missing-zip').hidden, true);
});

test('dropping a report onto the drop zone chooses it', t => {
  const { window, input, part, file } = projectPage(t);
  const drop = new window.Event('drop', { bubbles: true, cancelable: true });
  drop.dataTransfer = { files: [file('dropped.pdf')] };
  part('import-dropzone').dispatchEvent(drop);
  assert(drop.defaultPrevented);
  assert.equal(input.files[0].name, 'dropped.pdf');
  assert.equal(part('import-file-name').textContent, 'dropped.pdf');
});

test('upload shows progress, then a failed request returns to the previous step', t => {
  const { window, part, when, file, pick, htmx } = projectPage(t);
  pick(file());
  htmx('htmx:beforeRequest', {});
  assert.equal(part('import-progress').hidden, false);
  assert.equal(when('chosen missing-zip').hidden, true);
  assert(part('import-remove').hidden);
  const upload = new window.EventTarget();
  htmx('htmx:beforeSend', { xhr: { upload } });
  upload.dispatchEvent(Object.assign(new window.Event('progress'), { lengthComputable: true, loaded: 1, total: 4 }));
  assert.equal(part('import-progress-value').textContent, '25%');
  upload.dispatchEvent(new window.Event('load'));
  assert.equal(part('import-progress-label').textContent, 'Reading project and room loads…');
  htmx('htmx:afterRequest', { successful: false });
  assert.equal(part('import-progress').hidden, true);
  assert.equal(when('chosen missing-zip').hidden, false);
  assert.equal(part('import-remove').hidden, false);
});

test('a missing ZIP code is requested and kept when a duplicate is cancelled', t => {
  const { form, part, when, file, pick, htmx, respond } = projectPage(t);
  pick(file());
  htmx('htmx:beforeRequest', {});
  assert(respond('<p data-project-import-missing-zip>Enter the ZIP code.</p>').defaultPrevented);
  htmx('htmx:afterRequest', {});
  const zip = form.elements.namedItem('zipCode');
  assert.equal(when('missing-zip').hidden, false);
  assert.equal(part('zip-message').textContent, 'Enter the ZIP code.');
  assert.equal(zip.disabled, false);
  assert.equal(zip.required, true);
  assert.equal(when('chosen missing-zip').hidden, false);
  zip.value = '12345';
  respond('<div data-project-import-conflict data-suggested-name="Example House (2)"><p>Possible duplicate project</p></div>');
  form.querySelector('[data-import-cancel]').click();
  assert.equal(zip.value, '12345');
  assert.equal(zip.disabled, false);
  pick(file('another.pdf'));
  assert.equal(zip.value, '');
  assert.equal(zip.disabled, true);
});

test('a possible duplicate offers a suggested name that can be changed', t => {
  const { doc, form, part, when, file, pick, htmx, respond } = projectPage(t);
  pick(file());
  htmx('htmx:beforeRequest', {});
  const event = respond('<div data-project-import-conflict data-suggested-name="Example House (2)"><p>Possible duplicate project</p></div>');
  htmx('htmx:afterRequest', {});
  assert(event.defaultPrevented);
  const name = form.elements.namedItem('name');
  assert.equal(when('duplicate').hidden, false);
  assert.match(part('duplicate-details').textContent, /Possible duplicate project/);
  assert.equal(when('chosen missing-zip').hidden, true);
  assert.equal(name.value, 'Example House (2)');
  assert.equal(name.disabled, false);
  assert.equal(name.required, true);
  assert.equal(doc.activeElement, name);
  assert.equal(form.elements.namedItem('confirmDuplicate').value, 'true');
  // A failed request keeps the step and the decision.
  htmx('htmx:beforeRequest', {});
  htmx('htmx:afterRequest', { successful: false });
  assert.equal(when('duplicate').hidden, false);
  assert.equal(form.elements.namedItem('confirmDuplicate').value, 'true');
  form.querySelector('[data-import-cancel]').click();
  assert.equal(when('duplicate').hidden, true);
  assert.equal(when('chosen missing-zip').hidden, false);
  assert.equal(name.disabled, true);
  assert.equal(form.elements.namedItem('confirmDuplicate').value, 'false');
});

test('successful project pages are left for HTMX to swap in', t => {
  const { file, pick, respond } = projectPage(t);
  pick(file());
  assert.equal(respond('<main>Rooms</main>').defaultPrevented, false);
});

test('room imports accept a CSV or a report and post each to its own route', t => {
  const { form, part, when, file, pick, htmx, alert } = roomsPage(t);
  const [csvNote, pdfNote] = ['csv', 'pdf'].map(format => form.querySelector(`[data-import-format="${format}"]`));
  pick(file('notes.txt', 20, 'text/plain'));
  assert.match(alert().textContent, /Choose a room-load CSV or Cool Calc MJ8 report PDF/);
  const path = () => htmx('htmx:configRequest', { path: form.getAttribute('hx-post') }).detail.path;

  pick(file('rooms.csv', 200, 'text/csv'));
  assert.equal(when('chosen').hidden, false);
  assert.equal(csvNote.hidden, false);
  assert.equal(pdfNote.hidden, true);
  assert.match(path(), /\/rooms\/csv$/);

  pick(file('Report.PDF'));
  assert.equal(csvNote.hidden, true);
  assert.equal(pdfNote.hidden, false);
  assert.match(path(), /\/rooms\/pdf$/);
  assert.equal(part('import-file-name').textContent, 'Report.PDF');
});
