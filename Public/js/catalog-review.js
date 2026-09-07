(() => {
  function initialize() {
    const root = document.querySelector('#catalog-review'); if (!root || root.dataset.initialized) return;
    root.dataset.initialized = 'true';
    const cards = [...root.querySelectorAll('[data-review-id]')], save = root.querySelector('#save-catalog-review'), status = root.querySelector('#review-status');
    let version = root.dataset.version, dirty = false, busy = false;
    const value = card => ({ id: card.dataset.reviewId, ductShape: card.querySelector('[name=ductShape]').value, reviewed: card.querySelector('[name=reviewed]').checked });
    let baseline = new Map(cards.map(card => [card.dataset.reviewId, JSON.stringify(value(card))]));
    function changes() { return cards.map(value).filter(item => JSON.stringify(item) !== baseline.get(item.id)); }
    function update() {
      dirty = changes().length > 0; save.disabled = busy || !dirty;
      let reviewed = 0;
      for (const card of cards) {
        const item = value(card), changed = JSON.stringify(item) !== baseline.get(item.id);
        card.dataset.changed = changed; if (item.reviewed) reviewed++;
        card.querySelector('.review-card-status').textContent = `${item.reviewed ? 'Reviewed' : 'Needs review'}${changed ? ' · Unsaved' : ''}`;
      }
      root.querySelector('#review-progress').textContent = `${reviewed} of ${cards.length} reviewed`;
    }
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
        baseline = new Map(cards.map(card => [card.dataset.reviewId, JSON.stringify(value(card))]));
        status.textContent = saved.textContent;
        const groupLink = root.querySelector(`[data-review-group="${root.dataset.group}"]`);
        groupLink.textContent = `Group ${root.dataset.group} · ${cards.filter(card => value(card).reviewed).length}/${cards.length}`;
      } catch (error) { status.textContent = error.message; }
      finally { busy = false; root.inert = false; update(); }
    });
    window.addEventListener('beforeunload', event => { if (dirty) { event.preventDefault(); event.returnValue = ''; } });
    update();
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize); else initialize();
})();
