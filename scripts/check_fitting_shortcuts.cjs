const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { test } = require('node:test');
const { JSDOM } = require('jsdom');

const root = path.resolve(__dirname, '..');
const script = fs.readFileSync(path.join(root, 'Public/js/main.js'), 'utf8');
const snapshot = name => fs.readFileSync(path.join(root,
  `Tests/ViewControllerTests/__Snapshots__/FittingsSnapshotTests/${name}.1.html`), 'utf8');

function setup(t, name = 'allGroupsGuest') {
  const dom = new JSDOM(snapshot(name), { runScripts: 'outside-only' });
  t.after(() => dom.window.close());
  dom.window.eval(script);
  const { document, KeyboardEvent } = dom.window;
  const clicks = [];
  document.addEventListener('click', event => {
    const link = event.target.closest('a');
    if (link) { clicks.push(link); event.preventDefault(); }
  });
  const press = (key, options = {}, target = document.body) => {
    const event = new KeyboardEvent('keydown', {
      key, ctrlKey: true, altKey: true, bubbles: true, cancelable: true, composed: true, ...options,
    });
    target.dispatchEvent(event);
    return event;
  };
  return { dom, document, clicks, press };
}

test('N/P traverse filtered groups including All groups and stop at the ends', t => {
  for (const name of ['allGroupsGuest', 'returnGroupSignedIn', 'emptySupplyGroup']) {
    const { document, clicks, press } = setup(t, name);
    const links = [...document.querySelectorAll('[data-group]')];
    links.forEach((link, index) => {
      links.forEach(item => item.removeAttribute('aria-current'));
      link.setAttribute('aria-current', 'true');
      for (const key of ['n', 'p', 'N', 'P']) {
        const before = clicks.length;
        const next = index + (key.toLowerCase() === 'n' ? 1 : -1);
        assert(press(key).defaultPrevented);
        if (next < 0 || next >= links.length) assert.equal(clicks.length, before);
        else {
          assert.equal(clicks.length, before + 1);
          assert.equal(clicks.at(-1), links[next]);
          const query = new URL(clicks.at(-1).href, 'http://localhost').searchParams;
          assert.equal(query.get('q'), document.querySelector('#search').value);
          assert.equal(query.get('system') || 'all', document.querySelector('[name="system"]').value);
        }
      }
    });
    for (const key of '-=') assert.equal(press(key).defaultPrevented, false);
    links.at(-1).removeAttribute('aria-current');
    assert.equal(press('n').defaultPrevented, false);
    assert.equal(press('p').defaultPrevented, false);
    assert.equal(document.querySelector('nav [aria-keyshortcuts="Control+Alt+P"]'), null);
  }
});

test('number shortcuts open groups 1–10 while N/P also reach groups 11 and 12', t => {
  for (const name of ['allGroupsGuest', 'returnGroupSignedIn', 'emptySupplyGroup']) {
    const { document, clicks, press } = setup(t, name);
    [...'1234567890'].forEach((key, index) => {
      const link = document.querySelector(`[data-group="${index + 1}"]`);
      const before = clicks.length;
      assert.equal(press(key).defaultPrevented, Boolean(link));
      if (!link) return;
      assert.equal(link.getAttribute('aria-keyshortcuts'), `Control+Alt+${key}`);
      assert(link.title.includes(`Ctrl+Alt+${key}`));
      if (link.getAttribute('aria-current') === 'true') assert.equal(clicks.length, before);
      else assert.equal(clicks.at(-1), link);
    });
  }
});

test('J/K use the current filtered list, accept Caps Lock, and stop at the ends', t => {
  const { document, clicks, press } = setup(t);
  const links = [...document.querySelectorAll('[data-select]')];
  assert.equal(links.length, 2);
  assert(press('K').defaultPrevented);
  assert.equal(clicks.length, 0);
  assert(press('J').defaultPrevented);
  assert.equal(clicks.at(-1), links[1]);
  links[0].removeAttribute('aria-current');
  links[1].setAttribute('aria-current', 'true');
  assert(press('j').defaultPrevented);
  assert.equal(clicks.length, 1);
  assert(press('k').defaultPrevented);
  assert.equal(clicks.at(-1), links[0]);
  links[0].remove();
  const before = clicks.length;
  assert(press('j').defaultPrevented);
  assert(press('k').defaultPrevented);
  assert.equal(clicks.length, before);
  links[1].removeAttribute('aria-current');
  assert.equal(press('j').defaultPrevented, false);
  const empty = setup(t, 'emptySupplyGroup');
  assert.equal(empty.press('j').defaultPrevented, false);
  assert.equal(empty.press('k').defaultPrevented, false);
});

