/* Shared interaction for Styleguide.GroupCarousel; adapted from the agreed prototype. */
window.initializeGroupCarousel = function (root) {
  if (root.dataset.initialized) return;
  root.dataset.initialized = 'true';
  const slides = [...root.querySelectorAll('.carousel-slide')];
  let index = 0, pointer = null, suppressClickUntil = 0, wheelDistance = 0, lastWheel = 0, wheelLockedUntil = 0;
  const track = root.querySelector('.carousel-track');
  function move(next) {
    index = (next + slides.length) % slides.length;
    slides.forEach((slide, i) => {
      let delta = (i - index + slides.length) % slides.length;
      if (delta > slides.length / 2) delta -= slides.length;
      const distance = Math.abs(delta), active = distance === 0;
      slide.classList.toggle('is-current', active);
      slide.style.setProperty('--card-offset', delta); slide.style.setProperty('--card-depth', distance);
      slide.style.zIndex = 20 - distance; slide.style.visibility = distance > 1 ? 'hidden' : 'visible';
      slide.inert = distance > 1; slide.setAttribute('aria-hidden', String(distance > 1));
      slide.querySelector('.group-option').inert = !active;
      slide.querySelector('.carousel-peek').hidden = active;
    });
    root.querySelectorAll('.carousel-pagination button').forEach((button, i) => button.setAttribute('aria-pressed', String(i === index)));
    root.querySelector('.carousel-position').textContent = `${index + 1} of ${slides.length} groups`;
  }
  root.addEventListener('click', (event) => {
    const step = event.target.closest('[data-carousel-step]'), jump = event.target.closest('[data-carousel-jump]');
    if (step) move(index + Number(step.dataset.carouselStep));
    if (jump) move(Number(jump.dataset.carouselJump));
  });
  root.addEventListener('keydown', (event) => {
    if (event.target.matches('input,select,textarea')) return;
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') { event.preventDefault(); move(index + (event.key === 'ArrowLeft' ? -1 : 1)); }
  });
  track.addEventListener('dragstart', event => event.preventDefault());
  track.addEventListener('pointerdown', event => {
    if (event.isPrimary === false || event.button !== 0) return;
    pointer = { id: event.pointerId, x: event.clientX, y: event.clientY, started: performance.now(), dx: 0, dragging: false };
  });
  track.addEventListener('pointermove', event => {
    if (!pointer || pointer.id !== event.pointerId) return;
    const dx = event.clientX - pointer.x, dy = event.clientY - pointer.y;
    if (!pointer.dragging) {
      if (Math.max(Math.abs(dx), Math.abs(dy)) < 9) return;
      if (Math.abs(dy) > Math.abs(dx)) { pointer = null; return; }
      pointer.dragging = true; track.classList.add('is-dragging'); track.setPointerCapture(event.pointerId);
    }
    event.preventDefault(); pointer.dx = dx; track.style.setProperty('--drag-x', `${Math.max(-180, Math.min(180, dx * .75))}px`);
  }, { passive: false });
  function finish(event, cancelled = false) {
    if (!pointer || pointer.id !== event.pointerId) return;
    const p = pointer; pointer = null;
    track.classList.remove('is-dragging'); track.style.setProperty('--drag-x', '0px');
    if (track.hasPointerCapture(p.id)) track.releasePointerCapture(p.id);
    if (!p.dragging) return;
    suppressClickUntil = performance.now() + 450;
    if (!cancelled && (Math.abs(p.dx) >= 55 || (Math.abs(p.dx) >= 24 && Math.abs(p.dx) / Math.max(1, performance.now() - p.started) > .45))) move(index + (p.dx < 0 ? 1 : -1));
  }
  track.addEventListener('pointerup', event => finish(event));
  track.addEventListener('pointercancel', event => finish(event, true));
  track.addEventListener('lostpointercapture', event => finish(event, true));
  track.addEventListener('click', event => {
    if (event.detail !== 0 && performance.now() < suppressClickUntil) { event.preventDefault(); event.stopImmediatePropagation(); }
  }, { capture: true });
  track.addEventListener('wheel', event => {
    if (event.ctrlKey || Math.abs(event.deltaX) <= Math.abs(event.deltaY)) return;
    event.preventDefault(); const now = performance.now();
    if (now < wheelLockedUntil) return;
    if (now - lastWheel > 180 || Math.sign(event.deltaX) !== Math.sign(wheelDistance)) wheelDistance = 0;
    lastWheel = now; wheelDistance += event.deltaX * (event.deltaMode === 1 ? 16 : event.deltaMode === 2 ? track.clientWidth : 1);
    if (Math.abs(wheelDistance) >= 65) { move(index + (wheelDistance > 0 ? 1 : -1)); wheelDistance = 0; wheelLockedUntil = now + 300; }
  }, { passive: false });
  move(0);
};
