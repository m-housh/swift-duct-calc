function syncInputs(lhs, rhs) {
	const first = document.getElementById(lhs);
	const second = document.getElementById(rhs);
	first.value = second.value;
}

// Resolve the current controls on each press because HTMX replaces the body during navigation.
document.addEventListener('keydown', (event) => {
  const key = event.key.toLowerCase();
  if (event.defaultPrevented || event.repeat || event.isComposing
      || !event.ctrlKey || !event.altKey || event.shiftKey || event.metaKey
      || event.getModifierState('AltGraph') || !/^[1-6jkdfpu]$/.test(key)) return;

  const editing = event.composedPath().some(node => node instanceof Element && (
    node.isContentEditable
    || node.matches('input, textarea, select, [contenteditable]:not([contenteditable="false"]), [role="textbox"], [role="combobox"], [role="spinbutton"]')
  ));
  if (editing || document.querySelector('dialog[open], [role="dialog"][aria-modal="true"]')) return;

  const buttons = [...document.querySelectorAll('#project-sidebar button[aria-keyshortcuts]')];
  let control;
  if (key === 'j' || key === 'k') {
    const current = buttons.findIndex(button => button.dataset.active === 'true');
    if (current === -1) return;
    const next = Math.max(0, Math.min(buttons.length - 1, current + (key === 'j' ? 1 : -1)));
    control = buttons[next];
  } else {
    const shortcut = `Control+Alt+${key.toUpperCase()}`;
    control = document.querySelector(
      `#project-sidebar button[aria-keyshortcuts="${shortcut}"], nav a[aria-keyshortcuts="${shortcut}"]`
    );
  }
  if (!control || control.matches(':disabled') || control.closest('[inert]')) return;

  event.preventDefault();
  if (control.dataset.active !== 'true') control.click();
});
