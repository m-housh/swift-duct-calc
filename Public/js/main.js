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

if (!window.ductCalcFocusInitialized) {
  window.ductCalcFocusInitialized = true;
  const requests = new WeakMap();
  const openers = new WeakMap();
  const visible = element => element && element.checkVisibility({ checkVisibilityCSS: true });
  const focus = element => {
    if (!visible(element)) return;
    if (!element.matches('a[href],button,input,select,textarea,summary,[tabindex]')) element.tabIndex = -1;
    element.focus();
  };
  const heading = () => [...document.querySelectorAll('main h1')].find(visible);
  const updateTitle = () => {
    const title = heading()?.textContent.trim();
    if (title) document.title = title === 'Duct Calc' ? title : `${title} · Duct Calc`;
  };
  document.addEventListener('DOMContentLoaded', updateTitle);
  const announce = (message, error = false) => {
    let region = document.getElementById(error ? 'app-error' : 'app-status');
    const dialog = document.querySelector('dialog[open]');
    if (error && dialog) {
      region = dialog.querySelector('[data-request-error]');
      if (!region) {
        region = document.createElement('div');
        region.dataset.requestError = '';
        region.className = 'request-error';
        region.setAttribute('role', 'alert');
        (dialog.querySelector('.modal-box') || dialog).append(region);
      }
    }
    if (!region) return;
    region.textContent = '';
    requestAnimationFrame(() => { if (region.isConnected) region.textContent = message; });
  };
  document.addEventListener('click', event => {
    const opener = event.target.closest('[data-open-dialog]');
    if (opener) {
      const dialog = document.getElementById(opener.dataset.openDialog);
      if (dialog instanceof HTMLDialogElement) {
        openers.set(dialog, opener);
        dialog.showModal();
      }
    }
    if (event.target.closest('.skip-link')) {
      event.preventDefault();
      focus(heading() || document.getElementById('main-content'));
    }
  });
  document.addEventListener('close', event => {
    const opener = openers.get(event.target);
    if (opener?.isConnected) focus(opener);
  }, true);
  document.addEventListener('invalid', event => event.target.setAttribute('aria-invalid', 'true'), true);
  document.addEventListener('input', event => {
    if (event.target.validity?.valid) event.target.removeAttribute('aria-invalid');
  });
  document.addEventListener('htmx:beforeRequest', event => {
    const { xhr, elt, target } = event.detail;
    const active = document.activeElement;
    const dialog = elt.closest('dialog');
    (dialog || document).querySelectorAll('[data-request-error], #app-error').forEach(node => { node.textContent = ''; });
    requests.set(xhr, {
      active, dialog, target,
      next: target?.nextElementSibling,
      message: elt.closest('[data-success-message]')?.dataset.successMessage,
      deletion: elt.hasAttribute('hx-delete'),
      affected: target?.contains(active),
    });
  });
  document.addEventListener('htmx:afterSettle', event => {
    const state = requests.get(event.detail.xhr);
    if (!state) return;
    requests.delete(event.detail.xhr);
    if (state.target?.tagName === 'BODY') updateTitle();
    const error = [...document.querySelectorAll('[data-error-message]')].find(visible);
    const result = document.querySelector('[data-result-summary]');
    if (error) focus(error);
    else {
      if (result && state.target?.id === 'resultView') announce(result.dataset.resultSummary);
      else if (state.message) announce(state.message);
      else if (state.deletion) announce('Item deleted.');
      // Do not interrupt someone who moved to a different, surviving control during the request.
      const active = document.activeElement;
      if (active !== document.body && active !== state.active && active.isConnected && visible(active)) return;
      if (state.dialog && !state.dialog.isConnected) {
        focus(document.querySelector(`[data-open-dialog="${CSS.escape(state.dialog.id)}"]`) || heading());
      } else if (state.affected && !state.active.isConnected) {
        const target = event.detail.elt;
        const autofocus = [...(target?.querySelectorAll('[autofocus]') || [])].find(visible);
        focus(autofocus || state.next?.querySelector('a[href],button') || heading());
      }
    }
  });
  for (const name of ['htmx:responseError', 'htmx:sendError', 'htmx:timeout']) {
    document.addEventListener(name, () => announce('The request could not be completed. Please try again.', true));
  }
}