test('fitting shortcuts pause in editors and dialogs and ignore extra modifiers', t => {
  const { document, clicks, press } = setup(t);
  for (const key of ['1', '0', 'n', 'p', 'j', 'k']) {
    for (const options of [
      { ctrlKey: false }, { altKey: false }, { shiftKey: true }, { metaKey: true },
      { repeat: true }, { isComposing: true }, { modifierAltGraph: true },
    ]) assert.equal(press(key, options).defaultPrevented, false);
    for (const target of document.querySelectorAll('input, select, textarea')) {
      assert.equal(press(key, {}, target).defaultPrevented, false);
    }
    const editor = document.createElement('div');
    editor.innerHTML = '<div contenteditable><span>Editing</span></div>';
    document.body.append(editor);
    assert.equal(press(key, {}, editor.querySelector('span')).defaultPrevented, false);
    editor.remove();
    const dialog = document.querySelector('#fittingsShortcuts');
    dialog.setAttribute('open', '');
    assert.equal(press(key).defaultPrevented, false);
    dialog.removeAttribute('open');
  }
  document.querySelector('[data-group="1"]').setAttribute('aria-disabled', 'true');
  assert.equal(press('n').defaultPrevented, false);
  document.querySelector('.group-sidebar').setAttribute('inert', '');
  assert.equal(press('p').defaultPrevented, false);
  document.body.addEventListener('keydown', event => event.preventDefault(), { once: true });
  press('j');
  assert.deepEqual(clicks, []);
});

test('help dialog describes fitting bindings and only available app shortcuts', t => {
  for (const name of ['allGroupsGuest', 'returnGroupSignedIn']) {
    const { document } = setup(t, name);
    const dialog = document.querySelector('#fittingsShortcuts');
    const trigger = document.querySelector('[aria-controls="fittingsShortcuts"]');
    assert.equal(trigger.getAttribute('aria-label'), 'Keyboard shortcuts');
    assert.equal(trigger.getAttribute('aria-haspopup'), 'dialog');
    assert.equal(document.getElementById(dialog.getAttribute('aria-labelledby')).textContent, 'Keyboard shortcuts');
    const rows = Object.fromEntries([...dialog.querySelectorAll('tr')].map(row => [
      row.querySelector('kbd').textContent.trim(), row.querySelector('th').textContent.trim(),
    ]));
    assert.deepEqual(rows, {
      '1–9': 'Groups 1–9', '0': 'Group 10', N: 'Next group', P: 'Previous group',
      J: 'Next fitting', K: 'Previous fitting', D: 'Ductulator',
      ...(name === 'returnGroupSignedIn' ? { U: 'Profile' } : {}),
    });
  }
});

test('navigation replacements resolve new controls without duplicate handlers', t => {
  const { dom, document, clicks, press } = setup(t);
  press('j');
  assert.equal(clicks.length, 1);
  document.body.innerHTML = snapshot('returnGroupSignedIn');
  dom.window.eval(script);
  assert.equal(press('1').defaultPrevented, false);
  press('n');
  assert.equal(clicks.length, 2);
  assert.equal(clicks.at(-1).dataset.group, '10');
  press('p');
  assert.equal(clicks.at(-1).dataset.group, '7');
  document.body.innerHTML = '<main>Another page</main>';
  for (const key of ['1', '0', 'n', 'p', 'j', 'k']) assert.equal(press(key).defaultPrevented, false);
  document.body.innerHTML = snapshot('allGroupsGuest');
  press('j');
  assert.equal(clicks.length, 4);
});
