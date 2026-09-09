(() => {
  function initialize() {
    const root = document.querySelector('#catalog-review'); if (!root || root.dataset.initialized) return;
    root.dataset.initialized = 'true';
    const rows = [...root.querySelectorAll('[data-review-id]')], save = root.querySelector('#save-catalog-review'), status = root.querySelector('#review-status');
    const selectAll = root.querySelector('#review-select-all'), bulkShape = root.querySelector('#review-bulk-shape');
    const applyShape = root.querySelector('#review-apply-shape'), markReviewed = root.querySelector('#review-mark-reviewed');
    const markPending = root.querySelector('#review-mark-pending'), clearSelection = root.querySelector('#review-clear-selection');
    const selected = () => rows.filter(row => row.querySelector('[name=selected]').checked);
    let version = root.dataset.version, dirty = false, busy = false, selectionAnchor = null;
    const value = row => ({ id: row.dataset.reviewId, ductShape: row.querySelector('[name=ductShape]').value, reviewed: row.querySelector('[name=reviewed]').checked });
    let baseline = new Map(rows.map(row => [row.dataset.reviewId, JSON.stringify(value(row))]));
    function changes() { return rows.map(value).filter(item => JSON.stringify(item) !== baseline.get(item.id)); }
    function update() {
      dirty = changes().length > 0; save.disabled = busy || !dirty;
      let reviewed = 0;
      for (const row of rows) {
        const item = value(row), changed = JSON.stringify(item) !== baseline.get(item.id);
        row.dataset.changed = changed; if (item.reviewed) reviewed++;
        row.querySelector('.review-card-status').textContent = `${item.reviewed ? 'Reviewed' : 'Needs review'}${changed ? ' · Unsaved' : ''}`;
      }
      root.querySelector('#review-progress').textContent = `${reviewed} of ${rows.length} reviewed · ${changes().length} unsaved`;
      const count = selected().length;
      root.querySelector('#review-selection-count').textContent = `${count} selected`;
      selectAll.checked = count > 0 && count === rows.length;
      selectAll.indeterminate = count > 0 && count < rows.length;
      applyShape.disabled = busy || !count || !bulkShape.value;
      markReviewed.disabled = markPending.disabled = clearSelection.disabled = busy || !count;
      for (const row of rows) row.dataset.selected = row.querySelector('[name=selected]').checked;
    }
    // Shift-click extends the current checkbox state across a contiguous range.
    root.addEventListener('click', event => {
      if (event.target.name !== 'selected') return;
      const index = rows.indexOf(event.target.closest('[data-review-id]'));
      if (event.shiftKey && selectionAnchor !== null) {
        for (const row of rows.slice(Math.min(index, selectionAnchor), Math.max(index, selectionAnchor) + 1)) {
          row.querySelector('[name=selected]').checked = event.target.checked;
        }
      }
      selectionAnchor = index;
      update();
    });
    selectAll.addEventListener('change', () => {
      for (const row of rows) row.querySelector('[name=selected]').checked = selectAll.checked;
      selectionAnchor = null;
      update();
    });
    clearSelection.addEventListener('click', () => {
      for (const row of rows) row.querySelector('[name=selected]').checked = false;
      selectionAnchor = null;
      update();
    });
    function applyToSelection(shape, reviewed) {
      for (const row of selected()) {
        if (shape) row.querySelector('[name=ductShape]').value = shape;
        row.querySelector('[name=reviewed]').checked = reviewed;
      }
      update();
    }
    applyShape.addEventListener('click', () => { if (bulkShape.value) applyToSelection(bulkShape.value, true); });
    markReviewed.addEventListener('click', () => applyToSelection(null, true));
    markPending.addEventListener('click', () => applyToSelection(null, false));
    root.addEventListener('change', event => {
      // Choosing a classification is an explicit review decision.
      if (event.target.name === 'ductShape') event.target.closest('[data-review-id]').querySelector('[name=reviewed]').checked = true;
      update();
    });
    save.addEventListener('click', async () => {
      if (busy || !dirty) return;
      const edits = changes(); busy = true; root.inert = true; update(); status.textContent = 'Saving catalog review…';
      try {
        const response = await fetch('/fittings/review', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ payload: JSON.stringify({ version, changes: edits }) }) });
        if (!response.ok || response.redirected) throw Error('Save failed. Check your connection or sign in again. Your choices are still on this page.');
        const template = document.createElement('template'); template.innerHTML = await response.text();
        const saved = template.content.querySelector('[data-review-saved]');
        if (!saved) throw Error(template.content.textContent.trim() || 'Catalog review could not be saved.');
        version = saved.dataset.reviewSaved;
        baseline = new Map(rows.map(row => [row.dataset.reviewId, JSON.stringify(value(row))]));
        status.textContent = saved.textContent;
        const groupLink = root.querySelector(`[data-review-group="${root.dataset.group}"]`);
        groupLink.textContent = `Group ${root.dataset.group} · ${rows.filter(row => value(row).reviewed).length}/${rows.length}`;
      } catch (error) { status.textContent = error.message; }
      finally { busy = false; root.inert = false; update(); }
    });
    window.addEventListener('beforeunload', event => { if (dirty) { event.preventDefault(); event.returnValue = ''; } });
    update();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize); else initialize();
})();
