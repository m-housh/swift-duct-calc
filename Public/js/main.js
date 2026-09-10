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
