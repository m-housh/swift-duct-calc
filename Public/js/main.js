function syncInputs(lhs, rhs) {
	const first = document.getElementById(lhs);
	const second = document.getElementById(rhs);
	first.value = second.value;
}

// These listeners survive HTMX body replacements without being registered twice.
if (!window.ductCalcControlsInitialized) {
  window.ductCalcControlsInitialized = true;
  document.addEventListener('click', event => {
    const button = event.target.closest('[data-check-all]');
    if (button) {
      button.closest('fieldset').querySelectorAll('input[type=checkbox]').forEach(input => {
        input.checked = button.dataset.checkAll === 'true';
        input.dispatchEvent(new Event('change', { bubbles: true }));
      });
    }
    document.querySelectorAll('.account-menu[open]').forEach(menu => {
      if (!menu.contains(event.target)) menu.open = false;
    });
  });
  document.addEventListener('keydown', event => {
    const menu = event.target.closest('.account-menu[open]');
    if (event.key === 'Escape' && menu) {
      menu.open = false;
      menu.querySelector('summary').focus();
      event.preventDefault();
    }
  });
}

if (!window.ductCalcFocusInitialized) {
  window.ductCalcFocusInitialized = true;
  const requests = new WeakMap();
  const openers = new WeakMap();
  const visible = element => element && (element.checkVisibility
    ? element.checkVisibility({ checkVisibilityCSS: true })
    : element.getClientRects().length > 0);
  const focus = element => {
    if (!visible(element)) return;
    if (!element.matches('a[href],button,input,select,textarea,summary,[tabindex]')) element.tabIndex = -1;
    element.focus();
  };
  const heading = () => [...document.querySelectorAll('main h1')].find(visible);
  const updateTitle = () => {
    const title = heading()?.textContent.trim();
    if (title) document.title = title === 'Duct Calc' ? title : `${title} · Duct Calc`;
  };
  document.addEventListener('DOMContentLoaded', updateTitle);
  const announce = (message, error = false) => {
    let region = document.getElementById(error ? 'app-error' : 'app-status');
    const dialog = document.querySelector('dialog[open]');
    if (error && dialog) {
      region = dialog.querySelector('[data-request-error]');
      if (!region) {
        region = document.createElement('div');
        region.dataset.requestError = '';
        region.className = 'request-error';
        region.setAttribute('role', 'alert');
        dialog.append(region);
      }
    }
    if (!region) return;
    region.textContent = '';
    requestAnimationFrame(() => {
      if (!region.isConnected) return;
      region.textContent = message;
      if (error) {
        const close = document.createElement('button');
        close.type = 'button';
        close.setAttribute('aria-label', 'Dismiss error');
        close.textContent = '×';
        close.addEventListener('click', () => region.replaceChildren());
        region.append(close);
      }
    });
  };
  document.addEventListener('click', event => {
    const opener = event.target.closest('[data-open-dialog]');
    if (opener) {
      const dialog = document.getElementById(opener.dataset.openDialog);
      if (dialog instanceof HTMLDialogElement) {
        openers.set(dialog, opener);
        dialog.showModal();
      }
    }
    if (event.target.closest('.skip-link')) {
      event.preventDefault();
      focus(heading() || document.getElementById('main-content'));
    }
  });
  document.addEventListener('close', event => {
    const opener = openers.get(event.target);
    if (opener?.isConnected) focus(opener);
  }, true);
  document.addEventListener('invalid', event => event.target.setAttribute('aria-invalid', 'true'), true);
  document.addEventListener('input', event => {
    if (event.target.validity?.valid) event.target.removeAttribute('aria-invalid');
  });
  document.addEventListener('htmx:beforeRequest', event => {
    const { xhr, elt, target } = event.detail;
    const active = document.activeElement;
    const dialog = elt.closest('dialog');
    (dialog || document).querySelectorAll('[data-request-error], #app-error').forEach(node => { node.textContent = ''; });
    requests.set(xhr, {
      active, dialog, target,
      next: target?.nextElementSibling,
      message: elt.closest('[data-success-message]')?.dataset.successMessage,
      deletion: elt.hasAttribute('hx-delete'),
      affected: target?.contains(active),
    });
  });
  document.addEventListener('htmx:afterSettle', event => {
    const state = requests.get(event.detail.xhr);
    if (!state) return;
    requests.delete(event.detail.xhr);
    if (state.target?.tagName === 'BODY') updateTitle();
    const error = [...document.querySelectorAll('[data-error-message]')].find(visible);
    const result = document.querySelector('[data-result-summary]');
    if (error) focus(error);
    else {
      if (result && state.target?.id === 'resultView') announce(result.dataset.resultSummary);
      else if (state.message) announce(state.message);
      else if (state.deletion) announce('Item deleted.');
      // Do not interrupt someone who moved to a different, surviving control during the request.
      const active = document.activeElement;
      if (active !== document.body && active !== state.active && active.isConnected && visible(active)) return;
      if (state.dialog && !state.dialog.isConnected) {
        focus(document.querySelector(`[data-open-dialog="${CSS.escape(state.dialog.id)}"]`) || heading());
      } else if (state.affected && !state.active.isConnected) {
        const target = event.detail.elt;
        const autofocus = [...(target?.querySelectorAll('[autofocus]') || [])].find(visible);
        focus(autofocus || state.next?.querySelector('a[href],button') || heading());
      }
    }
  });
  for (const name of ['htmx:responseError', 'htmx:sendError', 'htmx:timeout']) {
    document.addEventListener(name, event => announce(
      event.detail?.elt?.closest('[hx-ext~="htmx-download"]')
        ? 'PDF export failed. Please try again.'
        : 'The request could not be completed. Please try again.', true));
  }
}

