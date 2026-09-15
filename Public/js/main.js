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
  const announce = (message, error = false, origin = null, actions = []) => {
    let region = document.getElementById(error ? 'app-error' : 'app-status');
    const owner = origin?.isConnected ? origin.closest('form') || origin.closest('dialog') : null;
    if (error && owner) {
      region = owner.querySelector('[data-request-error]');
      if (!region) {
        region = document.createElement('div');
        region.dataset.requestError = '';
        region.className = 'request-error';
        region.setAttribute('role', 'alert');
        region.tabIndex = -1;
        owner.prepend(region);
      }
    }
    if (!region) return;
    region.textContent = '';
    requestAnimationFrame(() => {
      if (!region.isConnected) return;
      region.textContent = message;
      if (error) {
        const content = document.createElement('div');
        content.className = 'request-error-content';
        content.textContent = message;
        region.replaceChildren(content);
        window.ductCalcRequestErrors.appendActions(content, actions);
        const close = document.createElement('button');
        close.type = 'button';
        close.setAttribute('aria-label', 'Dismiss error');
        close.textContent = '×';
        close.addEventListener('click', () => {
          region.replaceChildren();
          focus(origin?.querySelector('[aria-invalid="true"]') || origin);
        });
        region.append(close);
        focus(region);
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
    const owner = elt.closest('form') || dialog;
    (owner || document).querySelectorAll(owner ? '[data-request-error]' : '#app-error').forEach(node => { node.textContent = ''; });
    clearFieldErrors(owner);
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
    if (event.detail.xhr?.status >= 400) return;
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
  let fieldErrorID = 0;
  function clearFieldErrors(owner) {
    owner?.querySelectorAll('[data-server-field-error]').forEach(message => {
      owner.querySelectorAll('[aria-describedby]').forEach(input => {
        if (!input.getAttribute('aria-describedby').split(/\s+/).includes(message.id)) return;
        const ids = input.getAttribute('aria-describedby').split(/\s+/).filter(id => id !== message.id);
        if (ids.length) input.setAttribute('aria-describedby', ids.join(' '));
        else input.removeAttribute('aria-describedby');
        input.removeAttribute('aria-invalid');
      });
      message.remove();
    });
  }
  document.addEventListener('input', event => {
    const input = event.target;
    const owner = input.closest('form');
    if (!owner) return;
    for (const id of (input.getAttribute('aria-describedby') || '').split(/\s+/)) {
      const message = document.getElementById(id);
      if (!message?.hasAttribute('data-server-field-error')) continue;
      message.remove();
      const ids = input.getAttribute('aria-describedby').split(/\s+/).filter(value => value !== id);
      if (ids.length) input.setAttribute('aria-describedby', ids.join(' '));
      else input.removeAttribute('aria-describedby');
      input.removeAttribute('aria-invalid');
    }
  });
  for (const name of ['htmx:responseError', 'htmx:sendError', 'htmx:timeout']) {
    document.addEventListener(name, event => {
      const {xhr, elt} = event.detail || {};
      if (elt && !elt.isConnected) return;
      const form = elt?.closest('form');
      let failure;
      if (name === 'htmx:responseError' && xhr?.getResponseHeader?.('Content-Type')?.startsWith('application/vnd.ductcalc.error+json')) {
        try {
          const text = xhr.responseType === 'arraybuffer' ? new TextDecoder().decode(xhr.response) : xhr.responseText;
          failure = JSON.parse(text);
        } catch { /* A proxy or interrupted response may not contain the application error. */ }
      }
      let message = elt?.closest('[hx-ext~="htmx-download"]')
        ? 'PDF export failed. Please try again.'
        : name === 'htmx:responseError'
          ? 'The request could not be completed. Your current form is still on this page.'
          : 'The connection was interrupted. We could not confirm whether the request completed. Check your connection and the saved result before trying again.';
      if (typeof failure?.message === 'string') {
        const fields = Array.isArray(failure.fields) ? failure.fields : [];
        message = window.ductCalcRequestErrors.message(failure);
        for (const field of fields) {
          const input = [...(form?.elements || [])].find(input => input.name === field?.name && input.type !== 'hidden');
          if (!input || typeof field.message !== 'string') continue;
          const error = document.createElement('span');
          error.id = `server-field-error-${++fieldErrorID}`;
          error.dataset.serverFieldError = '';
          error.className = 'text-error text-sm';
          error.textContent = field.message;
          input.insertAdjacentElement('afterend', error);
          input.setAttribute('aria-invalid', 'true');
          input.setAttribute('aria-describedby', [input.getAttribute('aria-describedby'), error.id].filter(Boolean).join(' '));
        }
      }
      announce(message, true, elt, Array.isArray(failure?.actions) ? failure.actions : []);
      if (xhr) requests.delete(xhr);
    });
  }
}

if (!window.ductCalcShortcutsInitialized) {
  window.ductCalcShortcutsInitialized = true;
  window.ductCalcKeybindings = () => {
    try { return JSON.parse(document.querySelector('[data-keybindings]')?.dataset.keybindings || '{}'); }
    catch { return {}; }
  };
  window.ductCalcShortcutKey = event => {
    let key = event.key;
    if (key === '?') return '/';
    if (key === ' ') return 'Space';
    if (/^[a-z0-9]$/i.test(key)) return key.toUpperCase();
    // Shift and Option may produce symbols rather than the shortcut's key.
    if (event.shiftKey || event.altKey) {
      if (/^Digit[0-9]$/.test(event.code)) return event.code.slice(5);
      if (event.altKey && /^Key[A-Z]$/.test(event.code)) return event.code.slice(3);
      const punctuation = { Slash:'/', BracketLeft:'[', BracketRight:']', Semicolon:';', Quote:"'", Backquote:'`', Backslash:'\\', Comma:',', Period:'.', Minus:'-', Equal:'=' };
      if (punctuation[event.code]) return punctuation[event.code];
    }
    return key;
  };
  window.ductCalcChord = event => [event.ctrlKey && 'Control', event.altKey && 'Alt',
    event.shiftKey && 'Shift', event.metaKey && 'Meta', window.ductCalcShortcutKey(event)].filter(Boolean).join('+');
  window.ductCalcMatches = (event, action) => {
    const binding = window.ductCalcKeybindings()[action];
    if (!binding) return false;
    const chord = window.ductCalcChord(event);
    return chord === binding;
  };
  const editing = event => event.composedPath().some(node => node instanceof Element && (
    node.isContentEditable || node.matches('input:not([type="search"]), textarea, select, [contenteditable]:not([contenteditable="false"]), [role="textbox"], [role="combobox"], [role="spinbutton"]')));
  const unavailable = control => !control || control.matches(':disabled, [aria-disabled="true"]') || control.closest('[inert]');
  document.addEventListener('keydown', event => {
    if (event.defaultPrevented || event.repeat || event.isComposing || event.getModifierState('AltGraph') || editing(event)) return;
    const chord = window.ductCalcChord(event);
    const matchesControl = control => (control.getAttribute('aria-keyshortcuts') || '').split(' ').includes(chord);
    const dialogs = document.querySelectorAll('dialog[open], [role="dialog"][aria-modal="true"]');
    let control;
    if (dialogs.length) {
      if (dialogs.length !== 1 || dialogs[0].id !== 'frictionRateTemplates') return;
      control = [...dialogs[0].querySelectorAll('button[aria-keyshortcuts]')].find(matchesControl);
    } else if (window.ductCalcMatches(event, 'reveal')) {
      if (window.ductCalcToggleHints?.()) event.preventDefault();
      return;
    } else if (window.ductCalcMatches(event, 'help')) {
      control = document.querySelector('nav button[data-open-dialog][aria-keyshortcuts]');
    } else if (['nextStep', 'previousStep'].some(action => window.ductCalcMatches(event, action))) {
      const steps = [...document.querySelectorAll('#project-sidebar a')];
      const current = steps.findIndex(link => link.getAttribute('aria-current') === 'page');
      if (current < 0) return;
      control = steps[current + (window.ductCalcMatches(event, 'nextStep') ? 1 : -1)];
    } else if (window.ductCalcMatches(event, 'primaryAction')) {
      control = document.querySelector('#project-content [data-project-primary], .project-directory [data-project-primary]');
    } else {
      const fittings = document.getElementById('fittings-page');
      const action = fittings && ['nextGroup', 'previousGroup', 'nextFitting', 'previousFitting'].find(action => window.ductCalcMatches(event, action));
      if (action) {
        const links = [...fittings.querySelectorAll(action.endsWith('Group') ? 'a[data-group]' : 'a[data-select]')];
        const current = links.findIndex(link => ['page','true'].includes(link.getAttribute('aria-current')));
        if (current < 0) return;
        control = links[Math.max(0, Math.min(links.length - 1, current + (action.startsWith('next') ? 1 : -1)))];
      } else {
        control = [...document.querySelectorAll('#project-content button[hx-ext="htmx-download"][aria-keyshortcuts], .equipment-visual button[aria-keyshortcuts], [data-room-workspace] button[aria-keyshortcuts], .path-network a[aria-keyshortcuts], #project-sidebar a[aria-keyshortcuts], #fittings-page a[data-group][aria-keyshortcuts], nav a[aria-keyshortcuts]')].find(matchesControl);
      }
    }
    if (unavailable(control)) return;
    event.preventDefault();
    if (!['page','true'].includes(control.getAttribute('aria-current'))) control.click();
  });

  let recording;
  const form = () => document.getElementById('keybindings-form');
  const status = message => { const node = document.getElementById('keybinding-status'); if (node) node.textContent = message; };
  const keycaps = (button, binding) => {
    button.replaceChildren();
    const caps = document.createElement('span'); caps.className = 'keycaps';
    for (const key of binding.split('+')) {
      const cap = document.createElement('kbd'); cap.className = 'kbd kbd-sm';
      cap.textContent = key === 'Control' ? 'Ctrl' : key === 'Meta' ? 'Command' : key;
      caps.append(cap);
    }
    button.append(caps);
  };
  const cancel = () => {
    if (!recording) return;
    keycaps(recording, recording.dataset.binding);
    recording.removeAttribute('data-recording'); recording = null;
  };
  const conflicts = (row, binding) => [...form().querySelectorAll('[data-keybinding-action]')].find(other => {
    if (other === row || !row.dataset.contexts.split(' ').some(context => other.dataset.contexts.split(' ').includes(context))) return false;
    const otherBinding = other.querySelector('[data-binding]').dataset.binding;
    return binding === otherBinding;
  });
  const write = (row, binding) => {
    const button = row.querySelector('[data-binding]');
    button.dataset.binding = binding; keycaps(button, binding);
    button.setAttribute('aria-label', 'Change ' + row.dataset.title + ' shortcut, ' + binding.replace('Control', 'Ctrl').replace('Meta', 'Command'));
    row.querySelector('[data-reset-keybinding]').disabled = binding === row.dataset.default;
  };
  const serialize = () => {
    const overrides = {};
    for (const row of form().querySelectorAll('[data-keybinding-action]')) {
      const binding = row.querySelector('[data-binding]').dataset.binding;
      if (binding !== row.dataset.default) overrides[row.dataset.keybindingAction] = binding;
    }
    form().elements.bindings.value = JSON.stringify({ overrides });
  };
  document.addEventListener('click', event => {
    const button = event.target.closest('#keybindings-form button');
    if (!button || button.disabled) return;
    const wasRecording = recording === button; cancel();
    if (button.matches('[data-binding]')) {
      if (wasRecording) { status('Recording canceled.'); return; }
      recording = button; button.dataset.recording = ''; button.textContent = 'Press keys…';
      status('Press a combination for ' + button.closest('[data-title]').dataset.title + '. Escape cancels.');
    } else if (button.matches('[data-reset-keybinding]')) {
      const row = button.closest('[data-keybinding-action]');
      const conflict = conflicts(row, row.dataset.default);
      if (conflict) { status('Reset would conflict with ' + conflict.dataset.title + '. Change that binding first.'); return; }
      write(row, row.dataset.default); serialize(); status('Default restored. Save to apply.');
    } else if (button.matches('[data-reset-keybindings]')) {
      for (const row of form().querySelectorAll('[data-keybinding-action]')) write(row, row.dataset.default);
      serialize(); status('Defaults restored. Save to apply.');
    }
  });
  document.addEventListener('keydown', event => {
    if (!recording?.isConnected) { recording = null; return; }
    if (event.key === 'Tab') { cancel(); status('Recording canceled.'); return; }
    event.preventDefault(); event.stopImmediatePropagation();
    if (event.key === 'Escape') { cancel(); status('Recording canceled.'); return; }
    if (event.repeat || event.isComposing || event.getModifierState('AltGraph') || ['Control','Alt','Shift','Meta'].includes(event.key)) return;
    const key = window.ductCalcShortcutKey(event);
    const named = ['ArrowUp','ArrowDown','ArrowLeft','ArrowRight','Home','End','PageUp','PageDown','Insert','Delete','Backspace','Enter','Space'];
    if (!(event.ctrlKey || event.altKey || event.metaKey) || !(/^[A-Z0-9/\[\];='`\\,.-]$/.test(key) || named.includes(key) || /^F([1-9]|1[0-2])$/.test(key))) {
      status('Use Ctrl, Alt, or Command with a letter, number, punctuation, arrow, or function key.'); return;
    }
    const binding = window.ductCalcChord(event), row = recording.closest('[data-keybinding-action]');
    const conflict = conflicts(row, binding);
    if (conflict) { status('Already used by ' + conflict.dataset.title + ' in this context. Press another combination or Escape.'); return; }
    cancel(); write(row, binding); serialize(); status('Shortcut changed. Save to apply.');
  }, true);
  document.addEventListener('focusout', event => {
    if (event.target === recording) { cancel(); status('Recording canceled.'); }
  });
  document.addEventListener('submit', event => {
    if (event.target !== form()) return;
    cancel(); serialize();
  }, true);
  document.addEventListener('input', event => {
    if (event.target.id !== 'keybinding-search') return;
    const query = event.target.value.trim().toLowerCase();
    for (const row of form().querySelectorAll('[data-keybinding-action]')) row.hidden = !row.dataset.title.toLowerCase().includes(query);
    for (const section of form().querySelectorAll('.keybindings-section')) section.hidden = !section.querySelector('[data-keybinding-action]:not([hidden])');
    document.getElementById('keybinding-empty').hidden = !!form().querySelector('[data-keybinding-action]:not([hidden])');
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
    if (event.defaultPrevented || event.repeat || event.isComposing || event.getModifierState('AltGraph') || document.querySelector('dialog[open], [role="dialog"][aria-modal="true"]')) return;
    const editing = event.composedPath().some(node => node instanceof Element && node.matches('input:not([type="search"]),textarea,select,[contenteditable]:not([contenteditable="false"]),[role="textbox"],[role="combobox"],[role="spinbutton"]'));
    if (window.ductCalcMatches(event, 'search')) {
      const search = document.getElementById('keybinding-search') || document.getElementById('project-search') || document.getElementById('room-search') || document.getElementById('register-search');
      if (search && !search.disabled && !search.closest('[inert]') && (!editing || event.target === search)) { event.preventDefault(); search.focus(); search.select(); }
    } else if (!editing && ['nextRoom', 'previousRoom'].some(action => window.ductCalcMatches(event, action))) {
      const table = document.querySelector('[data-selectable-table="rooms"]');
      if (!table || table.closest('[inert]')) return;
      const visible = rows(table).filter(row => !row.hidden);
      if (!visible.length) return;
      const current = visible.findIndex(row => row.classList.contains('selected-row'));
      const next = current < 0 ? 0 : Math.max(0, Math.min(visible.length - 1, current + (window.ductCalcMatches(event, 'nextRoom') ? 1 : -1)));
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
  document.addEventListener('reset', event => dirtyForms.delete(event.target));
  window.addEventListener('beforeunload', event => {
    prune();
    if (dirtyForms.size) { event.preventDefault(); event.returnValue = ''; }
  });
  document.addEventListener('htmx:afterSettle', prune);
}
