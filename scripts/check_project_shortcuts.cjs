const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');
const { JSDOM } = require('jsdom');

const root = path.resolve(__dirname, '..');
const bindings = require('./keybinding_test_helpers.cjs');
const script = bindings.script(fs.readFileSync(path.join(root, 'Public/js/main.js'), 'utf8'));
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
    const sections = [...dialog.querySelectorAll(':scope > .modal-box > table')];
    const titles = ['Project', 'Rooms', 'Equipment', 'Total effective length', 'Friction rate', 'Duct sizes'];
    assert.deepEqual(sections.map(table => table.querySelector('caption').textContent),
      ['On this page · ' + titles[page - 1], 'Project navigation', 'App navigation']);
    const actions = [
      ['Project details'],
      ['Add room', 'Import loads', 'Find a room', 'Next room row', 'Previous room row'],
      ['Edit all', 'Heating airflow', 'Cooling airflow', 'Static pressure'],
      ['Add return', 'Add supply', 'Add path'], ['Use template'], ['Add trunk', 'Export PDF', 'Find a register'],
    ];
    assert.deepEqual([...sections[0].querySelectorAll('th')].map(th => th.textContent), actions[page - 1]);
    const other = dialog.querySelector('details');
    assert.equal(other.open, false);
    assert.equal(other.querySelector('summary').textContent, 'Other project pages');
    assert.deepEqual([...other.querySelectorAll('caption')].map(caption => caption.textContent), titles.filter((_, index) => index !== page - 1));
    assert(!dialog.textContent.includes('Current step action'));
    const keybindings = JSON.parse(document.querySelector('[data-keybindings]').dataset.keybindings);
    for (const keycaps of dialog.querySelectorAll('.keycaps')) {
      const chord = [...keycaps.querySelectorAll('kbd')].map(key => key.textContent.trim()).join('+').replace('Ctrl', 'Control');
      assert(Object.values(keybindings).includes(chord), chord);
    }

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
    assert.equal(trigger.getAttribute('aria-keyshortcuts'), 'Control+Alt+Shift+/');
    assert.match(trigger.title, /Ctrl\+Alt\+Shift\+\//);
    assert.match(dialog.textContent, /Ctrl\+Alt\+\//);
    let opens = 0;
    dialog.showModal = () => { opens++; dialog.setAttribute('open', ''); };
    trigger.getClientRects = () => [{}];
    for (const [key, options] of [['/', { shiftKey: true }], ['?', { shiftKey: true }]]) {
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
      assert.equal(press('/', {shiftKey:true}).defaultPrevented, false);
      trigger.removeAttribute(attribute);
    }
  }
  document.body.outerHTML = '<body><main>No shortcut help on this page</main></body>';
  assert.equal(press('/', {shiftKey:true}).defaultPrevented, false);
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

test('template shortcuts apply only in the chooser and preserve navigation elsewhere', t => {
  const { document, clicks, press } = setup(t, snapshot(5));
  const dialog = document.getElementById('frictionRateTemplates');
  const applied = [];
  dialog.addEventListener('click', event => {
    const button = event.target.closest('button[aria-keyshortcuts]');
    if (!button) return;
    applied.push(button.closest('form').getAttribute('hx-post').split('/').at(-1));
    event.preventDefault();
  });
  for (const [key, template] of [['d', 'shared'], ['f', 'furnace'], ['a', 'air-handler']]) {
    dialog.setAttribute('open', '');
    assert(press(key).defaultPrevented);
    assert.equal(applied.at(-1), template);
    assert(press(key.toUpperCase()).defaultPrevented);
    assert.equal(applied.at(-1), template);
    assert.deepEqual(clicks, []);
  }
  dialog.removeAttribute('open');
  assert(press('d').defaultPrevented);
  assert.equal(clicks.at(-1), '/ductulator');
  assert(press('f').defaultPrevented);
  assert.equal(clicks.at(-1), '/fittings');
  dialog.showModal = () => { dialog.open = true; };
  assert(press('a').defaultPrevented);
  assert(dialog.open, 'The current step action opens the template chooser');
  assert.equal(applied.length, 6);
});

test('template shortcuts respect editing, modifiers, unavailable controls and other dialogs', t => {
  const { document, clicks, press } = setup(t, snapshot(5));
  const dialog = document.getElementById('frictionRateTemplates');
  dialog.setAttribute('open', '');
  let applied = 0;
  dialog.addEventListener('click', event => { applied++; event.preventDefault(); });
  for (const options of [
    { ctrlKey: false }, { altKey: false }, { metaKey: true }, { shiftKey: true },
    { repeat: true }, { isComposing: true }, { modifierAltGraph: true },
  ]) {
    for (const key of ['d', 'f', 'a']) assert.equal(press(key, options).defaultPrevented, false);
  }
  const input = document.createElement('input');
  dialog.append(input);
  assert.equal(press('d', {}, input).defaultPrevented, false);
  input.remove();
  const button = dialog.querySelector('[aria-keyshortcuts="Control+Alt+D"]');
  button.disabled = true;
  assert.equal(press('d').defaultPrevented, false);
  button.disabled = false;
  dialog.setAttribute('inert', '');
  assert.equal(press('d').defaultPrevented, false);
  dialog.removeAttribute('inert');
  const other = document.createElement('dialog');
  other.setAttribute('open', '');
  document.body.append(other);
  assert.equal(press('d').defaultPrevented, false);
  other.remove();
  document.body.addEventListener('keydown', event => event.preventDefault(), { once: true });
  press('d');
  assert.equal(applied, 0);
  assert.deepEqual(clicks, []);
});

test('template shortcuts resolve buttons after body replacement without duplicate handlers', t => {
  const { document, dom, press } = setup(t, snapshot(5));
  for (let replacement = 0; replacement < 2; replacement++) {
    document.body.innerHTML = snapshot(5);
    dom.window.eval(script);
    const dialog = document.getElementById('frictionRateTemplates');
    dialog.setAttribute('open', '');
    let applied = 0;
    dialog.addEventListener('click', event => { applied++; event.preventDefault(); });
    assert(press('a').defaultPrevented);
    assert.equal(applied, 1);
  }
});

test('equipment shortcuts open each editor, pause inside dialogs and survive body replacement', t => {
  const { dom, document, press } = setup(t, snapshot(3));
  assert.equal(press('e').defaultPrevented, false);
  assert.equal(document.querySelector('[data-project-primary]').getAttribute('aria-keyshortcuts'), 'Control+Alt+A');
  dom.window.HTMLDialogElement.prototype.showModal = function () { this.open = true; };
  for (let pass = 0; pass < 2; pass++) {
    for (const [key, field] of [['h', 'heating'], ['c', 'cooling'], ['s', 'pressure'], ['a', 'all']]) {
      const dialog = document.getElementById(`equipmentForm-${field}`);
      assert(dialog);
      assert(press(key).defaultPrevented);
      assert(dialog.open);
      for (const other of ['h', 'c', 's', 'a']) assert.equal(press(other).defaultPrevented, false);
      dialog.open = false;
      for (const options of [{ctrlKey:false}, {altKey:false}, {shiftKey:true}, {metaKey:true},
        {repeat:true}, {isComposing:true}, {modifierAltGraph:true}]) {
        assert.equal(press(key, options).defaultPrevented, false);
      }
      assert.equal(press(key, {}, dialog.querySelector('input[type=number]')).defaultPrevented, false);
    }
    document.body.outerHTML = snapshot(3).match(/<body[\s\S]*<\/body>/)[0];
    dom.window.eval(script);
  }
  document.body.innerHTML = '<main>Another page</main>';
  for (const key of ['h', 'c', 's', 'a']) assert.equal(press(key).defaultPrevented, false);
});


test('individual bindings work after page replacement, including shifted number keys', t => {
  const { dom, document, press, clicks } = setup(t);
  for (const [action, combo, key, options] of [
    ['rooms', 'Control+Shift+2', '@', {altKey:false,shiftKey:true,code:'Digit2'}],
    ['ductulator', 'Alt+Meta+D', '∂', {ctrlKey:false,altKey:true,metaKey:true,code:'KeyD'}],
    ['projects', 'Alt+ArrowUp', 'ArrowUp', {ctrlKey:false}],
  ]) {
    document.body.outerHTML = new dom.window.DOMParser().parseFromString(snapshot(1), 'text/html').body.outerHTML;
    const root = document.querySelector('[data-keybindings]');
    root.dataset.keybindings = JSON.stringify({...bindings.defaults, [action]:combo});
    document.querySelector(`[aria-keyshortcuts="${bindings.defaults[action]}"]`).setAttribute('aria-keyshortcuts', combo);
    dom.window.eval(script);
    const before = clicks.length;
    assert(press(key, options).defaultPrevented);
    assert.equal(clicks.length, before + 1);
    assert.equal(press(key, {...options,repeat:true}).defaultPrevented, false);
  }
});

test('room navigation and search use their own bindings', t => {
  const { document, press } = setup(t, snapshot(2));
  document.querySelector('[data-keybindings]').dataset.keybindings = JSON.stringify({ ...bindings.defaults,
    nextRoom:'Alt+ArrowDown', previousRoom:'Alt+ArrowUp', search:'Control+Shift+F' });
  assert(press('ArrowDown', {ctrlKey:false}).defaultPrevented);
  assert(document.querySelector('[data-selectable-table="rooms"] .selected-row'));
  assert.equal(press('j').defaultPrevented, false);
  assert(press('F', {altKey:false,shiftKey:true}).defaultPrevented);
  assert.equal(document.activeElement.id, 'room-search');
});

test('app shortcuts work after Ctrl+K focuses search, while data entry fields keep their keys', t => {
  for (const name of ['userProfile', 'projectIndex']) {
    const html = fs.readFileSync(path.join(root,
      `Tests/ViewControllerTests/__Snapshots__/ViewControllerTests/${name}.1.html`), 'utf8');
    const { document, press, clicks } = setup(t, html);
    if (!document.getElementById('project-search')) {
      document.body.insertAdjacentHTML('beforeend', '<input id="keybinding-search" type="search">');
    }
    assert(press('k', {altKey:false}).defaultPrevented);
    const search = document.activeElement;
    assert.equal(search.type, 'search');
    search.value = 'Keep this query';
    assert(press('p', {}, search).defaultPrevented);
    assert.equal(clicks.at(-1), '/projects');
    assert.equal(search.value, 'Keep this query');
    assert.equal(press('p', {ctrlKey:false,altKey:false}, search).defaultPrevented, false);
    const input = document.createElement('input'); input.type = 'text'; document.body.append(input);
    assert.equal(press('p', {}, input).defaultPrevented, false);
  }
});

test('custom search and room navigation bindings work while a room search has focus', t => {
  const { document, press } = setup(t, snapshot(2));
  document.querySelector('[data-keybindings]').dataset.keybindings = JSON.stringify({ ...bindings.defaults,
    search:'Alt+K', nextRoom:'Alt+ArrowDown' });
  assert(press('k', {ctrlKey:false}).defaultPrevented);
  const search = document.activeElement;
  assert.equal(search.id, 'room-search');
  assert(press('ArrowDown', {ctrlKey:false}, search).defaultPrevented);
  assert(document.querySelector('[data-selectable-table="rooms"] .selected-row'));
});


test('next and previous steps follow the current sidebar and stop at its ends', t => {
  for (let page = 1; page <= 6; page++) {
    const { document, clicks, press } = setup(t, snapshot(page));
    const links = [...document.querySelectorAll('#project-sidebar a')];
    const current = links.findIndex(link => link.getAttribute('aria-current') === 'page');
    for (const [delta, options] of [[1, {}], [-1, {shiftKey:true}]]) {
      clicks.length = 0;
      const target = links[current + delta];
      assert.equal(press('Enter', options).defaultPrevented, !!target);
      assert.deepEqual(clicks, target ? [target.getAttribute('href')] : []);
    }
    const root = document.querySelector('[data-keybindings]');
    root.dataset.keybindings = JSON.stringify({...bindings.defaults, nextStep:'Alt+ArrowRight', previousStep:'Alt+ArrowLeft'});
    assert.equal(press('Enter').defaultPrevented, false);
    assert.equal(press('ArrowRight', {ctrlKey:false}).defaultPrevented, current < 5);
    assert.equal(press('ArrowLeft', {ctrlKey:false}).defaultPrevented, current > 0);
    const input = document.createElement('input'); document.body.append(input);
    assert.equal(press('ArrowRight', {ctrlKey:false}, input).defaultPrevented, false);
    document.querySelector('dialog').open = true;
    assert.equal(press('ArrowRight', {ctrlKey:false}).defaultPrevented, false);
  }
});

test('current step action opens the correct control once and respects guards and customization', t => {
  const titles = ['Project details', 'Add room', 'Edit all', 'Add path', 'Use template', 'Add trunk'];
  for (let page = 1; page <= 6; page++) {
    const { document, press, dom } = setup(t, snapshot(page));
    dom.window.HTMLDialogElement.prototype.showModal = function () { this.open = true; };
    const control = document.querySelector('#project-content [data-project-primary]');
    assert(control, titles[page - 1]);
    assert(control.title.startsWith(titles[page - 1]));
    assert(control.getAttribute('aria-keyshortcuts').split(' ').includes('Control+Alt+A'));
    let clicks = 0;
    control.addEventListener('click', event => { clicks++; event.preventDefault(); });
    assert(press('a').defaultPrevented);
    assert.equal(clicks, 1);
    if (control.dataset.openDialog) {
      assert(document.getElementById(control.dataset.openDialog).open);
      if (control.dataset.openDialog !== 'frictionRateTemplates') assert.equal(press('a').defaultPrevented, false);
      document.getElementById(control.dataset.openDialog).open = false;
    }
    document.querySelector('[data-keybindings]').dataset.keybindings = JSON.stringify({...bindings.defaults, primaryAction:'Alt+Enter'});
    control.setAttribute('aria-keyshortcuts', control.getAttribute('aria-keyshortcuts').replace('Control+Alt+A', 'Alt+Enter'));
    assert.equal(press('a').defaultPrevented, false);
    assert(press('Enter', {ctrlKey:false}).defaultPrevented);
    assert.equal(clicks, 2);
    document.querySelectorAll('dialog').forEach(dialog => { dialog.open = false; });
    for (const options of [{repeat:true}, {isComposing:true}, {modifierAltGraph:true}]) {
      assert.equal(press('Enter', {ctrlKey:false, ...options}).defaultPrevented, false);
    }
    const input = document.createElement('input'); document.body.append(input);
    assert.equal(press('Enter', {ctrlKey:false}, input).defaultPrevented, false);
    control.setAttribute('aria-disabled', 'true');
    assert.equal(press('Enter', {ctrlKey:false}).defaultPrevented, false);
  }
});

test('Add Project uses the primary action on populated, empty and searched directories', t => {
  const snapshots = [
    'ViewControllerTests/projectIndex.1',
    'ProjectWorkspaceTests/emptyProjectDirectoryAndSearch.1',
    'ProjectWorkspaceTests/emptyProjectDirectoryAndSearch.2',
  ];
  for (const name of snapshots) {
    const html = fs.readFileSync(path.join(root,
      `Tests/ViewControllerTests/__Snapshots__/${name}.html`), 'utf8');
    const { document, dom, press } = setup(t, html);
    dom.window.HTMLDialogElement.prototype.showModal = function () { this.open = true; };
    const button = document.querySelector('.project-directory [data-project-primary]');
    const dialog = document.getElementById('projectForm');
    assert.equal(button.getAttribute('aria-keyshortcuts'), 'Control+Alt+A');
    assert.equal(button.title, 'Add Project, Ctrl+Alt+A');
    assert(press('a').defaultPrevented);
    assert(dialog.open);
    assert.equal(press('a').defaultPrevented, false);
    dialog.open = false;
    assert(press('a', {}, document.getElementById('project-search')).defaultPrevented);
    assert(dialog.open);
    dialog.open = false;
    for (const options of [{ctrlKey:false}, {altKey:false}, {shiftKey:true}, {repeat:true}, {isComposing:true}, {modifierAltGraph:true}]) {
      assert.equal(press('a', options).defaultPrevented, false);
    }
    const input = document.createElement('input'); document.body.append(input);
    assert.equal(press('a', {}, input).defaultPrevented, false);
    button.disabled = true;
    assert.equal(press('a').defaultPrevented, false);
    button.disabled = false;
    document.querySelector('[data-keybindings]').dataset.keybindings = JSON.stringify({...bindings.defaults, primaryAction:'Alt+Enter'});
    button.setAttribute('aria-keyshortcuts', 'Alt+Enter');
    assert.equal(press('a').defaultPrevented, false);
    assert(press('Enter', {ctrlKey:false}).defaultPrevented);
    assert(dialog.open);
    document.body.innerHTML = '<main>Another page</main>';
    assert.equal(press('a').defaultPrevented, false);
    document.body.outerHTML = new dom.window.DOMParser().parseFromString(html, 'text/html').body.outerHTML;
    dom.window.eval(script);
    let clicks = 0;
    document.querySelector('[data-project-primary]').addEventListener('click', () => clicks++);
    assert(press('a').defaultPrevented);
    assert(document.getElementById('projectForm').open);
    assert.equal(clicks, 1);
  }
});

test('register search displays its complete shortcut and Ctrl+K focuses it', t => {
  const { document, press } = setup(t, snapshot(6));
  const input = document.querySelector('#register-search');
  assert(input);
  assert.equal(input.closest('label').querySelectorAll('kbd').length, 1);
  assert.match(input.closest('label').textContent.replace(/\s/g, ''), /Ctrl\+K/);
  assert(press('k', {altKey:false}).defaultPrevented);
  assert.equal(document.activeElement, input);
});


test('path shortcuts open the typed editor and Add path lives beside the table', t => {
  const empty = fs.readFileSync(path.join(root,
    'Tests/ViewControllerTests/__Snapshots__/ProjectWorkspaceTests/emptyPathsAndMissingPressure.1.html'), 'utf8');
  for (const html of [empty, snapshot(4)]) {
    const { document, dom, press } = setup(t, html);
    assert.equal(document.querySelector('.page-title-row [data-project-primary]'), null);
    assert(document.querySelector('.path-schedule-heading [data-project-primary]'));
    assert.match(document.querySelector('.page-title-row').textContent, /Manage templates/);
    const navigations = [];
    document.addEventListener('click', event => {
      const card = event.target.closest('.path-network a[aria-keyshortcuts]');
      if (card) { navigations.push(card.getAttribute('href')); event.preventDefault(); }
    });
    for (const [key, type, action, custom] of [['r', 'return', 'addReturn', 'Alt+R'], ['s', 'supply', 'addSupply', 'Alt+S']]) {
      const card = document.querySelector(`.missing-path.${type}`);
      assert.equal(card.getAttribute('aria-keyshortcuts'), `Control+Alt+${key.toUpperCase()}`);
      assert(press(key).defaultPrevented);
      assert.equal(new URL(navigations.at(-1), 'http://localhost').searchParams.get('type'), type);
      const config = document.querySelector('[data-keybindings]');
      config.dataset.keybindings = JSON.stringify({...JSON.parse(config.dataset.keybindings), [action]:custom});
      card.setAttribute('aria-keyshortcuts', custom);
      assert.equal(press(key).defaultPrevented, false);
      assert(press(key, {ctrlKey:false}).defaultPrevented);
      assert.equal(navigations.at(-1), card.getAttribute('href'));
      for (const options of [{repeat:true}, {isComposing:true}, {modifierAltGraph:true}]) {
        assert.equal(press(key, {ctrlKey:false,...options}).defaultPrevented, false);
      }
      const input = document.createElement('input'); document.body.append(input);
      assert.equal(press(key, {ctrlKey:false}, input).defaultPrevented, false);
      input.remove();
      const dialog = document.createElement('dialog'); dialog.open = true; document.body.append(dialog);
      assert.equal(press(key, {ctrlKey:false}).defaultPrevented, false);
      dialog.remove();
    }
    document.body.innerHTML = '<main>Another page</main>';
    assert.equal(press('r', {ctrlKey:false}).defaultPrevented, false);
    assert.equal(press('s', {ctrlKey:false}).defaultPrevented, false);
  }
});


test('Import loads uses its own shortcut and preserves editing and dialog guards', t => {
  const {document,dom,press} = setup(t, snapshot(2));
  dom.window.HTMLDialogElement.prototype.showModal = function () { this.open = true; };
  const button = document.querySelector('[data-open-dialog="uploadRooms"]');
  const dialog = document.getElementById('uploadRooms');
  assert.equal(button.getAttribute('aria-keyshortcuts'), 'Control+Alt+I');
  assert(press('i').defaultPrevented);
  assert(dialog.open);
  assert.equal(press('i').defaultPrevented, false);
  dialog.open = false;
  const input = document.getElementById('room-search');
  assert(press('i', {}, input).defaultPrevented);
  assert(dialog.open); dialog.open = false;
  for (const options of [{ctrlKey:false}, {altKey:false}, {repeat:true}, {isComposing:true}, {modifierAltGraph:true}]) {
    assert.equal(press('i', options).defaultPrevented, false);
  }
  const name = document.createElement('input'); document.body.append(name);
  assert.equal(press('i', {}, name).defaultPrevented, false);
  document.querySelector('[data-keybindings]').dataset.keybindings = JSON.stringify({...bindings.defaults, importLoads:'Alt+I'});
  button.setAttribute('aria-keyshortcuts', 'Alt+I');
  assert.equal(press('i').defaultPrevented, false);
  assert(press('i', {ctrlKey:false}).defaultPrevented);
  assert(dialog.open); dialog.open = false;
  document.body.innerHTML = '<main>Another page</main>';
  assert.equal(press('i', {ctrlKey:false}).defaultPrevented, false);
});

test('PDF shortcut activates the existing export control and respects page and editor scope', t => {
  const {document,press} = setup(t, snapshot(6));
  const link = document.querySelector('#project-content a[target="_blank"]');
  assert.equal(link.getAttribute('aria-keyshortcuts'), 'Control+Alt+E');
  let exports = 0;
  link.addEventListener('click', () => exports++);
  assert(press('e').defaultPrevented);
  assert.equal(exports, 1);
  for (const options of [{ctrlKey:false}, {altKey:false}, {repeat:true}, {isComposing:true}, {shiftKey:true}]) {
    assert.equal(press('e', options).defaultPrevented, false);
  }
  const input = document.createElement('input'); document.body.append(input);
  assert.equal(press('e', {}, input).defaultPrevented, false);
  const dialog = document.createElement('dialog'); dialog.open = true; document.body.append(dialog);
  assert.equal(press('e').defaultPrevented, false);
  dialog.remove();
  link.setAttribute('aria-disabled', 'true');
  assert.equal(press('e').defaultPrevented, false);
  link.removeAttribute('aria-disabled');
  document.querySelector('[data-keybindings]').dataset.keybindings = JSON.stringify({...bindings.defaults, exportPDF:'Alt+E'});
  link.setAttribute('aria-keyshortcuts', 'Alt+E');
  assert.equal(press('e').defaultPrevented, false);
  assert(press('e', {ctrlKey:false}).defaultPrevented);
  assert.equal(exports, 2);
  link.remove();
  assert.equal(press('e', {ctrlKey:false}).defaultPrevented, false);
});