if (!window.ductCalcShortcutsInitialized) {
  window.ductCalcShortcutsInitialized = true;
// Resolve the current controls on each press because HTMX replaces the body during navigation.
document.addEventListener('keydown', (event) => {
  const key = event.key.toLowerCase();
  if (event.defaultPrevented || event.repeat || event.isComposing
      || !event.ctrlKey || !event.altKey || event.shiftKey || event.metaKey
      || event.getModifierState('AltGraph') || !/^[0-9njkdfpu]$/.test(key)) return;

  const editing = event.composedPath().some(node => node instanceof Element && (
    node.isContentEditable
    || node.matches('input, textarea, select, [contenteditable]:not([contenteditable="false"]), [role="textbox"], [role="combobox"], [role="spinbutton"]')
  ));
  if (editing || document.querySelector('dialog[open], [role="dialog"][aria-modal="true"]')) return;

  const fittings = document.getElementById('fittings-page');
  if (!fittings && (key === 'j' || key === 'k')) return;
  const groupNavigation = fittings && (key === 'n' || key === 'p');
  const buttons = [...document.querySelectorAll(groupNavigation
    ? '#fittings-page a[data-group]'
    : fittings ? '#fittings-page a[data-select]' : '#project-sidebar a[aria-keyshortcuts]')];
  const isCurrent = button => ['page', 'true'].includes(button.getAttribute('aria-current'));
  let control;
  if (groupNavigation || key === 'j' || key === 'k') {
    const current = buttons.findIndex(isCurrent);
    if (current === -1) return;
    const next = Math.max(0, Math.min(buttons.length - 1, current + (key === 'j' || key === 'n' ? 1 : -1)));
    control = buttons[next];
  } else {
    const shortcut = `Control+Alt+${key.toUpperCase()}`;
    control = document.querySelector(
      `#project-sidebar a[aria-keyshortcuts="${shortcut}"], #fittings-page a[data-group][aria-keyshortcuts="${shortcut}"], nav a[aria-keyshortcuts="${shortcut}"]`
    );
  }
  if (!control || control.matches(':disabled, [aria-disabled="true"]') || control.closest('[inert]')) return;

  event.preventDefault();
  if (!isCurrent(control)) control.click();
});

}

