/* Progressive navigation and browser APIs. Swift owns records, state, markup, and exports. */
(() => {
  'use strict';
  const root = () => document.getElementById('fittings-page');
  if (!root()) return;
  const narrow = matchMedia('(max-width: 700px)');
  let request, searchTimer, toastTimer;
  function enhance() {
    const page = root();
    page.classList.add('js-enabled');
    const toggle = page.querySelector('.system-toggle');
    const target = page.querySelector(narrow.matches ? '#filters' : '.group-sidebar-header');
    target.prepend(toggle);
  }
  function focusSelector(element) {
    if (element?.id) return '#' + CSS.escape(element.id);
    for (const key of ['data-select', 'data-group', 'data-system', 'data-format', 'data-action', 'data-record']) {
      if (element?.hasAttribute(key)) return `[${key}="${CSS.escape(element.getAttribute(key))}"]`;
    }
  }
  async function navigate(url, { replace = false, history = true, focus = focusSelector(document.activeElement) } = {}) {
    clearTimeout(searchTimer);
    request?.abort();
    const controller = request = new AbortController();
    const page = root();
    const areas = ['.detail-panel', '.group-sidebar', '.fitting-sidebar'];
    const positions = areas.map(selector => {
      const area = page.querySelector(selector);
      return [selector, area.scrollTop, area.scrollLeft];
    });
    const oldSelected = page.querySelector('[data-select][aria-current]')?.dataset.select;
    const selection = document.activeElement?.id === 'search' ? [document.activeElement.selectionStart, document.activeElement.selectionEnd] : null;
    page.setAttribute('aria-busy', 'true');
    try {
      const response = await fetch(url, { signal: controller.signal, headers: { Accept: 'text/html' } });
      if (!response.ok) throw new Error('Reference navigation failed');
      const document = new DOMParser().parseFromString(await response.text(), 'text/html');
      const next = document.getElementById('fittings-page');
      if (!next) throw new Error('Reference page missing');
      if (controller.signal.aborted) return;
      page.replaceWith(next);
      enhance();
      if (history) window.history[replace ? 'replaceState' : 'pushState'](null, '', next.dataset.url);
      const selected = next.querySelector('[data-select][aria-current]')?.dataset.select;
      for (const [selector, top, left] of positions) {
        if (selector === '.detail-panel' && selected !== oldSelected) continue;
        const area = next.querySelector(selector); area.scrollTop = top; area.scrollLeft = left;
      }
      const active = focus && next.querySelector(focus);
      active?.focus({ preventScroll: true });
      if (selection && active?.id === 'search') active.setSelectionRange(...selection);
    } catch (error) {
      if (error.name !== 'AbortError') location.assign(url);
    } finally {
      if (request === controller) root()?.removeAttribute('aria-busy');
    }
  }
  function submit(form, replace = false) {
    const url = new URL(form.action);
    url.search = new URLSearchParams(new FormData(form));
    navigate(url, { replace });
  }
  async function copy(text) {
    try {
      await navigator.clipboard.writeText(text);
      const toast = root().querySelector('#toast');
      toast.textContent = 'Copied to clipboard'; toast.classList.add('visible');
      clearTimeout(toastTimer); toastTimer = setTimeout(() => toast.classList.remove('visible'), 2500);
    } catch {
      const dialog = root().querySelector('#copy-dialog');
      dialog.querySelector('textarea').value = text;
      dialog.showModal(); dialog.querySelector('textarea').select();
    }
  }
  document.addEventListener('click', event => {
    const page = root(), target = event.target.closest('a, button');
    if (!page?.contains(target)) return;
    if (target.matches('a[data-reference-nav]') && event.button === 0 && !event.metaKey && !event.ctrlKey && !event.shiftKey && !event.altKey) {
      event.preventDefault(); navigate(target.href, { focus: focusSelector(target) });
    } else if (target.dataset.copyId) copy(target.dataset.copyId);
    else if (target.dataset.action === 'share') copy(new URL(target.dataset.sharePath, location.origin).href);
    else if (target.dataset.action === 'copy-data') copy(page.querySelector('.code-panel pre').textContent);
    else if (target.dataset.action === 'close-copy') page.querySelector('#copy-dialog').close();
  });
  document.addEventListener('submit', event => {
    if (!root()?.contains(event.target)) return;
    event.preventDefault(); submit(event.target);
  });
  document.addEventListener('input', event => {
    if (event.target.id !== 'search' || !root()?.contains(event.target)) return;
    request?.abort(); clearTimeout(searchTimer);
    const form = event.target.form;
    if (event.target.value) form.elements.group.value = 'all';
    searchTimer = setTimeout(() => submit(form, true), 200);
  });
  document.addEventListener('change', event => {
    if (root()?.contains(event.target) && event.target.matches('select')) submit(event.target.form);
  });
  document.addEventListener('keydown', event => {
    if (root() && event.key === '/' && !event.ctrlKey && !event.metaKey && !/INPUT|TEXTAREA|SELECT/.test(event.target.tagName) && !document.querySelector('dialog[open]')) {
      event.preventDefault(); root().querySelector('#search').focus();
    }
  });
  window.addEventListener('popstate', () => { if (root()) navigate(location.href, { history: false }); });
  narrow.addEventListener('change', () => { if (root()) enhance(); });
  enhance();
})();
