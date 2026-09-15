const assert = require('node:assert/strict');
const fs = require('node:fs');
const { test } = require('node:test');
const { JSDOM } = require('jsdom');
const { defaults } = require('./keybinding_test_helpers.cjs');
const main = fs.readFileSync('Public/js/main.js', 'utf8');
const hints = fs.readFileSync('Public/js/shortcut-hints.js', 'utf8');
const fixture = `
<nav class="app-navbar"><button aria-keyshortcuts="Control+Alt+Shift+/" data-open-dialog="projectShortcuts">Help</button></nav>
<div id="project-sidebar">
  <a href="/project" aria-keyshortcuts="Control+Alt+1">Project</a>
  <a href="/rooms" aria-keyshortcuts="Control+Alt+2" aria-current="page">Rooms</a>
  <a href="/equipment" aria-keyshortcuts="Control+Alt+3">Equipment</a>
</div>
<div id="project-content"><button data-project-primary aria-keyshortcuts="Control+Alt+A" data-open-dialog="editor">Add room</button></div>
<input type="search" id="room-search" aria-keyshortcuts="Control+K">
<table data-selectable-table="rooms"></table>
<dialog id="projectShortcuts"></dialog><dialog id="editor"></dialog>
<div id="app-status"></div>`;
function setup(t, html = fixture) {
  const dom = new JSDOM(`<body data-keybindings='${JSON.stringify(defaults)}'>${html}</body>`, {
    url:'http://localhost', runScripts:'outside-only', pretendToBeVisual:true,
  });
  const errors = [];
  dom.window.addEventListener('error', event => errors.push(event.message));
  t.after(() => { dom.window.close(); assert.deepEqual(errors, []); });
  const { document } = dom.window;
  dom.window.HTMLElement.prototype.getClientRects = function () {
    return this.closest('[hidden], details:not([open]), dialog:not([open])') ? [] : [this.getBoundingClientRect()];
  };
  dom.window.HTMLElement.prototype.getBoundingClientRect = () => ({top:100,bottom:135,left:100,right:300,width:200,height:35});
  dom.window.HTMLDialogElement.prototype.showModal = function () { this.open = true; };
  dom.window.eval(main); dom.window.eval(hints);
  const press = (key='/', options={}, target=document.body) => {
    const event = new dom.window.KeyboardEvent('keydown', {key,ctrlKey:true,altKey:true,bubbles:true,cancelable:true,...options});
    target.dispatchEvent(event); return event;
  };
  const frame = () => new Promise(resolve => dom.window.requestAnimationFrame(resolve));
  const text = () => document.getElementById('shortcut-hints')?.textContent || '';
  return {dom, document, press, frame, text};
}
test('slash reveals the current controls without opening help; shifted slash opens help', async t => {
  const {document,press,frame,text} = setup(t);
  assert(press().defaultPrevented);
  assert(!document.getElementById('projectShortcuts').open);
  assert.match(text(), /Ctrl\+Alt\+A/);
  assert.doesNotMatch(text(), /Ctrl\+K/);
  for (const binding of ['Ctrl+Alt+1', 'Ctrl+Alt+2', 'Ctrl+Alt+3', 'Ctrl+Alt+Shift+Enter']) {
    assert(!text().includes(binding), binding + ' should not be revealed in the sidebar');
  }
  assert.match(document.querySelector('.shortcut-hints-note').textContent, /Ctrl\+Alt\+Enter for next step/);
  assert.match(text(), /Next row/);
  assert(![...document.querySelectorAll('.shortcut-hint')].some(hint => hint.textContent.includes('Ctrl+Alt+Shift+/')));
  assert.equal(document.getElementById('shortcut-hints').getAttribute('aria-hidden'),'true');
  assert(press('?', {shiftKey:true}).defaultPrevented);
  assert(document.getElementById('projectShortcuts').open);
  await frame(); assert.equal(text(), '');
  document.getElementById('projectShortcuts').open = false;
  document.getElementById('projectShortcuts').dispatchEvent(new document.defaultView.Event('close'));
  await frame(); assert.match(text(), /Ctrl\+Alt\+A/);
  press(); assert.equal(text(), '');
});
test('hints keep shortcuts and mouse controls usable, hide in an editor, and Escape dismisses', async t => {
  const {dom,document,press,frame,text} = setup(t);
  press(); press('a');
  assert(document.getElementById('editor').open);
  await frame(); assert.equal(text(), '');
  document.getElementById('editor').open = false;
  document.getElementById('editor').dispatchEvent(new dom.window.Event('close'));
  await frame(); assert(text());
  assert(press('Escape', {ctrlKey:false,altKey:false}).defaultPrevented);
  assert.equal(text(), '');
  assert.equal(dom.window.sessionStorage.getItem('ductcalc-reveal-shortcuts'),'false');
});
test('reveal respects editors, dialogs, composition and modifier keys', t => {
  const {document,press,text} = setup(t);
  for (const options of [{ctrlKey:false},{altKey:false},{repeat:true},{isComposing:true},{modifierAltGraph:true}]) {
    assert.equal(press('/', options).defaultPrevented,false);
    assert.equal(text(),'');
  }
  const input = document.createElement('input'); document.body.append(input);
  assert.equal(press('/', {}, input).defaultPrevented,false);
  document.getElementById('editor').open = true;
  assert.equal(press().defaultPrevented,false);
  document.getElementById('editor').open = false;
  assert(press('/', {}, document.getElementById('room-search')).defaultPrevented);
});
test('only available visible controls are revealed; labels follow saved bindings after replacement', async t => {
  const {dom,document,press,frame,text} = setup(t);
  document.body.insertAdjacentHTML('beforeend', '<button hidden aria-keyshortcuts="Alt+X">Hidden</button><button disabled aria-keyshortcuts="Alt+Z">Disabled</button>');
  press(); assert(!text().includes('Alt+X')); assert(!text().includes('Alt+Z'));
  document.body.dataset.keybindings = JSON.stringify({...defaults, nextStep:'Alt+Enter'});
  document.dispatchEvent(new dom.window.CustomEvent('htmx:afterSettle', {detail:{}}));
  await frame();
  assert.match(text(), /Alt\+Enter for next step/);
  assert(!text().includes('Ctrl+Alt+Enter'));
  document.querySelector('#project-sidebar [aria-current]').removeAttribute('aria-current');
  document.querySelector('#project-sidebar a:last-child').setAttribute('aria-current', 'page');
  document.dispatchEvent(new dom.window.CustomEvent('htmx:afterSettle', {detail:{}}));
  await frame(); assert(!text().includes('for next step'));
  document.body.innerHTML = '<nav><a href="/projects" aria-keyshortcuts="Control+Shift+P">Projects</a></nav>';
  document.body.dataset.keybindings = JSON.stringify({...defaults, reveal:'Alt+R', projects:'Control+Shift+P'});
  document.dispatchEvent(new dom.window.CustomEvent('htmx:afterSettle', {detail:{}}));
  await frame();
  assert.match(text(), /Ctrl\+Shift\+P/); assert(!text().includes('for next step'));
  assert.match(text(), /Alt\+R or Esc/);
  assert.equal(press().defaultPrevented,false);
  assert(press('r',{ctrlKey:false}).defaultPrevented);
  assert.equal(text(),'');
  dom.window.eval(hints);
  press('r',{ctrlKey:false}); assert.equal(document.querySelectorAll('#shortcut-hints').length,1);
});
