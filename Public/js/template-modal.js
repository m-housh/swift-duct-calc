/* Hosts the existing template views inside the project path dialog. */
(() => {
  window.FittingTemplateModal = {
    create(dialog, { endpoint, hasDraft, finish }) {
      const original = [...dialog.children];
      const host = document.createElement('section');
      host.hidden = true;
      host.innerHTML = `<div class="template-modal-toolbar"><button type="button" class="btn" data-template-back>Back to path</button><button type="button" class="btn" data-template-cancel>Cancel</button></div><p class="px-4" role="status" data-template-status></p><div class="template-modal-content"></div>`;
      dialog.append(host);
      const content = host.querySelector('.template-modal-content');
      const status = host.querySelector('[data-template-status]');
      let active = false, pending;
      function canLeave(force = false) {
        const workspace = content.querySelector('#path-template-workspace');
        return workspace
          ? workspace.dispatchEvent(new CustomEvent('path-template:leave', { cancelable: true, detail: { force } }))
          : !force || confirm('Discard unsaved changes to this path?');
      }
      function clear() {
        pending?.abort(); pending = null;
        content.replaceChildren(); host.hidden = true; active = false;
        original.forEach(node => { node.hidden = false; });
        dialog.classList.replace('template-path-active', 'fitting-path');
        dialog.setAttribute('aria-labelledby', 'path-title');
        dialog.removeAttribute('aria-label');
        dialog.scrollTop = 0;
      }
      function back() {
        if (!canLeave()) return;
        clear(); dialog.querySelector('#path-from-template').focus();
      }
      function close() {
        if (!canLeave(hasDraft())) return;
        clear(); finish(endpoint);
      }
      async function load(url, options = {}) {
        pending?.abort();
        const controller = new AbortController(); pending = controller;
        status.textContent = 'Loading templates…';
        try {
          const response = await fetch(url, { ...options, signal: controller.signal, credentials: 'same-origin' });
          if (!response.ok || response.redirected) throw Error('Unable to load templates. Check your connection or sign in again.');
          const page = new DOMParser().parseFromString(await response.text(), 'text/html');
          const failure = page.querySelector('[data-workspace-error]');
          if (failure) throw Error(failure.textContent);
          const view = page.querySelector('#path-template-list, #path-template-page');
          if (!view) throw Error('Unable to load templates. Your path is still available with Back to path.');
          if (controller !== pending) return;
          // The dialog supplies its own return/cancel controls; app navigation stays outside it.
          if (view.id === 'path-template-page') view.firstElementChild?.remove();
          else view.querySelector(`a[href="${endpoint}"]`)?.remove();
          content.replaceChildren(document.importNode(view, true));
          original.forEach(node => { node.hidden = true; });
          host.hidden = false; active = true;
          dialog.classList.replace('fitting-path', 'template-path-active');
          status.textContent = '';
          dialog.querySelector('#path-status').textContent = '';
          document.dispatchEvent(new Event('path-template:mount'));
          dialog.removeAttribute('aria-labelledby');
          dialog.setAttribute('aria-label', 'Build a path from a template');
          const heading = content.querySelector('h1, h2');
          if (heading) { heading.tabIndex = -1; heading.focus(); }
          dialog.scrollTop = 0;
        } catch (error) {
          if (error.name === 'AbortError') return;
          if (active) status.textContent = error.message;
          else dialog.querySelector('#path-status').textContent = error.message;
        } finally { if (pending === controller) pending = null; }
      }
      host.addEventListener('click', event => {
        if (event.target.closest('[data-template-back]')) { back(); return; }
        if (event.target.closest('[data-template-cancel]')) { close(); return; }
        const link = event.target.closest('a[href]');
        if (!link || link.target === '_blank') return;
        const url = new URL(link.href);
        if (url.origin !== location.origin) return;
        event.preventDefault();
        if (url.pathname === endpoint) { back(); return; }
        if (canLeave()) load(url.href);
      });
      host.addEventListener('submit', event => {
        if (!event.target.matches('form[action]')) return;
        event.preventDefault();
        if (canLeave()) load(event.target.action, { method: event.target.method.toUpperCase(), body: new URLSearchParams(new FormData(event.target)) });
      });
      host.addEventListener('path-template:navigate', event => {
        event.preventDefault(); load(event.detail.url);
      });
      host.addEventListener('path-template:saved', event => {
        event.preventDefault(); clear(); finish(event.detail.url);
      });
      return { get active() { return active; }, open: load, close };
    }
  };
})();
