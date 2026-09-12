const assert = require('node:assert/strict');
const fs = require('node:fs');
const { test } = require('node:test');
const { JSDOM } = require('jsdom');

const snapshot = name => fs.readFileSync(
  `Tests/ViewControllerTests/__Snapshots__/ViewControllerTests/${name}.1.html`, 'utf8');

test('login submits existing passwords without enforcing signup complexity', t => {
  const dom = new JSDOM(snapshot('login'));
  t.after(() => dom.window.close());
  const doc = dom.window.document;
  doc.querySelector('[name="email"]').value = 'ui-preview@example.test';
  const password = doc.querySelector('[name="password"]');
  assert.equal(password.autocomplete, 'current-password');
  assert.equal(password.hasAttribute('pattern'), false);
  assert.equal(doc.querySelector('#password-help'), null);
  for (const value of ['ab123456-cdef-4123-abcd-123456abcdef', 'existing-password', 'short']) {
    password.value = value;
    assert.equal(password.form.checkValidity(), true, 'Existing credentials must reach the server');
  }
  password.value = '';
  assert.equal(password.form.checkValidity(), false, 'A password is still required');
});

test('signup retains its password guidance and constraints', t => {
  const dom = new JSDOM(snapshot('signup'));
  t.after(() => dom.window.close());
  const doc = dom.window.document;
  assert(doc.querySelector('#password-help'));
  for (const name of ['password', 'confirmPassword']) {
    const input = doc.querySelector(`[name="${name}"]`);
    assert.equal(input.autocomplete, 'new-password');
    assert.equal(input.getAttribute('minlength'), '8');
    input.value = 'lowercase-only';
    assert.equal(input.checkValidity(), false);
    input.value = 'Preview1234!';
    assert.equal(input.checkValidity(), true);
  }
});
