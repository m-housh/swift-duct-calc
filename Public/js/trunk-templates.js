(() => {
  if (window.ductCalcTrunkTemplatesInitialized) return;
  window.ductCalcTrunkTemplatesInitialized = true;

  function setOpen(picker, open, focus = false) {
    const trigger = picker.querySelector('[data-trunk-template-toggle]');
    const panel = picker.querySelector('.trunk-template-panel');
    panel.hidden = !open;
    trigger.setAttribute('aria-expanded', String(open));
    if (focus) {
      (open ? panel.querySelector('[aria-pressed=true]') : trigger).focus({ preventScroll: !open });
    }
  }

  document.addEventListener('click', event => {
    const trigger = event.target.closest('[data-trunk-template-toggle]');
    if (trigger) {
      setOpen(trigger.closest('.trunk-template-picker'), trigger.getAttribute('aria-expanded') !== 'true');
      return;
    }
    const option = event.target.closest('[data-trunk-template]');
    if (option) {
      const form = option.form;
      const runs = new Set(option.dataset.runs.split(','));
      if (option.dataset.type) form.elements.namedItem('type').value = option.dataset.type;
      form.elements.namedItem('name').value = option.value;
      form.querySelectorAll('input[name="rooms"]').forEach(input => {
        input.checked = runs.has(input.value);
      });
      const picker = option.closest('.trunk-template-picker');
      picker.querySelectorAll('[data-trunk-template]').forEach(button => {
        button.setAttribute('aria-pressed', String(button === option));
      });
      picker.querySelector('[data-trunk-template-summary]').textContent = option.value || 'No template';
      picker.querySelector('[data-trunk-template-toggle]').dataset.type = option.dataset.type || '';
      form.elements.namedItem('name').dispatchEvent(new Event('input', { bubbles: true }));
      setOpen(picker, false, true);
      return;
    }
    document.querySelectorAll('.trunk-template-picker').forEach(picker => {
      if (!picker.contains(event.target)) setOpen(picker, false);
    });
  });

  document.addEventListener('focusin', event => {
    document.querySelectorAll('.trunk-template-picker').forEach(picker => {
      if (!picker.contains(event.target)) setOpen(picker, false);
    });
  });

  document.addEventListener('keydown', event => {
    const picker = event.target.closest('.trunk-template-picker');
    if (!picker) return;
    const panel = picker.querySelector('.trunk-template-panel');
    if (event.key === 'Escape' && !panel.hidden) {
      event.preventDefault();
      setOpen(picker, false, true);
      return;
    }
    if (event.target.matches('[data-trunk-template-toggle]') && ['ArrowDown', 'ArrowUp'].includes(event.key)) {
      event.preventDefault();
      setOpen(picker, true, true);
      return;
    }
    if (panel.hidden || !panel.contains(event.target)
      || !['ArrowDown', 'ArrowUp', 'ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return;
    event.preventDefault();
    const options = [...panel.querySelectorAll('[data-trunk-template]')];
    let index = options.indexOf(document.activeElement);
    if (event.key === 'Home') index = 0;
    else if (event.key === 'End') index = options.length - 1;
    // The first option spans both columns; the remaining options are supply/return pairs.
    else if (index === 0) { if (event.key === 'ArrowDown') index = 1; }
    else if (event.key === 'ArrowLeft') index -= (index - 1) % 2;
    else if (event.key === 'ArrowRight') index += 1 - (index - 1) % 2;
    else if (event.key === 'ArrowUp') index = Math.max(0, index - 2);
    else if (index + 2 < options.length) index += 2;
    options[index].focus();
  });

  document.addEventListener('close', event => {
    event.target.querySelectorAll?.('.trunk-template-picker').forEach(picker => setOpen(picker, false));
  }, true);
})();
