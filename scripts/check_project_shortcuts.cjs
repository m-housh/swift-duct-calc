const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');
const { JSDOM } = require('jsdom');

const root = path.resolve(__dirname, '..');
const script = fs.readFileSync(path.join(root, 'Public/js/main.js'), 'utf8');
const snapshot = number => fs.readFileSync(path.join(root,
  `Tests/ViewControllerTests/__Snapshots__/ViewControllerTests/projectDetail.${number}.html`), 'utf8');

function setup(t, html = snapshot(1)) {
  const dom = new JSDOM(html, { runScripts: 'outside-only' });
  t.after(() => dom.window.close());
  dom.window.eval(script);
  const { document, KeyboardEvent } = dom.window;
  const clicks = [];
  document.addEventListener('click', event => {
    const control = event.target.closest('#project-sidebar a, nav a[aria-keyshortcuts]');
    if (control) {
      clicks.push(control.getAttribute('hx-get') || control.getAttribute('href'));
      event.preventDefault();
    }
  });
  const press = (key = '2', options = {}, target = document.body) => {
    const event = new KeyboardEvent('keydown', {
      key, ctrlKey: true, altKey: true, bubbles: true, cancelable: true, composed: true, ...options,
    });
    target.dispatchEvent(event);
    return event;
  };
  return { dom, document, clicks, press };
}

test('all six project pages expose the correct shortcuts and use the navigation links', t => {
  const titles = ['Project', 'Rooms', 'Equipment', 'Total effective length', 'Friction rate', 'Duct sizes'];
  for (let page = 1; page <= 6; page++) {
    const { document, clicks, press } = setup(t, snapshot(page));
    const buttons = [...document.querySelectorAll('#project-sidebar a')];
    assert.equal(buttons.length, 6);
    buttons.forEach((button, index) => {
      const key = String(index + 1);
      assert.equal(button.querySelector('span').textContent, titles[index]);
      assert.equal(button.getAttribute('title'), `${titles[index]}, Ctrl+Alt+${key}`);
      assert.equal(button.getAttribute('aria-keyshortcuts'), `Control+Alt+${key}`);
      assert(button.getAttribute('href').startsWith('/projects/'));
      const before = clicks.length;
      assert(press(key).defaultPrevented);
      if (button.getAttribute('aria-current') === 'page') assert.equal(clicks.length, before);
      else assert.equal(clicks.at(-1), button.getAttribute('href'));
    });
  }
});

test('plain keys, browser shortcuts, extra modifiers, repeats, composition and AltGraph pass through', t => {
  const { document, clicks, press } = setup(t);
  for (const options of [
    { ctrlKey: false, altKey: false }, { ctrlKey: false }, { altKey: false },
    { metaKey: true }, { repeat: true }, { isComposing: true },
    { modifierAltGraph: true },
  ]) {
    for (const key of ['2', 'j', 'k', 'd', 'f', 'p', 'u', '/']) assert.equal(press(key, options).defaultPrevented, false);
  }
  for (const key of ['0', '7', 'g', 'F1']) assert.equal(press(key).defaultPrevented, false);
  for (const key of ['2', 'j', 'k', 'd', 'f', 'p', 'u']) {
    assert.equal(press(key, { shiftKey: true }).defaultPrevented, false);
  }
  document.body.addEventListener('keydown', event => event.preventDefault(), { once: true });
  press();
  assert.deepEqual(clicks, []);
});

test('J and K no longer navigate between sections', t => {
  const { clicks, press } = setup(t, snapshot(1));
  for (const key of ['j', 'k', 'J', 'K']) assert.equal(press(key).defaultPrevented, false);
  assert.deepEqual(clicks, []);
});

test('form controls, editable descendants and shadow DOM editors keep their keystrokes', t => {
  const { document, clicks, press } = setup(t);
  for (const html of [
    '<input>', '<textarea></textarea>', '<select><option>One</option></select>',
    '<div contenteditable><span>Draft</span></div>',
    '<div contenteditable="plaintext-only"><span>Draft</span></div>',
    '<div role="textbox"><span>Draft</span></div>',
    '<div role="combobox" tabindex="0"></div>', '<div role="spinbutton" tabindex="0"></div>',
  ]) {
    const wrapper = document.createElement('div');
    wrapper.innerHTML = html;
    document.body.append(wrapper);
    for (const key of ['2', 'j', 'k', 'd', 'f', 'p', 'u', '/']) {
      assert.equal(press(key, {}, wrapper.querySelector('span') || wrapper.firstChild).defaultPrevented, false);
    }
    wrapper.remove();
  }
  const host = document.createElement('div');
  document.body.append(host);
  const shadow = host.attachShadow({ mode: 'open' });
  shadow.innerHTML = '<input>';
  assert.equal(press('2', {}, shadow.firstChild).defaultPrevented, false);
  assert.deepEqual(clicks, []);
});

