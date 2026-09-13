const assert = require('node:assert/strict');
const fs = require('node:fs');
const { test } = require('node:test');
const { JSDOM } = require('jsdom');
const script = fs.readFileSync('Public/js/equipment.js', 'utf8');
const snapshot = fs.readFileSync('Tests/ViewControllerTests/__Snapshots__/ViewControllerTests/projectDetail.3.html', 'utf8');

function setup(t) {
  const dom = new JSDOM(snapshot, { runScripts: 'outside-only' });
  t.after(() => dom.window.close());
  const { document } = dom.window;
  let resize, disconnects = 0;
  dom.window.ResizeObserver = class {
    constructor(callback) { resize = callback; }
    observe() {}
    disconnect() { disconnects++; }
  };
  function fit(width) {
    const network = document.querySelector('.equipment-network');
    const rect = (x, y, width, height) => ({ x, y, left:x, top:y, width, height, right:x+width, bottom:y+height });
    network.getBoundingClientRect = () => rect(0, 0, width, 540);
    network.querySelector('.blower').getBoundingClientRect = () => rect(width/2-95, 248, 190, 260);
    for (const [mode, fraction] of [['heating',.16], ['cooling',.84]]) {
      const card = network.querySelector(`[data-equipment-mode="${mode}"]`);
      card.getBoundingClientRect = () => rect(width*fraction-80, 146, 160, 140);
      card.querySelector('.port').getBoundingClientRect = () => rect(width*fraction-4, 142, 8, 8);
    }
  }
  fit(1000);
  dom.window.eval(script);
  return { dom, document, fit, resize:() => resize(), disconnects:() => disconnects };
}

test('ducts switch to a wye at the available content width, then redraw when reopened', t => {
  const { document, fit, resize } = setup(t);
  const wires = document.querySelector('.airflow-lines');
  assert.equal(wires.querySelectorAll('.takeoff-transition').length, 2);
  fit(500); resize();
  assert(wires.querySelector('.mobile-wye'));
  assert.equal(wires.querySelectorAll('.takeoff-transition').length, 0);
  fit(0); resize();
  assert(!wires.innerHTML.includes('NaN'));
  fit(1000);
  document.querySelector('.equipment-canvas').dispatchEvent(new document.defaultView.Event('toggle'));
  assert.equal(wires.querySelectorAll('.takeoff-transition').length, 2);
  assert(wires.innerHTML.includes('var(--heating)'));
  assert(wires.innerHTML.includes('var(--cooling)'));
});

test('HTMX replacements reconnect the diagram without duplicating observers', t => {
  const { dom, document, fit, disconnects } = setup(t);
  const before = disconnects();
  document.body.outerHTML = snapshot.match(/<body[\s\S]*<\/body>/)[0];
  fit(500);
  dom.window.eval(script);
  document.dispatchEvent(new dom.window.Event('htmx:afterSwap'));
  assert.equal(disconnects(), before + 1);
  assert(document.querySelector('.mobile-wye'));
  document.body.innerHTML = '<main>Another view</main>';
  document.dispatchEvent(new dom.window.Event('htmx:afterSwap'));
  assert.equal(disconnects(), before + 2);
});

test('closing an equipment dialog discards its draft and clears the unload warning', t => {
  const { dom, document } = setup(t);
  dom.window.eval(fs.readFileSync('Public/js/main.js', 'utf8'));
  const dialog = document.querySelector('#equipmentForm-heating');
  const input = dialog.querySelector('[name=heatingCFM]');
  const original = input.value;
  input.value = '850';
  input.dispatchEvent(new dom.window.Event('input', { bubbles:true }));
  input.setAttribute('aria-invalid', 'true');
  const dirty = new dom.window.Event('beforeunload', { cancelable:true });
  dom.window.dispatchEvent(dirty);
  assert(dirty.defaultPrevented);
  dialog.dispatchEvent(new dom.window.Event('close'));
  assert.equal(input.value, original);
  assert(!input.hasAttribute('aria-invalid'));
  const clean = new dom.window.Event('beforeunload', { cancelable:true });
  dom.window.dispatchEvent(clean);
  assert(!clean.defaultPrevented);
});
