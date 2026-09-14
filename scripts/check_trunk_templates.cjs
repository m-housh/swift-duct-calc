const assert = require('node:assert/strict');
const fs = require('node:fs');
const { test } = require('node:test');
const { JSDOM } = require('jsdom');

const script = fs.readFileSync('Public/js/trunk-templates.js', 'utf8');
const snapshot = name => fs.readFileSync(
  `Tests/ViewControllerTests/__Snapshots__/TrunkTemplateTests/${name}.html`, 'utf8');
const run = (room, register = 1) => `00000000-0000-0000-0000-${String(room).padStart(12, '0')}_${register}`;

function setup(t, levels = true) {
  const html = snapshot(`chooser-withLevels.${levels ? 'levels' : 'main'}`);
  const dom = new JSDOM(`<main class="project-workspace">${html}</main>`, { runScripts: 'outside-only' });
  t.after(() => dom.window.close());
  dom.window.eval(script);
  const { document, FormData } = dom.window;
  const form = document.querySelector('form[hx-post]');
  const choose = name => {
    const button = [...document.querySelectorAll('[data-trunk-template]')].find(button => button.value === name);
    assert(button, `Missing template: ${name}`);
    const picker = button.closest('.trunk-template-picker');
    if (picker.querySelector('.trunk-template-panel').hidden) picker.querySelector('[data-trunk-template-toggle]').click();
    button.firstElementChild.click();
  };
  return { dom, document, form, choose, data: () => new FormData(form) };
}

for (const type of ['supply', 'return']) {
  test(`main ${type} selects every register, including rooms without a level`, t => {
    const { choose, data } = setup(t);
    choose(`Main ${type} trunk`);
    assert.equal(data().get('type'), type);
    assert.equal(data().get('name'), `Main ${type} trunk`);
    assert.equal(data().get('height'), '');
    assert.deepEqual(data().getAll('rooms'), [run(1), run(1, 2), run(2), run(3), run(4)]);
    assert.deepEqual([...new Set(data().keys())], ['projectID', 'type', 'height', 'name', 'rooms']);
  });
}

test('level templates replace the selection and support multiple registers and the basement', t => {
  const { document, choose, data } = setup(t);
  assert.deepEqual([...document.querySelectorAll('[data-trunk-template][data-type]')].map(o => o.value), [
    'Main supply trunk', 'Main return trunk', 'Basement supply trunk', 'Basement return trunk',
    'Level-1 supply trunk', 'Level-1 return trunk', 'Level-2 supply trunk', 'Level-2 return trunk',
  ]);
  choose('Main supply trunk');
  choose('Level-1 return trunk');
  assert.deepEqual(data().getAll('rooms'), [run(1), run(1, 2)]);
  assert.equal(data().get('type'), 'return');
  choose('Basement supply trunk');
  assert.deepEqual(data().getAll('rooms'), [run(2)]);
  choose('Level-2 return trunk');
  assert.deepEqual(data().getAll('rooms'), [run(3)]);
});

test('one basement template selects runs from all nonpositive levels', t => {
  const { document, choose } = setup(t);
  document.body.innerHTML = snapshot('equivalentBasementLevelsShareOneTemplate.1');
  for (const type of ['supply', 'return']) {
    const name = `Basement ${type} trunk`;
    assert.equal(document.querySelectorAll(`[data-trunk-template][value="${name}"]`).length, 1);
    choose(name);
    const formData = new document.defaultView.FormData(document.querySelector('form[hx-post]'));
    assert.deepEqual(formData.getAll('rooms'), [run(2), run(5), run(5, 2), run(6)]);
    assert.equal(formData.get('type'), type);
  }
});

test('templates allow manual changes and preserve the optional rectangular height', t => {
  const { form, choose, data } = setup(t);
  form.elements.namedItem('height').value = '8';
  choose('Main return trunk');
  choose('Level-1 supply trunk');
  assert.equal(data().get('height'), '8');
  form.elements.namedItem('name').value = 'East wing';
  form.querySelector(`input[value="${run(1, 2)}"]`).checked = false;
  assert.equal(data().get('name'), 'East wing');
  assert.deepEqual(data().getAll('rooms'), [run(1)]);
});

test('projects without levels offer only main templates', t => {
  const { document, choose, data } = setup(t, false);
  assert.equal(document.querySelectorAll('[data-trunk-template][data-type]').length, 2);
  choose('Main supply trunk');
  assert.equal(data().getAll('rooms').length, 5);
});

test('HTMX body replacements work without duplicate handlers or changes to existing trunks', t => {
  const { dom, document, choose } = setup(t);
  document.body.innerHTML = snapshot('chooser-withLevels.levels') + snapshot('editingDoesNotOfferTemplates.1');
  const editForm = document.querySelector('form[hx-patch]');
  const before = [...new dom.window.FormData(editForm)];
  let changes = 0;
  document.addEventListener('input', () => changes++);
  dom.window.eval(script);
  choose('Main return trunk');
  assert.equal(changes, 1);
  assert.deepEqual([...new dom.window.FormData(editForm)], before);
});

