const assert = require('node:assert/strict');
const fs = require('node:fs');
const { test } = require('node:test');
const { JSDOM } = require('jsdom');

const html = fs.readFileSync(
  'Tests/ViewControllerTests/__Snapshots__/ViewControllerTests/home.1.html', 'utf8');
const script = fs.readFileSync('Public/js/home.js', 'utf8');

function setup(t, reduced = false) {
  const dom = new JSDOM(html, { url: 'http://localhost/', runScripts: 'outside-only', pretendToBeVisual: true });
  t.after(() => dom.window.close());
  const { window } = dom;
  const doc = window.document;
  let timer;
  let onIntersection;
  let onMotionChange;
  let onColorChange;
  let hidden = false;
  const motion = {
    matches: reduced,
    addEventListener(_, callback) { onMotionChange = callback; },
  };
  const color = {
    matches: false,
    addEventListener(_, callback) { onColorChange = callback; },
  };
  window.matchMedia = query => query.includes('reduced-motion') ? motion : color;
  window.setTimeout = (callback, delay) => {
    assert.equal(delay, 3000);
    timer = callback;
    return 1;
  };
  window.clearTimeout = () => { timer = undefined; };
  window.IntersectionObserver = class {
    constructor(callback) { onIntersection = callback; }
    observe() {}
  };
  Object.defineProperty(doc, 'hidden', { get: () => hidden });
  // jsdom does not fetch frame URLs. Supply the document that a browser loads separately.
  doc.querySelectorAll('.demo-app-frame').forEach(frame => {
    frame.contentDocument.write('<!doctype html><html><head></head><body></body></html>');
    frame.contentDocument.close();
  });
  window.eval(script);
  const preview = doc.querySelector('.workspace-demo');
  const steps = [...preview.querySelectorAll('[data-preview-step]')];
  const panels = [...preview.querySelectorAll('[data-preview-panel]')];
  const playback = preview.querySelector('.demo-playback');
  return {
    preview, steps, panels, playback, doc,
    systemDark(value) { color.matches = value; onColorChange(); },
    loadFrame(frame) { frame.dispatchEvent(new window.Event('load')); },
    resize(width) {
      Object.defineProperty(doc.querySelector('.demo-stage'), 'clientWidth', { configurable: true, value: width });
      window.dispatchEvent(new window.Event('resize'));
    },
    get scheduled() { return Boolean(timer); },
    current() {
      const selected = steps.findIndex(step => step.getAttribute('aria-pressed') === 'true');
      assert.equal(steps.filter(step => step.getAttribute('aria-pressed') === 'true').length, 1);
      assert.equal(panels.filter(panel => panel.getAttribute('aria-hidden') === 'false').length, 1);
      assert.equal(panels[selected].getAttribute('aria-hidden'), 'false');
      assert.equal(steps[selected].getAttribute('aria-controls'), panels[selected].id);
      return selected;
    },
    tick() { assert(timer, 'expected a scheduled slide'); timer(); },
    visible(value) { onIntersection([{ isIntersecting: value }]); },
    hover(value) { preview.dispatchEvent(new window.Event(value ? 'mouseenter' : 'mouseleave')); },
    hidden(value) { hidden = value; doc.dispatchEvent(new window.Event('visibilitychange')); },
    reduce(value) { motion.matches = value; onMotionChange(); },
  };
}

test('autoplay visits every step and loops without changing keyboard focus', t => {
  const p = setup(t);
  assert.equal(p.current(), 0);
  assert.equal(p.scheduled, false);
  p.visible(true);
  assert.equal(p.playback.textContent, 'Pause preview');
  for (const index of [1, 2, 3, 4, 0]) {
    p.tick();
    assert.equal(p.current(), index);
    assert.equal(p.preview.ownerDocument.activeElement.tagName, 'BODY');
  }
});

