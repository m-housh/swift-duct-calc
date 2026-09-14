// New-project modal: tabs, plus the report import's follow-up questions. `file-import.js` owns
// the file itself; the server decides what is missing or conflicting and this presents it.
(() => {
  if (window.ductCalcProjectImportInitialized) return;
  window.ductCalcProjectImportInitialized = true;
  const projectForm = node => node?.closest?.('[data-project-import]');
  const field = (form, name) => form.elements.namedItem(name);
  const part = (form, name) => form.querySelector(`[data-${name}]`);
  const show = (form, state) => window.ductCalcFileImport.show(form, state);

  function clearDuplicate(form) {
    field(form, 'name').value = '';
    part(form, 'duplicate-details').replaceChildren();
  }

  function selectTab(tab, focus) {
    for (const other of tab.closest('[role=tablist]').querySelectorAll('[role=tab]')) {
      const selected = other === tab;
      other.classList.toggle('tab-active', selected);
      other.setAttribute('aria-selected', String(selected));
      other.tabIndex = selected ? 0 : -1;
      document.getElementById(other.getAttribute('aria-controls')).hidden = !selected;
    }
    if (focus) tab.focus();
  }

  document.addEventListener('click', event => {
    const tab = event.target.closest('[data-project-form-tabs] [role=tab]');
    if (tab) return selectTab(tab, false);
    const form = projectForm(event.target);
    if (form && event.target.closest('[data-import-cancel]')) {
      // Keep an entered ZIP code; only the duplicate decision is abandoned.
      clearDuplicate(form);
      show(form, 'chosen');
      part(form, 'import-submit').querySelector('button').focus();
    }
  });

  document.addEventListener('keydown', event => {
    const tab = event.target.closest?.('[data-project-form-tabs] [role=tab]');
    if (!tab) return;
    const tabs = [...tab.closest('[role=tablist]').querySelectorAll('[role=tab]')];
    const index = tabs.indexOf(tab);
    const next = { ArrowRight: index + 1, ArrowLeft: index - 1, Home: 0, End: tabs.length - 1 }[event.key];
    if (next === undefined) return;
    event.preventDefault();
    selectTab(tabs[(next + tabs.length) % tabs.length], true);
  });

  // A different file starts over: its report decides again what to ask.
  document.addEventListener('file-import:choose', event => {
    const form = projectForm(event.target);
    if (!form) return;
    const zip = field(form, 'zipCode');
    zip.value = '';
    zip.disabled = true;
    zip.required = false;
    clearDuplicate(form);
  });

  document.addEventListener('file-import:state', event => {
    const form = projectForm(event.target);
    // HTMX has already collected the values of a request in flight.
    if (!form || event.detail.state === 'uploading') return;
    const name = field(form, 'name');
    name.required = event.detail.state === 'duplicate';
    name.disabled = !name.required;
    field(form, 'confirmDuplicate').value = String(name.required);
  });

  // Follow-up questions arrive as fragments; keep the form instead of swapping them into the page.
  document.addEventListener('htmx:beforeOnLoad', event => {
    const form = projectForm(event.detail.elt);
    if (!form || event.detail.xhr.status !== 200) return;
    const response = new DOMParser().parseFromString(event.detail.xhr.responseText, 'text/html');
    const missingZIP = response.querySelector('[data-project-import-missing-zip]');
    const conflict = response.querySelector('[data-project-import-conflict]');
    if (!missingZIP && !conflict) return;
    event.preventDefault();
    if (missingZIP) {
      part(form, 'zip-message').textContent = missingZIP.textContent;
      const zip = field(form, 'zipCode');
      zip.disabled = false;
      zip.required = true;
      show(form, 'missing-zip');
      zip.focus();
    } else {
      part(form, 'duplicate-details').replaceChildren(conflict);
      show(form, 'duplicate');
      const name = field(form, 'name');
      name.value = conflict.dataset.suggestedName;
      name.focus();
      name.setSelectionRange(name.value.length, name.value.length);
    }
  });
})();