test('choosing a template marks the form as an unsaved draft', t => {
  const { dom, choose } = setup(t);
  dom.window.eval(fs.readFileSync('Public/js/main.js', 'utf8'));
  choose('Main supply trunk');
  const event = new dom.window.Event('beforeunload', { cancelable: true });
  dom.window.dispatchEvent(event);
  assert(event.defaultPrevented);
});


test('choosing a template closes the dropdown, shows its name, and restores focus', t => {
  const { document, choose } = setup(t);
  choose('Main supply trunk');
  choose('Level-1 return trunk');
  const picker = document.querySelector('.trunk-template-picker');
  assert.equal(picker.querySelector('.trunk-template-panel').hidden, true);
  assert.equal(document.activeElement, picker.querySelector('[data-trunk-template-toggle]'));
  assert.equal(picker.querySelector('[data-trunk-template-summary]').textContent, 'Level-1 return trunk');
  const selected = picker.querySelectorAll('[aria-pressed=true]');
  assert.equal(selected.length, 1);
  assert.equal(selected[0].value, 'Level-1 return trunk');
  assert.equal(picker.querySelectorAll('tbody tr').length, 4);
});


test('new trunks start with No template and an empty selection', t => {
  const { document, data } = setup(t);
  assert.equal(data().get('name'), '');
  assert.deepEqual(data().getAll('rooms'), []);
  assert.equal(document.querySelector('[data-trunk-template-summary]').textContent, 'No template');
  assert.equal(document.querySelector('[data-trunk-template-toggle]').getAttribute('aria-expanded'), 'false');
  assert.equal(document.querySelector('.trunk-template-panel').hidden, true);
  assert.equal(document.querySelector('[aria-pressed=true]').value, '');
});

test('No template clears the name and runs, preserves type and height, and permits manual selection', t => {
  const { form, choose, data } = setup(t);
  choose('Main return trunk');
  form.elements.namedItem('height').value = '8';
  choose('');
  assert.equal(data().get('name'), '');
  assert.equal(data().get('type'), 'return');
  assert.equal(data().get('height'), '8');
  assert.deepEqual(data().getAll('rooms'), []);
  form.elements.namedItem('name').value = 'Custom return';
  form.querySelector('input[name=rooms]').checked = true;
  assert.equal(data().get('name'), 'Custom return');
  assert.deepEqual(data().getAll('rooms'), [run(1)]);
});

test('arrow keys navigate table rows and columns including No template', t => {
  const { dom, document } = setup(t);
  const trigger = document.querySelector('[data-trunk-template-toggle]');
  const press = key => {
    const event = new dom.window.KeyboardEvent('keydown', { key, bubbles: true, cancelable: true });
    document.activeElement.dispatchEvent(event);
    assert(event.defaultPrevented);
  };
  trigger.focus();
  press('ArrowDown');
  assert.equal(document.activeElement.value, '');
  press('ArrowDown');
  assert.equal(document.activeElement.value, 'Main supply trunk');
  press('ArrowRight');
  assert.equal(document.activeElement.value, 'Main return trunk');
  press('ArrowDown');
  assert.equal(document.activeElement.value, 'Basement return trunk');
  press('ArrowLeft');
  assert.equal(document.activeElement.value, 'Basement supply trunk');
  press('End');
  assert.equal(document.activeElement.value, 'Level-2 return trunk');
  press('ArrowDown');
  assert.equal(document.activeElement.value, 'Level-2 return trunk');
  press('ArrowLeft');
  press('ArrowDown');
  assert.equal(document.activeElement.value, 'Level-2 supply trunk');
  press('Home');
  assert.equal(document.activeElement.value, '');
  press('ArrowUp');
  assert.equal(document.activeElement.value, '');
  press('Escape');
  assert.equal(document.activeElement, trigger);
  assert.equal(trigger.getAttribute('aria-expanded'), 'false');
  assert(document.querySelector('.trunk-template-panel').hidden);
});

test('outside clicks, leaving the chooser, and closing the dialog dismiss the dropdown', t => {
  const { dom, document, form, choose, data } = setup(t);
  choose('Main supply trunk');
  const before = [...data()];
  const trigger = document.querySelector('[data-trunk-template-toggle]');
  const panel = document.querySelector('.trunk-template-panel');
  trigger.click();
  assert.equal(panel.hidden, false);
  form.elements.namedItem('name').click();
  assert.equal(panel.hidden, true);
  trigger.click();
  form.elements.namedItem('name').focus();
  assert.equal(panel.hidden, true);
  trigger.click();
  document.querySelector('dialog').dispatchEvent(new dom.window.Event('close'));
  assert.equal(panel.hidden, true);
  assert.deepEqual([...data()], before);
});
