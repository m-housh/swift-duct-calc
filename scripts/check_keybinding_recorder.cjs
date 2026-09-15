const assert = require('node:assert/strict');
const fs = require('node:fs');
const {test} = require('node:test');
const {JSDOM} = require('jsdom');
const {script, defaults} = require('./keybinding_test_helpers.cjs');
const source = script(fs.readFileSync('Public/js/main.js','utf8'));
function setup(t) {
  const dom = new JSDOM(fs.readFileSync('Tests/ViewControllerTests/__Snapshots__/KeybindingsViewTests/editor.defaults.html','utf8'), {runScripts:'outside-only'});
  t.after(() => dom.window.close());
  dom.window.eval(source);
  const document = dom.window.document;
  const button = action => document.querySelector(`[data-keybinding-action="${action}"] [data-binding]`);
  const press = (key, options = {}) => {
    const event = new dom.window.KeyboardEvent('keydown', {key, ctrlKey:true, bubbles:true, cancelable:true, ...options});
    (document.querySelector('[data-recording]') || document.body).dispatchEvent(event);
    return event;
  };
  return {dom,document,button,press,status:()=>document.getElementById('keybinding-status').textContent};
}
test('records combinations, keeps live shortcuts unchanged until save, and resets', t => {
  const {dom,document,button,press} = setup(t);
  button('projects').click();
  assert(press('R',{shiftKey:true}).defaultPrevented);
  assert.equal(button('projects').dataset.binding,'Control+Shift+R');
  assert.equal(button('projects').textContent,'CtrlShiftR');
  assert.equal(dom.window.ductCalcKeybindings().projects, defaults.projects);
  assert.deepEqual(JSON.parse(document.querySelector('[name=bindings]').value), {overrides:{projects:'Control+Shift+R'}});
  document.querySelector('[data-keybinding-action=projects] [data-reset-keybinding]').click();
  assert.equal(button('projects').dataset.binding,defaults.projects);
});
test('rejects conflicts, bare keys, repeats, composition and AltGraph; Escape and Tab cancel', t => {
  const {document,button,press,status} = setup(t);
  button('projects').click();
  press('2',{altKey:true});
  assert.match(status(),/Rooms/);
  assert(button('projects').hasAttribute('data-recording'));
  press('x',{ctrlKey:false});
  assert.match(status(),/Use Ctrl/);
  for (const options of [{repeat:true},{isComposing:true},{modifierAltGraph:true}]) press('R',options);
  assert.equal(button('projects').dataset.binding,defaults.projects);
  press('Escape',{ctrlKey:false});
  assert(!document.querySelector('[data-recording]'));
  button('projects').click();
  assert.equal(press('Tab',{ctrlKey:false}).defaultPrevented,false);
  assert(!document.querySelector('[data-recording]'));
});
test('permits reuse in separate contexts, detects reset conflicts, and resets all', t => {
  const {document,button,press,status} = setup(t);
  for (const action of ['nextRoom','nextFitting']) { button(action).click(); press('J',{shiftKey:true}); }
  assert.equal(button('nextRoom').dataset.binding,button('nextFitting').dataset.binding);
  button('projects').click(); press('R',{shiftKey:true});
  button('profile').click(); press('P',{altKey:true});
  document.querySelector('[data-keybinding-action=projects] [data-reset-keybinding]').click();
  assert.match(status(),/conflict with Profile/);
  document.querySelector('[data-reset-keybindings]').click();
  assert.deepEqual(JSON.parse(document.querySelector('[name=bindings]').value),{overrides:{}});
  for (const [action,binding] of Object.entries(defaults)) assert.equal(button(action).dataset.binding,binding);
});
test('search filters actions without changing draft bindings; blur cancels recording', t => {
  const {dom,document,button,press} = setup(t);
  button('projects').click(); press('R',{shiftKey:true});
  button('profile').click();
  button('profile').dispatchEvent(new dom.window.FocusEvent('focusout',{bubbles:true}));
  assert(!document.querySelector('[data-recording]'));
  const search = document.getElementById('keybinding-search');
  search.value='heating'; search.dispatchEvent(new dom.window.Event('input',{bubbles:true}));
  assert.equal(document.querySelectorAll('[data-keybinding-action]:not([hidden])').length,1);
  assert.equal(button('projects').dataset.binding,'Control+Shift+R');
  dom.window.eval(source);
  button('heating').click(); press('H',{shiftKey:true});
  assert.equal(button('heating').dataset.binding,'Control+Shift+H');
});

test('a recorded Shift+slash binding requires Shift and allows an unshifted search binding', t => {
  const {dom,document,button,press} = setup(t);
  button('help').click(); press('?',{shiftKey:true});
  button('search').click(); press('/');
  assert.equal(button('help').dataset.binding,'Control+Shift+/');
  assert.equal(button('search').dataset.binding,'Control+/');
  document.querySelector('[data-keybindings]').dataset.keybindings = JSON.stringify({...defaults,help:'Control+Shift+/'});
  assert.equal(dom.window.ductCalcMatches(new dom.window.KeyboardEvent('keydown',{key:'/',ctrlKey:true}), 'help'),false);
});