test('manual step selection pauses rotation until Play is selected', t => {
  const p = setup(t);
  p.visible(true);
  p.steps[3].click();
  assert.equal(p.current(), 3);
  assert.equal(p.scheduled, false);
  assert.equal(p.playback.textContent, 'Play preview');
  p.playback.click();
  p.tick();
  assert.equal(p.current(), 4);
  p.playback.click();
  assert.equal(p.scheduled, false);
});

test('hover keeps playing while hidden tabs, scrolling offscreen, and keyboard focus pause', t => {
  const p = setup(t);
  p.visible(true);
  p.hover(true);
  assert.equal(p.scheduled, true);
  p.hover(false);
  assert.equal(p.scheduled, true);
  p.hidden(true);
  assert.equal(p.scheduled, false);
  p.hidden(false);
  assert.equal(p.scheduled, true);
  p.visible(false);
  assert.equal(p.scheduled, false);
  p.visible(true);
  assert.equal(p.scheduled, true);
  p.steps[0].focus();
  assert.equal(p.scheduled, false);
  assert.equal(p.current(), 0);
});

test('reduced motion starts paused, supports manual steps, and stops active playback when enabled', t => {
  const p = setup(t, true);
  p.visible(true);
  assert.equal(p.scheduled, false);
  p.steps[2].click();
  assert.equal(p.current(), 2);
  p.playback.click();
  assert.equal(p.scheduled, true);
  p.reduce(true);
  assert.equal(p.scheduled, false);
  p.reduce(false);
  assert.equal(p.scheduled, false);
});


test('the preview embeds the actual app screens with shared CSS and blocked editing', t => {
  const p = setup(t);
  const frames = [...p.doc.querySelectorAll('.demo-app-frame')];
  assert.equal(frames.length, 5);
  const markers = ['[data-room-workspace]', '.equipment-network', '[data-tel-workspace]', '[data-pressure-workspace]', '.trunk-panel'];
  frames.forEach((frame, index) => {
    assert.equal(frame.getAttribute('sandbox'), 'allow-same-origin');
    assert.equal(frame.tabIndex, -1);
    const step = frame.getAttribute('src').split('/').pop();
    const child = new JSDOM(fs.readFileSync(`Tests/ViewControllerTests/__Snapshots__/HomePageTests/preview-_.${step}.html`, 'utf8'));
    assert.equal(frame.getAttribute('loading'), 'lazy');
    const content = child.window.document;
    assert(content.querySelector('[inert] .project-workspace'));
    assert(content.querySelector(markers[index]), `${step} preview should contain ${markers[index]}`);
    assert(content.querySelector('.project-navigation'));
    const sidebarSteps = [...content.querySelectorAll('#project-sidebar a')].slice(1);
    assert.equal(sidebarSteps[index].getAttribute('aria-current'), 'page');
    assert(content.querySelector('link[href="/css/output.css"]'));
    assert(content.querySelector('link[href="/css/project-workspace.css"]'));
    assert.equal(content.querySelectorAll('script').length, 0);
    assert.match(content.querySelector('.project-switch').textContent, /Maple Avenue/);
    child.window.close();
  });
});

test('embedded app themes follow system changes and late frame loads', t => {
  const p = setup(t);
  const frames = [...p.doc.querySelectorAll('.demo-app-frame')];
  const assertTheme = theme => frames.forEach(frame => assert.equal(frame.contentDocument.documentElement.dataset.theme, theme));
  assertTheme('light');
  p.systemDark(true);
  assertTheme('dark');
  delete frames[0].contentDocument.documentElement.dataset.theme;
  p.loadFrame(frames[0]);
  assertTheme('dark');
  p.systemDark(false);
  assertTheme('light');
  p.resize(600);
  assert.equal(p.preview.style.getPropertyValue('--preview-scale'), '0.5');
  p.resize(1200);
  assert.equal(p.preview.style.getPropertyValue('--preview-scale'), '1');
});
