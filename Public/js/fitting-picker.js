/* Draft state and UI only. All catalog evaluation is performed by FittingClient. */
(() => {
  function initialize() {
    const root = document.querySelector('#fitting-picker');
    if (!root || root.dataset.initialized) return;
    root.dataset.initialized = 'true';
    const $ = (selector) => root.querySelector(selector);
    const pathType = root.dataset.pathType;
    const storageKey = `fitting-picker.v1.${pathType}`;
    const dialog = $('#fp-dialog'), referenceDialog = $('#fp-reference-dialog');
    let state = { straightLength: 0, rows: [] };
    let editID = null, controller, generation = 0, timer;
    const number = (value) => new Intl.NumberFormat(undefined, { maximumFractionDigits: 12 }).format(value);
    const announce = (text) => { $('#fp-announcement').textContent = text; };
    const element = (tag, text, className) => {
      const node = document.createElement(tag);
      if (text !== undefined) node.textContent = text;
      if (className) node.className = className;
      return node;
    };
    function validRow(row) {
      return row && typeof row.name === 'string' && typeof row.id === 'string' &&
        Number.isFinite(row.feet) && row.feet >= 0 && Number.isSafeInteger(row.quantity) && row.quantity > 0 &&
        Number.isFinite(row.feet * row.quantity) && Number.isInteger(row.groupID) &&
        ['catalog', 'referenceEntry'].includes(row.origin);
    }
    try {
      const saved = JSON.parse(sessionStorage.getItem(storageKey));
      if (saved && Number.isFinite(saved.straightLength) && saved.straightLength >= 0 &&
        Array.isArray(saved.rows) && saved.rows.every(validRow) &&
        Number.isFinite(saved.rows.reduce((sum, row) => sum + row.feet * row.quantity, saved.straightLength))) state = saved;
    } catch { /* Storage may be unavailable; an in-memory draft still works. */ }
    function persist() {
      try { sessionStorage.setItem(storageKey, JSON.stringify(state)); }
      catch { $('.fp-notice').textContent = 'This draft is in memory only. Download it before leaving this page.'; }
    }
    function total() { return state.rows.reduce((sum, row) => sum + row.feet * row.quantity, state.straightLength); }
    function render() {
      const rows = $('#fp-rows'); rows.replaceChildren();
      for (const row of state.rows) {
        const item = element('li', undefined, 'fp-path-row');
        const title = element('div', undefined, 'fp-row-title');
        if (row.artwork && row.artwork.startsWith('/images/fittings/')) {
          const img = element('img'); img.src = row.artwork; img.alt = ''; title.append(img);
        }
        const heading = element('div');
        heading.append(element('strong', row.sourceCode || `Group ${row.groupID}`), element('p', row.name));
        title.append(heading); item.append(title);
        item.append(element('small', `${row.origin === 'catalog' ? 'Calculated' : 'Entered'}${row.column ? ` · ${row.column}` : ''} · ${number(row.feet)} ft each`));
        const pair = row.calculation?.derivation?.scaled;
        if (pair) item.append(element('p', `Matching ${pair.base.sourceCode || '90°'} elbows: ${number(pair.base.equivalentLengthFeet)} ft × ${number(pair.multiplier)}.`, 'fp-note'));
        if (Array.isArray(row.details) && row.details.length) {
          const details = element('details', undefined, 'fp-row-details'); details.append(element('summary', 'Selected inputs'));
          for (const line of row.details) details.append(element('p', line));
          item.append(details);
        }
        if (row.calculation?.minimumUpstreamStaticPressureIWC != null) item.append(element('p', `Requires ≥ ${number(row.calculation.minimumUpstreamStaticPressureIWC)} IWC upstream.`, 'fp-note'));
        const actions = element('div', undefined, 'fp-row-actions');
        const label = element('label', 'Qty '), quantity = element('input');
        quantity.type = 'number'; quantity.min = '1'; quantity.step = '1'; quantity.value = row.quantity;
        quantity.setAttribute('aria-label', `Quantity for ${row.sourceCode || row.name}`);
        quantity.addEventListener('change', () => {
          const value = Number(quantity.value), previous = row.quantity;
          if (!Number.isSafeInteger(value) || value < 1) { quantity.value = previous; announce('Quantity must be a positive whole number.'); return; }
          row.quantity = value;
          if (!Number.isFinite(total())) { row.quantity = previous; quantity.value = previous; announce('This quantity is too large.'); return; }
          persist(); render();
        });
        label.append(quantity); actions.append(label, element('strong', `${number(row.feet * row.quantity)} ft`));
        const edit = element('button', 'Edit', 'fp-quiet'); edit.type = 'button';
        edit.addEventListener('click', () => {
          editID = row.id;
          if (row.origin === 'referenceEntry') openReference(row);
          else configure(row.fittingID, row.groupID, row.fields || {});
        });
        const remove = element('button', 'Remove', 'fp-quiet'); remove.type = 'button';
        remove.setAttribute('aria-label', `Remove ${row.sourceCode || row.name}`);
        remove.addEventListener('click', () => { state.rows = state.rows.filter((entry) => entry.id !== row.id); persist(); render(); announce('Fitting removed.'); });
        actions.append(edit, remove); item.append(actions); rows.append(item);
      }
      $('#fp-straight').value = state.straightLength;
      $('#fp-empty').hidden = state.rows.length > 0;
      $('#fp-count').textContent = `${state.rows.reduce((sum, row) => sum + row.quantity, 0)} fittings`;
      $('#fp-total').textContent = `${number(total())} ft`;
      $('#fp-download').disabled = !state.rows.length && !state.straightLength;
      const counts = new Map();
      for (const row of state.rows) counts.set(row.groupID, (counts.get(row.groupID) || 0) + row.quantity);
      const repeated = [...counts].filter(([group, count]) => group !== 8 && count > 1).map(([group]) => group);
      const warning = $('#fp-duplicate-warning'); warning.hidden = !repeated.length;
      warning.textContent = `Repeated groups: ${repeated.join(', ')}. Check that these contributions belong on the same path.`;
    }
    $('#fp-straight').addEventListener('change', (event) => {
      const value = Number(event.target.value), previous = state.straightLength;
      if (!Number.isFinite(value) || value < 0) { event.target.value = previous; announce('Straight duct length must be zero or greater.'); return; }
      state.straightLength = value;
      if (!Number.isFinite(total())) { state.straightLength = previous; announce('This length is too large.'); }
      persist(); render();
    });
    $('#fp-clear').addEventListener('click', () => { state = { straightLength: 0, rows: [] }; persist(); render(); announce('Path cleared.'); });
    $('#fp-download').addEventListener('click', () => {
      const url = URL.createObjectURL(new Blob([JSON.stringify({ schemaVersion: 1, pathType, ...state }, null, 2)], { type: 'application/json' }));
      const link = element('a'); link.href = url; link.download = `duct-${pathType}-draft.json`; link.click();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    });
    function filter() {
      const query = $('#fp-search').value.toLowerCase().trim();
      const active = $('[data-group].is-active')?.dataset.group;
      let matches = 0;
      for (const panel of root.querySelectorAll('[data-panel]')) {
        panel.hidden = !query && panel.dataset.panel !== active;
        for (const card of panel.querySelectorAll('[data-fitting-id]')) {
          card.hidden = !card.dataset.search.toLowerCase().includes(query);
          if (!panel.hidden && !card.hidden) matches++;
        }
        if (query) panel.hidden = ![...panel.querySelectorAll('[data-fitting-id]')].some((card) => !card.hidden);
      }
      $('#fp-no-matches').hidden = matches > 0;
      $('#fp-no-matches').textContent = query ? 'No matching fittings. Try another code or name.' : 'No matching fittings in this group.';
    }
    root.querySelectorAll('[data-group]').forEach((button) => button.addEventListener('click', () => {
      root.querySelectorAll('[data-group]').forEach((other) => { other.classList.toggle('is-active', other === button); other.setAttribute('aria-pressed', String(other === button)); });
      $('#fp-search').value = ''; filter();
    }));
    $('#fp-search').addEventListener('input', filter);
    root.querySelectorAll('[data-fitting-id]').forEach((card) => card.addEventListener('click', () => { editID = null; configure(card.dataset.fittingId, Number(card.dataset.fittingGroup), {}); }));
    function cancel() { clearTimeout(timer); controller?.abort(); generation++; }
    async function post(action, payload, target) {
      controller?.abort(); controller = new AbortController(); const current = ++generation;
      target.setAttribute('aria-busy', 'true');
      try {
        const response = await fetch(`/fittings/${action}`, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ payload: JSON.stringify(payload) }), signal: controller.signal });
        if (!response.ok) throw new Error('Request failed');
        const html = await response.text();
        if (current !== generation) return false;
        // Only escaped, server-rendered fragments from this app enter innerHTML.
        target.innerHTML = html; return true;
      } catch (error) {
        if (error.name !== 'AbortError' && current === generation) target.replaceChildren(element('p', 'Unable to load the fitting. Please try again.', 'fp-error'));
        return false;
      } finally { if (current === generation) target.removeAttribute('aria-busy'); }
    }
    function formFields(form) {
      const fields = Object.fromEntries(new FormData(form));
      form.querySelectorAll('input[type="checkbox"]').forEach((input) => { fields[input.name] = String(input.checked); });
      return fields;
    }
    function updateArtwork(form) {
      const fields = formFields(form);
      for (const name of ['bendVelocity', 'bendRadiusRatio']) {
        const control = form.querySelector(`[data-field="${name}"]`); if (control) control.hidden = fields.suppliedBend !== 'true';
      }
      const view = fields.suppliedBend === 'true' ? 'supplied-bend' : fields.artworkView || 'individual';
      const art = JSON.parse(form.dataset.artworks).find((item) => item.view === view);
      const image = $('#fp-active-art');
      if (art && image) { image.src = `${art.publicPath}?v=${encodeURIComponent(art.revision)}`; image.alt = art.altText; }
    }
    async function evaluate() {
      clearTimeout(timer);
      const form = $('#fp-config-form'); if (!form) return;
      const target = $('#fp-result'); target.replaceChildren(element('p', 'Checking selection…'));
      await post('evaluate', { pathType, groupID: Number(form.dataset.group), fittingID: form.dataset.id, fields: formFields(form) }, target);
    }
    async function configure(fittingID, groupID, fields) {
      cancel();
      const target = $('#fp-config'); target.replaceChildren(element('h2', 'Loading fitting…'));
      target.firstChild.id = 'fp-dialog-title';
      if (!dialog.open) dialog.showModal();
      if (!await post('configure', { pathType, fittingID, groupID, fields }, target)) return;
      const form = $('#fp-config-form'); if (!form) return;
      updateArtwork(form);
      form.querySelector('select, input:not([type="hidden"]), button')?.focus({ preventScroll: true });
      form.addEventListener('submit', (event) => { event.preventDefault(); evaluate(); });
      form.addEventListener('input', () => {
        cancel(); $('#fp-result').replaceChildren(element('p', 'Checking selection…')); updateArtwork(form);
        timer = setTimeout(evaluate, 200);
      });
      form.addEventListener('change', (event) => {
        if (event.target.name === 'baseFitting') configure(fittingID, groupID, { baseFitting: event.target.value });
      });
      evaluate();
    }
    function openReference(row) {
      cancel();
      const form = $('#fp-reference-form'); form.elements.code.value = row?.sourceCode || ''; form.elements.length.value = row?.feet ?? '';
      $('#fp-reference-result').replaceChildren(); referenceDialog.showModal();
    }
    $('#fp-reference-open').addEventListener('click', () => { editID = null; openReference(); });
    $('#fp-reference-form').addEventListener('input', () => { cancel(); $('#fp-reference-result').replaceChildren(); });
    $('#fp-reference-form').addEventListener('submit', async (event) => {
      event.preventDefault(); const fields = formFields(event.target);
      $('#fp-reference-result').replaceChildren(element('p', 'Checking entry…'));
      await post('reference', { pathType, ...fields }, $('#fp-reference-result'));
    });
    root.addEventListener('click', (event) => {
      const button = event.target.closest('[data-row]'); if (!button || button.disabled) return;
      const row = JSON.parse(button.dataset.row);
      const previous = state.rows.find((item) => item.id === editID);
      const next = { ...row, id: previous?.id || (globalThis.crypto?.randomUUID?.() || `${Date.now()}-${Math.random()}`), quantity: previous?.quantity || 1 };
      const nextRows = previous ? state.rows.map((item) => item.id === previous.id ? next : item) : [...state.rows, next];
      if (!validRow(next) || !Number.isFinite(nextRows.reduce((sum, item) => sum + item.feet * item.quantity, state.straightLength))) { announce('This selection exceeds the supported total.'); return; }
      button.disabled = true; state.rows = nextRows; persist(); render();
      dialog.close(); referenceDialog.close(); announce(previous ? 'Fitting updated.' : 'Fitting added to path.');
    });
    $('[data-close-picker]').addEventListener('click', () => dialog.close());
    $('[data-close-reference]').addEventListener('click', () => referenceDialog.close());
    for (const modal of [dialog, referenceDialog]) modal.addEventListener('close', cancel);
    render();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize);
  else initialize();
})();
