/* Account filter controls. Swift validates charts, computes drops, and saves account/project data. */
(() => {
  if (window.ductCalcFilters) return;
  window.ductCalcFilters = true;
  const $ = (selector, root = document) => root.querySelector(selector);
  let busy = false, lookupRequest;
  const status = () => $('#restore-filters[open] [data-filter-restore-error]') || $('#filter-delete-dialog[open] [data-delete-error]') || $('#filter-editor[open] [data-filter-editor-error]') || $('#filter-account #filter-status') || $('#filterLookup[open] [data-filter-status]') || $('#app-error');
  const showError = error => window.ductCalcRequestErrors.render(status(), error);
  async function request(url, options = {}) {
    const response = await fetch(url, { credentials: 'same-origin', ...options,
      headers: { 'X-DuctCalc-Request': 'true', ...options.headers } });
    await window.ductCalcRequestErrors.check(response);
    if (!response.ok || response.redirected) throw Error('Unable to load filter settings. Sign in again or retry.');
    return response.text();
  }
  const post = (url, body) => request(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  async function refreshAccount() {
    const documentNext = new DOMParser().parseFromString(await request(location.href), 'text/html');
    const next = $('#filter-account', documentNext), current = $('#filter-account');
    if (!next || !current) throw Error('Settings saved, but the page could not be refreshed. Reload before editing again.');
    const scroll = scrollY;
    current.replaceWith(next); window.htmx?.process(next); window.scrollTo(0, scroll);
    $('#filter-status').textContent = 'Filter settings saved.';
  }
  async function change(payload) {
    if (busy) return;
    busy = true;
    const controls = [...document.querySelectorAll('#filter-account button, #filter-editor button, #filterLookup button')].map(el => [el, el.disabled]);
    controls.forEach(([el]) => { el.disabled = true; });
    try {
      await post('/filters', payload);
      $('#filter-editor')?.close(); $('#restore-filters')?.close(); $('#filter-delete-dialog')?.close();
      if ($('#filter-account')) await refreshAccount();
      else await refreshLookup();
    } catch (error) { showError(error); }
    finally { busy = false; controls.forEach(([el, disabled]) => { if (el.isConnected) el.disabled = disabled; }); }
  }
  function revision() { return $('#filter-account')?.dataset.filterRevision; }
  async function openEditor(url) {
    if (busy) return;
    try {
      const html = await request(url);
      $('#filter-editor-mount').innerHTML = html;
      const dialog = $('#filter-editor');
      if (!dialog) throw Error('Could not load the filter editor.');
      dialog.showModal(); renumber();
    } catch (error) { showError(error); }
  }
  function editorFilter(form) {
    const value = JSON.parse(form.dataset.filterDraft);
    for (const field of ['manufacturer', 'model', 'description']) value[field] = form.elements[field].value;
    value.points = [...form.querySelectorAll('[data-filter-points] tr')].map(row => ({
      airflow: Number($('[name=pointAirflow]', row).value), pressureDrop: Number($('[name=pointDrop]', row).value)
    }));
    return value;
  }
  function renumber() {
    const rows = [...document.querySelectorAll('[data-filter-points] tr')];
    rows.forEach((row, index) => {
      $('[name=pointAirflow]', row).setAttribute('aria-label', `Airflow for point ${index + 1}`);
      $('[name=pointDrop]', row).setAttribute('aria-label', `Pressure drop for point ${index + 1}`);
      const remove = $('[data-filter-remove-point]', row);
      remove.setAttribute('aria-label', `Remove point ${index + 1}`); remove.disabled = rows.length <= 2;
    });
  }
  function replacePoints(points) {
    const body = $('[data-filter-points]'), template = body.firstElementChild.cloneNode(true);
    body.replaceChildren(...points.map(point => {
      const row = template.cloneNode(true);
      $('[name=pointAirflow]', row).value = point.airflow || '';
      $('[name=pointDrop]', row).value = point.pressureDrop || '';
      return row;
    })); renumber();
  }
  function deleteDialog(button) {
    $('#filter-delete-dialog')?.remove();
    const dialog = document.createElement('dialog'); dialog.id = 'filter-delete-dialog'; dialog.className = 'modal';
    dialog.setAttribute('aria-labelledby', 'filter-delete-title');
    dialog.innerHTML = '<div class="modal-box space-y-4"><h2 id="filter-delete-title" class="text-2xl font-bold"></h2><p>This removes the filter from your library and favorites. Filter losses already saved in projects keep their values.</p><p role="alert" data-delete-error></p><div class="flex justify-end gap-2"><button type="button" class="btn btn-ghost" data-cancel-delete>Cancel</button><button type="button" class="btn btn-error" data-confirm-delete>Delete filter</button></div></div>';
    $('#filter-delete-title', dialog).textContent = `Delete ${button.dataset.filterName}?`;
    $('[data-cancel-delete]', dialog).onclick = () => dialog.close();
    $('[data-confirm-delete]', dialog).onclick = () => change(JSON.parse(button.dataset.filterDelete));
    $('#filter-account').append(dialog); dialog.showModal();
  }
  function hideOver() {
    const root = $('#filterLookup'); if (!root) return;
    const hide = $('[data-filter-hide-over]', root)?.checked;
    root.querySelectorAll('tr[data-filter-over]').forEach(row => {
      row.hidden = hide && row.dataset.filterOver === 'true' && row.dataset.filterFavorite !== 'true';
    });
  }
  async function refreshLookup() {
    const root = $('#filterLookup');
    if (!root?.open) return;
    const config = $('[data-filter-results-url]', root);
    if (!config) return;
    const input = $('[data-filter-allowance]', root);
    if (!input?.checkValidity()) return;
    lookupRequest?.abort(); const controller = new AbortController(); lookupRequest = controller;
    const results = $('[data-filter-results]', root), hidden = $('[data-filter-hide-over]', root)?.checked;
    root.querySelectorAll('button[name=model]').forEach(b => { b.disabled = true; });
    try {
      const html = await request(`${config.dataset.filterResultsUrl}?allowance=${encodeURIComponent(input.value)}`, { signal: controller.signal });
      if (!root.isConnected || controller.signal.aborted || controller !== lookupRequest) return;
      results.innerHTML = html; window.htmx?.process(results);
      const toggle = $('[data-filter-hide-over]', root); if (toggle) toggle.checked = hidden;
      hideOver(); $('[data-filter-status]', root).textContent = '';
    } catch (error) { if (error.name !== 'AbortError') showError(error); }
  }
  document.addEventListener('click', event => {
    const target = event.target.closest('button'); if (!target) return;
    if (target.matches('[data-filter-editor]')) openEditor(target.dataset.filterEditor);
    if (target.matches('[data-filter-change]')) change(JSON.parse(target.dataset.filterChange));
    if (target.matches('[data-filter-delete]')) deleteDialog(target);
    if (target.matches('[data-filter-remove-point]')) { target.closest('tr').remove(); renumber(); }
    if (target.matches('[data-filter-add-point]')) {
      const form = $('#filter-editor-form'), points = editorFilter(form).points;
      if (points.length >= 100) return showError(Error('A chart can contain up to 100 points.'));
      points.push({ airflow: (points.at(-1)?.airflow || 0) + 200, pressureDrop: 0 }); replacePoints(points);
      $('[data-filter-points] tr:last-child [name=pointDrop]').focus();
    }
    if (target.matches('[data-filter-reset]')) {
      const original = JSON.parse(target.dataset.filterReset), form = $('#filter-editor-form');
      for (const field of ['manufacturer', 'model', 'description']) form.elements[field].value = original[field];
      replacePoints(original.points);
    }
    if (target.matches('[data-filter-fill-chart]')) {
      const form = $('#filter-editor-form'), start = Number(form.elements.firstAirflow.value), step = Number(form.elements.airflowStep.value);
      const drops = form.elements.chartValues.value.trim().split(/[\s,]+/).map(Number);
      if (!Number.isInteger(start) || start <= 0 || !Number.isInteger(step) || step <= 0 || drops.length < 2 || drops.length > 100 || drops.some(v => !(v > 0 && v <= 1))) return showError(Error('Enter a positive first airflow and step, and 2 to 100 pressure drops above 0 and at most 1.00.'));
      replacePoints(drops.map((pressureDrop, i) => ({ airflow: start + i * step, pressureDrop })));
    }
    if (target.matches('[data-filter-preview]')) {
      const form = $('#filter-editor-form'); if (!form.reportValidity()) return;
      post('/filters/preview', { filter: editorFilter(form), airflow: Number(form.elements.checkAirflow.value) })
        .then(html => { if (form.isConnected) $('#filter-chart-preview', form).innerHTML = html; }).catch(showError);
    }
  });
  document.addEventListener('submit', event => {
    const form = event.target;
    let payload;
    if (form.id === 'filter-editor-form') {
      const filter = editorFilter(form);
      payload = { action: 'save', revision: form.dataset.filterRevision, id: filter.id || null, filter, selected: form.elements.favorite.checked };
    }
    if (form.matches('[data-filter-maximum]')) payload = { action: 'maximum', revision: revision(), maximumPressureDrop: form.elements.maximumPressureDrop.value === '' ? null : Number(form.elements.maximumPressureDrop.value) };
    if (form.matches('[data-filter-cutoff]')) payload = { action: 'cutoff', revision: revision(), id: form.dataset.filterCutoff, airflowCutoff: form.elements.airflowCutoff.value === '' ? null : Number(form.elements.airflowCutoff.value) };
    if (form.matches('[data-filter-add-favorite]')) payload = { action: 'favorite', revision: revision(), id: form.elements.id.value, selected: true };
    if (form.matches('[data-filter-restore]')) payload = { action: 'restore', revision: revision(), sources: new FormData(form).getAll('sources') };
    if (payload) { event.preventDefault(); change(payload); }
    if (form.id === 'filter-lookup-form') form.dataset.successMessage = event.submitter?.dataset.filterCovered === 'true'
      ? 'The equipment rating covers this filter loss. No additional filter loss was added.' : 'Filter pressure loss saved.';
  }, true);
  let timer;
  document.addEventListener('input', event => {
    if (event.target.matches('[data-filter-allowance]')) {
      clearTimeout(timer); lookupRequest?.abort();
      document.querySelectorAll('#filterLookup button[name=model]').forEach(button => { button.disabled = true; });
      timer = setTimeout(refreshLookup, 200);
    }
  });
  document.addEventListener('change', event => {
    if (event.target.matches('[data-filter-hide-over]')) hideOver();
  });
  function initialize() {
    const root = $('#filterLookup'); if (!root) return;
    const marker = $('[data-filter-auto-open=true]', root);
    if (marker) { marker.dataset.filterAutoOpen = 'false'; root.showModal(); }
    // Refresh on opening so edits made in the account tab are reflected here.
    if (!root.dataset.filterBound) {
      root.dataset.filterBound = 'true';
      const status = document.createElement('p'); status.dataset.filterStatus = ''; status.setAttribute('role', 'status');
      $('[data-filter-results-url]', root).prepend(status);
      new MutationObserver(() => { if (root.open) refreshLookup(); }).observe(root, { attributes: true, attributeFilter: ['open'] });
    }
  }
  window.addEventListener('focus', refreshLookup);
  document.addEventListener('DOMContentLoaded', initialize);
  document.addEventListener('htmx:afterSettle', initialize);
  if (document.readyState !== 'loading') initialize();
})();