if (!window.ductCalcWorkspaceInitialized) {
  window.ductCalcWorkspaceInitialized = true;
  // Keep only view preferences here. Forms and calculations remain server-owned.
  const selections = new Map();
  const filters = new Map();
  const expansions = new Map();
  const pressureWidths = new WeakMap();
  const pendingLosses = new Map();
  const fitPressureStreams = () => {
    document.querySelectorAll('.pressure-river').forEach(river => {
      const svg = river.querySelector('.river-wires');
      if (!svg?.clientHeight || !svg.viewBox?.baseVal.height) return;
      const scaleY = svg.clientHeight / svg.viewBox.baseVal.height;
      const endpoints = new Map([...river.querySelectorAll('[data-select-loss]')]
        .map(button => [button.dataset.selectLoss, button.closest('.river-endpoint') || button]));
      const streams = [...svg.querySelectorAll('[data-loss-stream]')].flatMap(path => {
        const button = endpoints.get(path.dataset.lossStream);
        if (!button?.clientHeight) return [];
        if (!pressureWidths.has(path)) pressureWidths.set(path, parseFloat(path.style.strokeWidth));
        return [{path, width: pressureWidths.get(path) * scaleY, limit: Math.max(1, button.clientHeight - 8)}];
      });
      // One scale preserves the loss proportions, with space inside each rounded card border.
      const scale = Math.min(1, ...streams.map(({width, limit}) => limit / width));
      streams.forEach(({path, width}) => { path.style.strokeWidth = `${width * scale}px`; });
    });
  };
  const pressureResize = typeof ResizeObserver === 'function' ? new ResizeObserver(fitPressureStreams) : null;
  const key = name => `${document.querySelector('[data-project-id]')?.dataset.projectId || ''}:${name}`;
  const rows = table => [...table.querySelectorAll('tbody > tr[data-record]')];
  const select = (table, row, focus = false) => {
    if (!table) return;
    selections.set(key(table.dataset.selectableTable), row?.dataset.record);
    rows(table).forEach(item => {
      item.classList.toggle('selected-row', item === row);
      item.querySelector('.row-select')?.setAttribute('aria-pressed', String(item === row));
    });
    if (table.dataset.selectableTable === 'rooms') {
      document.querySelectorAll('[data-room-inspector]').forEach(panel => { panel.hidden = panel.dataset.roomInspector !== row?.dataset.record; });
      const empty = document.querySelector('[data-inspector-empty]');
      if (empty) empty.hidden = !!row;
    }
    if (table.dataset.selectableTable === 'paths') {
      document.querySelectorAll('[data-select-path]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.selectPath === row?.dataset.record)));
      document.querySelectorAll('[data-path-wire]').forEach(wire => wire.classList.toggle('selected-wire', wire.dataset.pathWire === row?.dataset.record));
    }
    if (table.dataset.selectableTable === 'loss') selectLoss(row?.dataset.record);
    if (focus) row?.querySelector('.row-select')?.focus({ preventScroll: true });
  };
  const filter = table => {
    const name = table.dataset.selectableTable;
    const search = document.getElementById(name === 'rooms' ? 'room-search' : 'register-search');
    const level = document.querySelector('[data-room-level]');
    const query = search?.value.trim().toLocaleLowerCase() || '';
    const floor = name === 'rooms' ? level?.value || 'all' : 'all';
    filters.set(key(name), { query: search?.value || '', floor });
    rows(table).forEach(row => { row.hidden = !(row.dataset.search || '').toLocaleLowerCase().includes(query) || (floor !== 'all' && row.dataset.level !== floor); });
    const visible = rows(table).filter(row => !row.hidden);
    const selected = visible.find(row => row.dataset.record === selections.get(key(name)));
    select(table, selected || visible[0]);
    if (name === 'rooms') {
      const empty = document.querySelector('[data-no-rooms]');
      if (empty) empty.hidden = visible.length > 0;
    }
  };
  const selectLoss = id => {
    selections.set(key('loss'), id);
    document.querySelectorAll('[data-select-loss]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.selectLoss === id)));
    document.querySelectorAll('[data-loss-stream]').forEach(stream => stream.classList.toggle('active', stream.dataset.lossStream === id));
    document.querySelectorAll('[data-selectable-table="loss"] tr[data-record]').forEach(row => {
      row.classList.toggle('selected-row', row.dataset.record === id);
      row.querySelector('.row-select')?.setAttribute('aria-pressed', String(row.dataset.record === id));
    });
  };
  const restore = () => {
    // A saved row refreshes derived values and rankings, but must not discard other drafts.
    document.querySelectorAll('[data-loss-form]').forEach(form => {
      const input = form.querySelector('input[name="value"]');
      const draftKey = key(`loss-draft:${form.dataset.lossForm}`);
      const draft = pendingLosses.get(draftKey);
      if (draft === undefined || !input) return;
      if (draft.trim() !== '' && Number(draft) === Number(input.defaultValue)) {
        pendingLosses.delete(draftKey);
      } else {
        input.value = draft;
        input.dispatchEvent(new Event('input', { bubbles: true }));
      }
    });
    document.querySelectorAll('[data-selectable-table]').forEach(table => {
      const name = table.dataset.selectableTable;
      if (name === 'paths' || name === 'loss') select(table, rows(table).find(row => row.dataset.record === selections.get(key(name))) || rows(table)[0]);
      else {
        const saved = filters.get(key(name));
        const search = document.getElementById(name === 'rooms' ? 'room-search' : 'register-search');
        if (saved && search) search.value = saved.query;
        const level = document.querySelector('[data-room-level]');
        if (saved && level && name === 'rooms' && [...level.options].some(option => option.value === saved.floor)) level.value = saved.floor;
        filter(table);
      }
    });
    document.querySelectorAll('[data-expansion]').forEach(detail => { detail.open = expansions.get(key(detail.dataset.expansion)) ?? detail.open; });
    const losses = [...document.querySelectorAll('[data-select-loss]')];
    if (losses.length) selectLoss(losses.find(button => button.dataset.selectLoss === selections.get(key('loss')))?.dataset.selectLoss || losses[0].dataset.selectLoss);
    pressureResize?.disconnect();
    document.querySelectorAll('.pressure-river, .pressure-river .river-endpoint').forEach(element => pressureResize?.observe(element));
    fitPressureStreams();
  };
  document.addEventListener('click', event => {
    const projectRow = event.target.closest('tr[data-project-row]');
    if (projectRow && !event.defaultPrevented && event.button === 0
        && !event.ctrlKey && !event.metaKey && !event.shiftKey && !event.altKey
        && !event.target.closest('a,button,input,select,textarea,label,summary,details,[contenteditable],[role="button"]')
        && !window.getSelection()?.toString()) {
      projectRow.querySelector('a.project-name')?.click();
      return;
    }
    const row = event.target.closest('[data-selectable-table] tr[data-record]');
    if (row && !event.target.closest('dialog, a, input, select, textarea, summary, details, button:not(.row-select)')) {
      select(row.closest('table'), row, true);
    }
    const path = event.target.closest('[data-select-path]');
    if (path) {
      const table = document.querySelector('[data-selectable-table="paths"]');
      const row = table && rows(table).find(row => row.dataset.record === path.dataset.selectPath);
      select(table, row);
    }
    const loss = event.target.closest('[data-select-loss]');
    if (loss) selectLoss(loss.dataset.selectLoss);
  });
  document.addEventListener('input', event => {
    const form = event.target.closest('[data-loss-form]');
    if (form && event.target.name === 'value') {
      const draftKey = key(`loss-draft:${form.dataset.lossForm}`);
      if (event.target.value === event.target.defaultValue) pendingLosses.delete(draftKey);
      else pendingLosses.set(draftKey, event.target.value);
    }
    if (event.target.id === 'room-search') filter(document.querySelector('[data-selectable-table="rooms"]'));
    if (event.target.id === 'register-search') filter(document.querySelector('[data-selectable-table="registers"]'));
  });
  document.addEventListener('focusin', event => {
    const form = event.target.closest('[data-loss-form]');
    if (form) selectLoss(form.dataset.lossForm);
  });
  document.addEventListener('submit', event => {
    if (event.target.matches('[data-loss-form]')) selectLoss(event.target.dataset.lossForm);
  }, true);
  document.addEventListener('change', event => {
    if (event.target.matches('[data-room-level]')) filter(document.querySelector('[data-selectable-table="rooms"]'));
  });
  document.addEventListener('toggle', event => {
    if (event.target.matches('[data-expansion]')) expansions.set(key(event.target.dataset.expansion), event.target.open);
    if (event.target.matches('.pressure-canvas[open]')) fitPressureStreams();
  }, true);
  document.addEventListener('keydown', event => {
    if (event.defaultPrevented || event.repeat || event.isComposing || !event.ctrlKey || event.metaKey || event.shiftKey || event.getModifierState('AltGraph') || document.querySelector('dialog[open], [role="dialog"][aria-modal="true"]')) return;
    const editing = event.composedPath().some(node => node instanceof Element && node.matches('input,textarea,select,[contenteditable]:not([contenteditable="false"]),[role="textbox"],[role="combobox"],[role="spinbutton"]'));
    const letter = event.key.toLowerCase();
    if (letter === 'k' && !event.altKey) {
      const search = document.getElementById('project-search') || document.getElementById('room-search') || document.getElementById('register-search');
      if (search && !search.disabled && !search.closest('[inert]') && (!editing || event.target === search)) { event.preventDefault(); search.focus(); search.select(); }
    } else if (event.altKey && !editing && ['j', 'k'].includes(letter)) {
      const table = document.querySelector('[data-selectable-table="rooms"]');
      if (!table || table.closest('[inert]')) return;
      const visible = rows(table).filter(row => !row.hidden);
      if (!visible.length) return;
      const current = visible.findIndex(row => row.classList.contains('selected-row'));
      const next = current < 0 ? 0 : Math.max(0, Math.min(visible.length - 1, current + (letter === 'j' ? 1 : -1)));
      event.preventDefault(); select(table, visible[next], true);
      visible[next].scrollIntoView?.({ block: 'nearest' });
    }
  });
  document.addEventListener('DOMContentLoaded', restore);
  document.addEventListener('htmx:afterSwap', restore);
  document.addEventListener('htmx:afterSettle', restore);
  document.addEventListener('htmx:historyRestore', restore);
  if (document.readyState !== 'loading') restore();
}

if (!window.ductCalcDraftGuardInitialized) {
  window.ductCalcDraftGuardInitialized = true;
  const dirtyForms = new Set();
  const prune = () => { for (const form of dirtyForms) if (!form.isConnected) dirtyForms.delete(form); };
  document.addEventListener('input', event => {
    const form = event.target.closest('.project-workspace form');
    if (form && (form.hasAttribute('hx-post') || form.hasAttribute('hx-patch'))) dirtyForms.add(form);
  });
  window.addEventListener('beforeunload', event => {
    prune();
    if (dirtyForms.size) { event.preventDefault(); event.returnValue = ''; }
  });
  document.addEventListener('htmx:afterSettle', prune);
}