test('open dialogs prevent navigation even when focus is outside them', t => {
  const { document, clicks, press } = setup(t);
  const dialog = document.createElement('dialog');
  document.body.append(dialog);
  dialog.setAttribute('open', '');
  for (const key of ['2', 'j', 'k', 'd', 'f', 'p', 'u', '/']) assert.equal(press(key).defaultPrevented, false);
  dialog.remove();
  const customDialog = document.createElement('div');
  customDialog.setAttribute('role', 'dialog');
  customDialog.setAttribute('aria-modal', 'true');
  document.body.append(customDialog);
  for (const key of ['2', 'j', 'k', 'd', 'f', 'p', 'u', '/']) assert.equal(press(key).defaultPrevented, false);
  assert.deepEqual(clicks, []);
});

test('tool shortcuts activate the navbar links with their existing tab behavior', t => {
  const { document, clicks, press } = setup(t);
  for (const [key, name, href, target] of [
    ['d', 'Ductulator', '/ductulator', '_blank'], ['f', 'Fitting reference', '/fittings', '_blank'],
  ]) {
    const link = document.querySelector(`nav a[aria-keyshortcuts="Control+Alt+${key.toUpperCase()}"]`);
    assert.equal(link.getAttribute('href'), href);
    assert.equal(link.getAttribute('target'), target);
    assert.equal(link.getAttribute('title'), `${name}, Ctrl+Alt+${key.toUpperCase()}`);
    assert(press(key).defaultPrevented);
    assert.equal(clicks.at(-1), href);
    assert(press(key.toUpperCase()).defaultPrevented);
    assert.equal(clicks.at(-1), href);
  }
  document.querySelector('#project-sidebar').remove();
  assert(press('d').defaultPrevented, 'Tools work outside project pages');
  assert.equal(clicks.at(-1), '/ductulator');
  document.querySelector('nav a[aria-keyshortcuts="Control+Alt+D"]').remove();
  assert.equal(press('d').defaultPrevented, false, 'Absent tools do not consume shortcuts');
  assert.equal(press('j').defaultPrevented, false);
});

test('disabled or inert navigation does not consume shortcuts', t => {
  const { document, clicks, press } = setup(t);
  const sidebar = document.querySelector('#project-sidebar');
  sidebar.setAttribute('inert', '');
  assert.equal(press().defaultPrevented, false);
  sidebar.removeAttribute('inert');
  sidebar.querySelector('[aria-keyshortcuts="Control+Alt+2"]').setAttribute('aria-disabled', 'true');
  assert.equal(press().defaultPrevented, false);
  assert.deepEqual(clicks, []);
});

test('Projects and Profile shortcuts use the account links in the current tab', t => {
  const { document, clicks, press } = setup(t);
  document.querySelector('#project-sidebar').remove();
  for (const [key, title, href] of [['p', 'Projects', '/projects'], ['u', 'Profile', '/profile']]) {
    const link = document.querySelector(`nav a[aria-keyshortcuts="Control+Alt+${key.toUpperCase()}"]`);
    assert.equal(link.querySelector('span').textContent, title);
    assert.equal(link.querySelector('.text-xs').textContent, `Ctrl+Alt+${key.toUpperCase()}`);
    assert.equal(link.getAttribute('href'), href);
    assert.equal(link.getAttribute('target'), null);
    for (const letter of [key, key.toUpperCase()]) {
      assert(press(letter).defaultPrevented);
      assert.equal(clicks.at(-1), href);
    }
    link.remove();
    assert.equal(press(key).defaultPrevented, false, 'Unavailable account links do not consume shortcuts');
  }
});

test('Profile has a Projects logo link and working account shortcuts; signed-out pages do not', t => {
  for (const name of ['userProfile', 'ductulator']) {
    const html = fs.readFileSync(path.join(root,
      `Tests/ViewControllerTests/__Snapshots__/ViewControllerTests/${name}.1.html`), 'utf8');
    const { document, clicks, press } = setup(t, html);
    const loggedIn = name === 'userProfile';
    assert.equal(document.querySelector('nav img').closest('a').getAttribute('href'), loggedIn ? '/projects' : '/');
    assert.equal(press('p').defaultPrevented, loggedIn);
    assert.equal(press('u').defaultPrevented, loggedIn);
    assert.deepEqual(clicks, loggedIn ? ['/projects', '/profile'] : []);
  }
});

