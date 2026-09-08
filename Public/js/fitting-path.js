/* Application path state only. Swift renders rows/cards and owns all fitting rules. */
(() => {
  function initialize() {
    const root = document.querySelector('#fitting-path');
    if (!root || root.dataset.initialized) return;
    root.dataset.initialized = 'true';
    const $ = selector => root.querySelector(selector);
    const baseline = JSON.parse(root.dataset.baseline), endpoint = root.dataset.endpoint;
    let entries = JSON.parse(root.dataset.rows), favorites = new Set(JSON.parse(root.dataset.favorites));
    let editing = null, dirty = false, busy = false, browserRequest = 0, rowsRequest = 0, editRequest = 0;
    const requests = new WeakMap(), timers = new WeakMap(), favoriteRequests = new Set();
    let favoriteTemplates = new Map();
    const templateModal = window.FittingTemplateModal.create(root, {
      endpoint, hasDraft: () => dirty,
      finish: url => { dirty = false; root.close(); location.assign(url); }
    });
    const preferenceKey = 'fitting-picker.shape-preference.v1';
    let shapePreference = 'none';
    try {
      const stored = localStorage.getItem(preferenceKey);
      if (['none', 'round', 'rectangular'].includes(stored)) shapePreference = stored;
    } catch { /* Browser storage is optional; keep the preference for this editor session. */ }
    root.querySelectorAll('[name="shape-preference"]').forEach(input => { input.checked = input.value === shapePreference; });
    const pathType = () => $('#path-type').value;
    const number = value => new Intl.NumberFormat(undefined, { maximumFractionDigits: 12 }).format(value);
    const status = text => { $('#path-status').textContent = text; };
    const parseStraight = () => {
      const text = $('#path-straight').value.trim();
      if (!text) return [];
      const values = text.split(',').map(value => value.trim());
      if (values.length > 100 || values.some(value => !/^\d+$/.test(value) || !Number.isSafeInteger(Number(value)) || Number(value) <= 0)) throw Error('Straight lengths must be positive whole feet, separated by commas.');
      return values.map(Number);
    };
    async function post(url, payload, signal) {
      const response = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ payload: JSON.stringify(payload) }), signal });
      if (!response.ok || response.redirected) throw Error('Request failed. Check your connection or sign in again. Your draft is still on this page.');
      return response.text();
    }
    function updateTotals() {
      const fittingTotal = entries.reduce((sum, entry) => sum + entry.row.feet * entry.quantity, 0);
      $('#fittings-total').textContent = `${number(fittingTotal)} ft`;
      try {
        const straight = parseStraight().reduce((sum, length) => sum + length, 0);
        $('#straight-total').textContent = `${number(straight)} ft`;
        $('#path-total').textContent = `${number(straight + fittingTotal)} ft`;
        $('#path-straight').setCustomValidity('');
      } catch (error) { $('#path-total').textContent = 'Check straight lengths'; $('#path-straight').setCustomValidity(error.message); }
      const counts = new Map();
      for (const entry of entries) counts.set(entry.row.groupID, (counts.get(entry.row.groupID) || 0) + entry.quantity);
      const coverage = $('#group-coverage'); coverage.replaceChildren();
      for (const [group, count] of [...counts].sort((a, b) => a[0] - b[0])) {
        const badge = document.createElement('span'); badge.className = 'coverage-chip';
        badge.textContent = `Group ${group} · ${count}`;
        if ([1,2,3,5,6].includes(group) && count > 1) { badge.classList.add('coverage-warning'); badge.textContent += ' · Check repeated use'; }
        coverage.append(badge);
      }
      root.querySelectorAll('[data-group-state]').forEach(node => {
        const group = Number(node.dataset.groupState), count = counts.get(group) || 0;
        node.textContent = count ? `${count} in this path` : 'None in this path';
        node.classList.toggle('repeated-group', [1,2,3,5,6].includes(group) && count > 1);
      });
    }
    async function renderRows() {
      updateTotals(); const current = ++rowsRequest;
      try {
        const html = await post('/fittings/rows', entries);
        if (current === rowsRequest) {
          const active = document.activeElement;
          const focus = $('#path-rows').contains(active) ? ['quantity', 'editRow', 'removeRow'].find(key => active.dataset[key]) : null;
          const value = focus ? active.dataset[focus] : null;
          $('#path-rows').innerHTML = html;
          if (focus) [...$('#path-rows').querySelectorAll('input,button')].find(node => node.dataset[focus] === value)?.focus({ preventScroll: true });
        }
      } catch (error) { status(error.message); }
    }
    function showGroups() {
      $('#group-selectors').hidden = false; $('#fitting-browser').hidden = true; $('#picker-dialog').scrollTop = 0;
      root.querySelectorAll('[data-path-carousel]').forEach(node => { node.hidden = node.dataset.pathCarousel !== pathType(); });
    }
    root.querySelectorAll('.group-carousel').forEach(window.initializeGroupCarousel);
    function openPicker() { editing = null; showGroups(); $('#picker-status').textContent = ''; $('#picker-dialog').showModal(); }
    function formFields(form) {
      const fields = Object.fromEntries(new FormData(form));
      form.querySelectorAll('input[type=checkbox]').forEach(input => { fields[input.name] = String(input.checked); });
      return fields;
    }
    function updateArtwork(configuration) {
      const form = configuration.querySelector('.fp-config-form'), fields = formFields(form);
      for (const name of ['bendVelocity', 'bendRadiusRatio']) {
        const field = form.querySelector(`[data-field="${name}"]`); if (field) field.hidden = fields.suppliedBend !== 'true';
      }
      const view = fields.suppliedBend === 'true' ? 'supplied-bend' : fields.artworkView || 'individual';
      const art = JSON.parse(form.dataset.artworks).find(item => item.view === view);
      const image = configuration.querySelector('.fp-active-art');
      if (art && image) { image.src = `${art.publicPath}?v=${encodeURIComponent(art.revision)}`; image.alt = art.altText; }
    }
    function invalidate(configuration) {
      clearTimeout(timers.get(configuration)); requests.get(configuration)?.abort();
      configuration.querySelector('.fp-result').textContent = 'Checking inputs…';
    }
    async function evaluate(configuration) {
      const form = configuration.querySelector('.fp-config-form');
      if (!form || !configuration.isConnected) return;
      invalidate(configuration); const controller = new AbortController(); requests.set(configuration, controller);
      try {
        const html = await post('/fittings/evaluate', { pathType: pathType(), groupID: Number(form.dataset.group), fittingID: form.dataset.id, fields: formFields(form) }, controller.signal);
        if (requests.get(configuration) === controller && configuration.isConnected) configuration.querySelector('.fp-result').innerHTML = html;
      } catch (error) { if (error.name !== 'AbortError') configuration.querySelector('.fp-result').textContent = error.message; }
    }
    async function reconfigure(configuration, fields) {
      const form = configuration.querySelector('.fp-config-form'); invalidate(configuration);
      const controller = new AbortController(); requests.set(configuration, controller);
      try {
        const html = await post('/fittings/configure', { pathType: pathType(), fittingID: form.dataset.id, groupID: Number(form.dataset.group), fields }, controller.signal);
        if (requests.get(configuration) !== controller || !configuration.isConnected) return;
        const template = document.createElement('template'); template.innerHTML = html;
        const next = template.content.querySelector('.fitting-configuration');
        if (!next) { configuration.querySelector('.fp-result').innerHTML = html; return; }
        configuration.replaceWith(next); bindConfiguration(next); evaluate(next);
      } catch (error) { if (error.name !== 'AbortError') configuration.querySelector('.fp-result').textContent = error.message; }
    }
    function bindConfiguration(configuration, initial = false) {
      const form = configuration.querySelector('.fp-config-form'); if (!form) return;
      updateArtwork(configuration);
      if (initial) {
        const template = configuration.closest('.art-card').querySelector('.initial-result');
        configuration.querySelector('.fp-result').replaceChildren(template.content.cloneNode(true));
      }
      form.addEventListener('submit', event => { event.preventDefault(); evaluate(configuration); });
      form.addEventListener('input', event => {
        invalidate(configuration); updateArtwork(configuration);
        if (event.target.name !== 'baseFitting') timers.set(configuration, setTimeout(() => evaluate(configuration), 180));
      });
      form.addEventListener('change', event => {
        if (event.target.name === 'baseFitting') reconfigure(configuration, { baseFitting: event.target.value });
      });
      const card = configuration.closest('[data-fixed="true"]');
      if (card) {
        const image = configuration.querySelector('.fp-active-art');
        image.tabIndex = 0; image.setAttribute('role', 'button'); image.setAttribute('aria-label', 'Add this fitting to path');
        const add = () => configuration.querySelector('[data-row]')?.click();
        image.addEventListener('click', add); image.addEventListener('keydown', event => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); add(); } });
      }
    }
    function shapeRank(card) {
      if (shapePreference === 'none' || card.dataset.ductShape === shapePreference) return 0;
      return ['mixed', 'schematic'].includes(card.dataset.ductShape) ? 1 : 2;
    }
    const compareCards = (a, b) => shapeRank(a) - shapeRank(b) || Number(a.dataset.order) - Number(b.dataset.order);
    function updateFavoriteButtons() {
      root.querySelectorAll('[data-favorite]').forEach(button => {
        const selected = favorites.has(button.dataset.favorite);
        button.setAttribute('aria-pressed', String(selected)); button.textContent = selected ? '★ Favorite' : '☆ Favorite';
        button.disabled = favoriteRequests.has(button.dataset.favorite);
      });
    }
    function syncFavorites(anchor) {
      const grid = $('#fitting-browser .favorite-grid'); if (!grid) return;
      const top = anchor?.isConnected ? anchor.getBoundingClientRect().top : null;
      const active = document.activeElement;
      const existing = new Map([...grid.querySelectorAll('[data-favorite-copy]')].map(card => [card.dataset.favoriteCopy, card]));
      for (const [id, card] of existing) {
        if (!favorites.has(id)) { card.remove(); existing.delete(id); }
      }
      for (const [id, template] of favoriteTemplates) {
        if (!favorites.has(id) || existing.has(id)) continue;
        // Each copy starts with the catalog defaults and owns its own draft inputs.
        const card = template.cloneNode(true); card.dataset.favoriteCopy = id; delete card.dataset.catalogId;
        grid.append(card); bindConfiguration(card.querySelector('.fitting-configuration'), true);
      }
      [...grid.children].sort(compareCards).forEach(card => grid.append(card));
      $('#catalog-favorite-count').textContent = grid.children.length;
      updateFavoriteButtons(); filterFittings();
      if (active?.isConnected && grid.contains(active)) active.focus({ preventScroll: true });
      else if (active && !active.isConnected) $('#catalog-favorites-title').focus({ preventScroll: true });
      // Adding/removing copies above the catalog must not move the source card
      // on screen. Measure after the browser's own scroll anchoring has run.
      if (top !== null && anchor.isConnected) $('#picker-dialog').scrollTop += anchor.getBoundingClientRect().top - top;
    }
    function sortFittings() {
      const grid = $('#catalog-grid'); if (!grid) return;
      const active = document.activeElement;
      [...grid.children].sort(compareCards).forEach(card => grid.append(card));
      syncFavorites();
      if (active && grid.contains(active)) active.focus({ preventScroll: true });
    }
    function filterFittings() {
      const target = $('#fitting-browser'), query = $('#catalog-search')?.value.trim().toLowerCase() || '';
      let count = 0, favoriteCount = 0;
      target.querySelectorAll('[data-catalog-id], [data-favorite-copy]').forEach(card => {
        card.hidden = !card.dataset.search.toLowerCase().includes(query);
        if (!card.hidden) { if (card.dataset.favoriteCopy) favoriteCount++; else count++; }
      });
      if ($('#catalog-empty')) $('#catalog-empty').hidden = count > 0;
      if ($('#favorites-empty')) {
        $('#favorites-empty').hidden = favoriteCount > 0;
        $('#favorites-empty').textContent = $('#catalog-favorite-count').textContent === '0' ? 'Star a fitting to keep a copy here.' : 'No favorites match your search.';
      }
    }
    async function chooseGroup(groupID) {
      const current = ++browserRequest; $('#group-selectors').hidden = true;
      const target = $('#fitting-browser'); target.hidden = false; target.textContent = 'Loading fittings…';
      try {
        const html = await post('/fittings/group', { pathType: pathType(), groupID });
        if (current !== browserRequest) return;
        target.innerHTML = html; $('#picker-dialog').scrollTop = 0;
        favoriteTemplates = new Map();
        target.querySelectorAll('[data-catalog-id]').forEach((card, index) => {
          card.dataset.order = index; favoriteTemplates.set(card.dataset.catalogId, card.cloneNode(true));
        });
        target.querySelectorAll('.fitting-configuration').forEach(configuration => bindConfiguration(configuration, true));
        sortFittings();
        $('#catalog-search')?.addEventListener('input', filterFittings);
      } catch (error) { target.textContent = error.message; }
    }
    function openReference(entry) {
      const form = $('#reference-form'); form.elements.code.value = entry?.row.sourceCode || ''; form.elements.length.value = entry?.row.feet ?? '';
      $('#reference-result').replaceChildren(); $('#reference-dialog').showModal();
    }
    function closeEditor() {
      if (templateModal.active) { templateModal.close(); return; }
      if (busy || (dirty && !window.confirm('Discard unsaved changes to this path?'))) return;
      dirty = false; root.close(); location.assign(endpoint);
    }
    $('#path-from-template')?.addEventListener('click', event => {
      event.preventDefault();
      if (busy) return;
      try {
        const draft = { name: $('#path-name').value, straightLengths: parseStraight() };
        const url = new URL(event.currentTarget.href);
        url.search = `?draft=${encodeURIComponent(JSON.stringify(draft))}`;
        status('Loading templates…');
        templateModal.open(url.href);
      } catch (error) { status(error.message); $('#path-straight').focus(); }
    });
    root.addEventListener('cancel', event => {
      if (event.target !== root) return;
      event.preventDefault(); closeEditor();
    });
    root.addEventListener('click', async event => {
      if (templateModal.active) return;
      const button = event.target.closest('button'); if (!button || button.disabled) return;
      if (button.id === 'close-path') { closeEditor(); return; }
      if (button.dataset.closeDialog) { editRequest++; $(`#${button.dataset.closeDialog}`).close(); return; }
      if (button.hasAttribute('data-open-picker')) { openPicker(); return; }
      if (button.id === 'choose-groups') { browserRequest++; showGroups(); return; }
      if (button.dataset.chooseGroup) { chooseGroup(Number(button.dataset.chooseGroup)); return; }
      if (button.dataset.favorite) {
        const id = button.dataset.favorite, selected = !favorites.has(id), hadFocus = document.activeElement === button;
        if (favoriteRequests.has(id)) return;
        favoriteRequests.add(id); updateFavoriteButtons();
        try {
          const html = await post(`${endpoint}/favorite`, { fittingID: id, selected });
          if (!html.includes('data-favorite-saved')) throw Error('Favorite could not be saved. Please try again.');
          if (selected) favorites.add(id); else favorites.delete(id);
          syncFavorites(button.closest('[data-catalog-id]'));
        } catch (error) { $('#picker-status').textContent = error.message; }
        finally {
          favoriteRequests.delete(id); updateFavoriteButtons();
          if (hadFocus && [document.body, root, $('#picker-dialog')].includes(document.activeElement)) {
            (button.isConnected ? button : $('#catalog-favorites-title'))?.focus({ preventScroll: true });
          }
        } return;
      }
      if (button.dataset.row) {
        const row = JSON.parse(button.dataset.row), previous = entries.find(entry => entry.id === editing);
        const next = { id: previous?.id || (globalThis.crypto?.randomUUID?.() || `${Date.now()}-${Math.random()}`), quantity: previous?.quantity || 1, savedIndex: null, replacesIndex: previous?.savedIndex ?? previous?.replacesIndex ?? null, row };
        const nextEntries = previous ? entries.map(entry => entry.id === previous.id ? next : entry) : [...entries, next];
        if (nextEntries.length > 500 || !Number.isFinite(nextEntries.reduce((sum, entry) => sum + entry.row.feet * entry.quantity, 0))) { status('This path exceeds the supported limit.'); return; }
        button.disabled = true; entries = nextEntries; dirty = true;
        $('#picker-dialog').close(); $('#edit-dialog').close(); $('#reference-dialog').close();
        await renderRows();
        if (previous) [...root.querySelectorAll('[data-edit-row]')].find(node => node.dataset.editRow === previous.id)?.focus({ preventScroll: true });
        status(previous ? 'Fitting updated. Save the path to keep this change.' : 'Fitting added.'); return;
      }
      if (button.dataset.removeRow) { button.closest('.path-row')?.remove(); entries = entries.filter(entry => entry.id !== button.dataset.removeRow); dirty = true; renderRows(); return; }
      if (button.dataset.editRow) {
        const entry = entries.find(entry => entry.id === button.dataset.editRow); if (!entry) return; editing = entry.id; const currentEdit = ++editRequest;
        if (entry.row.origin !== 'catalog') { openReference(entry); return; }
        const target = $('#edit-fitting'); target.textContent = 'Loading fitting…'; $('#edit-dialog').showModal();
        try {
          const html = await post('/fittings/configure', { pathType: pathType(), groupID: entry.row.groupID, fittingID: entry.row.fittingID, fields: entry.row.fields || {} });
          if (currentEdit !== editRequest || !$('#edit-dialog').open) return;
          target.innerHTML = html;
          const configuration = target.querySelector('.fitting-configuration'); if (configuration) { bindConfiguration(configuration); evaluate(configuration); }
        } catch (error) { target.textContent = error.message; } return;
      }
      if (button.id === 'quick-entry-open') { editing = null; openReference(); return; }
      if (button.id === 'save-path' && !busy) {
        let straightLengths;
        try { straightLengths = parseStraight(); } catch (error) { status(error.message); $('#path-straight').reportValidity(); return; }
        if (!$('#path-name').reportValidity()) return;
        busy = true; button.disabled = true; status('Saving path…'); root.inert = true;
        try {
          const html = await post(`${endpoint}/save-path`, { baseline, name: $('#path-name').value, pathType: pathType(), straightLengths, entries });
          const template = document.createElement('template'); template.innerHTML = html;
          const saved = template.content.querySelector('[data-saved-path]');
          if (saved) { dirty = false; location.assign(endpoint); }
          else $('#path-status').replaceChildren(template.content);
        } catch (error) { status(error.message); }
        finally { busy = false; root.inert = false; button.disabled = false; }
      }
    });
    root.addEventListener('change', event => {
      if (templateModal.active) return;
      if (event.target.name === 'shape-preference') {
        shapePreference = event.target.value;
        try { localStorage.setItem(preferenceKey, shapePreference); } catch { /* Session-only fallback. */ }
        sortFittings();
        return;
      }
      if (event.target.dataset.quantity) {
        const entry = entries.find(entry => entry.id === event.target.dataset.quantity), quantity = Number(event.target.value);
        if (!entry) return;
        if (!Number.isSafeInteger(quantity) || quantity < 1 || quantity > 1000000 || !Number.isFinite(entry.row.feet * quantity)) { event.target.value = entry.quantity; status('Quantity must be between 1 and 1,000,000.'); return; }
        entry.quantity = quantity; dirty = true; renderRows();
      }
      if (['path-name','path-straight','path-type'].includes(event.target.id)) {
        dirty = true; updateTotals();
        if (event.target.id === 'path-type') { $('#path-fitting-reference').href = '/fittings?' + new URLSearchParams({ system: pathType() }); browserRequest++; showGroups(); status('The path type changed. Existing rows are retained; incompatible rows must be removed or the original type restored before saving.'); }
      }
    });
    $('#path-name').addEventListener('input', () => { dirty = true; });
    $('#path-straight').addEventListener('input', () => { dirty = true; updateTotals(); });
    $('#edit-dialog').addEventListener('close', () => { editRequest++; });
    let referenceController;
    $('#reference-form').addEventListener('input', () => { referenceController?.abort(); $('#reference-result').replaceChildren(); });
    $('#reference-form').addEventListener('submit', async event => {
      event.preventDefault(); referenceController?.abort(); referenceController = new AbortController();
      const controller = referenceController; $('#reference-result').textContent = 'Checking entry…';
      try {
        const html = await post('/fittings/reference', { pathType: pathType(), ...Object.fromEntries(new FormData(event.target)) }, controller.signal);
        if (referenceController === controller) $('#reference-result').innerHTML = html;
      } catch (error) { if (error.name !== 'AbortError') $('#reference-result').textContent = error.message; }
    });
    window.addEventListener('beforeunload', event => { if (dirty) { event.preventDefault(); event.returnValue = ''; } });
    showGroups(); updateTotals(); root.showModal(); $('#path-name').focus();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize); else initialize();
})();
