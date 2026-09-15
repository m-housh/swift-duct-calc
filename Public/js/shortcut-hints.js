if (!window.ductCalcHintsInitialized) {
  window.ductCalcHintsInitialized = true;
  const storageKey = 'ductcalc-reveal-shortcuts';
  let enabled = false;
  try { enabled = sessionStorage.getItem(storageKey) === 'true'; } catch {}
  const label = binding => binding?.replaceAll('Control', 'Ctrl').replaceAll('Meta', 'Command');
  const visible = control => control && !control.matches(':disabled, [aria-disabled="true"]')
    && !control.closest('[hidden], [inert], dialog:not([open]), details:not([open])')
    && control.getClientRects().length && getComputedStyle(control).visibility !== 'hidden';
  const targets = () => {
    const bindings = window.ductCalcKeybindings();
    const entries = new Map();
    const add = (control, binding, name = '') => {
      if (!binding || !visible(control) || control.closest('#project-sidebar, .app-navbar')) return;
      const values = entries.get(control) || [];
      const text = [label(binding), name].filter(Boolean).join(' · ');
      if (!values.includes(text)) values.push(text);
      entries.set(control, values);
    };
    for (const control of document.querySelectorAll('a[aria-keyshortcuts], button[aria-keyshortcuts]')) {
      for (const binding of control.getAttribute('aria-keyshortcuts').split(' ')) add(control, binding);
    }
    const rooms = document.querySelector('[data-selectable-table="rooms"]');
    add(rooms, bindings.nextRoom, 'Next row');
    add(rooms, bindings.previousRoom, 'Previous row');
    const fittings = document.getElementById('fittings-page');
    if (fittings) {
      for (const [selector, next, previous] of [
        ['a[data-group]', 'nextGroup', 'previousGroup'],
        ['a[data-select]', 'nextFitting', 'previousFitting'],
      ]) {
        const links = [...fittings.querySelectorAll(selector)];
        const selected = links.findIndex(link => ['page', 'true'].includes(link.getAttribute('aria-current')));
        if (selected >= 0) {
          add(links[selected + 1], bindings[next]);
          add(links[selected - 1], bindings[previous]);
        }
      }
    }
    return entries;
  };
  const render = () => {
    document.getElementById('shortcut-hints')?.remove();
    if (!document.body || !enabled || document.querySelector('dialog[open], [role="dialog"][aria-modal="true"], [data-recording]')) return;
    const layer = document.createElement('div');
    layer.id = 'shortcut-hints';
    layer.setAttribute('aria-hidden', 'true');
    document.body.append(layer);
    const occupied = [];
    for (const [control, bindings] of targets()) {
      const rect = control.getBoundingClientRect();
      if (rect.bottom <= 0 || rect.top >= innerHeight || rect.right <= 0 || rect.left >= innerWidth) continue;
      const badge = document.createElement('span');
      badge.className = 'shortcut-hint';
      for (const binding of bindings) {
        const line = document.createElement('span');
        line.textContent = binding;
        badge.append(line);
      }
      layer.append(badge);
      const width = badge.offsetWidth, height = badge.offsetHeight;
      const left = Math.max(4, Math.min(innerWidth - width - 4, rect.right - width));
      const anchorTop = control.matches('[data-selectable-table]') ? rect.top + 4 : rect.top - height - 2;
      let top = Math.max(4, Math.min(innerHeight - height - 4, anchorTop));
      const overlaps = y => occupied.some(box => left < box.right + 3 && left + width > box.left - 3
        && y < box.bottom + 3 && y + height > box.top - 3);
      // Keep neighboring labels separate on narrow screens.
      if (overlaps(top)) {
        for (let offset = 4; offset < innerHeight; offset += 4) {
          const candidate = [top + offset, top - offset].find(y => y >= 4 && y + height <= innerHeight - 4 && !overlaps(y));
          if (candidate !== undefined) { top = candidate; break; }
        }
      }
      badge.style.left = left + 'px';
      badge.style.top = top + 'px';
      occupied.push({left, top, right:left + width, bottom:top + height});
    }
    const note = document.createElement('span');
    note.className = 'shortcut-hints-note';
    const bindings = window.ductCalcKeybindings();
    note.textContent = `${label(bindings.reveal)} or Esc to hide`;
    if (document.querySelector('nav [data-open-dialog][aria-keyshortcuts]')) note.textContent += ` · ${label(bindings.help)} for full list`;
    const steps = [...document.querySelectorAll('#project-sidebar a')];
    const current = steps.findIndex(link => link.getAttribute('aria-current') === 'page');
    if (current >= 0 && steps[current + 1] && bindings.nextStep) note.textContent += ` · ${label(bindings.nextStep)} for next step`;
    layer.append(note);
  };
  let pending = false;
  const refresh = () => {
    if (pending) return;
    pending = true;
    requestAnimationFrame(() => { pending = false; render(); });
  };
  const setEnabled = value => {
    enabled = value;
    try { sessionStorage.setItem(storageKey, String(value)); } catch {}
    const status = document.getElementById('app-status');
    if (status) status.textContent = value ? 'Shortcut labels shown. Press Escape to hide.' : 'Shortcut labels hidden.';
    render();
  };
  window.ductCalcToggleHints = () => {
    if (!enabled && !targets().size) return false;
    setEnabled(!enabled);
    return true;
  };
  document.addEventListener('keydown', event => {
    if (enabled && event.key === 'Escape' && !event.defaultPrevented
      && !document.querySelector('dialog[open], [role="dialog"][aria-modal="true"], [data-recording]')) {
      setEnabled(false);
      event.preventDefault();
    }
  });
  for (const name of ['DOMContentLoaded', 'htmx:afterSettle', 'htmx:historyRestore', 'ductcalc:page-updated', 'click', 'input', 'keyup']) {
    document.addEventListener(name, refresh);
  }
  document.addEventListener('close', refresh, true);
  document.addEventListener('toggle', refresh, true);
  document.addEventListener('scroll', refresh, true);
  window.addEventListener('resize', refresh);
  refresh();
}
