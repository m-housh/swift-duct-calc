(() => {
  if (window.ductCalcTrunkOrderInitialized) return;
  window.ductCalcTrunkOrderInitialized = true;

  const cards = list => [...list.querySelectorAll(':scope > .trunk-card')];
  const status = list => list.querySelector('.trunk-order-status');
  let drag = null;

  function restore(list, original) {
    original.forEach(card => list.insertBefore(card, status(list)));
  }

  async function save(list, original, handle) {
    const ordered = cards(list);
    if (ordered.every((card, index) => card === original[index]) || !list.isConnected) return;
    list.dataset.savingOrder = '';
    list.querySelectorAll('.trunk-drag-handle').forEach(button => { button.disabled = true; });
    const message = status(list);
    delete message.dataset.error;
    message.textContent = 'Saving order…';
    try {
      const body = new URLSearchParams({ type: list.dataset.trunkType });
      ordered.forEach(card => body.append('trunks', card.dataset.trunkId));
      const response = await fetch(list.dataset.trunkOrderUrl, {
        method: 'POST', body, headers: { 'HX-Request': 'true' },
      });
      await window.ductCalcRequestErrors?.check(response);
      if (!response.ok || response.redirected) throw Error('Could not save trunk order. Try again.');
      const index = ordered.indexOf(handle.closest('.trunk-card')) + 1;
      message.textContent = `${handle.dataset.trunkName} moved to position ${index} of ${ordered.length}.`;
    } catch (error) {
      restore(list, original);
      message.dataset.error = '';
      message.textContent = error.message || 'Could not save trunk order. Try again.';
    } finally {
      delete list.dataset.savingOrder;
      list.querySelectorAll('.trunk-drag-handle').forEach(button => { button.disabled = false; });
      if (list.isConnected && document.activeElement === document.body) handle.focus({ preventScroll: true });
    }
  }

  document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && drag) {
      event.preventDefault();
      finish(true);
      return;
    }
    const handle = event.target.closest('.trunk-drag-handle');
    if (!handle || !['ArrowUp', 'ArrowDown'].includes(event.key)) return;
    event.preventDefault();
    const list = handle.closest('[data-trunk-order-url]');
    if (!list || 'savingOrder' in list.dataset || drag) return;
    const original = cards(list);
    const card = handle.closest('.trunk-card');
    const index = original.indexOf(card);
    const target = original[index + (event.key === 'ArrowUp' ? -1 : 1)];
    if (!target) return;
    list.insertBefore(card, event.key === 'ArrowUp' ? target : target.nextSibling);
    save(list, original, handle);
  });

  document.addEventListener('pointerdown', event => {
    const handle = event.target.closest('.trunk-drag-handle');
    if (!handle || event.button !== 0 || !event.isPrimary || drag) return;
    const list = handle.closest('[data-trunk-order-url]');
    if (!list || 'savingOrder' in list.dataset) return;
    event.preventDefault();
    handle.focus({ preventScroll: true });
    drag = { handle, list, card: handle.closest('.trunk-card'), original: cards(list), pointerID: event.pointerId };
    list.setPointerCapture(event.pointerId);
    drag.card.classList.add('is-dragging');
  });

  document.addEventListener('pointermove', event => {
    if (!drag || drag.pointerID !== event.pointerId) return;
    event.preventDefault();
    const target = document.elementFromPoint(event.clientX, event.clientY)?.closest('.trunk-card');
    if (!target || target === drag.card || target.parentElement !== drag.list) return;
    const bounds = target.getBoundingClientRect();
    drag.list.insertBefore(drag.card, event.clientY < bounds.top + bounds.height / 2 ? target : target.nextSibling);
  });

  function finish(cancelled) {
    if (!drag) return;
    const { handle, list, card, original, pointerID } = drag;
    drag = null;
    card.classList.remove('is-dragging');
    if (list.hasPointerCapture(pointerID)) list.releasePointerCapture(pointerID);
    if (cancelled) restore(list, original);
    else save(list, original, handle);
  }

  document.addEventListener('pointerup', event => {
    if (drag?.pointerID === event.pointerId) finish(false);
  });
  document.addEventListener('pointercancel', event => {
    if (drag?.pointerID === event.pointerId) finish(true);
  });
  document.addEventListener('lostpointercapture', event => {
    if (drag?.pointerID === event.pointerId) finish(true);
  });
  document.addEventListener('htmx:beforeSwap', () => finish(true));
})();