test('every project page lists its shortcuts in an accessible help dialog', t => {
  for (let page = 1; page <= 6; page++) {
    const { document } = setup(t, snapshot(page));
    const dialog = document.querySelector('#projectShortcuts');
    assert(dialog);
    assert.equal(dialog.hasAttribute('open'), false);
    assert.equal(document.getElementById(dialog.getAttribute('aria-labelledby')).textContent, 'Keyboard shortcuts');
    const trigger = document.querySelector('nav button[aria-haspopup="dialog"][aria-controls="projectShortcuts"]');
    assert.equal(trigger.getAttribute('aria-label'), 'Keyboard shortcuts');
    assert(trigger.querySelector('svg[aria-hidden="true"]'));
    assert.deepEqual([...dialog.querySelectorAll('caption')].map(node => node.textContent), ['Project sections', 'App navigation']);
    const expected = { J: 'Next room row', K: 'Previous room row' };
    for (const control of document.querySelectorAll('#project-sidebar [aria-keyshortcuts], nav a[aria-keyshortcuts]')) {
      const key = control.getAttribute('aria-keyshortcuts').split('+').at(-1);
      // The formatted snapshot renderer can hoist inline text; live browser tests check control names.
      expected[key] = (control.querySelector('span') || control).textContent.trim()
        || control.getAttribute('title').split(',')[0];
    }
    const listed = Object.fromEntries([...dialog.querySelectorAll('tr')].map(row => [
      row.querySelector('kbd').textContent.trim(), row.querySelector('th').textContent.trim(),
    ]));
    assert.deepEqual(listed, expected);
  }
});

test('help shortcuts open the current dialog after body replacement and restore the opener on close', t => {
  const { dom, document, press } = setup(t);
  const fixtures = [
    ...Array.from({ length: 6 }, (_, index) => snapshot(index + 1)),
    ...['allGroupsGuest', 'returnGroupSignedIn'].map(name => fs.readFileSync(path.join(root,
      `Tests/ViewControllerTests/__Snapshots__/FittingsSnapshotTests/${name}.1.html`), 'utf8')),
  ];
  for (const html of fixtures) {
    document.body.outerHTML = new dom.window.DOMParser().parseFromString(html, 'text/html').body.outerHTML;
    dom.window.eval(script);
    const trigger = document.querySelector('nav button[data-open-dialog]');
    const dialog = document.getElementById(trigger.dataset.openDialog);
    assert.equal(trigger.getAttribute('aria-keyshortcuts'), 'Control+Alt+/ Control+Alt+Shift+/');
    assert.match(trigger.title, /Ctrl\+Alt\+\?/);
    assert.match(dialog.textContent, /Ctrl\+Alt\+\? or Ctrl\+Alt\+\//);
    let opens = 0;
    dialog.showModal = () => { opens++; dialog.setAttribute('open', ''); };
    trigger.getClientRects = () => [{}];
    for (const [key, options] of [['/', {}], ['/', { shiftKey: true }], ['?', { shiftKey: true }], ['?', {}]]) {
      const before = opens;
      assert.equal(press(key, options).defaultPrevented, true);
      assert.equal(opens, before + 1, 'The existing dialog opener runs exactly once');
      assert.equal(press(key, options).defaultPrevented, false, 'An open dialog pauses help');
      dialog.removeAttribute('open');
      dialog.dispatchEvent(new dom.window.Event('close'));
      assert.equal(document.activeElement, trigger);
    }
    for (const attribute of ['disabled', 'inert', 'aria-disabled']) {
      trigger.setAttribute(attribute, 'true');
      assert.equal(press('/').defaultPrevented, false);
      trigger.removeAttribute(attribute);
    }
  }
  document.body.outerHTML = '<body><main>No shortcut help on this page</main></body>';
  assert.equal(press('/').defaultPrevented, false);
  assert.equal(press('?', { shiftKey: true }).defaultPrevented, false);
});

test('shifted help respects modifiers, editors and canceled events', t => {
  const { document, press } = setup(t);
  for (const options of [
    { ctrlKey: false }, { altKey: false }, { metaKey: true },
    { repeat: true }, { isComposing: true }, { modifierAltGraph: true },
  ]) assert.equal(press('?', { shiftKey: true, ...options }).defaultPrevented, false);
  const input = document.createElement('input');
  document.body.append(input);
  assert.equal(press('?', { shiftKey: true }, input).defaultPrevented, false);
  const dialog = document.querySelector('#projectShortcuts');
  let opens = 0;
  dialog.showModal = () => { opens++; };
  document.body.addEventListener('keydown', event => event.preventDefault(), { once: true });
  press('?', { shiftKey: true });
  assert.equal(opens, 0);
});

test('body replacement and history restoration use the current project without duplicate clicks', t => {
  const { dom, document, clicks, press } = setup(t);
  const originalBody = document.body.outerHTML;
  press();
  const originalURL = clicks[0];
  document.body.outerHTML = originalBody.replaceAll('00000000-0000-0000-0000-000000000000', 'another-project');
  document.body.dispatchEvent(new dom.window.Event('htmx:load', { bubbles: true }));
  dom.window.eval(script);
  press();
  assert.equal(clicks.length, 2);
  assert.equal(clicks[1], originalURL.replace('00000000-0000-0000-0000-000000000000', 'another-project'));
  document.body.outerHTML = '<body><main>Projects</main></body>';
  assert.equal(press().defaultPrevented, false);
  document.body.outerHTML = originalBody;
  document.body.dispatchEvent(new dom.window.Event('htmx:historyRestore', { bubbles: true }));
  press();
  assert.deepEqual(clicks, [originalURL, clicks[1], originalURL]);
});
